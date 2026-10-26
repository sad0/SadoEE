--[[
SadoQoL component #15 - The Old Scholar at the rest camp (John 2026-10-23; a nod to Deckard Cain, renamed: "plus subtil").

An old sage in a grey robe sits by the camp fire (SQCAIN.CRE, a human mage look). He identifies every unidentified
item of the party at once, PRICE gold pieces each: the backpacks and equipment of all party members, plus the
Party Stash (its PSTASH store) when Party Stash is installed. His lines are original, in his manner (no Diablo text).

How: the camp's tick SQCamp_Tick (M_SQCAMP.lua, wrapped here once the game state is up) runs SQCamp_Hooks.cain
while the party is in the camp: Cain is created at SPOT when he is not
there (saves made before this component, or a camp visited before). Dialogue SQCAIN.dlg asks
SQCain_State() (0 nothing to identify, 1 not enough gold, 2 ok; it sets the tokens <SQCAINN> = count and
<SQCAINC> = cost) and runs SQCain_Identify() (takes the gold, sets the "identified" flag of each item).
--]]

SQCain = SQCain or {}
local T = SQCain

T.PRICE = T.PRICE or 80
T.RES   = 'SQCAIN'
T.SPOT  = T.SPOT or { 560, 445, 10 }   -- x, y, facing (10 = north-east): south-west of the fire, facing it
if SQCampSite and SQCampSite.CAIN then T.SPOT = SQCampSite.CAIN end   -- BG2EE's camp

local FLAG_IDENTIFIED = 0x1
T.NAME = tonumber("SQ_CAIN_NAME")      -- his name's strref, written by SadoQoL.tp2

