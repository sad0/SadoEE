--[[
SadoQoL component #12 - Mouse buttons (John 2026-10-23).

The extra mouse inputs run SadoQoL actions, set per input in the EEex Options menu (tab "SadoQoL"):
middle click, buttons 4 to 8, Shift + wheel up / down, Ctrl + wheel up / down.
Actions: Nothing (the game's own behaviour), Attack-move to the cursor (#11; press = destination, drag then release =
the way the formation faces), Trap aura on/off for the selected
thieves (#0 / #9), FPS counter on/off (#5). Default: button 4 = attack-move.

How: EEex's key listeners only see the keyboard, so EEex_Key_Hook_AfterEventsPoll (called for every SDL event) is
wrapped: a bound SDL_MOUSEBUTTONDOWN / SDL_MOUSEWHEEL in the game screen runs its action and is consumed.
Labels: uiStrings, filled at install from the .tra of the chosen language (SadoQoL.tp2).
--]]

SQMB = SQMB or {}
local T = SQMB

-- labels (SadoQoL.tp2 writes them in the install language)
local L = {
	tab = "SQ_MB_TXT_TAB",
	nothing = "SQ_MB_TXT_NOTHING", atkm = "SQ_MB_TXT_ATKM", traps = "SQ_MB_TXT_TRAPS", fps = "SQ_MB_TXT_FPS",
	desc = "SQ_MB_TXT_DESC",
}
local INPUTS = {   -- id, SDL button (or wheel sign + modifier), label
	{ 'Middle', 2, "SQ_MB_TXT_MIDDLE" },
	{ 'B4', 4, "SQ_MB_TXT_B4" }, { 'B5', 5, "SQ_MB_TXT_B5" },
	{ 'B6', 6, "SQ_MB_TXT_B6" }, { 'B7', 7, "SQ_MB_TXT_B7" }, { 'B8', 8, "SQ_MB_TXT_B8" },
	{ 'ShiftUp', 'shift+', "SQ_MB_TXT_SHIFTUP" }, { 'ShiftDown', 'shift-', "SQ_MB_TXT_SHIFTDOWN" },
	{ 'CtrlUp', 'ctrl+', "SQ_MB_TXT_CTRLUP" }, { 'CtrlDown', 'ctrl-', "SQ_MB_TXT_CTRLDOWN" },
}
local NOTHING, ATKM, TRAPS, FPS = 0, 1, 2, 3
local THIEF_CLASSES = { [4] = true, [9] = true, [10] = true, [13] = true, [15] = true }   -- as in M_SQTRAP.lua

-- ---- actions ----
local actions = {}
actions[ATKM] = function()
	if SQAttackMove_AtCursor then SQAttackMove_AtCursor() end
end
-- mouse buttons: press / release pairs (a wheel has no release: it runs actions[] at once)
local pressActions, releaseActions = {}, {}
pressActions[ATKM] = function()                 -- press = destination, release = facing (drag), like a right-click drag
	if SQAttackMove_Begin then SQAttackMove_Begin() elseif SQAttackMove_AtCursor then SQAttackMove_AtCursor() end
end
releaseActions[ATKM] = function()
	if SQAttackMove_End then SQAttackMove_End() end
end
actions[TRAPS] = function()
	if not SQMode_ToggleTraps then return end
	for _, s in ipairs(EEex_Sprite_GetAllSelected()) do
		if THIEF_CLASSES[s.m_typeAI.m_Class] then SQMode_ToggleTraps(s) end
	end
end
actions[FPS] = function()
	if not SQFps then return end
	SQFps.on = not SQFps.on
	pcall(Infinity_SetINIValue, 'SadoQoL', 'FPS', SQFps.on and 1 or 0)
end

-- ---- options ----
for _, inp in ipairs(INPUTS) do
	EEex_Options_Register('SQMB_' .. inp[1], EEex_Options_Option.new({
		['default']  = inp[1] == 'B4' and ATKM or NOTHING,
		['accessor'] = EEex_Options_ClampedAccessor.new({ ['min'] = 0, ['max'] = 3 }),
		['storage']  = EEex_Options_NumberLuaStorage.new({ ['section'] = 'SadoQoL', ['key'] = 'Mouse ' .. inp[1] }),
	}))
end

local function labels()
	uiStrings = uiStrings or {}
	uiStrings.SQMB_Tab, uiStrings.SQMB_Desc = L.tab, L.desc
	uiStrings.SQMB_Nothing, uiStrings.SQMB_Atkm = L.nothing, L.atkm
	uiStrings.SQMB_Traps, uiStrings.SQMB_Fps = L.traps, L.fps
	for _, inp in ipairs(INPUTS) do uiStrings['SQMB_' .. inp[1]] = inp[3] end
end
labels()
EEex_Menu_AddTranslationLoadedListener(labels)

EEex_Options_AddTab('SQMB_Tab', function()
	local rows = {}
	for _, inp in ipairs(INPUTS) do
		rows[#rows + 1] = EEex_Options_DisplayEntry.new({
			['optionID']    = 'SQMB_' .. inp[1],
			['label']       = 'SQMB_' .. inp[1],
			['description'] = 'SQMB_Desc',
			['widget']      = EEex_Options_HorizontalMultiToggleWidget.new({
				['toggles'] = {
					{ ['label'] = 'SQMB_Nothing', ['data'] = { ['toggleValue'] = NOTHING } },
					{ ['label'] = 'SQMB_Atkm',    ['data'] = { ['toggleValue'] = ATKM } },
					{ ['label'] = 'SQMB_Traps',   ['data'] = { ['toggleValue'] = TRAPS } },
					{ ['label'] = 'SQMB_Fps',     ['data'] = { ['toggleValue'] = FPS } },
				},
			}),
		})
	end
	return { rows }
end)

