#pragma semicolon 1

#include <sourcemod>
#include <tf2c>

#define PL_VERSION "0.2"

#define TF_CLASS_CIVILIAN		10
#define TF_CLASS_DEMOMAN		4
#define TF_CLASS_ENGINEER		9
#define TF_CLASS_HEAVY			6
#define TF_CLASS_MEDIC			5
#define TF_CLASS_PYRO				7
#define TF_CLASS_SCOUT			1
#define TF_CLASS_SNIPER			2
#define TF_CLASS_SOLDIER		3
#define TF_CLASS_SPY				8
#define TF_CLASS_UNKNOWN		0

#define TF_TEAM_GRN					4
#define TF_TEAM_YLW					5
#define TF_TEAM_BLU					3
#define TF_TEAM_RED					2

#define SIZE_OF_INT		2147483647		// without 0

//This code is based on the Class Restrictions Mod from Tsunami: http://forums.alliedmods.net/showthread.php?t=73104

public Plugin:myinfo =
{
    name        = "Civilian Only TF2C",
    author      = "Tsunami,JonathanFlynn, port by FigMan57",
    description = "Fat man fortress",
    version     = PL_VERSION,
    url         = "https://github.com/JonathanFlynn/Class-Warfare"
}

new g_iClass[MAXPLAYERS + 1];
new Handle:g_hEnabled;
new Handle:g_hFlags;
new Handle:g_hImmunity;
new Handle:g_hClassChangeInterval;
new Float:g_hLimits[8][11];
new String:g_sSounds[10][24] = {"", "vo/scout_no03.wav",   "vo/sniper_no04.wav", "vo/soldier_no01.wav",
    "vo/demoman_no03.wav", "vo/medic_no03.wav",  "vo/heavy_no02.wav",
    "vo/pyro_no01.wav",    "vo/spy_no02.wav",    "vo/engineer_no03.wav"};

