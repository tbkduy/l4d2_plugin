#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
    name = "[L4D2] Chainsaw Reload",
    author = "TBK Duy",
    description = "Reload chainsaw when run out of gas",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    HookEvent("weapon_fire", Event_WeaponFire);
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon == -1)
        return;

    char weaponName[32];
    GetEntityClassname(weapon, weaponName, sizeof(weaponName));
    
    if (StrEqual(weaponName, "weapon_chainsaw"))
    {
        int ammo = GetEntProp(weapon, Prop_Send, "m_iClip1");
        
        if (ammo <= 2)
        {
            RemovePlayerItem(client, weapon);
            AcceptEntityInput(weapon, "Kill");
            
            int newChainsaw = GivePlayerItem(client, "weapon_chainsaw");
            
            if (newChainsaw != -1)
            {
                EquipPlayerWeapon(client, newChainsaw);

                float currentTime = GetGameTime();
                SetEntPropFloat(client, Prop_Send, "m_flNextAttack", currentTime + 0.8);
                SetEntPropFloat(newChainsaw, Prop_Send, "m_flNextPrimaryAttack", currentTime + 0.8);
            }
        }
    }
}