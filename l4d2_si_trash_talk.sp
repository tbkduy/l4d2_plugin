#pragma semicolon 1
#pragma newdecls required 

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =  
{ 
    name = "[L4D2] SI Bot Trash Talk", 
    author = "TBK Duy", 
    description = "When SI bot incap an player, they will chat something", 
    version = "1.0", 
    url = "None" 
}; 

public void OnPluginStart()
{
	HookEvent("player_incapacitated", Event_PlayerIncapped);
}

public void Event_PlayerIncapped( Event event, const char[] sName, bool bDontBroadcast )
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && attacker > 0 && attacker <= MaxClients && GetClientTeam(attacker) == 3)
	{
		switch(GetRandomInt(1, 13)) 
		{
			case 1: 
			{
				FakeClientCommand(attacker, "say Con Gà =))");
			} 
			case 2: 
			{
				FakeClientCommand(attacker, "say Vấn Đề Kĩ Năng =))");
			}
			case 3: 
			{
				FakeClientCommand(attacker, "say Non =))");
			} 
			case 4: 
			{
				FakeClientCommand(attacker, "say Tưởng Thế Nào =))");
			} 
			case 5: 
			{
				FakeClientCommand(attacker, "say Hết Cứu =))");
			}
			case 6: 
			{
				FakeClientCommand(attacker, "say Múa Cho Lắm Vào =))");
			} 
			case 7: 
			{
				FakeClientCommand(attacker, "say Ngu Người =))");
			} 
			case 8: 
			{
				FakeClientCommand(attacker, "say Chạy Đâu Con Sâu =))");
			} 
			case 9: 
			{
				FakeClientCommand(attacker, "say Làm Gì Có Tuổi =))");
			} 
			case 10: 
			{
				FakeClientCommand(attacker, "say Cụp Cái Pha Xuống =))");
			}
			case 11: 
			{
				FakeClientCommand(attacker, "say Bố Láo Bố Lếu =))");
			}
			case 12: 
			{
				FakeClientCommand(attacker, "say Vớ Va Vớ Vẩn =))");
			}
			case 13: 
			{
				FakeClientCommand(attacker, "say ez =))");
			} 
		}
	}
	
}
