#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

#define PLUGIN_VERSION "3.0"

public Plugin myinfo =
{
    name = "Lifesteal Secondary",
    author = "arclightarchery + TBK Duy",
    description = "Melee killing common infected grants temporary health",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar g_hHealAmount;
ConVar g_hDecayRate;

public void OnPluginStart()
{
    CreateConVar(
        "l4d_lifesteal_melee_version",
        PLUGIN_VERSION,
        "Version",
        FCVAR_NOTIFY|FCVAR_DONTRECORD
    );

    g_hHealAmount = CreateConVar(
        "l4d_lifesteal_melee_amount",
        "1",
        "Temp HP gained per kill",
        FCVAR_NOTIFY,
        true,
        0.0
    );

    g_hDecayRate = FindConVar("pain_pills_decay_rate");
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "infected"))
    {
        SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawned);
    }
}

public void OnInfectedSpawned(int entity)
{
    if (IsValidEntity(entity))
    {
        SDKHook(entity, SDKHook_OnTakeDamageAlive, OnInfectedTakeDamage);
    }
}

public Action OnInfectedTakeDamage(
    int victim,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damagetype
)
{
    if (!IsValidSurvivor(attacker))
        return Plugin_Continue;

    if (!IsValidEntity(inflictor))
        return Plugin_Continue;

    char classname[64];
    GetEdictClassname(inflictor, classname, sizeof(classname));

    if (!StrEqual(classname, "weapon_melee") && !StrEqual(classname, "weapon_chainsaw"))
        return Plugin_Continue;

    int hp = GetEntProp(victim, Prop_Data, "m_iHealth");

    if (float(hp) > damage)
        return Plugin_Continue;

    AddTempHealth(attacker, float(g_hHealAmount.IntValue));

    return Plugin_Continue;
}

void AddTempHealth(int client, float amount)
{
    int realHealth = GetClientHealth(client);

    float tempHealth = GetTempHealth(client);

    if (float(realHealth) + tempHealth >= 100.0)
        return;

    tempHealth += amount;

    if (float(realHealth) + tempHealth > 100.0)
    {
        tempHealth = 100.0 - float(realHealth);
    }

    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", tempHealth);
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

float GetTempHealth(int client)
{
    float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");

    if (buffer <= 0.0)
        return 0.0;

    float bufferTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");

    buffer -= (GetGameTime() - bufferTime) * g_hDecayRate.FloatValue;

    if (buffer < 0.0)
        buffer = 0.0;

    return buffer;
}

bool IsValidSurvivor(int client)
{
    if (client < 1 || client > MaxClients)
        return false;

    if (!IsClientInGame(client))
        return false;

    if (!IsPlayerAlive(client))
        return false;

    if (GetClientTeam(client) != 2)
        return false;

    return true;
}