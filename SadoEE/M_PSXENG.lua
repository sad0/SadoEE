--[[
Party Stash engine extension (PROTOTYPE, John 2026-10-23, issue #1). Requires EEex. BGEE / BG2EE / EET, v2.6.6 and v2.7.3.
Separate from M_PSTASH.lua on purpose: nothing here is wired into the installer yet.

1. Merchant hook (store buy list, STORE_BUYSELL):
   The engine rebuilds the Lua table store.storeItems from scratch on every update (CScreenStore::UpdateBuySellPanel:
   lua_createtable + lua_settable on the global `store`). `store` is turned into a proxy whose raw table stays empty,
   so each engine write goes through __newindex: the fresh list is sorted there, before anything draws it.
   Only the Lua view is reordered: the real store (CStore) and the screen's own item list are untouched. The two
   engine methods that take a row index (SelectStoreItem, SetStoreItemCount) are wrapped on the CScreenStore tolua
   class to translate the shown row back to the engine's row.
   Ctrl + click on a store item toggles it on the wishlist (global PSXW_<RES>, kept in the save) instead of selecting
   it. Wishlisted items come first and their name gets a "* " prefix.
2. Loot hook: PSXEng_AddLootListener(fn) calls fn(ev) when an item lands in a party member's backpack (slots 18-33):
   ev = { portrait, sprite, slot, res, count, added, stolen, moved, item }. moved = the same item object (CItem*) was
   in another member's backpack just before (a transfer inside the party, not loot). Polled from a tick menu on the
   world screen every PSXEng.LOOT_MS: an item bought or taken in another screen is reported on return to the world.
   The first scan after a load is a baseline (no events).
Tuning from the EEex console: PSXEng.SORT = 'type' | 'price' | 'name' | false   PSXEng.DEBUG = true
--]]

PSXEng = PSXEng or {}
local X = PSXEng
if X.SORT == nil then X.SORT = 'type' end
X.LOOT_MS = X.LOOT_MS or 250
X.DEBUG = X.DEBUG or false
X.lootListeners = X.lootListeners or {}

local function log(...)
	if X.DEBUG then print('[PSXEng] ' .. string.format(...)) end
end

local function ctrlDown()
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left Ctrl')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Ctrl'))
end

-----------------------
-- Merchant: wishlist --
-----------------------

local function wishKey(res) return 'PSXW_' .. string.upper(res) end
function PSXEng_IsWished(res) return res ~= nil and res ~= '' and EEex_GameState_GetGlobalInt(wishKey(res)) == 1 end
function PSXEng_ToggleWish(res)
	if not res or res == '' then return end
	EEex_GameState_SetGlobalInt(wishKey(res), PSXEng_IsWished(res) and 0 or 1)
end

-----------------------
-- Merchant: sorting  --
-----------------------

X.itmCache = X.itmCache or {}
-- { type, price } from the ITM header (cached per resref).
local function itmInfo(res)
	res = string.upper(res or '')
	local c = X.itmCache[res]
	if c then return c end
	c = { type = 999, price = 0 }
	pcall(function()
		local p = EEex_Resource_Demand(res, 'ITM')
		if p then
			p = EEex_UDToPtr(p)
			c.type, c.price = EEex_ReadU16(p + 0x1C), EEex_ReadU32(p + 0x34)
		end
	end)
	X.itmCache[res] = c
	return c
end

local function entryRes(e) return e and e.item and string.upper(e.item.res or '') or '' end

