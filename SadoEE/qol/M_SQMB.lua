--[[
SadoQoL component #12 - Mouse buttons (John 2026-10-23, reworked 2026-10-28).

Each extra mouse input runs any action of the game's Keybindings screen, or SadoEE's attack-move (#11), chosen in the
SadoEE options page (M_SQOPT.lua, section Mouse buttons). Inputs: middle click, buttons 4 to 8, wheel tilt left /
right, each alone or with Shift / Ctrl / Alt; wheel up / down with Shift / Ctrl / Alt (alone, the wheel stays the
game's zoom). Default: button 4 = attack-move (John). MMO mice: their side buttons send keys, bound in the game's own
Keybindings screen.

How: EEex_Key_Hook_AfterEventsPoll (called for every SDL event, before the engine reads it) is wrapped. A bound input
in the game screen is either run here (attack-move: press = destination, drag then release = facing) or rewritten in
place into the key press of its action (the key the game's keymap gives it; an action without a key gets a spare key
for that press, given back right after).
Storage: the game's INI, [SadoQoL] "Bind <input>": 0 nothing, -1 attack-move, n > 0 the game's keybinding id.
Labels: SQ_OPT_TXT_<n> = SadoQoL setup.tra @n, written at install (SadoQoL.tp2).
--]]

SQMB = SQMB or {}
local T = SQMB

T.ATKM = -1
local L = {
	nothing = "SQ_OPT_TXT_1132", atkm = "SQ_OPT_TXT_1133",
}
-- input id, SDL button (or wheel axis + sign), label
T.INPUTS = {
	{ 'Middle', 2, "SQ_OPT_TXT_1137" },
	{ 'B4', 4, "SQ_OPT_TXT_1138" }, { 'B5', 5, "SQ_OPT_TXT_1139" }, { 'B6', 6, "SQ_OPT_TXT_1140" },
	{ 'B7', 7, "SQ_OPT_TXT_1141" }, { 'B8', 8, "SQ_OPT_TXT_1142" },
	{ 'TiltLeft', 'x-', "SQ_OPT_TXT_1590" }, { 'TiltRight', 'x+', "SQ_OPT_TXT_1591" },
	{ 'WheelUp', 'y+', "SQ_OPT_TXT_1588", modOnly = true }, { 'WheelDown', 'y-', "SQ_OPT_TXT_1589", modOnly = true },
}
T.MODS = { { '', "SQ_OPT_TXT_1583" }, { 'Shift', "SQ_OPT_TXT_1584" }, { 'Ctrl', "SQ_OPT_TXT_1585" }, { 'Alt', "SQ_OPT_TXT_1586" } }
T.DEFAULTS = { B4 = T.ATKM }

-- The most used actions, first in the page's list (the game's keybinding ids, BGEE.LUA `keybindings`).
T.TOP = { 33, 29, 24, 1, 5, 4, 2, 6, 7, 67, 20, 19, 10, 16, 17, 18, 21, 40, 30, 32, 25, 38, 39 }

-- ---- bindings ----
T.binds = T.binds or nil
local OLD = { Middle = 'Middle', B4 = 'B4', B5 = 'B5', B6 = 'B6', B7 = 'B7', B8 = 'B8',
	ShiftWheelUp = 'ShiftUp', ShiftWheelDown = 'ShiftDown', CtrlWheelUp = 'CtrlUp', CtrlWheelDown = 'CtrlDown' }
local function readBind(key)
	local ok, v = pcall(Infinity_GetINIValue, 'SadoQoL', 'Bind ' .. key, -999)
	v = ok and tonumber(v) or -999
	if v ~= -999 then return v end
	-- before 2026-10-28: "Mouse <input>" = 0 nothing / 1 attack-move / 2 trap aura / 3 FPS (only attack-move stays)
	if OLD[key] then
		local ok2, o = pcall(Infinity_GetINIValue, 'SadoQoL', 'Mouse ' .. OLD[key], -999)
		o = ok2 and tonumber(o) or -999
		if o ~= -999 then return o == 1 and T.ATKM or 0 end
	end
	return T.DEFAULTS[key] or 0
end
function SQMB_Bind(key)
	T.binds = T.binds or {}
	if T.binds[key] == nil then T.binds[key] = readBind(key) end
	return T.binds[key]
end
function SQMB_SetBind(key, code)
	T.binds = T.binds or {}
	T.binds[key] = code
	pcall(Infinity_SetINIValue, 'SadoQoL', 'Bind ' .. key, code)
end
function SQMB_InputShown(input, mod) return not (input.modOnly and mod == '') end

-- ---- actions ----
local function keybinding(id)
	if type(keybindings) ~= 'table' then return nil end
	for _, cat in ipairs(keybindings) do
		for _, kb in ipairs(cat) do
			if kb[1] == id then return kb end
		end
	end
end
-- the game's label of a keybinding (a uiStrings key, or a strref for the spells)
local function kbLabel(kb)
	-- as the game's getHotkeyName (UI.MENU)
	local ok, s = pcall(getUiString, kb[4])
	if ok and s and s ~= kb[4] then return s end
	local n = tonumber(kb[4])
	return n and Infinity_FetchString(n) or tostring(kb[3])
end
function SQMB_ActionLabel(code)
	if code == 0 then return L.nothing end
	if code == T.ATKM then return L.atkm end
	local kb = keybinding(code)
	return kb and kbLabel(kb) or ('#' .. tostring(code))
end
-- The page's list: { code =, text =, header = true/nil }. Short: the most used; all: every keybinding by category.
function SQMB_Actions(all)
	local out = { { code = 0, text = L.nothing } }
	if SQAttackMove_AtCursor or SQAttackMove_Begin then out[#out + 1] = { code = T.ATKM, text = L.atkm } end
	if not all then
		for _, id in ipairs(T.TOP) do
			local kb = keybinding(id)
			if kb then out[#out + 1] = { code = id, text = kbLabel(kb) } end
		end
		return out
	end
	local seen = {}
	for c, cat in ipairs(keybindings or {}) do
		local kc = keycategories and keycategories[c]
		local ok, h = pcall(getUiString, kc and kc[2] or '')
		out[#out + 1] = { header = true, text = ok and h or '' }
		for _, kb in ipairs(cat) do
			if not seen[kb[1]] then
				seen[kb[1]] = true
				out[#out + 1] = { code = kb[1], text = kbLabel(kb) }
			end
		end
	end
	return out
end

-- ---- running an action ----
local function keymap() return game and game.m_pKeymap end
local function keyOf(id)
	local ok, v = pcall(function() return keymap():get(id - 1) end)
	return ok and tonumber(v) or 0
end
-- a key no action uses (for an action without a key): Delete, backslash, backquote, brackets
local SPARE = { 127, 92, 96, 91, 93 }
local function spareKey()
	local used = {}
	for i = 0, 600 do
		local ok, v = pcall(function() return keymap():get(i) end)
		if not ok then break end
		used[tonumber(v) or 0] = true
	end
	for _, k in ipairs(SPARE) do if not used[k] then return k end end
end
-- the spare key lent to an action goes back after the engine read the press (the next event, or the release)
local function giveBack()
	local r = T.lent
	if not r then return end
	T.lent = nil
	pcall(function() keymap():set(r.index, r.old) end)
end
local function keyFor(id)
	local k = keyOf(id)
	if k ~= 0 then return k end
	k = spareKey()
	if not k then return nil end
	local ok = pcall(function() keymap():set(id - 1, k) end)
	if not ok or keyOf(id) ~= k then return nil end
	T.lent = { index = id - 1, old = 0, at = Infinity_GetClockTicks() }
	return k
end
-- rewrites the mouse event into the action's key press / release
local function asKey(event, id, down)
	local k = down and keyFor(id) or (T.held and T.held[id])
	if not k then return false end
	event.type = down and SDL_EventType.SDL_KEYDOWN or SDL_EventType.SDL_KEYUP
	event.key.state = down and 1 or 0
	event.key["repeat"] = 0
	event.key.keysym.sym = k
	event.key.keysym.mod = 0
	T.held = T.held or {}
	T.held[id] = down and k or nil
	return true
end

local function modifier(name)
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left ' .. name)) or EEex_Key_IsDown(EEex_Key_GetFromName('Right ' .. name))
end
local function modName()
	if modifier('Shift') then return 'Shift' end
	if modifier('Ctrl') then return 'Ctrl' end
	if modifier('Alt') then return 'Alt' end
	return ''
end
-- the bound key ('ShiftB4'...) of an SDL event, or nil
local function inputFor(event, released)
	local mod = modName()
	if event.type == (released and SDL_EventType.SDL_MOUSEBUTTONUP or SDL_EventType.SDL_MOUSEBUTTONDOWN) then
		for _, inp in ipairs(T.INPUTS) do
			if inp[2] == event.button.button then return mod .. inp[1] end
		end
	elseif not released and event.type == SDL_EventType.SDL_MOUSEWHEEL then
		local axis = event.wheel.x ~= 0 and (event.wheel.x > 0 and 'x+' or 'x-')
			or (event.wheel.y ~= 0 and (event.wheel.y > 0 and 'y+' or 'y-'))
		for _, inp in ipairs(T.INPUTS) do
			if inp[2] == axis and SQMB_InputShown(inp, mod) then return mod .. inp[1] end
		end
	end
end

-- a button held keeps the action it started with (its release ends that one, even if Shift was let go)
T.down = T.down or {}
local function onEvent(event)
	if T.lent and Infinity_GetClockTicks() > T.lent.at + 50 then giveBack() end
	if worldScreen ~= e:GetActiveEngine() then return false end
	if event.type == SDL_EventType.SDL_MOUSEBUTTONUP then
		local d = T.down[event.button.button]
		if not d then return false end
		T.down[event.button.button] = nil
		if d == T.ATKM then
			if SQAttackMove_End then SQAttackMove_End() end
			return true
		end
		local r = asKey(event, d, false)
		giveBack()
		return not r and true or false
	end
	local key = inputFor(event)
	local code = key and SQMB_Bind(key) or 0
	if code == 0 then return false end
	if event.type == SDL_EventType.SDL_MOUSEBUTTONDOWN then T.down[event.button.button] = code end
	if code == T.ATKM then
		if event.type == SDL_EventType.SDL_MOUSEBUTTONDOWN and SQAttackMove_Begin then SQAttackMove_Begin()
		elseif SQAttackMove_AtCursor then SQAttackMove_AtCursor() end
		return true
	end
	-- rewritten in place: the engine reads it as the action's key (false = not suppressed)
	if asKey(event, code, true) then return false end
	return true
end

if not T.hooked and EEex_Key_Hook_AfterEventsPoll then
	T.hooked = true
	local orig = EEex_Key_Hook_AfterEventsPoll
	EEex_Key_Hook_AfterEventsPoll = function(event)
		local ok, consumed = pcall(onEvent, event)
		if not ok then T.lastError = tostring(consumed) elseif consumed then return true end
		return orig(event)
	end
end
