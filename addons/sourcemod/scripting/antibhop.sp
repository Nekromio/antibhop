#pragma semicolon 1
#pragma newdecls required

ConVar
    cvEnable,
	cvCountJump,
	cvTimer;

bool bActive;

enum struct Settings
{
	Handle hTimerJump;
    bool bEnableJump;
    int iCountJump;
    float fPos[3];

	void Reset()
	{
		this.hTimerJump = null;
		this.bEnableJump = false;
		this.iCountJump = 0;
	}
}

Settings status[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= "Anti-BHop",
	author		= "Nek.'a 2x2 | ggwp.site ",
	description	= "Блокировка распрыжки",
	version		= "1.1.0",
	url			= "ggwp.site || vk.com/nekromio || t.me/sourcepwn "
}

public void OnPluginStart()
{
    cvEnable = CreateConVar("sm_antibhop_enable", "1", "Включить/Выключить плагин", _, true, 0.0, true, 1.0);

	cvCountJump = CreateConVar("sm_antibhop_count", "2", "Количество доступных прыжков подряд", _, true, 0.0, true, 700.0);
	
	cvTimer = CreateConVar("sm_antibhop_timer", "2", "Время через которое сработает восстановление", _, true, 0.0, true, 60.0);

    HookEvent("player_jump", Event_PlayerJump);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("round_start", Event_RoundStart);

    CreateTimer(0.5, Timer_CheckPos, _, TIMER_REPEAT);
	
	AutoExecConfig(true, "antibhop");
}

public void OnClientDisconnect(int client)
{
    delete status[client].hTimerJump;
    status[client].Reset();
}

void Event_RoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    bActive = false;
}

void Event_RoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    bActive = true;
}

void Event_PlayerJump(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    if(!cvEnable.BoolValue)
        return;

    int client = GetClientOfUserId(hEvent.GetInt("userid"));

    if(IsFakeClient(client))
        return;

    status[client].iCountJump++;
    
    if(!status[client].hTimerJump && status[client].iCountJump >= cvCountJump.IntValue)
    {
        status[client].hTimerJump = CreateTimer(cvTimer.FloatValue, Timer_Jump, GetClientUserId(client));
        status[client].bEnableJump = true;
    }
}

Action Timer_Jump(Handle hTimer, any UserID)
{
    int client = GetClientOfUserId(UserID);

    if(!IsClientValid(client))
        return Plugin_Continue;

    status[client].Reset();

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!cvEnable.BoolValue || !IsClientValid(client) || IsFakeClient(client) || !IsPlayerAlive(client) || !bActive)
		return Plugin_Continue;

	if(buttons & IN_JUMP && GetEntityFlags(client) & FL_ONGROUND && status[client].bEnableJump)
	{
        buttons &= ~IN_JUMP;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

bool IsClientValid(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

stock bool CheckSpeed(int client)
{
    float fPos[3];
    GetClientAbsOrigin(client, fPos);

    return false;
}

Action Timer_CheckPos(Handle hTimer)
{
    for (int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i))
    {
        float fCurrentPos[3];
        GetClientAbsOrigin(i, fCurrentPos);

        /* if (HasPlayerMoved(i, fCurrentPos))
        {
            PrintHintTextToAll("Игрок %N двигается.", i);
        }
        else
        {
            PrintHintTextToAll("Игрок %N стоит на месте.", i);
            status[i].bEnableJump = false;
        } */

        if(!HasPlayerMoved(i, fCurrentPos))
            status[i].bEnableJump = false;

        // Сохраняем текущую позицию как предыдущую для следующей проверки.
        status[i].fPos[0] = fCurrentPos[0];
        status[i].fPos[1] = fCurrentPos[1];
        status[i].fPos[2] = fCurrentPos[2];
    }
    return Plugin_Continue;
}

stock bool HasPlayerMoved(int client, float fCurrentPos[3])
{
    // Допустимый порог изменения координат (только по X и Y).
    const float fThreshold = 25.0;

    // Вычисляем расстояние только по осям X и Y.
    float fDistanceSquared = 
        Pow(fCurrentPos[0] - status[client].fPos[0], 2.0) +
        Pow(fCurrentPos[1] - status[client].fPos[1], 2.0);

    // Сравниваем с квадратом порога, чтобы избежать корня.
    return fDistanceSquared > Pow(fThreshold, 2.0);
}