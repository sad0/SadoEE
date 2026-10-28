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
}
-- section id, label, its switches (the mouse section lists SQMB's inputs instead)
O.SECTIONS = {
	{ 'stash', "SQ_OPT_TXT_1572", { 'StashTints', 'StashPlus', 'StashDps' } },
	{ 'traps', "SQ_OPT_TXT_1573", { 'Traps', 'AutoDisarm', 'AutoOpen', 'Outline' } },
	{ 'combat', "SQ_OPT_TXT_1574", { 'Ammo', 'Quiver', 'AttackMove', 'SongSpam' } },
	{ 'loot', "SQ_OPT_TXT_1575", { 'SortedLoot', 'ChestsBar', 'Waiting' } },
	{ 'display', "SQ_OPT_TXT_1576", { 'Fps' } },
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

-----------------------
-- Settings           --
-----------------------

-- The switch's setting: true / false; true when the page is not there (or before EEex read the INI).
function SQOpt_On(id)
	local o = EEex_Options_Get and EEex_Options_Get(optionID(id))
	if not o then return true end
	local ok, v = pcall(function() return o:get() end)
	return not ok or v == nil or v ~= 0
end

-- Copies a switch's setting into its feature's field (when installed).
local function apply(row)
	local t = _G[row[5]]
	if row[6] and type(t) == 'table' then t[row[6]] = SQOpt_On(row[1]) end
	if row[5] == 'PStash' and type(t) == 'table' then t.dirty = true end -- the stash page redraws its cells
end
function SQOpt_ApplyAll()
	for _, row in ipairs(O.ROWS) do pcall(apply, row) end
end
function SQOpt_Set(id, on)
	local o = EEex_Options_Get(optionID(id))
	if o then o:set(on and 1 or 0) end
end

for _, row in ipairs(O.ROWS) do
	if not EEex_Options_Get(optionID(row[1])) then
		EEex_Options_Register(optionID(row[1]), EEex_Options_Option.new({
			['default']  = 1,
			['type']     = EEex_Options_ToggleType.new(),
			['accessor'] = EEex_Options_ClampedAccessor.new({ ['min'] = 0, ['max'] = 1 }),
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
function SQOpt_RowDesc(k) local r = rows()[k] return r and r[4] or '' end
-- SQOPTCK.BAM: 0 = red cross (off), 1 = green check (on)
function SQOpt_RowFrame(k) local r = rows()[k] return (r and SQOpt_On(r[1])) and 1 or 0 end
function SQOpt_RowClick(k)
	local r = rows()[k]
	if r then SQOpt_Set(r[1], not SQOpt_On(r[1])) end
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
	if kind == 'r' then return SQOpt_RowDesc(k) end
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

-- The game's Options menu (Esc): a "SadoEE" button above EEex's, a copy of the Return button's look.
local function injectEscButton()
	local esc = EEex_Menu_Find('ESC_MENU')
	if not esc or O.escInjected then return end
	local ret = EEex_Options_Private_FindItemByText and EEex_Options_Private_FindItemByText(esc, getUiString('RETURN_GAME_BUTTON'))
	if not ret then return end
	local b = EEex_Menu_InjectTemplateInstance('ESC_MENU', 'SQOPT_TEMPLATE_EscButton', 0, 0, 0)
	b.bam.resref = ret.bam.resref
	b.bam.sequence = ret.bam.sequence
	b.pad.x, b.pad.y, b.pad.w, b.pad.h = ret.pad.x, ret.pad.y, ret.pad.w, ret.pad.h
	local area, retArea = b.area, ret.area
	local prev = EEex_Menu_GetItemFunction(esc.reference_onOpen)
	EEex_Menu_SetItemFunction(esc.reference_onOpen, function()
		if prev then prev() end
		local gap = 5
		area.x, area.w, area.h = retArea.x, retArea.w, retArea.h
		area.y = retArea.y - 2 * (retArea.h + gap) -- EEex's own button sits right above Return
	end)
	O.escInjected = true
end
function SQOpt_EscText() return O.TXT.button end

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
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
