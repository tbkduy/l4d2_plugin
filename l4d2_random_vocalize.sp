#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VOICE_COOLDOWN_FALL     1.0
#define VOICE_COOLDOWN_CHARGER  1.0
#define VOICE_COOLDOWN_SHOVE    1.0
#define VOICE_DEATH_DELAY       0.1

float g_fNextFallVoice[MAXPLAYERS + 1];
float g_fNextChargerVoice[MAXPLAYERS + 1];
float g_fNextShoveVoice[MAXPLAYERS + 1];

static const char g_sDeathSounds[][] =
{
	// 0 - Nick
	"player/survivor/voice/gambler/deathscream07.wav",

	// 1 - Rochelle
	"player/survivor/voice/producer/deathscream01.wav",

	// 2 - Coach
	"player/survivor/voice/coach/deathscream02.wav",

	// 3 - Ellis
	"player/survivor/voice/mechanic/deathscream05.wav",

	// 4 - Bill
	"player/survivor/voice/namvet/deathscream06.wav",

	// 5 - Zoey
	"player/survivor/voice/teengirl/deathscream03.wav",

	// 6 - Francis
	"player/survivor/voice/biker/deathscream07.wav",

	// 7 - Louis
	"player/survivor/voice/manager/deathscream06.wav"
};

static const char g_sCoachFall[][] =
{
	"scenes/coach/hurtmajor01.vcd",
	"scenes/coach/hurtmajor02.vcd",
	"scenes/coach/hurtmajor03.vcd",
	"scenes/coach/hurtmajor04.vcd",
	"scenes/coach/hurtmajor05.vcd",
	"scenes/coach/hurtmajor06.vcd",
	"scenes/coach/hurtmajor07.vcd",
	"scenes/coach/hurtmajor08.vcd",
	"scenes/coach/hurtmajor09.vcd",
	"scenes/coach/hurtmajor10.vcd",
	"scenes/coach/hurtmajor11.vcd"
};

static const char g_sNickFall[][] =
{
	"scenes/gambler/hurtmajor01.vcd",
	"scenes/gambler/hurtmajor02.vcd",
	"scenes/gambler/hurtmajor03.vcd",
	"scenes/gambler/hurtmajor04.vcd",
	"scenes/gambler/hurtmajor05.vcd",
	"scenes/gambler/hurtmajor06.vcd",
	"scenes/gambler/hurtmajor07.vcd",
	"scenes/gambler/hurtmajor08.vcd",
	"scenes/gambler/hurtmajor09.vcd",
	"scenes/gambler/hurtmajor10.vcd",
	"scenes/gambler/hurtmajor11.vcd"
};

static const char g_sRochelleFall[][] =
{
	"scenes/producer/hurtcritical03.vcd",
	"scenes/producer/hurtmajor01.vcd",
	"scenes/producer/hurtmajor02.vcd",
	"scenes/producer/hurtmajor03.vcd",
	"scenes/producer/hurtmajor04.vcd"
};

static const char g_sEllisFall[][] =
{
	"scenes/mechanic/hurtcritical05.vcd",
	"scenes/mechanic/hurtmajor01.vcd",
	"scenes/mechanic/hurtmajor02.vcd",
	"scenes/mechanic/hurtmajor03.vcd",
	"scenes/mechanic/hurtmajor04.vcd",
	"scenes/mechanic/hurtmajor05.vcd",
	"scenes/mechanic/hurtmajor06.vcd"
};

static const char g_sCoachCharger[][] =
{
	"scenes/coach/deathscream01.vcd",
	"scenes/coach/deathscream03.vcd",
	"scenes/coach/deathscream05.vcd",
	"scenes/coach/deathscream06.vcd",
	"scenes/coach/grabbedbycharger01.vcd"
};

static const char g_sNickCharger[][] =
{
	"scenes/gambler/ledgehangfall01.vcd",
	"scenes/gambler/ledgehangfall02.vcd",
	"scenes/gambler/ledgehangfall03.vcd",
	"scenes/gambler/grabbedbycharger01.vcd"
};

static const char g_sRochelleCharger[][] =
{
	"scenes/producer/ledgehangfall01.vcd",
	"scenes/producer/ledgehangfall02.vcd",
	"scenes/producer/incapacitatedinjury02.vcd",
	"scenes/producer/grabbedbycharger01.vcd",
	"scenes/producer/chargerrunningwithplayer03.vcd"
};

static const char g_sEllisCharger[][] =
{
	"scenes/mechanic/ledgehangfall01.vcd",
	"scenes/mechanic/ledgehangfall02.vcd",
	"scenes/mechanic/ledgehangfall03.vcd",
	"scenes/mechanic/grabbedbycharger01.vcd"
};

static const char g_sBillCharger[][] =
{
    "scenes/namvet/fall01.vcd",
    "scenes/namvet/fall02.vcd",
    "scenes/namvet/fall03.vcd"
};

