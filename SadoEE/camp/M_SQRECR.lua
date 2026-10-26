--[[
SadoQoL component #19 - Withers recruits (John 2026-10-24). Design notes: SadoQoL/docs/RECRUIT.md.

Withers (the lich at the rest camp) brings a NEW player character into the party, multiplayer style, free:
- "create": the game's own character creation panels (gender, portrait, race, class, ..., colours, sounds, name),
  opened over the world on a blank creature (CHARBASE.CRE, the engine's own chargen base) that already stands next
  to Withers in the party;
- "import": the game's own import (character file / saved game) on a blank creature that is NOT in the party; the
  engine replaces it with a new creature outside any area, which we place next to Withers and add to the party.
The recruit then gets the protagonist's XP (the game's level-up screens raise him). A created recruit gets, instead
of the class's starting weapon and gold: one plain weapon per weapon proficiency (the best one equipped), the best
plain armour his class / kit may wear, a shield and a helmet when usable. An imported recruit: the player chooses
whether he keeps his own items and his own XP.

Reuses #17's driver pieces (M_SQRESP.lua): createCharScreen +0x770 = sprite id, +0x48 = portrait slot, +0x768 =
current step; createCharScreen:OnMenuButtonClick() opens the panel of the step; the starting-gear block of
CompleteCharacterSkills is skipped while SQRespec.flag is set.
Needs Extension EEex's PSXP7_Add for parties of 7+ (else JoinParty, up to 6).
--]]

SQRecruit = SQRecruit or {}
local T = SQRecruit

T.TXT_TITLE = [[SQ_RECR_TXT_TITLE]]
T.TXT_CONTINUE = [[SQ_RECR_TXT_CONTINUE]]
T.TXT_ABANDON = [[SQ_RECR_TXT_ABANDON]]
T.TXT_ITEMS_Q = [[SQ_RECR_TXT_ITEMS_Q]]
T.TXT_KEEP = [[SQ_RECR_TXT_KEEP]]
T.TXT_DROP = [[SQ_RECR_TXT_DROP]]
T.TXT_XP_Q = [[SQ_RECR_TXT_XP_Q]]
T.TXT_XP_OWN = [[SQ_RECR_TXT_XP_OWN]]
T.TXT_XP_LEADER = [[SQ_RECR_TXT_XP_LEADER]]
T.TXT_JOINED = [[SQ_RECR_TXT_JOINED]]
T.TXT_FULL = [[SQ_RECR_TXT_FULL]]
T.TXT_GEAR_TITLE = [[SQ_RECR_TXT_GEAR_TITLE]]
T.TXT_GEAR_OK = [[SQ_RECR_TXT_GEAR_OK]]
T.TXT_GEAR_OFFER = [[SQ_RECR_TXT_GEAR_OFFER]]
T.TXT_GEAR_COST = [[SQ_RECR_TXT_GEAR_COST]]
T.TXT_SRC_STASH = [[SQ_RECR_TXT_SRC_STASH]]
T.TXT_SRC_GOLD = [[SQ_RECR_TXT_SRC_GOLD]]
T.TXT_SLOT = { melee = [[SQ_RECR_TXT_S_MELEE]], offhand = [[SQ_RECR_TXT_S_OFFHAND]], ranged = [[SQ_RECR_TXT_S_RANGED]],
	ammo = [[SQ_RECR_TXT_S_AMMO]], armor = [[SQ_RECR_TXT_S_ARMOR]], helmet = [[SQ_RECR_TXT_S_HELMET]],
	amulet = [[SQ_RECR_TXT_S_AMULET]], ring = [[SQ_RECR_TXT_S_RING]], bracers = [[SQ_RECR_TXT_S_BRACERS]],
	belt = [[SQ_RECR_TXT_S_BELT]], boots = [[SQ_RECR_TXT_S_BOOTS]], cloak = [[SQ_RECR_TXT_S_CLOAK]] }

T.SPOT = { x = 240, y = 410 }      -- next to Withers (205, 382), between him and the fire
if SQCampSite and SQCampSite.RECRUIT then T.SPOT = { x = SQCampSite.RECRUIT[1], y = SQCampSite.RECRUIT[2] } end   -- BG2EE's camp
T.TEMPLATE = 'CHARBASE'

