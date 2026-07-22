#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name = "Replace Kit to Pills",
    author = "TBK Duy",
    version = "1.0"
};

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    CreateTimer(0.1, Timer_ReplaceItems);
    return Plugin_Continue;
}

public Action Timer_ReplaceItems(Handle timer) {
    char classname[64];
    for (int i = MaxClients + 1; i < GetEntityCount(); i++) {
        if (!IsValidEntity(i)) continue;

        GetEdictClassname(i, classname, sizeof(classname));
        
        if (StrEqual(classname, "weapon_first_aid_kit_spawn") || StrEqual(classname, "weapon_first_aid_kit")) {
            if (GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == -1) {
                ReplaceItem(i);
            }
        }
    }
    return Plugin_Stop;
}

void ReplaceItem(int entity) {
    float origin[3], angles[3];
    GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
    GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);

    char newItem[64];

    Format(newItem, sizeof(newItem), "weapon_pain_pills");

    char spawnItem[64];
    Format(spawnItem, sizeof(spawnItem), "%s_spawn", newItem);
    
    int newEnt = CreateEntityByName(spawnItem);

    if (newEnt == -1) {
        newEnt = CreateEntityByName(newItem);
    }

    if (newEnt != -1) {
        TeleportEntity(newEnt, origin, angles, NULL_VECTOR);
        DispatchSpawn(newEnt);
        
        if (StrContains(spawnItem, "_spawn") == -1) {
            SetEntityMoveType(newEnt, MOVETYPE_NONE);
        }
        
        AcceptEntityInput(entity, "Kill");
    }
}