static String:ClassNames[TFClassType][] = {"", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer", "Civilian" };

new g_iBlueClass;
new g_iRedClass;
new g_iYellowClass;
new g_iGreenClass;

new RandomizedThisRound = 0;

public OnPluginStart()
{
    CreateConVar("sm_classwarfare_version", PL_VERSION, "Class Warfare in TF2.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    g_hEnabled                                = CreateConVar("sm_classwarfare_enabled",       "1",  "Enable/disable the Class Warfare mod in TF2.");
    g_hFlags                                  = CreateConVar("sm_classwarfare_flags",         "",   "Admin flags for restricted classes in TF2.");
    g_hImmunity                               = CreateConVar("sm_classwarfare_immunity",      "0",  "Enable/disable admins being immune for restricted classes in TF2.");
    g_hClassChangeInterval                        = CreateConVar("sm_classwarfare_change_interval",   "0",  "Shuffle the classes every x minutes, 0 for round only");

    HookEvent("player_changeclass", Event_PlayerClass);
    HookEvent("player_spawn",       Event_PlayerSpawn);
    HookEvent("player_team",        Event_PlayerTeam);
    
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("teamplay_setup_finished",Event_SetupFinished);
    
    HookEvent("teamplay_round_win",Event_RoundOver);
    
    new seeds[1];
    seeds[0] = GetTime();
    SetURandomSeed(seeds, 1);

    // for (new i = 0; i < 10; i++) {
    // LogError("Random[%i] = %i", i, Math_GetRandomInt(TF_CLASS_SCOUT, TF_CLASS_ENGINEER));
    // }  
    
}

public OnMapStart()
{
    SetupClassRestrictions();
    
    decl i, String:sSound[32];
    for(i = 1; i < sizeof(g_sSounds); i++)
    {
        Format(sSound, sizeof(sSound), "sound/%s", g_sSounds[i]);
        PrecacheSound(g_sSounds[i]);
    }
}

public Event_RoundOver(Handle:event, const String:name[], bool:dontBroadcast) {

    //new WinnerTeam = GetEventInt(event, "team"); 
    new FullRound = GetEventInt(event, "full_round"); 
    //new WinReason = GetEventInt(event, "winreason"); 
    //new FlagCapLimit = GetEventInt(event, "flagcaplimit"); 

    //PrintToChatAll("Full Round? %d | WinnerTeam: %d | WinReason: %d | FlagCapLimit: %d", FullRound, WinnerTeam, WinReason, FlagCapLimit); 
    
    //On Dustbowl, each stage is a mini-round.  If we switch up between minirounds,
    //the teams may end up in a stalemate with lots of times on the clock... 
    
    if(FullRound == 1) 
    {
        RandomizedThisRound = 0;
    }
}

public OnClientPutInServer(client)
{
    g_iClass[client] = TF_CLASS_UNKNOWN;
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(!GetConVarBool(g_hEnabled))
    return;
    
    new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
    iClass  = GetEventInt(event, "class");
    
    if(!IsValidClass(iClient, iClass))
    {
        //Don't need to show class selection again until we offer multiple classes
        //new iTeam   = GetClientTeam(iClient);
        //ShowVGUIPanel(iClient, iTeam == TF_TEAM_BLU ? "class_blue" : "class_red"); 
        //EmitSoundToClient(iClient, g_sSounds[iClass]);
        //TF2_SetPlayerClass(iClient, TFClassType:g_iClass[iClient]);
        
        PrintCenterText(iClient, "%s", "Fat man only!");   
        PrintToChat(iClient, "%s", "Fat man only!"); 
        AssignValidClass(iClient);
    }    
}


public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    RoundClassRestrictions();
    PrintStatus();
} 

public Action:Event_SetupFinished(Handle:event,  const String:name[], bool:dontBroadcast) 
{   
    PrintStatus();
}  

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new iClient = GetClientOfUserId(GetEventInt(event, "userid"));  
    g_iClass[iClient] = _:TF2_GetPlayerClass(iClient);
    
    if(!IsValidClass(iClient,g_iClass[iClient]))
    {   //new iTeam   = GetClientTeam(iClient);       
        //ShowVGUIPanel(iClient, iTeam == TF_TEAM_BLU ? "class_blue" : "class_red");
        //EmitSoundToClient(iClient, g_sSounds[g_iClass[iClient]]);
        
        AssignValidClass(iClient);
    }
}

public Event_PlayerTeam(Handle:event,  const String:name[], bool:dontBroadcast)
{   
    new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(!IsValidClass(iClient,g_iClass[iClient]))
    {
        //new iTeam   = GetClientTeam(iClient);
        //ShowVGUIPanel(iClient, iTeam == TF_TEAM_BLU ? "class_blue" : "class_red");
        //EmitSoundToClient(iClient, g_sSounds[g_iClass[iClient]]);
        AssignValidClass(iClient);
    }
}

bool:IsValidClass(iClient, iClass) {

    new iTeam = GetClientTeam(iClient);
    
    if(!(GetConVarBool(g_hImmunity) && IsImmune(iClient)) && IsFull(iTeam, iClass)) {
        return false;
    }
    return true;   
}

bool:IsFull(iTeam, iClass)
{
    // If plugin is disabled, or team or class is invalid, class is not full
    if(!GetConVarBool(g_hEnabled) || iTeam < TF_TEAM_RED || iClass < TF_CLASS_SCOUT)
    return false;
    
    // Get team's class limit
    new iLimit,
Float:flLimit = g_hLimits[iTeam][iClass];
    
    // If limit is a percentage, calculate real limit
    if(flLimit > 0.0 && flLimit < 1.0)
    iLimit = RoundToNearest(flLimit);
    else
    iLimit = RoundToNearest(flLimit);
    
    // If limit is -1, class is not full
    if(iLimit == -1)
    return false;
    // If limit is 0, class is full
    else if(iLimit == 0)
    return true;
    
    // Loop through all clients
    for(new i = 1, iCount = 0; i <= MaxClients; i++)
    {
        // If client is in game, on this team, has this class and limit has been reached, class is full
        if(IsClientInGame(i) && GetClientTeam(i) == iTeam && _:TF2_GetPlayerClass(i) == iClass && ++iCount > iLimit)
        return true;
    }
    
    return false;
}

