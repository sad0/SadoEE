--[[
Party Stash "grand marchand" (camp merchant), branch feature/grand-marchand (John 2026-10-23). Requires EEex and
M_PSTASH.lua (its engine stubs and item data). BGEE / BG2EE / EET, v2.6.6 and v2.7.3.

One merchant at the camp (SadoQoL's creature: StartStore("PSXCAMP", ...)) sells what the stores the party already
visited have in stock right now (John 2026-10-23: the exact stocks).
1. Known stores: those held by the loaded save (its BALDUR.SAV lists every store the party opened; read after each
   load) and those opened since. Nothing else is kept.
2. The camp store PSXCAMP is a real STO, rebuilt from them each time it opens (CStore::AddItem / CompressItems): per
   item, the sum of the stores' stocks (unlimited when one store has it unlimited); critical / quest items left out.
   The vanilla buy flow (gold, room, stolen flags) works unchanged.
3. Price: each copy at the price of the store it comes from, cheapest first. The camp store's markup (STO +0x14) is
   switched to that store's just around the engine's select + buy calls (reputation and charisma apply on top as the
   game does), and the copies bought are taken out of that store's stock.
3. The page (PSXGM.menu) replaces the vanilla buy list of the camp store: category tree, 8 x 7 icon grid with pages,
   name search, "usable by the selected character" and "affordable" filters, wishlist first (Ctrl + click, global
   PSXW_<RES>, the same as M_PSXENG.lua), price in the tooltip. Selling stays on the vanilla panel ("Vanilla view")
   and its "Sell Marked" button.
Console: PSXGM.DEBUG = true   PSXGM_Rescan()   PSXGM_Catalog()
--]]

PSXGM = PSXGM or {}
local G = PSXGM
G.CAMP = 'PSXCAMP'
G.CHEST = 'PSXCHEST' -- the camp chest: the stash + what the known stores sell + every item of the game
G.SEEN = 'PSXSEEN'   -- hidden bag: the save's log of the items seen
G.mode = G.mode or 'camp'
G.COLS, G.ROWS = 8, 7
G.DEBUG = G.DEBUG or false
G.page = G.page or 1
G.cat = G.cat or 'all'
G.expanded = G.expanded or {}
if G.sortV ~= 2 then G.sort, G.sortV = 'auto', 2 end -- Auto by default (John 2026-10-23)
G.qty = G.qty or 1
G.msg = G.msg or ''
gmFindText = gmFindText or ''

local function log(...)
	if G.DEBUG then print('[PSXGM] ' .. string.format(...)) end
end

-- English UI strings; a translation can override them through PStash_Strings (keys gm_*).
G.EN = {
	gm_title = 'Camp merchant', gm_all = 'All', gm_weapons = 'Weapons', gm_armor = 'Armor', gm_equipment = 'Equipment',
	gm_potions = 'Potions', gm_scrolls = 'Scrolls', gm_gems = 'Gems', gm_ammo = 'Ammo', gm_misc = 'Misc',
	gm_bows = 'Bows', gm_crossbows = 'Crossbows', gm_slings = 'Slings', gm_daggers = 'Daggers',
	gm_short_swords = 'Short swords', gm_long_swords = 'Long swords', gm_bastard_swords = 'Bastard swords',
	gm_two_handed = 'Two-handed swords', gm_katanas = 'Katanas', gm_scimitars = 'Scimitars', gm_axes = 'Axes',
	gm_maces = 'Maces', gm_hammers = 'War hammers', gm_flails = 'Flails, morning stars', gm_clubs = 'Clubs',
	gm_staves = 'Quarterstaves', gm_spears = 'Spears', gm_halberds = 'Halberds', gm_fists = 'Fist weapons',
	gm_robes = 'Robes', gm_leather = 'Leather', gm_mail = 'Mail', gm_plate = 'Plate', gm_other_armor = 'Other armor',
	gm_shields = 'Shields', gm_helmets = 'Helmets', gm_bracers = 'Bracers, gauntlets',
	gm_rings = 'Rings', gm_amulets = 'Amulets', gm_belts = 'Belts', gm_boots = 'Boots', gm_cloaks = 'Cloaks',
	gm_wands = 'Wands', gm_bags = 'Bags',
	gm_arrows = 'Arrows', gm_bolts = 'Bolts', gm_bullets = 'Bullets', gm_darts = 'Darts',
	gm_search = 'Search', gm_usable = 'Usable', gm_affordable = 'Affordable', gm_sort = 'Sort: %s',
	gm_sort_auto = 'Auto', gm_sort_type = 'Type', gm_sort_price = 'Price', gm_sort_name = 'Name',
	gm_buy = 'Buy', gm_done = 'Done', gm_vanilla = 'Sell / vanilla view', gm_back = 'Camp merchant',
	gm_price = '%d gp', gm_unlimited = 'Unlimited', gm_stock = '%d in stock', gm_from = 'From: %s', gm_wished = 'Wishlist',
	gm_items = '%d items', gm_empty = 'Nothing here yet: visit stores to fill the camp merchant.',
	gm_no_gold = 'Not enough gold', gm_full = 'Backpack full: select another character', gm_cannot_buy = 'Cannot buy that now', gm_bought = 'Bought: %s x%d',
	gm_select = 'Click: choose\nCtrl + click: wishlist\nRight click: description',
	gm_total = 'Total: %d gp',
	gm_skin = 'Board: %s', gm_skin_1 = 'pinned notices', gm_skin_2 = 'painted',
	gm_sell_marked = 'Sell marked: %s gp', gm_sell_none = 'Nothing marked', gm_sold = 'Sold from the stash: %d gp',
	gm_chest = 'Codex', gm_stash = 'Party stash', gm_take = 'Take', gm_in_stash = '%d in the stash',
	gm_value = 'Value: %d gp', gm_never_seen = 'Never seen', gm_seen_1 = 'Seen for sale: %s', gm_seen_2 = 'Carried: %s',
	gm_seen_3 = 'Seen on the ground: %s', gm_seen_4 = 'Seen in a container: %s',
	gm_origin = 'Where it comes from:', gm_more = '+%d more', gm_from_S = 'Sold by %s', gm_from_G = '%s: on the ground',
	gm_from_C = '%s: %s', gm_from_K = 'Carried by %s at %s', gm_from_K0 = 'Carried by %s', gm_from_G0 = 'On the ground',
	gm_from_D = 'Given by %s at %s', gm_from_D1 = 'Given by %s', gm_from_D2 = 'Given at %s',
	gm_from_D0 = 'Given in a quest or a dialogue', gm_from_P = 'Carried by %s (appears) at %s',
	gm_from_P0 = 'Carried by %s (appears)', gm_from_T = 'Random treasure',
	gm_equipped_by = 'Equipped by %s', gm_in_pack = "In %s's pack", gm_cf_8 = 'Carried', gm_cf_9 = 'Found',
	gm_cf_10 = 'Not found',
	gm_cf_1 = 'BG', gm_cf_2 = 'SoD', gm_cf_3 = 'BG2', gm_cf_4 = 'ToB', gm_cf_5 = 'BP1', gm_cf_6 = 'BP2', gm_cf_7 = 'Other',
	gm_camp_1 = "Baldur's Gate", gm_camp_2 = 'Siege of Dragonspear', gm_camp_3 = 'Shadows of Amn', gm_camp_4 = 'Throne of Bhaal',
	gm_camp_5 = 'The Black Pits', gm_camp_6 = 'The Black Pits II', gm_camp_7 = 'Elsewhere',
	gm_from_C0 = 'Container: %s', gm_from_S2 = 'Sold at %s: %s', gm_at = '%s, %s',
	-- container types (ARE container type), "In a container" when unknown
	gm_ctype = 'container', gm_ctype_1 = 'bag', gm_ctype_2 = 'chest', gm_ctype_3 = 'drawer', gm_ctype_5 = 'table',
	gm_ctype_6 = 'shelf', gm_ctype_7 = 'altar', gm_ctype_8 = 'hidden', gm_ctype_9 = 'spellbook', gm_ctype_10 = 'body',
	gm_ctype_11 = 'barrel', gm_ctype_12 = 'crate',
}
-- PSXGM_Strings: the installed language's M_PSXGT.lua (build_gm_strings.py; component #8 copies it).
local function T(key, ...)
	local s = (PSXGM_Strings and PSXGM_Strings[key]) or (PStash_Strings and PStash_Strings[key]) or G.EN[key] or key
	if select('#', ...) > 0 then return string.format(s, ...) end
	return s
end
PSXGM_T = T

-- Infinity_IsMenuOnStack returns 1 / nil, not booleans.
local function onStack(name) return Infinity_IsMenuOnStack(name) and true or false end

local function ctrlDown()
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left Ctrl')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Ctrl'))
end

local function getG(name) return EEex_GameState_GetGlobalInt(name) end
local function setG(name, v) EEex_GameState_SetGlobalInt(name, v) end

-- Wishlist: the same globals as M_PSXENG.lua (PSXW_<RES>).
local function isWished(res)
	if PSXEng_IsWished then return PSXEng_IsWished(res) end
	return res ~= nil and res ~= '' and getG('PSXW_' .. res) == 1
end
local function toggleWish(res)
	if PSXEng_ToggleWish then return PSXEng_ToggleWish(res) end
	setG('PSXW_' .. res, isWished(res) and 0 or 1)
end

-----------------------
-- Engine access      --
-----------------------