-- The shown order of a fresh engine list `t` (sorted in place). X.map[shownRow] = engineRow (both 1-based).
local function sortStoreList(t)
	local n = #t
	local rows = {}
	for i = 1, n do
		local e = t[i]
		local res = entryRes(e)
		local info = itmInfo(res)
		rows[i] = { e = e, orig = i, wish = PSXEng_IsWished(res), type = info.type, price = info.price,
			name = tostring(e and e.label or '') }
	end
	local mode = X.SORT
	table.sort(rows, function(a, b)
		if a.wish ~= b.wish then return a.wish end
		if mode == 'price' then
			if a.price ~= b.price then return a.price > b.price end
		elseif mode == 'name' then
			if a.name ~= b.name then return a.name < b.name end
		elseif mode == 'type' then
			if a.type ~= b.type then return a.type < b.type end
			if a.price ~= b.price then return a.price > b.price end
		end
		return a.orig < b.orig -- stable: ties keep the engine's order
	end)
	local map = {}
	for i, r in ipairs(rows) do
		t[i] = r.e
		map[i] = r.orig
		if r.wish and r.e and type(r.e.label) == 'string' and r.e.label:sub(1, 2) ~= '* ' then r.e.label = '* ' .. r.e.label end
	end
	X.map, X.mapList = map, t
	log('store list sorted (%d items, mode %s)', n, tostring(mode))
end

-- Engine row (0-based) for a shown row (0-based), as long as the shown list is the last one sorted.
local function engineRow(i)
	if type(i) ~= 'number' or not X.map or X.mapList ~= (store and store.storeItems) then return i end
	local o = X.map[i + 1]
	return o and (o - 1) or i
end
X.engineRow = engineRow

-- `store` proxy: every key lives in X.storeData, so engine writes (lua_settable) always reach __newindex.
local function hookStoreTable()
	if type(store) ~= 'table' then return false end
	local mt = getmetatable(store)
	if mt and mt.__psx then return true end
	if mt then log('store already has a metatable: not hooked') return false end
	local data = {}
	for k, v in pairs(store) do data[k] = v end
	for k in pairs(data) do store[k] = nil end
	X.storeData = data
	setmetatable(store, {
		__psx = true,
		__index = data,
		__newindex = function(_, k, v)
			if k == 'storeItems' and type(v) == 'table' and X.SORT then
				local ok, err = pcall(sortStoreList, v)
				if not ok then X.map = nil print('[PSXEng] store sort error: ' .. tostring(err)) end
			end
			data[k] = v
		end,
		__pairs = function() return next, data, nil end,
	})
	log('store table hooked')
	return true
end

-- CScreenStore tolua class: methods sit in the class metatable (rawget), shared by the storeScreen userdata.
local function hookStoreClass()
	if storeScreen == nil then return false end
	local mt = getmetatable(storeScreen)
	if not mt then return false end
	if rawget(mt, '__psxHooked') then return true end
	local sel, cnt = rawget(mt, 'SelectStoreItem'), rawget(mt, 'SetStoreItemCount')
	if type(sel) ~= 'function' or type(cnt) ~= 'function' then log('CScreenStore methods not found') return false end
	rawset(mt, '__psxHooked', true)
	X.origSelect, X.origCount = sel, cnt
	rawset(mt, 'SelectStoreItem', function(self, i, on, ...)
		if ctrlDown() and type(i) == 'number' then
			local e = store and store.storeItems and store.storeItems[i + 1]
			local res = entryRes(e)
			if res ~= '' then
				PSXEng_ToggleWish(res)
				log('wishlist %s = %s', res, tostring(PSXEng_IsWished(res)))
				pcall(function() self:UpdateBuySellPanel() end) -- rebuild: re-sorted with the new mark
				return
			end
		end
		return sel(self, engineRow(i), on, ...)
	end)
	rawset(mt, 'SetStoreItemCount', function(self, i, n, ...) return cnt(self, engineRow(i), n, ...) end)
	log('CScreenStore hooked')
	return true
end

function PSXEng_HookStore()
	local a, b = hookStoreTable(), hookStoreClass()
	return a and b
end

-----------------------
-- Loot hook          --
-----------------------

function PSXEng_AddLootListener(fn) table.insert(X.lootListeners, fn) end

