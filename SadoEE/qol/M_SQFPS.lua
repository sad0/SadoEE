--[[
SadoQoL component #5 - FPS counter (John 2026-10-20).

Top center of the game screen: frames per second over the last half second, plus the slowest frame of that
window (a stutter shows there even when the average looks fine). Green >= 50 fps, yellow >= 30, red below.
F12 shows / hides it (remembered in Baldur.ini).
Tuning live from the EEex console, e.g.  SQFps.KEY = 'F8'   SQFps.WINDOW = 1000
--]]

SQFps = SQFps or {}
local T = SQFps

T.WINDOW = T.WINDOW or 500      -- ms averaged per refresh
T.KEY    = T.KEY or 'F12'
T.frames, T.worst = T.frames or 0, T.worst or 0
T.text = T.text or ''

local function ini()
	local ok, v = pcall(Infinity_GetINIValue, 'SadoQoL', 'FPS', 1)
	return ok and tonumber(v) or 1
end
if T.on == nil then T.on = ini() ~= 0 end

local function color(fps)
	if fps >= 50 then return '^0xff40ff40' end
	if fps >= 30 then return '^0xff00e0ff' end
	return '^0xff4040ff'
end

-- Runs every frame (the menu's enabled check): counting only, the text is rebuilt twice a second.
function SQFps_Tick()
	local now = Infinity_GetClockTicks()
	if T.last then
		local gap = now - T.last
		if gap > T.worst then T.worst = gap end
	end
	T.last = now
	T.frames = T.frames + 1
	T.start = T.start or now
	local dt = now - T.start
	if dt >= T.WINDOW then
		local fps = T.frames * 1000 / dt
		T.text = string.format('%s%d FPS^-  ^0xffc0c0c0max %d ms^-', color(fps), math.floor(fps + 0.5), T.worst)
		T.frames, T.worst, T.start = 0, 0, now
		local sw = Infinity_GetScreenSize()
		pcall(Infinity_SetArea, 'SQFPS_TEXT', math.floor(sw / 2 - 90), 4, 180, 24)
	end
	return false
end

function SQFps_On()
	return T.on and e:GetActiveEngine() == worldScreen
end

function SQFps_Text()
	return T.text
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQFPS_TICK') then Infinity_PushMenu('SQFPS_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQFPS') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
	EEex_Key_AddPressedListener(function(key)
		if key == EEex_Key_GetFromName(T.KEY) then
			T.on = not T.on
			pcall(Infinity_SetINIValue, 'SadoQoL', 'FPS', T.on and 1 or 0)
		end
	end)
end
