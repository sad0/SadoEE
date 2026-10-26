--[[
SadoQoL component #20 - the camp necromancer: target dummies (John 2026-10-24).

A necromancer in a black robe stands where the forest path leaves the camp, north (SQNECRO.CRE). He raises the
creatures the party has seen die (John 2026-10-25: any hostile creature dying in the party's area, that exact
creature, per save: global SQK<resref without its first letter>), from the bestiary (M_SQBEST.lua written at
install from every CRE), as many as the party wants:
 - talk -> "Raise a creature" opens the bestiary (SQNECR.menu: Monsters / Humans tabs, search, level/HP/AC);
   a pick brings his second line, "how many?" (1 / 2 / 3 / 5 / 10).
 - The raised start undying and passive: no scripts, HP never below 1 (opcode 208), immune to instant death,
   healed to full every tick; they still count the damage taken.
 - His other lines act on all of them at once: unleash (mortal, hostile, their own scripts back, healed and purged
   by script, no animation) / calm (undying passive again, healed and purged) / clean up (they die on the spot) /
   join the party (real members, JoinParty; they leave the necromancer's care).
 - Never XP nor loot from them: XP value 0, gold 0, items flagged undroppable (dropped back to normal on joining).
 - Damage meter: every damage effect (opcode 12) reaching a raised creature passes through the opcode 403 screen
   SQDMGSCR, which notes its source; the HP lost between two ticks goes to those sources. A session starts on the
   first hit and ends after 6 s without damage; the panel (SQNECR_DPS) shows damage and DPS per attacker, the
   total and the length, until the next hit or Reset.
 - The other camp people (priestess, merchant, scholar, Withers, the necromancer) are immune to everything and
   never fight.
Raised creatures carry the local variable SQDUMMY (1 undying, 2 unleashed), saved with them.
--]]

SQNecro = SQNecro or {}
local T = SQNecro

T.RES    = 'SQNECRO'
T.SPOT   = T.SPOT or { 872, 214, 6 }       -- where the forest path leaves the camp, facing south-west
T.CENTER = T.CENTER or { 850, 104 }        -- the raised stand up the path, in rows
if SQCampSite and SQCampSite.NECRO then T.SPOT, T.CENTER = SQCampSite.NECRO, SQCampSite.NECRO_CENTER end   -- BG2EE's camp
T.GAP    = 44
T.BUFFER = 10000                           -- max HP added to the undying
T.SESSION_IDLE = 6000                      -- ms without damage: the session ends
T.COUNTS = { 1, 2, 3, 5, 10 }

-- texts: strrefs written by SadoQoL.tp2
local STR = {
	title = tonumber("SQ_NECR_TITLE"), monsters = tonumber("SQ_NECR_MONSTERS"), humans = tonumber("SQ_NECR_HUMANS"),
	search = tonumber("SQ_NECR_SEARCH"), raise = tonumber("SQ_NECR_RAISE"), close = tonumber("SQ_NECR_CLOSE"),
	level = tonumber("SQ_NECR_LEVEL"), hp = tonumber("SQ_NECR_HP"), ac = tonumber("SQ_NECR_AC"),
	dmg = tonumber("SQ_NECR_DMG"), total = tonumber("SQ_NECR_TOTAL"), reset = tonumber("SQ_NECR_RESET"),
	found = tonumber("SQ_NECR_FOUND"),
}
function SQNecro_T(k)
	local r = STR[k]
	return r and Infinity_FetchString(r) or k
end

local TYPE_SPRITE = 49
local HUMAN_RACES = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true }
local CAMP_PEOPLE = { SQPRIEST = true, SQMERCH = true, SQCAIN = true, SQWITHER = true, SQNECRO = true }
-- what the undying shrug off: instant death, petrification, disintegration, level drain, imprisonment, maze
local DEATH_OPS = { 13, 55, 134, 209, 216, 238, 211, 213 }
-- what the camp people shrug off (John: "immune à tout"): damage, death, and every disabling effect
local CAMP_IMMUNE_OPS = { 12, 13, 55, 134, 209, 216, 238, 211, 213, 3, 5, 24, 25, 38, 39, 40, 45, 74, 76, 78, 80,
	109, 128, 157, 175, 185, 210, 217, 241 }

