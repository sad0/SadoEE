// SadoEE options page (John 2026-10-28): Decard, the camp's old scholar, opens it too (M_SQOPT.lua, any SadoEE
// quality of life component). After the Codex (#4) and the quests (#5, added later) replies, before "Farewell".
// No spaces in the Lua chunks (EET strips them); "~=" needs the ~~~~~ delimiters (a ~ ends a ~...~ string).
EXTEND_BOTTOM ~SQCAIN~ 0 #5   // state 0 = sq_hello
	IF ~~~~~EEex_LuaTrigger("return(SQOpt_Open~=nil)")~~~~~ THEN REPLY @1594 GOTO sq_options
END

APPEND ~SQCAIN~
IF ~~ THEN BEGIN sq_options
	SAY @1595
	IF ~~ THEN DO ~EEex_LuaAction("SQOpt_Open()")~ EXIT
END
END
