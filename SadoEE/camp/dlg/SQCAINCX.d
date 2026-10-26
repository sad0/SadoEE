// SadoQoL rest camp: the Old Scholar opens the Codex, Party Stash's PSXCHEST page (John 2026-10-24).
// The reply needs PSXCHEST.STO in the game (SQCain_HasCodex in M_SQCAIN.lua).
EXTEND_BOTTOM ~SQCAIN~ 0 #4   // state 0 = sq_hello; before "Farewell"
	IF ~EEex_LuaTrigger("return(SQCain_HasCodex())")~ THEN REPLY @1211 GOTO sq_codex
END

APPEND ~SQCAIN~
IF ~~ THEN BEGIN sq_codex
	SAY @1212
	IF ~~ THEN DO ~StartStore("PSXCHEST",LastTalkedToBy())~ EXIT
END
END
