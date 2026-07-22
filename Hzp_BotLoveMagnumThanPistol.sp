#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_VERSION 		"1.0"

public Plugin:myinfo =
{
	name = "Bot Prefer Magnum than pistol",
	author = "Hoangzp",
	description = "Mô tả",
	version = PLUGIN_VERSION,
	url = "Link forum tải :))"
}
public void OnClientPutInServer(int iClient)
{
	SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}
public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidEdict(i) && IsValidEntity(i) )
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
				SDKHook(i, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
			}
		}
	}
}

public void OnClientDisconnect(int iClient)
{
	SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}
public void Hook_OnPostThinkPost(int iClient)
{
	if(!IsPlayerAlive(iClient) || GetClientTeam(iClient) != 2 || !IsFakeClient(iClient) ) 
		return;
	
	if(GetPlayerWeaponSlot(iClient, 1) == -1)
		return;
		
	char classname[48];
	GetEntityClassname(GetPlayerWeaponSlot(iClient, 1), classname, sizeof(classname));
	if(!StrEqual(classname, "weapon_pistol")){
		return;
	}
	else if( IsClientInGame(iClient) && GetClientTeam(iClient) == 2 && IsPlayerAlive(iClient) && IsFakeClient(iClient) && !IsReviving(iClient) && !IsIncapped(iClient)){
	for( int index = 1; index < GetEntityCount(); index++ ){
		if(IsValidEdict(index))
		{
		GetEntityClassname(index, classname, sizeof(classname));
		if(StrEqual(classname, "weapon_pistol_magnum") || StrEqual(classname, "weapon_pistol_magnum_spawn") || StrEqual(classname, "weapon_spawn"))
		{	
			GetEntPropString(index, Prop_Data, "m_ModelName", classname, sizeof(classname));
			if( StrEqual(classname, "models/w_models/weapons/w_desert_eagle.mdl") && GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") == -1)
			{
				float vBot[3], vPos[3];
				GetClientEyePosition(iClient, vBot);
				GetEntPropVector(index, Prop_Send, "m_vecOrigin", vPos);
				if(GetVectorDistance(vBot, vPos) <= 250)
				{
					if( IsVisibleTo(vBot, vPos) )
					{
						AcceptEntityInput(index, "Use", iClient);
						break;
					}
				}
			}
		}
		}
	}
	}
}
bool IsVisibleTo(float position[3], float targetposition[3])
{
	static float vAngles[3], vLookAt[3];

	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	static Handle trace;
	trace = TR_TraceRayFilterEx(position, vAngles, MASK_ALL, RayType_Infinite, _TraceFilter);

	static bool isVisible;
	isVisible = false;

	if( TR_DidHit(trace) )
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if( (GetVectorDistance(position, vStart, false) + 25.0 ) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
		}
	}
	delete trace;

	return isVisible;
}
public bool _TraceFilter(int entity, int contentsMask)
{
	if( entity <= MaxClients || !IsValidEntity(entity) )
		return false;
	return true;
}
stock bool IsReviving(int client)
{
	if( GetEntPropEnt(client, Prop_Send, "m_reviveOwner") > 0 )
		return true;
	return false;
}

stock bool IsIncapped(int client)
{
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0 )
		return true;
	return false;
}

