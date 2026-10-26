--[[
SadoQoL component #1 - Valuable containers (John 2026-10-18).

Containers holding something valuable get a permanent gold outline (no Alt, no hover needed).
Valuable item: worth carrying, i.e. base price / weight >= MIN_RATIO, a weightless item counting as weight 1
(John 2026-10-18, same rule as the sorted loot; a 1 gp throwing dagger weighs 0); gold coins: a pile of at least MIN_VALUE; magical (ITM flag 0x40);
ring / amulet / gem; spell scroll.
Once looted down to nothing valuable, the outline goes away. Trapped containers the party found keep the red.

How: the outline is drawn while m_drawPoly > 0 (Find Traps sets 400). Valuable containers get GOLD_POLY (401):
that value is the gold marker. Its color is set by a pure assembly hook on the outline's draw call (no Lua call
per frame: Lua there ran ~2000 times per second). The hover/Tab highlight goes through EEex's "Empty Container"
module hook (enabled in EEex.ini by SadoQoL.tp2); this file replaces the module's callback (the gray color for
empty containers is not used).
Tuning live from the EEex console, e.g.  SQCont.MIN_RATIO = 25 (then SQCont.itemCache = {})   SQCont.COLOR = 0x00D7FF   SQCont.ENABLED = false
--]]

SQCont = SQCont or {}
local T = SQCont

T.ENABLED   = T.ENABLED ~= false
T.MIN_VALUE = T.MIN_VALUE or 100       -- gold pieces in a gold pile
T.MIN_RATIO = T.MIN_RATIO or 50        -- base price per weight unit (Armure de plates 12, Potion de soins 75)
T.COLOR     = T.COLOR or 0x00D7FF      -- gold (engine color, 0xBBGGRR)
T.PERIOD    = T.PERIOD or 1000         -- ms between two scans of the visible area
T.FULL_MS   = T.FULL_MS or 5000        -- contents are re-read this often (sooner when the item count changes)
T.itemCache = {}                       -- resref -> valuable (true/false)
T.contCache = {}                       -- container id -> { item count, valuable } (cleared on area change)

local TYPE_CONTAINER = 17
local DRAW_POLY = 400       -- the engine's own (red) outline, Find Traps
local GOLD_POLY = 401       -- our marker: drawn like 400, recolored by the hook
local OFF_DRAWPOLY = 0x9A0  -- CGameContainer::m_drawPoly (int16), read by the hook
local TYPE_AMULET, TYPE_RING, TYPE_SCROLL, TYPE_GOLD, TYPE_GEM = 1, 10, 11, 33, 34
local FLAG_MAGICAL = 0x40

local function itemValuable(res, count)
	local key = string.upper(res)
	local v = T.itemCache[key]
	if v == nil then
		local h = EEex_Resource_Demand(key, 'ITM')
		if not h then
			v = false
		elseif h.itemType == TYPE_GOLD then
			v = 'gold'
		else
			local t = h.itemType
			v = h.baseValue / math.max(h.baseWeight, 1) >= T.MIN_RATIO or EEex_BAnd(h.itemFlags, FLAG_MAGICAL) ~= 0
				or t == TYPE_RING or t == TYPE_AMULET or t == TYPE_GEM or t == TYPE_SCROLL
		end
		T.itemCache[key] = v
	end
	if v == 'gold' then return count >= T.MIN_VALUE end
	return v
end

local function containerValuable(c)
	local found = false
	EEex_Utility_IterateCPtrList(c.m_lstItems, function(it)
		if not found and itemValuable(it.pRes.resref:get(), it.m_useCount1) then found = true end
	end)
	return found
end

local function trapShown(c)
	return c.m_trapActivated == 1 and c.m_trapDetected == 1
end

local function cachedValuable(id, c, full)
	local e = T.contCache[id]
	local n = c.m_lstItems.m_nCount
	if full or not e or e[1] ~= n then
		e = { n, n > 0 and containerValuable(c) }
		T.contCache[id] = e
	end
	return e[2]
end

