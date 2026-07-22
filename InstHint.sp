#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define DeathTime 15.0

public Plugin myinfo = 
{
	name = "Ping Menu",
	author = "Tuan - Thanks BHaType for helping me.",
	description = "Danh dau 1 vi tri nao day trong map",
	version = "0.0",
	url = "SDKCall"
};

Menu g_hMain;
ConVar cCooldown;
float g_flTime[MAXPLAYERS + 1];
int Lasttarget[MAXPLAYERS + 1];
int Lastinstruc[MAXPLAYERS + 1];

static const char g_szText[][] =
{
	"Go here!",
	"Defense this station!",
	"Clear this way!",
	"Dangerous",
	"Pipebomb here!",
	"Vomitjar here!",
	"Molotov here!",
	"Adrenaline here!",
	"Pills here!",
	"Medkit here!",
	"Defibrillator here!",
	"Ammo here!"
};

public void OnPluginStart()
{
	g_hMain = new Menu(VMainHandler);
	g_hMain.AddItem("icon_run", "Go here!");
	g_hMain.AddItem("icon_shield", "Defense this station!");
	g_hMain.AddItem("icon_alert", "Clear this way!");
	g_hMain.AddItem("icon_skull", "Dangerous!");
	g_hMain.AddItem("icon_equip_pipebomb", "Pipebomb here!");
	g_hMain.AddItem("icon_interact", "Vomitjar here!");
	g_hMain.AddItem("icon_equip_molotov", "Molotov here!");
	g_hMain.AddItem("icon_adrenaline", "Adrenaline here!");
	g_hMain.AddItem("icon_equip_pills", "Pills here!");
	g_hMain.AddItem("icon_medkit", "Medkit here!");
	g_hMain.AddItem("icon_defibrillator", "Defibrillator here!");
	g_hMain.AddItem("icon_ammo", "Ammo here!");
	g_hMain.SetTitle("-Look and press the button to call a ping-");
	
	cCooldown = CreateConVar("sm_hint_cooldown", "1.0", "Cooldown", 0); ///// Thời gian delay
	AutoExecConfig(true, "l4d2_hint");
	RegConsoleCmd("sm_hint", cHint);
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_flTime[i] = 0.0;
		Lasttarget[i] = 0;
		Lastinstruc[i] = 0;
	}	
}

public Action cHint (int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	g_hMain.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int VMainHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		g_hMain.Display(client, MENU_TIME_FOREVER);
		
		if (GetGameTime() - g_flTime[client] < cCooldown.FloatValue)
		{
			PrintToChat(client, "\x04Cooldown \x03%.2f", cCooldown.FloatValue - (GetGameTime() - g_flTime[client]));
			return;
		}
		
		static int iFixaw;
		iFixaw++;
		g_flTime[client] = GetGameTime();
		
		char szMenuItem[24], szTemp[64], szParent[36];
		menu.GetItem(index, szMenuItem, sizeof szMenuItem);

		float vOrigin[3], vAngles[3];
			
		GetClientEyeAngles(client, vAngles);
		GetClientEyePosition(client, vOrigin);
			
		Handle TraceRay = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter, client);
			
		if (TR_DidHit(TraceRay))
			TR_GetEndPosition(vOrigin, TraceRay);
			
		vOrigin[2] += 25.0;
		delete TraceRay;

		Format(szTemp, sizeof szTemp, "%i_name", client * iFixaw);
		
		CreateTarget(vOrigin, szTemp, szParent,client);
		CreateInstructorHint(vOrigin, szTemp, szMenuItem, g_szText[index],client);
		PrintToChatAll("\x03[\x04%N\x03] - \x05%s", client, g_szText[index]);
	}
}

public bool TraceFilter (int entity, int mask, int client)
{
	if (entity == client)
		return false;
	return true;
}

int CreateTarget(float vOrigin[3], const char[] name, const char[] parent, int client)
{
	if(IsValidEdict(Lasttarget[client]) && IsValidEntity(Lasttarget[client]))
	{
		char class[64];
		GetEntityClassname(Lasttarget[client], class, sizeof(class));
		if(StrEqual(class, "info_target_instructor_hint"))
		{RemoveEdict(Lasttarget[client]);}
		Lasttarget[client] = 0;
	}
	int entity = CreateEntityByName("info_target_instructor_hint");
	Lasttarget[client] = entity;
	DispatchKeyValue(entity, "parentname", parent);
	DispatchKeyValue(entity, "targetname", name);
	DispatchSpawn(entity);
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	
	char szBuffer[36];
	Format(szBuffer, sizeof szBuffer, "OnUser1 !self:Kill::%f:-1", DeathTime);

	SetVariantString(szBuffer); 
	AcceptEntityInput(entity, "AddOutput"); 
	AcceptEntityInput(entity, "FireUser1");
	
	return entity;
}

int CreateInstructorHint(float vOrigin[3], const char[] target, const char[] icon_name, const char[] text,int client)
{
	if(IsValidEdict(Lastinstruc[client]) && IsValidEntity(Lastinstruc[client]))
	{
		char class[64];
		GetEntityClassname(Lastinstruc[client], class, sizeof(class));
		if(StrEqual(class, "env_instructor_hint"))
		{RemoveEdict(Lastinstruc[client]);}
		Lastinstruc[client] = 0;
	}
	int entity = CreateEntityByName("env_instructor_hint");
	char szBuffer[36];
	Format(szBuffer, sizeof szBuffer, "%f", DeathTime);
	DispatchKeyValue(entity, "hint_timeout", szBuffer);   //////////////// thời gian hint kéo dài được
	DispatchKeyValue(entity, "hint_allow_nodraw_target", "1");
	DispatchKeyValue(entity, "hint_target", target);
	DispatchKeyValue(entity, "hint_range", "99999");
	DispatchKeyValue(entity, "hint_auto_start", "1");
	DispatchKeyValue(entity, "hint_forcecaption", "1");
	DispatchKeyValue(entity, "hint_color", "121 194 33");  ////// màu
	DispatchKeyValue(entity, "hint_icon_onscreen", icon_name);
	DispatchKeyValue(entity, "hint_instance_type", "1");  ///////// hiện nhiều hint
	DispatchKeyValue(entity, "hint_caption", text);
	DispatchSpawn(entity);
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "ShowHint");
	
	Format(szBuffer, sizeof szBuffer, "OnUser1 !self:Kill::%f:-1", DeathTime);

	SetVariantString(szBuffer); 
	AcceptEntityInput(entity, "AddOutput"); 
	AcceptEntityInput(entity, "FireUser1");
}