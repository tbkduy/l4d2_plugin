#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "L4D2 Force Custom Content",
    author = "TBK Duy",
    description = "Kick players who disable custom content downloads",
    version = "1.0",
    url = ""
};

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client))
    {
        return;
    }

    QueryClientConVar(
        client,
        "cl_downloadfilter",
        ConVarQueryFinished:Query_DownloadFilter
    );
}

public void Query_DownloadFilter(
    QueryCookie cookie,
    int client,
    ConVarQueryResult result,
    const char[] cvarName,
    const char[] cvarValue
)
{
    if (!IsClientInGame(client))
    {
        return;
    }

    // Query failed
    if (result != ConVarQuery_Okay)
    {
        KickClient(
            client,
            "Please enable this option:\nOptions -> Multiplayer -> Custom Server Content -> Allow All"
        );

        return;
    }

    // Player blocked downloads
    if (StrEqual(cvarValue, "none", false) || StrEqual(cvarValue, "nosounds", false))
    {
        KickClient(
            client,
            "Please enable this option:\nOptions -> Multiplayer -> Custom Server Content -> Allow All"
        );

        return;
    }
}