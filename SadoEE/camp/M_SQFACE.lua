--[[
SadoQoL - Faceless / Sans-Visage (John 2026-11-02, SadoEE 1.03): Withers' replacement at the rest camp. Same jobs
(respec #17, recruit #19), same script name (SQWITHER), so old saves and every camp table keep working.
A doppelganger who fled the Iron Throne: at EACH camp visit he wears another face, picked from the game's own people:
townsfolk (nobles, guards, merchants, peasants, men and women) most of the time; now and then his true doppelganger
voice slips through under a borrowed face; rarely a famous face (Gorion, Elminster).
How: SadoQoL.tp2 (#17) makes one creature per face at install time, a copy of SQWITHER.CRE wearing the donor's look
and voice: SQFACEnn (the donor's own voice) and SQFADOnn (his doppelganger voice). The engine keeps a creature's
voice from its file (writing the sound set at run time changed nothing), so at each visit the camp's Faceless is
swapped for the chosen creature, on the same spot. Design: SadoQoL/docs/CAMP_V2.md.
--]]

SQFace = SQFace or {}
local T = SQFace

T.SCRIPT = 'SQWITHER'
-- SAME ORDER as SadoQoL.tp2's list (nn = position): { donor, weight, famous }
T.FACES = {
	{ 'NOBL11', 3 }, { 'NOBLEM3', 2 }, { 'NOBLAY', 2 }, { 'MERCHANT', 2 }, { 'FLAM', 2 }, { 'GUARD', 2 },
	{ 'TOWNCR_', 1 }, { 'SERVANT', 1 }, { 'FARM', 1 }, { 'BEGGAR1', 1 },
	{ 'NOBW8', 3 }, { 'NOBLEW3', 2 }, { 'NOBWSN_A', 2 }, { 'SERVWG', 2 }, { 'AMMERC04', 1 }, { 'BEGGAR3', 1 },
	{ 'GORION', 1, true }, { 'ELMIN2', 1, true },
}
T.FAMOUS_CHANCE = 10     -- % of visits
T.SLIP_CHANCE = 20       -- % of visits: a townsfolk face with his own doppelganger voice

local function exists(res)
	local ok, d = pcall(EEex_Resource_Demand, res, 'CRE')
	return ok and d ~= nil
end

local function resref(kind, n) return string.format('%s%02d', kind, n) end

-- the creature to wear this visit
local function choose()
	local famous = math.random(100) <= T.FAMOUS_CHANCE
	local total, have = 0, {}
	for n, f in ipairs(T.FACES) do
		if (f[3] == true) == famous and exists(resref('SQFACE', n)) then
			have[#have + 1] = { n = n, w = f[2] }
			total = total + f[2]
		end
	end
	if total == 0 then return nil end
	local r, n = math.random(total), nil
	for _, h in ipairs(have) do
		r = r - h.w
		if r <= 0 then n = h.n break end
	end
	local slip = not famous and math.random(100) <= T.SLIP_CHANCE and exists(resref('SQFADO', n))
	return resref(slip and 'SQFADO' or 'SQFACE', n)
end

-- the camp's spot for him (M_SQRESP.lua puts him in SQCamp.RESIDENTS)
local function spot(sp)
	for _, r in ipairs(SQCamp and SQCamp.RESIDENTS or {}) do
		if r[1] == T.SCRIPT then return r[2], r[3], r[4] end
	end
	return sp.m_pos.x, sp.m_pos.y, 12
end

-- swaps the camp's Faceless (any creature named SQWITHER: Withers in an old save, or a face of an earlier visit)
function SQFace_Disguise(sp)
	local res = choose()
	if not res or not sp then return false end
	local x, y, face = spot(sp)
	T.face = res
	if string.upper(sp.m_resref:get()) == res then return true end
	-- the camp keeps one of each of its people, the one nearest his spot: the old Faceless (still listed while he goes)
	-- would win and the new one be removed, then both gone (compat test 2026-11-02). Not while we swap him.
	if SQCamp and SQCamp.ONE then SQCamp.ONE[T.SCRIPT] = nil T.oneHeld = Infinity_GetClockTicks() end
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroySelf()', sp)
	if SQCamp_Create then
		SQCamp_Create(res, x, y, face)
	else
		EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('CreateCreature("%s",[%d.%d],%d)', res, x, y,
			face), EEex_Sprite_GetInPortrait(0))
	end
	return true
end

-- ---- each camp visit ----
local function campArea() return SQCamp and SQCamp.AREA or 'SQCAMP' end

local function findFaceless(area)
	local found
	for _, list in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[list], function(id)
			if found then return end
			local o = EEex_GameObject_Get(id)
			if o and o.m_objectType == 49 then
				local sp = EEex_GameObject_CastUserType(o)
				if string.upper(sp.m_scriptName:get()) == T.SCRIPT then found = sp end
			end
		end)
	end
	return found
end

local function tick()
	local area = EEex_Area_GetVisible()
	if not area then return end
	if string.upper(area.m_resref:get()) ~= campArea() then T.visited = nil return end
	if T.visited then return end
	local sp = findFaceless(area)
	if not sp then return end        -- not spawned yet (the camp creates its people a few seconds in)
	T.visited = true
	local ok, err = pcall(SQFace_Disguise, sp)
	if not ok then T.lastError = tostring(err) end
end

function SQFace_Tick()
	local now = Infinity_GetClockTicks()
	if T.oneHeld and now - T.oneHeld > 5000 and SQCamp and SQCamp.ONE then
		SQCamp.ONE[T.SCRIPT] = true       -- the old one is gone: the camp's one-of-each rule again
		T.oneHeld = nil
	end
	if T.next and now < T.next then return false end
	T.next = now + 1000
	local ok, err = pcall(tick)
	if not ok then T.lastError = tostring(err) end
	return false
end

-- a game loaded inside the camp is a new visit too
if not T.listenersAdded then
	T.listenersAdded = true
	EEex_GameState_AddInitializedListener(function() T.visited = nil end)
end
-- ticks with the camp's own tick (SQCamp_Hooks[name], run every 500 ms by M_SQCAIN.lua's wrapper)
SQCamp_Hooks = SQCamp_Hooks or {}
SQCamp_Hooks.faceless = SQFace_Tick
