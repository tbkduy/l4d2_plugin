#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.3"
#define MAX_ENTS 2049
#define MELEE_ID_SIZE 128

#define DMG_BULLET_L4D2 (1 << 1)
#define DMG_BURN_L4D2   (1 << 3)
#define DMG_BLAST_L4D2  (1 << 6)
#define DMG_CLUB_L4D2   (1 << 7)

ConVar g_hMinDur;
ConVar g_hMaxDur;
ConVar g_hDisableOnFinale;
ConVar g_hDebug;
ConVar g_hPreserveReplace;
ConVar g_hPreserveWindow;

bool g_bFinaleStarted;
bool g_bCommonHooked[MAX_ENTS];

int g_iDurability[MAX_ENTS];
int g_iMaxDurability[MAX_ENTS];
int g_iLastMelee[MAXPLAYERS + 1];

// anti multi-hit: 1 swing chỉ trừ 1 lần, kể cả quét trúng nhiều common/SI
float g_fNextDurability[MAXPLAYERS + 1];

// dùng để chắc chắn damage vừa xảy ra là từ một cú vung melee thật
float g_fLastMeleeSwing[MAXPLAYERS + 1];

// chống exploit đổi character/plugin CSM làm weapon_melee bị tạo entity mới rồi random lại durability
char g_sSavedMeleeIdentity[MAXPLAYERS + 1][MELEE_ID_SIZE];
int g_iSavedMeleeDurability[MAXPLAYERS + 1];
int g_iSavedMeleeMaxDurability[MAXPLAYERS + 1];
float g_fSavedMeleeTime[MAXPLAYERS + 1];

// Chỉ restore durability khi thật sự vừa đổi character/model, tránh ảnh hưởng give/pickup cùng loại.
bool g_bHasCharacterCache[MAXPLAYERS + 1];
int g_iLastSurvivorCharacter[MAXPLAYERS + 1];
char g_sLastPlayerModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
float g_fLastCharacterChangeTime[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "[L4D2] Melee Durability",
    author      = "TBK Duy",
    description = "Melee durability system",
    version     = PLUGIN_VERSION,
    url         = "N/A"
};

public void OnPluginStart()
{
    g_hMinDur = CreateConVar(
        "sm_melee_durability_min",
        "36",
        "Minimum melee durability",
        FCVAR_NOTIFY,
        true,
        1.0
    );

    g_hMaxDur = CreateConVar(
        "sm_melee_durability_max",
        "67",
        "Maximum melee durability",
        FCVAR_NOTIFY,
        true,
        1.0
    );

    g_hDisableOnFinale = CreateConVar(
        "sm_melee_durability_disable_finale",
        "1",
        "Disable melee durability during finale",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    g_hDebug = CreateConVar(
        "sm_melee_durability_debug",
        "0",
        "Debug melee durability damage detection",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    g_hPreserveReplace = CreateConVar(
        "sm_melee_durability_preserve_replace",
        "1",
        "Preserve melee durability when the same melee is recreated/re-equipped by character switch plugins",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    g_hPreserveWindow = CreateConVar(
        "sm_melee_durability_preserve_window",
        "5.0",
        "Seconds to restore old durability to a newly recreated same melee entity",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        30.0
    );

    HookEvent("weapon_fire", Event_WeaponFire);
    HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("infected_hurt", Event_InfectedHurt);

	HookEvent("finale_rush", Event_FinaleStart);
	HookEvent("finale_start", Event_FinaleStart);
	HookEvent("finale_radio_start", Event_FinaleStart);
	HookEvent("finale_escape_start", Event_FinaleStart);
	HookEvent("gauntlet_finale_start", Event_FinaleStart);
	
    HookEvent("finale_win", Event_FinaleEnd);
    HookEvent("mission_lost", Event_FinaleEnd);
    HookEvent("map_transition", Event_FinaleEnd);

    // Nếu plugin được reload khi người chơi đã ở trong server thì vẫn hook được equip.
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
        }
    }

    CreateTimer(1.0, Timer_HookExistingCommons, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapStart()
{
    g_bFinaleStarted = false;

    for (int i = 0; i < MAX_ENTS; i++)
    {
        g_iDurability[i] = 0;
        g_iMaxDurability[i] = 0;
        g_bCommonHooked[i] = false;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        ResetClientCache(i);
    }

    CreateTimer(1.0, Timer_HookExistingCommons, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);

    g_bHasCharacterCache[client] = false;
    g_fLastCharacterChangeTime[client] = 0.0;
    RequestFrame(Frame_InitCharacterCache, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
    ResetClientCache(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity <= MaxClients || entity >= MAX_ENTS)
        return;

    if (!StrEqual(classname, "infected"))
        return;

    RequestFrame(Frame_HookCommon, EntIndexToEntRef(entity));
}

public void OnEntityDestroyed(int entity)
{
    if (entity <= 0 || entity >= MAX_ENTS)
        return;

    g_iDurability[entity] = 0;
    g_iMaxDurability[entity] = 0;
    g_bCommonHooked[entity] = false;
}

public void OnWeaponEquipPost(int client, int weapon)
{
    if (!IsValidHuman(client))
        return;

    UpdateClientCharacterCache(client);

    if (!IsValidMeleeWeapon(weapon))
        return;

    if (!TryRestoreClientMeleeDurability(client, weapon))
    {
        InitMeleeDurability(weapon);
    }

    SaveClientMeleeDurability(client, weapon);

    // Delay 1 frame để chắc chắn entity đã attach vào player.
    RequestFrame(Frame_NotifyMeleePickup, EntIndexToEntRef(weapon));
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidHuman(client))
        return;

    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));

    if (!StrEqual(weapon, "melee"))
        return;

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidMeleeWeapon(activeWeapon))
        return;

    g_fLastMeleeSwing[client] = GetGameTime();
}

