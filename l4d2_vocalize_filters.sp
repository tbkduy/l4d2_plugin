#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo =
{
    name = "L4D2 Vocalize Filters",
    author = "TBK Duy",
    description = "Block specific vocalize commands for specific player SteamIDs",
    version = "1.0"
};

char g_sBlockedVocalize[][] =
{
	"AskWhat",
    "PlayerNo",
	//"PlayerLaugh",
	"PlayerTaunt",
	"PlayerHurrah",
	"PlayerNegative",
    "ConceptBlock035",
    "ConceptBlock049",
    "ConceptBlock050",
    "ConceptBlock051",
    "WorldC6M1_WeddingWarn03c",
    "DLC1_C6M2_SafeRoomConvo16b",
};

// These people cannot use these vocalize
char g_sBlockedSteamIDs[][] =
{
    "STEAM_1:1:451693571",
    //"STEAM_1:1:987654321",
};

public void OnPluginStart()
{
    AddCommandListener(Command_Vocalize, "vocalize");
}

public Action Command_Vocalize(int client, const char[] command, int argc)
{
    if (client <= 0 || !IsClientInGame(client))
        return Plugin_Continue;

    if (argc < 1)
        return Plugin_Continue;

	//If you want to block everyone from using these vocalize, delete these 2 code under 
    if (!IsBlockedClient(client))
        return Plugin_Continue;

    char sArg[128];
    GetCmdArg(1, sArg, sizeof(sArg));

    for (int i = 0; i < sizeof(g_sBlockedVocalize); i++)
    {
        if (StrEqual(sArg, g_sBlockedVocalize[i], false))
        {
            PrintToServer(
                "[Vocalize Block] Blocked %N from using vocalize: %s",
                client,
                sArg
            );
			PrintHintText(client, "Stop doing that!");
			SDKHooks_TakeDamage(client, client, client, float(1));
            
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

bool IsBlockedClient(int client)
{
    if (IsFakeClient(client))
        return false;

    // If no SteamID => block all players.
    if (sizeof(g_sBlockedSteamIDs) == 0)
        return true;

    char sSteamID[32];

    if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true))
        return false;

    for (int i = 0; i < sizeof(g_sBlockedSteamIDs); i++)
    {
        if (StrEqual(sSteamID, g_sBlockedSteamIDs[i], false))
            return true;
    }

    return false;
}