static const char g_sZoeyCharger[][] =
{
    "scenes/teengirl/fall01.vcd",
    "scenes/teengirl/fall02.vcd",
    "scenes/teengirl/fall03.vcd"
};

static const char g_sFrancisCharger[][] =
{
    "scenes/biker/fall01.vcd",
    "scenes/biker/fall02.vcd",
    "scenes/biker/fall03.vcd"
};

static const char g_sLouisCharger[][] =
{
    "scenes/manager/fall01.vcd",
    "scenes/manager/fall02.vcd",
    "scenes/manager/fall03.vcd"
};

static const char g_sBillFall[][] =
{
	"scenes/namvet/hurtmajor01.vcd",
	"scenes/namvet/hurtmajor02.vcd",
	"scenes/namvet/hurtmajor03.vcd",
	"scenes/namvet/hurtmajor04.vcd",
	"scenes/namvet/hurtmajor05.vcd"
};

static const char g_sZoeyFall[][] =
{
	"scenes/teengirl/hurtcritical01.vcd",
	"scenes/teengirl/hurtcritical02.vcd",
	"scenes/teengirl/hurtmajor01.vcd",
	"scenes/teengirl/hurtmajor02.vcd",
	"scenes/teengirl/hurtmajor03.vcd"
};

static const char g_sFrancisFall[][] =
{
	"scenes/biker/hurtcritical01.vcd",
	"scenes/biker/hurtcritical02.vcd",
	"scenes/biker/hurtmajor01.vcd",
	"scenes/biker/hurtmajor02.vcd",
	"scenes/biker/hurtmajor03.vcd"
};

static const char g_sLouisFall[][] =
{
	"scenes/manager/hurtcritical01.vcd",
	"scenes/manager/hurtcritical02.vcd",
	"scenes/manager/hurtmajor01.vcd",
	"scenes/manager/hurtmajor02.vcd",
	"scenes/manager/hurtmajor03.vcd"
};

static const char g_sCoachShove[][] =
{
	"scenes/coach/meleeswing08.vcd",
	"scenes/coach/meleeswing10.vcd",
	"scenes/coach/meleeswing11.vcd",
	"scenes/coach/meleeswing17.vcd",
	"scenes/coach/meleeswing18.vcd",
	"scenes/coach/meleeswing20.vcd"
};

static const char g_sNickShove[][] =
{
	"scenes/gambler/meleeswing08.vcd",
	"scenes/gambler/meleeswing09.vcd",
	"scenes/gambler/meleeswing10.vcd",
	"scenes/gambler/meleeswing11.vcd",
	"scenes/gambler/meleeswing12.vcd",
	"scenes/gambler/meleeswing13.vcd"
};

static const char g_sRochelleShove[][] =
{
	"scenes/producer/meleeswing02.vcd",
	"scenes/producer/meleeswing03.vcd",
	"scenes/producer/meleeswing04.vcd",
	"scenes/producer/meleeswing05.vcd",
	"scenes/producer/meleeswing06.vcd",
	"scenes/producer/meleeswing07.vcd"
};

static const char g_sEllisShove[][] =
{
	"scenes/mechanic/meleeswing03.vcd",
	"scenes/mechanic/meleeswing04.vcd",
	"scenes/mechanic/meleeswing05.vcd",
	"scenes/mechanic/meleeswing06.vcd",
	"scenes/mechanic/meleeswing07.vcd"
};

public Plugin myinfo =
{
	name = "[L4D2] Survivor Voice System",
	author = "TBK Duy",
	description = "Death scream + random vocalize system",
	version = "1.0",
	url = "None"
};

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("charger_carry_start", Event_ChargerCarry);
	//HookEvent("player_shoved", Event_PlayerShoved);
}

public void OnMapStart()
{
	for (int i = 0; i < sizeof(g_sDeathSounds); i++)
	{
		PrecacheSound(g_sDeathSounds[i], true);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidSurvivor(client))
		return;

	CreateTimer(VOICE_DEATH_DELAY, Timer_PlayDeathSound, GetClientUserId(client));
}

public Action Timer_PlayDeathSound(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	int character = GetSurvivorCharacter(client);

	if (character < 0 || character >= sizeof(g_sDeathSounds))
		return Plugin_Stop;

	EmitSoundToAll(g_sDeathSounds[character], client, SNDCHAN_VOICE);
	return Plugin_Stop;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidAliveSurvivor(client))
        return;

    // Only real fall damage
    if (event.GetInt("type") != 32)
        return;

    int damage = event.GetInt("dmg_health");

    if (damage <= 0)
        return;

    if (GetGameTime() < g_fNextFallVoice[client])
        return;

    g_fNextFallVoice[client] = GetGameTime() + VOICE_COOLDOWN_FALL;

    int character = GetSurvivorCharacter(client);

    switch (character)
    {
        case 0: EmitRandomScene(client, g_sNickFall, sizeof(g_sNickFall));
        case 1: EmitRandomScene(client, g_sRochelleFall, sizeof(g_sRochelleFall));
        case 2: EmitRandomScene(client, g_sCoachFall, sizeof(g_sCoachFall));
        case 3: EmitRandomScene(client, g_sEllisFall, sizeof(g_sEllisFall));
        case 4: EmitRandomScene(client, g_sBillFall, sizeof(g_sBillFall));
        case 5: EmitRandomScene(client, g_sZoeyFall, sizeof(g_sZoeyFall));
        case 6: EmitRandomScene(client, g_sFrancisFall, sizeof(g_sFrancisFall));
        case 7: EmitRandomScene(client, g_sLouisFall, sizeof(g_sLouisFall));
    }
}

