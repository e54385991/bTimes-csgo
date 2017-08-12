#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <smlib/clients>
#include <bTimes-core>

#define HIDE_RADAR_CSGO 1<<12

public Plugin:myinfo = 
{
	name = "[bTimes] - Extras",
	description = "Additional functions for the timer plugin",
	author = "88",
	version = "1.8.3",
	url = "http://steamcommunity.com/id/wwwhiteboy"
}

new String:g_msg_start[128];
new String:g_msg_varcol[128];
new String:g_msg_textcol[128];

new bool:g_bCanReceiveWeapons[MAXPLAYERS] = {true, ...};

new g_HPOffset, g_APOffset;

new Handle:g_EnableAdmNoclip;
	
new Handle:mp_playercashawards = INVALID_HANDLE;
new Handle:mp_teamcashawards = INVALID_HANDLE;

new 	Handle:g_EnableTeamMsg,
	Handle:g_EnableAdminTeamMsg;
	
new     Handle:g_EnableJoinMsg,
	Handle:g_EnableAdminJoinMsg;
	
new 	Handle:g_EnableDisMsg,
	Handle:g_EnableAdminDisMsg;

// flashlight variables
new Handle:g_hFlashlightEnable = INVALID_HANDLE;
new Handle:g_hLAW = INVALID_HANDLE;
new Handle:g_hReturn = INVALID_HANDLE;

new bool:g_bEnabled = true;
new bool:g_bLAW = true;
new bool:g_bRtn = false;

new Handle:mp_timelimit = INVALID_HANDLE;
new timelimit;