local function areaSprites(area, f)
	for _, l in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[l], function(id)
			local o = EEex_GameObject_Get(id)
			if o and o.m_objectType == TYPE_SPRITE then return f(EEex_GameObject_CastUserType(o)) end
		end)
	end
end

local function inCamp()
	local a = EEex_Area_GetVisible()
	return a and string.upper(a.m_resref:get()) == 'SQCAMP' and a or nil
end

local function resrefOf(sp)   -- the engine marks the first letter of a sprite's resref with '*'
	return string.upper(sp.m_resref:get():sub(2))
end

local function act(sp, s) EEex_Action_ExecuteResponseStringOnAIBaseInstantly(s, sp) end
local function effect(sp, t)
	t.sourceID, t.sourceTarget = sp.m_id, sp.m_id
	EEex_GameObject_ApplyEffect(sp, t)
end

local function dummies()
	local out, area = {}, inCamp()
	if not area then return out end
	areaSprites(area, function(sp)
		local s = EEex_Sprite_GetLocalInt(sp, 'SQDUMMY')
		if s > 0 and EEex_BAnd(sp.m_derivedStats.m_generalState, 0x800) == 0 then out[#out + 1] = { sp = sp, state = s } end
	end)
	return out
end

-----------------
-- The bestiary --
-----------------
-- SQNecro_Bestiary (M_SQBEST.lua): { resref, name strref, level, max HP, AC, race }
local function bestiary()
	if T.best then return T.best end
	local seen, list = {}, {}
	for _, e in ipairs(SQNecro_Bestiary or {}) do
		local name = Infinity_FetchString(e[2]) or ''
		name = name:gsub('^%s+', ''):gsub('%s+$', '')
		if name ~= '' and not name:find('^<') and not name:find('^%*') then
			list[#list + 1] = { res = e[1], kill = 'SQK' .. string.upper(e[1]):sub(2), name = name, level = e[3], hp = e[4],
				ac = e[5], human = HUMAN_RACES[e[6]] == true, key = name:lower(),
				sig = name .. '|' .. e[3] .. '|' .. e[4] .. '|' .. e[5] }
		end
	end
	table.sort(list, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.key < b.key end)
	T.best = list
	return list
end

-- the creatures this save has seen die (globals SQK...), read when the menu opens
local function killed()
	local out, sigs = {}, {}
	for _, r in ipairs(bestiary()) do
		if not sigs[r.sig] and EEex_GameState_GetGlobalInt(r.kill) == 1 then
			sigs[r.sig] = true
			out[#out + 1] = r
		end
	end
	return out
end

necroRows = necroRows or {}
necroRow = necroRow or 0
necroFind = necroFind or ''
T.tab = T.tab or 'monsters'

local function rebuild()
	local q = (necroFind or ''):lower()
	local key = T.tab .. '|' .. q
	if T.builtKey == key then return end
	T.builtKey = key
	local rows = {}
	T.unlocked = T.unlocked or killed()
	for _, r in ipairs(T.unlocked) do
		if (r.human == (T.tab == 'humans')) and (q == '' or r.key:find(q, 1, true)) then rows[#rows + 1] = r end
	end
	necroRows = rows
	if necroRow > #rows then necroRow = 0 end
end

function SQNecro_OpenMenu()
	T.builtKey, T.unlocked, necroRow = nil, nil, 0
	if not Infinity_IsMenuOnStack('SQNECR_MENU') then Infinity_PushMenu('SQNECR_MENU') end
end
function SQNecro_OnOpen() rebuild() end
function SQNecro_Tab(t) T.tab = t T.builtKey = nil necroRow = 0 rebuild() end
function SQNecro_TabFrame(t) return T.tab == t and 1 or 0 end
function SQNecro_SearchEdit() T.builtKey = nil rebuild() return 1 end
function SQNecro_RowName(i) rebuild() local r = necroRows[i] return r and r.name or '' end
function SQNecro_RowNum(i, k) local r = necroRows[i] return r and tostring(r[k]) or '' end
function SQNecro_RowSelected(i) return necroRow == i end
function SQNecro_HasSel() return necroRows[necroRow] ~= nil end
function SQNecro_CountText() rebuild() return string.format(SQNecro_T('found'), #necroRows) end
function SQNecro_SelText()
	local r = necroRows[necroRow]
	if not r then return '' end
	return r.name .. '\n' .. SQNecro_T('level') .. ' ' .. r.level .. '   ' .. SQNecro_T('hp') .. ' ' .. r.hp .. '   '
		.. SQNecro_T('ac') .. ' ' .. r.ac
end
function SQNecro_Close()
	if Infinity_IsMenuOnStack('SQNECR_MENU') then Infinity_PopMenu('SQNECR_MENU') end
end

local function necro()
	local area, found = inCamp(), nil
	if not area then return nil end
	areaSprites(area, function(sp) if string.upper(sp.m_scriptName:get()) == T.RES then found = sp return true end end)
	return found
end

-- Raise: the menu closes, and the necromancer asks how many (his dialogue's first state, gated by SQNecro_Picking)
function SQNecro_Pick()
	local r = necroRows[necroRow]
	if not r then return end
	T.pick = r
	Infinity_SetToken('SQNECRN', r.name)
	SQNecro_Close()
	local n = necro()
	local talker = EEex_Sprite_GetInPortrait(0)
	if n and talker then
		-- the necromancer speaks to the party leader again: his queue holds nothing else, the target is written in
		EEex_LuaObject = talker
		EEex_Action_QueueResponseStringOnAIBase('StartDialogNoSet(EEex_LuaObject)', n)
		EEex_Utility_IterateCPtrList(n.m_queuedActions, function(a) a.m_acteeID.m_Instance = talker.m_id end)
	end
end
function SQNecro_Picking() return T.pick ~= nil end

-------------------
-- Raised creatures --
-------------------
local function ownScripts(sp) return EEex_Sprite_GetLocalInt(sp, 'SQDUMMYS') == 1 end

local function stripLoot(sp, flag)
	sp.m_baseStats.m_xpValue = 0
	pcall(function() sp.m_baseStats.m_gold = 0 end)
	for slot = 0, 38 do
		local it = sp.m_equipment.m_items:get(slot)
		if it then it.m_flags = flag and EEex_BOr(it.m_flags, 0x8) or EEex_BAnd(it.m_flags, EEex_BNot(0x8)) end
	end
end

-- heal and purge: magic dispelled (every dispellable effect), poison / disease / blindness... cured, full HP
local function healPurge(sp)
	effect(sp, { effectID = 58, durationType = 1, effectAmount = 100, dwFlags = 1 })     -- dispel, always
	for _, op in ipairs({ 11, 79, 77, 81, 75, 162, 240 }) do effect(sp, { effectID = op, durationType = 1 }) end
	effect(sp, { effectID = 17, durationType = 1, effectAmount = EEex_Sprite_GetStat(sp, 1) or 1, dwFlags = 1 })
end

local SCRIPT_LEVELS = { 'OVERRIDE', 'CLASS', 'RACE', 'GENERAL', 'DEFAULT', 'AREA', 'SPECIFICS' }
local function makeUndying(sp)
	-- always on a creature fresh from its CRE (just raised, or unleashed = made again): nothing of ours to remove.
	-- Our effects carry the parent resource SQDUMMY: opcode 321 takes them off without the creature's own.
	EEex_Sprite_SetLocalInt(sp, 'SQDUMMY', 1)
	local function mine(t) t.m_sourceRes = 'SQDUMMY' effect(sp, t) end
	mine({ effectID = 208, durationType = 9, effectAmount = 1 })
	-- +10000 max HP: a hit bigger than a small creature's HP is still counted in full (healed to full every tick)
	mine({ effectID = 18, durationType = 0, duration = 999999, effectAmount = T.BUFFER, dwFlags = 0 })   -- timed: a permanent one is baked in
	for _, op in ipairs(DEATH_OPS) do mine({ effectID = 101, durationType = 9, effectAmount = op }) end
	act(sp, 'ClearActions(Myself)')
	-- no scripts: the creature's own are kept in the CRE (ChangeAIScript only changes the live one); unleashing
	-- recreates it, so its scripts come back with it
	for _, l in ipairs(SCRIPT_LEVELS) do act(sp, 'ChangeAIScript("",' .. l .. ')') end
	act(sp, 'ChangeEnemyAlly(Myself,NEUTRAL)')   -- dummies are not hostile (John 2026-10-25): attack them on purpose
	stripLoot(sp, true)
	healPurge(sp)
end

local function screen(sp)
	if T.screened[sp.m_id] then return end
	T.screened[sp.m_id] = true
	effect(sp, { effectID = 403, durationType = 9, res = 'SQDMGSCR', m_sourceRes = 'SQDMG' })
	T.hp[sp.m_id] = sp.m_baseStats.m_hitPoints
end

local function grid(i, n)
	local cols = math.min(n, 5)
	local row, col = math.floor((i - 1) / cols), (i - 1) % cols
	return T.CENTER[1] + (col - (cols - 1) / 2) * T.GAP, T.CENTER[2] + row * T.GAP * 0.75
end

-- the creatures being created: { res, x, y, state (1 undying / 2 unleashed), at }
T.expect = T.expect or {}
T.screened = T.screened or {}
T.hp = T.hp or {}

local function create(res, x, y, state)
	local n = necro() or EEex_Sprite_GetInPortrait(0)
	if not n then return end
	T.expect[#T.expect + 1] = { res = string.upper(res), x = x, y = y, state = state, at = Infinity_GetClockTicks() }
	act(n, string.format('CreateCreature("%s",[%d.%d],%d)', res, x, y, 0))
end

function SQNecro_Spawn(count)
	local r = T.pick
	T.pick = nil
	if not r or not count or count <= 0 then return end
	for i = 1, count do
		local x, y = grid(i, count)
		create(r.res, x, y, 1)
	end
end
function SQNecro_Cancel() T.pick = nil end

-- the created creatures show up a moment later: matched to what was expected (same CRE, near the spot)
local function claim(area)
	if #T.expect == 0 then return end
	local now = Infinity_GetClockTicks()
	areaSprites(area, function(sp)
		if EEex_Sprite_GetLocalInt(sp, 'SQDUMMY') > 0 or EEex_Sprite_GetPortraitIndex(sp) >= 0 then return end
		if CAMP_PEOPLE[string.upper(sp.m_scriptName:get())] then return end
		local res = resrefOf(sp)
		for i, e in ipairs(T.expect) do
			if e.res:sub(2) == res and math.abs(sp.m_pos.x - e.x) < 400 and math.abs(sp.m_pos.y - e.y) < 400 then   -- 10 at once land far apart
				table.remove(T.expect, i)
				EEex_Sprite_SetLocalString(sp, 'SQDUMMYR', e.res)   -- the whole resref, for Unleash
				stripLoot(sp, true)
				if e.state == 1 then
					makeUndying(sp)
				else
					EEex_Sprite_SetLocalInt(sp, 'SQDUMMY', 2)
					act(sp, 'ChangeEnemyAlly(Myself,ENEMY)')
				end
				screen(sp)
				return
			end
		end
	end)
	for i = #T.expect, 1, -1 do if now - T.expect[i].at > 15000 then table.remove(T.expect, i) end end
end

-- the CRE a raised creature came from: its saved resref (claim), else the bestiary entry whose resref ends like the
-- sprite's (the engine keeps it with a '*' for the first letter: CreateCreature("IBBER") made nothing, 2026-10-25)
local function fullRes(sp)
	local r = EEex_Sprite_GetLocalString(sp, 'SQDUMMYR')
	if r and r ~= '' then return r end
	local tail = resrefOf(sp)
	for _, e in ipairs(SQNecro_Bestiary or {}) do
		if string.upper(e[1]):sub(2) == tail then return string.upper(e[1]) end
	end
	return nil
end

-- Unleash: each undying one is made again from its CRE (healed, purged, its own scripts back) and turns hostile
function SQNecro_Unleash()
	for _, d in ipairs(dummies()) do
		local res = d.state == 1 and fullRes(d.sp)
		if res then
			local sp = d.sp
			create(res, sp.m_pos.x, sp.m_pos.y, 2)
			act(sp, 'DestroySelf()')
		end
	end
end
function SQNecro_Calm()
	for _, d in ipairs(dummies()) do if d.state == 2 then makeUndying(d.sp) end end
end
-- things to do a moment later: an effect removed by opcode 337 still protects during the same update (a kill
-- right behind the removal of the minimum HP did nothing, 2026-10-24)
T.later = T.later or {}
local function later(ms, id, f) T.later[#T.later + 1] = { at = Infinity_GetClockTicks() + ms, id = id, f = f } end
local function runLater()
	local now = Infinity_GetClockTicks()
	for i = #T.later, 1, -1 do
		local l = T.later[i]
		if now >= l.at then
			table.remove(T.later, i)
			local o = EEex_GameObject_Get(l.id)
			if o and o.m_objectType == TYPE_SPRITE then pcall(l.f, EEex_GameObject_CastUserType(o)) end
		end
	end
end

local function unprotect(sp)
	effect(sp, { effectID = 321, durationType = 1, res = 'SQDUMMY' })
end

function SQNecro_CleanUp()
	for _, d in ipairs(dummies()) do
		local sp = d.sp
		EEex_Sprite_SetLocalInt(sp, 'SQDUMMY', 0)
		stripLoot(sp, true)
		unprotect(sp)
		later(300, sp.m_id, function(s) effect(s, { effectID = 13, durationType = 1, dwFlags = 4 }) end)   -- normal death
	end
end
-- Joining = a full respec, mandatory (docs/NECRO_RESPEC.md, John 2026-10-25): the game's creation panels from the
-- class step (race kept), the protagonist's XP; one creature after the other, once each (local SQRESPECED).
T.respecQueue = T.respecQueue or {}
local function nextRespec()
	if #T.respecQueue == 0 or not SQRespec_Begin or (SQRespec_Active and SQRespec_Active()) then return end
	local id = T.respecQueue[1]
	local o = EEex_GameObject_Get(id)
	if not o or o.m_objectType ~= TYPE_SPRITE then table.remove(T.respecQueue, 1) return end
	local sp = EEex_GameObject_CastUserType(o)
	if EEex_Sprite_GetPortraitIndex(sp) < 0 then return end          -- not in the party yet
	table.remove(T.respecQueue, 1)
	if EEex_Sprite_GetLocalInt(sp, 'SQRESPECED') == 1 then return end
	if SQRespec_Begin(sp, { necro = true, xp1 = true }) then
		EEex_Sprite_SetLocalInt(sp, 'SQRESPECED', 1)
	else
		T.lastError = 'respec could not begin for ' .. tostring(id)
	end
end

function SQNecro_Join()
	for _, d in ipairs(dummies()) do
		local sp = d.sp
		EEex_Sprite_SetLocalInt(sp, 'SQDUMMY', 0)
		unprotect(sp)
		effect(sp, { effectID = 321, durationType = 1, res = 'SQDMG' })
		T.screened[sp.m_id] = nil
		later(300, sp.m_id, function(s)
			effect(s, { effectID = 17, durationType = 1, effectAmount = EEex_Sprite_GetStat(s, 1) or 1, dwFlags = 1 })
		end)
		stripLoot(sp, false)
		if d.state == 1 then for _, l in ipairs(SCRIPT_LEVELS) do act(sp, 'ChangeAIScript("",' .. l .. ')') end end
		act(sp, 'ClearActions(Myself)')
		act(sp, 'JoinParty()')
		EEex_Sprite_SetLocalInt(sp, 'SQJOINED', 1)   -- gets a portrait from its animation when it has none
		-- no forced respec any more (John 2026-10-25): it joins as it is; Withers remakes it on request
		-- (SQRespec_Begin's necro path is still there for him)
	end
end
-- Level up: a creature without a player class (CLASS.IDS 1-21) never levels up (John 2026-10-24) - the engine
-- divides by zero in CRuleTables::GetProficiencySlots for those (crash on "Abela the Nymph" who had joined).
-- UI.MENU's Level Up button and the portraits' level-up icons go through these two (patched by SadoQoL.tp2).
local function levelLocked(sp)
	if not sp then return false end
	local cls = sp.m_typeAI.m_Class
	return cls < 1 or cls > 21
end
local function spriteOf(id)
	local o = id and EEex_GameObject_Get(id)
	if o and o.m_objectType == TYPE_SPRITE then return EEex_GameObject_CastUserType(o) end
end
function SQNecro_LevelUpClickable()
	local ok, locked = pcall(levelLocked, spriteOf(currentID) or EEex_Sprite_GetSelected())
	if ok and locked then return false end
	return characterScreen:IsLevelUpButtonClickable()
end
function SQNecro_CanLevelUp(i)
	local ok, locked = pcall(levelLocked, EEex_Sprite_GetInPortrait(i))
	if ok and locked then return false end
	return Infinity_CanLevelUp(i)
end

-- Race line of the record screen (characterDescString, UI.MENU): empty for a race the game has no text for (Ogre,
-- Gnoll, Dog...). John 2026-10-25: its race of the game, named after the creatures of that race - the name most of
-- them wear in the bestiary (the game's own, translated strings).
T.raceNames = T.raceNames or {}
local function raceName(r)
	if T.raceNames[r] ~= nil then return T.raceNames[r] end
	local count, best, bestN = {}, '', 0
	for _, e in ipairs(SQNecro_Bestiary or {}) do
		if e[6] == r then
			local n = (Infinity_FetchString(e[2]) or ''):gsub('^%s+', ''):gsub('%s+$', '')
			if n ~= '' and not n:find('^<') and not n:find('^%*') then
				count[n] = (count[n] or 0) + 1
				if count[n] > bestN or (count[n] == bestN and #n < #best) then best, bestN = n, count[n] end
			end
		end
	end
	T.raceNames[r] = best
	return best
end
local function wrapDesc()
	if type(characterDescString) ~= 'function' or characterDescString == T.descWrapped then return end
	local orig = characterDescString
	T.descWrapped = function(char)
		local text = orig(char)
		local ok, out = pcall(function()
			if char and char.race and Infinity_FetchString(char.race) ~= '' then return text end
			local sp = spriteOf(currentID)
			if not sp then return text end
			local name = raceName(sp.m_typeAI.m_Race)
			if name == '' then return text end
			local lines = {}
			for l in (text .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = l end
			if lines[2] == '' then lines[2] = name end
			return table.concat(lines, '\n')
		end)
		return ok and out or text
	end
	characterDescString = T.descWrapped
end
if not T.descListener then
	T.descListener = true
	EEex_Menu_AddMainFileLoadedListener(function() pcall(wrapDesc) end)
end
pcall(wrapDesc)

-- Customize > Appearance (the portrait): the engine greys it out for creatures; the necromancer's may change it
-- (John 2026-10-25). UI.MENU's button goes through this (patched by SadoQoL.tp2).
function SQNecro_AppearanceClickable()
	local sp = spriteOf(currentID) or EEex_Sprite_GetSelected()
	if sp and (EEex_Sprite_GetLocalInt(sp, 'SQJOINED') == 1 or levelLocked(sp)) then return true end
	return characterScreen:IsAppearanceButtonClickable()
end

-- Dolls and portraits for joined creatures that have none (John 2026-10-24), made from their animation by
-- tools/make_necro_art.py: SQNecro_Art (M_SQNART.lua) [animation id] = { doll SQD<id>.BAM made, portrait SQP<id>.BMP }
local function artOf(sp)
	local ok, id = pcall(function() return sp.m_animation.m_animation.m_animationID end)
	if not ok or not id or not SQNecro_Art then return nil end
	return SQNecro_Art[id], id
end
-- inventory (UI.MENU, patched by SadoQoL.tp2): the standing frame where the engine draws no paper doll
function SQNecro_DollBam()
	local sp = spriteOf(id) or spriteOf(currentID)   -- the inventory shows characters[id]
	local a, id = nil, nil
	if sp then a, id = artOf(sp) end
	return a and a[1] == 1 and string.format('SQD%04X', id) or nil
end
function SQNecro_HasDoll() return SQNecro_DollBam() ~= nil end

-- portrait: only for the necromancer's creatures and other non-player classes (a player's own portrait, maybe from
-- the portraits folder, is never touched)
local function noPortrait(sp)
	local r = string.upper(sp.m_baseStats.m_portraitSmall:get() or '')
	return r == '' or r == 'NONE' or EEex_Resource_Fetch(r, 'BMP') == nil
end
-- given once (local SQPORTRAIT): a portrait the player picks afterwards (Customize) stays (John 2026-10-25)
local function givePortrait(sp)
	if EEex_Sprite_GetLocalInt(sp, 'SQPORTRAIT') == 1 then return end
	if EEex_Sprite_GetLocalInt(sp, 'SQJOINED') ~= 1 and not levelLocked(sp) then return end
	if not noPortrait(sp) then return end
	EEex_Sprite_SetLocalInt(sp, 'SQPORTRAIT', 1)
	local a, id = artOf(sp)
	if not a or a[2] ~= 1 then return end
	local res = string.format('SQP%04X', id)
	effect(sp, { effectID = 107, durationType = 1, res = res, dwFlags = 0 })   -- small
	effect(sp, { effectID = 107, durationType = 1, res = res, dwFlags = 1 })   -- large
end
local function partyPortraits()
	for i = 0, 23 do   -- bigger parties too (Extension EEex)
		local sp = EEex_Sprite_GetInPortrait(i)
		if not sp then break end
		pcall(givePortrait, sp)
	end
end

-- dialogue triggers (no "==" or spaces inside EEex_LuaTrigger)
local function count(state) local n = 0 for _, d in ipairs(dummies()) do if not state or d.state == state then n = n + 1 end end return n end
function SQNecro_AnyUndying() return count(1) > 0 end
function SQNecro_AnyUnleashed() return count(2) > 0 end
function SQNecro_Any() return count() > 0 end

------------------
-- Damage meter --
------------------
T.meter = T.meter or { by = {}, names = {}, total = 0 }
T.sources = T.sources or {}

-- opcode 403 screen on every raised creature: notes who sends each damage effect
function SQDMGSCR(op403, e, sp)
	if e.m_effectId == 12 then
		local src = e.m_sourceId
		if src and src ~= -1 and src ~= sp.m_id then
			local l = T.sources[sp.m_id] or {}
			l[#l + 1] = src
			T.sources[sp.m_id] = l
		end
	end
	return false
end

local function nameOf(id)
	local o = EEex_GameObject_Get(id)
	if o and o.m_objectType == TYPE_SPRITE then return EEex_Sprite_GetName(EEex_GameObject_CastUserType(o)) end
	return '?'
end

local function record(dummy, lost)
	local m, now = T.meter, Infinity_GetClockTicks()
	if not m.start or now - (m.last or 0) > T.SESSION_IDLE then
		T.meter = { by = {}, names = {}, total = 0, start = now }
		m = T.meter
	end
	m.last = now
	m.total = m.total + lost
	local srcs = T.sources[dummy.m_id] or {}
	T.sources[dummy.m_id] = nil
	if #srcs == 0 then srcs = { -1 } end
	local share = lost / #srcs
	for _, id in ipairs(srcs) do
		m.by[id] = (m.by[id] or 0) + share
		if not m.names[id] then m.names[id] = id == -1 and '?' or nameOf(id) end
	end
end

local function meterTick()
	for _, d in ipairs(dummies()) do
		local sp = d.sp
		screen(sp)
		local hp = sp.m_baseStats.m_hitPoints
		local before = T.hp[sp.m_id] or hp
		if hp < before then record(sp, before - hp) end
		if d.state == 1 then
			if sp.m_typeAI.m_EnemyAlly ~= 128 then act(sp, 'ChangeEnemyAlly(Myself,NEUTRAL)') end
			local max = EEex_Sprite_GetStat(sp, 1) or hp
			if hp < max then
				effect(sp, { effectID = 17, durationType = 1, effectAmount = max, dwFlags = 1 })
				hp = max
			end
		end
		T.hp[sp.m_id] = hp
	end
end

local function seconds()
	local m = T.meter
	if not m.start then return 0 end
	return math.max(1, ((m.last or m.start) - m.start) / 1000)
end
function SQNecro_DpsShown() return inCamp() ~= nil and (count() > 0 or (T.meter.total or 0) > 0) end
function SQNecro_DpsTitle()
	local m = T.meter
	local live = m.start and Infinity_GetClockTicks() - (m.last or 0) <= T.SESSION_IDLE
	return string.format('%s  %.1f s%s', SQNecro_T('dmg'), seconds(), live and '  *' or '')
end
function SQNecro_DpsText()
	local m, s = T.meter, seconds()
	local rows = {}
	for id, v in pairs(m.by) do rows[#rows + 1] = { m.names[id] or '?', v } end
	table.sort(rows, function(a, b) return a[2] > b[2] end)
	local out = {}
	for _, r in ipairs(rows) do out[#out + 1] = string.format('%s: %d  (%.1f/s)', r[1], math.floor(r[2] + 0.5), r[2] / s) end
	out[#out + 1] = string.format('%s: %d  (%.1f/s)', SQNecro_T('total'), math.floor((m.total or 0) + 0.5), (m.total or 0) / s)
	return table.concat(out, '\n')
end
function SQNecro_DpsReset() T.meter = { by = {}, names = {}, total = 0 } end

------------------
-- Deaths seen --
------------------
-- a hostile creature seen alive in the party's area, then dead there: unlocked in the bestiary (that CRE, this save).
-- No death event in EEex: the area is scanned every tick (100 ms); a body blown to pieces leaves the area at once, so a
-- hostile one that vanishes with its last HP at 0 or less counts too. The engine keeps a sprite's resref with its first
-- letter replaced by '*': the key drops that letter.
T.alive = T.alive or {}
local function unlock(key) if EEex_GameState_GetGlobalInt(key) ~= 1 then EEex_GameState_SetGlobalInt(key, 1) end end
local function watchDeaths()
	local area = EEex_Area_GetVisible()
	if not area then T.alive = {} return end
	local now = {}
	areaSprites(area, function(sp)
		local id = sp.m_id
		if EEex_Sprite_GetPortraitIndex(sp) >= 0 or EEex_Sprite_GetLocalInt(sp, 'SQDUMMY') > 0 then return end
		local was = T.alive[id]
		if EEex_BAnd(sp.m_derivedStats.m_generalState, 0x800) == 0 then
			if sp.m_typeAI.m_EnemyAlly >= 200 then
				now[id] = { key = 'SQK' .. resrefOf(sp), hp = sp.m_baseStats.m_hitPoints }
			end
		elseif was then
			unlock(was.key)
		end
	end)
	for id, was in pairs(T.alive) do
		if not now[id] and was.hp <= 0 and not EEex_GameObject_Get(id) then unlock(was.key) end
	end
	T.alive = now
end

------------------------------
-- Camp people: untouchable --
------------------------------
local function protectCampPeople(area)
	areaSprites(area, function(sp)
		if CAMP_PEOPLE[string.upper(sp.m_scriptName:get())] and EEex_Sprite_GetLocalInt(sp, 'SQIMMUNE') ~= 1 then
			EEex_Sprite_SetLocalInt(sp, 'SQIMMUNE', 1)
			effect(sp, { effectID = 208, durationType = 9, effectAmount = 1 })
			for _, op in ipairs(CAMP_IMMUNE_OPS) do effect(sp, { effectID = 101, durationType = 9, effectAmount = op }) end
			act(sp, 'ChangeEnemyAlly(Myself,NEUTRAL)')
		end
	end)
end

-----------
-- Ticks --
-----------
-- the necromancer himself (old saves too) and the camp people's protection: the camp's shared hook (500 ms)
SQCamp_Hooks = SQCamp_Hooks or {}
SQCamp_Hooks.necro = function()
	local area = inCamp()
	if not area then return end
	if #T.later > 0 then runLater() end
	pcall(protectCampPeople, area)
	pcall(claim, area)
end

-- the meter: every 100 ms, from the panel's tick (SQNECR_TICK)
function SQNecro_Tick()
	local now = Infinity_GetClockTicks()
	if T.nextTick and now < T.nextTick then return false end
	T.nextTick = now + 100
	if #T.later > 0 then runLater() end
	if #T.respecQueue > 0 then
		local ok, err = pcall(nextRespec)
		if not ok then T.lastError = tostring(err) end
	end
	do
		local ok, err = pcall(watchDeaths)
		if not ok then T.lastError = tostring(err) end
	end
	if not T.nextPortraits or now >= T.nextPortraits then
		T.nextPortraits = now + 2000
		partyPortraits()
	end
	if inCamp() then
		local ok, err = pcall(meterTick)
		if not ok then T.lastError = tostring(err) end
	end
	return false
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQNECR_TICK') then Infinity_PushMenu('SQNECR_TICK') end
	if not Infinity_IsMenuOnStack('SQNECR_DPS') then Infinity_PushMenu('SQNECR_DPS') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQNECR') end)
	EEex_Menu_AddAfterMainFileReloadedListener(function() EEex_Menu_LoadFile('SQNECR') pushTick() end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
end

-- the necromancer joins the camp's residents (created at his spot when missing)
if SQCamp and SQCamp.RESIDENTS then
	local known = false
	for _, r in ipairs(SQCamp.RESIDENTS) do if r[1] == T.RES then known = true end end
	if not known then table.insert(SQCamp.RESIDENTS, { T.RES, T.SPOT[1], T.SPOT[2], T.SPOT[3] }) end
	if SQCamp.LOOKS then SQCamp.LOOKS[T.RES] = 0x6200 end
end