public void Event_ChargerCarry(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidAliveSurvivor(client))
		return;

	if (GetGameTime() < g_fNextChargerVoice[client])
		return;

	g_fNextChargerVoice[client] = GetGameTime() + VOICE_COOLDOWN_CHARGER;

	int character = GetSurvivorCharacter(client);

	switch (character)
	{
		case 0: EmitRandomScene(client, g_sNickCharger, sizeof(g_sNickCharger));
		case 1: EmitRandomScene(client, g_sRochelleCharger, sizeof(g_sRochelleCharger));
		case 2: EmitRandomScene(client, g_sCoachCharger, sizeof(g_sCoachCharger));
		case 3: EmitRandomScene(client, g_sEllisCharger, sizeof(g_sEllisCharger));
		case 4: EmitRandomScene(client, g_sBillCharger, sizeof(g_sBillCharger));
		case 5: EmitRandomScene(client, g_sZoeyCharger, sizeof(g_sZoeyCharger));
		case 6: EmitRandomScene(client, g_sFrancisCharger, sizeof(g_sFrancisCharger));
		case 7: EmitRandomScene(client, g_sLouisCharger, sizeof(g_sLouisCharger));
	}
}

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidAliveSurvivor(attacker))
		return;

	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	if (GetGameTime() < g_fNextShoveVoice[attacker])
		return;

	g_fNextShoveVoice[attacker] = GetGameTime() + VOICE_COOLDOWN_SHOVE;

	int character = GetSurvivorCharacter(attacker);

	switch (character)
	{
		case 0: EmitRandomScene(attacker, g_sNickShove, sizeof(g_sNickShove));
		case 1: EmitRandomScene(attacker, g_sRochelleShove, sizeof(g_sRochelleShove));
		case 2: EmitRandomScene(attacker, g_sCoachShove, sizeof(g_sCoachShove));
		case 3: EmitRandomScene(attacker, g_sEllisShove, sizeof(g_sEllisShove));
	}
}

stock bool IsValidSurvivor(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (GetClientTeam(client) != 2)
		return false;

	return true;
}

stock bool IsValidAliveSurvivor(int client)
{
	if (!IsValidSurvivor(client))
		return false;

	if (!IsPlayerAlive(client))
		return false;

	return true;
}

stock int GetSurvivorCharacter(int client)
{
	int character = GetEntProp(client, Prop_Send, "m_survivorCharacter");

	// Fix custom campaigns / survivor set mismatch
	char model[128];
	GetClientModel(client, model, sizeof(model));

	if (StrEqual(model, "models/survivors/survivor_gambler.mdl"))
		return 0;
	if (StrEqual(model, "models/survivors/survivor_producer.mdl"))
		return 1;
	if (StrEqual(model, "models/survivors/survivor_coach.mdl"))
		return 2;
	if (StrEqual(model, "models/survivors/survivor_mechanic.mdl"))
		return 3;
	if (StrEqual(model, "models/survivors/survivor_namvet.mdl"))
		return 4;
	if (StrEqual(model, "models/survivors/survivor_teenangst.mdl"))
		return 5;
	if (StrEqual(model, "models/survivors/survivor_biker.mdl"))
		return 6;
	if (StrEqual(model, "models/survivors/survivor_manager.mdl"))
		return 7;

	return character;
}

stock void EmitRandomScene(int client, const char[][] scenes, int count)
{
	if (!IsValidAliveSurvivor(client))
		return;

	int index = GetRandomInt(0, count - 1);
	PlayScene(client, scenes[index]);
}

stock void PlayScene(int client, const char[] scene)
{
	int entity = CreateEntityByName("instanced_scripted_scene");

	if (entity == -1)
		return;

	DispatchKeyValue(entity, "SceneFile", scene);
	DispatchSpawn(entity);

	SetEntPropEnt(entity, Prop_Data, "m_hOwner", client);

	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start");

	HookSingleEntityOutput(entity, "OnCompletion", OnSceneCompletion, true);

	CreateTimer(10.0, Timer_RemoveScene, EntIndexToEntRef(entity));
}

public void OnSceneCompletion(const char[] output, int caller, int activator, float delay)
{
	if (caller > 0 && IsValidEntity(caller))
	{
		RemoveEntity(caller);
	}
}

public Action Timer_RemoveScene(Handle timer, any ref)
{
	int entity = EntRefToEntIndex(ref);

	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		RemoveEntity(entity);
	}

	return Plugin_Stop;
}
