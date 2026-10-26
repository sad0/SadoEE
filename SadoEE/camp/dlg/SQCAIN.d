// SadoQoL rest camp: Deckard Cain by the fire identifies every unidentified item of the party (+ Party Stash),
// SQCain.PRICE gold each. SQCain_None / _Poor / _Ok (no "==" in triggers: WeiDU breaks the line there) set <SQCAINN>, <SQCAINC>;
// SQCain_Prime sets them (and <SQCAINP>, the price) before the first line. Nothing to identify: the plain reply @1210, and his answer @1167. No spaces in the chunks: the EET engine strips them ("return(x)").
BEGIN ~SQCAIN~

IF ~EEex_LuaTrigger("return(SQCain_Prime())")~ THEN BEGIN sq_hello
	SAY @1161
	IF ~EEex_LuaTrigger("return(SQCain_Ok())")~ THEN REPLY @1162 GOTO sq_offer
	IF ~EEex_LuaTrigger("return(SQCain_Poor())")~ THEN REPLY @1162 GOTO sq_poor
	IF ~EEex_LuaTrigger("return(SQCain_None())")~ THEN REPLY @1210 GOTO sq_none
	IF ~~ THEN REPLY @1170 GOTO sq_story
	IF ~~ THEN REPLY @1172 EXIT
END

IF ~~ THEN BEGIN sq_offer
	SAY @1163
	IF ~~ THEN REPLY @1164 DO ~EEex_LuaAction("SQCain_Identify()")~ GOTO sq_done
	IF ~~ THEN REPLY @1166 EXIT
END

IF ~~ THEN BEGIN sq_done
	SAY @1165
	IF ~~ THEN EXIT
END

IF ~~ THEN BEGIN sq_poor
	SAY @1168
	IF ~~ THEN EXIT
END

IF ~~ THEN BEGIN sq_none
	SAY @1167
	IF ~~ THEN EXIT
END

IF ~~ THEN BEGIN sq_story
	SAY @1171
	IF ~EEex_LuaTrigger("return(SQCain_Any())")~ THEN REPLY @1162 GOTO sq_hello2
	IF ~EEex_LuaTrigger("return(SQCain_None())")~ THEN REPLY @1210 GOTO sq_none
	IF ~~ THEN REPLY @1172 EXIT
END

IF ~~ THEN BEGIN sq_hello2
	SAY @1169
	IF ~EEex_LuaTrigger("return(SQCain_Ok())")~ THEN GOTO sq_offer
	IF ~EEex_LuaTrigger("return(SQCain_Poor())")~ THEN GOTO sq_poor
	IF ~EEex_LuaTrigger("return(SQCain_None())")~ THEN GOTO sq_none
END
