--[[
SadoQoL component #3 = PartyStash component #1 - Sorted loot (John 2026-10-18), BGEE and BG2EE.
Twin files (John 2026-10-19): SadoQoL/M_SQSORT.lua and PartyStash/M_SQSORT.lua (+ SQSORT.menu) are the same file and
must stay identical. Both mods install it under the same override name, so only one copy ever runs.

Ground piles and containers list their items sorted (John 2026-10-18), in four tiers:
  1. quest items, 2. weightless items worth WEIGHTLESS_MIN or more (gold piles by total, gems, rings...),
  3. the rest by value per weight unit (gold pieces per pound, the best deal to carry first; a weightless item
  counts as weight 1, like a 1 gp throwing dagger), 4. worthless items (value 0) last.
Within tiers 1 and 2 the most valuable comes first (a stack is worth unit value x count; wand charges are not a
stack); ties keep the game's order. Quest item = an item the game asks for: SadoQoL.tp2 reads every dialogue and script at install time and
lists the items checked or taken from the party (PartyHasItem, TakePartyItem, HasItem in dialogues...) that no
store sells (a dialogue asking for a healing potion does not make it a quest item).
That list replaces the placeholder in T.QUEST below (PartyStash.tp2 builds it the same way). Keys (item type 8) and critical items (ITM flag 0x1, e.g.
Korlasz's key) are quest items too. Gold is never a quest item.

How: the container's item list (CPtrList of CItem*) is reordered in place by rewriting each node's data pointer
(node + 0x10): no item is created or destroyed. A container is re-sorted when its item count changes, and every
FULL_MS anyway (stack sizes can change without the count changing).
The quick loot bar (WORLD_QUICKLOOT) shows the items of every pile near the party one pile after the other: its
Lua table loot.groundItems is sorted too, as a whole. Safe: a click there passes the entry's own slotId +
containerId to the engine, not its position. The engine refills that table at will, so it is checked every frame
(cheap when nothing changed: one comparison per entry).
Virtual stacks (John 2026-10-18): in that bar only, identical stackable items (same resref, same identified state:
arrows, potions, gold...) from every nearby pile show as one slot with the total count, no cap. The real piles are
untouched. The slot remembers its parts; groundItemClick (UI.MENU) is wrapped so one click takes every part,
highest slotId first per pile (taking a stack shifts the later slots of its pile).
Tuning live from the EEex console, e.g.  SQSort.ENABLED = false   SQSort.PERIOD = 500
--]]

SQSort = SQSort or {}
local T = SQSort

T.ENABLED = T.ENABLED ~= false
T.PERIOD  = T.PERIOD or 1000          -- ms between two checks of the visible area
T.FULL_MS = T.FULL_MS or 5000         -- every container is re-sorted this often
T.WEIGHTLESS_MIN = T.WEIGHTLESS_MIN or 50  -- gp: a weightless item this valuable goes first (= SQCont.MIN_RATIO)
T.QUEST   = SQ_SORT_QUEST_LIST        -- resref (upper case) -> true, filled by SadoQoL.tp2
T.itemCache = {}                      -- resref -> { quest, unit value, stackable, unit weight, gold }
T.counts = {}                         -- container id -> item count at the last sort (cleared on area change)

local TYPE_CONTAINER = 17
local TYPE_GOLD = 33
local TYPE_KEY = 8
local FLAG_CRITICAL = 0x1
local OFF_NODE_DATA = 0x10            -- CPtrList::CNode { pNext, pPrev, data }

local function itemInfo(res)
	local key = string.upper(res)
	local v = T.itemCache[key]
	if not v then
		local h = EEex_Resource_Demand(key, 'ITM')
		if not h then
			v = { false, 0, false, 0, false }
		elseif h.itemType == TYPE_GOLD then
			v = { false, 1, true, 0, true }   -- a gold pile is worth its count and weighs nothing
		else
			local quest = T.QUEST[key] == true or h.itemType == TYPE_KEY or EEex_BAnd(h.itemFlags, FLAG_CRITICAL) ~= 0
			v = { quest, h.baseValue, h.maxStackable > 1, h.baseWeight, false }
		end
		T.itemCache[key] = v
	end
	return v
end

-- tier (smaller first), score (bigger first)
local function sortKey(res, count)
	local info = itemInfo(res)
	local value = info[2] * ((info[3] and count > 1) and count or 1)
	if info[1] then return 1, value end
	if info[2] <= 0 then return 4, 0 end
	-- weightless: unit value decides (80 throwing daggers at 1 gp stay cheap), gold piles go by total
	if info[4] <= 0 and (info[5] and value or info[2]) >= T.WEIGHTLESS_MIN then return 2, value end
	return 3, info[2] / math.max(info[4], 1)   -- per unit: the ratio is the same for the whole stack
end

local function before(a, b)
	if a.tier ~= b.tier then return a.tier < b.tier end
	if a.score ~= b.score then return a.score > b.score end
	return a.index < b.index   -- stable: equal items keep their order
end

local function sortContainer(c)
	local nodes, items = {}, {}
	local node = c.m_lstItems.m_pNodeHead
	while node do
		local it = node.data
		local tier, score = sortKey(it.pRes.resref:get(), it.m_useCount1)
		local n = #nodes + 1
		nodes[n] = EEex_UDToPtr(node)
		items[n] = { ptr = EEex_UDToPtr(it), index = n, tier = tier, score = score }
		node = node.pNext
	end
	if #items < 2 then return end
	table.sort(items, before)
	for i, e in ipairs(items) do
		if e.index ~= i then EEex_WritePtr(nodes[i] + OFF_NODE_DATA, e.ptr) end
	end
end

-- Quick loot bar: loot.groundItems[0..n] = { item = { res, count... }, slotId, containerId }.

local function sortGround()
	local g = loot and loot.groundItems
	if not g or not g[0] then return end
	local done = T.groundDone
	if done and done.t == g then
		local same = true
		for i = 0, done.n do
			if g[i] ~= done[i] then same = false break end
		end
		if same and g[done.n + 1] == nil then return end
	end
	local list, stacks = {}, {}
	local i = 0
	while g[i] do
		local e = g[i]
		local it = e.item
		if not it then
			list[#list + 1] = { e = e, index = i, tier = 5, score = 0 }
		else
			local key = itemInfo(it.res)[3] and (string.upper(it.res) .. ':' .. tostring(it.identified))
			local x = key and stacks[key]
			if x then
				-- same stackable item: one virtual slot (a fresh table, the engine's entries stay as they are)
				if not x.e.sqParts then
					local first, item = x.e, {}
					for k, v in pairs(first.item) do item[k] = v end
					x.e = { item = item, slotId = first.slotId, containerId = first.containerId,
						sqParts = { { first.slotId, first.containerId, first.item.res } } }
				end
				local parts = x.e.sqParts
				parts[#parts + 1] = { e.slotId, e.containerId, it.res }
				x.count = x.count + math.max(tonumber(it.count) or 1, 1)
				x.e.item.count = x.count
			else
				x = { e = e, index = i, count = math.max(tonumber(it.count) or 1, 1) }
				list[#list + 1] = x
				if key then stacks[key] = x end
			end
		end
		i = i + 1
	end
	for _, x in ipairs(list) do
		if x.e.item then x.tier, x.score = sortKey(x.e.item.res, x.count) end
	end
	table.sort(list, before)
	done = { t = g, n = #list - 1 }
	for k, x in ipairs(list) do
		g[k - 1] = x.e
		done[k - 1] = x.e
	end
	for k = #list, i - 1 do g[k] = nil end   -- slots freed by the merge
	T.groundDone = done
end

-- One click on a virtual stack takes all its parts. Installed over UI.MENU's groundItemClick (again after each
-- UI reload, which redefines it).
local function takeGround(slot)
	local parts = {}
	for k, p in ipairs(slot.sqParts) do parts[k] = p end
	table.sort(parts, function(a, b)
		if a[2] ~= b[2] then return a[2] < b[2] end
		return a[1] > b[1]
	end)
	for _, p in ipairs(parts) do worldScreen:OnGroundButtonClick(p[1], p[2], p[3]) end
end

local function wrapGroundClick()
	if not groundItemClick or groundItemClick == T.groundClick then return end
	local orig = groundItemClick
	T.groundClick = function(slotId)
		local slot = loot.groundItems[slotId + worldScreen:GetTopGroundItem()]
		if T.ENABLED and slot and slot.item and slot.sqParts then
			T.groundDone = nil
			return takeGround(slot)
		end
		return orig(slotId)
	end
	groundItemClick = T.groundClick
end

local function scan(area)
	local now = Infinity_GetClockTicks()
	local key = area.m_resref:get()
	local full = key ~= T.areaKey or now - (T.fullAt or 0) >= T.FULL_MS
	if full or not T.ids then
		if key ~= T.areaKey then T.counts = {} end
		T.areaKey, T.fullAt = key, now
		-- the area's containers and ground piles (EEex_GameObject_Get makes garbage: not every tick)
		local ids = {}
		EEex_Utility_IterateCPtrList(area.m_lVertSortBack, function(id)
			local ob = EEex_GameObject_Get(id)
			if ob and ob.m_objectType == TYPE_CONTAINER then ids[#ids + 1] = id end
		end)
		T.ids, full = ids, true
	end
	for _, id in ipairs(T.ids) do
		local ob = EEex_GameObject_Get(id)
		if ob and ob.m_objectType == TYPE_CONTAINER then
			local c = EEex_GameObject_CastUserType(ob)
			local n = c.m_lstItems.m_nCount
			if full or T.counts[id] ~= n then
				T.counts[id] = n
				sortContainer(c)
			end
		end
	end
end

function SQSort_Tick()
	if groundItemClick ~= T.groundClick then pcall(wrapGroundClick) end
	if T.ENABLED then
		local ok, err = pcall(sortGround)
		if not ok then T.lastError = tostring(err) end
	end
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + T.PERIOD
	if not T.ENABLED then return false end
	local area = EEex_Area_GetVisible()
	if area and EEex_Sprite_GetInPortrait(0) then
		local ok, err = pcall(scan, area)
		if not ok then T.lastError = tostring(err) end
	end
	return false
end

-- The tick menu is pushed only on the world screen: pushed on a sprite load during character creation, a tick
-- menu crashed BG2 at the Appearance step (createCharScreen:GetCurrentPortrait 0xC0000005, found by the BG2 session
-- with GameLog, 2026-10-19). Any later menu push on the world screen brings it back (after a load or chargen).
local function pushTick()
	if Infinity_IsMenuOnStack('SQSORT_TICK') then return end
	if worldScreen == nil or e:GetActiveEngine() ~= worldScreen then return end
	Infinity_PushMenu('SQSORT_TICK')
end

-- Chained wrapper over whatever Infinity_PushMenu is now (other mods may wrap it too), installed once.
if not T.pushWrapped then
	T.pushWrapped = true
	local push = Infinity_PushMenu
	Infinity_PushMenu = function(...)
		local m = ...
		local r = table.pack(push(...)) -- forward the args as they came (pop() is not pop(nil))
		if m ~= 'SQSORT_TICK' then pcall(pushTick) end
		return table.unpack(r, 1, r.n)
	end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQSORT') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
