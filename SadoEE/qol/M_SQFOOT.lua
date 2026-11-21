--[[
SadoQoL component #7 - Small party footprint (John 2026-10-22, v2 2026-11-21).

The party stops jamming in corridors: on the area search map (the grid pathing uses), the party and its allies
take 1 square instead of 3x3 (MODE 1), or no square at all (MODE 0: they walk through everyone and everyone walks
through them). Melee reach, selection circles and monsters are unchanged. (Component #4 shrank the GetPersonalSpace
getter itself, which also drives melee reach: abandoned.)

How: the engine stamps a creature's footprint with three functions; each gets the size and a flag (the creature's
stored "bumpable" state, sprite +0x492C), and uses the same pair to add and to remove:
	CSearchBitmap::AddObject             0x14024C420  (rcx, CPoint* rdx, EA r8b, size r9b, flag [rsp+0x28])
	CSearchBitmap::RemoveObject          0x14024D090  (same arguments)
	CSearchBitmap::SnapshotRemoveObject  0x14024E900  (rcx, CPoint rdx, size r8b, flag r9d) - pathing copy
Every size from 0 to 2 stamps one square ((size - 1) / 2 rounds to 0), so MODE 1 caps the size at 1; MODE 0 returns
before anything is stamped. The change depends only on (size, flag), never on the EA (it can change while a stamp
is down: CGameSprite::Enemy), so a stamp is always removed exactly as it was added.

v2 (BeardyBandit's report: members stacked on one spot, stuck for ages): v1 only shrank idle members (flag 1).
A WALKING party member is not bumpable (flag 0) and stamped a full 3x3 wall; two members on one square were each
inside the other's wall, so every step failed (25-tick wait, re-path, forever). Now CheckBumpable's call in
CGameSprite::AIUpdate (0x140345699) returns a third value, 2 = "party walker" (not bumpable, EA <= 30): stamped
like a walker (non-bumpable counter) but with the small size. The two engine tests of that flag that mean
"bumpable" were "flag != 0"; they become "flag == 1":
	AIUpdate bump-state cancel  0x1403456E6  (test edi,edi / jne ; cmp [rbx+0x4930],sil / je) -> stub
	ClearBumpPath target test   0x14034F5A3  (cmp dword [r13+0x492C],0 / je) -> cmp ...,1 / jne
Pure assembly, written once at engine start, before any area is loaded. Bytes are checked first: another build is
left untouched. MODE is chosen at install time (WeiDU subcomponent); changing it needs a game restart.
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

-- CGameSprite::AIUpdate: call CGameSprite::CheckBumpable ; mov edi, eax
local BUMP_CALL, CHECK_BUMPABLE = SQ_Addr(0x140345699), SQ_Addr(0x14034C3A0)
local BUMP_CALL_BYTES = { 0xE8, 0x02, 0x6D, 0x00, 0x00, 0x8B, 0xF8 }
-- test edi, edi ; jne +0x2E ; cmp byte [rbx+0x4930], sil ; je +0x25
local CANCEL, CANCEL_SKIP, CANCEL_DO = SQ_Addr(0x1403456E6), SQ_Addr(0x140345718), SQ_Addr(0x1403456F3)
local CANCEL_BYTES = { 0x85, 0xFF, 0x75, 0x2E, 0x40, 0x38, 0xB3, 0x30, 0x49, 0x00, 0x00, 0x74, 0x25 }
-- CGameSprite::ClearBumpPath: cmp dword [r13+0x492C], 0 ; je ...
local CLEAR_TEST = SQ_Addr(0x14034F5A3)
local CLEAR_BYTES = { 0x41, 0x83, 0xBD, 0x2C, 0x49, 0x00, 0x00, 0x00, 0x0F, 0x84 }

local function bytesAre(addr, list)
	if not addr then return false end
	for i, b in ipairs(list) do
		if EEex_ReadU8(addr + i - 1) % 256 ~= b then return false end
	end
	return true
end

local function writeRel(at, op, target, size)
	local rel = target - (at + 5)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of jump range') end
	if rel < 0 then rel = rel + 0x100000000 end
	EEex_WriteU8(at, op)
	for i = 0, 3 do EEex_WriteU8(at + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
	for i = 5, size - 1 do EEex_WriteU8(at + i, 0x90) end
end
local function jumpTo(at, target, size) writeRel(at, 0xE9, target, size) end

-- flag 2 (party walker) is stamped as a walker (flag 0) with the small size; flag 1 (bumpable) keeps its flag
local function stubAddRemove(addr)
	local body
	if T.MODE == 0 then
		body = 'ret #ENDL'
	else
		body = [[
			cmp eax, 2
			jne sqfoot_shrink
			mov dword ptr ss:[rsp+0x28], 0
			sqfoot_shrink:
			cmp r9b, 1
			jbe sqfoot_orig
			mov r9d, 1
		]]
	end
	return EEex_JITNear({[[
		mov eax, dword ptr ss:[rsp+0x28]
		test eax, eax
		je sqfoot_orig
		]], body, [[
		sqfoot_orig:
		push rsi
		push r12
		sub rsp, 8
		jmp ]], addr + #PROLOGUE, [[ #ENDL
	]]})
end

local function stubSnap()
	local body
	if T.MODE == 0 then
		body = 'ret #ENDL'
	else
		body = [[
			cmp r9d, 2
			jne sqfoot_shrink
			xor r9d, r9d
			sqfoot_shrink:
			cmp r8b, 1
			jbe sqfoot_orig
			mov r8d, 1
		]]
	end
	return EEex_JITNear({[[
		test r9d, r9d
		je sqfoot_orig
		]], body, [[
		sqfoot_orig:
		test r8b, r8b
		je ]], SNAP_EXIT, [[ #ENDL
		jmp ]], SNAP + #SNAP_PROLOGUE, [[ #ENDL
	]]})
