// SadoQoL rest camp: the priestess by the fire (John 2026-10-24): no store, two services (M_SQPRST.lua).
// A donation buying the next reputation point (the game's temple rule) and the healing of the whole party at the
// temple prices, total shown in the reply. HP / poison / disease are free (@1340, John 2026-10-25). Triggers without spaces or "==" (EEex_LuaTrigger on EET, WeiDU).
BEGIN ~SQPRIEST~

IF ~EEex_LuaTrigger("return(SQPriest_Prime())")~ THEN BEGIN sq_hello
	SAY @1110
	IF ~EEex_LuaTrigger("return(SQPriest_RepOk())")~ THEN REPLY @1286 DO ~EEex_LuaAction("SQPriest_Donate()")~ GOTO sq_donated
	IF ~EEex_LuaTrigger("return(SQPriest_RepPoor())")~ THEN REPLY @1286 GOTO sq_poor
	IF ~EEex_LuaTrigger("return(SQPriest_FreeAny())")~ THEN REPLY @1340 DO ~EEex_LuaAction("SQPriest_FreeHeal()")~ GOTO sq_tended
	IF ~EEex_LuaTrigger("return(SQPriest_HealOk())")~ THEN REPLY @1287 DO ~EEex_LuaAction("SQPriest_Heal()")~ GOTO sq_healed
	IF ~EEex_LuaTrigger("return(SQPriest_HealPoor())")~ THEN REPLY @1287 GOTO sq_poor
	IF ~~ THEN REPLY @1112 EXIT
END

IF ~~ THEN BEGIN sq_donated
	SAY @1288
	IF ~~ THEN EXIT
END

IF ~~ THEN BEGIN sq_healed
	SAY @1289
	IF ~~ THEN EXIT
END

IF ~~ THEN BEGIN sq_tended
	SAY @1341
	IF ~~ THEN EXIT
END

IF ~~ THEN BEGIN sq_poor
	SAY @1290
	IF ~~ THEN EXIT
END
