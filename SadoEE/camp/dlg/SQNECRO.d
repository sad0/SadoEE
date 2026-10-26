// SadoQoL rest camp: the necromancer raises target dummies (M_SQNECR.lua). The "how many?" state comes first: it
// opens when a creature was just picked in the bestiary (SQNecro_Picking). No spaces or "==" in the Lua triggers.
BEGIN ~SQNECRO~

IF ~EEex_LuaTrigger("return(SQNecro_Picking())")~ THEN BEGIN sq_count
	SAY @1304
	IF ~~ THEN REPLY @1305 DO ~EEex_LuaAction("SQNecro_Spawn(1)")~ EXIT
	IF ~~ THEN REPLY @1306 DO ~EEex_LuaAction("SQNecro_Spawn(2)")~ EXIT
	IF ~~ THEN REPLY @1307 DO ~EEex_LuaAction("SQNecro_Spawn(3)")~ EXIT
	IF ~~ THEN REPLY @1308 DO ~EEex_LuaAction("SQNecro_Spawn(5)")~ EXIT
	IF ~~ THEN REPLY @1309 DO ~EEex_LuaAction("SQNecro_Spawn(10)")~ EXIT
	IF ~~ THEN REPLY @1310 DO ~EEex_LuaAction("SQNecro_Cancel()")~ EXIT
END

IF ~True()~ THEN BEGIN sq_hello
	SAY @1298
	IF ~~ THEN REPLY @1299 DO ~EEex_LuaAction("SQNecro_OpenMenu()")~ EXIT
	IF ~EEex_LuaTrigger("return(SQNecro_AnyUndying())")~ THEN REPLY @1300 DO ~EEex_LuaAction("SQNecro_Unleash()")~ GOTO sq_done
	IF ~EEex_LuaTrigger("return(SQNecro_AnyUnleashed())")~ THEN REPLY @1301 DO ~EEex_LuaAction("SQNecro_Calm()")~ GOTO sq_done
	IF ~EEex_LuaTrigger("return(SQNecro_Any())")~ THEN REPLY @1302 DO ~EEex_LuaAction("SQNecro_CleanUp()")~ GOTO sq_done
	IF ~EEex_LuaTrigger("return(SQNecro_Any())")~ THEN REPLY @1311 DO ~EEex_LuaAction("SQNecro_Join()")~ GOTO sq_done
	IF ~~ THEN REPLY @1303 EXIT
END

IF ~~ THEN BEGIN sq_done
	SAY @1312
	IF ~~ THEN EXIT
END