local PANELS = { 'CHARGEN_GENDER', 'CHARGEN_PORTRAIT', 'CHARGEN_RACE', 'CHARGEN_CLASS', 'CHARGEN_KIT',
	'CHARGEN_ALIGNMENT', 'CHARGEN_ABILITIES', 'CHARGEN_PROFICIENCIES', 'CHARGEN_CHOOSE_SPELLS',
	'CHARGEN_MEMORIZE_MAGE', 'CHARGEN_MEMORIZE_PRIEST', 'CHARGEN_HATEDRACE', 'CHARGEN_CUSTOMSOUNDS', 'CHARGEN_NAME',
	'CHARGEN_BIO', 'CHARGEN_DUALCLASS', 'CHARGEN_IMPORT', 'CHARACTER_SELECT', 'CHARACTER_COLOR',
	'POPUP_THREEBUTTON', 'CHARACTER_PORTRAIT' }   -- (LeUI's CHARGEN_PORTRAIT is a stub that opens CHARACTER_PORTRAIT)
local STEP_COLORS, STEP_DONE = 15, 18     -- 18: the name is done, the character is complete

local function cc() return EEex_UDToPtr(createCharScreen) end
local function step() return EEex_ReadU32(cc() + 0x768) end
local function ccId() return EEex_ReadU32(cc() + 0x770) end

local function spriteOf(id)
	local o = id and EEex_GameObject_Get(id)
	return o and o.m_objectType == 49 and EEex_GameObject_CastUserType(o) or nil
end
local function sprite() return spriteOf(T.id) end

local function panelOpen()
	for _, m in ipairs(PANELS) do if Infinity_IsMenuOnStack(m) then return m end end
	return nil
end

local function partyIds()
	local out = {}
	for i = 0, (PSXP7_N or 6) - 1 do
		local sp = EEex_Sprite_GetInPortrait(i)
		if sp then out[#out + 1] = sp.m_id end
	end
	return out
end
local function partySize() return #partyIds() end
local function maxParty() return (PSXP7_Add and PSXP7_N) or 6 end

local function leader() return EEex_Sprite_GetInPortrait(0) end

local function feedback(fmt, ...)
	local ok, s = pcall(string.format, fmt, ...)
	Infinity_DisplayString(ok and s or fmt)
end

-- ---- the blank creature ----
-- CreateCreature is an action: queued on the leader, the creature appears on a later tick. We find it as the
-- CHARBASE sprite of the area that did not exist before.
local function areaSprites(resref)
	local out = {}
	local lead = leader()
	local area = lead and lead.m_pArea
	if not area then return out end
	for _, l in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[l], function(id)
			local sp = spriteOf(id)
			if sp and string.upper(sp.m_resref:get()) == resref then out[id] = sp end
		end)
	end
	return out
end

local function spawnBlank()
	T.before = areaSprites(T.TEMPLATE)
	EEex_Action_QueueResponseStringOnAIBase(string.format('CreateCreature("%s",[%d.%d],12)', T.TEMPLATE,
		T.SPOT.x, T.SPOT.y), leader())
	T.phase = 'spawning'
	T.since = Infinity_GetClockTicks()
end

local function findSpawned()
	for id, sp in pairs(areaSprites(T.TEMPLATE)) do
		if not T.before[id] then return sp end
	end
	return nil
end

local function destroy(sp)
	if not sp then return end
	pcall(function()
		EEex_Action_QueueResponseStringOnAIBase('LeaveParty() DestroySelf()', sp)
	end)
end

-- ---- driving the panels ----
-- +0x800: the screen's mode. The Dual-Class screen leaves it at 6, where the portrait panel's Done goes back to the
-- record screen instead of the next step (BG2EE, John 2026-10-25): new characters are made in mode 0.
local CC_MODE = 0x800
local function saveScreen()
	T.old = { id = ccId(), step = step(), portrait = EEex_ReadU32(cc() + 0x48), mode = EEex_ReadU32(cc() + CC_MODE) }
	EEex_WriteU32(cc() + CC_MODE, 0)
end
local function restoreScreen()
	if T.old then
		EEex_WriteU32(cc() + 0x770, T.old.id)
		EEex_WriteU32(cc() + 0x768, T.old.step)
		EEex_WriteU32(cc() + 0x48, T.old.portrait)
		if T.old.mode then EEex_WriteU32(cc() + CC_MODE, T.old.mode) end
	end
	T.old = nil
end

-- The colour panel reads and writes characters[id] = the selected character: the recruit alone is selected.
local function selectRecruit(sp)
	if EEex_Sprite_GetPortraitIndex(sp) < 0 then return end
	pcall(function()
		local game = EngineGlobals.g_pBaldurChitin.m_pObjectGame
		game:UnselectAll()
		game:SelectCharacter(sp.m_id, false)
	end)
	pcall(Infinity_UpdateLuaStats)
	id = sp.m_id      -- the UI's current character (CHARACTER_COLOR reads characters[id])
end

local function primeLuaState()
	currentChargenAlignment = currentChargenAlignment or 1
	-- LeUI's gender step is a stub that applies this global, set by its CHARGEN screen's onOpen (2 there); left nil,
	-- the stub failed and stayed open under our screen, every button greyed (BG2EE 2.7.3, John 2026-10-25)
	gender = gender or 2
end

-- the game is paused while the creation screen is open (John 2026-10-24), and unpaused after if we paused it
local function pause()
	if T.paused then return end
	local ok, paused = pcall(function() return worldScreen:CheckIfPaused() end)
	if ok and not paused then pcall(function() worldScreen:TogglePauseGame(true) end) T.paused = true end
end
local function unpause()
	if not T.paused then return end
	T.paused = nil
	local ok, paused = pcall(function() return worldScreen:CheckIfPaused() end)
	if ok and paused then pcall(function() worldScreen:TogglePauseGame(true) end) end
end

-- Chargen hands out STARTARE.2DA START_XP (89000 in EET: level 7 or so). John (2026-10-25): a recruit is made at
-- level 1, then gets the protagonist's XP and the game's level-up screens raise him. Held at level 1 all through
-- the panels (the proficiency / spell screens count their picks from the level), and again at the end.
local MULTI = { [7] = 2, [8] = 2, [9] = 2, [10] = 3, [13] = 2, [14] = 2, [15] = 2, [16] = 2, [17] = 3, [18] = 2 }
local function levelOne(sp)
	local b = sp.m_baseStats
	local n = MULTI[sp.m_typeAI.m_Class] or 1
	b.m_xp = 0
	b.m_level1 = 1
	b.m_level2 = n >= 2 and 1 or 0
	b.m_level3 = n >= 3 and 1 or 0
end

local function refresh(sp) if SQRespec and SQRespec.refreshStats then pcall(SQRespec.refreshStats, sp) end end

local function setGear(on) if SQRespec and SQRespec.flag then EEex_WriteU8(SQRespec.flag, on and 1 or 0) end end

function SQRecruit_Continue()
	if not T.id or panelOpen() or T.phase ~= 'panels' then return end
	if step() >= STEP_DONE then return end
	primeLuaState()
	local sp = sprite()
	if sp then selectRecruit(sp) end
	if T.wrapInGame then pcall(T.wrapInGame) end      -- (UI.MENU reloaded: CurrentlyInGame is new again)
	local ok, err = pcall(function() createCharScreen:OnMenuButtonClick() end)
	if not ok then T.lastError = tostring(err) end
end

-- ---- the gear screen (menu SQRECR_GEAR, John 2026-10-24) ----
-- The last creation screen: for each slot the best items the recruit can use, from the Party Stash (free) and the
-- Grand marchand (bought at its price); nothing is given for free (John 2026-10-24): the 3 best melee weapons (at
-- least one one-handed, at least one plain), ranged weapons + their ammunition, armours (one plain), the off hand (shields, or
-- weapons for Two-Weapon Style); every usable helmet, amulet, ring, bracers, belt, boots and cloak. One pick per slot
-- (two rings), the best pre-checked by John's rules.
local MELEE_TYPES = { [16] = 1, [17] = 1, [19] = 1, [20] = 1, [21] = 1, [22] = 1, [23] = 1, [25] = 1, [26] = 1,
	[28] = 1, [29] = 1, [30] = 1, [44] = 1, [57] = 1, [69] = 1 }
local AMMO_TYPES = { [5] = 1, [14] = 1, [31] = 1 }
local LAUNCHER_AMMO = { [15] = 5, [27] = 31, [18] = 14 }     -- bow -> arrows, crossbow -> bolts, sling -> bullets
local SLOTS = {   -- key, item types, top n (0 = all), equip slot (SLOTS.IDS)
	{ key = 'melee', top = 3, slot = 'SLOT_WEAPON0' },
	{ key = 'offhand', top = 3, slot = 'SLOT_SHIELD' },
	{ key = 'ranged', top = 3, slot = 'SLOT_WEAPON1' },
	{ key = 'ammo', top = 3, slot = 'SLOT_AMMO0' },
	{ key = 'armor', types = { [2] = 1 }, top = 3, slot = 'SLOT_ARMOR' },
	{ key = 'helmet', types = { [7] = 1 }, top = 0, slot = 'SLOT_HELMET' },
	{ key = 'amulet', types = { [1] = 1 }, top = 0, slot = 'SLOT_AMULET' },
	{ key = 'ring', types = { [10] = 1 }, top = 0, slot = 'SLOT_RING_LEFT', slot2 = 'SLOT_RING_RIGHT', picks = 2 },
	{ key = 'bracers', types = { [3] = 1 }, top = 0, slot = 'SLOT_GAUNTLETS' },
	{ key = 'belt', types = { [4] = 1 }, top = 0, slot = 'SLOT_BELT' },
	{ key = 'boots', types = { [6] = 1 }, top = 0, slot = 'SLOT_BOOTS' },
	{ key = 'cloak', types = { [32] = 1 }, top = 0, slot = 'SLOT_CLOAK' },
}

local function bit(v, b) return math.floor(v / 2 ^ b) % 2 == 1 end

local function readRes(p)
	local out = {}
	for i = 0, 7 do
		local c = EEex_ReadU8(p + i)
		if c == 0 then break end
		out[#out + 1] = string.char(c)
	end
	return string.upper(table.concat(out))
end

-- raw ITM header (EEex_Resource_Demand keeps it loaded): what the userdata does not name
local itmCache = {}
local function itm(res)
	if itmCache[res] ~= nil then return itmCache[res] or nil end
	local ok, h = pcall(EEex_Resource_Demand, res, 'ITM')
	if not ok or not h then itmCache[res] = false return nil end
	local p = EEex_UDToPtr(h)
	local info = { res = res, type = EEex_ReadU16(p + 0x1C), flags = EEex_ReadU32(p + 0x18),
		prof = EEex_ReadU8(p + 0x31), price = EEex_ReadU32(p + 0x34), stack = math.max(1, EEex_ReadU16(p + 0x38)),
		icon = readRes(p + 0x3A), enchant = EEex_ReadU32(p + 0x60),
		name = h.identifiedName > 0 and h.identifiedName or h.genericName }
	info.magic = bit(info.flags, 6)
	info.twoHanded = bit(info.flags, 1)
	-- first ability: damage / to-hit
	local abOff, abCount = EEex_ReadU32(p + 0x64), EEex_ReadU16(p + 0x68)
	if abCount > 0 then
		local a = p + abOff
		local sides, dice, bonus = EEex_ReadU8(a + 0x16), EEex_ReadU8(a + 0x18), EEex_Read16(a + 0x1A)
		info.abType, info.hit, info.dmg = EEex_ReadU8(a), EEex_Read16(a + 0x14), dice * (sides + 1) / 2 + bonus
	end
	-- equipped effects: AC (opcode 0; param2 16 = base AC, else a bonus)
	local fOff, fIdx, fCount = EEex_ReadU32(p + 0x6A), EEex_ReadU16(p + 0x6E), EEex_ReadU16(p + 0x70)
	info.ac = 0
	for i = 0, fCount - 1 do
		local f = p + fOff + (fIdx + i) * 0x30
		if EEex_ReadU16(f) == 0 then
			local v, kind = EEex_Read32(f + 4), EEex_ReadU32(f + 8)
			if kind == 16 then info.ac = info.ac + (10 - v) else info.ac = info.ac + v end
		end
	end
	itmCache[res] = info
	return info
end

local function usable(sp, res)
	if SQRespec and SQRespec.usable then return SQRespec.usable(sp, res) end
	return true
end

local function stars(sp, stat)
	local ok, v = pcall(EEex_Sprite_GetStat, sp, stat)
	return ok and tonumber(v) or 0
end

local STAR_HIT = { [0] = -4, 0, 1, 3, 3, 3 }
local STAR_DMG = { [0] = 0, 0, 2, 3, 4, 5 }
local function weaponScore(sp, it)
	-- the Party Stash's own DPS figure (damage per round x to-hit, bows' extra attack, strength, stars) when there
	if PStash_WeaponDps and PStash_ItemInfo then
		local ok, d = pcall(PStash_WeaponDps, EEex_Sprite_GetPortraitIndex(sp), PStash_ItemInfo(it.res))
		if ok and d then return d.score end
	end
	local n = math.min(stars(sp, it.prof), 5)
	return (it.dmg or 0) + STAR_DMG[n] + 0.5 * ((it.hit or 0) + STAR_HIT[n]) + 0.25 * it.enchant
end

local function gold()
	local ok, g = pcall(function() return game:GetPartyGold() end)
	return ok and g or 0
end

-- every candidate: { res, info, src = 'stash' | 'merchant', price, count }
local function pool(sp)
	local out, seen = {}, {}
	local function add(res, src, price, count)
		res = string.upper(res)
		local key = res .. '/' .. src
		if seen[key] then return end
		local info = itm(res)
		if not info or not usable(sp, res) then return end
		seen[key] = true
		out[#out + 1] = { res = res, info = info, src = src, price = price or 0, count = count or 1 }
	end
	if PStash_List then
		local ok, list = pcall(PStash_List)
		if ok then for _, e in ipairs(list) do if e.identified then add(e.res, 'stash', 0, e.count) end end end
	end
	if PSXGM_Pool then
		local ok, list = pcall(PSXGM_Pool)
		if ok and type(list) == 'table' then for res, e in pairs(list) do add(res, 'merchant', e.price, e.stock) end end
	end
	return out
end

-- fighting styles (STATS.IDS): 111 two-handed, 112 sword and shield, 113 single weapon, 114 two weapons
local function twoWeapons(sp) return stars(sp, 114) > 0 end
local function singleWeapon(sp) return stars(sp, 113) > 0 end

local function fits(sp, slot, c, chosen)
	local t, i = c.info.type, c.info
	if slot.key == 'melee' then return MELEE_TYPES[t] ~= nil and i.abType == 1 end
	if slot.key == 'offhand' then
		if twoWeapons(sp) then return MELEE_TYPES[t] ~= nil and not i.twoHanded and i.abType == 1 end
		return t == 12
	end
	if slot.key == 'ranged' then return LAUNCHER_AMMO[t] ~= nil end
	if slot.key == 'ammo' then
		local l = chosen.ranged and chosen.ranged[1]
		return l ~= nil and LAUNCHER_AMMO[l.info.type] == t
	end
	return slot.types[t] ~= nil
end

local function score(sp, slot, c)
	local i = c.info
	if slot.key == 'melee' or (slot.key == 'offhand' and i.type ~= 12) then return weaponScore(sp, i) end
	if slot.key == 'ranged' then return weaponScore(sp, i) end
	if slot.key == 'ammo' then return (i.dmg or 0) + i.enchant end
	if slot.key == 'armor' or slot.key == 'offhand' then return i.ac end
	return i.price
end

local function better(a, b)
	if a.score ~= b.score then return a.score > b.score end
	if a.src ~= b.src then return a.src == 'stash' end
	return a.info.price > b.info.price
end

-- the rows of one slot, best first (top 3 with a plain one and, for melee, a one-handed one kept in)
local function candidates(sp, slot, chosen)
	local list = {}
	for _, c in ipairs(T.gear.all) do
		if fits(sp, slot, c, chosen) then
			c.score = score(sp, slot, c)
			list[#list + 1] = c
		end
	end
	table.sort(list, better)
	if slot.top == 0 then return list end
	local top = {}
	for k = 1, math.min(slot.top, #list) do top[k] = list[k] end
	local function keep(pred)
		for _, c in ipairs(top) do if pred(c) then return end end
		for _, c in ipairs(list) do
			if pred(c) then top[#top] = c table.sort(top, better) return end
		end
	end
	if slot.key == 'melee' then keep(function(c) return not c.info.twoHanded end) end
	if slot.key ~= 'ammo' then keep(function(c) return not c.info.magic end) end
	return top
end

-- John's defaults: the best of each top-3 slot; the off hand: nothing for Single Weapon Style or a two-handed
-- weapon, the favourite melee weapon again for Two-Weapon Style (when one-handed), else the best shield.
local function rebuild(sp)
	local chosen = T.gear.chosen
	T.gear.rows = {}
	for _, slot in ipairs(SLOTS) do
		local list = candidates(sp, slot, chosen)
		if not T.gear.auto[slot.key] then
			local pick = slot.top > 0 and list[1] or nil
			if slot.key == 'offhand' then
				local m = chosen.melee and chosen.melee[1]
				if singleWeapon(sp) or (m and m.info.twoHanded) then pick = nil
				elseif twoWeapons(sp) then
					pick = nil
					if m then for _, c in ipairs(list) do if c.res == m.res then pick = c break end end end
				end
			end
			chosen[slot.key] = pick and { pick } or {}
			T.gear.auto[slot.key] = true
		end
		for _, c in ipairs(list) do T.gear.rows[#T.gear.rows + 1] = { slot = slot, c = c } end
	end
	T.gear.picked = {}
	for _, slot in ipairs(SLOTS) do
		for _, c in ipairs(chosen[slot.key] or {}) do T.gear.picked[#T.gear.picked + 1] = { slot = slot, c = c } end
	end
	sqRecrOffer, sqRecrPicked = {}, {}
	for k = 1, #T.gear.rows do sqRecrOffer[k] = k end
	for k = 1, #T.gear.picked do sqRecrPicked[k] = k end
end

local function isChosen(slotKey, c)
	for _, x in ipairs(T.gear.chosen[slotKey] or {}) do if x == c then return true end end
	return false
end

local function cost()
	local total = 0
	for _, picks in pairs(T.gear.chosen) do
		for _, c in ipairs(picks) do if c.src == 'merchant' then total = total + c.price end end
	end
	return total
end

local function row(list, i)
	local r = T.gear and T.gear[list] and T.gear[list][i]
	return r and r.c, r and r.slot
end
local function priceText(c) return c.src == 'stash' and T.TXT_SRC_STASH or string.format(T.TXT_SRC_GOLD, c.price) end

-- left: what is offered (store items); right: what the recruit gets (the party's side of the store)
function SQRecruit_OfferIcon(i) local c = row('rows', i) return c and c.info.icon or '' end
function SQRecruit_OfferName(i) local c = row('rows', i) return c and Infinity_FetchString(c.info.name) or '' end
function SQRecruit_OfferPrice(i) local c = row('rows', i) return c and priceText(c) or '' end
function SQRecruit_OfferFrame(i)
	local c, slot = row('rows', i)
	return (c and isChosen(slot.key, c)) and 2 or 0
end
function SQRecruit_OfferGrey(i)
	local c, slot = row('rows', i)
	return c ~= nil and not isChosen(slot.key, c) and c.src == 'merchant' and cost() + c.price > gold()
end
function SQRecruit_PickIcon(i) local c = row('picked', i) return c and c.info.icon or '' end
function SQRecruit_PickName(i) local c = row('picked', i) return c and Infinity_FetchString(c.info.name) or '' end
function SQRecruit_PickPrice(i) local c = row('picked', i) return c and priceText(c) or '' end

local function toggle(c, slot)
	local key = slot.key
	local picks = T.gear.chosen[key] or {}
	for k, x in ipairs(picks) do
		if x == c then
			table.remove(picks, k)
			T.gear.chosen[key] = picks
			rebuild(sprite())
			return
		end
	end
	if c.src == 'merchant' and cost() + c.price > gold() then return end
	if (slot.picks or 1) <= #picks then table.remove(picks, 1) end
	picks[#picks + 1] = c
	T.gear.chosen[key] = picks
	if key == 'ranged' then T.gear.auto.ammo = nil end   -- the ammunition follows the launcher
	if key == 'melee' then T.gear.auto.offhand = nil end
	rebuild(sprite())
end
function SQRecruit_OfferClick(i) local c, slot = row('rows', i) if c then toggle(c, slot) end end
function SQRecruit_PickClick(i) local c, slot = row('picked', i) if c then toggle(c, slot) end end

-- right click: the game's item description window (as the Party Stash and the Grand marchand open it)
local function describe(c)
	if not c or not showItemDescription then return end
	local ok, h = pcall(EEex_Resource_Demand, c.res, 'ITM')
	if not ok or not h then return end
	local ptr = EEex_UDToPtr(h)
	local desc = EEex_ReadU32(ptr + 0x54)              -- identified description (else +0x50, the unidentified one)
	if desc == 0 or desc == 0xFFFFFFFF then desc = EEex_ReadU32(ptr + 0x50) end
	local pic = {}
	for k = 0, 7 do
		local ch = EEex_ReadU8(ptr + 0x58 + k)
		if ch == 0 then break end
		pic[#pic + 1] = string.char(ch)
	end
	showItemDescription({ name = Infinity_FetchString(c.info.name), description = Infinity_FetchString(desc),
		descPicture = table.concat(pic), icon = c.info.icon }, 2)
end
function SQRecruit_OfferDescribe(i) describe((row('rows', i))) end
function SQRecruit_PickDescribe(i) describe((row('picked', i))) end
function SQRecruit_GearGold() return tostring(gold()) end
function SQRecruit_GearCostValue() return tostring(cost()) end
function SQRecruit_RecruitName() local sp = sprite() return sp and sp:getName() or '' end

function SQRecruit_GearCost() return string.format(T.TXT_GEAR_COST, cost(), gold()) end

-- one item onto the recruit: from the stash (PStash_Take puts it in his backpack), bought from the Grand marchand,
-- or made (plain items); then into its slot
local function equip(sp, c, slotName)
	local stackable = AMMO_TYPES[c.info.type] ~= nil
	if c.src == 'stash' then
		if not PStash_Take then return end
		local portrait = EEex_Sprite_GetPortraitIndex(sp)
		local n = stackable and math.max(1, math.ceil(c.count / c.info.stack)) or 1    -- ammunition: all of it (John)
		for _ = 1, n do if not PStash_Take(portrait, c.res) then break end end
	else
		-- PSXGM_PoolTake takes the copy out of the known stores' stock and pays; it refuses before touching anything
		if not (PSXGM_PoolTake and PSXGM_PoolTake(c.res, 1)) then return end
		EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('CreateItem("%s",%d,0,0)', c.res,
			stackable and c.info.stack or 0), sp)
	end
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('XEquipItem("%s",Myself,%s,EQUIP)', c.res,
		slotName), sp)
end

local function closeGear()
	if Infinity_IsMenuOnStack('SQRECR_GEAR') then Infinity_PopMenu('SQRECR_GEAR') end
	if Infinity_IsMenuOnStack('SQRECR_SHADE') then Infinity_PopMenu('SQRECR_SHADE') end
end

local function joined(sp)
	local l = leader()
	sp.m_baseStats.m_xp = l and l.m_baseStats.m_xp or 0
	refresh(sp)
	feedback(T.TXT_JOINED, sp:getName())
	T.id, T.phase, T.mode, T.gear = nil, nil, nil, nil
end

-- The window is laid out as the stock store (STORE_BUYSELL); LeUI draws its store differently (a taller frame, the
-- buttons inside it, no bottom bar): its own places then (John 2026-10-25, BG2EE 2.7.3).
local LEUI_GEAR = {
	sqRecrGearBg = { 0, 0, 864, 614 }, sqRecrGearTitle = { 48, 6, 768, 52 }, sqRecrGearOffer = { 277, 68, 310, 26 },
	sqRecrGearGold = { 274, 103, 313, 31 }, sqRecrGearOfferList = { 19, 138, 434, 376 },
	sqRecrGearPickList = { 462, 138, 392, 376 }, sqRecrGearCostLabel = { 94, 524, 146, 23 },
	sqRecrGearCost = { 319, 524, 108, 23 }, sqRecrGearOk = { 604, 560, 201, 44 },
}
function SQRecruit_GearLayout()
	if not LeUI_uiStrings then return end
	for item, a in pairs(LEUI_GEAR) do pcall(Infinity_SetArea, item, a[1], a[2], a[3], a[4]) end
end

function SQRecruit_GearValidate()
	local sp = sprite()
	if sp and T.gear then
		for _, slot in ipairs(SLOTS) do
			for k, c in ipairs(T.gear.chosen[slot.key] or {}) do
				local ok, err = pcall(equip, sp, c, k == 2 and slot.slot2 or slot.slot)
				if not ok then T.lastError = 'equip ' .. c.res .. ': ' .. tostring(err) end
			end
		end
	end
	closeGear()
	unpause()
	if sp then joined(sp) else T.id, T.phase, T.mode, T.gear = nil, nil, nil, nil end
end

local function openGear(sp)
	T.phase = 'gear'
	T.gear = { chosen = {}, auto = {}, rows = {} }
	T.gear.all = pool(sp)
	rebuild(sp)
	sqRecrOfferRow, sqRecrPickedRow = 0, 0
	pause()
	if not Infinity_IsMenuOnStack('SQRECR_SHADE') then Infinity_PushMenu('SQRECR_SHADE') end
	if not Infinity_IsMenuOnStack('SQRECR_GEAR') then Infinity_PushMenu('SQRECR_GEAR') end
end

local function dropItems(sp)
	-- an imported recruit who leaves his own items behind: everything but the fist goes
	local acts = {}
	for i = 0, 38 do
		local it = sp.m_equipment.m_items:get(i)
		if it and i ~= 10 then acts[#acts + 1] = string.format('DestroyItem("%s")', it.pRes.resref:get()) end
	end
	if #acts > 0 then EEex_Action_QueueResponseStringOnAIBase(table.concat(acts, ' '), sp) end
end

local function leaderXP()
	local l = leader()
	return l and l.m_baseStats.m_xp or 0
end

local function joinParty(sp)
	if EEex_Sprite_GetPortraitIndex(sp) >= 0 then return true end
	if not sp.m_pArea then
		local lead = leader()
		if not (lead and lead.m_pArea) then return false end
		EEex_Object_AddToArea(sp, lead.m_pArea, T.SPOT.x, T.SPOT.y)
	end
	if PSXP7_Add then
		local ok, res = pcall(PSXP7_Add, sp.m_id)
		if ok and res then return true end
	end
	EEex_Action_QueueResponseStringOnAIBase('JoinParty()', sp)
	return true
end

local function finish()
	local sp = sprite()
	setGear(false)
	unpause()
	restoreScreen()
	if Infinity_IsMenuOnStack('SQRECR_MAIN') then Infinity_PopMenu('SQRECR_MAIN') end
	if Infinity_IsMenuOnStack('SQRECR_SHADE') then Infinity_PopMenu('SQRECR_SHADE') end
	if not sp then T.id, T.phase = nil, nil return end
	if T.mode == 'import' then
		joinParty(sp)
		T.phase = 'ask'          -- items / XP questions (window SQRECR_ASK)
		if not Infinity_IsMenuOnStack('SQRECR_ASK') then Infinity_PushMenu('SQRECR_ASK') end
		return
	end
	levelOne(sp)
	if SQRespec and SQRespec.levelOneHP then
		local hp = SQRespec.levelOneHP(sp)
		sp.m_baseStats.m_maxHitPointsBase, sp.m_baseStats.m_hitPoints = hp, hp
	end
	refresh(sp)
	local ok, err = pcall(openGear, sp)
	if not ok then T.lastError = 'gear: ' .. tostring(err) closeGear() unpause() joined(sp) end
end

function SQRecruit_AskText()
	return T.ask == 'xp' and T.TXT_XP_Q or T.TXT_ITEMS_Q
end
function SQRecruit_AskLeft() return T.ask == 'xp' and T.TXT_XP_OWN or T.TXT_KEEP end
function SQRecruit_AskRight() return T.ask == 'xp' and T.TXT_XP_LEADER or T.TXT_DROP end
function SQRecruit_Answer(left)
	local sp = sprite()
	if not sp then
		T.id, T.phase, T.mode, T.ask = nil, nil, nil, nil
		Infinity_PopMenu('SQRECR_ASK')
		return
	end
	if T.ask ~= 'xp' then
		if not left then pcall(dropItems, sp) end
		T.ask = 'xp'
		return
	end
	if not left then sp.m_baseStats.m_xp = leaderXP() end
	refresh(sp)
	Infinity_PopMenu('SQRECR_ASK')
	feedback(T.TXT_JOINED, sp:getName())
	T.id, T.phase, T.mode, T.ask = nil, nil, nil, nil
end

function SQRecruit_Abandon()
	local sp = sprite()
	setGear(false)
	unpause()
	for _, m in ipairs(PANELS) do if Infinity_IsMenuOnStack(m) then Infinity_PopMenu(m) end end
	if sp then
		-- the creation screen's own Cancel deletes the character and frees his party slot (a creature left
		-- half-made by the panels no longer runs his actions: LeaveParty / DestroySelf are never executed)
		EEex_WriteU32(cc() + 0x770, sp.m_id)
		local slot = EEex_Sprite_GetPortraitIndex(sp)
		if slot >= 0 then EEex_WriteU32(cc() + 0x48, slot) end
		local ok, err = pcall(function() createCharScreen:OnMainCancelButtonClick() end)
		if not ok then T.lastError = 'cancel: ' .. tostring(err) destroy(sp) end
	end
	restoreScreen()
	if Infinity_IsMenuOnStack('SQRECR_MAIN') then Infinity_PopMenu('SQRECR_MAIN') end
	if Infinity_IsMenuOnStack('SQRECR_SHADE') then Infinity_PopMenu('SQRECR_SHADE') end
	T.id, T.phase, T.mode, T.ask, T.imported, T.lastStep = nil, nil, nil, nil, nil, nil
end

-- ---- the start (Withers' dialogue) ----
function SQRecruit_Begin(mode)
	if T.phase then return false end
	-- a respec still running: Withers takes it up again first (M_SQRESP.lua)
	if SQRespec and SQRespec_Active and SQRespec_Active() then SQRespec_BeginSelected() return false end
	if partySize() >= maxParty() then feedback(T.TXT_FULL, maxParty()) return false end
	T.mode = mode == 'import' and 'import' or 'create'
	spawnBlank()
	return true
end

-- The shade lifts the sidebars over it (pushSidebars, as the record screen does). The game's popSidebars() takes them
-- off the stack, made for screens of their own: over the world, 2.6.6 then lost its sidebars and portraits until
-- reloaded (John 2026-10-25). Those that were up come back.
local SIDEBARS = { 'RIGHT_SIDEBAR', 'RIGHT_SIDEBAR_HIDDEN', 'LEFT_SIDEBAR', 'LEFT_SIDEBAR_HIDDEN' }
function SQRecruit_ShadeOpen()
	T.sidebars = {}
	for _, m in ipairs(SIDEBARS) do if Infinity_IsMenuOnStack(m) then T.sidebars[#T.sidebars + 1] = m end end
	pushSidebars()
end
function SQRecruit_ShadeClose()
	popSidebars()
	for _, m in ipairs(T.sidebars or {}) do
		if not Infinity_IsMenuOnStack(m) then Infinity_PushMenu(m) end
	end
	T.sidebars = nil
end

local function showMain()
	if not Infinity_IsMenuOnStack('SQRECR_SHADE') then Infinity_PushMenu('SQRECR_SHADE') end
	if not Infinity_IsMenuOnStack('SQRECR_MAIN') then Infinity_PushMenu('SQRECR_MAIN') end
end

local function startPanels(sp)
	T.id, T.lastStep, T.lastOpen = sp.m_id, nil, nil
	sp.m_baseStats.m_gold = 0            -- CHARBASE carries 100 gold, handed to the party when he joins
	saveScreen()
	setGear(true)
	EEex_WriteU32(cc() + 0x770, sp.m_id)
	EEex_WriteU32(cc() + 0x768, 0)
	if T.mode == 'import' then
		-- not in the party: the engine replaces this creature by the imported one. The creation screen comes after
		-- the pick: pushed now, it hid the game's import popup and list (John 2026-10-24)
		EEex_WriteU32(cc() + 0x48, partySize())
		T.phase, T.imported, T.lastOpen = 'panels', false, 'POPUP_THREEBUTTON'
		pause()
		local ok, err = pcall(function() createCharScreen:OnImportCharacterButtonClick() end)
		if not ok then T.lastError = tostring(err) SQRecruit_Abandon() end
	else
		showMain()
		T.phase = 'joining'
		EEex_Action_QueueResponseStringOnAIBase('JoinParty()', sp)
	end
end

function SQRecruit_Title()
	local sp = sprite()
	local name = sp and sp:getName() or ''
	return name ~= '' and string.format('%s - %s', T.TXT_TITLE, name) or T.TXT_TITLE
end
function SQRecruit_Active() return T.phase == 'panels' end

-- ---- the creation screen (menu SQRECR_MAIN, a copy of the game's CHARGEN) ----
function SQRecruit_Step() return T.phase == 'panels' and step() or -1 end
-- a step button covers the steps its panels go through (gender + portrait, class + kit, skills + spells ...): a panel
-- closed with Back leaves the step where it was, and its button must reopen it (John 2026-10-25: stuck on portrait)
function SQRecruit_StepIn(lo, hi)
	local s = SQRecruit_Step()
	return s >= lo and s <= hi and not panelOpen()
end
function SQRecruit_CanAccept() return T.phase == 'panels' and step() >= STEP_DONE and not panelOpen() end
function SQRecruit_Accept() if SQRecruit_CanAccept() then finish() end end
function SQRecruit_Back()
	if T.phase ~= 'panels' or panelOpen() then return end
	local ok, can = pcall(function() return createCharScreen:IsMainBackButtonClickable() end)
	if step() <= 0 or not (ok and can) then SQRecruit_Abandon() return end
	T.lastStep = nil
	local ok2, err = pcall(function() createCharScreen:OnMainBackButtonClick() end)
	if not ok2 then T.lastError = 'back: ' .. tostring(err) end
end
function SQRecruit_Portrait()
	local sp = sprite()
	local res = sp and sp.m_baseStats.m_portraitLarge:get() or ''
	return (res ~= '' and res ~= 'None') and res or ''
end

local function str(ref)
	ref = tonumber(ref or '')
	return (ref and ref > 0) and Infinity_FetchString(ref) or ''
end
local function raceName(r)
	local ok, v = pcall(function()
		local a = EEex_Resource_Load2DA('RACETEXT')
		local out
		for row = 0, 40 do
			local id = tonumber(a:getAtPoint(0, row) or '')
			if id == r then out = a:getAtPoint(1, row) break end
		end
		EEex_Resource_Free2DA(a)
		return out
	end)
	return ok and str(v) or ''
end
local function className(c, kit)
	local ok, v = pcall(function()
		local a = EEex_Resource_Load2DA('CLASTEXT')
		local out
		for row = 0, 200 do
			local cid, kid = tonumber(a:getAtPoint(0, row) or ''), tonumber(a:getAtPoint(1, row) or '')
			if cid == c and (kid == kit or (kit == 0 and kid == 16384)) then out = a:getAtPoint(4, row) break end
			if cid == nil then break end
		end
		EEex_Resource_Free2DA(a)
		return out
	end)
	return ok and str(v) or ''
end

-- 2.7 renamed t() to getUiString(); 2.6.6 only has t()
local uiString = getUiString or t

-- the summary on the right of the creation screen (the game fills chargen.information only on its own screen)
function SQRecruit_Info()
	local sp = sprite()
	if not sp then return '' end
	local b, t = sp.m_baseStats, sp.m_typeAI
	local lines = {}
	local name = sp:getName() or ''
	if name ~= '' then lines[#lines + 1] = name end
	local s = step()
	if s >= 3 then lines[#lines + 1] = raceName(t.m_Race) end
	if s >= 7 then
		local kit = math.floor(b.m_mageSpecUpperWord or 0) % 0x10000
		lines[#lines + 1] = className(t.m_Class, kit > 0x4000 and kit - 0x4000 or 0)
	end
	if s >= 9 then
		lines[#lines + 1] = ''
		for _, a in ipairs({ { 'STRENGTH_LABEL', 'm_STRBase' }, { 'DEXTERITY_LABEL', 'm_DEXBase' },
				{ 'CONSTITUTION_LABEL', 'm_CONBase' }, { 'INTELLIGENCE_LABEL', 'm_INTBase' },
				{ 'WISDOM_LABEL', 'm_WISBase' }, { 'CHARISMA_LABEL', 'm_CHRBase' } }) do
			lines[#lines + 1] = string.format('%s: %d', uiString(a[1]), b[a[2]])
		end
	end
	return table.concat(lines, '\n')
end

-- ---- tick (menu SQRECR_TICK) ----
local function tick()
	local now = Infinity_GetClockTicks()
	if not T.phase or T.phase == 'ask' then return end
	if T.phase == 'spawning' then
		local sp = findSpawned()
		if sp then startPanels(sp)
		elseif now - T.since > 5000 then T.phase, T.mode = nil, nil T.lastError = 'spawn failed' end
		return
	end
	if T.phase == 'joining' then
		local sp = sprite()
		if not sp then SQRecruit_Abandon() return end
		if EEex_Sprite_GetPortraitIndex(sp) >= 0 then
			EEex_WriteU32(cc() + 0x48, EEex_Sprite_GetPortraitIndex(sp))
			T.phase = 'panels'
			pause()
			SQRecruit_Continue()
		end
		return
	end
	-- panels: the import swaps the creature (new id at +0x770)
	if T.mode == 'import' and ccId() ~= T.id and spriteOf(ccId()) then T.id, T.imported = ccId(), true end
	if T.mode == 'import' and T.imported and not panelOpen() then showMain() end
	if not sprite() then SQRecruit_Abandon() return end
	-- (the derived stats follow at once: a level drop seen later costs the HP written at the end, M_SQRESP.lua)
	if T.mode == 'create' and sprite().m_baseStats.m_xp > 0 then levelOne(sprite()) refresh(sprite()) end
	local open = panelOpen()
	if open then
		T.lastOpen = open
		return
	end
	-- the colour panel only advances the step under the creation screen: we do it when it closes
	if T.lastOpen == 'CHARACTER_COLOR' and step() == STEP_COLORS then
		pcall(function() createCharScreen:OnDoneButtonClick() end)
	end
	local closed = T.lastOpen
	T.lastOpen = nil
	-- import window closed with Back / Cancel before a character was picked: nothing to recruit
	if T.mode == 'import' and not T.imported then SQRecruit_Abandon() return end
	local s = step()
	-- Back on the first panel (gender): the half-made recruit is deleted (John 2026-10-24)
	-- (its Done always moves to the portrait, step 1; its Back calls OnCancelButtonClick, whose step is not 0 here)
	if closed == 'CHARGEN_GENDER' and s ~= 1 then SQRecruit_Abandon() return end
	if s >= STEP_DONE then return end      -- complete: the Accept button of the creation screen ends it
	if s ~= T.lastStep then
		T.lastStep = s
		SQRecruit_Continue()
	end
end

function SQRecruit_Tick()
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + 200
	local ok, err = pcall(tick)
	if not ok then T.lastError = tostring(err) end
	return false
end

-- LeUI's portrait panel serves the record screen's Customize too: in game (CurrentlyInGame()) it lists the portraits
-- of characters[currentID], which a recruit has not, and hides the gender buttons; the list stayed empty and the
-- game hung (BG2EE 2.7.3, John 2026-10-25). While a new recruit is at the portrait step it is a new character.
local function wrapInGame()
	if not LeUI_uiStrings or not CurrentlyInGame or CurrentlyInGame == T.inGame then return end
	local orig = CurrentlyInGame
	T.inGame = function()
		if T.phase == 'panels' and T.mode == 'create' and step() == 1 then return false end
		return orig()
	end
	CurrentlyInGame = T.inGame
end
T.wrapInGame = wrapInGame

local function pushTick()
	if not Infinity_IsMenuOnStack('SQRECR_TICK') then Infinity_PushMenu('SQRECR_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQRECR') pcall(wrapInGame) end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end

pcall(wrapInGame)   -- loaded live: UI.MENU is already there