end

-- CheckBumpable as called by AIUpdate: 0 becomes 2 for the party and its allies (EA <= 30), rbx = sprite
local function stubBump()
	return EEex_JITNear({[[
		sub rsp, 0x28
		call ]], CHECK_BUMPABLE, [[ #ENDL
		add rsp, 0x28
		test eax, eax
		jnz sqfoot_bump_ret
		cmp byte ptr ds:[rbx+0x38], 0x1E
		ja sqfoot_bump_ret
		mov eax, 2
		sqfoot_bump_ret:
		ret
	]]})
end

-- AIUpdate's bump-state cancel ran for "not bumpable" (flag 0): it must run for flag 2 too
local function stubCancel()
	return EEex_JITNear({[[
		cmp edi, 1
		je ]], CANCEL_SKIP, [[ #ENDL
		cmp byte ptr ds:[rbx+0x4930], sil
		je ]], CANCEL_SKIP, [[ #ENDL
		jmp ]], CANCEL_DO, [[ #ENDL
	]]})
end

local function patch()
	if T.status and not T.HOT then return end
	if T.MODE ~= 0 and T.MODE ~= 1 then T.status = 'skipped: bad MODE' return end
	-- T.HOT (dev hot reload over v1): the three entries already jump to v1 stubs
	local entriesOk = T.HOT or (bytesAre(ADD, PROLOGUE) and bytesAre(REMOVE, PROLOGUE) and bytesAre(SNAP, SNAP_PROLOGUE))
	if not (entriesOk and bytesAre(BUMP_CALL, BUMP_CALL_BYTES) and bytesAre(CANCEL, CANCEL_BYTES)
		and bytesAre(CLEAR_TEST, CLEAR_BYTES)) then
		T.status = 'skipped: unexpected engine code'
		print('[SadoQoL] small party footprint: ' .. T.status)
		return
	end
	local add, remove, snap = stubAddRemove(ADD), stubAddRemove(REMOVE), stubSnap()
	local bump, cancel = stubBump(), stubCancel()
	EEex_DisableCodeProtection()
	jumpTo(ADD, add, #PROLOGUE)
	jumpTo(REMOVE, remove, #PROLOGUE)
	jumpTo(SNAP, snap, #SNAP_PROLOGUE)
	writeRel(BUMP_CALL, 0xE8, bump, 5)
	jumpTo(CANCEL, cancel, #CANCEL_BYTES)
	EEex_WriteU8(CLEAR_TEST + 7, 0x01)   -- cmp dword [r13+0x492C], 1
	EEex_WriteU8(CLEAR_TEST + 9, 0x85)   -- jne: a target is bumpable only with flag 1
	EEex_EnableCodeProtection()
	T.HOT = nil
	T.status = 'patched v2, mode ' .. T.MODE
end

do
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] small party footprint: ' .. T.status) end
end
