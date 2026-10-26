--[[
SadoQoL rest camp on BG2EE (John 2026-10-25): where things stand in SQCAMP when it is the crop of OH5300, the Helmite
Camp. WRITTEN BY tools/build_camp_bg2.py (edit the numbers there: the ARE uses the same). Installed with the BG2EE
camp only: without it (BGEE / EET, the BD5000 crop) the camp Lua keeps its own BD5000 spots.
Loaded before the camp files (the 0 in its name). Points are { x, y } or { x, y, facing } (0 south, 4 west, 8 north).
--]]

SQCampSite = {
	ENTRY   = { 1594, 176 },   -- on the road between the two exits (the party arrives here)
	-- travel regions of SQCAMP.ARE (same order): the road's north end, its east end
	EXITS   = {
		{ { 1152, 0 }, { 1450, 0 }, { 1450, 80 }, { 1152, 80 } },
		{ { 1711, 176 }, { 1791, 176 }, { 1791, 420 }, { 1711, 420 } },
	},
	FIRE    = { 908, 609 },
	PRIEST  = { 791, 306, 0 },
	MERCH   = { 494, 486, 14 },
	CAIN    = { 972, 552, 2 },
	WITHERS = { 1344, 236, 2 },
	RECRUIT = { 1304, 266 },
	NECRO   = { 1324, 726, 12 },
	NECRO_CENTER = { 1524, 716 },
}