-- ---- SDL events ----
local function bound(id)
	local ok, v = pcall(function() return EEex_Options_Get('SQMB_' .. id):get() end)
	return ok and v or NOTHING
end

local function modifier(name)
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left ' .. name)) or EEex_Key_IsDown(EEex_Key_GetFromName('Right ' .. name))
end

local function inputFor(event, released)
	if event.type == (released and SDL_EventType.SDL_MOUSEBUTTONUP or SDL_EventType.SDL_MOUSEBUTTONDOWN) then
		for _, inp in ipairs(INPUTS) do
			if inp[2] == event.button.button then return inp[1] end
		end
	elseif event.type == SDL_EventType.SDL_MOUSEWHEEL and event.wheel.y ~= 0 then
		local mod = modifier('Shift') and 'shift' or (modifier('Ctrl') and 'ctrl')
		if mod then
			local key = mod .. (event.wheel.y > 0 and '+' or '-')
			for _, inp in ipairs(INPUTS) do
				if inp[2] == key then return inp[1] end
			end
		end
	end
end

if not T.hooked and EEex_Key_Hook_AfterEventsPoll then
	T.hooked = true
	local orig = EEex_Key_Hook_AfterEventsPoll
	EEex_Key_Hook_AfterEventsPoll = function(event)
		local ok, consumed = pcall(function()
			if worldScreen ~= e:GetActiveEngine() then return false end
			if event.type == SDL_EventType.SDL_MOUSEBUTTONUP then
				local id = inputFor(event, true)
				local act = id and releaseActions[bound(id)]
				if not act then return false end
				act()
				return true
			end
			local id = inputFor(event)
			local b = id and bound(id)
			local act = b and ((event.type == SDL_EventType.SDL_MOUSEBUTTONDOWN and pressActions[b]) or actions[b])
			if not act then return false end
			act()
			return true
		end)
		if not ok then T.lastError = tostring(consumed) elseif consumed then return true end
		return orig(event)
	end
end