public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!IsValidHuman(attacker))
        return;

    if (!IsRecentMeleeSwing(attacker))
        return;

    int activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
    if (!IsValidMeleeWeapon(activeWeapon))
        return;

    int dmgType = event.GetInt("type");
    if (IsClearlyNonMeleeDamageType(dmgType))
        return;

    // Không check cứng weapon == "melee" nữa.
    // Một số melee được give/spawn có thể bắn infected_hurt với weapon name khác,
    // nhưng active weapon vẫn là weapon_melee và cú đánh vừa xảy ra là weapon_fire melee.

    DebugInfectedHurt(event, attacker, activeWeapon, dmgType);

    TryDamageMelee(attacker, activeWeapon);
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));

    int dmg = event.GetInt("dmg_health");
    if (dmg <= 0)
        return;

    if (!IsValidHuman(attacker))
        return;

    if (!IsRecentMeleeSwing(attacker))
        return;

    if (victim <= 0 || victim > MaxClients)
        return;

    if (!IsClientInGame(victim))
        return;

    // Chỉ infected player: SI/Tank.
    if (GetClientTeam(victim) != 3)
        return;

    // Tank đang gục không trừ durability.
    if (IsTank(victim) && GetEntProp(victim, Prop_Send, "m_isIncapacitated") != 0)
        return;

    int dmgType = event.GetInt("type");
    if (IsClearlyNonMeleeDamageType(dmgType))
        return;

    int activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
    if (!IsValidMeleeWeapon(activeWeapon))
        return;

    TryDamageMelee(attacker, activeWeapon);
}

