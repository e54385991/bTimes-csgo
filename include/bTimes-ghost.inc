#if defined _ghost_included
  #endinput
#endif
#define _ghost_included

#define TOTAL_BOTS 3

enum
{
    RECFRM_POS[3],
    RECFRM_ANG[2],
    
    RECFRM_FLAGS,
    
    RECFRM_SIZE
};

/**
* Gets if a client is a replay bot, also gets type and style of replay bot through parameters
* 
* @param client		The index of the client
* @param Type			The Timer Type of the client to be returned
* @param Style		The Timer Style of the client to be returned
* 
* @return			true if client is a replay bot, false otherwise
*/
native bool:GetBotInfo(client, &Type, &Style);

public SharedPlugin:__pl_ghost = 
{
	name = "ghost",
	file = "bTimes-ghost.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_ghost_SetNTVOptional()
{
	MarkNativeAsOptional("GetBotInfo");
}
#endif
