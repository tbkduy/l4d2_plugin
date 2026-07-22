#pragma semicolon 1
#pragma newdecls required

ConVar EnablePlugin;

public Plugin myinfo =
{
	name = "[L4D2] Vocalize Blocker",
	author = "TBK Duy",
	description = "Turn on/off vocalize commands usability",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	EnablePlugin = CreateConVar("l4d2_block_vocalize", "0", "Enable the Vocalize Blocker");
	AddCommandListener(vocalizeblock, "vocalize");
}

public Action vocalizeblock(int client, char[] command, int args)
{
	if (EnablePlugin.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Changed;
}