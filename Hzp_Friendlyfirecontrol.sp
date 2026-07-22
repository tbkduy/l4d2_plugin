#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_VERSION 		"1.0"
Handle Vipmember = INVALID_HANDLE;
Handle Crazymember = INVALID_HANDLE;
new String:sAllowedWeapons[64][32];

public Plugin myinfo =
{
	name = "Friendly fire control, remove bot bullet shake",
	author = "Hoangzp",
	description = "Mô tả",
	version = PLUGIN_VERSION,
	url = "Link forum tải :))"
}
ConVar Friendlyfire;
ConVar BotFriendlyfire;
ConVar CrazyReflect;
public OnPluginStart()
{
	Friendlyfire = CreateConVar("zp_friendlyfire", "1", "Friendlyfire (Def 1)", FCVAR_NONE, true, 0.0, true, 1.0);
	BotFriendlyfire = CreateConVar("zp_botfriendlyfire", "1", "BotFriendlyfire (Def 0)", FCVAR_NONE, true, 0.0, true, 1.0);
	Vipmember = CreateConVar("zp_noffperson", "",
	"[ALLOWED WEAPONS] Use ';' to add more then one like: 'STEAM_1:1:219118361;STEAM_1:0:442193132'", FCVAR_NONE );
	Crazymember = CreateConVar("zp_crazyperson", "",
	"[ALLOWED WEAPONS] Use ';' to add more then one like: 'STEAM_1:1:219118361;STEAM_1:0:442193132'", FCVAR_NONE );
	CrazyReflect = CreateConVar("zp_crazyReflect", "0", "Friendlyfire (Def 0)", FCVAR_NONE, true, 0.0, true, 1.0);
	HookEvent("player_spawn", SI_Spawn);	
}
public Action SI_Spawn(Handle event, const char[]name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(GetClientTeam(client) == 3)
	{
		SDKUnhook(client, SDKHook_TraceAttack, PreThink);
	}
}	
stock bool:IsVipMember(client)
{
	if(!IsFakeClient(client))
	{
		char sCurrentName[32];
		decl String:sConVarAllowedWeapons[256];
		GetConVarString(Vipmember, sConVarAllowedWeapons, sizeof(sConVarAllowedWeapons));
		new iWeaponNumbers = ReplaceString(sConVarAllowedWeapons, sizeof(sConVarAllowedWeapons), ";", ";", false);
		ExplodeString(sConVarAllowedWeapons, ";", sAllowedWeapons, iWeaponNumbers + 1, 32);
		GetClientAuthId(client, AuthId_Steam2, sCurrentName, sizeof(sCurrentName));
		for(new i = 0; i <= iWeaponNumbers; i++)
		{
			if(StrEqual(sAllowedWeapons[i], sCurrentName, false))
			{
				return true;
			}		
		}
	}
	return false;
}
stock bool:IsCrazyMember(client)
{
	if(!IsFakeClient(client))
	{
		char sCurrentName[32];
		decl String:sConVarAllowedWeapons[256];
		GetConVarString(Crazymember, sConVarAllowedWeapons, sizeof(sConVarAllowedWeapons));
		new iWeaponNumbers = ReplaceString(sConVarAllowedWeapons, sizeof(sConVarAllowedWeapons), ";", ";", false);
		ExplodeString(sConVarAllowedWeapons, ";", sAllowedWeapons, iWeaponNumbers + 1, 32);
		GetClientAuthId(client, AuthId_Steam2, sCurrentName, sizeof(sCurrentName));
		for(new i = 0; i <= iWeaponNumbers; i++)
		{
			if(StrEqual(sAllowedWeapons[i], "STEAM_1:1:219118361", false))
			{
				continue;
			}
			if(StrEqual(sAllowedWeapons[i], sCurrentName, false))
			{
				return true;
			}
		}
	}
	return false;
}
public OnMapStart()
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if(IsClientConnected(target) && IsClientInGame(target))
		{
			SDKUnhook(target, SDKHook_TraceAttack, PreThink);
			SDKHook(target, SDKHook_TraceAttack, PreThink);
		}
	}
}	
public OnClientPutInServer(client)
{
	SDKUnhook(client, SDKHook_TraceAttack, PreThink);
	SDKHook(client, SDKHook_TraceAttack, PreThink);
}
public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity) || !IsValidEdict(entity))
	{
		return;
	}
}
public Action PreThink(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if( !(0 < victim < MaxClients ) || !(0 < attacker < MaxClients)) 
	{
		return Plugin_Continue;
	}
	if( !(IsValidEntity(victim) || IsValidEdict(victim)) || !(IsValidEntity(attacker) || IsValidEdict(attacker)))
	{
		return Plugin_Continue;
	}	
	if((!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 9)
	{
		return Plugin_Continue;
	}
	if((!victim || !IsClientInGame(victim) || !IsPlayerAlive(victim) || GetClientTeam(victim) !=2) && GetEntProp(victim, Prop_Send, "m_zombieClass") != 9)
	{
		return Plugin_Continue;
	}
	char steam_ip_vic[32];
	char steam_ip_att[32];
	GetClientAuthId(attacker, AuthId_Steam2, steam_ip_att, sizeof(steam_ip_att));
	GetClientAuthId(victim, AuthId_Steam2, steam_ip_vic, sizeof(steam_ip_vic));
	if(IsVipMember(attacker) || IsVipMember(victim))
	{
		if(damagetype & 2 || damagetype & DMG_SLASH || damagetype & DMG_CLUB)
		return Plugin_Handled;
	}
	if(IsCrazyMember(attacker))
	{
		if(GetConVarBool(CrazyReflect))
		{
			float pos1[3];
			char dam[128];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos1);
			FormatEx(dam, sizeof(dam), "%i",RoundFloat(damage));
			PushCommonInfected(attacker, attacker, pos1, dam, "2");
		}
		return Plugin_Handled;
	}	
	if(!IsFakeClient(attacker) && !IsFakeClient(victim) && (IsClientLagger(attacker) || IsClientLagger(victim)))	
	{
		if(damagetype & 2)
		return Plugin_Handled;
	}	
	if(!GetConVarBool(Friendlyfire))
	{
		if((damagetype & 2 || damagetype & 4 || damagetype & 128))
		return Plugin_Handled;
	}
	if(IsFakeClient(attacker) && damagetype & 2 && !GetConVarBool(FindConVar("sb_friendlyfire")))
	{
		return Plugin_Handled;
	}
	if(IsFakeClient(victim) && !GetConVarBool(BotFriendlyfire))
	{
		return Plugin_Handled;
	}
	if(IsClientLagger(attacker))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
stock IsClientLagger(int client)
{
	if (!IsFakeClient(client))
	{
		if((GetClientAvgLatency(client, NetFlow_Outgoing) * 1024.0) >= 150.0)
		{
			return true;
		}
	}
	return false;
}
public Action PushCommonInfected(int client, int target, float vPos[3],char dam[128], char damtype[128])
{
	int entity = CreateEntityByName("point_hurt");
	DispatchKeyValue(target, "targetname", "silvershot");
	DispatchKeyValue(entity, "DamageTarget", "silvershot");
	DispatchKeyValue(entity, "Damage", dam);
	DispatchKeyValue(entity, "DamageType", damtype);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Hurt", client, client);
	RemoveEdict(entity);
}