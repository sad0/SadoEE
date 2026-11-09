--[[
SadoEE options page (John 2026-10-27 / 28): the interface and quality of life features switched on / off in game,
and the mouse buttons, on a page of their own in the camp merchant's notice board look (SQOPT.menu), instead of
install components (promised on G3 and in Party Stash issue #1).

Opened from: the game's Options menu (Esc, a "SadoEE" button), EEex's Options menu (tab SadoEE, one line), Decard at
the camp (a reply). A full page: the game paused, the world veiled, the portrait bars live (M_PSXPG.lua when there).
Left: the sections (only those with an installed feature). Middle: the section's switches (a red diamond = on) or
the mouse buttons (M_SQMB.lua: one action per input and modifier, chosen in a list). Right: help on the line pointed.

Settings: global, the game's INI (Baldur.lua) [SadoQoL], through EEex options (SQOPT_<id>). Turning a feature off only
stops it acting: what it already did stays (traps found, quiver arrows given...).
Each component with a switch copies this file (SadoQoL.tp2: SQ_OPT_TXT_<n> = setup.tra @n, written at install).

Other modules ask:  SQOpt_On('StashTints')   -> true / false (true when the page is not installed)
EEex only (EEex_Options_*, EEex_Menu_*): no engine patch.
--]]

SQOpt = SQOpt or {}
local O = SQOpt

-- id, INI key, label, description, the feature's table (a global) and its on / off field
O.ROWS = {
	{ 'StashTints', 'Stash Tints', "SQ_OPT_TXT_1542", "SQ_OPT_TXT_1543", 'PStash' },
	{ 'StashPlus', 'Stash Upgrade Mark', "SQ_OPT_TXT_1544", "SQ_OPT_TXT_1545", 'PStash' },
	{ 'StashDps', 'Stash DPS Line', "SQ_OPT_TXT_1546", "SQ_OPT_TXT_1547", 'PStash' },
	-- a choice, not a switch (values = its labels, 0 first; John 2026-10-29: off by default, more filters later)
	{ 'AutoStash', 'Auto Stash', "SQ_OPT_TXT_1620", "SQ_OPT_TXT_1621", 'PStash', 'autoFilter',
		values = { "SQ_OPT_TXT_1622", "SQ_OPT_TXT_1623" }, default = 0 },
	{ 'Traps', 'Passive Traps', "SQ_OPT_TXT_1548", "SQ_OPT_TXT_1549", 'SQTrap', 'ENABLED' },
	{ 'AutoDisarm', 'Auto Disarm', "SQ_OPT_TXT_1550", "SQ_OPT_TXT_1551", 'SQAuto', 'ENABLED' },
	{ 'AutoOpen', 'Auto Open', "SQ_OPT_TXT_1552", "SQ_OPT_TXT_1553", 'SQAuto', 'CLICK' },
	{ 'Outline', 'Valuable Containers', "SQ_OPT_TXT_1554", "SQ_OPT_TXT_1555", 'SQCont', 'ENABLED' },
	{ 'Ammo', 'Endless Ammo', "SQ_OPT_TXT_1556", "SQ_OPT_TXT_1557", 'SQAmmo', 'ENABLED' },
	{ 'Quiver', 'Basic Ammo Quiver', "SQ_OPT_TXT_1558", "SQ_OPT_TXT_1559", 'SQQuiv', 'ENABLED' },
	{ 'AttackMove', 'Attack Move', "SQ_OPT_TXT_1560", "SQ_OPT_TXT_1561", 'SQAttackMove', 'ENABLED' },
	{ 'SongSpam', 'Mode Spam Filter', "SQ_OPT_TXT_1562", "SQ_OPT_TXT_1563", 'SQMode', 'SPAM' },
	{ 'SortedLoot', 'Sorted Loot', "SQ_OPT_TXT_1564", "SQ_OPT_TXT_1565", 'SQSort', 'ENABLED' },
	{ 'ChestsBar', 'Chests In Ground Bar', "SQ_OPT_TXT_1566", "SQ_OPT_TXT_1567", 'SQChest', 'ENABLED' },
	{ 'Waiting', 'Camp Waiting', "SQ_OPT_TXT_1568", "SQ_OPT_TXT_1569", 'SQWait', 'ENABLED' },
	{ 'Fps', 'FPS', "SQ_OPT_TXT_1570", "SQ_OPT_TXT_1571", 'SQFps', 'on' },
	{ 'AlliesFog', 'Allies Clear Fog', "SQ_OPT_TXT_1641", "SQ_OPT_TXT_1642", 'SQFog', 'ENABLED' },
	-- per save, not in the INI (get / set: the module's functions; John 2026-11-09, big party XP, #40)
	{ 'XpMode', 'Big Party XP', "SQ_OPT_TXT_1643", "SQ_OPT_TXT_1644", 'PSXP7',
		values = { "SQ_OPT_TXT_1645", "SQ_OPT_TXT_1646", "SQ_OPT_TXT_1647" }, default = 0,
		get = 'PSXP7_XpMode', set = 'PSXP7_SetXpMode' },
}
-- section id, label, its switches (the mouse section lists SQMB's inputs instead)
O.SECTIONS = {
	{ 'stash', "SQ_OPT_TXT_1572", { 'StashTints', 'StashPlus', 'StashDps', 'AutoStash' } },
	{ 'traps', "SQ_OPT_TXT_1573", { 'Traps', 'AutoDisarm', 'AutoOpen', 'Outline' } },
	{ 'combat', "SQ_OPT_TXT_1574", { 'Ammo', 'Quiver', 'AttackMove', 'SongSpam' } },
	{ 'loot', "SQ_OPT_TXT_1575", { 'SortedLoot', 'ChestsBar', 'Waiting' } },
	{ 'display', "SQ_OPT_TXT_1576", { 'Fps', 'AlliesFog' } },
	{ 'party', "SQ_OPT_TXT_1648", { 'XpMode' } },
	{ 'mouse', "SQ_OPT_TXT_1577" },
}
O.TXT = {
	tab = "SQ_OPT_TXT_1540", note = "SQ_OPT_TXT_1541", close = "SQ_OPT_TXT_1578", more = "SQ_OPT_TXT_1581",
	cancel = "SQ_OPT_TXT_1582", openRow = "SQ_OPT_TXT_1592", openDesc = "SQ_OPT_TXT_1593", point = "SQ_OPT_TXT_1596",
	mouseHelp = "SQ_OPT_TXT_1597", button = "SQ_OPT_TXT_1540",
}
O.MAX_ROWS = 7     -- switch lines of the middle paper (SQOPT_R1..7)
O.MOUSE_ROWS = 10  -- mouse lines, two columns of 5 (SQOPT_M1..10)

local function optionID(id) return 'SQOPT_' .. id end
local function rowById(id)
	for _, row in ipairs(O.ROWS) do if row[1] == id then return row end end
end
local function installed(row) return row ~= nil and type(_G[row[5]]) == 'table' end
-- a per-save row: its value comes from the module (the loaded game), 0 when it cannot be read
local function saveValue(row)
	local f = _G[row.get]
	if type(f) ~= 'function' then return 0 end
	local ok, v = pcall(f)
	return ok and tonumber(v) or 0
end
local function setSaveValue(row, v)
	local f = _G[row.set]
	if type(f) == 'function' then pcall(f, v) end
end

-----------------------
-- Settings           --
-----------------------

-- The switch's setting: true / false; true when the page is not there (or before EEex read the INI).
function SQOpt_On(id)
	local row = rowById(id)
	if row and row.get then return saveValue(row) ~= 0 end
	local o = EEex_Options_Get and EEex_Options_Get(optionID(id))
	if not o then return true end
	local ok, v = pcall(function() return o:get() end)
	return not ok or v == nil or v ~= 0
end

-- A choice's setting: 0 (off) .. #values - 1; for a switch 1 / 0. 0 when the page is not there.
function SQOpt_Value(id)
	local row = rowById(id)
	if row and row.get then return saveValue(row) end
	local o = EEex_Options_Get and EEex_Options_Get(optionID(id))
	if not o then return 0 end
	local ok, v = pcall(function() return o:get() end)
	return ok and tonumber(v) or 0
end

-- Copies a switch's setting (a choice's value) into its feature's field (when installed).
local function apply(row)
	if row.get then return end
	local t = _G[row[5]]
	if row[6] and type(t) == 'table' then
		if row.values then t[row[6]] = SQOpt_Value(row[1]) else t[row[6]] = SQOpt_On(row[1]) end
	end
	if row[5] == 'PStash' and type(t) == 'table' then t.dirty = true end -- the stash page redraws its cells
end
function SQOpt_ApplyAll()
	for _, row in ipairs(O.ROWS) do pcall(apply, row) end
end
function SQOpt_Set(id, on)
	local row = rowById(id)
	if row and row.set then setSaveValue(row, on and 1 or 0) return end
	local o = EEex_Options_Get(optionID(id))
	if o then o:set(on and 1 or 0) end
end

for _, row in ipairs(O.ROWS) do
	if not row.get and not EEex_Options_Get(optionID(row[1])) then
		EEex_Options_Register(optionID(row[1]), EEex_Options_Option.new({
			['default']  = row.default or 1,
			['type']     = EEex_Options_ToggleType.new(),
			['accessor'] = EEex_Options_ClampedAccessor.new({ ['min'] = 0, ['max'] = row.values and #row.values - 1 or 1 }),
			['storage']  = EEex_Options_NumberLuaStorage.new({ ['section'] = 'SadoQoL', ['key'] = row[2] }),
			['onChange'] = function() pcall(apply, row) end,
		}))
	end
end
-- EEex's tab: one line that opens the page (its toggle never changes: the click is caught by toggleWarning)
if not EEex_Options_Get('SQOPT_OpenPage') then
	EEex_Options_Register('SQOPT_OpenPage', EEex_Options_Option.new({
		['default']  = 0,
		['type']     = EEex_Options_ToggleType.new(),
		['accessor'] = EEex_Options_ClampedAccessor.new({ ['min'] = 0, ['max'] = 1 }),
		-- EEex reads every option at game init: a storage is needed (it always stays 0)
		['storage']  = EEex_Options_NumberLuaStorage.new({ ['section'] = 'SadoQoL', ['key'] = 'Options Page Line' }),
	}))
end

-----------------------
-- Page state         --
-----------------------

O.sec = O.sec or nil      -- the shown section id
O.mod = O.mod or ''       -- mouse section: the modifier shown ('', Shift, Ctrl, Alt)
sqOptSecList = sqOptSecList or {}
sqOptSecRow = sqOptSecRow or 1
sqOptDropList = sqOptDropList or {}
sqOptDropRow = sqOptDropRow or 0

local function sectionShown(s)
	if s[1] == 'mouse' then return SQMB_Bind ~= nil end
	for _, id in ipairs(s[3]) do if installed(rowById(id)) then return true end end
	return false
end
local function buildSections()
	sqOptSecList = {}
	for _, s in ipairs(O.SECTIONS) do
		if sectionShown(s) then sqOptSecList[#sqOptSecList + 1] = { id = s[1], text = s[2], rows = s[3] } end
	end
	local found = false
	for i, s in ipairs(sqOptSecList) do
		if s.id == O.sec then sqOptSecRow, found = i, true end
	end
	if not found then
		sqOptSecRow = 1
		O.sec = sqOptSecList[1] and sqOptSecList[1].id
	end
end
local function section() return sqOptSecList[sqOptSecRow] end
local function isMouse() local s = section() return s ~= nil and s.id == 'mouse' end
-- the shown section's installed switches
local function rows()
	local s = section()
	local out = {}
	if not s or not s.rows then return out end
	for _, id in ipairs(s.rows) do
		local row = rowById(id)
		if installed(row) then out[#out + 1] = row end
	end
	return out
end
-- mouse section: the inputs shown with the chosen modifier
local function mouseInputs()
	local out = {}
	if not SQMB then return out end
	for _, inp in ipairs(SQMB.INPUTS) do
		if SQMB_InputShown(inp, O.mod) then out[#out + 1] = inp end
	end
	return out
end

-----------------------
-- Page: menu calls   --
-----------------------

function SQOpt_SecText(r) local s = sqOptSecList[r] return s and s.text or '' end
function SQOpt_SecSelected(r) return r == sqOptSecRow end
function SQOpt_SecClick()
	local s = sqOptSecList[sqOptSecRow]
	if s then O.sec = s.id end
end
function SQOpt_Title() local s = section() return s and s.text or '' end

-- switch lines
function SQOpt_RowShown(k) return not isMouse() and rows()[k] ~= nil end
function SQOpt_RowName(k) local r = rows()[k] return r and r[3] or '' end
-- under the name: a switch's description; a choice's value, between arrows (its description goes to the help)
function SQOpt_RowDesc(k)
	local r = rows()[k]
	if not r then return '' end
	if r.values then
		local v = SQOpt_Value(r[1])
		return (v == 0 and '' or '^0xff901010') .. '< ' .. (r.values[v + 1] or '') .. ' >'
	end
	return r[4]
end
local function rowHelp(k) local r = rows()[k] return r and r[4] or '' end
-- SQOPTCK.BAM: 0 = red cross (off), 1 = green check (on; a choice: any value but the first)
function SQOpt_RowFrame(k) local r = rows()[k] return (r and SQOpt_On(r[1])) and 1 or 0 end
-- click: a switch flips, a choice goes to its next value; right click: off
function SQOpt_RowClick(k)
	local r = rows()[k]
	if not r then return end
	if r.values and r.set then setSaveValue(r, (SQOpt_Value(r[1]) + 1) % #r.values) return end
	local o = EEex_Options_Get(optionID(r[1]))
	if r.values and o then o:set((SQOpt_Value(r[1]) + 1) % #r.values) return end
	SQOpt_Set(r[1], not SQOpt_On(r[1]))
end
function SQOpt_RowClear(k)
	local r = rows()[k]
	if r then SQOpt_Set(r[1], false) end
end

-- mouse lines
function SQOpt_IsMouse() return isMouse() end
function SQOpt_ModText(i) return SQMB and SQMB.MODS[i] and SQMB.MODS[i][2] or '' end
function SQOpt_ModFrame(i) return (SQMB and SQMB.MODS[i] and SQMB.MODS[i][1] == O.mod) and 2 or 0 end
function SQOpt_ModClick(i) if SQMB and SQMB.MODS[i] then O.mod = SQMB.MODS[i][1] end end
function SQOpt_MouseShown(k) return isMouse() and mouseInputs()[k] ~= nil end
function SQOpt_MouseName(k) local inp = mouseInputs()[k] return inp and inp[3] or '' end
local function mouseKey(k) local inp = mouseInputs()[k] return inp and (O.mod .. inp[1]) end
function SQOpt_MouseValue(k)
	local key = mouseKey(k)
	if not key then return '' end
	local code = SQMB_Bind(key)
	return (code == 0 and '' or '^0xff901010') .. '< ' .. SQMB_ActionLabel(code) .. ' >'
end
function SQOpt_MouseClear(k)
	local key = mouseKey(k)
	if key then SQMB_SetBind(key, 0) end
end

-- the list of actions for one mouse input (SQOPT_DROP)
local function fillDrop(all)
	O.dropAll = all
	sqOptDropList = SQMB_Actions(all)
	if not all then sqOptDropList[#sqOptDropList + 1] = { more = true, text = O.TXT.more } end
	sqOptDropRow = 0
end
function SQOpt_MouseClick(k)
	O.dropKey = mouseKey(k)
	if not O.dropKey then return end
	O.dropName = SQOpt_MouseName(k) .. (O.mod ~= '' and (' (' .. SQOpt_ModText(SQOpt_ModIndex()) .. ')') or '')
	fillDrop(false)
	Infinity_PushMenu('SQOPT_DROP')
end
function SQOpt_ModIndex()
	for i, m in ipairs(SQMB and SQMB.MODS or {}) do if m[1] == O.mod then return i end end
	return 1
end
function SQOpt_DropTitle() return O.dropName or '' end
function SQOpt_DropText(r)
	local d = sqOptDropList[r]
	if not d then return '' end
	if d.header then return '^0xff5a3c14' .. d.text end
	if d.more then return '^0xff901010' .. d.text end
	local cur = O.dropKey and SQMB_Bind(O.dropKey)
	return (d.code == cur and '> ' or '   ') .. d.text
end
function SQOpt_DropSelected(r)
	local d = sqOptDropList[r]
	return d ~= nil and not d.header and not d.more and O.dropKey ~= nil and d.code == SQMB_Bind(O.dropKey)
end
function SQOpt_DropClick()
	local d = sqOptDropList[sqOptDropRow]
	if not d or d.header then return end
	if d.more then fillDrop(true) return end
	SQMB_SetBind(O.dropKey, d.code)
	Infinity_PopMenu('SQOPT_DROP')
end
function SQOpt_DropClose() Infinity_PopMenu('SQOPT_DROP') end

-- help (right paper): the line under the mouse
local function hovered()
	if not EEex_Menu_IsCursorWithin then return nil end
	for k = 1, O.MAX_ROWS do
		if SQOpt_RowShown(k) and EEex_Menu_IsCursorWithin('SQOPT_PAGE', 'SQOPT_R' .. k) then return 'r', k end
	end
	for k = 1, O.MOUSE_ROWS do
		if SQOpt_MouseShown(k) and EEex_Menu_IsCursorWithin('SQOPT_PAGE', 'SQOPT_M' .. k) then return 'm', k end
	end
end
function SQOpt_HelpTitle()
	local kind, k = hovered()
	if kind == 'r' then return SQOpt_RowName(k) end
	if kind == 'm' then return SQOpt_MouseName(k) end
	return ''
end
function SQOpt_HelpText()
	local kind, k = hovered()
	if kind == 'r' then return rowHelp(k) end
	if kind == 'm' then
		local key = mouseKey(k)
		return SQMB_ActionLabel(key and SQMB_Bind(key) or 0) .. '\n\n' .. O.TXT.mouseHelp
	end
	return O.TXT.point
end

-- the board's look follows the camp merchant's page when it is installed (painted board otherwise)
function SQOpt_Skin()
	if PSXGM_Skin then
		local ok, s = pcall(PSXGM_Skin)
		if ok and s == 1 then return 1 end
	end
	return 2
end

-----------------------
-- Open / close       --
-----------------------

local function onWorld() return worldScreen ~= nil and e:GetActiveEngine() == worldScreen end

function SQOpt_OnOpen()
	buildSections()
	O.mod = O.mod or ''
end

-- On the world screen: a full page (M_PSXPG.lua: pause + veil), or pushed as is with the game paused.
function SQOpt_Open()
	-- main menu (no game loaded): selecting the world screen crashes the game; push the page as is.
	-- (CurrentlyInGame() is no help: it already says true on the start screen.)
	if not O.inGame or e:GetActiveEngine() == startEngine then
		O.pending = nil
		O.direct = true
		if not Infinity_IsMenuOnStack('SQOPT_PAGE') then Infinity_PushMenu('SQOPT_PAGE') end
		return
	end
	O.direct = nil
	if not onWorld() then
		-- from the game's Options menu: back to the world first, the page opens on the next frame (SQOPT_TICK)
		O.pending = true
		pcall(function() e:SelectEngine(worldScreen) end)
		return
	end
	O.pending = nil
	if Infinity_IsMenuOnStack('SQOPT_PAGE') then return end
	if PSXPG_Open then PSXPG_Open('SQOPT_PAGE') return end
	O.unpause = false
	local ok, paused = pcall(function() return worldScreen:CheckIfPaused() end)
	if ok and not paused then
		pcall(function() worldScreen:TogglePauseGame(true) end)
		O.unpause = true
	end
	Infinity_PushMenu('SQOPT_PAGE')
end
function SQOpt_Close()
	if Infinity_IsMenuOnStack('SQOPT_DROP') then Infinity_PopMenu('SQOPT_DROP') end
	if O.direct then
		O.direct = nil
		if Infinity_IsMenuOnStack('SQOPT_PAGE') then Infinity_PopMenu('SQOPT_PAGE') end
		return
	end
	if PSXPG_Close then PSXPG_Close('SQOPT_PAGE') return end
	if Infinity_IsMenuOnStack('SQOPT_PAGE') then Infinity_PopMenu('SQOPT_PAGE') end
	if O.unpause then
		O.unpause = false
		local ok, paused = pcall(function() return worldScreen:CheckIfPaused() end)
		if ok and paused then pcall(function() worldScreen:TogglePauseGame(true) end) end
	end
end
-- Decard's reply shows when the page is installed
function SQOpt_Installed() return true end

-- SQOPT_TICK: the page asked from the game's Options menu opens once the world screen is back
function SQOpt_Tick()
	if O.pending and onWorld() then pcall(SQOpt_Open) end
	return false
end
local function pushTick()
	if not Infinity_IsMenuOnStack('SQOPT_TICK') then Infinity_PushMenu('SQOPT_TICK') end
end

-- An item of `menu` by its text, without colour codes and any case (Infinity UI++ draws its buttons' text as
-- rgString(): '^$' .. getUiString(...), which an exact match misses).
local function plain(t)
	if type(t) ~= 'string' then return nil end
	return string.lower((t:gsub('%^0x%x%x%x%x%x%x%x%x', ''):gsub('%^.', '')))
end
local function findItemByText(menu, text)
	local want = plain(text)
	if not menu or not want then return nil end
	local item = menu.items
	while item ~= nil do
		local ok, t = pcall(function() return EEex_Menu_GetItemVariant(item.text.text) end)
		if ok and type(t) == 'function' then
			local ok2, r = pcall(t)
			t = ok2 and r or nil
		end
		if ok and plain(t) == want then return item end
		item = item.next
	end
end

-- The game's Options menu (Esc): a "SadoEE" button above EEex's, a copy of the Return button's look.
local function injectEscButton()
	local esc = EEex_Menu_Find('ESC_MENU')
	if not esc or O.escInjected then return end
	local ret = findItemByText(esc, getUiString('RETURN_GAME_BUTTON'))
	if not ret then
		print('[SQOpt] Options menu: no Return button, no SadoEE button')
		return
	end
	local b = EEex_Menu_InjectTemplateInstance('ESC_MENU', 'SQOPT_TEMPLATE_EscButton', 0, 0, 0)
	b.bam.resref = ret.bam.resref
	b.bam.sequence = ret.bam.sequence
	b.pad.x, b.pad.y, b.pad.w, b.pad.h = ret.pad.x, ret.pad.y, ret.pad.w, ret.pad.h
	b.area.x, b.area.y = -1000, -1000 -- placed on the first frame shown (SQOpt_EscText), once every item has its place
	-- No menu or item reference is kept: after the mods load, EEex adds its option tab menus and the engine's
	-- name-sorted menu array shifts, so a kept ESC_MENU would point at another menu (IEX, 2026-10-30).
	O.escInjected = true
end

-- The "SadoEE" button's place (IEX session 2026-10-28: a fixed "two rows above Return" sat on Save game when EEex's
-- own button is not there): the first free slot of Return's column, going up then down, among the items the menu
-- shows now (EEex's button or not; vanilla, Infinity UI++, LeUI, Dragonspear UI++): buttons, texts and BAM pictures
-- count, the backgrounds (over a quarter of the menu) do not.
local function itemShown(item)
	local ok, v = pcall(function() return EEex_Menu_GetItemVariant(item.enabled) end)
	if not ok or v == nil then return true end
	if type(v) == 'function' then
		local ok2, r = pcall(v)
		return not ok2 or (r ~= false and r ~= nil and r ~= 0)
	end
	return v ~= 0 and v ~= false
end
local function itemText(item)
	local ok, t = pcall(function() return EEex_Menu_GetItemVariant(item.text.text) end)
	if not ok then return nil end
	if type(t) == 'function' then
		local ok2, r = pcall(t)
		return ok2 and r or nil
	end
	return t
end
local function placeEscButton()
	-- looked up again each time (see injectEscButton)
	local esc = EEex_Menu_Find('ESC_MENU')
	if not esc then return end
	local retItem = findItemByText(esc, getUiString('RETURN_GAME_BUTTON'))
	local ours = findItemByText(esc, O.TXT.button)
	if not retItem or not ours then
		if O.DEBUG then print('[SQOpt] Esc button: Return ' .. tostring(retItem) .. ', ours ' .. tostring(ours)) end
		return
	end
	local area, ret = ours.area, retItem.area
	local x, w, h, gap = ret.x, ret.w, ret.h, 5
	local menuX, menuY, menuW, menuH = EEex_Menu_GetUIMenuArea(esc)
	local sw, sh = Infinity_GetScreenSize()
	menuX, menuY = menuX or 0, menuY or 0
	-- the slot must be on screen (the menu can be larger than a small window)
	local function onScreen(px, py)
		return menuX + px >= 0 and menuY + py >= 0 and (not sw or menuX + px + w <= sw) and (not sh or menuY + py + h <= sh)
	end
	local busy = {}
	local item = esc.items
	while item ~= nil do
		local a = item.area
		local text = itemText(item)
		-- what a button must not cover: the other buttons, the texts (title, version), the pictures with a BAM. Without
		-- uiItemType (IEX, 2026-10-28: Quit looked free) every item counts but the backgrounds.
		local known, isButton = pcall(function() return item.type == assert(uiItemType.ITEM_BUTTON) end)
		local okBam, bam = pcall(function() return EEex_Menu_GetItemVariant(item.bam.resref) end)
		local taken = not known or isButton or (type(text) == 'string' and text ~= '')
			or (okBam and type(bam) == 'string' and bam ~= '')
		if a and taken and plain(text) ~= plain(O.TXT.button) and itemShown(item)
			and a.w > 0 and a.h > 0 and a.w * a.h < 0.25 * (menuW or 1024) * (menuH or 768) then
			busy[#busy + 1] = { a.x, a.y, a.w, a.h }
		end
		item = item.next
	end
	local function free(px, py)
		if not onScreen(px, py) then return false end
		for _, r in ipairs(busy) do
			if px < r[1] + r[3] and r[1] < px + w and py < r[2] + r[4] and r[2] < py + h then return false end
		end
		return true
	end
	local function put(px, py)
		area.x, area.y, area.w, area.h = px, py, w, h
		if O.DEBUG then print(string.format('[SQOpt] Esc button at %d,%d (menu %d,%d %dx%d, screen %sx%s, %d taken)',
			px, py, menuX, menuY, menuW or 0, menuH or 0, tostring(sw), tostring(sh), #busy)) end
		return true
	end
	for k = 1, 12 do
		local y = ret.y - k * (h + gap)
		if free(x, y) then return put(x, y) end
	end
	for k = 1, 6 do
		local y = ret.y + k * (h + gap)
		if free(x, y) then return put(x, y) end
	end
	-- no free slot in the column: left, then right of Return; at worst over the column's top, kept on screen
	if free(x - w - gap, ret.y) then return put(x - w - gap, ret.y) end
	if free(x + w + gap, ret.y) then return put(x + w + gap, ret.y) end
	local px = math.max(-menuX, math.min(x, (sw or 99999) - menuX - w))
	local py = math.max(-menuY, math.min(ret.y - (h + gap), (sh or 99999) - menuY - h))
	return put(px, py)
end
-- Placed again each time the Options menu shows (it was closed for a moment: the window may have changed size).
function SQOpt_EscText()
	local now = Infinity_GetClockTicks()
	-- placeEscButton reads every button's text, this one's too: not again from inside it (C stack overflow, IUI++ 1.4)
	if not O.placing and (not O.escSeen or now - O.escSeen > 300) then
		O.placing = true
		local ok, err = pcall(placeEscButton)
		O.placing = nil
		if not ok then print('[SQOpt] Options button place: ' .. tostring(err)) end
	end
	O.escSeen = now
	return O.TXT.button
end

if not O.listenersAdded then
	O.listenersAdded = true
	uiStrings = uiStrings or {}
	local function labels()
		uiStrings.SQOPT_Tab = O.TXT.tab
		uiStrings.SQOPT_OpenPage, uiStrings.SQOPT_OpenPage_Desc = O.TXT.openRow, O.TXT.openDesc
	end
	labels()
	EEex_Menu_AddTranslationLoadedListener(labels)
	EEex_Options_AddTab('SQOPT_Tab', function()
		return { {
			EEex_Options_DisplayEntry.new({
				['optionID']    = 'SQOPT_OpenPage',
				['label']       = 'SQOPT_OpenPage',
				['description'] = 'SQOPT_OpenPage_Desc',
				['widget']      = EEex_Options_ToggleWidget.new({
					['toggleWarning'] = function()
						pcall(EEex_Options_Close)
						pcall(SQOpt_Open)
						return true
					end,
				}),
			}),
		} }
	end)
	EEex_Menu_AddMainFileLoadedListener(function()
		EEex_Menu_LoadFile('SQOPT')
		local ok, err = pcall(injectEscButton)
		if not ok then print('[SQOpt] Options button: ' .. tostring(err)) end
	end)
	EEex_GameState_AddInitializedListener(function() SQOpt_ApplyAll() pcall(pushTick) end)
	EEex_Sprite_AddLoadedListener(function() O.inGame = true pcall(pushTick) end)
	EEex_GameState_AddDestroyedListener(function() O.inGame = nil end)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