PrintStatus() {
    if(!GetConVarBool(g_hEnabled))
    return;
    
    PrintCenterTextAll("%s", "Fat man only!");
    PrintToChatAll("%s", "Fat man only!");
}
bool:IsImmune(iClient)
{
    if(!iClient || !IsClientInGame(iClient))
    return false;
    
    decl String:sFlags[32];
    GetConVarString(g_hFlags, sFlags, sizeof(sFlags));
    
    // If flags are specified and client has generic or root flag, client is immune
    return !StrEqual(sFlags, "") && GetUserFlagBits(iClient) & (ReadFlagString(sFlags)|ADMFLAG_ROOT);
}

AssignPlayerClasses() {
    for (new i = 1; i <= MaxClients; ++i) {            
        if (IsClientConnected(i) && (!IsValidClass(i,g_iClass[i]))) {
            AssignValidClass(i);     
        }
    }
}

// Run once per real round (event fires multiple times)
RoundClassRestrictions() {
    if ( RandomizedThisRound == 0) {
        SetupClassRestrictions();
    } 
    RandomizedThisRound = 1;
    AssignPlayerClasses();
}

SetupClassRestrictions() {
    
    for(new i = TF_CLASS_SCOUT; i <= TF_CLASS_CIVILIAN; i++)
    {
        g_hLimits[TF_TEAM_BLU][i] = 0.0;
        g_hLimits[TF_TEAM_RED][i] = 0.0;
        g_hLimits[TF_TEAM_YLW][i] = 0.0;
        g_hLimits[TF_TEAM_GRN][i] = 0.0;
    }
    
    g_iBlueClass = TF_CLASS_CIVILIAN;
    g_iRedClass = TF_CLASS_CIVILIAN;
    g_iGreenClass = TF_CLASS_CIVILIAN;
    g_iYellowClass = TF_CLASS_CIVILIAN;
    
    g_hLimits[TF_TEAM_BLU][g_iBlueClass] = -1.0;
    g_hLimits[TF_TEAM_RED][g_iRedClass] = -1.0; 
    g_hLimits[TF_TEAM_YLW][g_iYellowClass] = -1.0;
    g_hLimits[TF_TEAM_GRN][g_iGreenClass] = -1.0; 
    new seconds = GetConVarInt(g_hClassChangeInterval) * 60;
    if (seconds > 0) { 
        CreateTimer(float(seconds), TimerClassChange);
    }
    
}

public Action:TimerClassChange(Handle:timer, any:client)
{
    SetupClassRestrictions();
    PrintToChatAll("%s", "Fat man only!");
}

AssignValidClass(iClient)
{
    // Loop through all classes, starting at random class
    for(new i = (TF_CLASS_SCOUT, TF_CLASS_CIVILIAN), iClass = i, iTeam = GetClientTeam(iClient);;)
    {
        // If team's class is not full, set client's class
        if(!IsFull(iTeam, i))
        {
            TF2_SetPlayerClass(iClient, TFClassType:i);
            TF2_RegeneratePlayer(iClient);  
            if (!IsPlayerAlive(iClient)) {
                TF2_RespawnPlayer(iClient);
            }
            g_iClass[iClient] = i;
            break;
        }
        // If next class index is invalid, start at first class
        else if(++i > TF_CLASS_CIVILIAN)
        i = TF_CLASS_SCOUT;
        // If loop has finished, stop searching
        else if(i == iClass)
        break;
    }
}

stock Math_GetRandomInt(min, max)
{
    new random = GetURandomInt();
    
    if (random == 0) {
        random++;
    }

    return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}
