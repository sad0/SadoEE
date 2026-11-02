// SadoQoL rest camp: Faceless (Sans-Visage, Withers' replacement since SadoEE 1.03; the creature is still SQWITHER)
// recreates the party member who talks to him (SQRespec_BeginSelected), free.
BEGIN ~SQWITHER~

IF ~True()~ THEN BEGIN sq_hello
	SAY @1401
	// everyone may be remade (John 2026-10-25); a monster starts at the class step, race kept (M_SQRESP.lua opts.necro)
	IF ~~ THEN REPLY @1402 GOTO sq_warn
	IF ~~ THEN REPLY @1404 EXIT
END

IF ~~ THEN BEGIN sq_warn
	SAY @1405
	IF ~~ THEN REPLY @1406 DO ~EEex_LuaAction("SQRespec_BeginSelected()")~ EXIT
	IF ~~ THEN REPLY @1407 EXIT
END
