#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Melee Range
*	Author	:	SilverShot
*	Descrp	:	Adjustable melee range for each melee weapon.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=318958
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (03-Oct-2019)
	- Increased string size to fix the plugin not working. Thanks to "xZk" for reporting.

1.0 (02-Oct-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

int g_iFrameCount[MAXPLAYERS+1];
int g_FixRange;
Handle g_iStockRange;
Handle g_iStockRangeBot;


// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Melee Range++ for lag player",
	author = "SilverShot, Hoangzp",
	description = "Adjustable melee range for lag player.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318958"
}

public void OnPluginStart()
{
	HookEvent("weapon_fire", Event_WeaponFire);
	g_iStockRange =		CreateConVar(	"melee_rangefix",		"80",			"Default melee range.", FCVAR_NONE );
	g_iStockRangeBot =		CreateConVar(	"meleebot_rangefix",		"160",			"Melee range for bot and high ping player.", FCVAR_NONE );
	UnlockConsoleCommandAndConvar("melee_range");
	SetConVarInt(FindConVar("melee_range"), GetConVarInt(g_iStockRange));

}
// ====================================================================================================
//					CVARS
// ====================================================================================================

//					EVENTS
// ====================================================================================================
public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	char sTemp[16];
	event.GetString("weapon", sTemp, sizeof sTemp);

	if( (sTemp[0] == 'm' && sTemp[1] == 'e' && sTemp[2] == 'l') || (sTemp[0] == 'c' && sTemp[1] == 'h' && sTemp[2] == 'a') )
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if( client && IsClientInGame(client) )
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			//PrintToChatAll("%N- First-MeleeID %i",client, weapon);
			if( weapon != -1 )
			{
			//	if( !g_iFrameCount )
			//	{
					g_iFrameCount[client] = 0;
					if(!IsFakeClient(client))
					{
						float PingRange = (GetClientAvgLatency(client, NetFlow_Outgoing) * 1024.0);
						if(PingRange > 120.0)
						{
						//PrintToChatAll("%N- MeleePing %f",client, PingRange);
						//GetConVarInt(FindConVar("melee_range"))
						int A = GetConVarInt(g_iStockRange) + RoundFloat(PingRange/ 4.5) ; // + RoundFloat(PingRange*((GetClientAvgLatency(client, NetFlow_Outgoing) * 1024.0)/256) ) ;
						g_FixRange = A;
						SetConVarInt(FindConVar("melee_range"), A);
						//PrintToChatAll("%N- Meleerange %i",client, A);
						RequestFrame(OnNextFrame,client);
						}
						else{
						g_FixRange = GetConVarInt(g_iStockRange);
						SetConVarInt(FindConVar("melee_range"), g_FixRange);
						//PrintToChatAll("g_FixRange");
						RequestFrame(OnNextFrame,client);
						}
					}
					else if(IsFakeClient(client))
					{
						SetConVarInt(FindConVar("melee_range"), GetConVarInt(g_iStockRangeBot));
						g_FixRange = GetConVarInt(g_iStockRangeBot);
						RequestFrame(OnNextFrame,client);
					}
			//	}
			}
			RequestFrame(OnNextFrame,client);
		}
	}
}

public void OnNextFrame(int client)
{
	if( g_iFrameCount[client]++ < 21 ) // 5 frames.
	{
		SetConVarInt(FindConVar("melee_range"), g_FixRange);
		RequestFrame(OnNextFrame,client);
	} 
	else 
	{
		SetConVarInt(FindConVar("melee_range"), GetConVarInt(g_iStockRange));
		g_iFrameCount[client] = 0;
	}
//	PrintToChatAll("g_FixRange%i", g_FixRange);
}
void UnlockConsoleCommandAndConvar(char[] command)
{
    int flags = GetCommandFlags(command);
    if (flags != INVALID_FCVAR_FLAGS)
    {
        SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    }
    
    Handle cvar = FindConVar(command);
    if (cvar != INVALID_HANDLE)
    {
        flags = GetConVarFlags(cvar);
        SetConVarFlags(cvar, flags & ~FCVAR_CHEAT);
    }
}