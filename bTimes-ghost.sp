#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] - Ghost",
	author = "blacky",
	description = "Shows a bot that replays the top times",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <smlib/weapons>
#include <smlib/entities>
#include <cstrike>
#include <bTimes-timer>

/*
enum
{
	GameType_CSS,
	GameType_CSGO
};

new g_GameType;
*/

new	String:g_sMapName[64],
	Handle:g_DB;

new 	Handle:g_hFrame[MAXPLAYERS + 1],
	bool:g_bUsedFrame[MAXPLAYERS + 1];

new 	Handle:g_hGhost[MAX_TYPES][MAX_STYLES],
	g_Ghost[MAX_TYPES][MAX_STYLES],
	g_GhostFrame[MAX_TYPES][MAX_STYLES],
	bool:g_GhostPaused[MAX_TYPES][MAX_STYLES],
	String:g_sGhost[MAX_TYPES][MAX_STYLES][48],
	g_GhostPlayerID[MAX_TYPES][MAX_STYLES],
	Float:g_fGhostTime[MAX_TYPES][MAX_STYLES],
	Float:g_fPauseTime[MAX_TYPES][MAX_STYLES],
	bool:g_bGhostLoadedOnce[MAX_TYPES][MAX_STYLES],
	bool:g_bGhostLoaded[MAX_TYPES][MAX_STYLES],
	bool:g_bReplayFileExists[MAX_TYPES][MAX_STYLES];
	
new 	Float:g_fStartTime[MAX_TYPES][MAX_STYLES];

// Cvars
new	Handle:g_hGhostStartPauseTime,
	Handle:g_hGhostEndPauseTime;

ConVar g_hBotQuota;

int g_iBotQuota;

Handle g_hCheckGhost;

public OnPluginStart()
{	
	/*
	decl String:sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));
	
	if(StrEqual(sGame, "cstrike"))
		g_GameType = GameType_CSS;
	else if(StrEqual(sGame, "csgo"))
		g_GameType = GameType_CSGO;
	else
		SetFailState("This timer does not support this game (%s)", sGame);
		*/
	
	// Connect to the database
	DB_Connect();
	
	g_hGhostStartPauseTime = CreateConVar("timer_ghoststartpause", "5.0", "How long the ghost will pause before starting its run.");
	g_hGhostEndPauseTime   = CreateConVar("timer_ghostendpause", "5.0", "How long the ghost will pause after it finishes its run.");
	
	AutoExecConfig(true, "ghost", "timer");

	// Create admin command that deletes the ghost
	RegAdminCmd("sm_deleteghost", SM_DeleteGhost, ADMFLAG_CHEATS, "Deletes the ghost.");
	
	g_hBotQuota = FindConVar("bot_quota");
	g_hBotQuota.Flags &= ~FCVAR_NOTIFY;
	
	new Handle:hBotDontShoot = FindConVar("bot_dont_shoot");
	SetConVarFlags(hBotDontShoot, GetConVarFlags(hBotDontShoot) & ~FCVAR_CHEAT);
	
	HookUserMessage(GetUserMessageId("SayText2"), UserMessageHook_SayText2, true);
	
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{	
	CreateNative("GetBotInfo", Native_GetBotInfo);
	
	RegPluginLibrary("ghost");
	
	return APLRes_Success;
}

public OnStylesLoaded()
{	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			// Don't create cvars for styles on bonus except normal style
			if(Style_CanUseReplay(Style, Type))
			{
				g_hGhost[Type][Style] = CreateArray(6);
			}
		}
	}
}

public Native_GetBotInfo(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if(!IsFakeClient(client))
		return false;
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				if(g_Ghost[Type][Style] == client)
				{
					SetNativeCellRef(2, Type);
					SetNativeCellRef(3, Style);
					
					return true;
				}
			}
		}
	}
	
	return false;
}

