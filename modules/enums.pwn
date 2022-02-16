// ข้อมูลผู้เล่น
enum E_PLAYERS
{
	ORM: ORM_ID,

	ID,
	Name[MAX_PLAYER_NAME],
	Password[250], 
	Float: X_Pos,
	Float: Y_Pos,
	Float: Z_Pos,
	Float: A_Pos,
	Interior,

	bool: IsLoggedIn,
	LoginAttempts,
	LoginTimer
};
new Player[MAX_PLAYERS][E_PLAYERS];