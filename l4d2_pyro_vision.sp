#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Pyro vision",
	author = "Pé-de-mosca, TBK Duy",
	description = "",
	version = "3.0",
	url = ""
};

public void OnPluginStart()
{
	AddNormalSoundHook(SoundCallback);
}

public Action SoundCallback(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if ((entity > 0 && entity <= MaxClients && GetClientTeam(entity) == 3 && StrContains(sample, "tank", false) != -1) || (StrContains(sample, "witch", false) != -1 && entity > MaxClients && IsValidEdict(entity) && IsValidEntity(entity)) && channel == SNDCHAN_VOICE)
	{
		pitch = GetRandomInt(90, 180);
		flags |= SND_CHANGEPITCH;
		return Plugin_Changed;
	}
	else if (StrContains(sample, "laughter", false) != -1 && StrContains(sample, "producer", false) != -1)
	{
		pitch = GetRandomInt(100, 120);
		flags |= SND_CHANGEPITCH;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}