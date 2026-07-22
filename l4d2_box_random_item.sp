#include <sourcemod>
#include <sdktools>

bool isMapRunning;

public Plugin myinfo = 
{
	name = "[L4D2] Box Random Item",
	author = "Hoangzp, TBK Duy",
	description = "As title",
	version = "1.0",
	url = "Nah"
}

public OnPluginStart()
{
	RegAdminCmd("sm_box", box_spawn, ADMFLAG_ROOT);
	RegAdminCmd("sm_hop", box_spawn, ADMFLAG_ROOT);
}
 
public OnMapStart()
{
	isMapRunning = true;
	PrecacheModel("models/props_junk/wood_crate001a.mdl", true);
}

public OnMapEnd()
{
	isMapRunning = false;
}

public Action:box_spawn(client, args)
{
	float Look[3];
	GetLookPos(client, Look);
	new karobka = CreateEntityByName("prop_physics");
	if (karobka > MaxClients)
	{
		DispatchKeyValueVector(karobka, "origin", Look);
		DispatchKeyValue(karobka, "health", "10"); 
		SetEntityModel(karobka, "models/props_junk/wood_crate001a.mdl");
		DispatchSpawn(karobka);
	}
	return Plugin_Handled;
}
 
public OnEntityDestroyed(entity)
{
	if ( isMapRunning == false || IsServerProcessing()==false)
	{
		return;
	}
	if(!IsValidEdict(entity) ||  entity == -1){
		return;
	}
	new String:model_name[256];
	GetEntPropString(entity, Prop_Data, "m_ModelName", model_name, sizeof(model_name));
	if (StrEqual(model_name, "models/props_junk/wood_crate001a.mdl")
	|| StrEqual(model_name, "models/props_junk/wood_crate002a.mdl")
	|| StrEqual(model_name, "models/props_junk/cardboard_box04.mdl"))
	{
		float ent_pos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ent_pos)
		int item = GetItemIndex();
		DispatchSpawn(item);
		TeleportEntity(item, ent_pos, NULL_VECTOR, NULL_VECTOR);
	}
}

GetItemIndex()
{
	int item = -1;
	switch(GetRandomInt(1, 8)) 
	{
		case 1: 
		{
			item = CreateEntityByName("weapon_adrenaline");
		} 
		case 2: 
		{
			item = CreateEntityByName("weapon_first_aid_kit");
		}
		case 3: 
		{
			item = CreateEntityByName("weapon_defibrillator");
		} 
		case 4: 
		{
			item = CreateEntityByName("weapon_pain_pills");
		}
		case 5: 
		{
			item = CreateEntityByName("weapon_pipe_bomb");
		} 
		case 6: 
		{
			item = CreateEntityByName("weapon_molotov");
		}
		case 7: 
		{
			item = CreateEntityByName("weapon_upgradepack_explosive");
		} 
		case 8: 
		{
			item = CreateEntityByName("weapon_upgradepack_incendiary");
		}
		case 9: 
		{
			item = CreateEntityByName("weapon_pistol_magnum");
		}			
	}
	if(!IsValidEdict(item) || item == -1)
	{
		GetItemIndex();
	}
	return item;
}
 
stock GetLookPos(client, Float:v[3])
{
    decl Float:EyePosition[3], Float:EyeAngles[3], Handle:h_trace;
    GetClientEyePosition(client, EyePosition);
    GetClientEyeAngles(client, EyeAngles);
    h_trace = TR_TraceRayFilterEx(EyePosition, EyeAngles, MASK_SOLID, RayType_Infinite, GetLookPos_Filter, client);
    TR_GetEndPosition(v, h_trace);
    CloseHandle(h_trace);
}
 
public bool:GetLookPos_Filter(ent, mask, any:client)
{
    return client != ent;
} 