-- off = true: only removes our marker (component turned off)
local function scan(area, off)
	local now = Infinity_GetClockTicks()
	local key = area.m_resref:get()
	local full = key ~= T.areaKey or now - (T.fullAt or 0) >= T.FULL_MS
	if full or not T.ids then
		if key ~= T.areaKey then T.contCache = {} end
		T.areaKey, T.fullAt = key, now
		-- the area's containers (the list also holds creatures and other objects: skipped between full scans)
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
			local dp = c.m_drawPoly
			if not off and cachedValuable(id, c, full) then
				-- m_drawPoly is not saved and hovering resets it: put it back every scan.
				-- A trap the party found keeps the engine's red.
				local want = trapShown(c) and DRAW_POLY or GOLD_POLY
				if dp ~= want and (dp == 0 or dp == GOLD_POLY or dp == DRAW_POLY) then c.m_drawPoly = want end
			elseif dp == GOLD_POLY then
				c.m_drawPoly = trapShown(c) and DRAW_POLY or 0
			end
		end
	end
end

-- Called by EEex's Empty Container hook when a container is highlighted (hover / Tab; hovering resets m_drawPoly).
function B3EmptyContainer_Hook_OnBeforeContainerOutlineRender(container, color)
	if not T.ENABLED then return end
	local e = T.contCache[container.m_id]
	if e and e[2] and not trapShown(container) then color.value = T.COLOR end
end

-- The permanent outline (m_drawPoly > 0) is a second draw call in CGameContainer::Render, right after the
-- highlight call EEex hooks, with a hard-coded red (mov [rsp+0x20], 0xFF ; call DrawPoly). Pure assembly hook on
-- that call: when the container (r14) carries the GOLD_POLY marker, the color argument becomes the color stored
-- at T.colorPtr. Checked against the expected bytes first: another game build is left untouched.
local function hookDrawPoly()
	if T.polyHooked then return end
	local base = EEex_Label("Hook-CGameContainer::Render()-B3EmptyContainer")
	local at = base + 0x39  -- the call after "mov dword ptr [rsp+0x20], 0xFF"
	local expect = { 0xC7, 0x44, 0x24, 0x20, 0xFF, 0x00, 0x00, 0x00, 0xE8 }
	for i, b in ipairs(expect) do
		if EEex_ReadU8(at - 8 + i - 1) % 256 ~= b then
			T.polyHooked = 'skipped: unexpected code at +0x39'
			print('[SadoQoL] valuable containers: ' .. T.polyHooked)
			return
		end
	end
	-- "cmp word ptr [r14+0x9A0], 0 ; jle" guards that call: checks the field offset the hook reads.
	local guard = { 0x66, 0x41, 0x83, 0xBE, 0xA0, 0x09, 0x00, 0x00, 0x00, 0x7E }
	for i, b in ipairs(guard) do
		if EEex_ReadU8(base + 5 + i - 1) % 256 ~= b then
			T.polyHooked = 'skipped: unexpected m_drawPoly check'
			print('[SadoQoL] valuable containers: ' .. T.polyHooked)
			return
		end
	end
	T.colorPtr = EEex_Malloc(4)
	EEex_WriteU32(T.colorPtr, T.COLOR)
	T.colorWritten = T.COLOR
	EEex_DisableCodeProtection()
	EEex_HookBeforeCallWithLabels(at, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		{[[
			cmp word ptr ds:[r14+]], OFF_DRAWPOLY, [[], ]], GOLD_POLY, [[ #ENDL
			jne sqcont_keep_color
			mov r10, ]], T.colorPtr, [[ #ENDL
			mov r11d, dword ptr ds:[r10]
			mov dword ptr ss:[rsp+#LAST_FRAME_TOP(32)], r11d
			sqcont_keep_color:
		]]}
	)
	EEex_HookIntegrityWatchdog_IgnoreStackSizes(at, {{0x20, 4}})
	EEex_EnableCodeProtection()
	T.polyHooked = true
end

function SQCont_Tick()
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + T.PERIOD
	if T.colorPtr and T.colorWritten ~= T.COLOR then
		EEex_WriteU32(T.colorPtr, T.COLOR)
		T.colorWritten = T.COLOR
	end
	local area = EEex_Area_GetVisible()
	if area and EEex_Sprite_GetInPortrait(0) then
		local ok, err = pcall(scan, area, not T.ENABLED)
		if not ok then T.lastError = tostring(err) end
	end
	return false
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQCONT_TICK') then Infinity_PushMenu('SQCONT_TICK') end
end

do
	local ok, err = pcall(hookDrawPoly)
	if not ok then T.polyHooked = 'error: ' .. tostring(err) print('[SadoQoL] valuable containers: ' .. T.polyHooked) end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQCONT') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
