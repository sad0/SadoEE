// Quest chronicle (John 2026-10-24): Decard, the camp's old scholar (SadoQoL / SadoEE SQCAIN), opens the quest page.
// After his Codex reply when it is there (#4), before "Farewell". No spaces in the Lua chunks (EET strips them).
EXTEND_BOTTOM ~SQCAIN~ 0 #5   // state 0 = sq_hello
	IF ~EEex_LuaTrigger("return(PSXQ_Installed())")~ THEN REPLY @1 GOTO psxq_quests
END

APPEND ~SQCAIN~
IF ~~ THEN BEGIN psxq_quests
	SAY @2
	IF ~~ THEN DO ~EEex_LuaAction("PSXQ_Open()")~ EXIT
END
END
