--[[
SadoQoL component #17 - Withers' respec (John 2026-10-23). Design notes: SadoQoL/docs/RESPEC.md.

Withers (the lich at the rest camp) recreates a party member from scratch, free: race, class (single / multi),
kit, alignment, abilities (the game's own dice, Re-roll / Store / Recall, Auto-Roll from the Auto-Roller mod),
weapon proficiencies, thief skills, spells, hated race... in the game's OWN character creation panels, opened over
the world on that member. Name, gender, portrait, voice, colours, inventory and XP are kept. Once begun it cannot
be undone (Withers warns first). At the end the member is level 1 with level-1 hit points, and gets his XP back:
the game's level-up screens take him up again.

How: CScreenCreateChar works on the sprite id at +0x770, its current step at +0x768 (3 race, 4 class, 6 kit,
7 alignment, 8 abilities, 9 / 14 skills and proficiencies, 11-13 spells, ...; 15 = appearance, where we stop).
createCharScreen:OnMenuButtonClick() opens the panel of the current step; each panel's Done
(OnDoneButtonClick) applies it (CompleteCharacterClass, CompleteCharacterAbilities, ...) and moves the step on.
The SQRESP_TICK menu opens the next panel whenever none is open; SQRESPEC (a small bar at the top) shows who
and where, with "Continue" (a panel closed with Back) and, at the end, "Finish".
Engine patch (bytes checked): CompleteCharacterSkills hands out the starting weapon and gold; while a respec runs
(flag byte), that block is skipped (the member keeps his own gear).
Before the panels: RemoveAbilities(cc, sprite, 0, 1) (what dual-classing does to the old class: its spells,
skills, special abilities), XP 0.
--]]

SQRespec = SQRespec or {}
local T = SQRespec

-- ---- engine calls (a stub per function: Lua integers in, the return value out; as Party Stash's buildStub) ----
local function bytesLE(v, n)
	local out = {}
	for i = 1, n do out[i] = v % 256 v = math.floor(v / 256) end
	return table.unpack(out)
end

local function buildStub(name, target, nargs)
	local toint, pushint = EEex_Label('Hardcoded_lua_tointegerx'), EEex_Label('Hardcoded_lua_pushinteger')
	local code = {}
	local function emit(...) for _, b in ipairs({ ... }) do code[#code + 1] = b end end
	local function slot(i) return 0x50 + 8 * (i - 1) end
	emit(0x53, 0x56, 0x57)
	emit(0x48, 0x81, 0xEC, bytesLE(0xA0, 4))
	emit(0x48, 0x89, 0xCB)
	for i = 1, nargs do
		emit(0x48, 0x89, 0xD9)
		emit(0xBA, bytesLE(i, 4))
		emit(0x45, 0x31, 0xC0)
		emit(0x48, 0xB8, bytesLE(toint, 8))
		emit(0xFF, 0xD0)
		emit(0x48, 0x89, 0x84, 0x24, bytesLE(slot(i), 4))
	end
	local regs = { { 0x48, 0x8B, 0x8C }, { 0x48, 0x8B, 0x94 }, { 0x4C, 0x8B, 0x84 }, { 0x4C, 0x8B, 0x8C } }
	for i = 1, math.min(nargs, 4) do
		emit(regs[i][1], regs[i][2], regs[i][3], 0x24, bytesLE(slot(i), 4))
	end
	emit(0x48, 0xB8, bytesLE(target, 8))
	emit(0xFF, 0xD0)
	emit(0x48, 0x89, 0xD9)
	emit(0x48, 0x89, 0xC2)
	emit(0x48, 0xB8, bytesLE(pushint, 8))
	emit(0xFF, 0xD0)
	emit(0xB8, 1, 0, 0, 0)
	emit(0x48, 0x81, 0xC4, bytesLE(0xA0, 4))
	emit(0x5F, 0x5E, 0x5B, 0xC3)
	local addr = EEex_AllocNear(#code)
	EEex_DisableCodeProtection()
	for i, b in ipairs(code) do EEex_WriteU8(addr + i - 1, b) end
	EEex_EnableCodeProtection()
	EEex_ExposeToLua(addr, 'SQRespec_Eng_' .. name)
end

local REMOVE_ABILITIES = SQ_Addr(0x1402AC8D0)     -- CScreenCreateChar::RemoveAbilities(this, sprite, newClass, 1)

-- CompleteCharacterSkills, after the starting gold: "mov rdx, rdi ; mov [rsp+0xD60], r14" (11 bytes) then the
-- gold + starting weapon block, which ends at SKILLS_AFTER_GEAR (r13d = 1, r12d = 0 there).
local SKILLS_GEAR, SKILLS_GEAR_NEXT, SKILLS_AFTER_GEAR = SQ_Addr(0x1402B385D), SQ_Addr(0x1402B3868), SQ_Addr(0x1402B3AF5)
local SKILLS_GEAR_BYTES = { 0x48, 0x8B, 0xD7, 0x4C, 0x89, 0xB4, 0x24, 0x60, 0x0D, 0x00, 0x00 }

local function byteAt(a) return EEex_ReadU8(a) % 256 end

local function patch()
	if T.status then return end
	for i, b in ipairs(SKILLS_GEAR_BYTES) do
		if byteAt(SKILLS_GEAR + i - 1) ~= b then T.status = 'skipped: unexpected engine code' end
	end
	if T.status then print('[SadoQoL] respec: ' .. T.status) return end
	T.flag = EEex_Malloc(8)
	EEex_WriteU8(T.flag, 0)
	local stub = EEex_JITNear({[[
		mov rdx, rdi
		mov qword ptr ss:[rsp+0xD60], r14
		mov rax, ]], T.flag, [[ #ENDL
		cmp byte ptr ds:[rax], 0
		je sqresp_gear
		mov r13d, 1
		xor r12d, r12d
		jmp ]], SKILLS_AFTER_GEAR, [[ #ENDL
		sqresp_gear:
		jmp ]], SKILLS_GEAR_NEXT, [[ #ENDL
	]]})
	local rel = stub - (SKILLS_GEAR + 5)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of range') end
	if rel < 0 then rel = rel + 0x100000000 end
	EEex_DisableCodeProtection()
	EEex_WriteU8(SKILLS_GEAR, 0xE9)
	for i = 0, 3 do EEex_WriteU8(SKILLS_GEAR + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
	for i = 5, #SKILLS_GEAR_BYTES - 1 do EEex_WriteU8(SKILLS_GEAR + i, 0x90) end
	EEex_EnableCodeProtection()
	buildStub('RemoveAbilities', REMOVE_ABILITIES, 4)
	T.status = 'patched'
end

do
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] respec: ' .. T.status) end
end

-- ---- the creation panels ----
local PANELS = { 'CHARGEN_GENDER', 'CHARGEN_PORTRAIT', 'CHARGEN_RACE', 'CHARGEN_CLASS', 'CHARGEN_KIT',
	'CHARGEN_ALIGNMENT', 'CHARGEN_ABILITIES', 'CHARGEN_PROFICIENCIES', 'CHARGEN_CHOOSE_SPELLS',
	'CHARGEN_MEMORIZE_MAGE', 'CHARGEN_MEMORIZE_PRIEST', 'CHARGEN_HATEDRACE', 'CHARGEN_CUSTOMSOUNDS', 'CHARGEN_NAME',
	'CHARGEN_BIO', 'CHARGEN_DUALCLASS' }
local STEP_RACE, STEP_CLASS, STEP_ALIGNMENT, STEP_DONE = 3, 4, 7, 15   -- 15 = appearance: everything after it is kept as it is

local function cc() return EEex_UDToPtr(createCharScreen) end
-- +0x800: the screen's mode; the Dual-Class screen leaves 6 there (see M_SQRECR.lua): 0 while the panels run
local CC_MODE = 0x800
local function step() return EEex_ReadU32(cc() + 0x768) end

local function panelOpen()
	for _, m in ipairs(PANELS) do if Infinity_IsMenuOnStack(m) then return true end end
	return false
end

local function sprite()
	local o = T.id and EEex_GameObject_Get(T.id)
	return o and o.m_objectType == 49 and EEex_GameObject_CastUserType(o) or nil
end

-- The menus' own Lua state some Done buttons check (set by their list clicks, which we do not see).
local function primeLuaState()
	currentChargenAlignment = currentChargenAlignment or 1
end

-- HP at level 1: the class's HP table, row 1, at its best (SIDES x ROLLS + MODIFIER), + the Constitution bonus
-- (HPCONBON: WARRIOR column for warriors).
local CLASS_LABELS = { 'MAGE', 'FIGHTER', 'CLERIC', 'THIEF', 'BARD', 'PALADIN', 'FIGHTER_MAGE', 'FIGHTER_CLERIC',
	'FIGHTER_THIEF', 'FIGHTER_MAGE_THIEF', 'DRUID', 'RANGER', 'MAGE_THIEF', 'CLERIC_MAGE', 'CLERIC_THIEF',
	'FIGHTER_DRUID', 'FIGHTER_MAGE_CLERIC', 'CLERIC_RANGER', 'SORCERER', 'MONK', 'SHAMAN' }
local WARRIORS = { [2] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [12] = true,
	[16] = true, [17] = true, [18] = true }

local function at2DA(res, col, row)
	local ok, v = pcall(function()
		local a = EEex_Resource_Load2DA(res)
		local r = EEex_Resource_GetAt2DALabels(a, col, row)
		EEex_Resource_Free2DA(a)
		return r
	end)
	return ok and v or nil
end

local function levelOneHP(sp)
	local class = sp.m_typeAI.m_Class
	local label = CLASS_LABELS[class] or 'FIGHTER'
	local kit = math.floor(sp.m_baseStats.m_mageSpecUpperWord or 0) % 0x10000
	local tbl
	if kit > 0x4000 then
		local kitLabel = at2DA('KITLIST', 'ROWNAME', tostring(kit - 0x4000))
		if kitLabel then tbl = at2DA('HPCLASS', 'TABLE', kitLabel) end
	end
	tbl = tbl or at2DA('HPCLASS', 'TABLE', label) or 'HPWAR'
	local sides = tonumber(at2DA(tbl, 'SIDES', '1')) or 8
	local rolls = tonumber(at2DA(tbl, 'ROLLS', '1')) or 1
	local mod = tonumber(at2DA(tbl, 'MODIFIER', '1')) or 0
	local con = sp.m_baseStats.m_CONBase
	local bonus = tonumber(at2DA('HPCONBON', WARRIORS[class] and 'WARRIOR' or 'OTHER', tostring(con))) or 0
	return math.max(1, sides * rolls + mod + bonus)
end

-- ---- gear the new character can no longer use (John 2026-10-23) ----
-- ITM "not usable by" bits (header 0x1E): class, race, alignment; kit bytes 0x29 / 0x2B / 0x2D / 0x2F against
-- KITLIST's UNUSABLE; plus the minimum abilities. Unusable equipped items go to the backpack, or, when it is full,
-- to the Party Stash with a line in the message log.
local CLASS_BIT = { [1] = 18, [2] = 11, [3] = 7, [4] = 22, [5] = 6, [6] = 20, [7] = 13, [8] = 14, [9] = 17,
	[10] = 16, [11] = 30, [12] = 21, [13] = 19, [14] = 8, [15] = 9, [16] = 12, [17] = 15, [18] = 10, [19] = 18,
	[20] = 29, [21] = 30 }
local RACE_BIT = { [1] = 27, [2] = 23, [3] = 25, [4] = 24, [5] = 26, [6] = 28, [7] = 31 }
local LAW_BIT = { [1] = 4, [2] = 5, [3] = 0 }       -- alignment high nibble: lawful, neutral, chaotic
local GOOD_BIT = { [1] = 2, [2] = 3, [3] = 1 }      -- low nibble: good, neutral, evil
local EQUIPPED = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 35, 36, 37, 38 }

local function bit(v, b) return math.floor(v / 2 ^ b) % 2 == 1 end

local function usable(sp, res)
	local h = EEex_Resource_Demand(res, 'ITM')
	if not h then return true end
	local t, b = sp.m_typeAI, sp.m_baseStats
	local nu = h.notUsableBy
	if CLASS_BIT[t.m_Class] and bit(nu, CLASS_BIT[t.m_Class]) then return false end
	if RACE_BIT[t.m_Race] and bit(nu, RACE_BIT[t.m_Race]) then return false end
	local al = t.m_Alignment
	if LAW_BIT[math.floor(al / 16)] and bit(nu, LAW_BIT[math.floor(al / 16)]) then return false end
	if GOOD_BIT[al % 16] and bit(nu, GOOD_BIT[al % 16]) then return false end
	local kit = math.floor(b.m_mageSpecUpperWord or 0) % 0x10000
	if kit > 0x4000 then
		local mask = tonumber(at2DA('KITLIST', 'UNUSABLE', tostring(kit - 0x4000)) or '0') or 0
		local bits = h.notUsableBy2a * 0x1000000 + h.notUsableBy2b * 0x10000 + h.notUsableBy2c * 0x100 + h.notUsableBy2d
		if mask > 0 and EEex_BAnd(bits, mask) ~= 0 then return false end
	end
	if b.m_STRBase < h.minSTRRequired or b.m_DEXBase < h.minDEXRequired or b.m_CONBase < h.minCONRequired
			or b.m_INTBase < h.minINTRequired or b.m_WISBase < h.minWISRequired or b.m_CHRBase < h.minCHRRequired then
		return false
	end
	return true
end

-- texts, from the .tra at install (SadoQoL.tp2)
T.TXT_STASH = "SQ_RESP_TXT_STASH"     -- "%s: %s went to the stash (backpack full)"
T.TXT_CONTINUE = "SQ_RESP_TXT_CONTINUE"
T.TXT_FINISH = "SQ_RESP_TXT_FINISH"
T.TXT_DUAL = "SQ_RESP_TXT_DUAL"       -- "Level %d before dual-classing: %d XP now, %d XP after"
T.TXT_BANK = "SQ_RESP_TXT_BANK"       -- "%s: %d XP given back after dual-classing"
T.TXT_DUAL_TITLE = "SQ_RESP_TXT_DUALTITLE"
T.TXT_DUAL_OK = "SQ_RESP_TXT_DUALOK"
T.TXT_DUAL_NONE = "SQ_RESP_TXT_DUALNONE"
T.TXT_GRIM_GOT = "SQ_RESP_TXT_GRIMGOT"        -- "%s: %d spells went into the grimoire"
T.TXT_GRIM_LEARN = "SQ_RESP_TXT_GRIMLEARN"    -- "%s learns %s"
T.TXT_GRIM_ROW = "SQ_RESP_TXT_GRIMROW"        -- "%s (level %d)"
T.TXT_GRIM_TITLE = "SQ_RESP_TXT_GRIMTITLE"    -- "Grimoire - read by %s"
T.TXT_GRIM_OPEN = "SQ_RESP_TXT_GRIMOPEN"
T.TXT_GRIM_LEARNBTN = "SQ_RESP_TXT_GRIMLBTN"
T.TXT_GRIM_CLOSE = "SQ_RESP_TXT_GRIMCLOSE"

local function unequipUnusable(sp)
	local portrait = EEex_Sprite_GetPortraitIndex(sp)
	if not portrait or portrait < 0 or not PStash_Add or not PStash_Take then return end
	for _, slot in ipairs(EQUIPPED) do
		local it = sp.m_equipment.m_items:get(slot)
		if it then
			local res = it.pRes.resref:get()
			if not usable(sp, res) then
				-- through the stash and back: the engine's own swaps take it off properly (equipped effects)
				local ok = PStash_Add(portrait, slot)
				if ok and not PStash_Take(portrait, res) then
					local name = Infinity_FetchString(EEex_Resource_Demand(res, 'ITM').identifiedName)
					Infinity_DisplayString(string.format(T.TXT_STASH, sp:getName(), name))
				end
			end
		end
	end
end

-- ---- dual-class preparation (John 2026-10-23) ----
-- A human in a single class that DUALCLAS.2DA lets dual-class: a window (SQRESP_DUAL) asks the level of the first
-- class. He gets the XP of that level (XPLEVEL.2DA); the rest is kept on him (local SQRESPXP) and given back as
-- soon as he has dual-classed (CRE flags 0x8-0x100: the original class of a dual-class).
local DUAL_ORIGINAL = 0x8 + 0x10 + 0x20 + 0x40 + 0x80 + 0x100

local function dualLabel(sp)
	-- humans; and the necromancer's creatures, whatever their race (John 2026-10-25)
	if sp.m_typeAI.m_Race ~= 1 and EEex_Sprite_GetLocalInt(sp, 'SQJOINED') ~= 1 then return nil end
	local label = CLASS_LABELS[sp.m_typeAI.m_Class]
	if not label or label:find('_') then return nil end           -- multi-classes
	if EEex_BAnd(sp.m_baseStats.m_flags, DUAL_ORIGINAL) ~= 0 then return nil end
	for _, col in ipairs({ 'FIGHTER', 'CLERIC', 'MAGE', 'THIEF', 'DRUID', 'RANGER' }) do
		if at2DA('DUALCLAS', col, label) == '1' then return label end
	end
	return nil
end

local function xpFor(label, level) return tonumber(at2DA('XPLEVEL', tostring(level), label) or '') end

local function levelFor(label, xp)
	local lv = 1
	for l = 2, 50 do
		local need = xpFor(label, l)
		if not need or need > xp then break end
		lv = l
	end
	return lv
end

function SQRespec_DualOpen() return T.dual ~= nil end
function SQRespec_DualLevel() return T.dual and T.dual.level or 0 end
function SQRespec_DualText()
	if not T.dual then return '' end
	local need = xpFor(T.dual.label, T.dual.level) or 0
	return string.format(T.TXT_DUAL, T.dual.level, need, T.dual.total - need)
end
function SQRespec_DualStep(d)
	if T.dual then T.dual.level = math.max(1, math.min(T.dual.max, T.dual.level + d)) end
end

-- Base stats written by hand stay out of the derived ones (record screen, level-up) until the effect list runs
-- again: BG2EE 2.7.3 kept 0 XP and the old 75 max HP after a respec (John 2026-10-25). An instant no-op effect
-- (AC +0, duration 0) makes the engine rebuild them.
local function refreshStats(sp)
	EEex_GameObject_ApplyEffect(sp, { effectID = 0, durationType = 0, duration = 0, effectAmount = 0,
		sourceID = sp.m_id, sourceTarget = sp.m_id })
end

local function giveXP(sp, xp)
	sp.m_baseStats.m_xp = sp.m_baseStats.m_xp + xp
	pcall(refreshStats, sp)
end

-- "Confirm": the level's XP now, the rest when he has dual-classed
function SQRespec_DualConfirm()
	local d = T.dual
	T.dual = nil
	if Infinity_IsMenuOnStack('SQRESP_DUAL') then Infinity_PopMenu('SQRESP_DUAL') end
	local o = d and EEex_GameObject_Get(d.id)
	if not o then return end
	local sp = EEex_GameObject_CastUserType(o)
	local need = xpFor(d.label, d.level) or 0
	giveXP(sp, need)
	EEex_Sprite_SetLocalInt(sp, 'SQRESPXP', d.total - need)
end

-- "No dual-class": all the XP now
function SQRespec_DualNone()
	local d = T.dual
	T.dual = nil
	if Infinity_IsMenuOnStack('SQRESP_DUAL') then Infinity_PopMenu('SQRESP_DUAL') end
	local o = d and EEex_GameObject_Get(d.id)
	if o then giveXP(EEex_GameObject_CastUserType(o), d.total) end
end

-- the kept XP comes back once he has dual-classed
local function checkBankedXP()
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			local bank = EEex_Sprite_GetLocalInt(sp, 'SQRESPXP')
			if bank > 0 and EEex_BAnd(sp.m_baseStats.m_flags, DUAL_ORIGINAL) ~= 0 then
				EEex_Sprite_SetLocalInt(sp, 'SQRESPXP', 0)
				giveXP(sp, bank)
				Infinity_DisplayString(string.format(T.TXT_BANK, sp:getName(), bank))
			end
		end
	end
end

-- ---- the grimoire of lost spells (John 2026-10-23) ----
-- The mage spells in his book are noted when the respec begins. At the end, those the new character can still
-- write in his book come back (opcode 147); the others go into the party's grimoire (item SQGRIM, a copy of the
-- game's "Spell book"): its description screen gets an "Open the grimoire" button, whose window lists the spells
-- and lets the character who reads it learn those he can (book caster, school, a level he can cast).
-- The grimoire's spells: Player1's local string SQGRIMOIRE ("RES1,RES2,...").
local BOOK_CASTERS = { [1] = 1, [5] = 1, [7] = 2, [10] = 2, [13] = 1, [14] = 2, [17] = 2 }   -- class -> level field
local OPPOSITION = { ABJURER = { 8 }, CONJURER = { 3 }, DIVINER = { 2 }, ENCHANTER = { 6 }, ILLUSIONIST = { 7 },
	INVOKER = { 4, 2 }, NECROMANCER = { 5 }, TRANSMUTER = { 1, 7 } }       -- SPL school numbers
T.GRIM_ITEM = 'SQGRIM'

local function grimList()
	local p = EEex_Sprite_GetInPortrait(0)
	local s = p and EEex_Sprite_GetLocalString(p, 'SQGRIMOIRE') or ''
	local out = {}
	for r in string.gmatch(s, '[^,]+') do out[#out + 1] = r end
	return out
end

local function grimSave(list)
	local p = EEex_Sprite_GetInPortrait(0)
	if p then EEex_Sprite_SetLocalString(p, 'SQGRIMOIRE', table.concat(list, ',')) end
end

local function knownMage(sp)
	local out = {}
	for level, _, res in EEex_Sprite_GetKnownMageSpellsIterator(sp) do
		out[#out + 1] = { res = string.upper(res), level = level + 1 }
	end
	return out
end

local function kitLabel(sp)
	local kit = math.floor(sp.m_baseStats.m_mageSpecUpperWord or 0) % 0x10000
	if kit <= 0x4000 then return nil end
	return at2DA('KITLIST', 'ROWNAME', tostring(kit - 0x4000))
end

-- highest mage spell level he can cast now (0: none)
local function maxSpellLevel(sp)
	local field = BOOK_CASTERS[sp.m_typeAI.m_Class]
	if not field then return 0 end
	local b = sp.m_baseStats
	local lv = field == 2 and b.m_level2 or b.m_level1
	local tbl = sp.m_typeAI.m_Class == 5 and 'MXSPLBRD' or 'MXSPLWIZ'
	local best = 0
	for l = 1, 9 do
		if (tonumber(at2DA(tbl, tostring(l), tostring(math.max(1, lv)))) or 0) > 0 then best = l end
	end
	return best
end

-- can he ever write it in his book? (class and school; the level is checked when learning)
local function bookAllows(sp, res)
	if not BOOK_CASTERS[sp.m_typeAI.m_Class] then return false end
	local h = EEex_Resource_Demand(res, 'SPL')
	if not h then return false end
	if sp.m_typeAI.m_Class == 5 and h.spellLevel > 6 then return false end
	local opp = OPPOSITION[kitLabel(sp) or '']
	if opp then for _, school in ipairs(opp) do if h.school == school then return false end end end
	return true
end

local function knows(sp, res)
	for _, k in ipairs(knownMage(sp)) do if k.res == res then return true end end
	return false
end

local function learn(sp, res)
	EEex_GameObject_ApplyEffect(sp, { effectID = 147, durationType = 1, res = res,
		sourceID = sp.m_id, sourceTarget = sp.m_id })
end

local function partyHasGrimoire()
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			for i = 0, 38 do
				local it = sp.m_equipment.m_items:get(i)
				if it and string.upper(it.pRes.resref:get()) == T.GRIM_ITEM then return true end
			end
		end
	end
	return false
end

-- end of a respec: spells he can still write come back, the others go into the grimoire
local function settleSpells(sp)
	local old = T.spells or {}
	T.spells = nil
	if #old == 0 then return end
	local lost = {}
	for _, k in ipairs(old) do
		if bookAllows(sp, k.res) then
			if not knows(sp, k.res) then learn(sp, k.res) end
		else
			lost[#lost + 1] = k.res
		end
	end
	if #lost == 0 then return end
	local list = grimList()
	local have = {}
	for _, r in ipairs(list) do have[r] = true end
	for _, r in ipairs(lost) do if not have[r] then list[#list + 1] = r have[r] = true end end
	grimSave(list)
	if not partyHasGrimoire() then
		EEex_Action_QueueResponseStringOnAIBase('CreateItem("' .. T.GRIM_ITEM .. '",0,0,0)', sp)
	end
	Infinity_DisplayString(string.format(T.TXT_GRIM_GOT, sp:getName(), #lost))
end

-- the window (SQGRIMOIRE): rows of the grimoire, a page of ROWS, for the reader (the inventory's character)
T.ROWS = 8
T.page = T.page or 0
function SQGrim_Open(readerId)
	T.reader = readerId
	T.page = 0
	if not Infinity_IsMenuOnStack('SQGRIMOIRE') then Infinity_PushMenu('SQGRIMOIRE') end
end

local function reader()
	local o = T.reader and EEex_GameObject_Get(T.reader)
	return o and o.m_objectType == 49 and EEex_GameObject_CastUserType(o) or nil
end

local function row(i)
	return grimList()[T.page * T.ROWS + i]
end

function SQGrim_RowShown(i) return row(i) ~= nil end
function SQGrim_RowIcon(i)
	local r = row(i)
	local h = r and EEex_Resource_Demand(r, 'SPL')
	local ab = h and EEex_Resource_GetSpellAbility(h, 0)
	return ab and ab.quickSlotIcon:get() or ''
end
function SQGrim_RowText(i)
	local r = row(i)
	local h = r and EEex_Resource_Demand(r, 'SPL')
	if not h then return r or '' end
	return string.format(T.TXT_GRIM_ROW, Infinity_FetchString(h.genericName), h.spellLevel)
end
function SQGrim_CanLearn(i)
	local r, sp = row(i), reader()
	if not r or not sp then return false end
	local h = EEex_Resource_Demand(r, 'SPL')
	return h ~= nil and bookAllows(sp, r) and not knows(sp, r) and h.spellLevel <= maxSpellLevel(sp)
end
function SQGrim_Learn(i)
	if not SQGrim_CanLearn(i) then return end
	local r, sp = row(i), reader()
	learn(sp, r)
	local list = grimList()
	for k = #list, 1, -1 do if list[k] == r then table.remove(list, k) end end
	grimSave(list)
	local h = EEex_Resource_Demand(r, 'SPL')
	Infinity_DisplayString(string.format(T.TXT_GRIM_LEARN, sp:getName(), Infinity_FetchString(h.genericName)))
	if #list == 0 then
		-- empty: the grimoire crumbles
		for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
			local m = EEex_Sprite_GetInPortrait(p)
			if m then EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroyItem("' .. T.GRIM_ITEM .. '")', m) end
		end
		if Infinity_IsMenuOnStack('SQGRIMOIRE') then Infinity_PopMenu('SQGRIMOIRE') end
	end
end
function SQGrim_Title()
	local sp = reader()
	return string.format(T.TXT_GRIM_TITLE, sp and sp:getName() or '')
end
function SQGrim_Page(d)
	local pages = math.max(1, math.ceil(#grimList() / T.ROWS))
	T.page = math.max(0, math.min(pages - 1, T.page + d))
end
function SQGrim_PageText()
	return (T.page + 1) .. ' / ' .. math.max(1, math.ceil(#grimList() / T.ROWS))
end

-- "Open the grimoire" on the item description screen (left button), for our item only
local function wrapItemDesc()
	if T.descWrapped or not itemDescLeftButtonEnabled then return end
	T.descWrapped = true
	local function ours()
		return itemDesc and itemDesc.mode == 0 and itemDesc.item
			and string.upper(itemDesc.item.res or '') == T.GRIM_ITEM
	end
	local en, tx, ac = itemDescLeftButtonEnabled, itemDescLeftButtonText, itemDescLeftButtonAction
	itemDescLeftButtonEnabled = function() if ours() then return true end return en() end
	itemDescLeftButtonText = function() if ours() then return T.TXT_GRIM_OPEN end return tx() end
	itemDescLeftButtonAction = function()
		if ours() then
			Infinity_PopMenu()
			SQGrim_Open(id)
			return
		end
		return ac()
	end
end

-- ---- flow ----
-- Everyone may be recreated (John 2026-10-25), monsters too: a monster (class outside the player classes 1-21, or
-- anything joined through the camp necromancer, local SQJOINED) starts at the class step and keeps its race (the
-- opts.necro path); Withers' dialogue has its own lines for them (dlg/SQWITHER.d; WeiDU triggers take no "==" nor
-- "not": SQRespec_IsMonster / SQRespec_IsMortal).
local function isMonster(sp)
	if not sp then return false end
	local cls = sp.m_typeAI.m_Class
	return cls < 1 or cls > 21 or EEex_Sprite_GetLocalInt(sp, 'SQJOINED') == 1
end
local function selected()
	local sel = EEex_Sprite_GetAllSelected()
	return sel and sel[1]
end
function SQRespec_IsMonster()
	local ok, yes = pcall(isMonster, selected())
	return ok and yes or false
end
function SQRespec_IsMortal() return not SQRespec_IsMonster() end

local function setRace(sp, r)
	sp.m_typeAI.m_Race = r
	sp.m_startTypeAI.m_Race = r
	pcall(function() sp.m_liveTypeAI.m_Race = r end)
end

-- the class panel of a monster: every class of the game (the union of the playable races' lists), John 2026-10-25
local function allClasses()
	if T.allClasses then return T.allClasses end
	local sp = sprite()
	local all, order = {}, {}
	T.raceFor = {}
	for r = 1, 7 do
		setRace(sp, r)
		pcall(function() createCharScreen:OnMenuButtonClick() end)
		for _, c in ipairs(chargen.class or {}) do
			if not all[c.id] then
				all[c.id] = { id = c.id, name = c.name, desc = c.desc }
				order[#order + 1] = c.id
				T.raceFor[c.id] = r          -- a playable race the engine offers this class to
			end
		end
		if Infinity_IsMenuOnStack('CHARGEN_CLASS') then Infinity_PopMenu('CHARGEN_CLASS') end
	end
	setRace(sp, 1)
	table.sort(order)
	local list = {}
	for _, id in ipairs(order) do list[#list + 1] = all[id] end
	T.allClasses = list
	return list
end

-- A monster's class pick: the engine only takes a class its own list holds, and that list is the stand-in race's
-- (human: no multi-class). A class of another race's list (fighter / mage...) left the monster in its own class, then
-- an empty alignment list (Ogrillon, 2026-10-25). So on each pick the stand-in race becomes one the engine offers
-- the class to, the panel is rebuilt by the engine for it (then shows every class again) and the pick is made.
local function watchClassPick()
	if not Infinity_IsMenuOnStack('CHARGEN_CLASS') then T.picked = nil return end
	local c = chargen.class and currentChargenClass and chargen.class[currentChargenClass]
	if not c or c.id == T.picked then return end
	T.picked = c.id
	local sp = sprite()
	local r = T.raceFor and T.raceFor[c.id] or 1
	if sp.m_startTypeAI.m_Race ~= r then
		setRace(sp, r)
		Infinity_PopMenu('CHARGEN_CLASS')
		createCharScreen:OnMenuButtonClick()
		chargen.class = T.allClasses
		for i, e in ipairs(T.allClasses) do if e.id == c.id then currentChargenClass = i end end
	end
	createCharScreen:OnClassSelectButtonClick(c.id)
end

-- The creation panels hand out STARTARE.2DA's START_XP (89000 in EET: level 7), and the proficiency / spell panels
-- count their picks from the current level: the character is held at level 1 with no XP during the panels (every
-- tick) and at the end, so the dual-class question comes before any XP and the level-up screens raise him
-- (John 2026-10-25; same rule in M_SQRECR.lua).
local function holdLevelOne(sp)
	local label = CLASS_LABELS[sp.m_typeAI.m_Class] or ''
	local _, parts = label:gsub('_', '')
	sp.m_baseStats.m_xp = 0
	sp.m_baseStats.m_level1 = 1
	sp.m_baseStats.m_level2 = parts >= 1 and 1 or 0
	sp.m_baseStats.m_level3 = parts >= 2 and 1 or 0
end

-- opts.necro (monsters, and M_SQNECR.lua's joining creatures): re-created from the CLASS step (the race stays);
-- the necromancer's joining creatures also get the protagonist's XP (opts.xp1).
function SQRespec_Begin(sp, opts)
	if T.id or not sp or T.status ~= 'patched' then return false end
	local necro = opts and opts.necro or false
	local p = EEex_Sprite_GetPortraitIndex(sp)
	if not p or p < 0 then return false end
	T.id = sp.m_id
	T.xp = sp.m_baseStats.m_xp
	T.old = { id = EEex_ReadU32(cc() + 0x770), step = step(), portrait = EEex_ReadU32(cc() + 0x48),
		mode = EEex_ReadU32(cc() + CC_MODE) }
	EEex_WriteU32(cc() + CC_MODE, 0)
	EEex_WriteU8(T.flag, 1)
	T.spells = knownMage(sp)          -- the book, before it goes (grimoire of lost spells)
	-- the old class goes, as when dual-classing: its spells, skills and special abilities
	pcall(SQRespec_Eng_RemoveAbilities, cc(), EEex_UDToPtr(sp), 0, 1)
	sp.m_baseStats.m_xp = 0
	-- level 1 now, in the derived stats too: the engine takes the Constitution HP of the lost levels off the base
	-- max HP when it sees the level drop (8 -> 1, CON 18: -28). Seen first at the end, it took the new level-1 HP
	-- below 0 and killed the protagonist (EET, John 2026-10-25); here it only trims the old HP, rewritten at the end.
	holdLevelOne(sp)
	pcall(refreshStats, sp)
	EEex_WriteU32(cc() + 0x770, sp.m_id)
	EEex_WriteU32(cc() + 0x48, p)
	EEex_WriteU32(cc() + 0x768, necro and STEP_CLASS or STEP_RACE)
	T.necro = necro
	if necro then
		-- a monster's race has no row in the engine's race tables (an empty class list, then a crash when the class
		-- picks a character animation for it, 2026-10-25): it is a human while the panels run; its race and its own
		-- look come back at the end
		T.monster = { race = sp.m_typeAI.m_Race, anim = sp.m_animation.m_animation.m_animationID }
		setRace(sp, 1)
	end
	if opts and opts.xp1 then
		local p1 = EEex_Sprite_GetInPortrait(0)
		T.xp = p1 and p1.m_baseStats.m_xp or T.xp
	end
	T.started = Infinity_GetClockTicks()
	T.lastStep, T.wantOpen = nil, nil       -- the race (or class) panel opens on the next tick
	if not Infinity_IsMenuOnStack('SQRESP_BACK') then Infinity_PushMenu('SQRESP_BACK') end    -- under the panels
	if not Infinity_IsMenuOnStack('SQRESPEC') then Infinity_PushMenu('SQRESPEC') end
	if not Infinity_IsMenuOnStack('SQRESP_TICK') then Infinity_PushMenu('SQRESP_TICK') end
	return true
end

function SQRespec_Active() return T.id ~= nil end

-- the stock Race / Kit / Alignment panels are the bottom of a screen (GUISMF): the backdrop draws the top
local HALF_PANELS = { 'CHARGEN_RACE', 'CHARGEN_KIT', 'CHARGEN_ALIGNMENT' }
function SQRespec_NeedBack()
	if not T.id or LeUI_uiStrings then return false end
	for _, m in ipairs(HALF_PANELS) do if Infinity_IsMenuOnStack(m) then return true end end
	return false
end
function SQRespec_AtEnd() return T.id ~= nil and step() >= STEP_DONE end

function SQRespec_Title()
	local sp = sprite()
	return sp and sp:getName() or ''
end

-- Opens the panel of the current step (also the "Continue" button, after a Back).
function SQRespec_Continue()
	if not T.id or panelOpen() then return end
	if step() >= STEP_DONE then return end
	primeLuaState()
	-- a monster never goes back to the race panel (its race stays), and never goes past the class one without a
	-- player class (an empty alignment list otherwise)
	if T.monster and step() < STEP_CLASS then EEex_WriteU32(cc() + 0x768, STEP_CLASS) end
	local sp = sprite()
	if T.monster and sp and step() > STEP_CLASS and (sp.m_startTypeAI.m_Class < 1 or sp.m_startTypeAI.m_Class > 21) then
		EEex_WriteU32(cc() + 0x768, STEP_CLASS)
	end
	-- from the alignment step on (the dice are rolled when it is done), a monster is a plain human: 3-18 with no
	-- race bonus (John 2026-10-25), whatever stand-in race its class needed
	if T.monster and sp and step() >= STEP_ALIGNMENT and sp.m_startTypeAI.m_Race ~= 1 then setRace(sp, 1) end
	local list = T.monster and step() == STEP_CLASS and allClasses() or nil
	local ok, err = pcall(function() createCharScreen:OnMenuButtonClick() end)
	if not ok then T.lastError = tostring(err) end
	if list then chargen.class = list end
end

-- The end: level-1 hit points, XP back (the game's level-up takes it from there), the screen as it was.
function SQRespec_Finish()
	local sp = sprite()
	if sp and T.monster then
		-- the monster's own race and look again (the panels gave it a human body)
		setRace(sp, T.monster.race)
		EEex_GameObject_ApplyEffect(sp, { effectID = 53, durationType = 1, effectAmount = T.monster.anim,
			sourceID = sp.m_id, sourceTarget = sp.m_id })
	end
	T.monster = nil
	if sp then
		holdLevelOne(sp)
		local hp = levelOneHP(sp)
		sp.m_baseStats.m_maxHitPointsBase = hp
		sp.m_baseStats.m_hitPoints = hp
		local ok, err = pcall(unequipUnusable, sp)
		if not ok then T.lastError = 'unequip: ' .. tostring(err) end
		ok, err = pcall(settleSpells, sp)
		if not ok then T.lastError = 'spells: ' .. tostring(err) end
		-- a human in one class that can be dual-classed: choose the level of the first class first (John 2026-10-23)
		ok, err = pcall(function()
			if dualLabel(sp) and (T.xp or 0) > 0 then
				T.dual = { id = sp.m_id, total = T.xp, label = dualLabel(sp) }
				T.dual.max = levelFor(T.dual.label, T.dual.total)
				T.dual.level = T.dual.max
				sp.m_baseStats.m_xp = 0
				if not Infinity_IsMenuOnStack('SQRESP_DUAL') then Infinity_PushMenu('SQRESP_DUAL') end
			else
				sp.m_baseStats.m_xp = T.xp or 0
			end
		end)
		if not ok then T.lastError = 'unequip: ' .. tostring(err) end
		pcall(refreshStats, sp)
	end
	if T.flag then EEex_WriteU8(T.flag, 0) end
	if T.old then
		EEex_WriteU32(cc() + 0x770, T.old.id)
		EEex_WriteU32(cc() + 0x768, T.old.step)
		EEex_WriteU32(cc() + 0x48, T.old.portrait)
		if T.old.mode then EEex_WriteU32(cc() + CC_MODE, T.old.mode) end
	end
	T.id, T.old, T.xp, T.necro, T.lastStep, T.wantOpen = nil, nil, nil, nil, nil, nil
	if Infinity_IsMenuOnStack('SQRESPEC') then Infinity_PopMenu('SQRESPEC') end
	if Infinity_IsMenuOnStack('SQRESP_BACK') then Infinity_PopMenu('SQRESP_BACK') end
end

-- Next panel as soon as the previous one closed with Done (Back leaves the step as it was: "Continue" reopens it).
-- Withers' dialogue is still closing when the respec begins: the first panel waits for it, and a panel that never
-- showed (closed in the same frames, as LeUI did on BG2EE 2.7.3, 2026-10-25) is opened again (T.wantOpen).
function SQRespec_Tick()
	local now = Infinity_GetClockTicks()
	if T.wantOpen and panelOpen() then T.wantOpen = nil end     -- every frame: a panel closed by Back was seen
	if T.id and T.monster then                                  -- every frame: before the Done button
		local ok, err = pcall(watchClassPick)
		if not ok then T.lastError = 'class pick: ' .. tostring(err) end
	end
	if T.next and now < T.next then return false end
	T.next = now + 200
	if not T.id then
		if not T.nextBank or now >= T.nextBank then
			T.nextBank = now + 1000
			local ok, err = pcall(checkBankedXP)
			if not ok then T.lastError = 'bank: ' .. tostring(err) end
		end
		return false
	end
	if not sprite() then SQRespec_Finish() return false end
	if sprite().m_baseStats.m_xp > 0 then pcall(holdLevelOne, sprite()) pcall(refreshStats, sprite()) end
	local s = step()
	if panelOpen() then return false end
	if Infinity_IsMenuOnStack('WORLD_DIALOG') then return false end
	if s >= STEP_DONE then
		-- the last panel closed: the end (the Finish button was easy to miss behind other screens, 2026-10-23)
		SQRespec_Finish()
	elseif s ~= T.lastStep or (T.wantOpen and T.wantOpen.tries < 10) then
		T.wantOpen = { tries = (s == T.lastStep and T.wantOpen) and T.wantOpen.tries + 1 or 0 }
		T.lastStep = s
		SQRespec_Continue()
	end
	return false
end

-- Withers' dialogue: the party member who talked to him (the selected one).
-- A respec already running (its panel closed, the Continue bar unseen, John 2026-10-25): talking to him resumes it.
function SQRespec_BeginSelected()
	if T.id then T.lastStep, T.wantOpen = nil, nil return end     -- the tick reopens the panel once the dialogue is gone
	local sp = selected()
	local ok, monster = pcall(isMonster, sp)
	if not SQRespec_Begin(sp, { necro = ok and monster }) then T.lastError = 'could not begin' end
end

-- shared with #19 (Withers recruits, M_SQRECR.lua)
T.usable, T.levelOneHP, T.refreshStats = usable, levelOneHP, refreshStats

local function pushTick()
	if not Infinity_IsMenuOnStack('SQRESP_TICK') then Infinity_PushMenu('SQRESP_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQRESP') wrapItemDesc() end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end

-- Withers stands at the camp: one more resident for M_SQCAMP.lua (created when missing, old saves too)
if SQCamp and SQCamp.RESIDENTS then
	local known = false
	for _, r in ipairs(SQCamp.RESIDENTS) do if r[1] == 'SQWITHER' then known = true end end
	local w = SQCampSite and SQCampSite.WITHERS or { 205, 382, 12 }   -- (BG2EE's camp: its own spot)
	if not known then table.insert(SQCamp.RESIDENTS, { 'SQWITHER', w[1], w[2], w[3] }) end
end

pcall(wrapItemDesc)   -- loaded live: UI.MENU is already there