public OnMapStart()
{		
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				ClearArray(g_hGhost[Type][Style]);
				g_Ghost[Type][Style]  = 0;
				g_fGhostTime[Type][Style] = 0.0;
				g_GhostFrame[Type][Style] = 0;
				g_GhostPlayerID[Type][Style] = 0;
				g_bGhostLoaded[Type][Style] = false;
				
				decl String:sType[32], String:sStyle[32];
				GetTypeName(Type, sType, sizeof(sType), true);
				
				GetStyleName(Style, sStyle, sizeof(sStyle));
				
				if(Type == 1)
					FormatEx(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "Bonus %s - N/A", sStyle);
				else
					FormatEx(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "%s - N/A", sStyle);
			}
		}
	}
	
	// Get map name to use the database
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	// Check path to folder that holds all the ghost data
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes");
	if(!DirExists(sPath))
	{
		// Create ghost data directory if it doesn't exist
		CreateDirectory(sPath, 511);
	}
	
	ConVar bot_controllable = FindConVar("bot_controllable");
	
	if(bot_controllable != null)
	{
		bot_controllable.BoolValue = false;
	}
		
	// Timer to check ghost things such as clan tag
	g_hCheckGhost = CreateTimer(0.1, GhostCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnZonesLoaded()
{
	LoadGhost();
}

public OnConfigsExecuted()
{
	CalculateBotQuota();
}

public OnUseGhostChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CalculateBotQuota();
}

CalculateBotQuota()
{
	g_iBotQuota = 0;
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style<MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				g_iBotQuota++;
				
				if(!g_Ghost[Type][Style])
					ServerCommand("bot_add");
			}
			else if(g_Ghost[Type][Style])
				KickClient(g_Ghost[Type][Style]);
		}
	}
	
	new Handle:hBotQuota = FindConVar("bot_quota");
	new iBotQuota = GetConVarInt(hBotQuota);
	
	if(iBotQuota != g_iBotQuota)
		ServerCommand("bot_quota %d", g_iBotQuota);
	
	CloseHandle(hBotQuota);
}

public OnMapEnd()
{
	// Remove ghost to get a clean start next map
	ServerCommand("bot_kick all");
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			g_Ghost[Type][Style] = 0;
		}
	}
	
	if(g_hCheckGhost != INVALID_HANDLE)
		KillTimer(g_hCheckGhost);
}

public OnClientPutInServer(client)
{
	if(!IsFakeClient(client))
	{
		// Reset player recorded movement
		if(g_bUsedFrame[client] == false)
		{
			g_hFrame[client]     = CreateArray(6);
			g_bUsedFrame[client] = true;
		}
		else
		{
			ClearArray(g_hFrame[client]);
		}
	}
}

public OnEntityCreated(entity, const String:classname[])
{
    if (StrContains(classname, "func_button", false) != -1)
    {
        SDKHook(entity, SDKHook_Use, OnTrigger);
    }

    if (StrContains(classname, "trigger_", true) != -1 || StrContains(classname, "func_door", true) != -1)
    {
        SDKHook(entity, SDKHook_StartTouch, OnTrigger);
        SDKHook(entity, SDKHook_EndTouch, OnTrigger);
        SDKHook(entity, SDKHook_Touch, OnTrigger);
    }
}
 
public Action:OnTrigger(entity, other)
{
	if(0 < other <= MaxClients)
	{
		if(IsClientConnected(other))
		{
			if(IsFakeClient(other))
			{
				return Plugin_Handled;
			}
		}
	}
   
	return Plugin_Continue;
}

public OnPlayerIDLoaded(client)
{
	new PlayerID = GetPlayerID(client);
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				if(PlayerID == g_GhostPlayerID[Type][Style])
				{
					decl String:sTime[32];
					FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 1);
					
					decl String:sType[32], String:sStyle[32];
					GetTypeName(Type, sType, sizeof(sType), true);
				
					GetStyleName(Style, sStyle, sizeof(sStyle));
					
					if(Type == 1)
						FormatEx(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "Bonus %s - %s", sStyle, sTime);
					else
						FormatEx(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "%s - %s", sStyle, sTime);
				}
			}
		}
	}
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	// Find out if it's the bot added from another time
	if(IsFakeClient(client) && !IsClientSourceTV(client))
	{
		for(new Type; Type < MAX_TYPES; Type++)
		{
			for(new Style; Style < MAX_STYLES; Style++)
			{
				if(g_Ghost[Type][Style] == 0)
				{
					if(Style_CanUseReplay(Style, Type))
					{
						g_Ghost[Type][Style] = client;
						
						return true;
					}
				}
			}
		}
	}
	return true;
}

