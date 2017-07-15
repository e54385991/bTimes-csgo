#define STOP_DOORS   	1<<0
#define STOP_GUNS    	1<<1
#define STOP_MUSIC   	1<<2
#define AUTO_BHOP    	1<<3
#define HIDE_PLAYERS 	1<<4
#define KH_TIMELEFT	1<<5
#define SHOW_2DVEL   	1<<6

native GetClientSettings(client);
native SetClientSettings(client, settings);
forward OnTimerChatChanged(MessageType, String:Message[]);