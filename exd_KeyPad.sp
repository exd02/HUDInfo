/*
Special thanks to JHUD Creator "blank" and Sikarii-movementhud Creator - One
*/

#include <sdktools>
#include <sourcemod>
#include <clientprefs>
#include <DynamicChannels>
#include <entity_prop_stocks>

#define PLUGIN_VERSION "1.02"
#define PLUGIN_URL "https://github.com/exd02/HUDInfo"
#define GROUND_TICK_TIME 15

public Plugin myinfo = 
{
	name = "HUDInfo",
	author = "exd",
	description = "Prints Target key on screen and the Speed/gain",
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

// Global
int gI_HopCount[MAXPLAYERS + 1];
int gI_TicksOnGround[MAXPLAYERS + 1];
int gI_StrafeTick[MAXPLAYERS + 1];
int gI_SyncedTick[MAXPLAYERS + 1];
int gI_TextRGB[MAXPLAYERS + 1][3];

Handle gH_KeyHUDCookie;
Handle gH_HUDSpeed;

float gF_OldAngle[MAXPLAYERS + 1];
float gF_RawGain[MAXPLAYERS + 1];
float gF_Trajectory[MAXPLAYERS + 1];
float gF_TraveledDistance[MAXPLAYERS + 1][3];

bool gB_HUDKey[MAXPLAYERS + 1];
bool gB_HUDSpeed[MAXPLAYERS + 1];

char gS_SpeedText[MAXPLAYERS + 1][32];

public void OnPluginStart()
{
	gH_KeyHUDCookie  = RegClientCookie("bKeyHUDCookie",  "bKeyHUDCookie", CookieAccess_Protected);
	gH_HUDSpeed = RegClientCookie("bGainHUDCookie", "bGainHUDCookie", CookieAccess_Protected);

	RegConsoleCmd("sm_hudkeypad", Command_HUDKeyPad, "Toggles ON KeyPad");
	RegConsoleCmd("sm_keypad", Command_HUDKeyPad, "Toggles ON KeyPad");
	RegConsoleCmd("sm_keys", Command_HUDKeyPad, "Toggles ON KeyPad");

	RegConsoleCmd("sm_jhud", Command_HUDSpeed, "Toggles ON SSJHUD");
	RegConsoleCmd("sm_jumphud", Command_HUDSpeed, "Toggles ON SSJHUD");
	RegConsoleCmd("sm_ssjhud", Command_HUDSpeed, "Toggles ON SSJHUD");

	HookEvent("player_jump", Event_PlayerJump);
}

public Action Command_HUDKeyPad(int client, any args)
{
	if (client != 0)
	{
		gB_HUDKey[client] = !gB_HUDKey[client];
		SetClientCookieBool(client, gH_KeyHUDCookie, gB_HUDKey[client]);
	}  
	return Plugin_Handled;
}

public Action Command_HUDSpeed(int client, any args)
{
	if (client != 0)
	{
		gB_HUDSpeed[client] = !gB_HUDSpeed[client];
		SetClientCookieBool(client, gH_HUDSpeed, gB_HUDSpeed[client]);
	}  
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	gB_HUDKey[client] = GetClientCookieBool(client, gH_KeyHUDCookie);
	gB_HUDSpeed[client] = GetClientCookieBool(client, gH_HUDSpeed);
}

public void OnClientPostAdminCheck(int client)
{
	gI_HopCount[client] = 0;
	gI_StrafeTick[client] = 0;
	gI_SyncedTick[client] = 0;
	gF_RawGain[client] = 0.0;
	gF_Trajectory[client] = 0.0;
	gF_TraveledDistance[client] = NULL_VECTOR;
	gI_TicksOnGround[client] = 0;
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{	
	// Get the client from the event
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if((gI_HopCount[client] && gI_StrafeTick[client] <= 0) || (IsFakeClient(client))) return;

	gI_HopCount[client] ++;
	
	int target = client;

	// Here we print to the player that is jumping
	if (IsPlayerAlive(client) && gB_HUDSpeed[client]) GetPlayerSpeed(client, target);

	// Here we print to the player that is spectating the client
	for(int i=1; i<MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsPlayerAlive(i) && gB_HUDSpeed[i])
		{
			target = GetEntPropEnt(i, Prop_Data, "m_hObserverTarget");
			GetPlayerSpeed(client, target);
		}
	}

	gF_RawGain[client] = 0.0;
	gI_StrafeTick[client] = 0;
	gI_SyncedTick[client] = 0;
	gF_Trajectory[client] = 0.0;
	gF_TraveledDistance[client] = NULL_VECTOR;
}



/*	The client is the player that we gonna print the HUD
		The target is the player that's jumping			*/
public void GetPlayerSpeed(int client, int target)
{
	// ========================================== Get and convert the Speed ========================================== //
	float fVelocity[3];
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", fVelocity);
	int iPlayerSpeed = RoundToFloor(GetVectorLength(fVelocity));
	// =============================================================================================================== //

	

	// ================================== Calculate the RGB based in GAIN% OR SSJ ==================================== //
	int r = 0; int rPercentage; 
	int g = 0; int gPercentage;
	int b = 0; int bPercentage;
	char sTargetSpeed[16];

	int JumpNumber = gI_HopCount[target] - 1;
	if (gI_HopCount[target] <= 6)
	{
		int SSJ[6][3];
		// SSJ [J][C]  J Represents the Jump index and C the color.
		SSJ[0][0] = 280;
		SSJ[1][0] = 360;
		SSJ[2][0] = 440;
		SSJ[3][0] = 520;
		SSJ[4][0] = 580;
		SSJ[5][0] = 600;
		//
		SSJ[0][1] = 281;
		SSJ[1][1] = 380;
		SSJ[2][1] = 460;
		SSJ[3][1] = 530;
		SSJ[4][1] = 600;
		SSJ[5][1] = 660;
		// 
		SSJ[0][2] = 286;
		SSJ[1][2] = 390;
		SSJ[2][2] = 480;
		SSJ[3][2] = 560;
		SSJ[4][2] = 620;
		SSJ[5][2] = 680;

		for (int i=0; i<6; i++)
		{
			if (iPlayerSpeed <= SSJ[JumpNumber][0])
			{
				rPercentage = 100; gPercentage = 0; bPercentage = 0;
			}
			else if (iPlayerSpeed <= SSJ[JumpNumber][1])
			{
				rPercentage = 90; gPercentage = 65; bPercentage = 0;
			}
			else if (iPlayerSpeed <= SSJ[JumpNumber][2])
			{
				rPercentage = 0; gPercentage = 90; bPercentage = 15;
			}
			else
			{
				rPercentage = 0; gPercentage = 90; bPercentage = 90;
			}
		}
		Format(sTargetSpeed, sizeof(sTargetSpeed), "[%i] - %i", gI_HopCount[target], iPlayerSpeed);
	}
	else
	{
		float coeffsum = gF_RawGain[target];
		coeffsum /= gI_StrafeTick[target];
		coeffsum *= 100.0;
		coeffsum = RoundToFloor(coeffsum * 100.0 + 0.5) / 100.0;

		int percentage = RoundToFloor(coeffsum);

		if (percentage < 0) percentage = 0;
		else if (percentage > 100) percentage = 100;

		rPercentage = 100 - percentage;
		gPercentage = percentage;

		if (percentage > 80)
		{
			rPercentage = 0;
			bPercentage = (percentage-80)*5;
			if (bPercentage<50) bPercentage = 50;
		}
		Format(sTargetSpeed, sizeof(sTargetSpeed), "%.02f%%", coeffsum);
	}

	r = RoundToFloor(2.55*rPercentage);
	g = RoundToFloor(2.55*gPercentage);
	b = RoundToFloor(2.55*bPercentage);
	// ================================================================================================================ //



	// ============================================== Print SSJ or %Gain ============================================== //
	gI_TextRGB		[client]	[0] 	= r;
	gI_TextRGB		[client]	[1] 	= g;
	gI_TextRGB		[client]	[2] 	= b;
	gS_SpeedText	[client] 			= sTargetSpeed;
	// =============================================================================================================== //
}

public void PrintTheText(float x, float y, int client, int r, int g, int b, char[] sMsg, int group)
{
	SetHudTextParams(x, y, 0.5, r, g, b, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, GetDynamicChannel(group), "%s", sMsg);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client)) return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(gI_TicksOnGround[client] > GROUND_TICK_TIME)
		{
			gI_HopCount[client] = 0;
			gI_StrafeTick[client] = 0;
			gI_SyncedTick[client] = 0;
			gF_RawGain[client] = 0.0;
			gF_Trajectory[client] = 0.0;
			gF_TraveledDistance[client] = NULL_VECTOR;
		}
		gI_TicksOnGround[client]++;
	}
	else
	{
		if(GetEntityMoveType(client) != MOVETYPE_NONE && GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
		{
			GetStats(client, vel, angles);
		}
		gI_TicksOnGround[client] = 0;
		if (gB_HUDSpeed[client]) PrintTheText(-1.0, -0.65, client, gI_TextRGB[client][0], gI_TextRGB[client][1], gI_TextRGB[client][2], gS_SpeedText[client],0);
	}

	// We need to run the function, because the client target can be a player that he is watching
	if (gB_HUDKey[client]) DisplayKeyPad(client);
	return Plugin_Continue;
}

