--[[
Full pages over the world (John 2026-10-24): one helper every custom page opts into. Requires EEex. BGEE / BG2EE /
EET, v2.6.6 and v2.7.3.

While a page is open:
1. The game is paused. Closing the last page restores the state from before: paused before -> stays paused,
   running before -> runs again. A pause the player removes by hand while the page is open is left alone.
2. The world behind is darkened by a veil (PSXPG_VEIL in PSXPG.menu: black at the opacity of the game's own
   SQRECR shade, the same look as the world behind the engine's store screen; with the game's "Greyscale on pause"
   option the paused world is grey too). The veil swallows the clicks on the world, the left sidebar and the action
   bar; it stops at the party portrait bar (RIGHT_SIDEBAR, 80 wide) and at the big-party bar left of it (PSXP7_BAR),
   which stay usable: a click on a portrait makes that character the selected one, and the page is told (onChar).
3. Leaving the world screen (a hotkey opened the inventory...) closes the pages.

Use (the page menu itself keeps its own look; push nothing else):
	PSXPG_Open('MY_PAGE', { onChar = function(id) ... end, onClose = function() ... end })
	PSXPG_Close('MY_PAGE')
	PSXPG_CharID()   -- the selected character's id (the page's "active" character), or nil
Console: PSXPG.DEBUG = true
--]]

PSXPG = PSXPG or {}
local P = PSXPG
P.DEBUG = P.DEBUG or false
P.pages = P.pages or {}   -- open pages, oldest first: { name =, opts = }
P.SIDEBAR_W = 80          -- RIGHT_SIDEBAR's width (UI.MENU)
P.SETTLE_MS = 1500        -- after opening: the page (re)pauses the game, e.g. when the dialogue that opened it ends

local function log(...)
	if P.DEBUG then print('[PSXPG] ' .. string.format(...)) end
end

-- Infinity_IsMenuOnStack returns 1 / nil, not booleans.
local function onStack(name) return Infinity_IsMenuOnStack(name) and true or false end

local function onWorld()
	return worldScreen ~= nil and e:GetActiveEngine() == worldScreen
end

local function isPaused()
	local ok, paused = pcall(function() return worldScreen:CheckIfPaused() end)
	return ok and paused == true
end

local function togglePause()
	pcall(function() worldScreen:TogglePauseGame(true) end)
end

local function find(name)
	for i, pg in ipairs(P.pages) do
		if pg.name == name then return i, pg end
	end
end

-----------------------
-- Pause              --
-----------------------

-- Pauses when the game runs, during the settle time after an open; past it, the player's own unpause stands.
local function holdPause(now)
	if #P.pages == 0 or not onWorld() then return end
	if P.settleUntil and now < P.settleUntil and not isPaused() then
		togglePause()
		if isPaused() then P.wePaused = true log('paused') end
	end
end

-- The last page closed: runs again only when it ran before and the game is still paused by us.
local function releasePause()
	local ours = P.wePaused
	P.wePaused, P.settleUntil = nil, nil
	if ours and isPaused() then togglePause() log('resumed') end
end

-----------------------
-- Veil               --
-----------------------

