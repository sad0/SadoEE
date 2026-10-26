// SadoQoL #19: Withers also brings a new companion into the party (M_SQRECR.lua): created in the game's own
// creation panels, or imported from a character file / saved game. Free.
EXTEND_BOTTOM SQWITHER 0 #1
	IF ~~ THEN REPLY @1250 GOTO sq_recruit
END

APPEND SQWITHER

IF ~~ THEN BEGIN sq_recruit
	SAY @1251
	IF ~~ THEN REPLY @1252 DO ~EEex_LuaAction("SQRecruit_Begin('create')")~ EXIT
	IF ~~ THEN REPLY @1253 DO ~EEex_LuaAction("SQRecruit_Begin('import')")~ EXIT
	IF ~~ THEN REPLY @1254 EXIT
END

END
