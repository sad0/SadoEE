--[[
SadoQoL engine builds (John 2026-10-24, SadoEE 1.0 = BGEE + EET on v2.7.3 AND v2.6.6).
The engine patches of SadoQoL were written against v2.7.3 addresses. SQ_Addr(addr) gives the same place on the
running build: itself on v2.7.3 (BGEE, BG2EE / EET share it), the matching address on v2.6.6, nil on an unknown
build (the features then stay off: their byte checks fail and they say so once).
Build detection: CGameSprite::SetModalState's first 16 bytes at its v2.7.3 / v2.6.6 address.
The v2.6.6 table was made by matching each v2.7.3 site in the same function (EEex function_names.db) by its bytes,
relative operands masked (scratch tool port266.py, 2026-10-24); the functions involved are byte-identical.
Loaded before the other M_SQ*.lua files (the 0 in its name).
--]]

SQBuild = SQBuild or {}
local B = SQBuild

local PROBE = { 0x48, 0x89, 0x5C, 0x24, 0x18, 0x48, 0x89, 0x74, 0x24, 0x20, 0x57, 0x48, 0x83, 0xEC, 0x40, 0x0F }
local PROBE_AT = { ['2.7.3.0'] = 0x140374940, ['2.6.6.0'] = 0x140374300 }

B.V266 = {
	[0x14016CAC7] = 0x14016C8B7,
	[0x1401868E0] = 0x1401866D0,
	[0x140186911] = 0x140186701,
	[0x14018691A] = 0x14018670A,
	[0x140186A08] = 0x1401867F8,
	[0x140186A9B] = 0x14018688B,
	[0x140186AA5] = 0x140186895,
	[0x140186B27] = 0x140186917,
	[0x14018AC40] = 0x14018AA30,
	[0x1401B0452] = 0x1401B0242,
	[0x1401BA85F] = 0x1401BA64F,
	[0x140200710] = 0x1402004B0,
	[0x14024C420] = 0x14024C1C0,
	[0x14024D090] = 0x14024CE30,
	[0x14024E900] = 0x14024E6A0,
	[0x14024EA6E] = 0x14024E80E,
	[0x140264113] = 0x140263EB3,
	[0x140264186] = 0x140263F26,
	[0x1402641DF] = 0x140263F7F,
	[0x140264219] = 0x140263FB9,
	[0x140264292] = 0x140264032,
	[0x140264373] = 0x140264113,
	[0x1402644C8] = 0x140264268,
	[0x140264657] = 0x1402643F7,
	[0x140264757] = 0x1402644F7,
	[0x14026480B] = 0x1402645AB,
	[0x140264916] = 0x1402646B6,
	[0x140264AF7] = 0x140264897,
	[0x140265371] = 0x140265111,
	[0x14026A6C0] = 0x14026A460,
	[0x1402AC8D0] = 0x1402AC250,
	[0x1402B385D] = 0x1402B31DD,
	[0x1402B3868] = 0x1402B31E8,
	[0x1402B3AF5] = 0x1402B3475,
	[0x1402F3450] = 0x1402F2E10,
	[0x1402F3460] = 0x1402F2E20,
	[0x1402F4CDD] = 0x1402F469D,
	[0x1402FE8E5] = 0x1402FE2A5,
	[0x140301B00] = 0x1403014C0,
	[0x140301F1A] = 0x1403018DA,
	[0x140301F23] = 0x1403018E3,
	[0x140302620] = 0x140301FE0,
	[0x140374940] = 0x140374300,
	[0x14038662E] = 0x140385FEE,
	[0x140386638] = 0x140385FF8,
	[0x140386805] = 0x1403861C5,
	[0x14038DBBA] = 0x14038D57A,
	[0x14038ECCB] = 0x14038E68B,
	[0x140392AF0] = 0x1403924B0,
	[0x14039C510] = 0x14039BED0,
	[0x1403A93C5] = 0x1403A8D85,
	[0x1403A98A0] = 0x1403A9260,
	[0x1403B0480] = 0x1403AFE40,
	[0x1403B3AA0] = 0x1403B3460,
	[0x1403B48AE] = 0x1403B426E,
	[0x1403B4AF0] = 0x1403B44B0,
	[0x1403B902A] = 0x1403B89EA,
	[0x1403BAA9A] = 0x1403BA45A,
	[0x1403BB905] = 0x1403BB2C5,
}

local function matches(addr)
	local ok, same = pcall(function()
		for i, b in ipairs(PROBE) do
			if EEex_ReadU8(addr + i - 1) % 256 ~= b then return false end
		end
		return true
	end)
	return ok and same
end

if B.build == nil then
	B.build = false
	for build, at in pairs(PROBE_AT) do
		if matches(at) then B.build = build end
	end
	if not B.build then print('[SadoQoL] unknown engine build: the engine patches stay off') end
end

-- the v2.7.3 address `addr` on the running build (nil: unknown build or a site not ported)
function SQ_Addr(addr)
	if B.build == '2.7.3.0' then return addr end
	if B.build == '2.6.6.0' then return B.V266[addr] end
	return nil
end
