--[[
SadoQoL component #26 - Allies clear the fog of war (John 2026-11-04, after Endarire's question on Discord).

Summoned creatures, familiars, charmed creatures and quest allies (allegiance FAMILIAR .. GOODCUTOFF, not in the
party) reveal the fog of war around them, like party members: a scout summon or a familiar sent ahead shows the way.
Each one gets opcode 268 (clear fog of war), tagged with the parent resource SQFOG and the local SQFOG = 1. It is taken
off (opcode 321 SQFOG) when the creature turns hostile or neutral, joins the party, or the switch is turned off.

Every PERIOD ms, the visible area only (the fog that matters is the one shown). Nothing is patched in the CRE files:
creatures of every mod are covered, whatever the install order.
Albie's "Summons and charmed creatures clear fog of war" (wl_SummonsFoW, its WLSFMC01.SPL) does the same from the
creatures' scripts: when it is installed this feature stands aside.
Tuning live from the EEex console, e.g.  SQFog.PERIOD = 500   SQFog.ENABLED = false
--]]

SQFog = SQFog or {}
local T = SQFog

T.ENABLED = T.ENABLED ~= false
T.PERIOD  = T.PERIOD or 1000   -- ms between two scans of the visible area

local EA_FAMILIAR, EA_GOODCUTOFF = 3, 30
local DEAD = 0x800
local TAG = 'SQFOG'

-- Albie's mod is installed: its creature scripts already do it
local function albie()
	if T.albie == nil then
		local ok, res = pcall(EEex_Resource_Fetch, 'WLSFMC01', 'SPL')
		T.albie = ok and res ~= nil
	end
	return T.albie
end

local function wanted(sp, party)
	local ea = sp.m_typeAI.m_EnemyAlly
	return T.ENABLED and ea >= EA_FAMILIAR and ea <= EA_GOODCUTOFF and not party[sp.m_id]
		and EEex_BAnd(sp.m_baseStats.m_generalState, DEAD) == 0
end

local function give(sp)
	EEex_GameObject_ApplyEffect(sp, { effectID = 268, durationType = 9, m_sourceRes = TAG,
		sourceID = sp.m_id, sourceTarget = sp.m_id })
	EEex_Sprite_SetLocalInt(sp, TAG, 1)
end

local function take(sp)
	EEex_GameObject_ApplyEffect(sp, { effectID = 321, res = TAG, durationType = 1,
		sourceID = sp.m_id, sourceTarget = sp.m_id })
	EEex_Sprite_SetLocalInt(sp, TAG, 0)
end

local function scan(area)
	local party = {}
	local last = PSXP7_LastPortrait and PSXP7_LastPortrait() or 5
	for i = 0, last do
		local m = EEex_Sprite_GetInPortrait(i)
		if m then party[m.m_id] = true end
	end
	for _, list in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[list], function(id)
			local o = EEex_GameObject_Get(id)
			if o and o.m_objectType == 49 then
				local sp = EEex_GameObject_CastUserType(o)
				local has = EEex_Sprite_GetLocalInt(sp, TAG) == 1
				local want = wanted(sp, party)
				if want and not has then give(sp) elseif has and not want then take(sp) end
			end
		end)
	end
end

function SQFog_Tick()
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + T.PERIOD
	if albie() then return false end
	local area = EEex_Area_GetVisible()
	if area and EEex_Sprite_GetInPortrait(0) then
		local ok, err = pcall(scan, area)   -- switched off: the next scan takes the effect off again
		if not ok then T.lastError = tostring(err) end
	end
	return false
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQFOG_TICK') then Infinity_PushMenu('SQFOG_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQFOG') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