public Action OnCommonTakeDamage(
    int victim,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damagetype
)
{
    if (damage <= 0.0)
        return Plugin_Continue;

    if (!IsValidHuman(attacker))
        return Plugin_Continue;

    int activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
    if (!IsValidMeleeWeapon(activeWeapon))
        return Plugin_Continue;

    if (!IsLikelyCommonMeleeDamage(attacker, activeWeapon, inflictor, damagetype))
        return Plugin_Continue;

    DebugCommonDamage(victim, attacker, activeWeapon, inflictor, damage, damagetype);

    TryDamageMelee(attacker, activeWeapon);

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(
    int client,
    int &buttons,
    int &impulse,
    float vel[3],
    float angles[3],
    int &weapon
)
{
    if (!IsValidHuman(client))
        return Plugin_Continue;

    UpdateClientCharacterCache(client);

    int melee = GetPlayerWeaponSlot(client, 1);

    if (!IsValidMeleeWeapon(melee))
    {
        g_iLastMelee[client] = 0;
        return Plugin_Continue;
    }

    int ref = EntIndexToEntRef(melee);

    if (ref != g_iLastMelee[client])
    {
        g_iLastMelee[client] = ref;

        // Fallback cực quan trọng cho melee được give bằng console/plugin hoặc spawn sẵn
        // nếu SDKHook_WeaponEquipPost không khởi tạo đúng lúc.
        // Nếu plugin đổi nhân vật vừa tạo lại cùng loại melee, restore durability cũ.
        if (!TryRestoreClientMeleeDurability(client, melee))
        {
            InitMeleeDurability(melee);
        }

        NotifyMeleePickup(client, melee);
    }

    SaveClientMeleeDurability(client, melee);

    return Plugin_Continue;
}

public Action Timer_HookExistingCommons(Handle timer)
{
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "infected")) != -1)
    {
        HookCommonIfValid(entity);
    }

    return Plugin_Stop;
}

void Frame_HookCommon(int ref)
{
    int entity = EntRefToEntIndex(ref);
    if (entity == INVALID_ENT_REFERENCE)
        return;

    HookCommonIfValid(entity);
}

void HookCommonIfValid(int entity)
{
    if (entity <= MaxClients || entity >= MAX_ENTS)
        return;

    if (!IsValidEntity(entity))
        return;

    if (g_bCommonHooked[entity])
        return;

    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (!StrEqual(classname, "infected"))
        return;

    SDKHook(entity, SDKHook_OnTakeDamage, OnCommonTakeDamage);
    g_bCommonHooked[entity] = true;
}

void TryDamageMelee(int client, int melee)
{
    if (g_hDisableOnFinale.BoolValue && g_bFinaleStarted)
        return;

    if (!CanLoseDurability(client))
        return;

    DamageMelee(client, melee);
}

bool CanLoseDurability(int client)
{
    float time = GetGameTime();

    if (time < g_fNextDurability[client])
        return false;

    g_fNextDurability[client] = time + 0.25;
    return true;
}

bool IsRecentMeleeSwing(int client)
{
    return (GetGameTime() - g_fLastMeleeSwing[client] <= 0.35);
}

bool IsClearlyNonMeleeDamageType(int dmgType)
{
    if ((dmgType & DMG_BULLET_L4D2) != 0)
        return true;

    if ((dmgType & DMG_BURN_L4D2) != 0)
        return true;

    if ((dmgType & DMG_BLAST_L4D2) != 0)
        return true;

    return false;
}

bool IsLikelyCommonMeleeDamage(int client, int activeWeapon, int inflictor, int dmgType)
{
    if (!IsValidMeleeWeapon(activeWeapon))
        return false;

    if (IsClearlyNonMeleeDamageType(dmgType))
        return false;

    if (inflictor == activeWeapon)
        return true;

    if (IsValidMeleeWeapon(inflictor))
        return true;

    if ((dmgType & DMG_CLUB_L4D2) != 0 && IsRecentMeleeSwing(client))
        return true;

    // Fallback cho những melee/entity lạ: vừa weapon_fire melee, đang cầm weapon_melee,
    // damage type không phải bullet/burn/blast thì cho tính là melee hit.
    if (IsRecentMeleeSwing(client))
        return true;

    return false;
}

bool IsValidMeleeWeapon(int weapon)
{
    if (weapon <= MaxClients || weapon >= MAX_ENTS)
        return false;

    if (!IsValidEntity(weapon))
        return false;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    return StrEqual(classname, "weapon_melee");
}

void InitMeleeDurability(int weapon)
{
    if (!IsValidMeleeWeapon(weapon))
        return;

    if (g_iMaxDurability[weapon] > 0)
        return;

    int minDur = g_hMinDur.IntValue;
    int maxDur = g_hMaxDur.IntValue;

    if (minDur > maxDur)
    {
        int temp = minDur;
        minDur = maxDur;
        maxDur = temp;
    }

    int durability = GetRandomInt(minDur, maxDur);

    g_iDurability[weapon] = durability;
    g_iMaxDurability[weapon] = durability;
}

