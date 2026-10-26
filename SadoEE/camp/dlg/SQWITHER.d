// SadoQoL rest camp: Withers recreates the party member who talks to him (SQRespec_BeginSelected), free.
BEGIN ~SQWITHER~

IF ~True()~ THEN BEGIN sq_hello
	SAY @1190
	// everyone may be remade (John 2026-10-25); a monster starts at the class step, race kept (M_SQRESP.lua opts.necro)
	IF ~~ THEN REPLY @1191 GOTO sq_warn
	IF ~~ THEN REPLY @1192 EXIT
END

IF ~~ THEN BEGIN sq_warn
	SAY @1193
	IF ~~ THEN REPLY @1194 DO ~EEex_LuaAction("SQRespec_BeginSelected()")~ EXIT
	IF ~~ THEN REPLY @1195 EXIT
END
