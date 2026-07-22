#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
    name = "Vocalize Cooldown",
    author = "TBK Duy",
    description = "Add delay when using vocalize",
    version = "1.0"
};

float g_fLastUse[MAXPLAYERS + 1];
ConVar g_hCooldown;

public void OnPluginStart()
{
    g_hCooldown = CreateConVar(
        "sm_vocalize_cooldown",
        "5.0",
        "Cooldown vocalize in seconds",
        _,
        true, 0.0,
        true, 60.0
    );

    AutoExecConfig(true, "vocalize_cooldown");

    AddCommandListener(Command_Vocalize, "vocalize");
}

public void OnMapStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_fLastUse[i] = 0.0;
    }
}

public void OnClientPutInServer(int client)
{
    g_fLastUse[client] = 0.0;
}

public Action Command_Vocalize(int client, const char[] command, int argc)
{
    if (client <= 0 || !IsClientInGame(client))
        return Plugin_Continue;

    // Admin can use vocalize freely
    if (CheckCommandAccess(client, "admin_vocalize", ADMFLAG_GENERIC))
        return Plugin_Continue;

    float cooldown = g_hCooldown.FloatValue;
    float currentTime = GetGameTime();

    if (g_fLastUse[client] > currentTime)
    {
        g_fLastUse[client] = 0.0;
    }

    if (currentTime - g_fLastUse[client] < cooldown)
    {
        float timeLeft = cooldown - (currentTime - g_fLastUse[client]);
        //PrintToChat(client, "[Vocalize] Wait %.1f seconds to use vocalize!", timeLeft);
        return Plugin_Handled;
    }

    g_fLastUse[client] = currentTime;
    return Plugin_Continue;
}