public OnClientDisconnect(client)
{
	// Prevent players from becoming the ghost.
	if(IsFakeClient(client))
	{
		for(new Type; Type < MAX_TYPES; Type++)
		{
			for(new Style; Style < MAX_STYLES; Style++)
			{
				if(Style_CanUseReplay(Style, Type))
				{
					if(client == g_Ghost[Type][Style])
					{
						g_Ghost[Type][Style] = 0;
						break;
					}
				}
			}
		}
	}
}

public OnTimesDeleted(Type, Style, RecordOne, RecordTwo, Handle:Times)
{
	new iSize = GetArraySize(Times);
	
	if(RecordTwo <= iSize)
	{
		for(new idx = RecordOne - 1; idx < RecordTwo; idx++)
		{
			if(GetArrayCell(Times, idx) == g_GhostPlayerID[Type][Style])
			{
				DeleteGhost(Type, Style);
				break;
			}
		}
	}
}

public Action:SM_DeleteGhost(client, args)
{
	OpenDeleteGhostMenu(client);
	
	return Plugin_Handled;
}

OpenDeleteGhostMenu(client)
{
	new Handle:menu = CreateMenu(Menu_DeleteGhost);
	
	SetMenuTitle(menu, "Select ghost to delete");
	
	decl String:sDisplay[64], String:sType[32], String:sStyle[32], String:sInfo[8];
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				GetStyleName(Style, sStyle, sizeof(sStyle));
				FormatEx(sDisplay, sizeof(sDisplay), "%s (%s)", sType, sStyle);
				Format(sInfo, sizeof(sInfo), "%d;%d", Type, Style);
				AddMenuItem(menu, sInfo, sDisplay);
			}
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_DeleteGhost(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[16], String:sTypeStyle[2][8];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			ExplodeString(info, ";", sTypeStyle, 2, 8);
			
			DeleteGhost(StringToInt(sTypeStyle[0]), StringToInt(sTypeStyle[1]));
			
			LogMessage("%L deleted the ghost", param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:GhostCheck(Handle:timer, any:data)
{	
    
	new iBotQuota = GetConVarInt(g_hBotQuota);
    
	if(iBotQuota != g_iBotQuota)
		ServerCommand("bot_quota %d", g_iBotQuota);
    
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				if(g_Ghost[Type][Style] != 0)
				{
					if(IsClientInGame(g_Ghost[Type][Style]))
					{
						
						new iSize = GetArraySize(g_hGhost[Type][Style]);
						
						decl String:sName[MAX_NAME_LENGTH];
						GetNameFromPlayerID(g_GhostPlayerID[Type][Style], sName, sizeof(sName));

						decl String:sClanTag[64];
						FormatEx(sClanTag, sizeof(sClanTag), "%s", sName);
						if(!StrEqual("Replay -", sClanTag))
						{
							if(0 < g_GhostFrame[Type][Style] < iSize)
							{
								CS_SetClientClanTag(g_Ghost[Type][Style], sClanTag);
							}
							else
							{
								CS_SetClientClanTag(g_Ghost[Type][Style], "N/A");
							}
						}

						// Check name
						if(strlen(g_sGhost[Type][Style]) > 0)
						{
							decl String:sGhostname[48];
							GetClientName(g_Ghost[Type][Style], sGhostname, sizeof(sGhostname));
							if(!StrEqual(sGhostname, g_sGhost[Type][Style]))
							{
								SetClientInfo(g_Ghost[Type][Style], "name", g_sGhost[Type][Style]);
							}
						}
						
						// Check if replay file is existed
						if(g_bReplayFileExists[Type][Style])
						{
							if(!IsPlayerAlive(g_Ghost[Type][Style]))
							{
								CS_RespawnPlayer(g_Ghost[Type][Style]);
							}
						}
						else if(!g_bReplayFileExists[Type][Style])
						{
							if(IsPlayerAlive(g_Ghost[Type][Style]))
							{
								FakeClientCommand(g_Ghost[Type][Style], "kill");
							}
						}
						
						// Display ghost's current time to spectators
						for(new client = 1; client <= MaxClients; client++)
						{
							if(IsClientInGame(client))
							{
								if(!IsPlayerAlive(client))
								{
									new target 	 = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
									new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
									
									if(target == g_Ghost[Type][Style] && (ObserverMode == 4 || ObserverMode == 5))
									{
										if(!g_GhostPaused[Type][Style] && (0 < g_GhostFrame[Type][Style] < iSize))
										{
											decl String:sTime[32], String:sStyle[16], String:keys[64];
											new Float:time = GetEngineTime() - g_fStartTime[Type][Style];
											FormatPlayerTime(time, sTime, sizeof(sTime), false, 0);
											float fSpeed[3];
											GetEntPropVector(target, Prop_Data, "m_vecVelocity", fSpeed);
											float fSpeed_New = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
											GetStyleName(Style, sStyle, sizeof(sStyle));
											GetKeysMessage(target, keys, sizeof(keys));
											new SpecCount[MaxClients+1];
											SpecCountToArrays(SpecCount);
											new buttons = GetClientButtons(target);
											PrintHintText(client, "<font size=\"16\" color=\"#0089CC\">\t\t   Replay</font>\n<font size='16'>Style: %s%sTime: %s\nSpecs: %d\t      %s\t\tSpeed: %.f\n%s", 
											sStyle,
											strlen(sStyle) <= 5 ? "\t\t\t":"\t\t",
											sTime,
											SpecCount[target],
											buttons & IN_FORWARD ? "W":"_",
											fSpeed_New,
											keys);
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

void GetKeysMessage(int client, char[] keys, int maxlen)
{
	new buttons = GetClientButtons(client);

	Format(keys, maxlen, "");

	if(buttons & IN_JUMP)
		Format(keys, maxlen, "%sJump\t\t   ", keys);
	else
		Format(keys, maxlen, "%s    \t\t   ", keys);
	
	if(buttons & IN_MOVELEFT)
		Format(keys, maxlen, "%sA", keys);
	else
		Format(keys, maxlen, "%s_ ", keys);

	if(buttons & IN_BACK)
		Format(keys, maxlen, "%sS", keys);
	else
		Format(keys, maxlen, "%s_ ", keys);

	if(buttons & IN_MOVERIGHT)
		Format(keys, maxlen, "%sD\t\t", keys);
	else
		Format(keys, maxlen, "%s_\t\t", keys);

	if(buttons & IN_DUCK)
		Format(keys, maxlen, "%sDuck", keys);
	else
		Format(keys, maxlen, "%s", keys);

	Format(keys, maxlen, "%s", keys);
}

void SpecCountToArrays(clients[])
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			if(!IsPlayerAlive(client))
			{
				new Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
				if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
				{
					clients[Target]++;
				}
			}
		}
	}
}

LoadGhost()
{
	// Rename old version files
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s.rec", g_sMapName);
	if(FileExists(sPath))
	{
		decl String:sPathTwo[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPathTwo, sizeof(sPathTwo), "data/btimes/%s_0_0.rec", g_sMapName);
		RenameFile(sPathTwo, sPath);
	}
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_CanUseReplay(Style, Type))
			{
				
				g_fGhostTime[Type][Style]    = 0.0;
				g_GhostPlayerID[Type][Style] = 0;
				
				BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, Style);
				
				if(FileExists(sPath))
				{
					
					g_bReplayFileExists[Type][Style] = true;
					
					// Open file for reading
					new Handle:hFile = OpenFile(sPath, "r");
					
					// Load all data into the ghost handle
					decl String:line[512], String:expLine[6][64], String:expLine2[2][10];
					new iSize = 0;
					
					ReadFileLine(hFile, line, sizeof(line));
					ExplodeString(line, "|", expLine2, 2, 10);
					g_GhostPlayerID[Type][Style] = StringToInt(expLine2[0]);
					g_fGhostTime[Type][Style]    = StringToFloat(expLine2[1]);
					
					while(!IsEndOfFile(hFile))
					{
						ReadFileLine(hFile, line, sizeof(line));
						ExplodeString(line, "|", expLine, 6, 64);
						
						iSize = GetArraySize(g_hGhost[Type][Style]) + 1;
						ResizeArray(g_hGhost[Type][Style], iSize);
						SetArrayCell(g_hGhost[Type][Style], iSize - 1, StringToFloat(expLine[0]), 0);
						SetArrayCell(g_hGhost[Type][Style], iSize - 1, StringToFloat(expLine[1]), 1);
						SetArrayCell(g_hGhost[Type][Style], iSize - 1, StringToFloat(expLine[2]), 2);
						SetArrayCell(g_hGhost[Type][Style], iSize - 1, StringToFloat(expLine[3]), 3);
						SetArrayCell(g_hGhost[Type][Style], iSize - 1, StringToFloat(expLine[4]), 4);
						SetArrayCell(g_hGhost[Type][Style], iSize - 1, StringToInt(expLine[5]), 5);
					}
					CloseHandle(hFile);
					
					g_bGhostLoadedOnce[Type][Style] = true;
					
					new Handle:pack = CreateDataPack();
					WritePackCell(pack, Type);
					WritePackCell(pack, Style);
					WritePackString(pack, g_sMapName);
					
					// Query for name/time of player the ghost is following the path of
					decl String:query[512];
					Format(query, sizeof(query), "SELECT t2.User, t1.Time FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID AND t1.PlayerID=%d AND t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=%d AND t1.Style=%d",
						g_GhostPlayerID[Type][Style],
						g_sMapName,
						Type,
						Style);
					SQL_TQuery(g_DB, LoadGhost_Callback, query, pack);
				}
				else
				{
					g_bReplayFileExists[Type][Style] = false;
					g_bGhostLoaded[Type][Style] = true;
				}
			}
		}
	}
}

public LoadGhost_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new Type  = ReadPackCell(data);
		new Style = ReadPackCell(data);
		
		decl String:sMapName[64];
		ReadPackString(data, sMapName, sizeof(sMapName));
		
		if(StrEqual(g_sMapName, sMapName))
		{
			if(SQL_GetRowCount(hndl) != 0)
			{
				SQL_FetchRow(hndl);
				
				decl String:sName[20];
				SQL_FetchString(hndl, 0, sName, sizeof(sName));
				
				if(g_fGhostTime[Type][Style] == 0.0)
					g_fGhostTime[Type][Style] = SQL_FetchFloat(hndl, 1);
				
				decl String:sTime[32];
				FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 1);
				
				decl String:sType[32], String:sStyle[32];
				GetTypeName(Type, sType, sizeof(sType), true);
							
				GetStyleName(Style, sStyle, sizeof(sStyle));
				if(Type == 1)
					FormatEx(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "Bonus %s - %s", sStyle, sTime);
				else
					FormatEx(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "%s - %s", sStyle, sTime);
			}
			
			g_bGhostLoaded[Type][Style] = true;
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

public OnTimerStart_Post(client, Type, Style)
{
	// Reset saved ghost data
	ClearArray(g_hFrame[client]);
}

public OnTimerFinished_Post(client, Float:Time, Type, Style, bool:NewTime, OldPosition, NewPosition)
{
	if(g_bGhostLoaded[Type][Style] == true)
	{
		if(Style_CanReplaySave(Style, Type))
		{
			if(Time < g_fGhostTime[Type][Style] || g_fGhostTime[Type][Style] == 0.0)
			{
				SaveGhost(client, Time, Type, Style);
			}
		}
	}
}

SaveGhost(client, Float:Time, Type, Style)
{
	g_fGhostTime[Type][Style] = Time;
	
	g_GhostPlayerID[Type][Style] = GetPlayerID(client);
	
	// Delete existing ghost for the map
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, Style);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	// Open a file for writing
	new Handle:hFile = OpenFile(sPath, "w");
	
	// save playerid to file to grab name and time for later times map is played
	decl String:playerid[16];
	IntToString(GetPlayerID(client), playerid, sizeof(playerid));
	WriteFileLine(hFile, "%d|%f", GetPlayerID(client), Time);
	
	new iSize = GetArraySize(g_hFrame[client]);
	decl String:buffer[512];
	new Float:data[5], buttons;
	
	ClearArray(g_hGhost[Type][Style]);
	for(new i=0; i<iSize; i++)
	{
		GetArrayArray(g_hFrame[client], i, data, 5);
		PushArrayArray(g_hGhost[Type][Style], data, 5);
		
		buttons = GetArrayCell(g_hFrame[client], i, 5);
		SetArrayCell(g_hGhost[Type][Style], i, buttons, 5);
		
		FormatEx(buffer, sizeof(buffer), "%f|%f|%f|%f|%f|%d", data[0], data[1], data[2], data[3], data[4], buttons);
		WriteFileLine(hFile, buffer);
	}
	CloseHandle(hFile);
	
	g_GhostFrame[Type][Style] = 0;
	
	decl String:sTime[32];
	FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 1);
	
	decl String:sType[32], String:sStyle[32];
	GetTypeName(Type, sType, sizeof(sType), true);
				
	GetStyleName(Style, sStyle, sizeof(sStyle));
	Format(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "%s %s - %s", sType, sStyle, sTime);
	
	g_bReplayFileExists[Type][Style] = true;
	
	if(g_Ghost[Type][Style] != 0)
    {
        if(!IsPlayerAlive(g_Ghost[Type][Style]))
        {
            CS_RespawnPlayer(g_Ghost[Type][Style]);
        }
    }
	
}

DeleteGhost(Type, Style)
{
	// delete map ghost file
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, Style);
	if(FileExists(sPath))
		DeleteFile(sPath);
	
	// reset ghost
	if(g_Ghost[Type][Style] != 0)
	{
		g_fGhostTime[Type][Style] = 0.0;
		ClearArray(g_hGhost[Type][Style]);
		
		decl String:sType[32], String:sStyle[32];
		GetTypeName(Type, sType, sizeof(sType), true);
				
		GetStyleName(Style, sStyle, sizeof(sStyle));
		
		Format(g_sGhost[Type][Style], sizeof(g_sGhost[][]), "%s %s - N/A", sType, sStyle);
		CS_SetClientClanTag(g_Ghost[Type][Style], "N/A");
		FakeClientCommand(g_Ghost[Type][Style], "kill");
	}
	
	g_bReplayFileExists[Type][Style] = false;
	
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
		CloseHandle(g_DB);
	
	decl String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsPlayerAlive(client))
	{
		if(!IsFakeClient(client))
		{
			new Type = GetClientTimerType(client);
			new Style = GetClientStyle(client);
			if(IsBeingTimed(client, TIMER_ANY) && !IsTimerPaused(client) && Style_CanReplaySave(Style, Type))
			{
				// Record player movement data
				new iSize = GetArraySize(g_hFrame[client]);
				ResizeArray(g_hFrame[client], iSize + 1);
				
				new Float:vPos[3], Float:vAng[3];
				Entity_GetAbsOrigin(client, vPos);
				GetClientEyeAngles(client, vAng);
				
				SetArrayCell(g_hFrame[client], iSize, vPos[0], 0);
				SetArrayCell(g_hFrame[client], iSize, vPos[1], 1);
				SetArrayCell(g_hFrame[client], iSize, vPos[2], 2);
				SetArrayCell(g_hFrame[client], iSize, vAng[0], 3);
				SetArrayCell(g_hFrame[client], iSize, vAng[1], 4);
				SetArrayCell(g_hFrame[client], iSize, buttons, 5);
			}
		}
		else
		{
			for(new Type; Type < MAX_TYPES; Type++)
			{
				for(new Style; Style < MAX_STYLES; Style++)
				{
					if(client == g_Ghost[Type][Style] && g_hGhost[Type][Style] != INVALID_HANDLE)
					{
						new iSize = GetArraySize(g_hGhost[Type][Style]);
						
						new Float:vPos[3], Float:vAng[3];
						if(g_GhostFrame[Type][Style] == 1)
						{
							g_fStartTime[Type][Style] = GetEngineTime();
							

							vPos[0] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 0);
							vPos[1] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 1);
							vPos[2] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 2);
							vAng[0] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 3);
							vAng[1] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 4);
							TeleportEntity(g_Ghost[Type][Style], vPos, vAng, Float:{0.0, 0.0, 0.0});
							
							
							if(g_GhostPaused[Type][Style] == false)
							{
								g_GhostPaused[Type][Style] = true;
								g_fPauseTime[Type][Style]  = GetEngineTime();
							}
							
							if(GetEngineTime() > g_fPauseTime[Type][Style] + GetConVarFloat(g_hGhostStartPauseTime))
							{
								g_GhostPaused[Type][Style] = false;
								g_GhostFrame[Type][Style]++;
							}
						}
						else if(g_GhostFrame[Type][Style] == (iSize - 1))
						{

							vPos[0] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 0);
							vPos[1] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 1);
							vPos[2] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 2);
							vAng[0] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 3);
							vAng[1] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 4);
								
							TeleportEntity(g_Ghost[Type][Style], vPos, vAng, Float:{0.0, 0.0, 0.0});
							
							
							if(g_GhostPaused[Type][Style] == false)
							{					
								g_GhostPaused[Type][Style] = true;
								g_fPauseTime[Type][Style]  = GetEngineTime();
							}
							
							if(GetEngineTime() > g_fPauseTime[Type][Style] + GetConVarFloat(g_hGhostEndPauseTime))
							{
								g_GhostPaused[Type][Style] = false;
								g_GhostFrame[Type][Style]  = 1;
							}
						}
						else if(g_GhostFrame[Type][Style] < iSize)
						{
							new Float:vPos2[3];
							Entity_GetAbsOrigin(client, vPos2);
							
							vPos[0] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 0);
							vPos[1] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 1);
							vPos[2] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 2);
							vAng[0] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 3);
							vAng[1] = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 4);
							buttons = GetArrayCell(g_hGhost[Type][Style], g_GhostFrame[Type][Style], 5);
							
							// Get the new velocity from the the 2 points
							new Float:vVel[3];
							MakeVectorFromPoints(vPos2, vPos, vVel);
							ScaleVector(vVel, 1.0 / GetTickInterval());
								
							//TeleportEntity(g_Ghost[Type][Style], NULL_VECTOR, vAng, vVel);
							
							float fDistance = GetVectorDistance(vPos2, vPos);

							if((g_GhostFrame[Type][Style] % 128) == 0 && SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0)) < 2.0 * fDistance)
							{
								TeleportEntity(g_Ghost[Type][Style], vPos2, vAng, vVel);
							}
							
							else
							{
								TeleportEntity(g_Ghost[Type][Style], NULL_VECTOR, vAng, vVel);
							}
							
							
							if(GetEntityMoveType(g_Ghost[Type][Style]) != MOVETYPE_NOCLIP)
							{
								SetEntityMoveType(g_Ghost[Type][Style], MOVETYPE_NOCLIP);
							}
							
							g_GhostFrame[Type][Style]++;
						}
						else if(g_GhostFrame[Type][Style] == 0 && iSize > 0)
							g_GhostFrame[Type][Style]++;
						
						if(g_GhostPaused[Type][Style] == true)
						{
							if(GetEntityMoveType(g_Ghost[Type][Style]) != MOVETYPE_NONE)
							{
								SetEntityMoveType(g_Ghost[Type][Style], MOVETYPE_NONE);
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Changed;
}

public Action UserMessageHook_SayText2(UserMsg msg_hd, Handle bf, const int [] players, int playersNum, bool reliable, bool init)
{
	char UserMessage[96];
	Action returnaction = Plugin_Continue;

	if(GetUserMessageType() == UM_Protobuf)
	{
		PbReadString(bf, "msg_name", UserMessage, sizeof(UserMessage));
		if(StrContains(UserMessage, "Name_Change") != -1)
			returnaction = Plugin_Handled;
	}

	if(GetUserMessageType() == UM_BitBuf)
	{
		BfReadString(bf, UserMessage, sizeof(UserMessage));
		BfReadString(bf, UserMessage, sizeof(UserMessage));
		if(StrContains(UserMessage, "Name_Change") != -1)
		{
			returnaction = Plugin_Handled;
		}
	}

	return returnaction;
}