void DamageMelee(int client, int melee)
{
    if (!IsValidHuman(client))
        return;

    if (!IsValidMeleeWeapon(melee))
    {
        melee = GetPlayerWeaponSlot(client, 1);
    }

    if (!IsValidMeleeWeapon(melee))
        return;

    // Fallback cho melee bị miss WeaponEquipPost hoặc được spawn/give bằng đường lạ.
    if (!TryRestoreClientMeleeDurability(client, melee))
    {
        InitMeleeDurability(melee);
    }

    if (g_iMaxDurability[melee] <= 0)
        return;

    g_iDurability[melee]--;

    if (g_iDurability[melee] < 0)
    {
        g_iDurability[melee] = 0;
    }

    SaveClientMeleeDurability(client, melee);

    PrintHintText(
        client,
        "Melee durability: %d",
        g_iDurability[melee]
    );

    if (g_iDurability[melee] > 0)
        return;

    char playerName[MAX_NAME_LENGTH];
    GetClientName(client, playerName, sizeof(playerName));

    PrintToChatAll(
        "\x04%s\x03 melee weapon \x04broke\x03!",
        playerName
    );

    RemovePlayerItem(client, melee);

    if (IsValidEntity(melee))
    {
        AcceptEntityInput(melee, "Kill");
    }

    GivePlayerItem(client, "weapon_pistol");

    PrintHintText(client, "Your melee weapon broke!");
}

void NotifyMeleePickup(int client, int weapon)
{
    if (!IsValidHuman(client))
        return;

    if (!IsValidMeleeWeapon(weapon))
        return;

    if (!TryRestoreClientMeleeDurability(client, weapon))
    {
        InitMeleeDurability(weapon);
    }

    if (g_iMaxDurability[weapon] <= 0)
        return;

    PrintHintText(
        client,
        "Melee durability: %d",
        g_iDurability[weapon]
    );
}

void Frame_NotifyMeleePickup(int ref)
{
    int weapon = EntRefToEntIndex(ref);
    if (weapon == INVALID_ENT_REFERENCE)
        return;

    if (!IsValidMeleeWeapon(weapon))
        return;

    int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

    if (!IsValidHuman(client))
        return;

    NotifyMeleePickup(client, weapon);
}


void Frame_InitCharacterCache(int userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || client > MaxClients)
        return;

    if (!IsClientInGame(client))
        return;

    UpdateClientCharacterCache(client);
}

void UpdateClientCharacterCache(int client)
{
    if (client <= 0 || client > MaxClients)
        return;

    if (!IsClientInGame(client))
        return;

    int survivorCharacter = -1;
    if (HasEntProp(client, Prop_Send, "m_survivorCharacter"))
    {
        survivorCharacter = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    }

    char model[PLATFORM_MAX_PATH];
    model[0] = '\0';
    GetClientModel(client, model, sizeof(model));
    TrimString(model);

    if (!g_bHasCharacterCache[client])
    {
        g_bHasCharacterCache[client] = true;
        g_iLastSurvivorCharacter[client] = survivorCharacter;
        strcopy(g_sLastPlayerModel[client], PLATFORM_MAX_PATH, model);
        return;
    }

    if (survivorCharacter == g_iLastSurvivorCharacter[client]
        && StrEqual(model, g_sLastPlayerModel[client], false))
    {
        return;
    }

    g_iLastSurvivorCharacter[client] = survivorCharacter;
    strcopy(g_sLastPlayerModel[client], PLATFORM_MAX_PATH, model);
    g_fLastCharacterChangeTime[client] = GetGameTime();

    if (g_hDebug.BoolValue)
    {
        PrintToServer(
            "[MeleeDurability] character/model changed: client=%N survivorCharacter=%d model=%s",
            client,
            survivorCharacter,
            model
        );
    }
}

