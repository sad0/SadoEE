// SadoQoL #19: Faceless (ex-Withers) also brings a new companion into the party (M_SQRECR.lua): created in the game's own
// creation panels, or imported from a character file / saved game. Free.
EXTEND_BOTTOM SQWITHER 0 #1
	IF ~~ THEN REPLY @1403 GOTO sq_recruit
END

APPEND SQWITHER

IF ~~ THEN BEGIN sq_recruit
	SAY @1408
	IF ~~ THEN REPLY @1409 DO ~EEex_LuaAction("SQRecruit_BeginCreate()")~ EXIT
	IF ~~ THEN REPLY @1410 DO ~EEex_LuaAction("SQRecruit_BeginImport()")~ EXIT
	IF ~~ THEN REPLY @1411 EXIT
END

END