local BACKPACK_FIRST, BACKPACK_LAST = 18, 33

-- { [CItem*] = { portrait, slot, res, count, flags } } of every party backpack.
local function snapshot()
	local out = {}
	for portrait = 0, 5 do
		local sp = EEex_Sprite_GetInPortrait(portrait)
		if sp then
			local items = sp.m_equipment.m_items
			for slot = BACKPACK_FIRST, BACKPACK_LAST do
				local it = items:get(slot)
				if it then
					out[EEex_UDToPtr(it)] = { portrait = portrait, slot = slot, res = string.upper(it.pRes.resref:get()),
						count = it.m_useCount1, flags = it.m_flags, item = it, sprite = sp }
				end
			end
		end
	end
	return out
end

local function fire(ev)
	log('loot: P%d slot %d %s x%d (+%d)%s%s', ev.portrait + 1, ev.slot, ev.res, ev.count, ev.added,
		ev.stolen and ' STOLEN' or '', ev.moved and ' (moved)' or '')
	for _, fn in ipairs(X.lootListeners) do
		local ok, err = pcall(fn, ev)
		if not ok then print('[PSXEng] loot listener error: ' .. tostring(err)) end
	end
end

function PSXEng_LootScan()
	local now = snapshot()
	local before = X.lootSnap
	X.lootSnap = now
	if not before then return end -- baseline
	for ptr, s in pairs(now) do
		local b = before[ptr]
		local added
		if not b then added = math.max(1, s.count)
		elseif s.count > b.count then added = s.count - b.count end
		local moved = b ~= nil and b.portrait ~= s.portrait
		if moved and not added then added = math.max(1, s.count) end
		if added then
			fire({ portrait = s.portrait, sprite = s.sprite, slot = s.slot, res = s.res, count = s.count, added = added,
				stolen = EEex_BAnd(s.flags, 0x4) ~= 0, moved = moved, item = s.item })
		end
	end
end

-- Tick: the PSXENG_TICK menu's enabled check runs every frame on the world screen.
function PSXEng_Tick()
	local t = Infinity_GetClockTicks()
	if X.nextLoot and t < X.nextLoot then return false end
	X.nextLoot = t + X.LOOT_MS
	if not X.storeHooked then X.storeHooked = PSXEng_HookStore() end
	if PSXP7_Mirror then pcall(PSXP7_Mirror) end -- >6 prototype: keep the old party arrays' copy current
	if PSXP7_BarTick then pcall(PSXP7_BarTick) end -- >6 prototype: portrait bar for members 7+
	if #X.lootListeners > 0 or X.DEBUG then
		local ok, err = pcall(PSXEng_LootScan)
		if not ok then print('[PSXEng] loot scan error: ' .. tostring(err)) end
	end
	return false
end

-- Same tick menu pattern as M_PSTASH / M_SQSORT (world screen only: a tick menu crashed chargen in BG2).
local function pushTick()
	if Infinity_IsMenuOnStack('PSXENG_TICK') then return end
	if worldScreen == nil or e:GetActiveEngine() ~= worldScreen then return end
	Infinity_PushMenu('PSXENG_TICK')
end

if not X.pushWrapped then
	X.pushWrapped = true
	local push = Infinity_PushMenu
	Infinity_PushMenu = function(...)
		local m = ...
		local r = table.pack(push(...))
		if m ~= 'PSXENG_TICK' then pcall(pushTick) end
		return table.unpack(r, 1, r.n)
	end
end

if not X.listenersAdded then
	X.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function()
		EEex_Menu_LoadFile('PSXENG')
		X.storeHooked = PSXEng_HookStore()
	end)
	EEex_Menu_AddAfterMainFileReloadedListener(function()
		X.storeHooked = PSXEng_HookStore()
		pcall(pushTick)
	end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(function()
		X.lootSnap = nil -- new game or load: next scan is a baseline
		pushTick()
	end)
end