void ResetClientCache(int client)
{
    g_iLastMelee[client] = 0;
    g_fNextDurability[client] = 0.0;
    g_fLastMeleeSwing[client] = 0.0;

    g_sSavedMeleeIdentity[client][0] = '\0';
    g_iSavedMeleeDurability[client] = 0;
    g_iSavedMeleeMaxDurability[client] = 0;
    g_fSavedMeleeTime[client] = 0.0;

    g_bHasCharacterCache[client] = false;
    g_iLastSurvivorCharacter[client] = -1;
    g_sLastPlayerModel[client][0] = '\0';
    g_fLastCharacterChangeTime[client] = 0.0;
}

void SaveClientMeleeDurability(int client, int weapon)
{
    if (!IsValidHuman(client))
        return;

    if (!IsValidMeleeWeapon(weapon))
        return;

    if (g_iMaxDurability[weapon] <= 0)
        return;

    char identity[MELEE_ID_SIZE];
    GetMeleeIdentity(weapon, identity, sizeof(identity));

    if (identity[0] == '\0')
        return;

    strcopy(g_sSavedMeleeIdentity[client], MELEE_ID_SIZE, identity);
    g_iSavedMeleeDurability[client] = g_iDurability[weapon];
    g_iSavedMeleeMaxDurability[client] = g_iMaxDurability[weapon];
    g_fSavedMeleeTime[client] = GetGameTime();
}

bool TryRestoreClientMeleeDurability(int client, int weapon)
{
    if (!g_hPreserveReplace.BoolValue)
        return false;

    if (!IsValidHuman(client))
        return false;

    UpdateClientCharacterCache(client);

    if (!IsValidMeleeWeapon(weapon))
        return false;

    // Entity này đã có durability riêng thì không đè lên.
    if (g_iMaxDurability[weapon] > 0)
        return false;

    float window = g_hPreserveWindow.FloatValue;
    if (window <= 0.0)
        return false;

    // Quan trọng: chỉ restore khi vừa có đổi character/model.
    // Nhờ vậy give weapon hoặc nhặt melee cùng loại bình thường sẽ không bị lấy durability cũ.
    if (g_fLastCharacterChangeTime[client] <= 0.0)
        return false;

    float characterElapsed = GetGameTime() - g_fLastCharacterChangeTime[client];
    if (characterElapsed > window)
        return false;

    if (g_iSavedMeleeMaxDurability[client] <= 0)
        return false;

    // Không restore vũ khí đã gãy, tránh nhặt melee mới rồi bị set thành 0 ngay.
    if (g_iSavedMeleeDurability[client] <= 0)
        return false;

    float elapsed = GetGameTime() - g_fSavedMeleeTime[client];
    if (elapsed > window)
        return false;

    char identity[MELEE_ID_SIZE];
    GetMeleeIdentity(weapon, identity, sizeof(identity));

    if (identity[0] == '\0')
        return false;

    if (!StrEqual(identity, g_sSavedMeleeIdentity[client], false))
        return false;

    g_iDurability[weapon] = g_iSavedMeleeDurability[client];
    g_iMaxDurability[weapon] = g_iSavedMeleeMaxDurability[client];

    if (g_hDebug.BoolValue)
    {
        PrintToServer(
            "[MeleeDurability] restored durability after character switch melee recreate: client=%N identity=%s durability=%d/%d melee_elapsed=%.3f character_elapsed=%.3f",
            client,
            identity,
            g_iDurability[weapon],
            g_iMaxDurability[weapon],
            elapsed,
            characterElapsed
        );
    }

    return true;
}

