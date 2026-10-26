// SadoQoL rest camp: the camp merchant opens Party Stash's camp store PSXCAMP (Party Stash #8).
BEGIN ~SQMERCH~

IF ~True()~ THEN BEGIN sq_hello
	SAY @1116
	IF ~~ THEN REPLY @1117 DO ~StartStore("PSXCAMP",LastTalkedToBy())~ EXIT
	IF ~~ THEN REPLY @1118 EXIT
END