local function partyMembers()
	local out = {}
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(p)
		if s then out[#out + 1] = s end
	end
	return out
end

-- unidentified items: { { kind = 'item', item = CItem } | { kind = 'stash', ptr = store entry } }, plus the stash
local function unidentified()
	local out = {}
	for _, sp in ipairs(partyMembers()) do
		for slot = 0, 38 do
			local it = sp.m_equipment.m_items:get(slot)
			if it and EEex_BAnd(it.m_flags, FLAG_IDENTIFIED) == 0 then out[#out + 1] = { kind = 'item', item = it } end
		end
	end
	return out
end

-- Party Stash (optional): unidentified entries of the stash store, as PStash_List reports them
local function stashCount()
	if not (PStash_List and PStash_Ready and PStash_Ready()) then return 0 end
	local n = 0
	for _, e in ipairs(PStash_List()) do if not e.identified then n = n + 1 end end
	return n
end

local goldScripts = {}
local function partyGoldAtLeast(n)
	if n <= 0 then return true end
	goldScripts[n] = goldScripts[n] or EEex_Trigger_ParseConditionalString('PartyGoldGT(' .. (n - 1) .. ')')
	return EEex_Trigger_EvalScriptFileConditionalAsAIBase(goldScripts[n], EEex_Sprite_GetInPortrait(0))
end

function SQCain_State()
	local n = #unidentified() + stashCount()
	local cost = n * T.PRICE
	Infinity_SetToken('SQCAINN', tostring(n))
	Infinity_SetToken('SQCAINC', tostring(cost))
	Infinity_SetToken('SQCAINP', tostring(T.PRICE))
	if n == 0 then return 0 end
	if not partyGoldAtLeast(cost) then return 1 end
	return 2
end

-- dialogue triggers (SQCAIN.d): no "==" inside EEex_LuaTrigger, WeiDU's compiler splits the line there
function SQCain_None() return SQCain_State() == 0 end
function SQCain_Poor() return SQCain_State() == 1 end
function SQCain_Ok() return SQCain_State() == 2 end
function SQCain_Any() return SQCain_State() ~= 0 end
-- the Codex reply: only with Party Stash's PSXCHEST page in the game
function SQCain_HasCodex()
	local ok, r = pcall(EEex_Resource_Fetch, 'PSXCHEST', 'STO')
	return ok and r ~= nil
end
-- the greeting's state trigger: the tokens are set before any reply text is shown; always true
function SQCain_Prime() pcall(SQCain_State) return true end

-- Identifies the stash's entries in place: raw store entry flags u32 at +0x10, bit 0 = identified (as PStash_List
-- reads them). Same demand / get / release calls as Party Stash (M_PSTASH.lua); returns how many were set.
local function identifyStash()
	if not (PStash and PStash.RES and PStash_Ready and PStash_Ready() and PStash.scratch) then return 0 end
	local game, buf, n = EEex_UDToPtr(EEex_EngineGlobal_CBaldurChitin.m_pObjectGame), PStash.scratch, 0
	for i = 0, 7 do EEex_WriteU8(buf + i, i < #PStash.RES and string.byte(PStash.RES, i + 1) or 0) end
	PStash_Eng_DemandServerStore(game, buf, 0)
	local ok, err = pcall(function()
		local storePtr = PStash_Eng_GetServerStore(game, buf)
		if storePtr == 0 then return end
		EEex_Utility_IterateCPtrList(EEex_PtrToUD(storePtr, 'CStore').m_lInventory, function(data)
			local ptr = type(data) == 'number' and data or EEex_UDToPtr(data)
			local f = EEex_ReadU32(ptr + 0x10)
			if EEex_BAnd(f, FLAG_IDENTIFIED) == 0 then EEex_WriteU32(ptr + 0x10, f + FLAG_IDENTIFIED) n = n + 1 end
		end)
	end)
	PStash_Eng_ReleaseServerStore(game, buf)
	if not ok then T.lastError = tostring(err) end
	PStash.dirty = true
	return n
end

function SQCain_Identify()
	local items = unidentified()
	local n = #items + stashCount()
	local cost = n * T.PRICE
	if n == 0 or not partyGoldAtLeast(cost) then return end
	local cain = EEex_LuaAction_Object or EEex_Sprite_GetInPortrait(0)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('TakePartyGold(' .. cost .. ')', cain)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroyGold(' .. cost .. ')', cain)
	for _, e in ipairs(items) do e.item.m_flags = EEex_BOr(e.item.m_flags, FLAG_IDENTIFIED) end
	identifyStash()
end

-- ---- camp presence ----
local function present(area)
	local found = false
	for _, list in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[list], function(id)
			local o = EEex_GameObject_Get(id)
			if o and o.m_objectType == 49 then
				local sp = EEex_GameObject_CastUserType(o)
				if string.upper(sp.m_scriptName:get()) == T.RES then found, T.found = true, sp return true end
			end
		end)
		if found then break end
	end
	return found
end

SQCamp_Hooks = SQCamp_Hooks or {}
SQCamp_Hooks.cain = function()
	local area = EEex_Area_GetVisible()
	if not area or string.upper(area.m_resref:get()) ~= 'SQCAMP' then return end
	if not area then return end
	if present(area) then
		-- saves made before the renaming keep the old name: give him the current one
		if T.NAME and T.found and T.found.m_baseStats.m_name ~= T.NAME then
			T.found.m_baseStats.m_name = T.NAME
			pcall(function() T.found.m_baseStats.m_apparentName = T.NAME end)
		end
		return
	end
	local now, key = Infinity_GetClockTicks(), EEex_UDToPtr(area)
	-- right after the area loads its actors may not be listed yet (a duplicate was made, 2026-10-23): the camp must
	-- have been entered 3 s ago (SQCamp.spawnSince, M_SQCAMP.lua)
	if SQCamp.spawnArea ~= key or now - (SQCamp.spawnSince or now) < 3000 then return end
	-- once per camp visit, created at once (a CreateCreature queued on a talking leader or a paused game waited,
	-- and the next try made a second scholar: Compat test, 2026-10-25)
	if T.pending == key or not SQCamp_Create then return end
	T.pending = key
	SQCamp_Create(T.RES, T.SPOT[1], T.SPOT[2], T.SPOT[3])
end

-- Camp residents (Cain #15, Withers #16) share one wrapper around the camp's tick: SQCamp_Hooks[name]() each tick.
-- M_SQCAIN.lua loads before M_SQCAMP.lua (alphabetical), so the wrap waits for the game state.
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
if not T.listenerAdded then
	T.listenerAdded = true
	EEex_GameState_AddInitializedListener(SQCamp_WrapTick)
end
SQCamp_WrapTick()

-- The camp's people carry no weapons (John 2026-10-23): their weapon slots (35-38) and off-hand (2) are emptied once.
local CAMP_NPCS = { SQPRIEST = true, SQMERCH = true, SQCAIN = true }
SQCamp_Hooks.unarm = function()
	local area = EEex_Area_GetVisible()
	if not area or string.upper(area.m_resref:get()) ~= 'SQCAMP' then return end
	EEex_Utility_IterateCPtrList(area.m_lVertSort, function(id)
		local o = EEex_GameObject_Get(id)
		if not (o and o.m_objectType == 49) then return end
		local sp = EEex_GameObject_CastUserType(o)
		if not CAMP_NPCS[string.upper(sp.m_scriptName:get())] then return end
		for _, slot in ipairs({ 35, 36, 37, 38, 2 }) do
			local it = sp.m_equipment.m_items:get(slot)
			if it then
				local h = EEex_Resource_Demand(it.pRes.resref:get(), 'ITM')
				-- off-hand: a shield (item type 12) stays, a weapon goes
				if slot ~= 2 or (h and h.itemType ~= 12) then
					EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroyItem("' .. it.pRes.resref:get() .. '")', sp)
				end
			end
		end
	end)
end