public void OnPluginStart()
{
	// ConVars
	g_hFlashlightEnable		 = CreateConVar("timer_flashlight", "1", "Adds a flashlight in the game", 0, true, 0.0, true, 1.0);
	g_hLAW 					 = CreateConVar("timer_flashlightlaw", "1", "It enables the use of flashlight through +lookatweapon", 0, true, 0.0, true, 1.0);
	g_hReturn 				 = CreateConVar("timer_flashlightrtn", "0", "Enables weapons inspection animation when you press +lookatweapon", 0, true, 0.0, true, 1.0);
	g_EnableTeamMsg			 = CreateConVar("timer_enableteammsg", "1", "Sets the join team message using timer_enableteammsg cvar", 0, true, 0.0, true, 1.0);
	g_EnableAdminTeamMsg 	 = CreateConVar("timer_enableadmteammsg", "0", "It enable a message indicating an administrator joined team", 0, true, 0.0, true, 1.0);
	g_EnableJoinMsg			 = CreateConVar("timer_enablejoinmsg", "1", "Sets the join message using timer_enablejoinmsg cvar", 0, true, 0.0, true, 1.0);
	g_EnableAdminJoinMsg	 = CreateConVar("timer_enableadmjoinmsg", "0", "It enable a message indicating an administrator connection", 0, true, 0.0, true, 1.0);
	g_EnableDisMsg			 = CreateConVar("timer_enabledismsg", "1", "Sets the disconnect message using timer_enabledismsg cvar", 0, true, 0.0, true, 1.0);
	g_EnableAdminDisMsg		 = CreateConVar("timer_enableadmdismsg", "0", "It enable a message indicating the disconnection from the server administrator", 0, true, 0.0, true, 1.0);

	// ConVars
	SetConVar("sv_enablebunnyhopping", "1");
	/*	SetConVar("sv_maxvelocity", "911420");*/
	SetConVar("sv_friction", "4");
	SetConVar("sv_accelerate", "5");
	SetConVar("bot_dont_shoot", "1");
	SetConVar("bot_join_after_player", "0");
	SetConVar("sv_infinite_ammo", "1");
	SetConVar("sv_ladder_scale_speed", "1");
	SetConVar("sv_staminamax", "0");
	SetConVar("sv_staminajumpcost", "0");
	SetConVar("sv_staminalandcost", "0");
	SetConVar("mp_limitteams", "0");
	mp_playercashawards = FindConVar("mp_playercashawards");
	mp_teamcashawards = FindConVar("mp_teamcashawards");

	// Events/hooks
	HookEvent("server_cvar", OnCvarChange, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_activate", Event_PlayerActive, EventHookMode_Post);
	HookEvent("player_team", Event_JoinTeam);
	HookEvent("player_team", Event_JoinTeam2, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookConVarChange(g_hFlashlightEnable, ConVarChanged);
	HookConVarChange(g_hLAW, ConVarChanged);
	HookConVarChange(g_hReturn, ConVarChanged);
	mp_timelimit = FindConVar("mp_timelimit");
	timelimit = GetConVarInt(mp_timelimit);
	HookConVarChange(mp_timelimit, ConVarChanged);
	EditVarFlags("mp_timelimit");

	// Commands
	RegConsoleCmd("sm_glock", GiveGlock, "Gives player glock");
	RegConsoleCmd("sm_usp", GiveUsp, "Gives player usp");
	RegConsoleCmd("sm_knife", GiveKnife, "Gives player knife");
	RegConsoleCmd("sm_weaponlist", WeaponList, "Show weapon list");
	AddCommandListener(Command_LAW, "+lookatweapon");
	RegConsoleCmd("sm_flashlight", Command_Flashlight);

	// Admin commands
	RegAdminCmd("sm_extend", admcmd_extend, ADMFLAG_CHANGEMAP, "sm_extend <minutes> - Extend map time or -short");
	RegAdminCmd("sm_stripweps", StripWeapons, ADMFLAG_CHEATS, "Strips a player's weapons and blocks them from weapon commands");
	RegAdminCmd("sm_stripweapons", StripWeapons, ADMFLAG_CHEATS, "Strips a player's weapons and blocks them from weapon commands");
	RegAdminCmd("sm_ak47", GiveAk47, ADMFLAG_CHEATS, "Gives player ak47");
	RegAdminCmd("sm_aug", GiveAug, ADMFLAG_CHEATS, "Gives player aug");
	RegAdminCmd("sm_awp", GiveAwp, ADMFLAG_CHEATS, "Gives player awp");
	RegAdminCmd("sm_bizon", GiveBizon, ADMFLAG_CHEATS, "Gives player bizon");
	RegAdminCmd("sm_cz", GiveCZ75, ADMFLAG_CHEATS, "Gives player cz-75");
	RegAdminCmd("sm_deagle", GiveDeagle, ADMFLAG_CHEATS, "Gives player deagle");
	RegAdminCmd("sm_dual", GiveBerettas, ADMFLAG_CHEATS, "Gives player dual berettas");
	RegAdminCmd("sm_famas", GiveFamas, ADMFLAG_CHEATS, "Gives player famas");
	RegAdminCmd("sm_fiveseven", GiveFiveSeven, ADMFLAG_CHEATS, "Gives player fiveseven");
	RegAdminCmd("sm_g3sg1", GiveG3SG1, ADMFLAG_CHEATS, "Gives player g3sg1");
	RegAdminCmd("sm_galil", GiveGalil, ADMFLAG_CHEATS, "Gives player galil ar");
	RegAdminCmd("sm_p2000", GiveP2000, ADMFLAG_CHEATS, "Gives player p2000");
	RegAdminCmd("sm_m249", GiveM249, ADMFLAG_CHEATS, "Gives player m249");
	RegAdminCmd("sm_m4a4", GiveM4A4, ADMFLAG_CHEATS, "Gives player m4a4");
	RegAdminCmd("sm_m4a1", GiveM4A1, ADMFLAG_CHEATS, "Gives player m4a1");
	RegAdminCmd("sm_mac10", GiveMAC10, ADMFLAG_CHEATS, "Gives player mac10");
	RegAdminCmd("sm_mag7", GiveMAG7, ADMFLAG_CHEATS, "Gives player mag7");
	RegAdminCmd("sm_mp7", GiveMP7, ADMFLAG_CHEATS, "Gives player mp7");
	RegAdminCmd("sm_mp9", GiveMP9, ADMFLAG_CHEATS, "Gives player mp9");
	RegAdminCmd("sm_negev", GiveNegev, ADMFLAG_CHEATS, "Gives player negev");
	RegAdminCmd("sm_nova", GiveNova, ADMFLAG_CHEATS, "Gives player nova");
	RegAdminCmd("sm_p250", GiveP250, ADMFLAG_CHEATS, "Gives player p250");
	RegAdminCmd("sm_p90", GiveP90, ADMFLAG_CHEATS, "Gives player p90");
	RegAdminCmd("sm_sawedoff", GiveSawedoff, ADMFLAG_CHEATS, "Gives player sawedoff");
	RegAdminCmd("sm_scar", GiveScar, ADMFLAG_CHEATS, "Gives player scar");
	RegAdminCmd("sm_sg", GiveSG556, ADMFLAG_CHEATS, "Gives player sg556");
	RegAdminCmd("sm_tec", GiveTEC9, ADMFLAG_CHEATS, "Gives player tec9");
	RegAdminCmd("sm_ump", GiveUMP45, ADMFLAG_CHEATS, "Gives player ump45");
	RegAdminCmd("sm_xm", GiveXM1014, ADMFLAG_CHEATS, "Gives player xm1014");
	RegAdminCmd("sm_revolver", GiveRevolver, ADMFLAG_CHEATS, "Gives player revolver");
	RegAdminCmd("sm_flash", GiveFlashbang, ADMFLAG_CHEATS, "Gives player flashbang");
	RegAdminCmd("sm_admnc", Admin_Noclip, ADMFLAG_ROOT, "Enable noclip for administrators");
	RegAdminCmd("sm_ap", Admin_Noclip, ADMFLAG_ROOT, "Enable noclip for administrators");

	// Change HP ana ARMOR
	g_HPOffset = FindSendPropInfo("CCSPlayer", "m_iHealth");
	g_APOffset = FindSendPropInfo("CCSPlayer", "m_ArmorValue");

	AutoExecConfig(true, "extras", "timer");
}

public ConVarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if(cvar == g_hFlashlightEnable)
	{
		g_bEnabled = bool:StringToInt(newVal);
	}

	if(cvar == g_hLAW)
	{
		g_bLAW = bool:StringToInt(newVal);
	}

	if(cvar == g_hReturn)
	{
		g_bRtn = bool:StringToInt(newVal);
	}
	
	timelimit = GetConVarInt(mp_timelimit);
}

EditVarFlags(const String:VarName[])
{
    new Handle:h_Cvar = FindConVar(VarName);
    if (h_Cvar != INVALID_HANDLE)
    {
        SetConVarFlags(h_Cvar, GetConVarFlags(h_Cvar) &~ FCVAR_NOTIFY);
    }
    else LogError("%s INVALID_HANDLE", VarName);
}

public OnTimerChatChanged(MessageType, String:Message[])
{
	if(MessageType == 0)
	{
		Format(g_msg_start, sizeof(g_msg_start), Message);
		ReplaceMessage(g_msg_start, sizeof(g_msg_start));
	}
	else if(MessageType == 1)
	{
		Format(g_msg_varcol, sizeof(g_msg_varcol), Message);
		ReplaceMessage(g_msg_varcol, sizeof(g_msg_varcol));
	}
	else if(MessageType == 2)
	{
		Format(g_msg_textcol, sizeof(g_msg_textcol), Message);
		ReplaceMessage(g_msg_textcol, sizeof(g_msg_textcol));
	}
}

ReplaceMessage(String:message[], maxlength)
{
	ReplaceString(message, maxlength, "^A", "\x0A");
	ReplaceString(message, maxlength, "^B", "\x0B");
	ReplaceString(message, maxlength, "^C", "\x0C");
	ReplaceString(message, maxlength, "^D", "\x0D");
	ReplaceString(message, maxlength, "^E", "\x0E");
	ReplaceString(message, maxlength, "^F", "\x0F");
	ReplaceString(message, maxlength, "^1", "\x01");
	ReplaceString(message, maxlength, "^2", "\x02");
	ReplaceString(message, maxlength, "^3", "\x03");
	ReplaceString(message, maxlength, "^4", "\x04");
	ReplaceString(message, maxlength, "^5", "\x05");
	ReplaceString(message, maxlength, "^6", "\x06");
	ReplaceString(message, maxlength, "^7", "\x07");
	ReplaceString(message, maxlength, "^8", "\x08");
	ReplaceString(message, maxlength, "^9", "\x09");
	ReplaceString(message, maxlength, "^0", "\x10");
}

void SetConVar(String:cvar1[], String:n_val[])
{
	new Handle:cvar = FindConVar(cvar1);
	if(cvar)
	{
		SetConVarString(cvar, n_val);
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// For change HP and AP
	SetEntData(client, g_HPOffset, 1337);
	SetEntData(client, g_APOffset, 100);
	
	// For remove radar
	CreateTimer(0.0, Timer_RemoveRadar, client);
}

// extend
public Action:admcmd_extend(client, args)
{
    if (args < 1)
    {
        CPrintToChat(client, "%s%sUsage: %ssm_extend <minutes>",
		g_msg_start,
		g_msg_textcol,
		g_msg_varcol);
        return Plugin_Handled;
    }

    new String:arg[10];
    GetCmdArg(1, arg, sizeof(arg));

    new time;
    time = 0;

    if((time = StringToInt(arg)) != 0)
    {

        SetConVarInt(mp_timelimit, timelimit + time);

        if(time > 0)
        {
            CPrintToChatAll("%s%sAdmin %s%N %sextend map time on %s%i %sminutes.",
			g_msg_start,
		    g_msg_textcol,
			g_msg_varcol,
			client,
			g_msg_textcol,
			g_msg_varcol,
			time,
			g_msg_textcol);
        }
        else
        {
			CPrintToChatAll("%s%sAdmin %s%N %sshorten map time (%s%i %sminutes)",
			g_msg_start,
		    g_msg_textcol,
			g_msg_varcol,
			client,
			g_msg_textcol,
			g_msg_varcol,
			time,
			g_msg_textcol);
        }
    }

    return Plugin_Handled;
}

public Action:Timer_RemoveRadar(Handle:timer, any:client) 
{    
	if(IsValidEntity(client))
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR_CSGO);
	}
}