void GetStats(int client, float vel[3], float angles[3])
{
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

	float gaincoeff;
	gI_StrafeTick[client]++;

	gF_TraveledDistance[client][0] += velocity[0] *  GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	gF_TraveledDistance[client][1] += velocity[1] *  GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	velocity[2] = 0.0;
	gF_Trajectory[client] += GetVectorLength(velocity) * GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");

	float fore[3], side[3], wishvel[3], wishdir[3];
	float wishspeed, wishspd, currentgain;

	GetAngleVectors(angles, fore, side, NULL_VECTOR);

	fore[2] = 0.0;
	side[2] = 0.0;
	NormalizeVector(fore, fore);
	NormalizeVector(side, side);

	for(int i = 0; i < 2; i++)
		wishvel[i] = fore[i] * vel[0] + side[i] * vel[1];
   
	wishspeed = NormalizeVector(wishvel, wishdir);
	if(wishspeed > GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") && GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != 0.0)
		wishspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");

	if(wishspeed)
	{
		wishspd = (wishspeed > 30.0) ? 30.0 : wishspeed;

		currentgain = GetVectorDotProduct(velocity, wishdir);
		if(currentgain < 30.0)
		{
			gI_SyncedTick[client]++;
			gaincoeff = (wishspd - FloatAbs(currentgain)) / wishspd;
		}
		gF_RawGain[client] += gaincoeff;
	}
}

public void DisplayKeyPad(int client)
{
	// ================================== Select the Target player to track the keys ================================= //
	int target;

	if(IsPlayerAlive(client))
		target = client;
	else
		target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	// Get Buttons
	int buttons = GetClientButtons(target);

	// Get Angles
	float Angle[3];
	GetClientEyeAngles(target, Angle);
	
	// Get the Angle Difference btw ActualAngle - OldAngle
	float AngleDiff = Angle[1] - gF_OldAngle[target];

	if (Angle[1] - gF_OldAngle[target] > 180)
		AngleDiff -= 360;
	else if	(Angle[1] - gF_OldAngle[target] < -180)
		AngleDiff += 360;
	
	gF_OldAngle[target] = Angle[1];
	// =============================================================================================================== //



	// ==================================================== Chars ==================================================== //
	char sKeys[32];																// The Key HUD
	char sCharacters[8][5] = {"←", "W", "→", "A", "S", "D", "DUCK", "JUMP"};	// The Characters
	char sNotPressingButton[2] = "_";											// Not pressing the Buton Character
	// =============================================================================================================== //


	
	// =================================================== KeyBool =================================================== //
	bool IsPressingTheKey[8] = { false, ...};
	IsPressingTheKey[0] = (AngleDiff > 0);								// ←
	IsPressingTheKey[1] = (buttons & IN_FORWARD == IN_FORWARD); 		// W
	IsPressingTheKey[2] = (AngleDiff < 0);								// →
	IsPressingTheKey[3] = (buttons & IN_MOVELEFT == IN_MOVELEFT);		// A
	IsPressingTheKey[4] = (buttons & IN_BACK == IN_BACK);				// S
	IsPressingTheKey[5] = (buttons & IN_MOVERIGHT == IN_MOVERIGHT);		// D
	IsPressingTheKey[6] = (buttons & IN_DUCK == IN_DUCK);				// DUCK
	IsPressingTheKey[7] = (buttons & IN_JUMP == IN_JUMP);				// JUMP
	// =============================================================================================================== //



	// ========================================== Loop to format the sKeys =========================================== //
	for (int i=0; i<8; i++)
	{
		if (IsPressingTheKey[i])
		{
			Format(sKeys, sizeof(sKeys), "%s %s", sKeys, sCharacters[i]);
		}
		else
		{
			if (i!=6 && i!=7)
				Format(sKeys, sizeof(sKeys), "%s %s", sKeys, sNotPressingButton);
		}

		if (i == 2 || i == 5 || i == 6)
			Format(sKeys, sizeof(sKeys), "%s\n", sKeys);
		
	}
	// =============================================================================================================== //



	// ========================================== Print the sKeys to the HUD ========================================= //
	if ((IsPressingTheKey[1] && IsPressingTheKey[4]) || (IsPressingTheKey[5] && IsPressingTheKey[3]))
		PrintTheText(-1.0, 0.2, client, 255, 100, 100, sKeys, 1);
	else
		PrintTheText(-1.0, 0.2, client, 255, 255, 255, sKeys, 1);
	// =============================================================================================================== //
}

stock bool GetClientCookieBool(int client, Handle cookie)
{
	char sValue[8];
	GetClientCookie(client, cookie, sValue, sizeof(sValue));
	return (sValue[0] != '\0' && StringToInt(sValue));
}

stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	char sValue[8];
	IntToString(value, sValue, sizeof(sValue));
	SetClientCookie(client, cookie, sValue);
}