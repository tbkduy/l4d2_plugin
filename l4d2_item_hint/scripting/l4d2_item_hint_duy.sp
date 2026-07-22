#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

ConVar CvarFindRadius, g_hColorGlowRange, g_hCvarColor, g_hGlowTimer, g_hCoolDown;
int g_iColorGlowRange, g_iCvarColor;
float g_fCoolDown, g_fGlowTimer;
float fCoolDownTime[MAXPLAYERS+1];

#define MAXENTITIES 2048
int g_iHintRef[MAXENTITIES];
int g_iHintTargetRef[MAXENTITIES];
int g_iModelIndex[MAXENTITIES] = 0;
Handle g_iModelTimer[MAXENTITIES];
Handle g_hUseEntity;
StringMap g_smModelToName;

bool g_bShuttingDown;
bool g_bSavedTargetName[MAXENTITIES];
char g_sOriginalTargetName[MAXENTITIES][64];
char g_sAssignedTargetName[MAXENTITIES][64];

public Plugin myinfo =
{
	name = "L4D2 Item hint",
	author = "BHaType, fdxx, HarryPotter, TBK Duy",
	description = "When using 'Look' in vocalize menu, print corresponding item to chat area and make item glow.",
	version = "0.6-stable-reload",
	url = "https://forums.alliedmods.net/showthread.php?t=333669"
};

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success; 
}

public void OnPluginStart()
{
	GameData hGameData = new GameData("l4d2_item_hint");
	if (hGameData != null)
	{
		int iOffset = hGameData.GetOffset("FindUseEntity");
		if (iOffset != -1)
		{
			//https://forums.alliedmods.net/showpost.php?p=2753773&postcount=2
			StartPrepSDKCall(SDKCall_Player);
			PrepSDKCall_SetVirtual(iOffset);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
			g_hUseEntity = EndPrepSDKCall();
		}
		else SetFailState("Failed to load offset");
	}
	else SetFailState("Failed to load l4d2_item_hint.txt file");
	delete hGameData;

	CvarFindRadius = FindConVar("player_use_radius");
	AddCommandListener(Vocalize_Listener, "vocalize");
	
	g_hCoolDown = CreateConVar(			"l4d2_item_hint_cooldown_time",	"1",	"Cold Down Time in seconds a player can use 'Look' item chat again.", FCVAR_NOTIFY, true, 0.0 );
	g_hGlowTimer = CreateConVar(		"l4d2_item_hint_glow_timer",	"50.0",	"Item Glow Time.", FCVAR_NOTIFY, true, 0.0 );
	g_hColorGlowRange = CreateConVar(	"l4d2_item_hint_glow_range",	"1000",	"Item Glow Range.", FCVAR_NOTIFY, true, 0.0 );
	g_hCvarColor = CreateConVar(		"l4d2_item_hint_glow_color",	"255 255 0",	"Item Glow Color, Three values between 0-255 separated by spaces. (Empty = Disable Glow)", FCVAR_NOTIFY);
	AutoExecConfig(true, "l4d2_item_hint");

	GetCvars();
	g_hCoolDown.AddChangeHook(ConVarChanged_Cvars);
	g_hGlowTimer.AddChangeHook(ConVarChanged_Cvars);
	g_hColorGlowRange.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_Round_End);
	HookEvent("map_transition", Event_Round_End); //戰役過關到下一關的時候 (沒有觸發round_end)
	HookEvent("mission_lost", Event_Round_End); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", Event_Round_End); //救援載具離開之時  (沒有觸發round_end)
	HookEvent("spawner_give_item", Event_SpawnerGiveItem);

	CreateStringMap();
	Clear();

	for (int entity = 0; entity < MAXENTITIES; entity++)
	{
		g_iModelIndex[entity] = INVALID_ENT_REFERENCE;
		g_iHintRef[entity] = INVALID_ENT_REFERENCE;
		g_iHintTargetRef[entity] = INVALID_ENT_REFERENCE;
	}

	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnPluginEnd()
{
	// Stop every timer first. Entity deletion can fire OnEntityDestroyed
	// immediately, so block that callback while the plugin is unloading.
	g_bShuttingDown = true;

	for (int entity = 1; entity < MAXENTITIES; entity++)
	{
		delete g_iModelTimer[entity];
	}

	RemoveItemGlow_Timer();
	delete g_smModelToName;
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCoolDown = g_hCoolDown.FloatValue;
	g_fGlowTimer = g_hGlowTimer.FloatValue;
	g_iColorGlowRange = g_hColorGlowRange.IntValue;

	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);
}

