--[[
SadoQoL component #10 - the camp priestess (John 2026-10-24): no store any more, two services in her dialogue.

1. Donation: the gold the game's temples ask for the next reputation point (REPUTATI.2DA: BASE_CHURCH at the
   current reputation buys MONEY_CHURCH / 10 points; 0 = donations no longer raise it, from 18 up).
2. Healing the whole party at the temple prices (SadoQoL camp store, tools/build_camp.py), total shown first:
   dead (not petrified / frozen / chunked) -> Resurrection 1000; missing HP -> Cure Medium Wounds, 14 HP for 50 gp,
   at most a Heal (750); level drain -> Restoration 750; cursed equipment -> Remove Curse 500; poison ->
   Neutralize Poison 300; disease -> Cure Disease 200. The cures are the spells' own effects (SPPR712A, SPPR607,
   SPPR417, SPPR307, SPPR404, SPPR317) applied on each member who needs them.

Dialogue SQPRIEST.dlg: SQPriest_Prime() (state trigger) sets the tokens, the replies ask SQPriest_RepOk / RepPoor /
HealOk / HealPoor, the actions run SQPriest_Donate() / SQPriest_Heal().

John 2026-10-25:
 - HP, poison and disease are free: her reply "tend our wounds" (SQPriest_FreeAny / SQPriest_FreeHeal) and every
   rest in the camp (a jump of 2+ game hours seen by the camp tick) heal them on every living member (Heal's own
   effects, SPPR607), with a line in the message log. The paid list keeps resurrection, lost levels and curses.
 - Install-time price option (SadoQoL #21-#24): SQPriest_PCT = 75 / 50 / 25 / 0 (M_SQPRPC.lua), healing only;
   the donation keeps the game's rule.
--]]

SQPriest = SQPriest or {}
local T = SQPriest

-- labels of the healing list, strrefs written by SadoQoL.tp2
T.LABEL = {
	raise  = tonumber("SQ_PR_RAISE"),
	wounds = tonumber("SQ_PR_WOUNDS"),
	drain  = tonumber("SQ_PR_DRAIN"),
	curse  = tonumber("SQ_PR_CURSE"),
	poison = tonumber("SQ_PR_POISON"),
	disease = tonumber("SQ_PR_DISEASE"),
}
T.ORDER = { 'raise', 'drain', 'curse' }              -- paid; wounds / poison / disease are free (John 2026-10-25)
T.FREE  = { 'wounds', 'poison', 'disease' }
T.PRICE = { raise = 1000, drain = 750, curse = 500, poison = 300, disease = 200 }

local STATE_DEAD, STATE_GONE = 0x800, 0x20 + 0x40 + 0x80   -- exploding / frozen / stone deaths: not raised here
local STATE_POISONED = 0x4000
local ITEM_CURSED = 0x10
local EQUIPPED = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 35, 36, 37, 38 }