local function readRes(addr)
	local out = {}
	for i = 0, 7 do
		local b = EEex_ReadU8(addr + i)
		if b == 0 then break end
		out[#out + 1] = string.char(b)
	end
	return string.upper(table.concat(out))
end

G.scratch = G.scratch or nil
local function resRef(res, offset)
	G.scratch = G.scratch or EEex_Malloc(64) -- [0] store resref, [16] item resref, [32] int err
	local buf = G.scratch + (offset or 0)
	res = string.upper(res)
	for i = 0, 7 do EEex_WriteU8(buf + i, i < #res and string.byte(res, i + 1) or 0) end
	return buf
end

local function gamePtr() return EEex_UDToPtr(EEex_EngineGlobal_CBaldurChitin.m_pObjectGame) end

-- CStore layout (BGEE 2.7.3, CStore::GetItemBuyValue): the STO header is copied at +0: +0x08 type, +0x10 flags,
-- +0x14 sell markup (what the player pays, %). Inventory entries (CStoreFileItem, STO layout): +0x00 resref,
-- +0x0A..0x0E 3 usages, +0x10 flags (1 identified, 4 stolen), +0x14 stock, +0x18 infinite.
local STO_TYPE, STO_FLAGS, STO_SELL = 0x08, 0x10, 0x14
local FI_USE1, FI_FLAGS, FI_STOCK, FI_INF = 0x0A, 0x10, 0x14, 0x18

local function storeEntries(storePtr)
	local out = {}
	EEex_Utility_IterateCPtrList(EEex_PtrToUD(storePtr, 'CStore').m_lInventory, function(data)
		local ptr = type(data) == 'number' and data or EEex_UDToPtr(data)
		out[#out + 1] = { ptr = ptr, res = readRes(ptr), flags = EEex_ReadU32(ptr + FI_FLAGS),
			stock = EEex_ReadU32(ptr + FI_STOCK), inf = EEex_ReadU32(ptr + FI_INF),
			u = { EEex_ReadU16(ptr + FI_USE1), EEex_ReadU16(ptr + FI_USE1 + 2), EEex_ReadU16(ptr + FI_USE1 + 4) } }
	end)
	return out
end

-- Runs fn(storePtr) on a server store (loaded from the save when it was visited), released after.
local function withStore(res, fn)
	if not (PStash_Ready and PStash_Ready()) then return nil end
	local game = gamePtr()
	PStash_Eng_DemandServerStore(game, resRef(res), 0)
	local ok, a, b = pcall(function()
		local p = PStash_Eng_GetServerStore(game, resRef(res))
		if p == 0 then return nil end
		return fn(p)
	end)
	PStash_Eng_ReleaseServerStore(game, resRef(res))
	if not ok then print('[PSXGM] ' .. res .. ': ' .. tostring(a)) return nil end
	return a, b
end

-- The store open in the store screen: (CStore*, resref) or nil.
local function openStore()
	if storeScreen == nil or e:GetActiveEngine() ~= storeScreen then return nil end
	local ok, p, res = pcall(function()
		-- the EEex view of the screen (the global storeScreen is the engine's own binding, without fields)
		local s = EEex_EngineGlobal_CBaldurChitin.m_pEngineStore.m_pStore
		if s == nil then return nil end
		return EEex_UDToPtr(s), string.upper(s.m_resRef:get())
	end)
	if ok and p and p ~= 0 then return p, res end
end
G.openStore = openStore

local function atCamp()
	local _, res = openStore()
	return res == G.CAMP
end
PSXGM_AtCamp = atCamp

-----------------------
-- Item data          --
-----------------------

G.info = G.info or {}
-- PStash_ItemInfo + the armor animation (ITM +0x22) and the names as text.
local function itemInfo(res)
	local c = G.info[res]
	if c ~= nil then return c or nil end
	local pi = PStash_ItemInfo and PStash_ItemInfo(res)
	if not pi then G.info[res] = false return nil end
	c = setmetatable({}, { __index = pi })
	pcall(function()
		local p = EEex_UDToPtr(EEex_Resource_Demand(res, 'ITM'))
		c.anim = string.char(EEex_ReadU8(p + 0x22), EEex_ReadU8(p + 0x23))
	end)
	c.anim = c.anim or ''
	c.idText = Infinity_FetchString(pi.idName) or ''
	c.unidText = Infinity_FetchString(pi.unidName) or ''
	G.info[res] = c
	return c
end

local function questItem(info, res)
	local P = PStash or {}
	if info.critical then return true end
	if P.NOT_QUEST and P.NOT_QUEST[res] then return false end
	return (P.KEEP and P.KEEP[res]) or (P.QUEST and P.QUEST[res]) or false
end

-- Never sold at the camp: quest / critical items, gold, the Party Stash bag itself.
local function excluded(info, res)
	return questItem(info, res) or info.type == 33 or res == 'PSTASH'
end

-- Engine functions of our own, through the same fixed-target stubs as M_PSTASH.lua (PStash.buildStub). Same bytes
-- on BGEE / BG2EE / EET of each build (checked 2026-10-23). The game's Lua has no io library: the save file is read
-- with the engine's own C runtime (_wfopen, fread, fseek, fclose) and dimmResolveFileName ("home:/..." -> real path).
-- CStore::AddItem: CInfGame::AddItemToStore only takes bags (STO type 5) and pays the item's sale value.
-- CStore::CompressItems drops the entries with no stock that are not unlimited.
local FILE_FUNCS = {
	['2.7.3.0'] = { ResolveFileName = 0x1404058F0, wfopen = 0x14050FAA0, fread = 0x14050F354, fseek = 0x14050FD20,
		fclose = 0x14050F060, StoreAddItem = 0x14024F650, StoreCompress = 0x14024FA90 },
	['2.6.6.0'] = { ResolveFileName = 0x140404A50, wfopen = 0x14050EAC0, fread = 0x14050E374, fseek = 0x14050ED40,
		fclose = 0x14050E080, StoreAddItem = 0x14024F3F0, StoreCompress = 0x14024F830 },
}
local FILE_PROLOGUE = {
	ResolveFileName = { { 0x40, 0x53, 0x48, 0x83, 0xEC, 0x20, 0x41, 0xB8 }, 1 },
	wfopen = { { 0x41, 0xB8, 0x40, 0x00, 0x00, 0x00, 0xE9 }, 2 },
	fread = { { 0x48, 0x83, 0xEC, 0x38, 0x4C, 0x89, 0x4C, 0x24 }, 4 },
	fseek = { { 0x48, 0x63, 0xD2, 0xE9 }, 3 },
	fclose = { { 0x48, 0x89, 0x5C, 0x24, 0x10, 0x48, 0x89, 0x4C }, 1 },
	StoreAddItem = { { 0x40, 0x53, 0x55, 0x56, 0x48, 0x83, 0xEC, 0x70 }, 2 }, -- CStore::AddItem(this, CItem&)
	StoreCompress = { { 0x48, 0x89, 0x5C, 0x24, 0x10, 0x56, 0x48, 0x83 }, 1 }, -- CStore::CompressItems(this)
}

local function fileReady()
	if G.fileReady ~= nil then return G.fileReady end
	G.fileReady = false
	local build = PStash_Build and PStash_Build()
	local t = build and FILE_FUNCS[build]
	if not t or not (PStash and PStash.buildStub) then return false end
	for name, pro in pairs(FILE_PROLOGUE) do
		for i, b in ipairs(pro[1]) do
			if EEex_ReadU8(t[name] + i - 1) ~= b then print('[PSXGM] ' .. name .. ': unknown bytes') return false end
		end
	end
	for name, pro in pairs(FILE_PROLOGUE) do
		if not _G['PStash_Eng_GM_' .. name] then PStash.buildStub('GM_' .. name, t[name], pro[2]) end
	end
	G.fileReady = true
	return true
end

-----------------------
-- Camp store         --
-----------------------
-- A live window on every store the party knows (John 2026-10-23): for each item, the sum of the current stocks
-- (unlimited when one store has it unlimited), each copy at the price of the store it comes from (cheapest first),
-- and a copy bought at the camp is taken out of its store. Known stores: those held by the loaded save (read after
-- each load) and those opened since. The camp store PSXCAMP is rebuilt from them each time it opens.
G.known = G.known or {} -- [store resref] = true

local function findEntry(storePtr, res)
	for _, it in ipairs(storeEntries(storePtr)) do if it.res == res then return it end end
end

-- A CItem for CStore::AddItem (the engine copies it).
-- CItem(CResRef, useCount1, useCount2, useCount3, wear, flags) through the binding's manual overload.
local function makeItem(res, u)
	local it = EEex_NewUD('CItem')
	local rr = EEex_NewUD('CResRef')
	rr:set(res)
	it:Construct_Overload_Manual(rr, u[1], u[2], u[3], 0, 1)
	return it
end
G.makeItem = makeItem

-- Puts one more entry in the camp store (the server store, kept and saved by the engine).
local function addToCamp(campPtr, res, u)
	local ok, err = pcall(function()
		if not fileReady() then error('engine build not supported') end
		local it = makeItem(res, u)
		if PStash_Eng_GM_StoreAddItem(campPtr, EEex_UDToPtr(it)) % 256 == 0 then error('refused') end
	end)
	if not ok then print('[PSXGM] add ' .. res .. ': ' .. tostring(err)) return nil end
	return findEntry(campPtr, res)
end

-- A store the camp draws from: a merchant (not a container / bag, type 5) that sells (flag bit 0 "user can buy").
local function isMerchant(p)
	return EEex_ReadU32(p + STO_TYPE) ~= 5 and EEex_BAnd(EEex_ReadU32(p + STO_FLAGS), 1) ~= 0
end

-- A store just opened joins the known ones.
local OURS = { PSXCAMP = true, PSXCHEST = true, PSXSEEN = true, PSTASH = true }
local markSeen -- the items seen log, below

-- A store just opened joins the known ones; what it sells is seen there.
local function discover(storePtr, storeRes)
	if OURS[storeRes] or not isMerchant(storePtr) then return false end
	if not G.known[storeRes] then log('known store + %s', storeRes) end
	G.known[storeRes] = true
	for _, it in ipairs(storeEntries(storePtr)) do
		if it.res ~= '' and (EEex_BAnd(it.inf, 1) ~= 0 or it.stock > 0) then markSeen(it.res, 1, storeRes) end
	end
	return true
end
G.discover = discover

-- { [res] = { inf, total, sources = { { store, stock, inf, markup, name }, ... } cheapest first } } from the known
-- stores' current contents (critical / quest items left out); withStash: the Party Stash too, as a free source
-- (markup 0, quest items included: they are the party's own).
G.storeNames = G.storeNames or {}
local function aggregate(withStash)
	local out, names = {}, {}
	for sres in pairs(G.known) do names[#names + 1] = sres end
	table.sort(names)
	for _, sres in ipairs(names) do
		withStore(sres, function(p)
			if not isMerchant(p) then return end
			local markup = EEex_ReadU32(p + STO_SELL)
			local strref = EEex_ReadU32(p + 0x0C)
			local name = (strref ~= 0xFFFFFFFF and Infinity_FetchString(strref)) or sres
			G.storeNames[sres] = name
			for _, it in ipairs(storeEntries(p)) do
				local inf = EEex_BAnd(it.inf, 1) ~= 0
				local info = it.res ~= '' and itemInfo(it.res)
				if info and (inf or it.stock > 0) then markSeen(it.res, 1, sres, true) end
				if info and not excluded(info, it.res) and (inf or it.stock > 0) then
					local a = out[it.res]
					if not a then a = { total = 0, inf = false, sources = {}, u = it.u } out[it.res] = a end
					a.sources[#a.sources + 1] = { store = sres, stock = it.stock, inf = inf, markup = markup, name = name }
					if inf then a.inf = true else a.total = a.total + it.stock end
				end
			end
		end)
	end
	if withStash and PStash_List then
		for _, e in ipairs(PStash_List('PSTASH')) do
			if e.res ~= '' and e.count > 0 and itemInfo(e.res) then
				local a = out[e.res]
				if not a then a = { total = 0, inf = false, sources = {}, u = { e.uses, 0, 0 }, unid = true } out[e.res] = a end
				local s = nil
				for _, x in ipairs(a.sources) do if x.stash then s = x end end
				if not s then
					s = { store = 'PSTASH', stock = 0, inf = false, markup = 0, name = T('gm_stash'), stash = true }
					a.sources[#a.sources + 1] = s
				end
				s.stock = s.stock + e.count
				a.total = a.total + e.count
				a.stash = (a.stash or 0) + e.count
				if e.identified then a.unid = nil end
			end
		end
	end
	for _, a in pairs(out) do
		table.sort(a.sources, function(x, y)
			if x.markup ~= y.markup then return x.markup < y.markup end
			return x.store < y.store
		end)
	end
	return out
end
G.aggregate = aggregate

-- The camp store's own markup: 300 %, so the vanilla view is never a cheaper way to buy (the page switches it to the
-- source store's while buying). Forced at each opening: a save keeps the camp store it was made with.
G.CAMP_MARKUP = 300

-- The camp store gets exactly the aggregated stock: missing items added, gone ones emptied, then compressed
-- (CStore::CompressItems drops the entries with no stock that are not unlimited).
local function syncCamp(campPtr, withStash)
	EEex_Write32(campPtr + STO_SELL, G.CAMP_MARKUP)
	local agg = aggregate(withStash)
	G.agg = agg
	for _, e in ipairs(storeEntries(campPtr)) do
		if not agg[e.res] then
			EEex_Write32(e.ptr + FI_STOCK, 0)
			EEex_Write32(e.ptr + FI_INF, 0)
		end
	end
	local n = 0
	for res, a in pairs(agg) do
		local e = findEntry(campPtr, res) or addToCamp(campPtr, res, a.u)
		if e then
			local info = itemInfo(res)
			-- identified, as at a store; the stash's own unidentified items stay so
			local fl = EEex_ReadU32(e.ptr + FI_FLAGS)
			EEex_Write32(e.ptr + FI_FLAGS, a.unid and (fl - EEex_BAnd(fl, 1)) or EEex_BOr(fl, 1))
			EEex_Write32(e.ptr + FI_INF, a.inf and 1 or 0)
			EEex_Write32(e.ptr + FI_STOCK, a.inf and math.max(1, info and info.stack or 1) or a.total)
			n = n + 1
		end
	end
	if fileReady() then PStash_Eng_GM_StoreCompress(campPtr) end
	G.dirty = true
	log('camp: %d items from the known stores', n)
	return n
end
G.syncCamp = syncCamp

-- `n` copies of `res` bought at the camp leave store `s` (and the aggregate `a`).
local function takeFrom(s, res, n, a)
	withStore(s.store, function(p)
		local left = n
		for _, it in ipairs(storeEntries(p)) do
			if left <= 0 then break end
			if it.res == res and EEex_BAnd(it.inf, 1) == 0 and it.stock > 0 then
				local k = math.min(left, it.stock)
				EEex_Write32(it.ptr + FI_STOCK, it.stock - k)
				left = left - k
			end
		end
		if fileReady() then PStash_Eng_GM_StoreCompress(p) end
	end)
	s.stock = math.max(0, s.stock - n)
	a.total = math.max(0, a.total - n)
	if s.stash and PStash then -- the stash page reads its list again
		PStash.list, PStash.dirty = nil, true
		a.stash = math.max(0, (a.stash or 0) - n)
	end
end
G.takeFrom = takeFrom

-- Copies that left the camp store some other way (bought in the vanilla view) leave their stores too, cheapest
-- first: the camp never sells more than the stores hold. Run by the tick while the camp is open.
local function reconcileCamp(campPtr)
	if not G.agg then return end
	local have = {}
	for _, e in ipairs(storeEntries(campPtr)) do have[e.res] = (have[e.res] or 0) + e.stock end
	for res, a in pairs(G.agg) do
		if not a.inf and (have[res] or 0) < a.total then
			local gone = a.total - (have[res] or 0)
			for _, s in ipairs(a.sources) do
				if gone <= 0 then break end
				if not s.inf and s.stock > 0 then
					local k = math.min(gone, s.stock)
					takeFrom(s, res, k, a)
					gone = gone - k
				end
			end
			G.dirty = true
			log('camp: %s bought outside the page, taken from its stores', res)
		end
	end
end

-----------------------
-- Items seen         --
-----------------------
-- The camp chest shows every item of the game; those the party has seen say how and where, last (John 2026-10-23).
-- The log lives in the save: the hidden bag PSXSEEN, one entry per item (STO item layout): the 8 bytes from +0x08
-- (expiry + 3 usages) hold the place's resref (an area, or the store that sold it), the stock holds the ways:
-- low 4 bits the last one (1 for sale, 2 carried, 3 on the ground, 4 in a container), then a bit per way seen
-- (* 16). Never 0, so CStore::CompressItems keeps the entry.
G.seen = G.seen or nil      -- [res] = { way, place, ways }
G.seenDirty = G.seenDirty or {}

local function loadSeen()
	G.seen = {}
	withStore(G.SEEN, function(p)
		for _, it in ipairs(storeEntries(p)) do
			G.seen[it.res] = { way = it.stock % 16, ways = math.floor(it.stock / 16), place = readRes(it.ptr + 0x08) }
		end
	end)
end

-- keepPlace: an item already seen this way keeps the place it was first seen at (carried, for sale in the save's
-- stores when the camp opens); otherwise the last sighting wins.
markSeen = function(res, way, place, keepPlace)
	if not G.seen then loadSeen() end
	res = string.upper(res)
	local bit = math.floor(2 ^ (way - 1))
	local s = G.seen[res]
	if not s then
		G.seen[res] = { way = way, place = place or '', ways = bit }
		G.seenDirty[res] = true
		return
	end
	local had = EEex_BAnd(s.ways, bit) ~= 0
	if not had then s.ways = s.ways + bit end
	if not (keepPlace and had) and (s.way ~= way or s.place ~= (place or '')) then
		s.way, s.place = way, place or ''
		G.seenDirty[res] = true
	elseif not had then
		G.seenDirty[res] = true
	end
end
G.markSeen = markSeen

local function writePlace(ptr, place)
	for i = 0, 7 do EEex_WriteU8(ptr + 0x08 + i, i < #place and string.byte(place, i + 1) or 0) end
end

local function flushSeen()
	if not next(G.seenDirty) then return end
	local dirty = G.seenDirty
	G.seenDirty = {}
	withStore(G.SEEN, function(p)
		local have = {}
		for _, it in ipairs(storeEntries(p)) do have[it.res] = it end
		for res in pairs(dirty) do
			local s = G.seen[res]
			local e = have[res] or addToCamp(p, res, { 0, 0, 0 })
			if s and e then
				writePlace(e.ptr, s.place)
				EEex_Write32(e.ptr + FI_STOCK, s.way + 16 * s.ways)
				EEex_Write32(e.ptr + FI_INF, 0)
			end
		end
	end)
end
G.flushSeen = flushSeen

local function areaRes()
	local ok, res = pcall(function() return EEex_Sprite_GetInPortrait(0).m_pArea.m_resref:get() end)
	return ok and res and string.upper(res) or ''
end

-- World tick (every 2 s): what the party carries (backpacks, worn, the stash), what the game's loot lists show
-- (the ground near the party, the container open).
local function scanSeen()
	local area = areaRes()
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			local items = sp.m_equipment.m_items
			for slot = 0, 38 do
				local ok, it = pcall(function() return items:get(slot) end)
				if ok and it then markSeen(it.pRes.resref:get(), 2, area, true) end
			end
		end
	end
	if PStash_List then
		for _, e in ipairs(PStash_List('PSTASH')) do markSeen(e.res, 2, area, true) end
	end
	if type(loot) == 'table' then
		for way, list in pairs({ [3] = loot.groundItems, [4] = loot.containerItems }) do
			for _, g in ipairs(type(list) == 'table' and list or {}) do
				local r = g.item and g.item.res
				if type(r) == 'string' and r ~= '' then markSeen(r, way, area) end
			end
		end
	end
	flushSeen()
end
G.scanSeen = scanSeen

-- "Where": an area's readable name (PSXGM_PLACES from M_PSXCAT.lua: the outer area, and the building for an inner
-- one; else the world map caption of it or of its "xx00" area), or a store as "place: store name".
local function areaName(area)
	if not area or area == '' then return nil end
	local areas = PSXGM_AREAS or {}
	return (PSXGM_PLACES or {})[area] or areas[area] or areas[string.sub(area, 1, 4) .. '00']
end
local function placeName(place)
	if not place or place == '' then return '?' end
	local store = G.storeNames[place]
	if store then
		local at = areaName((PSXGM_STOREAT or {})[place])
		return at and T('gm_at', at, store) or store
	end
	return areaName(place) or place
end
local function seenText(res)
	local s = G.seen and G.seen[res]
	if not s then return T('gm_never_seen') end
	return T('gm_seen_' .. s.way, placeName(s.place))
end
G.seenText = seenText

-----------------------
-- Stores before the install: the loaded save's BALDUR.SAV
-----------------------

local function writeCStr(addr, s)
	for i = 1, #s do EEex_WriteU8(addr + i - 1, string.byte(s, i)) end
	EEex_WriteU8(addr + #s, 0)
end
local function readCStr(addr, max)
	local out = {}
	for i = 0, (max or 1024) - 1 do
		local b = EEex_ReadU8(addr + i)
		if b == 0 then break end
		out[#out + 1] = string.char(b)
	end
	return table.concat(out)
end
-- UTF-8 -> NUL-terminated UTF-16LE at addr.
local function writeWStr(addr, s)
	local o, i, n = addr, 1, #s
	local function put(u) EEex_WriteU16(o, u) o = o + 2 end
	while i <= n do
		local c = string.byte(s, i)
		local cp, len
		if c < 0x80 then cp, len = c, 1
		elseif c < 0xE0 then cp, len = c % 0x20, 2
		elseif c < 0xF0 then cp, len = c % 0x10, 3
		else cp, len = c % 0x08, 4 end
		for k = 1, len - 1 do cp = cp * 64 + (string.byte(s, i + k) or 0x80) % 64 end
		if cp >= 0x10000 then
			cp = cp - 0x10000
			put(0xD800 + math.floor(cp / 1024)) put(0xDC00 + cp % 1024)
		else put(cp) end
		i = i + len
	end
	put(0)
end

-- Store resrefs held by the save file at `alias` ("home:/save/<name>/BALDUR.SAV"); nil when it cannot be read.
-- Entries: u32 name length, name, u32 size, u32 compressed size, zlib data: only the names are read.
local function savStores(alias)
	if not fileReady() then return nil end
	local buf = EEex_Malloc(0x1000)
	local out
	local ok, err = pcall(function()
		writeCStr(buf, alias)
		local path = readCStr(PStash_Eng_GM_ResolveFileName(buf), 1024)
		writeWStr(buf, path)
		writeWStr(buf + 0x900, 'rb')
		local f = PStash_Eng_GM_wfopen(buf, buf + 0x900)
		if f == 0 then return end
		local function read(n)
			if n > 0x800 or PStash_Eng_GM_fread(buf + 0x800, 1, n, f) ~= n then return nil end
			local s = {}
			for i = 0, n - 1 do s[#s + 1] = string.char(EEex_ReadU8(buf + 0x800 + i)) end
			return table.concat(s)
		end
		local function u32at(s, i)
			local a, b, c, d = string.byte(s, i, i + 3)
			return a + b * 256 + c * 65536 + d * 16777216
		end
		if read(8) == 'SAV V1.0' then
			out = {}
			while true do
				local h = read(4)
				if not h then break end
				local nl = u32at(h, 1)
				local name = nl > 0 and read(nl)
				local sz = name and read(8)
				if not sz then break end
				local stem = string.upper(name:gsub('%z.*$', '')):match('^(.-)%.STO$')
				if stem then out[#out + 1] = stem end
				if PStash_Eng_GM_fseek(f, u32at(sz, 5), 1) ~= 0 then break end -- SEEK_CUR past the data
			end
		end
		PStash_Eng_GM_fclose(f)
	end)
	EEex_Free(buf)
	if not ok then print('[PSXGM] save read: ' .. tostring(err)) return nil end
	return out
end
G.savStores = savStores

-- The loaded save's BALDUR.SAV ("home:/<save dir>/<save name>/BALDUR.SAV") as store resrefs, or nil.
-- The folder follows the campaign (BGEE: SoD saves in sodsave/, BP in bpsave/; the same save name can be in both).
local CAMPAIGN_DIR = { SOD = 'sodsave', BP = 'bpsave' }
local function loadedSaveStores()
	local game = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
	local name = game.m_sSaveGame.m_pchData:get()
	if not name or name == '' then return nil end
	local ok, camp = pcall(function() return game.m_sCurrentCampaign.m_pchData:get() end)
	local dir = CAMPAIGN_DIR[ok and string.upper(camp or '') or ''] or 'save'
	for _, dir in ipairs({ dir, 'mp' .. dir }) do
		local out = savStores('home:/' .. dir .. '/' .. name .. '/BALDUR.SAV')
		if out then return out, dir .. '/' .. name end
	end
end
G.loadedSaveStores = loadedSaveStores

-- The stores held by the loaded save join the known ones (read after each load: the save holds every store the party
-- opened, so nothing else needs to be kept).
function PSXGM_Rescan()
	local stores, where = loadedSaveStores()
	if not stores then log('the loaded save could not be read') return 0 end
	for _, res in ipairs(stores) do
		if res ~= G.CAMP and res ~= 'PSTASH' then G.known[res] = true end
	end
	log('%s: %d stores', where, #stores)
	return #stores
end

-----------------------
-- Categories         --
-----------------------

local function types(...)
	local s = {}
	for _, t in ipairs({ ... }) do s[t] = true end
	return function(info) return s[info.type] == true end
end
-- Large swords (20) split by proficiency (BG EE: 89 bastard, 90 long, 93 two-handed, 94 katana, 95 scimitar).
local function sword(profs, extra)
	local p = {}
	for _, v in ipairs(profs) do p[v] = true end
	return function(info) return (info.type == 20 and p[info.prof] == true) or (extra and info.type == extra) end
end
local function armorAnim(pred) return function(info) return info.type == 2 and pred(info.anim) end end

G.TREE = {
	{ key = 'all', label = 'gm_all' },
	{ key = 'weap', label = 'gm_weapons', children = {
		{ key = 'w_bow', label = 'gm_bows', match = types(15) },
		{ key = 'w_xbow', label = 'gm_crossbows', match = types(27) },
		{ key = 'w_sling', label = 'gm_slings', match = types(18) },
		{ key = 'w_dagger', label = 'gm_daggers', match = types(16) },
		{ key = 'w_short', label = 'gm_short_swords', match = types(19) },
		{ key = 'w_long', label = 'gm_long_swords', match = function(i) return i.type == 20 and not (i.prof == 89 or i.prof == 93 or i.prof == 94 or i.prof == 95) end },
		{ key = 'w_bastard', label = 'gm_bastard_swords', match = sword({ 89 }, 69) },
		{ key = 'w_2h', label = 'gm_two_handed', match = sword({ 93 }, 57) },
		{ key = 'w_katana', label = 'gm_katanas', match = sword({ 94 }) },
		{ key = 'w_scim', label = 'gm_scimitars', match = sword({ 95 }) },
		{ key = 'w_axe', label = 'gm_axes', match = types(25) },
		{ key = 'w_mace', label = 'gm_maces', match = types(17) },
		{ key = 'w_hammer', label = 'gm_hammers', match = types(21) },
		{ key = 'w_flail', label = 'gm_flails', match = types(22, 23) },
		{ key = 'w_club', label = 'gm_clubs', match = types(44) },
		{ key = 'w_staff', label = 'gm_staves', match = types(26) },
		{ key = 'w_spear', label = 'gm_spears', match = types(29) },
		{ key = 'w_halb', label = 'gm_halberds', match = types(30) },
		{ key = 'w_fist', label = 'gm_fists', match = types(28) },
	} },
	{ key = 'arm', label = 'gm_armor', children = {
		{ key = 'a_robe', label = 'gm_robes', match = armorAnim(function(a) return a:sub(2, 2) == 'W' end) },
		{ key = 'a_leather', label = 'gm_leather', match = armorAnim(function(a) return a == '2A' end) },
		{ key = 'a_mail', label = 'gm_mail', match = armorAnim(function(a) return a == '3A' end) },
		{ key = 'a_plate', label = 'gm_plate', match = armorAnim(function(a) return a == '4A' end) },
		{ key = 'a_other', label = 'gm_other_armor', match = function(i)
			return (i.type == 2 and not (i.anim:sub(2, 2) == 'W' or i.anim == '2A' or i.anim == '3A' or i.anim == '4A'))
				or (i.type >= 60 and i.type <= 68) end },
		{ key = 'a_shield', label = 'gm_shields', match = types(12, 41, 47, 49, 53) },
		{ key = 'a_helm', label = 'gm_helmets', match = types(7, 72) },
		{ key = 'a_bracer', label = 'gm_bracers', match = types(6, 73) },
	} },
	{ key = 'equip', label = 'gm_equipment', children = {
		{ key = 'e_ring', label = 'gm_rings', match = types(10) },
		{ key = 'e_amulet', label = 'gm_amulets', match = types(1) },
		{ key = 'e_belt', label = 'gm_belts', match = types(3) },
		{ key = 'e_boots', label = 'gm_boots', match = types(4) },
		{ key = 'e_cloak', label = 'gm_cloaks', match = types(32) },
		{ key = 'e_wand', label = 'gm_wands', match = types(35) },
		{ key = 'e_bag', label = 'gm_bags', match = types(36) },
	} },
	{ key = 'pot', label = 'gm_potions', match = types(9) },
	{ key = 'scr', label = 'gm_scrolls', match = types(11) },
	{ key = 'gem', label = 'gm_gems', match = types(34) },
	{ key = 'ammo', label = 'gm_ammo', children = {
		{ key = 'm_arrow', label = 'gm_arrows', match = types(5) },
		{ key = 'm_bolt', label = 'gm_bolts', match = types(31) },
		{ key = 'm_bullet', label = 'gm_bullets', match = types(14) },
		{ key = 'm_dart', label = 'gm_darts', match = types(24) },
	} },
	{ key = 'misc', label = 'gm_misc' },
}

-- Leaves in tree order: { node, parent, order }.
G.leaves, G.nodes = {}, {}
do
	local order = 0
	for ti, top in ipairs(G.TREE) do
		G.nodes[top.key] = top
		top.index = ti
		if top.match then order = order + 1 G.leaves[#G.leaves + 1] = { node = top, parent = top, order = order } end
		for _, c in ipairs(top.children or {}) do
			order = order + 1
			c.parent = top
			G.nodes[c.key] = c
			G.leaves[#G.leaves + 1] = { node = c, parent = top, order = order }
		end
	end
end

-- The leaf an item belongs to (nil = Misc), cached per resref.
G.leafOf = G.leafOf or {}
local function leafOf(info, res)
	local l = G.leafOf[res]
	if l ~= nil then return l or nil end
	for _, lf in ipairs(G.leaves) do
		if lf.node.match(info) then G.leafOf[res] = lf return lf end
	end
	G.leafOf[res] = false
end

local function inCategory(key, info, res)
	if key == 'all' then return true end
	local lf = leafOf(info, res)
	if key == 'misc' then return lf == nil end
	if not lf then return false end
	return lf.node.key == key or lf.parent.key == key
end

-- Tree rows for the list: top nodes, the expanded one's children indented.
-- The menu's own globals (list table, list row, search text) have short names, no '_' and no shared start, like the
-- game's (storeItemsVar, currentItem): with table "PSXGM.treeRows" / var PSXGM_treeVar / var PSXGM_search the engine
-- wrote the clicked row into the wrong global (PSXGM, then the search field; John 2026-10-23). The list reads
-- gmTreeList, the same table as G.treeRows.
G.treeRows = G.treeRows or {}
gmTreeList = G.treeRows
local function buildTree()
	local rows = {}
	for _, top in ipairs(G.TREE) do
		local mark = top.children and (G.expanded[top.key] and '- ' or '+ ') or '  '
		rows[#rows + 1] = { key = top.key, text = mark .. T(top.label), depth = 0 }
		if top.children and G.expanded[top.key] then
			for _, c in ipairs(top.children) do rows[#rows + 1] = { key = c.key, text = '      ' .. T(c.label), depth = 1 } end
		end
	end
	-- refilled in place: the menu's list keeps the table it was given
	for i = #G.treeRows, 1, -1 do G.treeRows[i] = nil end
	for i, r in ipairs(rows) do G.treeRows[i] = r end
end
buildTree()
gmTreeRow = gmTreeRow or 1

function PSXGM_TreeClick()
	local r = G.treeRows[gmTreeRow]
	if not r then return end
	local node = G.nodes[r.key]
	if node.children then
		local open = not (G.expanded[r.key] and G.cat == r.key)
		G.expanded = {}
		G.expanded[r.key] = open or nil
	end
	G.cat, G.page = r.key, 1
	buildTree()
	G.dirty = true
end
function PSXGM_TreeText(row)
	local r = G.treeRows[row]
	if not r then return '' end
	return r.text
end
function PSXGM_TreeSelected(row) local r = G.treeRows[row] return r ~= nil and r.key == G.cat end
-- The search field: back to the first page on each key (1 = the key is accepted).
function PSXGM_SearchEdit() G.page = 1 return 1 end

-----------------------
-- Usable by          --
-----------------------

-- ITM 0x1E "unusable by" bits (copy of M_PSTASH.lua's rules: class, race, alignment, kit, minimum stats).
local CLASS_BIT = { [1] = 0x40000, [2] = 0x800, [3] = 0x80, [4] = 0x400000, [5] = 0x40, [6] = 0x100000,
	[7] = 0x2000, [8] = 0x4000, [9] = 0x20000, [10] = 0x10000, [11] = 0x40000000, [12] = 0x200000, [13] = 0x80000,
	[14] = 0x100, [15] = 0x200, [16] = 0x1000, [17] = 0x8000, [18] = 0x400, [19] = 0x40000, [20] = 0x20000000,
	[21] = 0x40000000 }
local RACE_BIT = { [1] = 0x8000000, [2] = 0x800000, [3] = 0x2000000, [4] = 0x1000000, [5] = 0x4000000,
	[6] = 0x10000000, [7] = 0x80000000 }
G.kits = G.kits or {}
local function kitUnusable(kitId)
	if not kitId or kitId < 0x4000 then return nil end
	if G.kits[kitId] == nil then
		G.kits[kitId] = false
		pcall(function()
			local t = EEex_Resource_Load2DA('KITLIST')
			local u = tonumber(EEex_Resource_GetAt2DALabels(t, 'UNUSABLE', tostring(kitId - 0x4000)))
			if u then
				G.kits[kitId] = { math.floor(u / 0x1000000) % 256, math.floor(u / 0x10000) % 256,
					math.floor(u / 0x100) % 256, u % 256 }
			end
		end)
	end
	return G.kits[kitId] or nil
end

local function usableBy(sp, info)
	if not sp then return true end
	local ai, f = sp.m_typeAI, info.unusable
	local function has(bit) return bit ~= nil and EEex_BAnd(f, bit) ~= 0 end
	if has(CLASS_BIT[ai.m_Class]) or has(RACE_BIT[ai.m_Race]) then return false end
	local law, moral = math.floor(ai.m_Alignment / 16), ai.m_Alignment % 16
	if (law == 3 and has(0x1)) or (moral == 3 and has(0x2)) or (moral == 1 and has(0x4)) or (moral == 2 and has(0x8))
		or (law == 1 and has(0x10)) or (law == 2 and has(0x20)) then
		return false
	end
	local kit = kitUnusable(EEex_Sprite_GetStat(sp, 152))
	if kit and (EEex_BAnd(info.kit[1], kit[1]) ~= 0 or EEex_BAnd(info.kit[2], kit[2]) ~= 0
		or EEex_BAnd(info.kit[3], kit[3]) ~= 0 or EEex_BAnd(info.kit[4], kit[4]) ~= 0) then
		return false
	end
	local function st(n) return EEex_Sprite_GetStat(sp, n) end
	if st(36) < info.minStr or (st(36) == 18 and info.minStr == 18 and st(37) < info.minStrEx) then return false end
	return st(38) >= info.minInt and st(40) >= info.minDex and st(39) >= info.minWis and st(41) >= info.minCon
		and st(42) >= info.minCha
end
G.usableBy = usableBy

-- The buyer: the character chosen in the store screen (its portraits), not the one selected in the world
-- (EEex_Sprite_GetSelected stays on the world's: John 2026-10-23, the DPS order ignored the store's choice).
local function selectedSprite()
	local name = Infinity_GetSelectedCharacterName and Infinity_GetSelectedCharacterName()
	if name and name ~= '' then
		for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
			local sp = EEex_Sprite_GetInPortrait(p)
			if sp and sp:getName() == name then return sp end
		end
	end
	local ok, sp = pcall(EEex_Sprite_GetSelected)
	if ok and sp then return sp end
	return EEex_Sprite_GetInPortrait(0)
end

-----------------------
-- Grid view          --
-----------------------

-- Search folding: lower case and Latin accents dropped (UTF-8 U+00C0-U+00FF, Œ/œ), so "epee", "épée" and "Épée"
-- all find "Épée" (string.lower leaves non-ASCII letters alone).
local FOLD = {}
do
	local runs = { { 0x80, 0x85, 'a' }, { 0x86, 0x86, 'ae' }, { 0x87, 0x87, 'c' }, { 0x88, 0x8B, 'e' }, { 0x8C, 0x8F, 'i' },
		{ 0x90, 0x90, 'd' }, { 0x91, 0x91, 'n' }, { 0x92, 0x96, 'o' }, { 0x98, 0x98, 'o' }, { 0x99, 0x9C, 'u' },
		{ 0x9D, 0x9D, 'y' }, { 0x9F, 0x9F, 'ss' }, { 0xA0, 0xA5, 'a' }, { 0xA6, 0xA6, 'ae' }, { 0xA7, 0xA7, 'c' },
		{ 0xA8, 0xAB, 'e' }, { 0xAC, 0xAF, 'i' }, { 0xB1, 0xB1, 'n' }, { 0xB2, 0xB6, 'o' }, { 0xB8, 0xB8, 'o' },
		{ 0xB9, 0xBC, 'u' }, { 0xBD, 0xBD, 'y' }, { 0xBF, 0xBF, 'y' } }
	for _, r in ipairs(runs) do
		for b = r[1], r[2] do FOLD[string.char(0xC3, b)] = r[3] end
	end
	FOLD[string.char(0xC5, 0x92)], FOLD[string.char(0xC5, 0x93)] = 'oe', 'oe'
end
local function fold(s)
	s = tostring(s or ''):gsub('[\195\197][\128-\191]', function(c) return FOLD[c] end)
	return string.lower(s)
end
G.fold = fold

local function entryRes(en) return en and en.item and string.upper(en.item.res or '') or '' end
local function cleanLabel(s)
	s = tostring(s or '')
	if s:sub(1, 2) == '* ' then s = s:sub(3) end
	-- the engine's label ends with the stock: "Name<no-break space> (1)" (U+00A0 = bytes 194 160)
	s = s:gsub('%s*%(%d+%)%s*$', '')
	return (s:gsub('\194\160', ' '):gsub('%s+$', ''))
end
local function partyGold()
	local ok, g = pcall(function() return game:GetPartyGold() end)
	return ok and tonumber(g) or 0
end

-- What one copy costs from store `s`: the engine's price at the camp markup (reputation, charisma, charges
-- included), scaled to that store's markup.
local function unitPrice(c, s)
	return math.floor(c.value * s.markup / math.max(1, c.campMk) + 0.5)
end
G.unitPrice = unitPrice

local function campMarkup()
	local p = openStore()
	return p and EEex_ReadU32(p + STO_SELL) or 100
end

G.view = G.view or {}
G.wishV = G.wishV or 0
-- Campaign filters (John 2026-10-24): 1 BG, 2 SoD, 3 BG2, 4 ToB, 5 other (the Black Pits, elsewhere); all ticked
-- by default. An item shows when one of its origins (G.origins, its campaigns) is ticked.
-- 1 BG, 2 SoD, 3 BG2, 4 ToB, 5 Black Pits, 6 Black Pits II, 7 other (all ticked); [8] = carried only (off)
if not G.camps or #G.camps < 7 then G.camps = { true, true, true, true, true, true, true } end
-- [9] found (seen in this save), [10] not found yet: both ticked
if G.camps[9] == nil then G.camps[9], G.camps[10] = true, true end
G.campOf = G.campOf or {}
local function campKey()
	local k = ''
	for i = 1, 10 do k = k .. (G.camps[i] and '1' or '0') end
	return k
end
local function campOk(res, sources)
	if string.sub(campKey(), 1, 7) == '1111111' then return true end
	-- the stores it was seen at (the camp merchant): their campaign counts too
	for _, src in ipairs(sources or {}) do
		local at = src.store and (PSXGM_STOREAT or {})[string.upper(src.store)]
		if at and G.campaign and G.camps[G.campaign(at)] then return true end
	end
	local set = G.campOf[res]
	if not set then
		set = {}
		-- all the origins' campaigns (PSXGM_CAMPS, a bitmask: the list shown is cut at 12 lines), else the shown ones
		local mask = (PSXGM_CAMPS or {})[res]
		if mask then
			for i = 1, 7 do set[i] = math.floor(mask / 2 ^ i) % 2 == 1 end
		else
			local o = G.origins and G.origins(res) or { camp = {} }
			for i = 1, #o do set[o.camp[i]] = true end
			-- no origin known (a quest item outside the Codex, in the stash): every campaign keeps it
			if #o == 0 then set = { true, true, true, true, true, true, true } end
		end
		-- "Other" = no known campaign only (John 2026-10-24: an item of BG with one unknown origin is not "Other")
		for i = 1, 6 do if set[i] then set[7] = false break end end
		G.campOf[res] = set
	end
	for i = 1, 7 do
		if set[i] and G.camps[i] then return true end
	end
	return false
end
local function viewKey()
	local sp = selectedSprite()
	return table.concat({ tostring(store and store.storeItems), G.cat, gmFindText or '', tostring(G.usable),
		tostring(G.afford), G.sort, G.afford and partyGold() or 0,
		(G.usable or G.sort == 'auto') and sp and sp.m_id or 0, G.wishV, tostring(G.agg), G.mode, campKey() }, '|')
end

-- Auto (default, John 2026-10-23: the stash's Auto order): grouped by category in tree order (Misc last); weapons by
-- damage per round for the buyer (PStash_WeaponDps; those he cannot use last), armor by AC, equipment in body order
-- (head, cloak, amulet, rings, bracers, belt, boots), scrolls mage then priest by level, the rest by price;
-- quality (enchantment, magic, price) breaks the ties.
local BODY_ORDER = { [7] = 1, [72] = 1, [32] = 2, [1] = 3, [10] = 4, [6] = 5, [73] = 5, [3] = 6, [4] = 7 }
local function acOf(info)
	local e = info.equip
	if not e then return 0 end
	return (e.base and 10 - e.base or 0) + e.ac
end
local function scrollRank(info)
	local sp = info.spell or ''
	local lvl = tonumber(string.sub(sp, 5, 5)) or 9
	if string.sub(sp, 1, 4) == 'SPWI' then return lvl end
	if string.sub(sp, 1, 4) == 'SPPR' then return 10 + lvl end
	return sp ~= '' and 30 or 40
end
local function portraitOf(sp)
	if not sp then return nil end
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(p)
		if s and s.m_id == sp.m_id then return p end
	end
end
local function autoKeys(c, portrait)
	local info, lf = c.info, leafOf(c.info, c.res)
	c.topKey = lf and lf.parent.key or 'misc'
	c.top = lf and lf.parent.index or 99
	c.enchant, c.magic, c.ac = info.enchant, info.magical or info.enchant > 0, acOf(info)
	c.body = BODY_ORDER[info.type] or 9
	c.scroll = info.type == 11 and scrollRank(info) or 0
	if c.topKey == 'weap' and portrait and PStash_WeaponDps then
		local ok, d = pcall(PStash_WeaponDps, portrait, info)
		c.dps = ok and d or nil
	end
end
local function qualityLess(a, b)
	if a.enchant ~= b.enchant then return a.enchant > b.enchant end
	if a.magic ~= b.magic then return a.magic end
	if a.price ~= b.price then return a.price > b.price end
	return a.name < b.name
end
local function autoLess(a, b)
	if a.top ~= b.top then return a.top < b.top end
	local k = a.topKey
	if k == 'weap' then
		if (a.dps ~= nil) ~= (b.dps ~= nil) then return a.dps ~= nil end
		if a.dps and a.dps.score ~= b.dps.score then return a.dps.score > b.dps.score end
		return qualityLess(a, b)
	elseif k == 'arm' then
		if a.ac ~= b.ac then return a.ac > b.ac end
		return qualityLess(a, b)
	elseif k == 'equip' then
		if a.body ~= b.body then return a.body < b.body end
	elseif k == 'scr' then
		if a.scroll ~= b.scroll then return a.scroll < b.scroll end
	elseif k ~= 'pot' and k ~= 'gem' then -- ammo, misc: type then price
		if a.info.type ~= b.info.type then return a.info.type < b.info.type end
	end
	if a.price ~= b.price then return a.price > b.price end
	return a.name < b.name
end

-- What the search looks into besides the name (John 2026-10-23): the item's description, its category and
-- sub-category names, the names of the stores that sell it. Folded, cached per item (the stores are added per view).
G.findText = G.findText or {}
local function findText(info, res)
	local t = G.findText[res]
	if t then return t end
	local desc = ''
	for _, ref in ipairs({ info.idDesc, info.unidDesc }) do
		if ref and ref > 0 and ref < 0x7FFFFFFF then desc = Infinity_FetchString(ref) or '' break end
	end
	local lf = leafOf(info, res)
	local cats = lf and (T(lf.node.label) .. ' ' .. T(lf.parent.label)) or T('gm_misc')
	t = fold(desc .. ' ' .. cats)
	G.findText[res] = t
	return t
end
-- 2 = the name matches, 1 = something else matches (description, category, store), nil = no match.
local function findHit(q, name, info, res, sources)
	if q == '' then return 2 end
	if string.find(fold(name), q, 1, true) then return 2 end
	if string.find(findText(info, res), q, 1, true) then return 1 end
	for _, s in ipairs(sources) do
		if string.find(fold(s.name or ''), q, 1, true) or string.find(fold(s.store), q, 1, true) then return 1 end
	end
end

-- What the party carries (John 2026-10-24): G.carried[RES] = { eq = { names }, bag = { names } }; inventory slots
-- 18 to 33 = the pack, the others = equipped (worn, weapons, quiver, quick items).
local function scanCarried()
	local out = {}
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			local name = sp:getName()
			local items = sp.m_equipment.m_items
			for slot = 0, 38 do
				local ok, it = pcall(function() return items:get(slot) end)
				if ok and it then
					local res = string.upper(it.pRes.resref:get())
					local e = out[res] or { eq = {}, bag = {}, seen = {} }
					out[res] = e
					local key = (slot >= 18 and slot <= 33) and 'bag' or 'eq'
					if not e.seen[key .. name] then
						e.seen[key .. name] = true
						e[key][#e[key] + 1] = name
					end
				end
			end
		end
	end
	G.carried = out
end
local function carriedText(res)
	local e = G.carried and G.carried[res]
	if not e then return nil end
	local t = {}
	if #e.eq > 0 then t[#t + 1] = T('gm_equipped_by', table.concat(e.eq, ', ')) end
	if #e.bag > 0 then t[#t + 1] = T('gm_in_pack', table.concat(e.bag, ', ')) end
	return #t > 0 and table.concat(t, '\n') or nil
end
G.carriedText = carriedText

local function rebuild()
	scanCarried()
	local list = store and store.storeItems or {}
	local out, sp, gold, campMk = {}, selectedSprite(), partyGold(), campMarkup()
	local q = fold(gmFindText):gsub('^%s+', ''):gsub('%s+$', '')
	local shown = {}
	local function keep(c, info, res)
		c.hit = inCategory(G.cat, info, res) and findHit(q, c.name, info, res, c.sources)
		if c.hit
			and (not G.usable or usableBy(sp, info))
			and (not G.afford or (not c.catalog and c.price <= gold))
			and campOk(res, c.sources)
			and (not G.camps[8] or (G.carried and G.carried[res]))
			and ((G.seen and G.seen[res]) and G.camps[9] or (not (G.seen and G.seen[res]) and G.camps[10])) then
			local lf = leafOf(info, res)
			c.wish, c.order, c.usable = isWished(res), lf and lf.order or 999, usableBy(sp, info)
			out[#out + 1] = c
		end
	end
	for i, en in ipairs(list) do
		local res = entryRes(en)
		local info = res ~= '' and itemInfo(res)
		local a = G.agg and G.agg[res]
		if info and a and #a.sources > 0 and not shown[res] then
			shown[res] = true
			local name = cleanLabel(en.label)
			local c = { en = en, row = i, res = res, info = info, name = name, value = tonumber(en.value) or 0,
				campMk = campMk, sources = a.sources, inf = a.inf, total = a.total, icon = en.item.icon,
				stash = a.stash }
			c.price = unitPrice(c, a.sources[1])
			local src = a.sources[1]
			c.from = src.name and src.name ~= '' and src.name or nil
			keep(c, info, res)
		end
	end
	-- the camp chest: every other item of the game (M_PSXCAT.lua) and anything seen that is not in that list,
	-- greyed, with where it was seen (John 2026-10-23: all shown, mixed with what can be taken or bought)
	if G.mode == 'chest' then
		local function catalog(res)
			if shown[res] then return end
			shown[res] = true
			local info = itemInfo(res)
			if not info or info.icon == '' then return end
			local name = Infinity_FetchString(info.idName)
			if not name or name == '' then name = Infinity_FetchString(info.unidName) or res end
			local c = { res = res, info = info, name = name, value = info.price, campMk = 100, sources = {},
				inf = false, total = 0, icon = info.icon, catalog = true, price = info.price, row = 100000 }
			keep(c, info, res)
		end
		for _, res in ipairs(PSXGM_ALL or {}) do catalog(res) end
		for res in pairs(G.seen or {}) do catalog(res) end
	end
	local mode = G.sort
	if mode == 'auto' then
		local portrait = portraitOf(sp)
		for _, c in ipairs(out) do autoKeys(c, portrait) end
	end
	table.sort(out, function(a, b)
		if a.wish ~= b.wish then return a.wish end
		if a.hit ~= b.hit then return a.hit > b.hit end -- searching: name matches first
		if mode == 'auto' then return autoLess(a, b) end
		if mode == 'price' then
			if a.price ~= b.price then return a.price > b.price end
		elseif mode == 'type' then
			if a.order ~= b.order then return a.order < b.order end
			if a.price ~= b.price then return a.price > b.price end
		end
		if a.name ~= b.name then return a.name < b.name end
		return a.row < b.row
	end)
	G.view = out
	G.pages = math.max(1, math.ceil(#out / (G.COLS * G.ROWS)))
	G.page = math.max(1, math.min(G.page, G.pages))
	G.key = viewKey()
	G.dirty = false
end

local function view()
	if G.dirty or G.key ~= viewKey() then rebuild() end
	return G.view
end

local function cell(i)
	return view()[(G.page - 1) * G.COLS * G.ROWS + i + 1]
end
G.cell = cell

local function selected()
	if not G.sel then return nil end
	for _, c in ipairs(view()) do if c.res == G.sel then return c end end
end

function PSXGM_CellIcon(i) local c = cell(i) return c and c.icon or nil end
-- Bottom right of the cell: how many are left (nothing when unlimited, nothing for the chest's catalog).
function PSXGM_CellCount(i)
	local c = cell(i)
	if not c or c.inf or c.catalog then return nil end
	return c.total
end
-- Catalog items (camp chest): greyed; never seen: darkened too.
function PSXGM_CellTint(i)
	local c = cell(i)
	if not c then return nil end
	if c.res == G.sel then return 'PSTASHOR' end
	if c.catalog then return (G.seen and G.seen[c.res]) and nil or 'PSTASHDK' end
	return c.en.item.tint
end
function PSXGM_CellGrey(i) local c = cell(i) return c ~= nil and (c.catalog or not c.usable) end
function PSXGM_CellWished(i) local c = cell(i) return c ~= nil and c.wish end
-- What the item is here: price and stock (and how many in the stash), or for the catalog its value and where seen.
-- Where the item comes from at the start of the game (PSXGM_FROM, M_PSXCAT.lua; John 2026-10-23): text lines.
G.fromCache = G.fromCache or {}
-- The campaign an area belongs to (John 2026-10-24: the origins grouped BG, SoD, BG2, ToB): 1 BG, 2 SoD, 3 SoA,
-- 4 ToB, 5 the Black Pits (BGEE: OH1000-OH3999, OH93xx), 6 the Black Pits II (BG2EE: the other OH), 7 elsewhere. AR is BG1 on BGEE, BG2 elsewhere (PSXGM_GAME, M_PSXCAT.lua).
local function campaign(area)
	-- an origin without an area carries its campaign ("#2", build_gm_catalog.py camp_of)
	local c = tonumber(string.match(area or '', '^#(%d)$'))
	if c then return c end
	local pre, num = string.match(area or '', '^(%a%a)(%d%d%d%d)')
	if not pre then return 7 end
	pre, num = string.upper(pre), tonumber(num)
	if pre == 'BG' then return 1 end
	if pre == 'BD' then return 2 end
	if pre == 'BP' then return 5 end
	if pre == 'OH' then return (num < 4000 or (num >= 9300 and num < 9400)) and 5 or 6 end
	if pre == 'AR' then
		if PSXGM_GAME == 'bgee' then return 1 end
		return num >= 4000 and 4 or 3
	end
	return 7
end
G.campaign = campaign
-- Text lines, sorted by campaign (o.camp[i] = its campaign), then sold, container, ground, given, carried, carried
-- by a creature that appears, random treasure.
local KIND_RANK = { S = 1, C = 2, G = 3, D = 4, K = 5, P = 6, T = 7 }
local function origins(res)
	local o = G.fromCache[res]
	if o then return o end
	local list, dup = {}, {}
	for entry in string.gmatch((PSXGM_FROM or {})[res] or '', '[^|]+') do
		local kind, name, area = string.match(entry, '^(%a)~([^~]*)~(.*)$')
		local text
		-- S: name~its area; C: its container type~area (John 2026-10-24: place first, readable names)
		if kind == 'S' then
			local at = areaName(area)
			text = at and T('gm_from_S2', at, name) or T('gm_from_S', name)
		-- an area without a readable name shows no place (never a code)
		elseif kind == 'K' then
			local at = areaName(area)
			text = at and T('gm_from_K', name, at) or T('gm_from_K0', name)
		elseif kind == 'G' then
			local at = areaName(area)
			text = at and T('gm_from_G', at) or T('gm_from_G0')
		elseif kind == 'C' then
			local key = 'gm_ctype_' .. name
			local word = T(key)
			if word == key then word = T('gm_ctype') end
			local at = areaName(area)
			text = at and T('gm_from_C', at, word) or T('gm_from_C0', word)
		-- D: given by a dialogue or a script (its speaker or creature, its area); P: a creature that appears
		elseif kind == 'D' then
			local at = areaName(area)
			if name ~= '' then text = at and T('gm_from_D', name, at) or T('gm_from_D1', name)
			else text = at and T('gm_from_D2', at) or T('gm_from_D0') end
		elseif kind == 'P' then
			local at = areaName(area)
			text = at and T('gm_from_P', name, at) or T('gm_from_P0', name)
		elseif kind == 'T' then
			text = T('gm_from_T')
		end
		-- several entries can read the same (creatures sharing a name, areas sharing a place)
		if text and not dup[text] then
			dup[text] = true
			list[#list + 1] = { text = text, camp = campaign(area), rank = KIND_RANK[kind] or 5, n = #list }
		end
	end
	table.sort(list, function(x, y)
		if x.camp ~= y.camp then return x.camp < y.camp end
		if x.rank ~= y.rank then return x.rank < y.rank end
		return x.n < y.n
	end)
	o = { camp = {} }
	for i, e in ipairs(list) do o[i], o.camp[i] = e.text, e.camp end
	G.fromCache[res] = o
	return o
end
G.origins = origins
-- The first origin, and how many more ("+2").
local function firstOrigin(res)
	local o = origins(res)
	if #o == 0 then return nil end
	return o[1] .. (#o > 1 and ('  ' .. T('gm_more', #o - 1)) or '')
end

-- The card and the tooltip (tip): the catalog's value and where seen, or price / stock (stash, store); the first
-- origin on the catalog's card and in every tooltip.
local function infoLines(c, tip)
	local s
	if c.catalog then
		s = T('gm_value', c.price) .. '\n' .. seenText(c.res)
	else
		s = T('gm_price', c.price) .. '  ' .. (c.inf and T('gm_unlimited') or T('gm_stock', c.total))
		if c.stash and c.stash > 0 then s = s .. '\n' .. T('gm_in_stash', c.stash) end
		if c.from and not (c.sources[1] and c.sources[1].stash) then s = s .. '\n' .. T('gm_from', c.from) end
	end
	if c.catalog or tip then
		local f = firstOrigin(c.res)
		if f then s = s .. '\n' .. f end
	end
	return s
end
G.infoLines = infoLines
function PSXGM_CellTip(i)
	local c = cell(i)
	if not c then return '' end
	local cr = carriedText(c.res)
	local s = c.name .. '\n' .. (cr and (cr .. '\n') or '') .. infoLines(c, true)
	if c.wish then s = s .. '\n* ' .. T('gm_wished') end
	return s
end
function PSXGM_CellClick(i)
	local c = cell(i)
	if not c then return end
	if ctrlDown() then
		toggleWish(c.res)
		G.wishV = G.wishV + 1
		return
	end
	if G.sel ~= c.res then G.qty = 1 end
	G.sel, G.msg = c.res, ''
end
-- The description window (right click), made from the ITM as the stash does: the item's text, then where it was
-- seen and every origin.
local function describe(c)
	if not c then return end
	local ref = c.info.idDesc
	if not ref or ref <= 0 or ref >= 0x7FFFFFFF then ref = c.info.unidDesc end
	local lines = { seenText(c.res) }
	local cr = carriedText(c.res)
	if cr then table.insert(lines, 1, cr) end
	local o, last = origins(c.res), nil
	for i, text in ipairs(o) do
		-- a sub-title per campaign
		if o.camp[i] ~= last then
			last = o.camp[i]
			lines[#lines + 1] = T('gm_camp_' .. last) .. ':'
		end
		lines[#lines + 1] = '- ' .. text
	end
	local text = (Infinity_FetchString(ref) or '') .. '\n\n' .. T('gm_origin') .. '\n' .. table.concat(lines, '\n')
	showItemDescription({ name = c.name, description = text, descPicture = c.info.descPic, icon = c.icon }, 2)
end
function PSXGM_CellDesc(i) describe(cell(i)) end
function PSXGM_Wheel()
	local d = (scrollDirection or 0)
	if d == 0 then return end
	PSXGM_Page(d > 0 and -1 or 1)
end
function PSXGM_Page(d) view() G.page = math.max(1, math.min(G.pages or 1, G.page + d)) end
function PSXGM_PageText() view() return string.format('%d / %d', G.page, G.pages or 1) end
function PSXGM_CountText()
	local n = #view()
	if n == 0 and G.cat == 'all' and gmFindText == '' then return T('gm_empty') end
	return T('gm_items', n)
end
function PSXGM_CanPage(d)
	view()
	return (d < 0 and G.page > 1) or (d > 0 and G.page < (G.pages or 1))
end

function PSXGM_ToggleCamp(i) G.camps[i] = not G.camps[i] G.page = 1 end
function PSXGM_CampFrame(i) return G.camps[i] and 2 or 0 end
function PSXGM_CampText(i) return T('gm_cf_' .. i) end
function PSXGM_ToggleUsable() G.usable = not G.usable G.page = 1 end
function PSXGM_ToggleAfford() G.afford = not G.afford G.page = 1 end
function PSXGM_FilterText(which)
	return T(which == 'usable' and 'gm_usable' or 'gm_affordable')
end
-- ROUNDBUT frame: 2 = on, 0 = off.
function PSXGM_FilterFrame(which)
	local on = (which == 'usable' and G.usable) or (which == 'afford' and G.afford)
	return on and 2 or 0
end
local SORTS = { 'auto', 'type', 'price', 'name' }
function PSXGM_NextSort()
	for k, s in ipairs(SORTS) do
		if s == G.sort then G.sort = SORTS[k % #SORTS + 1] break end
	end
	G.page = 1
end
function PSXGM_SortText() return T('gm_sort', T('gm_sort_' .. G.sort)) end

-- Page background (John 2026-10-23): 1 = notice board assembled from pieces (PSXGMBA), 2 = the same redrawn by
-- SwarmUI (PSXGMBB, the default: John 2026-10-23). Kept in Baldur.lua (per player, not per save).
function PSXGM_Skin()
	-- the painted board only (John 2026-10-24: the swap button is gone)
	return 2
end
function PSXGM_NextSkin()
	G.skin = PSXGM_Skin() == 1 and 2 or 1
	pcall(Infinity_SetINIValue, 'Party Stash', 'Camp Merchant Board', G.skin)
end
function PSXGM_SkinText() return T('gm_skin', T('gm_skin_' .. PSXGM_Skin())) end

-- Selected item panel.
function PSXGM_SelIcon() local c = selected() return c and c.icon or nil end
function PSXGM_SelName() local c = selected() return c and c.name or T('gm_select') end
function PSXGM_SelInfo()
	local c = selected()
	if not c then return '' end
	return infoLines(c)
end
function PSXGM_SelDesc() describe(selected()) end
local function maxQty(c)
	if not c or c.catalog then return 1 end
	return c.inf and 99 or math.max(1, math.min(99, c.total))
end
-- The chest's button says "Take" for what comes from the stash (free), "Buy" otherwise.
function PSXGM_BuyText()
	local c = selected()
	if c and c.sources and c.sources[1] and c.sources[1].stash then return T('gm_take') end
	return T('gm_buy')
end
function PSXGM_Mode() return G.mode end
-- What `qty` copies cost: the cheapest stores' copies first.
local function costOf(c, qty)
	local left, cost = qty, 0
	for _, s in ipairs(c.sources) do
		if left <= 0 then break end
		local n = s.inf and left or math.min(left, s.stock)
		cost = cost + n * unitPrice(c, s)
		left = left - n
	end
	return cost
end
function PSXGM_Qty(d)
	local c = selected()
	G.qty = math.max(1, math.min(maxQty(c), (G.qty or 1) + d))
end
function PSXGM_QtyText() return tostring(G.qty or 1) end
function PSXGM_TotalText()
	local c = selected()
	if not c then return '' end
	return T('gm_total', costOf(c, G.qty or 1))
end
function PSXGM_GoldText() return T('gm_price', partyGold()) end
function PSXGM_MsgText() return G.msg or '' end

-- Party Stash's "sell marked" from the page (John: sell straight from the stash): the camp store buys them like the
-- vanilla panel's button would (M_PSTASH.lua's rules: 50 % at an unknown store, every type the STO buys).
function PSXGM_CanSellMarked()
	local ok, can = pcall(function() return PStash_CanSellMarked and PStash_CanSellMarked() end)
	return ok and can == true
end
function PSXGM_SellMarkedText()
	local ok, gold = pcall(function() return PStash_SellAmount and PStash_SellAmount() end)
	if not ok or not gold or gold == '' or not PSXGM_CanSellMarked() then return T('gm_sell_none') end
	return T('gm_sell_marked', gold)
end
function PSXGM_SellMarked()
	if not PSXGM_CanSellMarked() then return end
	local before = partyGold()
	local ok, err = pcall(PStash_SellMarked)
	if not ok then print('[PSXGM] sell marked: ' .. tostring(err)) end
	G.msg = T('gm_sold', partyGold() - before)
	G.dirty = true
end
function PSXGM_CanBuy()
	local c = selected()
	return c ~= nil and not c.catalog and costOf(c, G.qty or 1) <= partyGold()
end

-----------------------
-- Buying             --
-----------------------

local function rowOf(res)
	for i, en in ipairs(store and store.storeItems or {}) do
		if entryRes(en) == res then return i - 1, en end
	end
end

-- A free backpack slot on the character buying (the store screen's selected one).
local function freeSlot()
	local sp = selectedSprite()
	if not sp then return false end
	for i = 18, 32 do if not sp.m_equipment.m_items:get(i) then return true end end
	return false
end

local function clearSelection()
	for i, en in ipairs(store and store.storeItems or {}) do
		if en.highlight == 1 then storeScreen:SelectStoreItem(i - 1, false) end
	end
end

-- Buys `qty` of `res` through the engine (select + Buy), store by store, cheapest first: the camp markup is set to
-- that store's for its copies, and they are taken out of that store's stock.
function PSXGM_Buy(res, qty)
	local campPtr, campRes = openStore()
	if not campPtr or (campRes ~= G.CAMP and campRes ~= G.CHEST) then return 0 end
	res = string.upper(res or G.sel or '')
	qty = qty or G.qty or 1
	local a = G.agg and G.agg[res]
	if not a then G.msg = T('gm_cannot_buy') return 0 end
	local saved = EEex_ReadU32(campPtr + STO_SELL)
	local bought, why = 0, nil
	local ok, err = pcall(function()
		clearSelection()
		for _, s in ipairs(a.sources) do
			local avail = s.inf and math.huge or s.stock
			while bought < qty and avail > 0 and not why do
				local row, en = rowOf(res)
				if not row then why = T('gm_cannot_buy') break end
				local n = math.min(qty - bought, avail, math.max(1, tonumber(en.maxCount) or 1))
				EEex_Write32(campPtr + STO_SELL, s.markup)
				storeScreen:SelectStoreItem(row, true)
				if n > 1 then storeScreen:SetStoreItemCount(row, n) end
				if not storeScreen:IsBuyItemButtonClickable() then
					storeScreen:SelectStoreItem(row, false)
					if not freeSlot() then why = T('gm_full')
					elseif partyGold() < n * math.floor((tonumber(en.value) or 0) * s.markup / math.max(1, saved) + 0.5) then
						why = T('gm_no_gold')
					else why = T('gm_cannot_buy') end
					break
				end
				storeScreen:OnBuyItemButtonClick()
				bought, avail = bought + n, avail - n
				if not s.inf then takeFrom(s, res, n, a) end
			end
			if bought >= qty or why then break end
		end
	end)
	EEex_Write32(campPtr + STO_SELL, saved)
	pcall(function() storeScreen:UpdateBuySellPanel() end)
	if not ok then print('[PSXGM] buy error: ' .. tostring(err)) why = T('gm_cannot_buy') end
	local info = itemInfo(res)
	G.msg = why or T('gm_bought', info and info.idText or res, bought)
	if not a.inf and a.total <= 0 then G.sel = nil end
	G.dirty = true
	log('buy %s x%d -> %d (%s)', res, qty, bought, tostring(why))
	return bought
end
function PSXGM_BuySelected() if G.sel then PSXGM_Buy(G.sel, G.qty) end end

-----------------------
-- Page open / close  --
-----------------------

function PSXGM_Vanilla()
	G.vanilla = true
	if Infinity_IsMenuOnStack('PSXGM_PAGE') then Infinity_PopMenu('PSXGM_PAGE') end
end
function PSXGM_Back()
	G.vanilla = false
	pcall(function() storeScreen:UpdateBuySellPanel() end)
end
function PSXGM_Done()
	G.vanilla = false
	if Infinity_IsMenuOnStack('PSXGM_PAGE') then Infinity_PopMenu('PSXGM_PAGE') end
	pcall(function() storeScreen:OnMainDoneButtonClick() end)
end
function PSXGM_OnOpen()
	G.dirty, G.msg = true, ''
	-- the filters back to their defaults at every opening (John 2026-10-24): every campaign, found and not found
	-- ticked, Carried off
	G.camps = { true, true, true, true, true, true, true, false, true, true }
	gmFindText = gmFindText or ''
	G.findText = {}
	buildTree() -- in the installed language (M_PSXGT.lua loads after this file)
end
function PSXGM_ShowBack()
	return G.vanilla == true and atCamp() and onStack('STORE_BUYSELL')
end

-- No vanilla view any more (John 2026-10-24): the page stays while the camp store or the chest is open. Party
-- Stash's own "Sell Marked" menu (PSTASH_STORE, for the vanilla panel) is pushed after the page opens: the page is
-- pushed again over it once per visit, so only the page's own Sell marked ticket shows.
local function syncMenus()
	local p, res = openStore()
	local buysell = p ~= nil and onStack('STORE_BUYSELL')
	local want = buysell and (res == G.CAMP or res == G.CHEST)
	local shown = onStack('PSXGM_PAGE')
	if want and not shown then Infinity_PushMenu('PSXGM_PAGE') elseif shown and not want then Infinity_PopMenu('PSXGM_PAGE') end
	if want and shown and onStack('PSTASH_STORE') and G.overStash ~= p then
		G.overStash = p
		Infinity_PopMenu('PSXGM_PAGE')
		Infinity_PushMenu('PSXGM_PAGE')
	end
	if not want then G.overStash = nil end
	if onStack('PSXGM_BACK') then Infinity_PopMenu('PSXGM_BACK') end
end

-- Tick (PSXGM_TICK's enabled check, every frame; throttled).
function PSXGM_Tick()
	local now = Infinity_GetClockTicks()
	if G.next and now < G.next then return false end
	G.next = now + 100
	local p, res = openStore()
	if p then
		if p ~= G.visitPtr then
			G.visitPtr, G.visitRes, G.vanilla, G.sel = p, res, false, nil
			local ok, err = pcall(function()
				if res == G.CAMP or res == G.CHEST then
					-- the camp opens: its stock follows the known stores' current ones; the chest adds the stash
					G.mode = res == G.CHEST and 'chest' or 'camp'
					G.syncCamp(p, res == G.CHEST)
					storeScreen:UpdateBuySellPanel()
				elseif not storeScreen:IsContainer() then
					discover(p, res)
				end
			end)
			if not ok then print('[PSXGM] store error: ' .. tostring(err)) end
		elseif res == G.CAMP and (not G.nextRec or now >= G.nextRec) then
			G.nextRec = now + 500
			local ok, err = pcall(reconcileCamp, p)
			if not ok then print('[PSXGM] camp check error: ' .. tostring(err)) end
		end
	else
		G.visitPtr = nil
		-- after each load: the stores held by the save join the known ones
		if worldScreen ~= nil and e:GetActiveEngine() == worldScreen and G.scanFor ~= G.gameId then
			G.scanFor = G.gameId
			local ok, err = pcall(PSXGM_Rescan)
			if not ok then print('[PSXGM] save scan error: ' .. tostring(err)) end
		end
		-- the items seen log: what the party carries, the ground near it, the container open
		if worldScreen ~= nil and e:GetActiveEngine() == worldScreen and (not G.nextSeen or now >= G.nextSeen) then
			G.nextSeen = now + 2000
			local ok, err = pcall(scanSeen)
			if not ok then print('[PSXGM] seen log error: ' .. tostring(err)) end
		end
	end
	pcall(syncMenus)
	return false
end

-----------------------
-- Public API         --
-----------------------
-- For other mods (SadoQoL / SadoEE Withers: the recruit's gear screen, 2026-10-24). Outside the store screen: the
-- engine's store price (reputation, charisma) is not at hand, so one copy costs ITM price x the store's markup / 100.

-- What the camp merchant sells right now: { [RES] = { price = gp for one (cheapest store), stock = n or -1 } }.
-- Quest / critical items are left out, as on the page; the Party Stash is not part of it (PStash_List).
function PSXGM_Pool()
	local out = {}
	local ok, err = pcall(function()
		local agg = aggregate(false)
		for res, a in pairs(agg) do
			local info, s = itemInfo(res), a.sources[1]
			if info and s then
				out[res] = { price = math.floor(info.price * s.markup / 100 + 0.5), stock = a.inf and -1 or a.total }
			end
		end
	end)
	if not ok then print('[PSXGM] PSXGM_Pool: ' .. tostring(err)) end
	return out
end

-- Party gold through CInfGame +0x7988 (as M_PSTASH.lua's addGold, both builds): false when the field does not match.
local function payGold(n)
	local p = EEex_UDToPtr(EEex_EngineGlobal_CBaldurChitin.m_pObjectGame)
	local cur = game:GetPartyGold()
	if cur < n or EEex_ReadU32(p + 0x7988) ~= cur then return false end
	EEex_Write32(p + 0x7988, cur - n)
	if game:GetPartyGold() == cur - n then return true end
	EEex_Write32(p + 0x7988, cur)
	return false
end

-- Takes `n` copies of `res` out of the stores (cheapest first, as the page buys them) and charges the party gold.
-- Does NOT create the item: the caller does. Returns true, gp paid, or nil, reason ('not sold', 'stock', 'gold',
-- 'gold field'). Prices as PSXGM_Pool.
function PSXGM_PoolTake(res, n)
	res, n = string.upper(res or ''), math.max(1, n or 1)
	local agg = aggregate(false) -- fresh: the stores may have changed since PSXGM_Pool
	local a = agg[res]
	local info = itemInfo(res)
	if not a or not info or #a.sources == 0 then return nil, 'not sold' end
	if not a.inf and a.total < n then return nil, 'stock' end
	local plan, left, cost = {}, n, 0
	for _, s in ipairs(a.sources) do
		if left <= 0 then break end
		local k = s.inf and left or math.min(left, s.stock)
		if k > 0 then
			plan[#plan + 1] = { s = s, k = k }
			cost = cost + k * math.floor(info.price * s.markup / 100 + 0.5)
			left = left - k
		end
	end
	if left > 0 then return nil, 'stock' end
	if game:GetPartyGold() < cost then return nil, 'gold' end
	if not payGold(cost) then return nil, 'gold field' end
	for _, p in ipairs(plan) do
		if not p.s.inf then takeFrom(p.s, res, p.k, a) end
	end
	G.dirty = true
	return true, cost
end

-- The camp catalog from the known stores: { stores, items, infinite, units } (no listing: a long print crashed the game).
function PSXGM_Catalog()
	local agg = G.aggregate()
	local out = { stores = 0, items = 0, infinite = 0, units = 0 }
	for _ in pairs(G.known) do out.stores = out.stores + 1 end
	for _, a in pairs(agg) do
		out.items = out.items + 1
		if a.inf then out.infinite = out.infinite + 1 else out.units = out.units + a.total end
	end
	return out
end

-- The store screen rebuilds store.storeItems on each change: the tick menu is pushed from there too, so it runs at
-- a store even when it was not on the stack (the world screen pushes it otherwise).
local function pushTick()
	if Infinity_IsMenuOnStack('PSXGM_TICK') then return end
	local eng = e:GetActiveEngine()
	if (worldScreen ~= nil and eng == worldScreen) or (storeScreen ~= nil and eng == storeScreen) then
		Infinity_PushMenu('PSXGM_TICK')
	end
end
G.pushTick = pushTick

-- The page menu is PSXGM_PAGE, not PSXGM: the engine makes a global of each menu's name (a number), which
-- overwrote this module's table (John 2026-10-23: the tree and the search broke).

-- Chains onto the `store` proxy of M_PSXENG.lua (made first), or makes a plain one.
local function hookStoreTable()
	if type(store) ~= 'table' then return false end
	if PSXEng_HookStore then pcall(PSXEng_HookStore) end
	local mt = getmetatable(store)
	if mt and mt.__psxgm then return true end
	local function onWrite(k, v)
		if k == 'storeItems' then G.dirty = true pcall(pushTick) end
	end
	if mt and mt.__psx then
		local orig = mt.__newindex
		mt.__newindex = function(t, k, v) orig(t, k, v) onWrite(k, v) end
		mt.__psxgm = true
		return true
	end
	if mt then return false end
	local data = {}
	for k, v in pairs(store) do data[k] = v end
	for k in pairs(data) do store[k] = nil end
	setmetatable(store, {
		__psxgm = true,
		__index = data,
		__newindex = function(_, k, v) data[k] = v onWrite(k, v) end,
		__pairs = function() return next, data, nil end,
	})
	return true
end
G.hookStoreTable = hookStoreTable

if not G.pushWrapped then
	G.pushWrapped = true
	local push = Infinity_PushMenu
	Infinity_PushMenu = function(...)
		local m = ...
		local r = table.pack(push(...))
		if m ~= 'PSXGM_TICK' then pcall(pushTick) end
		-- the store panel opens: the page goes over it in the same frame (the throttled tick showed the game's
		-- store screen for a moment first, John 2026-10-24)
		if m == 'STORE_BUYSELL' then G.next = nil pcall(PSXGM_Tick) end
		return table.unpack(r, 1, r.n)
	end
end

if not G.listenersAdded then
	G.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function()
		EEex_Menu_LoadFile('PSXGM')
		G.hooked = hookStoreTable()
	end)
	EEex_Menu_AddAfterMainFileReloadedListener(function()
		G.hooked = hookStoreTable()
		pcall(pushTick)
	end)
	EEex_GameState_AddInitializedListener(function()
		G.gameId = (G.gameId or 0) + 1 -- new game or load: the known stores are read again from the save
		G.info, G.leafOf, G.known, G.agg, G.findText = {}, {}, {}, nil, {}
		G.seen, G.seenDirty = nil, {} -- the seen log of the game just loaded (PSXSEEN in its save)
		pcall(pushTick)
	end)
end