void CreateStringMap()
{
	g_smModelToName = new StringMap();

	//Case-sensitive
	g_smModelToName.SetString("models/w_models/weapons/w_eq_Medkit.mdl",				"First aid kit here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_defibrillator.mdl",			"Defibrillator here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_painpills.mdl",				"Pills here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_adrenaline.mdl",			"Adrenaline here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_bile_flask.mdl",			"Bile bomb here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_molotov.mdl",				"Molotov here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_pipebomb.mdl",				"Pipe bomb here!");
	g_smModelToName.SetString("models/w_models/Weapons/w_laser_sights.mdl",				"Laser sight here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_incendiary_ammopack.mdl",	"Incendiary pack here!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_explosive_ammopack.mdl",	"Explosive pack here!");
	g_smModelToName.SetString("models/props/terror/ammo_stack.mdl", 					"Ammo here!");
	g_smModelToName.SetString("models/props_unique/spawn_apartment/coffeeammo.mdl", 	"Ammo here!");
	g_smModelToName.SetString("models/props/de_prodigy/ammo_can_02.mdl", 				"Ammo here!");
	g_smModelToName.SetString("models/weapons/melee/w_chainsaw.mdl", 					"Chainsaw here!");
	g_smModelToName.SetString("models/w_models/weapons/w_pistol_B.mdl", 				"Pistol here!");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_eagle.mdl", 			"Magnum here!");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun.mdl", 					"Pump shotgun here!");
	g_smModelToName.SetString("models/w_models/weapons/w_pumpshotgun_A.mdl", 			"Chrome shotgun here!");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_uzi.mdl", 					"SMG here!");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_a.mdl", 					"SMG Silenced here!");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_mp5.mdl", 					"MP5 here!");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_m16a2.mdl", 				"M16 here!");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_sg552.mdl", 				"SG552 here!");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_ak47.mdl", 				"AK47 here!");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_rifle.mdl", 			"SCAR here!");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun_spas.mdl", 			"Spas shotgun here!");
	g_smModelToName.SetString("models/w_models/weapons/w_autoshot_m4super.mdl", 		"Auto shotgun here!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_mini14.mdl", 			"Hunting rifle here!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_military.mdl", 			"Military sniper here!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_scout.mdl", 			"Scout here!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_awp.mdl", 				"AWP here!");
	g_smModelToName.SetString("models/w_models/weapons/w_grenade_launcher.mdl", 		"Grenade launcher here!");
	g_smModelToName.SetString("models/w_models/weapons/w_m60.mdl", 						"M60 here!");
	g_smModelToName.SetString("models/props_junk/gascan001a.mdl", 						"Gas can here!");
	g_smModelToName.SetString("models/props_junk/explosive_box001.mdl", 				"Firework crate here!");
	g_smModelToName.SetString("models/props_junk/propanecanister001a.mdl", 				"Propane tank here!");
	g_smModelToName.SetString("models/props_equipment/oxygentank01.mdl", 				"Oxygen tank here!");
	g_smModelToName.SetString("models/props_junk/gnome.mdl", 							"Gnome here!");
	g_smModelToName.SetString("models/w_models/weapons/w_cola.mdl", 					"Cola here!");
	//g_smModelToName.SetString("models/w_models/weapons/50cal.mdl",						"Mountgun here!");
	//g_smModelToName.SetString("models/w_models/weapons/w_minigun.mdl", 					"Minigun here!");
	g_smModelToName.SetString("models/props/terror/exploding_ammo.mdl", 				"Explosive ammo here!");
	g_smModelToName.SetString("models/props/terror/incendiary_ammo.mdl", 				"Incendiary ammo here!");
	g_smModelToName.SetString("models/w_models/weapons/w_knife_t.mdl", 					"Knife here!");
	g_smModelToName.SetString("models/weapons/melee/w_bat.mdl", 						"Baseball bat here!");
	g_smModelToName.SetString("models/weapons/melee/w_cricket_bat.mdl", 				"Cricket bat here!");
	g_smModelToName.SetString("models/weapons/melee/w_crowbar.mdl", 					"Crowbar here!");
	g_smModelToName.SetString("models/weapons/melee/w_electric_guitar.mdl", 			"Guitar here!");
	g_smModelToName.SetString("models/weapons/melee/w_fireaxe.mdl", 					"Axe here!");
	g_smModelToName.SetString("models/weapons/melee/w_frying_pan.mdl", 					"Frying pan here!");
	g_smModelToName.SetString("models/weapons/melee/w_katana.mdl", 						"Katana here!");
	g_smModelToName.SetString("models/weapons/melee/w_machete.mdl", 					"Machete here!");
	g_smModelToName.SetString("models/weapons/melee/w_tonfa.mdl", 						"Nightstick here!");
	g_smModelToName.SetString("models/weapons/melee/w_golfclub.mdl", 					"Golf club here!");
	g_smModelToName.SetString("models/weapons/melee/w_pitchfork.mdl", 					"Pitckfork here!");
	g_smModelToName.SetString("models/weapons/melee/w_shovel.mdl", 						"Shovel here!");
	g_smModelToName.SetString("models/props_doors/checkpoint_door_02.mdl", 				"Saferoom here!");
}

