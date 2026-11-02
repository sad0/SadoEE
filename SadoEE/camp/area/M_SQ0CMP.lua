--[[
SadoQoL rest camp: where things stand in SQCAMP when it is a Camp Map 3D map (E:/AI/bg3d). WRITTEN BY
E:/AI/bg3d/tools/build_camp3d.py from the editor's spots (the ARE uses the same numbers). Points are { x, y } or
{ x, y, facing } (0 south, 4 west, 8 north, 12 east).
--]]

SQCampSite = {
	ENTRY   = { 210, 1140, 12 },
	EXITS   = {
		{ { 0, 982 }, { 109, 982 }, { 109, 1241 }, { 0, 1241 } },
	},
	FIRE         = { 1392, 971 },
	PRIEST       = { 1464, 792, 0 },
	MERCH        = { 989, 898, 12 },
	CAIN         = { 1754, 918, 2 },
	WITHERS      = { 1097, 729, 14 },
	RECRUIT      = { 1079, 1149 },
	NECRO        = { 1680, 1166, 6 },
	NECRO_CENTER = { 2012, 1076 },
}

-- the camp's lasting sight (John 2026-11-02): no fog inside this ellipse around the fire, like a permanent Farsight with no
-- effect shown. { x, y, radius x, radius y } in area pixels (a 18.7 m ground circle seen at 38 degrees). SadoQoL keeps it lit.
SQCampSite.VISION = { 1392, 971, 785, 484 }