void GetMeleeIdentity(int weapon, char[] output, int size)
{
    output[0] = '\0';

    if (!IsValidMeleeWeapon(weapon))
        return;

    char scriptName[64];
    scriptName[0] = '\0';

    if (HasEntProp(weapon, Prop_Data, "m_strMapSetScriptName"))
    {
        GetEntPropString(
            weapon,
            Prop_Data,
            "m_strMapSetScriptName",
            scriptName,
            sizeof(scriptName)
        );

        TrimString(scriptName);
    }

    if (scriptName[0] != '\0')
    {
        Format(output, size, "script:%s", scriptName);
        return;
    }

    char model[PLATFORM_MAX_PATH];
    model[0] = '\0';

    if (HasEntProp(weapon, Prop_Data, "m_ModelName"))
    {
        GetEntPropString(
            weapon,
            Prop_Data,
            "m_ModelName",
            model,
            sizeof(model)
        );

        TrimString(model);
    }

    if (model[0] != '\0')
    {
        Format(output, size, "model:%s", model);
        return;
    }

    strcopy(output, size, "class:weapon_melee");
}

void GetMeleeName(int weapon, char[] output, int size)
{
    output[0] = '\0';

    if (!IsValidMeleeWeapon(weapon))
    {
        strcopy(output, size, "melee");
        return;
    }

    GetEntPropString(
        weapon,
        Prop_Data,
        "m_strMapSetScriptName",
        output,
        size
    );

    if (output[0] != '\0')
        return;

    char model[128];
    GetEntPropString(
        weapon,
        Prop_Data,
        "m_ModelName",
        model,
        sizeof(model)
    );

    if (StrContains(model, "fireaxe", false) != -1)
        strcopy(output, size, "fireaxe");
    else if (StrContains(model, "tonfa", false) != -1)
        strcopy(output, size, "tonfa");
    else if (StrContains(model, "machete", false) != -1)
        strcopy(output, size, "machete");
    else if (StrContains(model, "katana", false) != -1)
        strcopy(output, size, "katana");
    else if (StrContains(model, "knife", false) != -1)
        strcopy(output, size, "knife");
    else if (StrContains(model, "crowbar", false) != -1)
        strcopy(output, size, "crowbar");
    else
        strcopy(output, size, "melee");
}

void DebugInfectedHurt(Event event, int attacker, int activeWeapon, int dmgType)
{
    if (!g_hDebug.BoolValue)
        return;

    char weaponName[64];
    event.GetString("weapon", weaponName, sizeof(weaponName));

    int entityid = event.GetInt("entityid");
    int amount = event.GetInt("amount");

    char meleeName[64];
    GetMeleeName(activeWeapon, meleeName, sizeof(meleeName));

    PrintToServer(
        "[MeleeDurability] infected_hurt attacker=%N entity=%d weapon=%s melee=%s amount=%d type=%d",
        attacker,
        entityid,
        weaponName,
        meleeName,
        amount,
        dmgType
    );
}

void DebugCommonDamage(int victim, int attacker, int activeWeapon, int inflictor, float damage, int dmgType)
{
    if (!g_hDebug.BoolValue)
        return;

    char inflictorClass[64];
    inflictorClass[0] = '\0';

    if (inflictor > 0 && inflictor < MAX_ENTS && IsValidEntity(inflictor))
    {
        GetEntityClassname(inflictor, inflictorClass, sizeof(inflictorClass));
    }
    else
    {
        strcopy(inflictorClass, sizeof(inflictorClass), "invalid");
    }

    char meleeName[64];
    GetMeleeName(activeWeapon, meleeName, sizeof(meleeName));

    PrintToServer(
        "[MeleeDurability] OnTakeDamage common=%d attacker=%N melee=%s inflictor=%d/%s damage=%.1f type=%d recent=%.3f",
        victim,
        attacker,
        meleeName,
        inflictor,
        inflictorClass,
        damage,
        dmgType,
        GetGameTime() - g_fLastMeleeSwing[attacker]
    );
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleStarted = true;
}

public void Event_FinaleEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleStarted = false;
}

bool IsValidHuman(int client)
{
    if (client <= 0 || client > MaxClients)
        return false;

    if (!IsClientInGame(client))
        return false;

    if (!IsPlayerAlive(client))
        return false;

    if (GetClientTeam(client) != 2)
        return false;

    if (IsFakeClient(client))
        return false;

    return true;
}

bool IsTank(int client)
{
    if (client <= 0 || client > MaxClients)
        return false;

    if (!IsClientInGame(client))
        return false;

    if (GetClientTeam(client) != 3)
        return false;

    return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}
