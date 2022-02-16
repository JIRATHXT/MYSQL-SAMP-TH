
#include <YSI_Coding\y_hooks>

hook OnGameModeInit()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true); // ���������ѵ��ѵ�

	g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, option_id); // AUTO_RECONNECT �Դ����Ѻ����������͹����ҹ��
	if (g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		print("MySQL connection failed. Server is shutting down.");
		SendRconCommand("exit"); // �Դ�����ҡ�������������
		return 1;
	}

	print("MySQL connection is successful.");

	return 1;
}

hook OnGameModeExit()
{
	// �ѹ�֡�������������蹷ء����������쿶١�Դ��зѹ�ѹ
	for (new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
	{
		if (IsPlayerConnected(i))
		{
			// ���˵ء���͡ ����� (1) �繤���������

			// OnPlayerDisconnect(i, 1); (Function ������� SSCANF2 �ջѭ��)
            IfPlayerDisconnect(i, 1);
		}
	}

	mysql_close(g_SQL);
	return 1;
}

hook OnPlayerConnect(playerid)
{
	g_MysqlRaceCheck[playerid]++;

	// ���絢����ż�����
	static const empty_player[E_PLAYERS];
	Player[playerid] = empty_player;

	GetPlayerName(playerid, Player[playerid][Name], MAX_PLAYER_NAME);

	// ���ҧ ORM �Ѻ��Ҩҡ�ҹ���������������
	new ORM: ormid = Player[playerid][ORM_ID] = orm_create("players", g_SQL);

	orm_addvar_int(ormid, Player[playerid][ID], "id");
	orm_addvar_string(ormid, Player[playerid][Name], MAX_PLAYER_NAME, "username");
	orm_addvar_string(ormid, Player[playerid][Password], 65, "password");
	orm_addvar_float(ormid, Player[playerid][X_Pos], "x");
	orm_addvar_float(ormid, Player[playerid][Y_Pos], "y");
	orm_addvar_float(ormid, Player[playerid][Z_Pos], "z");
	orm_addvar_float(ormid, Player[playerid][A_Pos], "angle");
	orm_addvar_int(ormid, Player[playerid][Interior], "interior");
	orm_setkey(ormid, "username");

	// �͡����к� ORM ��Ŵ�����ŷ����� ��˹����Ѻ����âͧ��� ��� Callback ����;����
	orm_load(ormid, "OnPlayerDataLoaded", "dd", playerid, g_MysqlRaceCheck[playerid]);
	return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
	IfPlayerDisconnect(playerid, reason);
	return 1;
}

hook OnPlayerSpawn(playerid)
{
	// ��˹��ش�Դ
	SetPlayerInterior(playerid, Player[playerid][Interior]);
	SetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
	SetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);

	SetCameraBehindPlayer(playerid);
	return 1;
}

hook OnPlayerDeath(playerid, killerid, reason)
{

	return 1;
}

