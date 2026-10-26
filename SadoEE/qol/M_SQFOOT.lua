--[[
SadoQoL component #7 - Small party footprint (John 2026-10-22).

The party stops jamming in corridors: on the area search map (the grid pathing uses), "bumpable" creatures (the
party, and likely its allies and summons) take 1 square instead of 3x3 (MODE 1), or no square at all (MODE 0:
they walk through everyone and everyone walks through them). Melee reach, selection circles and monsters are
unchanged. (Component #4 shrank the GetPersonalSpace getter itself, which also drives melee reach: abandoned.)

How: the engine stamps a creature's footprint with three functions; each gets the size and the bumpable flag
(party cost 2 per square, others 0x10) as arguments, and uses the same values to add and to remove, so keying the
change on that flag can never leave blocked "ghost" squares:
	CSearchBitmap::AddObject             0x14024C420  (rcx, CPoint* rdx, r8b, size r9b, bumpable [rsp+0x28])
	CSearchBitmap::RemoveObject          0x14024D090  (same arguments)
	CSearchBitmap::SnapshotRemoveObject  0x14024E900  (rcx, CPoint rdx, size r8b, bumpable r9d) - pathing copy
Every size from 0 to 2 stamps one square ((size - 1) / 2 rounds to 0), so MODE 1 caps the size at 1; MODE 0 returns
before anything is stamped. Pure assembly, written once at engine start, before any area is loaded (a creature
already on the map would be removed with the wrong size). Bytes are checked first: another build is left untouched.
MODE is chosen at install time (WeiDU subcomponent); changing it needs a game restart.
--]]

SQFoot = SQFoot or {}
local T = SQFoot

T.MODE = SQ_FOOT_MODE   -- 1 = one square, 0 = no square (set by SadoQoL.tp2)

local ADD, REMOVE, SNAP = SQ_Addr(0x14024C420), SQ_Addr(0x14024D090), SQ_Addr(0x14024E900)
-- push rsi ; push r12 ; sub rsp, 8
local PROLOGUE = { 0x40, 0x56, 0x41, 0x54, 0x48, 0x83, 0xEC, 0x08 }
-- test r8b, r8b ; je 0x14024EA6E
local SNAP_PROLOGUE = { 0x45, 0x84, 0xC0, 0x0F, 0x84, 0x65, 0x01, 0x00, 0x00 }
local SNAP_EXIT = SQ_Addr(0x14024EA6E)

local function bytesAre(addr, list)
	for i, b in ipairs(list) do
		if EEex_ReadU8(addr + i - 1) % 256 ~= b then return false end
	end
	return true
end

local function jumpTo(at, target, size)
	local rel = target - (at + 5)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of jump range') end
	if rel < 0 then rel = rel + 0x100000000 end
	EEex_WriteU8(at, 0xE9)
	for i = 0, 3 do EEex_WriteU8(at + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
	for i = 5, size - 1 do EEex_WriteU8(at + i, 0x90) end
end

-- the size argument becomes 1 (MODE 1) or the function returns at once (MODE 0) when the bumpable flag is set
local function shrink(sizeReg, sizeReg32)
	if T.MODE == 0 then return 'ret #ENDL' end
	return 'cmp ' .. sizeReg .. ', 1 #ENDL jbe sqfoot_keep #ENDL mov ' .. sizeReg32 .. ', 1 #ENDL sqfoot_keep: #ENDL'
end

local function stubAddRemove(addr)
	return EEex_JITNear({[[
		cmp dword ptr ss:[rsp+0x28], 0
		je sqfoot_orig
		]], shrink('r9b', 'r9d'), [[
		sqfoot_orig:
		push rsi
		push r12
		sub rsp, 8
		jmp ]], addr + #PROLOGUE, [[ #ENDL
	]]})
end

local function stubSnap()
	return EEex_JITNear({[[
		test r9d, r9d
		je sqfoot_orig
		]], shrink('r8b', 'r8d'), [[
		sqfoot_orig:
		test r8b, r8b
		je ]], SNAP_EXIT, [[ #ENDL
		jmp ]], SNAP + #SNAP_PROLOGUE, [[ #ENDL
	]]})
end

local function patch()
	if T.status then return end
	if T.MODE ~= 0 and T.MODE ~= 1 then T.status = 'skipped: bad MODE' return end
	if not (bytesAre(ADD, PROLOGUE) and bytesAre(REMOVE, PROLOGUE) and bytesAre(SNAP, SNAP_PROLOGUE)) then
		T.status = 'skipped: unexpected code in CSearchBitmap'
		print('[SadoQoL] small party footprint: ' .. T.status)
		return
	end
	local add, remove, snap = stubAddRemove(ADD), stubAddRemove(REMOVE), stubSnap()
	EEex_DisableCodeProtection()
	jumpTo(ADD, add, #PROLOGUE)
	jumpTo(REMOVE, remove, #PROLOGUE)
	jumpTo(SNAP, snap, #SNAP_PROLOGUE)
	EEex_EnableCodeProtection()
	T.status = 'patched, mode ' .. T.MODE
end

do
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] small party footprint: ' .. T.status) end
end