-- The veil covers the screen up to the portrait bars (none when the game's bar is hidden).
local function veilWidth(sw)
	if not onStack('RIGHT_SIDEBAR') then return sw end
	local bar = 0
	if PSXP7_BarWidth then
		local ok, w = pcall(PSXP7_BarWidth)
		if ok and type(w) == 'number' then bar = w end
	end
	return math.max(0, sw - P.SIDEBAR_W - bar)
end

-- The veil sits right under the lowest open page: popped and pushed again under it.
local function pushVeil()
	if onStack('PSXPG_VEIL') then Infinity_PopMenu('PSXPG_VEIL') end
	P.layoutKey = nil
	Infinity_PushMenu('PSXPG_VEIL')
end

-- The world's own menus the engine pushes again over the page (when the dialogue that opened it ends...): the veil
-- and the pages go back on top of them.
P.WORLD_MENUS = P.WORLD_MENUS or { 'WORLD_ACTIONBAR', 'WORLD_MESSAGES', 'LEFT_SIDEBAR', 'LEFT_SIDEBAR_BOTTOM',
	'LEFT_SIDEBAR_HIDDEN', 'WORLD_DIALOG' }
local function worldMenusKey()
	local t = {}
	for i, m in ipairs(P.WORLD_MENUS) do t[i] = onStack(m) and '1' or '0' end
	return table.concat(t)
end
local function raise()
	for i = #P.pages, 1, -1 do
		if onStack(P.pages[i].name) then Infinity_PopMenu(P.pages[i].name) end
	end
	pushVeil()
	for _, pg in ipairs(P.pages) do Infinity_PushMenu(pg.name) end
	log('raised')
end

-- PSXPG_TICK's enabled check, every frame: layout, pause, the menus over the page, the selected character.
function PSXPG_Tick()
	if #P.pages == 0 then return false end
	if not onWorld() then
		PSXPG_CloseAll()
		return false
	end
	-- a page popped without PSXPG_Close (its own Close button...): closed here, the veil goes with the last one
	for i = #P.pages, 1, -1 do
		if not onStack(P.pages[i].name) then PSXPG_Close(P.pages[i].name) end
	end
	if #P.pages == 0 then return false end
	local wk = worldMenusKey()
	if P.worldKey and wk ~= P.worldKey then
		-- one of the world's menus came back (absent -> present): pushed after the page
		local before = P.worldKey
		for i = 1, #wk do
			if wk:sub(i, i) == '1' and before:sub(i, i) == '0' then raise() break end
		end
	end
	P.worldKey = wk
	local now = Infinity_GetClockTicks()
	holdPause(now)
	local sw, sh = Infinity_GetScreenSize()
	local w = veilWidth(sw)
	local key = w .. 'x' .. sh
	if key ~= P.layoutKey then
		P.layoutKey = key
		pcall(Infinity_SetArea, 'PSXPG_SHADE', 0, 0, w, sh)
		pcall(Infinity_SetArea, 'PSXPG_BLOCK', 0, 0, w, sh)
	end
	if not P.nextChar or now >= P.nextChar then
		P.nextChar = now + 100
		local id = PSXPG_CharID()
		if id ~= P.charID then
			P.charID = id
			for _, pg in ipairs(P.pages) do
				if pg.opts.onChar then
					local ok, err = pcall(pg.opts.onChar, id)
					if not ok then print('[PSXPG] ' .. pg.name .. ' onChar: ' .. tostring(err)) end
				end
			end
		end
	end
	return true
end

-----------------------
-- Pages              --
-----------------------

-- The selected character (the one the page shows): its id, or nil.
function PSXPG_CharID()
	local ok, id = pcall(EEex_Sprite_GetSelectedID)
	if ok and id and id ~= -1 then return id end
end

function PSXPG_IsOpen(name)
	if name then return find(name) ~= nil end
	return #P.pages > 0
end

-- Opens the page menu `name` over the veil (on the world screen only). opts: onChar(id), onClose().
function PSXPG_Open(name, opts)
	if not onWorld() then return false end
	if find(name) then return true end
	if #P.pages == 0 then
		P.wePaused = nil
		P.charID = PSXPG_CharID()
		if not isPaused() then
			togglePause()
			P.wePaused = isPaused() or nil
		end
		pushVeil()
		P.worldKey = worldMenusKey()
	end
	if not onStack('PSXPG_TICK') then Infinity_PushMenu('PSXPG_TICK') end
	P.settleUntil = Infinity_GetClockTicks() + P.SETTLE_MS
	table.insert(P.pages, { name = name, opts = opts or {} })
	if onStack(name) then Infinity_PopMenu(name) end
	Infinity_PushMenu(name)
	log('open %s (paused by us: %s)', name, tostring(P.wePaused))
	return true
end

function PSXPG_Close(name)
	local i, pg = find(name)
	if not i then
		if onStack(name) then Infinity_PopMenu(name) end
		return
	end
	table.remove(P.pages, i)
	if onStack(name) then Infinity_PopMenu(name) end
	if pg.opts.onClose then pcall(pg.opts.onClose) end
	if #P.pages == 0 then
		if onStack('PSXPG_VEIL') then Infinity_PopMenu('PSXPG_VEIL') end
		releasePause()
	end
	log('close %s', name)
end

function PSXPG_CloseAll()
	for i = #P.pages, 1, -1 do PSXPG_Close(P.pages[i].name) end
end

if not P.listenersAdded then
	P.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function()
		EEex_Menu_LoadFile('PSXPG')
	end)
	EEex_GameState_AddInitializedListener(function()
		P.pages, P.wePaused, P.settleUntil, P.layoutKey = {}, nil, nil, nil
	end)
end
