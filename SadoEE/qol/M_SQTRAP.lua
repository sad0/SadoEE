--[[
SadoQoL component #1 - Passive trap detection (John 2026-10-17).

The party's thieves spot traps on their own, without the Find Traps mode: they can walk, fight and cast as usual.
Every PERIOD ms, each thief rolls once for each armed, undetected trap (trap regions, trapped containers and doors)
within her sight (VISUALRANGE, line of sight). Rule: her Find Traps skill (stat TRAPS) against the trap's detection
difficulty, like the game. Optional: within SLACK points below the difficulty, a (SLACK - gap) % chance per roll (off by default). On success the trap is marked detected exactly like the Find Traps mode does (m_trapDetected)
and a "Trap found" line shows over her head.

Only reads/sets m_trapDetected: no conflict with BGBot (its own tick menu, its REMOTE_DISARM disarms on its own).
Tuning: edit the SQTrap table below in override/M_SQTRAP.lua, or live from the EEex console, e.g.
  SQTrap.PERIOD = 2000   SQTrap.RANGE = 600   SQTrap.SLACK = 0   SQTrap.ENABLED = false
--]]

SQTrap = SQTrap or {}
local T = SQTrap

T.ENABLED = T.ENABLED ~= false
T.PERIOD  = T.PERIOD  or 3000   -- ms between two rolls (one roll per trap per thief per period)
T.RANGE   = T.RANGE             -- px; nil = the thief's own sight (VISUALRANGE stat x 32, 448 by default)
T.LOS     = T.LOS ~= false      -- also require a line of sight (the engine's CGameArea:CheckLOS)
T.SLACK   = T.SLACK   or 0      -- below the difficulty: (SLACK - gap) % per roll; 0 = strict, like the game
T.HEAD    = T.HEAD ~= false     -- "Trap found" over the thief's head
T.SCAN_MS = T.SCAN_MS or 5000   -- the area's list of armed traps is rebuilt this often (or on area change)
T.FOUND_STRREF = tonumber("SQ_TRAP_FOUND_STRREF")  -- written by SadoQoL.tp2 (localized "Trap found")

local STAT_TRAPS, STAT_VISUALRANGE = 28, 147
local THIEF_CLASSES = { [4] = true, [9] = true, [10] = true, [13] = true, [15] = true }  -- thief + multis
local TYPE_CONTAINER, TYPE_DOOR, TYPE_TRIGGER = 17, 33, 65
local DEAD_STATES = 0x800 + 0x80 + 0x40 + 0x40000  -- dead, frozen, stone, blind

local function get(o, name) return o[name] end
local function field(o, name)  -- nil when the type has no such field (no closure: called a lot)
	local ok, v = pcall(get, o, name)
	if ok then return v end
end

-- The red outline: m_drawPoly (400, as the Find Traps mode sets it) and, for regions, the "detectable" flag 0x8.
local DRAW_POLY = 400
local function setPoly(t) if t.m_drawPoly == 0 then t.m_drawPoly = DRAW_POLY end end
-- A region that lacked the flag is a scripted, undisarmable trap (AR0125 horrors, Sarevok's skull): remembered in
-- the area variable SQND_<x>_<y> (saved with the area) for component #2 (auto-disarm).
local function setDetectable(area, t)
	if EEex_BAnd(t.m_dwFlags, 0x8) == 0 then
		local b = t.m_rBounding
		EEex_Area_SetVariableInt(area, 'SQND_' .. b.left .. '_' .. b.top, 1)
		t.m_dwFlags = EEex_BOr(t.m_dwFlags, 0x8)
	end
end
local function markDrawn(area, t, ty)
	pcall(setPoly, t)
	if ty == TYPE_TRIGGER then pcall(setDetectable, area, t) end
end

-- Scripted triggers flagged "trapped" in the area file that are not traps at all: bounty hunter triggers (REPTRAP,
-- ACT* scripts), and SoD's story triggers (BD1000: Corwin romance, banters, the camp region covering the whole
-- map): disarm difficulty 0, or a region that lacked the "detectable" flag and is over FAKE_PX on a side.
local FAKE_PX = 600
local function isFake(area, t)
	local scr = string.upper(field(t, 'm_scriptRes') and t.m_scriptRes:get() or '')
	if scr:sub(1, 3) == 'ACT' or scr:sub(1, 7) == 'REPTRAP' then return true end
	if (field(t, 'm_trapDisarmingDifficulty') or 1) == 0 then return true end
	local b = field(t, 'm_rBounding')
	if not b then return false end
	local lacked = EEex_BAnd(t.m_dwFlags, 0x8) == 0 or EEex_Area_GetVariableInt(area, 'SQND_' .. b.left .. '_' .. b.top) == 1
	return lacked and (b.right - b.left > FAKE_PX or b.bottom - b.top > FAKE_PX)
end

-- A fake trap shown by an older version of the mod (saved as detected): hidden again, flag restored.
local function unmark(area, t)
	local b = t.m_rBounding
	t.m_trapDetected, t.m_drawPoly = 0, 0
	if EEex_Area_GetVariableInt(area, 'SQND_' .. b.left .. '_' .. b.top) == 1 then
		t.m_dwFlags = EEex_BAnd(t.m_dwFlags, 0xFFFFFFF7)
		EEex_Area_SetVariableInt(area, 'SQND_' .. b.left .. '_' .. b.top, 0)
	end
end

-- Rebuilds the candidate list: armed, undetected traps of the visible area, with their box (world px).
local function scan(area)
	local out = {}
	for _, l in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[l], function(id)
			local ob = EEex_GameObject_Get(id)
			local ty = ob and ob.m_objectType
			if ty == TYPE_TRIGGER or ty == TYPE_CONTAINER or ty == TYPE_DOOR then
				local t = EEex_GameObject_CastUserType(ob)
				-- Detected traps lose their red outline on a reload (m_drawPoly is not saved, even for traps the
				-- game found itself): put it back, with the "detectable" flag (0x8) regions need to be drawn.
				local armed, found = field(t, 'm_trapActivated') == 1, field(t, 'm_trapDetected')
				local fake = ty == TYPE_TRIGGER and armed and isFake(area, t)
				if fake and found == 1 then pcall(unmark, area, t) found = 0 end
				if armed and found == 1 then markDrawn(area, t, ty) end
				if armed and found == 0 then
					-- Fake traps stay hidden. Undisarmable traps (disarm 100, Sarevok's temple) are real: the game's
					-- Find Traps shows them too.
					if not fake then
						local b = field(t, 'm_rBounding')
						local x1, y1, x2, y2
						if b then x1, y1, x2, y2 = b.left, b.top, b.right, b.bottom end
						if not x1 or (x1 == 0 and x2 == 0) then
							x1, y1 = t.m_pos.x, t.m_pos.y
							x2, y2 = x1, y1
						end
						out[#out + 1] = { id = id, diff = field(t, 'm_trapDetectionDifficulty') or 0,
							x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
					end
				end
			end
		end)
	end
	return out
end

-- Line of sight with the engine's own check; turned off for good (range only) if the binding misbehaves.
local function los(area, sp, ax, ay, bx, by)
	if not T.LOS or T.losBroken then return true end
	local ok, res = pcall(function()
		return EEex_RunWithStackManager({
			{ ["name"] = "a", ["struct"] = "CPoint", ["constructor"] = { ["variant"] = "fromXY", ["args"] = { ax, ay } } },
			{ ["name"] = "b", ["struct"] = "CPoint", ["constructor"] = { ["variant"] = "fromXY", ["args"] = { bx, by } } } },
			function(m)
				return area:CheckLOS(m:getUD("a"), m:getUD("b"), sp:virtual_GetVisibleTerrainTable(), 0, 0)
			end)
	end)
	if not ok then
		T.losBroken = tostring(res)
		print('[SadoQoL] trap detection: CheckLOS unavailable, range only (' .. T.losBroken .. ')')
		return true
	end
	return res ~= 0 and res ~= false
end

local function thieves(area)
	local out = {}
	-- members 7+ of the >6-party prototype (M_PSXP7.lua) too, when it is installed
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local sp = EEex_Sprite_GetInPortrait(p)
		-- SQTRAPOFF: the player turned this thief's detection off with the Find Traps button (#9 lasting modes)
		if sp and EEex_UDEqual(sp.m_pArea, area) and THIEF_CLASSES[sp.m_typeAI.m_Class]
				and EEex_BAnd(sp.m_derivedStats.m_generalState, DEAD_STATES) == 0
				and EEex_Sprite_GetLocalInt(sp, 'SQTRAPOFF') ~= 1 then
			local skill = EEex_Sprite_GetStat(sp, STAT_TRAPS) or 0
			if skill > 0 then
				local vr = EEex_Sprite_GetStat(sp, STAT_VISUALRANGE) or 0
				out[#out + 1] = { sp = sp, skill = skill, range = T.RANGE or (vr > 0 and vr * 32 or 448) }
			end
		end
	end
	return out
end

local function detect(area)
	local now = Infinity_GetClockTicks()
	local key = area.m_resref:get()
	if key ~= T.areaKey or not T.list or now - (T.scanAt or 0) >= T.SCAN_MS then
		T.areaKey, T.scanAt, T.list = key, now, scan(area)
	end
	if #T.list == 0 then return end
	local team = thieves(area)
	if #team == 0 then return end
	for i = #T.list, 1, -1 do
		local trap = T.list[i]
		local ob = EEex_GameObject_Get(trap.id)
		local t = ob and EEex_GameObject_CastUserType(ob)
		if not t or field(t, 'm_trapActivated') ~= 1 or field(t, 'm_trapDetected') ~= 0 then
			table.remove(T.list, i)  -- gone, sprung, disarmed or already found
		else
			for _, th in ipairs(team) do
				local px, py = th.sp.m_pos.x, th.sp.m_pos.y
				-- nearest point of the trap box to the thief
				local nx = math.max(trap.x1, math.min(px, trap.x2))
				local ny = math.max(trap.y1, math.min(py, trap.y2))
				-- Sight is an ellipse on screen (isometric view): vertical distances count 4/3 (like the engine's LOS).
				local dx, dy = nx - px, (ny - py) * 4 / 3
				if dx * dx + dy * dy <= th.range * th.range then
					local gap = trap.diff - th.skill
					local hit = gap <= 0 or (T.SLACK > gap and math.random(100) <= T.SLACK - gap)
					-- Seen if ANY of these points is in sight: nearest point of the box, its center, its corners.
					local seen = false
					if hit then
						local cx, cy = (trap.x1 + trap.x2) / 2, (trap.y1 + trap.y2) / 2
						for _, q in ipairs({ { nx, ny }, { cx, cy }, { trap.x1, trap.y1 }, { trap.x2, trap.y1 },
								{ trap.x1, trap.y2 }, { trap.x2, trap.y2 } }) do
							if los(area, th.sp, px, py, math.floor(q[1]), math.floor(q[2])) then seen = true break end
						end
					end
					if seen then
						t.m_trapDetected = 1
						markDrawn(area, t, ob.m_objectType)
						table.remove(T.list, i)
						if T.HEAD and T.FOUND_STRREF and T.FOUND_STRREF >= 0 then
							pcall(EEex_Action_ExecuteResponseStringOnAIBaseInstantly,
								'DisplayStringHead(Myself,' .. T.FOUND_STRREF .. ')', th.sp)
						end
						break
					end
				end
			end
		end
	end
end

function SQTrap_Tick()
	if not T.ENABLED then return false end
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + T.PERIOD
	local area = EEex_Area_GetVisible()
	if area and EEex_Sprite_GetInPortrait(0) then
		local ok, err = pcall(detect, area)
		if not ok then T.lastError = tostring(err) end
	end
	return false
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQTRAP_TICK') then Infinity_PushMenu('SQTRAP_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQTRAP') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
