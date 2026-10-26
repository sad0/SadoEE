// SadoQoL: an ex-member asks whether to wait at the rest camp (right after leaving the party); a player-created
// character keeps this dialogue while he waits, and its second state brings him back.
BEGIN ~SQKICK~

IF ~EEex_LuaTrigger("return(SQWait_Asking())")~ THEN BEGIN sq_ask
	SAY @1180
	IF ~~ THEN REPLY @1181 DO ~EEex_LuaAction("SQWait_ToCamp()")~ EXIT
	IF ~~ THEN REPLY @1182 DO ~EEex_LuaAction("SQWait_Stay()")~ EXIT
END

IF ~True()~ THEN BEGIN sq_back
	SAY @1183
	IF ~~ THEN REPLY @1184 DO ~EEex_LuaAction("SQWait_Join()")~ EXIT
	IF ~~ THEN REPLY @1185 EXIT
END
