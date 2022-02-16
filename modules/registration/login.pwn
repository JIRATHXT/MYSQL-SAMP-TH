
#include <YSI_Coding\y_hooks>

hook OnGameModeInit()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true); // เชื่อมต่ออัตโนมัติ

	g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, option_id); // AUTO_RECONNECT เปิดสำหรับการเชื่อมต่อนี้เท่านั้น
	if (g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		print("MySQL connection failed. Server is shutting down.");
		SendRconCommand("exit"); // ปิดเซิร์ฟหากเชื่อมต่อไม่ได้
		return 1;
	}

	print("MySQL connection is successful.");

	return 1;
}

hook OnGameModeExit()
{
	// บันทึกข้อมูลให้ผู้เล่นทุกคนเมื่อเซิร์ฟถูกปิดกระทันหัน
	for (new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
	{
		if (IsPlayerConnected(i))
		{
			// สาเหตุการออก ตั้งเป็น (1) เป็นค่าเริ่มต้น

			// OnPlayerDisconnect(i, 1); (Function นี้ทำให้ SSCANF2 มีปัญหา)
            IfPlayerDisconnect(i, 1);
		}
	}

	mysql_close(g_SQL);
	return 1;
}

hook OnPlayerConnect(playerid)
{
	g_MysqlRaceCheck[playerid]++;

	// รีเซ็ตข้อมูลผู้เล่น
	static const empty_player[E_PLAYERS];
	Player[playerid] = empty_player;

	GetPlayerName(playerid, Player[playerid][Name], MAX_PLAYER_NAME);

	// สร้าง ORM รับค่าจากฐานข้อมูลมาใส่ตัวแปร
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

	// บอกให้ระบบ ORM โหลดข้อมูลทั้งหมด กำหนดให้กับตัวแปรของเรา และ Callback เมื่อพร้อม
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
	// กำหนดจุดเกิด
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
        // เมื่อรหัสผ่านถูกต้องผู้เล่นจะ Spawn
        Dialog_Show(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have been successfully logged in.", "Okay", "");

        KillTimer(Player[playerid][LoginTimer]);
        Player[playerid][LoginTimer] = 0;
        Player[playerid][IsLoggedIn] = true;

        // Spawn ในจุดที่ผู้เล่นเคยมาก่อนหน้า
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

    // ใช้ Whirlpool ในการสร้างการเข้ารหัสเพื่อความปลอดภัยของรหัสผ่าน
    new buf[250];
    WP_Hash(buf, sizeof(buf), inputtext);
    Player[playerid][Password] = buf;
    // ส่งข้อมูลไปยัง Query
    orm_save(Player[playerid][ORM_ID], "OnPlayerRegister", "d", playerid);
    return 1;
}

//-----------------------------------------------------

forward OnPlayerDataLoaded(playerid, race_check);
public OnPlayerDataLoaded(playerid, race_check)
{
	/* ตรวจสอบสภาพการแข่งขัน:
        ผู้เล่น A เชื่อมต่อ -> แบบสอบถาม SELECT เริ่มทำงาน -> แบบสอบถามนี้ใช้เวลานานมาก
        ในขณะที่คำค้นหายังดำเนินการอยู่ ผู้เล่น A ที่มี ID ผู้เล่น 2 ถูกตัดการเชื่อมต่อ
        ผู้เล่น B เข้าร่วมตอนนี้ด้วย playerid 2 -> แบบสอบถาม SELECT ที่ล่าช้าของเราในที่สุดก็เสร็จสิ้น แต่สำหรับผู้เล่นที่ไม่ถูกต้อง

        เราจะทำอย่างไรกับมัน?
        เราสร้างจำนวนการเชื่อมต่อสำหรับ ID ผู้เล่นแต่ละคนและเพิ่มทุกครั้งที่ ID ผู้เล่นเชื่อมต่อหรือตัดการเชื่อมต่อ
        เรายังส่งค่าปัจจุบันของจำนวนการเชื่อมต่อไปยังการ Callback OnPlayerDataLoaded ของเราด้วย
        จากนั้นเราจะตรวจสอบว่าจำนวนการเชื่อมต่อปัจจุบันเท่ากับจำนวนการเชื่อมต่อที่เราส่งไปยังการ Callback หรือไม่
        ถ้าใช่ ทุกอย่างโอเค ถ้าไม่ เราก็แค่เตะผู้เล่น
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

			// เมื่อผู้เล่นใช้เวลาเกิน 30 วินาที
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
	// รีเซ็ตการนับเวลาให้กลายเป็น (0)
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

	// หากไคลเอนต์ขัดข้อง จะไม่สามารถรับตำแหน่งของผู้เล่นในการ Callback ของ OnPlayerDisconnect
	// ดังนั้นเราจะใช้ตำแหน่งที่เซฟไว้ล่าสุด (กรณีผู้เล่นที่ลงทะเบียนแล้วชน/เตะ ตำแหน่งจะเป็นจุดเกิดเริ่มต้น)
	if (reason == 1)
	{
		GetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
		GetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
	}

	// สิ่งสำคัญคือต้องเก็บทุกอย่างไว้ในตัวแปรที่ลงทะเบียนในอินสแตนซ์ ORM
	Player[playerid][Interior] = GetPlayerInterior(playerid);

	// orm_save ส่งไปอัพเดต Query
	orm_save(Player[playerid][ORM_ID]);
	orm_destroy(Player[playerid][ORM_ID]);
	return 1;
}

IfPlayerDisconnect(playerid, reason)
{
    g_MysqlRaceCheck[playerid]++;

	UpdatePlayerData(playerid, reason);

	// ผู้เล่นจะถูกเตะเมื่อใช้เวลามากกว่า 30 วินาที
	if (Player[playerid][LoginTimer])
	{
		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
	}

	// ตั้งค่า "IsLoggedIn" เป็น False เมื่อผู้เล่นตัดการเชื่อมต่อ 
	Player[playerid][IsLoggedIn] = false;
    return 1;
}
