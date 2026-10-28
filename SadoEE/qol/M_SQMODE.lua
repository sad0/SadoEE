--[[
SadoQoL component #9 - Lasting modes (John 2026-10-23).

Bard song, turn undead, stealth and shaman dance stay on while the character attacks, casts, uses an item, talks or
moves: the action-bar button still toggles them, they just stop being cancelled by everything else. The engine keeps
applying their per-round effects (CGameSprite::CheckModal never looks at the current action). Everyone benefits,
enemies too (John's choice). The Find Traps button no longer starts the engine mode: it toggles SadoQoL's passive
trap detection (#0) for that thief, so a thief can stay in stealth and keep detecting traps.

Engine patches (bytes checked first; another build is left untouched, SQMode.status says why):
 1. CGameSprite::SetCurrAction: a new action other than walking/waiting called SetModalState(0) at 0x1403B3AA0.
    That call is NOPed. Stealth's "already hidden" flag (+0x4E50, lets the re-roll ignore visible enemies) is left
    alone: clearing it on every action made the thief fail every re-roll near enemies and stay visible.
 2. CInfButtonArray / CScreenWorld: 13 calls SetModalState(0) on a button click (attack, spell, item, quick slots,
    talk, guard, thieving, special abilities, spell hotkey, picking up an item) -> NOPed.
 3. CheckModal stealth re-roll failure: no cancel, the thief rolls again 3 rounds later (0x14038DBBA).
 4. Movement-rate modal effect (opcode 363, shaman dance): no cancel when moving (0x1401BA85F je -> jmp).
 5. Find Traps button handler 0x140264916 -> SQMode_ToggleTraps(sprite) then the handler's normal exit.
 5b. CheckModal's per-round feedback "Singing Bard Song" (0x14038E6AA, song and dance) and "Turning Undead"
    (0x14038D2B4) -> NOPed. In vanilla a bard stops singing as soon as he acts, so it was barely seen; with lasting
    modes it filled the log every round (Garrick, 2026-10-28). The portrait icon and the action bar still show it.
Patches apply once per game run, at engine start or when this file is first run.
--]]

SQMode = SQMode or {}
local T = SQMode

T.TRAP_ON = tonumber("SQ_MODE_TRAP_ON_STRREF")    -- "Trap detection: on" (SadoQoL.tp2)
T.TRAP_OFF = tonumber("SQ_MODE_TRAP_OFF_STRREF")  -- "Trap detection: off"

local SET_MODAL = SQ_Addr(0x140374940)
local CURR_ACTION_CALL = SQ_Addr(0x1403B3AA0)
local UI_CALLS = { SQ_Addr(0x140264113), SQ_Addr(0x140264186), SQ_Addr(0x1402641DF), SQ_Addr(0x140264219), SQ_Addr(0x140264292), SQ_Addr(0x140264373), SQ_Addr(0x1402644C8),
	SQ_Addr(0x140264657), SQ_Addr(0x140264757), SQ_Addr(0x14026480B), SQ_Addr(0x140265371), SQ_Addr(0x1402F4CDD), SQ_Addr(0x1402F3460) }
local STEALTH_FAIL = SQ_Addr(0x14038DBBA)
-- lea rdx, [rip+disp] ; mov [rsi+0x4E50], r12d -- false = any byte (the RIP displacement differs between v2.7.3 and v2.6.6)
local STEALTH_FAIL_BYTES = { 0x48, 0x8D, 0x15, false, false, false, false, 0x44, 0x89, 0xA6, 0x50, 0x4E }
-- mov dword ptr [rsi+0x4E50], r12d (r12d = 0 there, as the original failure path) ; jmp 0x14038ECCB (CheckModal end)
local STEALTH_FAIL_PATCH = { 0x44, 0x89, 0xA6, 0x50, 0x4E, 0x00, 0x00, 0xE9, 0x05, 0x11, 0x00, 0x00 }
local DANCE_JE = SQ_Addr(0x1401BA85F)
local DANCE_JE_BYTES = { 0x0F, 0x84, 0xB9, 0x00, 0x00, 0x00 }
local TRAP_BUTTON = SQ_Addr(0x140264916)
local TRAP_BUTTON_BYTES = { 0x48, 0x8B, 0x4C, 0x24, 0x48 }   -- mov rcx, qword ptr [rsp+0x48] (the sprite)
local TRAP_BUTTON_EXIT = SQ_Addr(0x140264AF7)                         -- selected = 100, update buttons, return 1
local MODAL_FEEDBACK = SQ_Addr(0x140398B70)                           -- CGameSprite feedback (message id in edx)
local FEEDBACK_CALLS = { SQ_Addr(0x14038E6AA), SQ_Addr(0x14038D2B4) }   -- song / dance (0x39), turn undead (0x36)

local function byteAt(a) return EEex_ReadU8(a) % 256 end
local function bytesAre(addr, list)
	for i, b in ipairs(list) do if b and byteAt(addr + i - 1) ~= b then return false end end
	return true
end
local function writeBytes(addr, list)
	for i, b in ipairs(list) do EEex_WriteU8(addr + i - 1, b) end
end
local function relTarget(at)   -- target of the E8/E9 rel32 at 'at'
	local rel = byteAt(at + 1) + byteAt(at + 2) * 0x100 + byteAt(at + 3) * 0x10000 + byteAt(at + 4) * 0x1000000
	if rel >= 0x80000000 then rel = rel - 0x100000000 end
	return at + 5 + rel
end
local function writeRel(at, opcode, target)
	local rel = target - (at + 5)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of range') end
	if rel < 0 then rel = rel + 0x100000000 end
	EEex_WriteU8(at, opcode)
	for i = 0, 3 do EEex_WriteU8(at + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
end
local function isSetModalCall(at) return byteAt(at) == 0xE8 and relTarget(at) == SET_MODAL end

-- Find Traps button: toggles SadoQoL's passive trap detection for this thief (saved as a creature variable).
function SQMode_ToggleTraps(sprite)
	if not sprite then return end
	local off = EEex_Sprite_GetLocalInt(sprite, 'SQTRAPOFF') ~= 1
	EEex_Sprite_SetLocalInt(sprite, 'SQTRAPOFF', off and 1 or 0)
	local strref = off and T.TRAP_OFF or T.TRAP_ON
	-- a message, not a queued DisplayStringHead action: an action would take the thief out of stealth
	if strref then EEex_Sprite_DisplayTextRef(sprite, strref, { overHead = true }) end
end

local function patch()
	if T.status then return end
	local ok = isSetModalCall(CURR_ACTION_CALL) and bytesAre(STEALTH_FAIL, STEALTH_FAIL_BYTES)
		and bytesAre(DANCE_JE, DANCE_JE_BYTES) and bytesAre(TRAP_BUTTON, TRAP_BUTTON_BYTES)
	for _, a in ipairs(UI_CALLS) do ok = ok and isSetModalCall(a) end
	if not ok then
		T.status = 'skipped: unexpected engine code'
		print('[SadoQoL] lasting modes: ' .. T.status)
		return
	end


	-- 5. Find Traps button -> Lua, then the handler's own exit
	local cell = EEex_Malloc(8)
	local trapStub = EEex_JITNear(EEex_FlattenTable({
		{[[
			mov rcx, qword ptr ss:[rsp+0x48]
			mov rax, ]], cell, [[ #ENDL
			mov qword ptr ds:[rax], rcx
			#MAKE_SHADOW_SPACE(40)
		]]},
		EEex_GenLuaCall("SQMode_ToggleTraps", {
			["args"] = {
				function(rspOffset) return {[[
					mov rax, #$(1) #ENDL
					mov rax, qword ptr ds:[rax]
					mov qword ptr ss:[rsp+#$(2)], rax #ENDL
				]], {cell, rspOffset}}, "CGameSprite" end,
			},
		}),
		{[[
			call_error:
			#DESTROY_SHADOW_SPACE
			jmp ]], TRAP_BUTTON_EXIT, [[ #ENDL
		]]},
	}))

	EEex_DisableCodeProtection()
	writeBytes(CURR_ACTION_CALL, { 0x0F, 0x1F, 0x44, 0x00, 0x00 })   -- 1. a new action keeps the modal
	for _, a in ipairs(UI_CALLS) do writeBytes(a, { 0x0F, 0x1F, 0x44, 0x00, 0x00 }) end
	writeBytes(STEALTH_FAIL, STEALTH_FAIL_PATCH)
	writeBytes(DANCE_JE, { 0x90, 0xE9 })
	if SQTrap then writeRel(TRAP_BUTTON, 0xE9, trapStub) end   -- only with the passive trap detection (#0)
	-- 5b. no per-round "Singing Bard Song" / "Turning Undead" (checked on their own: the rest does not depend on it)
	for _, a in ipairs(FEEDBACK_CALLS) do
		if byteAt(a) == 0xE8 and relTarget(a) == MODAL_FEEDBACK then writeBytes(a, { 0x0F, 0x1F, 0x44, 0x00, 0x00 }) end
	end
	EEex_EnableCodeProtection()
	T.status = SQTrap and 'patched' or 'patched (no #0: Find Traps button unchanged)'
end

--[[
Stealth: only hostile acts reveal (John 2026-10-23). Every reveal goes through CGameSprite::ForceVisible (opcode 136
-> removes opcode 20 invisibility), each call followed by RemoveSanctuary. Patches:
 6. ForceVisible entry: when the modal is stealth, clear +0x4E50 ("already hidden") so re-hiding after a reveal is a
    real roll in front of enemies.
 7. Talking (PlayerDialog x2), opening a container (UseContainer), taking a ground item: no reveal (calls NOPed).
 8. Spell (x2), UseItem, ForceSpell: the engine reveals when the SPL / ability is flagged hostile (0x600), whatever
    the target. Now no reveal when the target is the caster or an ally (EA both <= 30 or both >= 200); creatures
    only, a null target reveals. Attacks (Swing) and point / area casts are unchanged: they reveal.
--]]
local FORCE_VISIBLE, REMOVE_SANCTUARY = SQ_Addr(0x14039C510), SQ_Addr(0x1403B0480)
local FV_PROLOGUE = { 0x40, 0x53, 0x48, 0x83, 0xEC, 0x70 }   -- push rbx ; sub rsp, 0x70
local QUIET_CALLS = { SQ_Addr(0x1403A93C5), SQ_Addr(0x1403A98A0), SQ_Addr(0x1403BAA9A), SQ_Addr(0x1402F3450) }
local CAST_SITES = { { SQ_Addr(0x1403B48AE), 'r15' }, { SQ_Addr(0x1403B4AF0), 'r15' }, { SQ_Addr(0x1403BB905), 'r12' }, { SQ_Addr(0x14016CAC7), 'r12' } }
local MOV_RCX_RBX = { 0x48, 0x8B, 0xCB }

local function isCallTo(at, target) return byteAt(at) == 0xE8 and relTarget(at) == target end
local function castSiteOk(a)   -- mov rcx,rbx ; call ForceVisible ; mov rcx,rbx ; call RemoveSanctuary
	return bytesAre(a, MOV_RCX_RBX) and isCallTo(a + 3, FORCE_VISIBLE)
		and bytesAre(a + 8, MOV_RCX_RBX) and isCallTo(a + 11, REMOVE_SANCTUARY)
end

local function castStub(site, tgt)
	return EEex_JITNear({[[
		test ]], tgt, [[, ]], tgt, [[ #ENDL
		jz sq_reveal
		cmp ]], tgt, [[, rbx #ENDL
		je sq_skip
		cmp byte ptr ds:[]], tgt, [[+8], 0x31 #ENDL
		jne sq_reveal
		movzx eax, byte ptr ds:[rbx+0x38]
		movzx ecx, byte ptr ds:[]], tgt, [[+0x38] #ENDL
		cmp eax, 30
		ja sq_not_good
		cmp ecx, 30
		jbe sq_skip
		jmp sq_reveal
		sq_not_good:
		cmp eax, 200
		jb sq_reveal
		cmp ecx, 200
		jae sq_skip
		sq_reveal:
		mov rcx, rbx
		call ]], FORCE_VISIBLE, [[ #ENDL
		mov rcx, rbx
		call ]], REMOVE_SANCTUARY, [[ #ENDL
		sq_skip:
		jmp ]], site + 16, [[ #ENDL
	]]})
end

local function patchStealth()
	if T.stealthStatus then return end
	local ok = bytesAre(FORCE_VISIBLE, FV_PROLOGUE)
	for _, a in ipairs(QUIET_CALLS) do ok = ok and isCallTo(a, FORCE_VISIBLE) end
	for _, s in ipairs(CAST_SITES) do ok = ok and castSiteOk(s[1]) end
	if not ok then
		T.stealthStatus = 'skipped: unexpected engine code'
		print('[SadoQoL] lasting modes, stealth: ' .. T.stealthStatus)
		return
	end
	local fvStub = EEex_JITNear({[[
		cmp byte ptr ds:[rcx+0x3A29], 3
		jne sq_fv
		mov dword ptr ds:[rcx+0x4E50], 0
		sq_fv:
		push rbx
		sub rsp, 0x70
		jmp ]], FORCE_VISIBLE + #FV_PROLOGUE, [[ #ENDL
	]]})
	local stubs = {}
	for i, s in ipairs(CAST_SITES) do stubs[i] = castStub(s[1], s[2]) end
	EEex_DisableCodeProtection()
	writeRel(FORCE_VISIBLE, 0xE9, fvStub)
	EEex_WriteU8(FORCE_VISIBLE + 5, 0x90)
	for _, a in ipairs(QUIET_CALLS) do writeBytes(a, { 0x0F, 0x1F, 0x44, 0x00, 0x00 }) end
	for i, s in ipairs(CAST_SITES) do
		writeRel(s[1], 0xE9, stubs[i])
		for k = 5, 15 do EEex_WriteU8(s[1] + k, 0x90) end
	end
	EEex_EnableCodeProtection()
	T.stealthStatus = 'patched'
end

local function run()
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] lasting modes: ' .. T.status) end
	ok, err = pcall(patchStealth)
	if not ok then T.stealthStatus = 'error: ' .. tostring(err) print('[SadoQoL] lasting modes, stealth: ' .. T.stealthStatus) end
end

-- Orange frame on the Find Traps button while the selected thief's trap detection is on. CInfButtonArray::
-- UpdateButtons sets each button's "selected modal" dword (button + 0x28C, buttons 0x2A0 bytes apart) from the
-- engine modal; this runs right after it (EEex buttons-updated listener; the button handler calls UpdateButtons).
local BUTTON_FIND_TRAPS, BUTTON_SIZE, BUTTON_SELECTED = 4, 0x2A0, 0x28C
local THIEF_CLASSES = { [4] = true, [9] = true, [10] = true, [13] = true, [15] = true }   -- as in M_SQTRAP.lua
local function frameTrapButton()
	if not SQTrap or not T.status or T.status:sub(1, 7) ~= 'patched' then return end
	local sprite = EEex_Sprite_GetSelected()
	-- thieves only: other classes reuse button type 4 (the shaman's dance slot)
	if not sprite or not THIEF_CLASSES[sprite.m_typeAI.m_Class]
			or EEex_Sprite_GetLocalInt(sprite, 'SQTRAPOFF') == 1 then return end
	local bar = EEex_Actionbar_GetArray()
	local base = EEex_UDToPtr(bar)
	for i = 0, 11 do
		if bar.m_buttonTypes:get(i) == BUTTON_FIND_TRAPS then
			EEex_WriteU32(base + i * BUTTON_SIZE + BUTTON_SELECTED, 1)
		end
	end
end
-- registered once; a reload of this file swaps the function it calls (hot reload while testing)
local function onButtonsUpdated() pcall(frameTrapButton) end
local list = EEex_Actionbar_Private_ButtonsUpdatedListeners
local replaced = false
for i, f in ipairs(list or {}) do
	if f == T.frameListener then list[i] = onButtonsUpdated replaced = true end
end
if not replaced then EEex_Actionbar_AddButtonsUpdatedListener(onButtonsUpdated) end
T.frameListener = onButtonsUpdated

-- M_SQMODE.lua loads before M_SQTRAP.lua (alphabetical): patch once every M_ file has run
if SQTrap then run()
elseif not T.listenerAdded then
	T.listenerAdded = true
	EEex_GameState_AddInitializedListener(run)
end

-- No chat spam (John 2026-10-25): with the modes lasting, the party AI scripts keep queuing BattleSong() / Turn()
-- while the mode is already on, and the action prints its feedback line ("Singing Bard Song") every time. Such an
-- action is dropped when the sprite is already in that modal state (byte +0x3A29: 1 song, 4 turn undead, 5 dance).
local A_BATTLESONG, A_TURN = 296, 33
local MODAL_OFF = 0x3A29
T.SPAM = T.SPAM ~= false -- the filter on (SadoEE options panel: SQMode.SPAM)
function SQMode_OnStartedAction(sp, a)
	if not T.SPAM then return end
	local id = a.m_actionID
	if id ~= A_BATTLESONG and id ~= A_TURN then return end
	local m = EEex_ReadU8(EEex_UDToPtr(sp) + MODAL_OFF)
	if (id == A_BATTLESONG and (m == 1 or m == 5)) or (id == A_TURN and m == 4) then a.m_actionID = 0 end
end
if not T.spamListener then
	T.spamListener = true
	EEex_Action_AddSpriteStartedActionListener(function(sp, a) pcall(SQMode_OnStartedAction, sp, a) end)
end