local function partyMembers()
	local out = {}
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(p)
		if s then out[#out + 1] = s end
	end
	return out
end

local goldScripts = {}
local function partyGoldAtLeast(n)
	if n <= 0 then return true end
	goldScripts[n] = goldScripts[n] or EEex_Trigger_ParseConditionalString('PartyGoldGT(' .. (n - 1) .. ')')
	return EEex_Trigger_EvalScriptFileConditionalAsAIBase(goldScripts[n], EEex_Sprite_GetInPortrait(0))
end

local function hasEffect(sp, ids)
	local found = false
	for _, list in ipairs({ sp.m_timedEffectList, sp.m_equipedEffectList }) do
		EEex_Utility_IterateCPtrList(list, function(e) if ids[e.m_effectId] then found = true return true end end)
		if found then return true end
	end
	return false
end

local function cursed(sp)
	for _, slot in ipairs(EQUIPPED) do
		local it = sp.m_equipment.m_items:get(slot)
		local h = it and EEex_Resource_Demand(it.pRes.resref:get(), 'ITM')
		if h and EEex_BAnd(h.itemFlags, ITEM_CURSED) ~= 0 then return true end
	end
	return false
end

-- what each member needs: { { sp = sprite, raise = true, wounds = hp, ... } }, and the cost per service
local function needs()
	local out, count, cost = {}, {}, {}
	for _, k in ipairs(T.ORDER) do count[k], cost[k] = 0, 0 end
	for _, sp in ipairs(partyMembers()) do
		local state = sp.m_derivedStats.m_generalState
		local n = { sp = sp }
		if EEex_BAnd(state, STATE_DEAD) ~= 0 then
			if EEex_BAnd(state, STATE_GONE) == 0 then n.raise = true end   -- Resurrection also restores the HP
		else
			local missing = (EEex_Sprite_GetStat(sp, 1) or 0) - sp.m_baseStats.m_hitPoints
			if missing > 0 then n.wounds = true end
			if EEex_BAnd(state, STATE_POISONED) ~= 0 or hasEffect(sp, { [25] = true }) then n.poison = true end
			if hasEffect(sp, { [78] = true }) then n.disease = true end
		end
		if hasEffect(sp, { [216] = true }) then n.drain = true end
		if cursed(sp) then n.curse = true end
		for _, k in ipairs(T.FREE) do if n[k] then n.free = true end end
		local any = false
		for _, k in ipairs(T.ORDER) do
			if n[k] then
				any = true
				count[k] = count[k] + 1
				cost[k] = cost[k] + math.floor(T.PRICE[k] * (SQPriest_PCT or 100) / 100)
			end
		end
		if any or n.free then out[#out + 1] = n end
		n.paid = any
	end
	return out, count, cost
end

local function healTotal()
	local list, count, cost = needs()
	local total, parts = 0, {}
	for _, k in ipairs(T.ORDER) do
		if count[k] > 0 then
			total = total + cost[k]
			local label = T.LABEL[k] and Infinity_FetchString(T.LABEL[k]) or k
			parts[#parts + 1] = label .. (count[k] > 1 and (' x' .. count[k]) or '') .. ' (' .. cost[k] .. ')'
		end
	end
	return total, table.concat(parts, ', '), list
end

-- donation: cost of the next reputation point, 0 when donations no longer raise it
local function repCost()
	local rep = math.floor((EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_nReputation or 100) / 10)
	local a = EEex_Resource_Load2DA('REPUTATI')
	local row = tostring(math.max(1, math.min(20, rep)))
	local cost = tonumber(EEex_Resource_GetAt2DALabels(a, 'BASE_CHURCH', row) or '') or 0
	local gain = math.floor((tonumber(EEex_Resource_GetAt2DALabels(a, 'MONEY_CHURCH', row) or '') or 0) / 10)
	EEex_Resource_Free2DA(a)
	if gain <= 0 then cost = 0 end
	return cost, rep, gain
end

function SQPriest_State()
	local rc, rep, gain = repCost()
	local hc, hl = healTotal()
	Infinity_SetToken('SQPRRC', tostring(rc))
	Infinity_SetToken('SQPRREP', tostring(rep))
	Infinity_SetToken('SQPRNEXT', tostring(math.min(20, rep + math.max(gain, 1))))
	Infinity_SetToken('SQPRHC', tostring(hc))
	Infinity_SetToken('SQPRHL', hl)
	return rc, hc
end

-- dialogue triggers (SQPRIEST.d): no "==" inside EEex_LuaTrigger, WeiDU's compiler splits the line there
function SQPriest_Prime() pcall(SQPriest_State) return true end
function SQPriest_RepOk() local rc = SQPriest_State() return rc > 0 and partyGoldAtLeast(rc) end
function SQPriest_RepPoor() local rc = SQPriest_State() return rc > 0 and not partyGoldAtLeast(rc) end
-- the paid list can come to 0 gp (price option 0 %): still offered when someone needs it
local function paidAny() local list = needs() for _, n in ipairs(list) do if n.paid then return true end end return false end
function SQPriest_HealOk() local _, hc = SQPriest_State() return paidAny() and partyGoldAtLeast(hc) end
function SQPriest_HealPoor() local _, hc = SQPriest_State() return paidAny() and not partyGoldAtLeast(hc) end

local function pay(cost)
	local priest = EEex_LuaAction_Object or EEex_Sprite_GetInPortrait(0)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('TakePartyGold(' .. cost .. ')', priest)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroyGold(' .. cost .. ')', priest)
end

function SQPriest_Donate()
	local cost, _, gain = repCost()
	if cost <= 0 or not partyGoldAtLeast(cost) then return end
	pay(cost)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('ReputationInc(' .. gain .. ')', EEex_Sprite_GetInPortrait(0))
end

-- the spell's own effects (its first ability), applied on the member as if the priestess cast it
local function applySpell(sp, res)
	local h = EEex_Resource_Demand(res, 'SPL')
	if not h then return end
	local base = EEex_UDToPtr(h)
	local ab = EEex_PtrToUD(base + h.abilityOffset, 'Spell_ability_st')
	local eo = base + h.effectsOffset
	for i = ab.startingEffect, ab.startingEffect + ab.effectCount - 1 do
		local p = eo + i * 0x30
		local id = EEex_ReadU16(p)
		if id == 17 then   -- healing: "set to max HP" (the spells' "+100 % of max" went over the max applied this way)
			EEex_GameObject_ApplyEffect(sp, { effectID = 17, effectAmount = EEex_Sprite_GetStat(sp, 1) or 1, dwFlags = 1,
				durationType = 1, sourceID = sp.m_id, sourceTarget = sp.m_id })
		elseif id ~= 324 and id ~= 326 then   -- immunity checks / chained spells: the cure itself only
			EEex_GameObject_ApplyEffect(sp, {
				effectID = id,
				effectAmount = EEex_ReadU32(p + 0x4),
				dwFlags = EEex_ReadU32(p + 0x8),
				durationType = EEex_ReadU8(p + 0xC),
				duration = EEex_ReadU32(p + 0xE),
				res = EEex_ReadLString(p + 0x14, 8),
				numDice = EEex_ReadU32(p + 0x1C),
				diceSize = EEex_ReadU32(p + 0x20),
				sourceID = sp.m_id,
				sourceTarget = sp.m_id,
			})
		end
	end
end

T.SPELL = { raise = 'SPPR712A', wounds = 'SPPR607', drain = 'SPPR417', curse = 'SPPR307', poison = 'SPPR404', disease = 'SPPR317' }

function SQPriest_Heal()
	local total, _, list = healTotal()
	if not paidAny() or not partyGoldAtLeast(total) then return end
	if total > 0 then pay(total) end
	for _, n in ipairs(list) do
		for _, k in ipairs(T.ORDER) do
			if n[k] then pcall(applySpell, n.sp, T.SPELL[k]) end
		end
	end
end

-- ---- free: HP, poison, disease (John 2026-10-25) ----
T.REST_MSG = tonumber("SQ_PR_REST")
T.FREE_MSG = tonumber("SQ_PR_FREEMSG")

local function freeList()
	local out = {}
	for _, n in ipairs(needs()) do if n.free then out[#out + 1] = n.sp end end
	return out
end
function SQPriest_FreeAny() return #freeList() > 0 end

-- Heal's own effects (full HP, poison, disease, blindness, deafness...) on every living member who needs them
local function freeHeal(msg)
	local list = freeList()
	for _, sp in ipairs(list) do pcall(applySpell, sp, 'SPPR607') end
	if #list > 0 and msg and msg >= 0 then pcall(Infinity_DisplayString, Infinity_FetchString(msg)) end
	return #list
end
function SQPriest_FreeHeal() freeHeal(T.FREE_MSG) end

-- a rest in the camp: game time jumps by 8 hours in one go (2 hours or more is taken as a rest)
local HOUR = 4500   -- game ticks per hour (15 per second, 300 seconds)
SQCamp_Hooks = SQCamp_Hooks or {}
SQCamp_Hooks.restheal = function()
	local area = EEex_Area_GetVisible()
	local now = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
	local inCamp = area and string.upper(area.m_resref:get()) == 'SQCAMP'
	-- a loaded save is a new area object: no heal for the time between two saves
	local key = inCamp and EEex_UDToPtr(area) or nil
	if inCamp and T.lastTime and T.lastArea == key and now - T.lastTime >= 2 * HOUR then freeHeal(T.REST_MSG) end
	T.lastTime, T.lastArea = inCamp and now or nil, key
end

-- the camp's shared hook runner (also in M_SQCAIN.lua, #12): defined here too, the scholar is optional
if not SQCamp_WrapTick then
	function SQCamp_WrapTick()
		if SQCamp_TickWrapped or not SQCamp_Tick then return end
		SQCamp_TickWrapped = true
		local orig = SQCamp_Tick
		SQCamp_Tick = function()
			local now = Infinity_GetClockTicks()
			if not SQCamp_HooksNext or now >= SQCamp_HooksNext then
				SQCamp_HooksNext = now + 500
				for name, f in pairs(SQCamp_Hooks) do
					local ok, err = pcall(f)
					if not ok then SQCamp_HooksError = name .. ': ' .. tostring(err) end
				end
			end
			return orig()
		end
	end
end
if not T.wrapListener then
	T.wrapListener = true
	EEex_GameState_AddInitializedListener(function() SQCamp_WrapTick() end)
end
SQCamp_WrapTick()
