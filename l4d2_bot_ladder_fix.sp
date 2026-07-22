#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "[L4D2] Bot ladder fix",
	author = "Hoangzp",
	description = "As title",
	version = "1.0",
	url = "-"
}

public Action:OnPlayerRunCmd(client, &buttons, &impuls, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsFakeClient(client))
	{
		if(buttons != 0)
		{
			if(GetEntityMoveType(client) == MOVETYPE_LADDER)
			{
				float pos[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", pos);
				if(pos[2] == 0 && buttons & 8)
				{
					GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
					pos[2] += 50.5;
					TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR); 
				}
			}
		}
	}
}
