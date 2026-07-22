#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

char SOUND_PISTOL[] = ")weapons/pistol/gunfire/pistol_fire.wav";

public Plugin myinfo = 
{
    name = "[L4D/2] AutoPistolSoundFix",
    author = "Lux, TBK Duy",
    description = "Fixes the sound bug when you use Timocops l4dautopistols",
    version = "1.0",
    url = ""
}

public void OnPluginStart()
{
    HookEvent("weapon_fire", Event_WeaponFire);
}

public void OnMapStart()
{    
    PrefetchSound(SOUND_PISTOL);
    PrecacheSound(SOUND_PISTOL, true);   
} 

public void Event_WeaponFire(Handle event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));	
    int activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(!IsFakeClient(client))
	{
		float PingRange = (GetClientAvgLatency(client, NetFlow_Outgoing) * 1024.0);
		if (!IsPlayerAlive(client) || GetClientTeam(client) != 2 || IsInIncapped(client)) return;
		if (!IsValidEntity(activeweapon)) return;
		char weaponname[64];
		GetEntityClassname(activeweapon, weaponname, sizeof(weaponname));
		if (strcmp(weaponname, "weapon_pistol") != 0) return; 
		if (GetEntProp(activeweapon, Prop_Send, "m_isDualWielding") && PingRange > 60.0)
		{
			EmitSoundToAll(SOUND_PISTOL, client, SNDCHAN_WEAPON);
		}
		if (!GetEntProp(activeweapon, Prop_Send, "m_isDualWielding") && PingRange > 180.0)
		{
			EmitSoundToAll(SOUND_PISTOL, client, SNDCHAN_WEAPON);
		}
	}
}  

stock bool IsInIncapped(int client)
{
    return (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0);
} 