Dialog:DIALOG_LOGIN(playerid, response, listitem, inputtext[])
{
    if (!response) return Kick(playerid);

    new buf[211];
    WP_Hash(buf, sizeof(buf), inputtext);

    if (strcmp(buf, Player[playerid][Password]) == 0)
    {
        // ��������ʼ�ҹ�١��ͧ�����蹨� Spawn
        Dialog_Show(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have been successfully logged in.", "Okay", "");

        KillTimer(Player[playerid][LoginTimer]);
        Player[playerid][LoginTimer] = 0;
        Player[playerid][IsLoggedIn] = true;

        // Spawn 㹨ش�����������ҡ�͹˹��
        SetSpawnInfo(playerid, NO_TEAM, 0, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
        SpawnPlayer(playerid);
    }
    else
    {
        Player[playerid][LoginAttempts]++;

        if (Player[playerid][LoginAttempts] >= 3)
        {
            Dialog_Show(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have mistyped your password too often (3 times).", "Okay", "");
            DelayedKick(playerid);
        }
        else Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Wrong password!\nPlease enter your password in the field below:", "Login", "Abort");
    }
    return 1;
}

Dialog:DIALOG_REGISTER(playerid, response, listitem, inputtext[])
{
    if (!response) return Kick(playerid);

    if (strlen(inputtext) <= 5) return Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", "Your password must be longer than 5 characters!\nPlease enter your password in the field below:", "Register", "Abort");

    // �� Whirlpool 㹡�����ҧ�������������ͤ�����ʹ��¢ͧ���ʼ�ҹ
    new buf[250];
    WP_Hash(buf, sizeof(buf), inputtext);
    Player[playerid][Password] = buf;
    // �觢�������ѧ Query
    orm_save(Player[playerid][ORM_ID], "OnPlayerRegister", "d", playerid);
    return 1;
}

//-----------------------------------------------------

forward OnPlayerDataLoaded(playerid, race_check);
public OnPlayerDataLoaded(playerid, race_check)
{
	/* ��Ǩ�ͺ��Ҿ����觢ѹ:
        ������ A �������� -> Ẻ�ͺ��� SELECT ������ӧҹ -> Ẻ�ͺ�����������ҹҹ�ҡ
        㹢�з��Ӥ����ѧ���Թ������� ������ A ����� ID ������ 2 �١�Ѵ�����������
        ������ B ��������͹������ playerid 2 -> Ẻ�ͺ��� SELECT �����Ҫ�Ңͧ���㹷���ش��������� ������Ѻ�����蹷�����١��ͧ

        ��Ҩз����ҧ�áѺ�ѹ?
        ������ҧ�ӹǹ���������������Ѻ ID ���������Ф���������ء���駷�� ID �����������������͵Ѵ�����������
        ����ѧ�觤�һѨ�غѹ�ͧ�ӹǹ�������������ѧ��� Callback OnPlayerDataLoaded �ͧ��Ҵ���
        �ҡ�����Ҩе�Ǩ�ͺ��Ҩӹǹ����������ͻѨ�غѹ��ҡѺ�ӹǹ����������ͷ���������ѧ��� Callback �������
        ����� �ء���ҧ��� ������ ��ҡ����м�����
    */
	if (race_check != g_MysqlRaceCheck[playerid]) return Kick(playerid);

	orm_setkey(Player[playerid][ORM_ID], "id");

	new string[115];
	switch (orm_errno(Player[playerid][ORM_ID]))
	{
		case ERROR_OK:
		{
			format(string, sizeof string, "This account (%s) is registered. Please login by entering your password in the field below:", Player[playerid][Name]);
			Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", string, "Login", "Abort");

			// ����ͼ������������Թ 30 �Թҷ�
			Player[playerid][LoginTimer] = SetTimerEx("OnLoginTimeout", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
		}
		case ERROR_NO_DATA:
		{
			format(string, sizeof string, "Welcome %s, you can register by entering your password in the field below:", Player[playerid][Name]);
			Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", string, "Register", "Abort");
		}
	}
	return 1;
}

forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
	// ���絡�ùѺ������������ (0)
	Player[playerid][LoginTimer] = 0;

	Dialog_Show(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have been kicked for taking too long to login successfully to your account.", "Okay", "");
	DelayedKick(playerid);
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	Dialog_Show(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Registration", "Account successfully registered, you have been automatically logged in.", "Okay", "");

	Player[playerid][IsLoggedIn] = true;

	Player[playerid][X_Pos] = DEFAULT_POS_X;
	Player[playerid][Y_Pos] = DEFAULT_POS_Y;
	Player[playerid][Z_Pos] = DEFAULT_POS_Z;
	Player[playerid][A_Pos] = DEFAULT_POS_A;

	SetSpawnInfo(playerid, NO_TEAM, 0, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

forward _KickPlayerDelayed(playerid);
public _KickPlayerDelayed(playerid)
{
	Kick(playerid);
	return 1;
}


//-----------------------------------------------------

DelayedKick(playerid, time = 500)
{
	SetTimerEx("_KickPlayerDelayed", time, false, "d", playerid);
	return 1;
}

UpdatePlayerData(playerid, reason)
{
	if (Player[playerid][IsLoggedIn] == false) return 0;

	// �ҡ���͹��Ѵ��ͧ ���������ö�Ѻ���˹觢ͧ������㹡�� Callback �ͧ OnPlayerDisconnect
	// �ѧ�����Ҩ�����˹觷��૿�������ش (�óռ����蹷��ŧ����¹���Ǫ�/�� ���˹觨��繨ش�Դ�������)
	if (reason == 1)
	{
		GetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
		GetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
	}

	// ����Ӥѭ��͵�ͧ�纷ء���ҧ���㹵���÷��ŧ����¹��Թ�ᵹ�� ORM
	Player[playerid][Interior] = GetPlayerInterior(playerid);

	// orm_save ����Ѿവ Query
	orm_save(Player[playerid][ORM_ID]);
	orm_destroy(Player[playerid][ORM_ID]);
	return 1;
}

IfPlayerDisconnect(playerid, reason)
{
    g_MysqlRaceCheck[playerid]++;

	UpdatePlayerData(playerid, reason);

	// �����蹨ж١��������������ҡ���� 30 �Թҷ�
	if (Player[playerid][LoginTimer])
	{
		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
	}

	// ��駤�� "IsLoggedIn" �� False ����ͼ����蹵Ѵ����������� 
	Player[playerid][IsLoggedIn] = false;
    return 1;
}