bool g_bConfigLoaded;
public void OnConfigsExecuted()
{
    g_bConfigLoaded = true;
}

public void OnMapEnd()
{
	g_bShuttingDown = true;
	RemoveItemGlow_Timer();
	g_bConfigLoaded = false;
	g_bShuttingDown = false;
}

public void OnClientPutInServer(int client)
{
	Clear(client);
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnWeaponEquipPost(int client, int weapon)
{
	if (!IsValidEntity(weapon))
		return;

	RemoveEntityModelGlow(weapon);
	RemoveEntityHint(weapon);
	
	delete g_iModelTimer[weapon];
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	g_bShuttingDown = false;
	Clear();
	
	return Plugin_Continue;
}

public Action Event_Round_End(Event event, const char[] name, bool dontBroadcast)
{
	RemoveItemGlow_Timer();
	
	return Plugin_Continue;
}

public void Event_SpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("spawner");
	int count = GetEntProp(entity, Prop_Data, "m_itemCount");

	if(count <= 1)
	{
		RemoveEntityModelGlow(entity);
		RemoveEntityHint(entity);
		delete g_iModelTimer[entity];
	}
}

public Action Vocalize_Listener(int client, const char[] command, int argc)
{
	bool bGlow = false;
	if (IsRealSur(client))
	{
		static char sCmdString[32];
		if (GetCmdArgString(sCmdString, sizeof(sCmdString)) > 1)
		{
			if ((strncmp(sCmdString, "smartlook #", 11, false) == 0) && (GetEngineTime() > fCoolDownTime[client])) 
			{
				//char sClassName[64];
				static int iEntity;
				iEntity = GetUseEntity(client, CvarFindRadius.FloatValue);						
				//GetEntityClassname(iEntity, sClassName, sizeof(sClassName));
			
				if (IsValidEntityIndex(iEntity) && IsValidEntity(iEntity))
				{
					if (HasEntProp(iEntity, Prop_Data, "m_ModelName"))
					{
						static char sEntModelName[PLATFORM_MAX_PATH];
						if (GetEntPropString(iEntity, Prop_Data, "m_ModelName", sEntModelName, sizeof(sEntModelName)) > 1)
						{
							static char sItemName[64];
							static char classname[64];
							GetEntityClassname(iEntity, classname, sizeof(classname));
							if (g_smModelToName.GetString(sEntModelName, sItemName, sizeof(sItemName)))
							{
								//PrintToChatAll("\x01(\x04Vocalize\x01) \x05%N\x01: %s", client, sItemName);
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}
							else if (StrContains(sEntModelName, "/melee/") != -1) //custom 3rd party melee weapon
							{
								strcopy(sItemName, sizeof(sItemName), "Custom melee weapon here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}
							else if (StrContains(classname, "first_aid_kit") != -1)
							{
								strcopy(sItemName, sizeof(sItemName), "First aid kit here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}	
							else if (StrContains(classname, "pistol") != -1)
							{
								strcopy(sItemName, sizeof(sItemName), "Pistol here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}	
							else if (StrContains(classname, "laser") != -1) 
							{
								strcopy(sItemName, sizeof(sItemName), "Laser sights here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}
							else if (StrContains(classname, "ammo") != -1) 
							{
								strcopy(sItemName, sizeof(sItemName), "Ammo here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}
							else if (StrContains(sEntModelName, "checkpoint_door") != -1) 
							{
								strcopy(sItemName, sizeof(sItemName), "Saferoom here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}
							else if (StrContains(classname, "checkpoint") != -1) 
							{
								strcopy(sItemName, sizeof(sItemName), "Saferoom here!");
								FakeClientCommand(client, "say %s", sItemName);
								fCoolDownTime[client] = GetEngineTime() + g_fCoolDown;
								bGlow = true;
							}

							if(bGlow && g_iCvarColor != 0) 
							{
								RemoveEntityModelGlow(iEntity);
								delete g_iModelTimer[iEntity];
															
								// Spawn dynamic prop entity
								int entity = CreateEntityByName("prop_dynamic_override");
								if (entity == -1) return Plugin_Continue;													
								
								// Set new fake model
								DispatchKeyValue(entity, "model", sEntModelName);
								DispatchSpawn(entity);

								float vPos[3], vAng[3];
								GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vPos);
								GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vAng);
								TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

								// Set outline glow color
								//int r = GetRandomInt(0, 255);
								//int g = GetRandomInt(0, 255);
								//int b = GetRandomInt(0, 255);

								//int randomColor = (r << 8) | (g << 16) | b;
								SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
								SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
								SetEntProp(entity, Prop_Send, "m_nGlowRange", g_iColorGlowRange);
								SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
								SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarColor);
								AcceptEntityInput(entity, "StartGlowing");
								
								if (StrContains(sEntModelName, "checkpoint_door") != -1 && StrContains(classname, "checkpoint") != -1)
								{
									CreateInstructorHint(iEntity, "icon_door", sItemName, "1000", "10", "255 255 255");
								}
								else if (StrContains(classname, "laser") != -1)
								{
									CreateInstructorHint(iEntity, "icon_laser_sight", sItemName, "1000", "10", "255 255 255");
								}
								else if (StrContains(classname, "ammo") != -1)
								{
									CreateInstructorHint(iEntity, "icon_ammo", sItemName, "1000", "10", "255 255 255");
								}
								else 
								{
									CreateInstructorHint(iEntity, "icon_interact", sItemName, "1000", "10", "255 255 255");
								}

								// Set model invisible
								SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
								SetEntityRenderColor(entity, 0, 0, 0, 0);

								// Set model attach to item, and always synchronize
								SetVariantString("!activator");
								AcceptEntityInput(entity, "SetParent", iEntity);								

								//g_iModelIndex[iEntity] = entity;
								g_iModelIndex[iEntity] = EntIndexToEntRef(entity);

								delete g_iModelTimer[iEntity];
								g_iModelTimer[iEntity] = CreateTimer(g_fGlowTimer, CoolDown, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

int CreateInstructorHint(int target, const char[] icon, const char[] text, const char[] range, const char[] time, const char[] color)
{
	if (!IsValidEntityIndex(target) || !IsValidEntity(target))
		return INVALID_ENT_REFERENCE;

	// Remove only the previous env_instructor_hint for this item.
	RemoveEntityHint(target);

	// Use one stable name for each entity. Re-pinging the same item must reuse
	// the same hint_name so hint_instance_type 1 suppresses duplicate hints.
	// EntRef includes the entity serial, therefore a later entity reusing the
	// same index will still receive a different name.
	char targetName[64];
	Format(targetName, sizeof(targetName), "item_hint_%d", EntIndexToEntRef(target));

	// Preserve the map/plugin targetname before assigning our own.
	// Only the first hint for this entity stores the original value.
	if (!g_bSavedTargetName[target])
	{
		g_sOriginalTargetName[target][0] = '\0';
		if (HasEntProp(target, Prop_Data, "m_iName"))
			GetEntPropString(target, Prop_Data, "m_iName", g_sOriginalTargetName[target], sizeof(g_sOriginalTargetName[]));

		g_bSavedTargetName[target] = true;
	}

	strcopy(g_sAssignedTargetName[target], sizeof(g_sAssignedTargetName[]), targetName);
	DispatchKeyValue(target, "targetname", targetName);

	int hint = CreateEntityByName("env_instructor_hint");
	if (hint == -1 || !IsValidEntity(hint))
		return INVALID_ENT_REFERENCE;

	DispatchKeyValue(hint, "hint_target", targetName);
	DispatchKeyValue(hint, "hint_name", targetName);
	DispatchKeyValue(hint, "hint_timeout", time);
	DispatchKeyValue(hint, "hint_range", range);
	DispatchKeyValue(hint, "hint_allow_nodraw_target", "1");
	DispatchKeyValue(hint, "hint_auto_start", "1");
	DispatchKeyValue(hint, "hint_color", color);
	DispatchKeyValue(hint, "hint_icon_offscreen", icon);
	DispatchKeyValue(hint, "hint_instance_type", "1");
	DispatchKeyValue(hint, "hint_icon_onscreen", icon);
	DispatchKeyValue(hint, "hint_caption", text);
	DispatchKeyValue(hint, "hint_static", "0");
	DispatchKeyValue(hint, "hint_nooffscreen", "0");
	DispatchKeyValue(hint, "hint_forcecaption", "1");
	DispatchKeyValue(hint, "hint_display_limit", "0");
	DispatchKeyValue(hint, "hint_suppress_rest", "1");
	DispatchSpawn(hint);
	ActivateEntity(hint);
	AcceptEntityInput(hint, "ShowHint");

	g_iHintRef[target] = EntIndexToEntRef(hint);
	g_iHintTargetRef[target] = INVALID_ENT_REFERENCE;

	DataPack pack = new DataPack();
	pack.WriteCell(EntIndexToEntRef(hint));
	pack.WriteCell(INVALID_ENT_REFERENCE);
	pack.WriteCell(EntIndexToEntRef(target));
	CreateTimer(StringToFloat(time), Timer_KillHint, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);

	return g_iHintRef[target];
}

public Action Timer_KillHint(Handle timer, DataPack pack)
{
	pack.Reset();
	int hintRef = pack.ReadCell();
	int anchorRef = pack.ReadCell();
	int targetRef = pack.ReadCell();

	int hint = EntRefToEntIndex(hintRef);
	if (hint != INVALID_ENT_REFERENCE && IsValidEntity(hint))
		RemoveEntity(hint);

	int anchor = EntRefToEntIndex(anchorRef);
	if (anchor != INVALID_ENT_REFERENCE && IsValidEntity(anchor))
		RemoveEntity(anchor);

	int target = EntRefToEntIndex(targetRef);
	if (IsValidEntityIndex(target))
	{
		if (g_iHintRef[target] == hintRef)
		{
			g_iHintRef[target] = INVALID_ENT_REFERENCE;
			RestoreTargetName(target);
		}

		if (g_iHintTargetRef[target] == anchorRef)
			g_iHintTargetRef[target] = INVALID_ENT_REFERENCE;
	}

	return Plugin_Stop;
}

public Action CoolDown(Handle timer, int entityRef)
{
	int entity = EntRefToEntIndex(entityRef);
	if (entity == INVALID_ENT_REFERENCE || !IsValidEntityIndex(entity))
		return Plugin_Stop;

	// Ignore an obsolete timer that belonged to an earlier ping.
	if (g_iModelTimer[entity] != timer)
		return Plugin_Stop;

	g_iModelTimer[entity] = null;
	RemoveEntityModelGlow(entity);
	return Plugin_Stop;
}

void RemoveEntityModelGlow(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;

	int glowRef = g_iModelIndex[entity];
	g_iModelIndex[entity] = INVALID_ENT_REFERENCE;

	int glow = EntRefToEntIndex(glowRef);
	if (glow != INVALID_ENT_REFERENCE && IsValidEntity(glow))
		RemoveEntity(glow);
}

void RestoreTargetName(int entity)
{
	if (!IsValidEntityIndex(entity) || !IsValidEntity(entity) || !g_bSavedTargetName[entity])
		return;

	char currentName[64];
	currentName[0] = '\0';
	if (HasEntProp(entity, Prop_Data, "m_iName"))
		GetEntPropString(entity, Prop_Data, "m_iName", currentName, sizeof(currentName));

	// Do not overwrite a targetname that another plugin changed after us.
	if (StrEqual(currentName, g_sAssignedTargetName[entity]))
		DispatchKeyValue(entity, "targetname", g_sOriginalTargetName[entity]);

	g_bSavedTargetName[entity] = false;
	g_sOriginalTargetName[entity][0] = '\0';
	g_sAssignedTargetName[entity][0] = '\0';
}

void RemoveEntityHint(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;

	int hintRef = g_iHintRef[entity];
	int anchorRef = g_iHintTargetRef[entity];
	g_iHintRef[entity] = INVALID_ENT_REFERENCE;
	g_iHintTargetRef[entity] = INVALID_ENT_REFERENCE;

	int hint = EntRefToEntIndex(hintRef);
	if (hint != INVALID_ENT_REFERENCE && IsValidEntity(hint))
		RemoveEntity(hint);

	int anchor = EntRefToEntIndex(anchorRef);
	if (anchor != INVALID_ENT_REFERENCE && IsValidEntity(anchor))
		RemoveEntity(anchor);

	RestoreTargetName(entity);
}

int GetUseEntity(int client, float fRadius)
{
	return SDKCall(g_hUseEntity, client, fRadius, 0.0, 0.0, 0, 0);
}

bool IsRealSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client));
}

void Clear(int client = -1)
{
	if(client == -1)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			fCoolDownTime[i] = 0.0;
		}
	}	
	else
	{
		fCoolDownTime[client] = 0.0;
	}
}

int GetColor(char[] sTemp)
{
	if( StrEqual(sTemp, "") )
		return 0;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 )
		return true;
	return false;
}

public void OnEntityDestroyed(int entity)
{
	if (!g_bConfigLoaded || g_bShuttingDown || !IsValidEntityIndex(entity))
		return;

	// Never kill another entity from inside this engine destruction callback.
	// Capture the linked entrefs, clear our state immediately, then clean them
	// on the next frame. This avoids recursive OnEntityDestroyed chains.
	int glowRef = g_iModelIndex[entity];
	int hintRef = g_iHintRef[entity];
	int anchorRef = g_iHintTargetRef[entity];

	g_iModelIndex[entity] = INVALID_ENT_REFERENCE;
	g_iHintRef[entity] = INVALID_ENT_REFERENCE;
	g_iHintTargetRef[entity] = INVALID_ENT_REFERENCE;
	delete g_iModelTimer[entity];

	g_bSavedTargetName[entity] = false;
	g_sOriginalTargetName[entity][0] = '\0';
	g_sAssignedTargetName[entity][0] = '\0';

	if (glowRef == INVALID_ENT_REFERENCE && hintRef == INVALID_ENT_REFERENCE && anchorRef == INVALID_ENT_REFERENCE)
		return;

	DataPack pack = new DataPack();
	pack.WriteCell(glowRef);
	pack.WriteCell(hintRef);
	pack.WriteCell(anchorRef);
	RequestFrame(Frame_CleanupDestroyedItem, pack);
}

public void Frame_CleanupDestroyedItem(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int glowRef = pack.ReadCell();
	int hintRef = pack.ReadCell();
	int anchorRef = pack.ReadCell();
	delete pack;

	if (g_bShuttingDown)
		return;

	int glow = EntRefToEntIndex(glowRef);
	if (glow != INVALID_ENT_REFERENCE && IsValidEntity(glow))
		RemoveEntity(glow);

	int hint = EntRefToEntIndex(hintRef);
	if (hint != INVALID_ENT_REFERENCE && IsValidEntity(hint))
		RemoveEntity(hint);

	int anchor = EntRefToEntIndex(anchorRef);
	if (anchor != INVALID_ENT_REFERENCE && IsValidEntity(anchor))
		RemoveEntity(anchor);
}

void RemoveItemGlow_Timer()
{
	for (int entity = 1; entity < MAXENTITIES; entity++)
	{
		delete g_iModelTimer[entity];
	}

	for (int entity = 1; entity < MAXENTITIES; entity++)
	{
		RemoveEntityModelGlow(entity);
		RemoveEntityHint(entity);
	}
}

bool IsValidEntityIndex(int entity)
{
	return (entity > MaxClients && entity < MAXENTITIES && entity < GetMaxEntities());
}