public Event_PlayerActive(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsFakeClient(client))
	{
		SendConVarValue(client, mp_playercashawards, "0");
		SendConVarValue(client, mp_teamcashawards, "0");
	}
}

public Action:Command_LAW(client, const String:command[], argc)
{
	if(!g_bLAW || !g_bEnabled)
	{	
		return Plugin_Continue;
	}

	if(!IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	if(!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	ToggleFlashlight(client);

	return (g_bRtn) ? Plugin_Continue : Plugin_Handled;
}

public Action:GiveFlashbang(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{
			GiveWeapon(client, "weapon_flashbang");
			CPrintToChat(client, "%s%sYou have received a %sFlashbang%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveRevolver(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_revolver");
			CPrintToChat(client, "%s%sYou have received a %sR8 Revolver%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveXM1014(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_xm1014");
			CPrintToChat(client, "%s%sYou have received a %sXM1014%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveUMP45(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_ump45");
			CPrintToChat(client, "%s%sYou have received a %sUMP-45%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveTEC9(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_tec9");
			CPrintToChat(client, "%s%sYou have received a %sTec-9%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveSG556(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_sg556");
			CPrintToChat(client, "%s%sYou have received a %sSG 553%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveScar(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_scar20");
			CPrintToChat(client, "%s%sYou have received a %sSCAR-20%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveSawedoff(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_sawedoff");
			CPrintToChat(client, "%s%sYou have received a %sSawed-Off%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
		
	return Plugin_Handled;
}

public Action:GiveP90(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_p90");
			CPrintToChat(client, "%s%sYou have received a %sFN P90%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveP250(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		if(g_bCanReceiveWeapons[client])
		{
			GiveWeapon(client, "weapon_p250");
			CPrintToChat(client, "%s%sYou have received a %sP250%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveNova(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_nova");
			CPrintToChat(client, "%s%sYou have received a %sNova%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveNegev(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_negev");
			CPrintToChat(client, "%s%sYou have received a %sNegev%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveMP9(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_mp9");
			CPrintToChat(client, "%s%sYou have received a %sMP9%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveMP7(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_mp7");
			CPrintToChat(client, "%s%sYou have received a %sMP7%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveMAG7(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_mag7");
			CPrintToChat(client, "%s%sYou have received a %sMAG-7%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveMAC10(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_mac10");
			CPrintToChat(client, "%s%sYou have received a %sMAC-10%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveM4A1(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_m4a1_silencer");
			CPrintToChat(client, "%s%sYou have received a %sM4A1-S%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveM4A4(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_m4a1");
			CPrintToChat(client, "%s%sYou have received a %sM4A4%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveM249(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_m249");
			CPrintToChat(client, "%s%sYou have received a %sM249%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveP2000(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_hkp2000");
			CPrintToChat(client, "%s%sYou have received a %sP2000%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveGalil(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_galilar");
			CPrintToChat(client, "%s%sYou have received a %sGalil AR%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveG3SG1(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_g3sg1");
			CPrintToChat(client, "%s%sYou have received a %sG3SG1%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveFiveSeven(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_fiveseven");
			CPrintToChat(client, "%s%sYou have received a %sFive-Seven%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveFamas(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_famas");
			CPrintToChat(client, "%s%sYou have received a %sFamas%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveBerettas(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_elite");
			CPrintToChat(client, "%s%sYou have received a %sDual Berettas%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveDeagle(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_deagle");
			CPrintToChat(client, "%s%sYou have received a %sDesert Eagle%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveCZ75(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_cz75a");
			CPrintToChat(client, "%s%sYou have received a %sCZ-75 Auto%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}
	
	return Plugin_Handled;
}

public Action:GiveBizon(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_bizon");
			CPrintToChat(client, "%s%sYou have received a %sPP-Bizon%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:GiveGlock(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_glock");
			CPrintToChat(client, "%s%sYou have received a %sGlock%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:GiveUsp(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_usp_silencer");
			CPrintToChat(client, "%s%sYou have received a %sUsp%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:GiveKnife(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_knife");
			CPrintToChat(client, "%s%sYou have received a %sKnife%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:GiveAk47(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{		
			GiveWeapon(client, "weapon_ak47");
			CPrintToChat(client, "%s%sYou have received a %sAK-47%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:GiveAug(int client, int args)
{
	if(IsPlayerAlive(client))
	{	
		if(g_bCanReceiveWeapons[client])
		{	
			GiveWeapon(client, "weapon_aug");
			CPrintToChat(client, "%s%sYou have received a %sAug%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:GiveAwp(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		if(g_bCanReceiveWeapons[client])
		{
			GiveWeapon(client, "weapon_awp");
			CPrintToChat(client, "%s%sYou have received a %sAwp%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
		}
		else
		{
			CPrintToChat(client, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
		}	
	}
	else
	{
		CPrintToChat(client, "%sYou need to be alive to receive weapons.", g_msg_start);
	}

	return Plugin_Handled;
}

void GiveWeapon(int client, String:newweapon[])
{	
	new weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon != -1)
	{
		RemovePlayerItem(client, weapon);
		AcceptEntityInput(weapon, "Kill");
	}

	weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon != -1)
	{
		RemovePlayerItem(client, weapon);
		AcceptEntityInput(weapon, "Kill");
	}

	GivePlayerItem(client, newweapon, 0);
}

public Action:StripWeapons(int client, int args)
{
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	//Yes you can use this on bots
	new target = Client_FindByName(arg1);
	
	if(target == -1)
	{
		CPrintToChat(client, "%sCould not find that player", g_msg_start);
		return Plugin_Handled;
	}
	
	if(g_bCanReceiveWeapons[target])
	{
		g_bCanReceiveWeapons[target] = false;
		if(IsPlayerAlive(target))
		{
			new weapon = GetPlayerWeaponSlot(target, 1);
			if(weapon != -1)
			{
				RemovePlayerItem(target, weapon);
				AcceptEntityInput(weapon, "Kill");
			}
			weapon = GetPlayerWeaponSlot(target, 0);
			if(weapon != -1)
			{
				RemovePlayerItem(target, weapon);
				AcceptEntityInput(weapon, "Kill");
			}
		}
		CPrintToChat(client, "%sPlayer %s'%N' %scan no longer use weapon commands", g_msg_start, g_msg_varcol, target, g_msg_textcol);
		CPrintToChat(target, "%sAn admin has stripped your ability to use weapon commands!", g_msg_start);
	}
	else
	{
		g_bCanReceiveWeapons[target] = true;
		CPrintToChat(client, "%sPlayer %s'%N' %scan now use weapons commands again", g_msg_start, g_msg_varcol, target, g_msg_textcol);
		CPrintToChat(target, "%sWeapon command access has been restored.", g_msg_start);
	}

	return Plugin_Handled;
}

public Action:WeaponList(int client, int args)
{
	ReplyToCommand(client, "[SM] Look in your console for weapons command list.");
	PrintToConsole(client, "\n¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\n Weapon list:\n !glock               !usp\n !knife               !ak47\n !aug                 !awp\n !bizon               !cz\n !deagle              !dual\n !famas               !fiveseven\n !g3sg1               !galil\n !p2000               !m249\n !m4a4                !m4a1\n !mac10               !mag7\n !mp7                 !mp9\n !negev               !nova\n !p250                !p90\n !sawedoff            !scar\n !sg                  !tec\n !ump                 !xm\n !revolver            !flash\n_____________________________________\n");
}

public Action:OnCvarChange(Handle:event, const String:name[], bool:dontbroadcast)
{
	decl String:cvar_string[64];
	GetEventString(event, "cvarname", cvar_string, 64);
	
	if(StrEqual(cvar_string, "sv_enablebunnyhopping"))
		SetConVar("sv_enablebunnyhopping", "1");
/*	else if(StrEqual(cvar_string, "sv_maxvelocity"))
		SetConVar("sv_maxvelocity", "911420");*/
	else if(StrEqual(cvar_string, "sv_friction"))
		SetConVar("sv_friction", "4");
	else if(StrEqual(cvar_string, "sv_accelerate"))
		SetConVar("sv_accelerate", "5");
	else if(StrEqual(cvar_string, "bot_dont_shoot"))
		SetConVar("bot_dont_shoot", "1");
	else if(StrEqual(cvar_string, "bot_join_after_player"))
		SetConVar("bot_join_after_player", "0");
	else if(StrEqual(cvar_string, "sv_infinite_ammo"))
		SetConVar("sv_infinite_ammo", "1");
	else if(StrEqual(cvar_string, "sv_ladder_scale_speed"))
		SetConVar("sv_ladder_scale_speed", "1");
	else if(StrEqual(cvar_string, "sv_staminamax"))
		SetConVar("sv_staminamax", "0");
	else if(StrEqual(cvar_string, "sv_staminajumpcost"))
		SetConVar("sv_staminajumpcost", "0");
	else if(StrEqual(cvar_string, "sv_staminalandcost"))
		SetConVar("sv_staminalandcost", "0");
	else if(StrEqual(cvar_string, "mp_limitteams"))		
		SetConVar("mp_limitteams", "0");

	return Plugin_Handled;
}

public Action:Event_JoinTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetEventInt(event, "team");
	new oldteam = GetEventInt(event, "oldteam");

	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	if(GetConVarBool(g_EnableTeamMsg))
	{	
		if(!IsFakeClient(client))
		{	
			if(GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective) && GetConVarBool(g_EnableAdminTeamMsg))
			{	
				if(team == 2 && oldteam != 3 || team == 3 && oldteam != 2)
				{
					CPrintToChatAll(" %sAdmin %s%s %sis now bhopping", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
				}
				else if(team == 1)
				{
					CPrintToChatAll(" %sAdmin %s%s %sis now spectating", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
				}
			}
			else
			{
				if(team == 2 && oldteam != 3 || team == 3 && oldteam != 2)
				{
					CPrintToChatAll(" %sPlayer %s%s %sis now bhopping", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
				}
				else if(team == 1)
				{
					CPrintToChatAll(" %sPlayer %s%s %sis now spectating", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	if(GetConVarBool(g_EnableJoinMsg))
	{
		if(!IsFakeClient(client))
		{
			if(GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective) && GetConVarBool(g_EnableAdminJoinMsg))
			{
				CPrintToChatAll(" %sAdmin %s%s %sjoined the server", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
			}
			else
			{
				CPrintToChatAll(" %sPlayer %s%s %sjoined the server", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_bCanReceiveWeapons[client] = true;

	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	if(GetConVarBool(g_EnableDisMsg))
	{	
		if(!IsFakeClient(client))
		{	
			if(GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective) && GetConVarBool(g_EnableAdminDisMsg))
			{
				CPrintToChatAll(" %sAdmin %s%s %sleft the server", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
			}
			else
			{
				CPrintToChatAll(" %sPlayer %s%s %sleft the server", g_msg_textcol, g_msg_varcol, sName, g_msg_textcol);
			}
		}
	}
}

public Action:Event_JoinTeam2(Handle:event, const String:name[], bool:dontBroadcast)
{
	return Plugin_Handled;
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	return Plugin_Handled;
}