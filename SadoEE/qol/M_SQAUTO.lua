--[[
SadoQoL component #2 - Automatic trap disarming (John 2026-10-18).

Out of combat, every idle thief of the party whose trap detection is on (component #0; not turned off with the
Find Traps button, #9) goes and disarms the nearest detected trap she can disarm (John 2026-10-23: all of them, not
only the best one); two thieves never take the same trap:
  - only traps already detected (by component #0 or the game's own Find Traps), armed, within her sight;
  - only if her Find Traps skill >= the trap's disarm difficulty, and never the scripted undisarmable ones
    (regions that did not have the "detectable" flag; component #0 records them as area variables SQND_<x>_<y>);
  - one try per trap (a failed one is left to the player); any order the player gives her wins (the trap is
    then tried again later, once she is idle);
  - "I'll take care of the trap" over her head when she leaves.
While one works, BGBot.cmb.busy[portrait] is set (BGBot's Lua brain leaves her alone).

For BGBot: SQAuto_Request(trapId) forces a try on that trap by the best thief (no idle/combat/range/once checks) and
SQAuto_Status(trapId) returns 'working', 'done', 'failed' or 'none'.
Tuning: SQAuto.ENABLED, SQAuto.RANGE (px, nil = sight), SQAuto.PERIOD (ms between two looks).
--]]

SQAuto = SQAuto or {}
local S = SQAuto

S.ENABLED = S.ENABLED ~= false
S.PERIOD  = S.PERIOD or 1000
S.RANGE   = S.RANGE
S.REACH   = S.REACH or 120   -- she walks to this distance of the trap before RemoveTraps (dropped from afar)
S.tried   = S.tried or {}    -- [areaKey .. id] = true
S.results = S.results or {}  -- [trapId] = 'done' | 'failed'
S.jobs    = S.jobs or {}     -- [thief id] = running job

local A_NONE, A_MOVE, A_REMOVETRAPS = 0, 23, 28
local TYPE_CONTAINER, TYPE_DOOR, TYPE_TRIGGER = 17, 33, 65
local THIEF_CLASSES = { [4] = true, [9] = true, [10] = true, [13] = true, [15] = true }
local DEAD_STATES = 0x800 + 0x80 + 0x40 + 0x40000

local function field(o, name)
	local ok, v = pcall(function() return o[name] end)
	if ok then return v end
end

local function alive(sp)
	return EEex_BAnd(sp.m_derivedStats.m_generalState, DEAD_STATES) == 0
end

local function queueEmpty(sp)
	local empty = true
	EEex_Utility_IterateCPtrList(sp.m_queuedActions, function() empty = false return true end)
	return empty
end

local function lastPortrait()
	return PSXP7_LastPortrait and PSXP7_LastPortrait() or 5
end

-- living thieves of the area with a Find Traps skill and their detection on: { { sp, skill }, ... }
local function thieves(area)
	local out = {}
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and EEex_UDEqual(sp.m_pArea, area) and THIEF_CLASSES[sp.m_typeAI.m_Class] and alive(sp)
				and EEex_Sprite_GetLocalInt(sp, 'SQTRAPOFF') ~= 1 then
			local s = EEex_Sprite_GetStat(sp, 28) or 0
			if s > 0 then out[#out + 1] = { sp, s } end
		end
	end
	return out
end

local function bestThief(area)
	local best, skill
	for _, t in ipairs(thieves(area)) do
		if not skill or t[2] > skill then best, skill = t[1], t[2] end
	end
	return best, skill
end

local function jobOnTrap(trapId)
	for _, job in pairs(S.jobs) do
		if job.trap == trapId then return job end
	end
end

-- Any living party member sees an enemy (one parsed trigger, evaluated once per member per look).
local function inCombat(area)
	S.seeEnemy = S.seeEnemy or EEex_Trigger_ParseConditionalString('See(NearestEnemyOf(Myself))')
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and EEex_UDEqual(sp.m_pArea, area) and alive(sp)
				and EEex_Trigger_EvalScriptFileConditionalAsAIBase(S.seeEnemy, sp) then
			return true
		end
	end
	return false
end

local function box(t)
	local b = field(t, 'm_rBounding')
	if b and not (b.left == 0 and b.right == 0) then return b.left, b.top, b.right, b.bottom end
	return t.m_pos.x, t.m_pos.y, t.m_pos.x, t.m_pos.y
end

-- Scripted traps that cannot be disarmed: regions without the "detectable" flag in the area file.
function SQAuto_Undisarmable(area, t, ty)
	if ty ~= TYPE_TRIGGER then return false end
	local x1, y1 = box(t)
	if EEex_Area_GetVariableInt(area, 'SQND_' .. x1 .. '_' .. y1) == 1 then return true end
	return EEex_BAnd(t.m_dwFlags, 0x8) == 0 -- not marked (component #0 absent): the original flag is still there
end

-- The nearest detected, armed trap the thief can disarm, within her sight, that no other thief is on.
local function pickTrap(area, thief, skill)
	local px, py = thief.m_pos.x, thief.m_pos.y
	local vr = EEex_Sprite_GetStat(thief, 147) or 0
	local range = S.RANGE or (vr > 0 and vr * 32 or 448)
	local key, best, bestD = area.m_resref:get(), nil, nil
	for _, l in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[l], function(id)
			local ob = EEex_GameObject_Get(id)
			local ty = ob and ob.m_objectType
			if (ty == TYPE_TRIGGER or ty == TYPE_CONTAINER or ty == TYPE_DOOR) and not S.tried[key .. id] and not jobOnTrap(id) then
				local t = EEex_GameObject_CastUserType(ob)
				if field(t, 'm_trapActivated') == 1 and field(t, 'm_trapDetected') == 1
						and (field(t, 'm_trapDisarmingDifficulty') or field(t, 'm_trapRemovalDifficulty') or 999) <= skill
						and not SQAuto_Undisarmable(area, t, ty) then
					local x1, y1, x2, y2 = box(t)
					local nx, ny = math.max(x1, math.min(px, x2)), math.max(y1, math.min(py, y2))
					local dx, dy = nx - px, (ny - py) * 4 / 3
					local d = dx * dx + dy * dy
					if d <= range * range and (not bestD or d < bestD) then best, bestD = { id = id, x = nx, y = ny }, d end
				end
			end
		end)
	end
	return best
end

-- BGBot's Lua combat brain leaves her alone (BGBot.cmb.busy). NOT the LOCALS BGB_BUSY: BGBot's party scripts
-- answer it with a NoAction() block, and a firing script block cancels her walk every round.
local function setBusy(sp, on)
	pcall(function()
		if not (BGBot and BGBot.cmb and BGBot.cmb.busy) then return end
		for p = 0, lastPortrait() do
			local m = EEex_Sprite_GetInPortrait(p)
			if m and m.m_id == sp.m_id then BGBot.cmb.busy[p] = on or nil end
		end
	end)
end

-- Sends `thief` to `trap` ({id, x, y}): walk close first (RemoveTraps is dropped from afar), then disarm.
local function start(area, thief, trap, forced)
	local px, py = thief.m_pos.x, thief.m_pos.y
	local dx, dy = px - trap.x, py - trap.y
	local n = math.sqrt(dx * dx + dy * dy)
	EEex_LuaObject = EEex_GameObject_Get(trap.id)
	if not EEex_LuaObject then return false end
	local job = { thief = thief.m_id, trap = trap.id, key = area.m_resref:get() .. trap.id }
	if EEex_LuaObject.m_objectType ~= TYPE_TRIGGER then
		-- Containers and doors: RemoveTraps only works from their use point (m_pos); from 70 px it is dropped.
		local mx, my = EEex_LuaObject.m_pos.x, EEex_LuaObject.m_pos.y
		if math.abs(px - mx) > 20 or math.abs(py - my) > 20 then
			EEex_Action_QueueResponseStringOnAIBase('MoveToPoint([' .. mx .. '.' .. my .. '])', thief)
			job.dest = { mx, my }
		end
	elseif n > S.REACH then
		local mx, my = math.floor(trap.x + dx / n * S.REACH * 0.6), math.floor(trap.y + dy / n * S.REACH * 0.6)
		EEex_Action_QueueResponseStringOnAIBase('MoveToPoint([' .. mx .. '.' .. my .. '])', thief)
		job.dest = { mx, my }
	end
	if EEex_LuaObject.m_objectType == TYPE_TRIGGER then
		-- Regions: by id (names repeat, "Arrow Trap 3" twice in AR5201). The target is resolved when the action
		-- runs, not when it is queued (EEex_LuaObject has changed by then): write the id into the queued action.
		EEex_Action_QueueResponseStringOnAIBase('RemoveTraps(EEex_LuaObject)', thief)
		EEex_Utility_IterateCPtrList(thief.m_queuedActions, function(a)
			if a.m_actionID == A_REMOVETRAPS then a.m_acteeID.m_Instance = trap.id end
		end)
	else
		-- Containers and doors: the patched id never started (BD0130 sarcophagus); by script name it works.
		local name = EEex_GameObject_CastUserType(EEex_LuaObject).m_scriptName:get()
		EEex_Action_QueueResponseStringOnAIBase('RemoveTraps("' .. name .. '")', thief)
	end
	job.at, job.forced = Infinity_GetClockTicks(), forced
	S.jobs[thief.m_id] = job
	S.results[trap.id] = nil
	setBusy(thief, true)
	if S.GO_STRREF and S.GO_STRREF >= 0 then
		pcall(EEex_Action_ExecuteResponseStringOnAIBaseInstantly, 'DisplayStringHead(Myself,' .. S.GO_STRREF .. ')', thief)
	end
	return true
end

local function finish(job, thief, result)
	S.jobs[job.thief] = nil
	if thief then setBusy(thief, false) end
	if result then
		S.results[job.trap] = result
		if result == 'failed' then S.tried[job.key] = true end
	end
end

-- The player took over: the trap is tried again later, but 3 interruptions in a row and it is left alone (an
-- order that keeps being rewritten would otherwise loop: "I'll take care of the trap" over and over).
local function abandon(job, thief)
	S.abandons = S.abandons or {}
	local key = job.key
	S.abandons[key] = (S.abandons[key] or 0) + 1
	if S.abandons[key] >= 3 then return finish(job, thief, 'failed') end
	return finish(job, thief, nil)
end

-- The running job: done, failed, or overridden by the player.
local function follow(job)
	local thief = EEex_GameObject_Get(job.thief)
	local ob = EEex_GameObject_Get(job.trap)
	if not thief or not alive(thief) then return finish(job, thief, 'failed') end
	if not ob or field(EEex_GameObject_CastUserType(ob), 'm_trapActivated') ~= 1 then return finish(job, thief, 'done') end
	local a = thief.m_curAction.m_actionID
	if a == A_REMOVETRAPS then job.started = true return end
	if a == A_MOVE then
		local d = thief.m_curAction.m_dest
		-- The engine moves an unwalkable destination (a container's use point) to the nearest open spot.
		if job.dest and math.abs(d.x - job.dest[1]) <= 80 and math.abs(d.y - job.dest[2]) <= 80 then return end
		return abandon(job, thief) -- the player sent her elsewhere: tried again later
	end
	if a == A_NONE and queueEmpty(thief) then
		if job.started then return finish(job, thief, 'failed') end
		if Infinity_GetClockTicks() - job.at > 4000 then
			-- The order never started (unreachable?): two such tries and the trap is left to the player.
			S.nostart = S.nostart or {}
			S.nostart[job.key] = (S.nostart[job.key] or 0) + 1
			if S.nostart[job.key] >= 2 then return finish(job, thief, 'failed') end
			return finish(job, thief, nil)
		end
		return
	end
	if a ~= A_NONE then return abandon(job, thief) end -- any other order: the player's
end

function SQAuto_Request(trapId)
	local ob = EEex_GameObject_Get(trapId)
	local area = EEex_Area_GetVisible()
	if not ob or not area then return false end
	local thief = bestThief(area)
	if not thief then return false end
	local old = S.jobs[thief.m_id] or jobOnTrap(trapId)
	if old then finish(old, EEex_GameObject_Get(old.thief), nil) end
	local t = EEex_GameObject_CastUserType(ob)
	local x1, y1, x2, y2 = box(t)
	local px, py = thief.m_pos.x, thief.m_pos.y
	return start(area, thief, { id = trapId, x = math.max(x1, math.min(px, x2)), y = math.max(y1, math.min(py, y2)) }, true)
end

function SQAuto_Status(trapId)
	if jobOnTrap(trapId) then return 'working' end
	return S.results[trapId] or 'none'
end

function SQAuto_Tick()
	if not S.ENABLED then return false end
	local now = Infinity_GetClockTicks()
	if S.pendingOpen and SQAuto_FollowOpen then
		local ok, err = pcall(SQAuto_FollowOpen)
		if not ok then S.lastError = tostring(err) S.pendingOpen = nil end
	end
	if next(S.jobs) and (not S.nextFollow or now >= S.nextFollow) then
		S.nextFollow = now + 250
		for id, job in pairs(S.jobs) do
			local ok, err = pcall(follow, job)
			if not ok then S.lastError = tostring(err) S.jobs[id] = nil end
		end
	end
	if S.next and now < S.next then return false end
	S.next = now + S.PERIOD
	local ok, err = pcall(function()
		if e:GetActiveEngine() ~= worldScreen then return end
		local area = EEex_Area_GetVisible()
		if not area or not EEex_Sprite_GetInPortrait(0) then return end
		local idle = {}
		for _, t in ipairs(thieves(area)) do
			local sp = t[1]
			if not S.jobs[sp.m_id] and sp.m_curAction.m_actionID == A_NONE and queueEmpty(sp) then idle[#idle + 1] = t end
		end
		if #idle == 0 or inCombat(area) then return end
		for _, t in ipairs(idle) do
			local trap = pickTrap(area, t[1], t[2])
			if trap then start(area, t[1], trap, false) end
		end
	end)
	if not ok then S.lastError = tostring(err) end
	return false
end

---------------------
-- Container click --
---------------------
-- John 2026-10-24: a click on a container whose trap is detected sends the party's best disarmer instead (that's
-- all); on a locked one, whoever opens it best: lockpicking (skill >= lock difficulty) or bashing (Strength's
-- bend bars value >= lock difficulty, no die roll either way). Nobody able: a line over the clicker's head and the
-- click is dropped; a second click on the same container within 3 s goes through (the game's own behaviour).
local A_USECONTAINER, A_PICKLOCK, A_BASHDOOR = 112, 145, 148
local BEND_BARS = { [0] = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 50, 55, 60, 65, 70, 75, 80 } -- STRMOD.2DA
S.CLICK = S.CLICK ~= false
S.clickLog = S.clickLog or {}

local function say(sp, strref)
	if strref and strref >= 0 then
		pcall(EEex_Action_ExecuteResponseStringOnAIBaseInstantly, 'DisplayStringHead(Myself,' .. strref .. ')', sp)
	end
end

local function bashValue(sp)
	local str = EEex_Sprite_GetStat(sp, 36) or 0
	local v = BEND_BARS[math.max(0, math.min(25, str))] or 0
	if str == 18 then -- 18/xx: STRMODEX.2DA's bend bars bonus on top (John's 18/100 forced a 30 lock: 20 + 25)
		local ex = EEex_Sprite_GetStat(sp, 37) or 0
		v = v + (ex >= 100 and 25 or ex >= 91 and 20 or ex >= 76 and 15 or ex >= 51 and 10 or ex >= 1 and 5 or 0)
	end
	return v
end

-- The best opener of a lock in the area: sprite, 'pick' | 'bash', margin (>= 0), or nil.
local function bestOpener(area, diff)
	local best, how, margin
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and EEex_UDEqual(sp.m_pArea, area) and alive(sp) then
			local pick = THIEF_CLASSES[sp.m_typeAI.m_Class] and (EEex_Sprite_GetStat(sp, 26) or 0) or 0
			if pick > 0 and pick - diff >= 0 and (not margin or pick - diff > margin) then best, how, margin = sp, 'pick', pick - diff end
			local bash = bashValue(sp)
			if bash - diff >= 0 and (not margin or bash - diff > margin) then best, how, margin = sp, 'bash', bash - diff end
		end
	end
	return best, how, margin
end

-- Walk to the container's use point, then pick or bash its lock (by script name when it has a unique one, else by
-- id written into the queued action).
local function openLock(sp, ob, how)
	local c = EEex_GameObject_CastUserType(ob)
	local mx, my = ob.m_pos.x, ob.m_pos.y
	if math.abs(sp.m_pos.x - mx) > 20 or math.abs(sp.m_pos.y - my) > 20 then
		EEex_Action_QueueResponseStringOnAIBase('MoveToPoint([' .. mx .. '.' .. my .. '])', sp)
	end
	local verb, aid = how == 'pick' and 'PickLock' or 'BashDoor', how == 'pick' and A_PICKLOCK or A_BASHDOOR
	EEex_LuaObject = ob
	EEex_Action_QueueResponseStringOnAIBase(verb .. '(EEex_LuaObject)', sp)
	EEex_Utility_IterateCPtrList(sp.m_queuedActions, function(a)
		if a.m_actionID == aid then a.m_acteeID.m_Instance = ob.m_id end
	end)
	S.clickLog[#S.clickLog + 1] = string.format('%s %s by %s (%s)', verb, c.m_scriptName:get(), EEex_Sprite_GetName(sp), tostring(ob.m_id))
end

-- John 2026-10-24: with the whole party selected, the group's own move orders reach the opener after ours and wipe
-- them (only the clicker walked). So the order is (re)given from the tick until the opener holds it, for 3 s.
local function holdsOrder(sp, aid)
	if sp.m_curAction.m_actionID == aid then return true end
	local found = false
	EEex_Utility_IterateCPtrList(sp.m_queuedActions, function(a) if a.m_actionID == aid then found = true return true end end)
	return found
end

local function followOpen()
	local p = S.pendingOpen
	local now = Infinity_GetClockTicks()
	if not p or now < p.next then return end
	p.next = now + 250
	local sp, ob = EEex_GameObject_Get(p.sp), EEex_GameObject_Get(p.ob)
	local c = ob and EEex_GameObject_CastUserType(ob)
	if not (sp and c) or EEex_BAnd(c.m_dwFlags, 1) == 0 or now > p.till then S.pendingOpen = nil return end
	if not holdsOrder(sp, p.how == 'pick' and A_PICKLOCK or A_BASHDOOR) then openLock(sp, ob, p.how) end
end

SQAuto_FollowOpen = followOpen

local function startOpen(sp, ob, how)
	local now = Infinity_GetClockTicks()
	-- ClearActions lands on her next AI update and wiped the orders queued right after it: the orders come from
	-- the tick, 100 ms later
	if not S.clicker or S.clicker.m_id ~= sp.m_id then EEex_Action_ExecuteResponseStringOnAIBaseInstantly('ClearActions(Myself)', sp) end
	say(sp, how == 'pick' and S.PICK_STRREF or S.BASH_STRREF)
	S.pendingOpen = { sp = sp.m_id, ob = ob.m_id, how = how, next = now + 100, till = now + 3000 }
end

-- One click on a container: true = handled (the click's action is dropped).
local function onContainerClick(sp, ob)
	local area = sp.m_pArea
	local c = EEex_GameObject_CastUserType(ob)
	local now = Infinity_GetClockTicks()
	if S.passId == ob.m_id and now - (S.passAt or 0) < 3000 then S.passId = nil return false end
	if S.pendingOpen and S.pendingOpen.ob == ob.m_id then return true end   -- the opener is already on her way
	local trapped = field(c, 'm_trapActivated') == 1 and field(c, 'm_trapDetected') == 1
	if trapped then
		if jobOnTrap(ob.m_id) then return true end
		local thief, skill = bestThief(area)
		local diff = field(c, 'm_trapRemovalDifficulty') or 999
		if thief and skill >= diff then
			S.tried[area.m_resref:get() .. ob.m_id] = nil
			if thief.m_id ~= sp.m_id then EEex_Action_ExecuteResponseStringOnAIBaseInstantly('ClearActions(Myself)', thief) end
			SQAuto_Request(ob.m_id)
			return true
		end
		say(sp, S.NOTRAP_STRREF)
		S.passId, S.passAt = ob.m_id, now
		return true
	end
	if EEex_BAnd(c.m_dwFlags, 1) ~= 0 then
		local diff = field(c, 'm_lockDifficulty') or 100
		local who, how = bestOpener(area, diff)
		if who then startOpen(who, ob, how) return true end
		say(sp, S.NOLOCK_STRREF)
		S.passId, S.passAt = ob.m_id, now
		return true
	end
	return false
end

-- The container whose use point is nearest to the sprite (within 60 px), or nil.
local function nearContainer(sp, px, py)
	local area = sp.m_pArea
	px, py = px or sp.m_pos.x, py or sp.m_pos.y
	local best, bestD
	for _, l in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[l], function(id)
			local ob = EEex_GameObject_Get(id)
			if ob and ob.m_objectType == TYPE_CONTAINER then
				local dx, dy = ob.m_pos.x - px, ob.m_pos.y - py
				local d = dx * dx + dy * dy
				if d <= 60 * 60 and (not bestD or d < bestD) then best, bestD = ob, d end
			end
		end)
	end
	return best
end

-- Called through the global so a reloaded file takes over.
function SQAuto_OnStartedAction(sp, a)
	if not S.ENABLED or not S.CLICK or EEex_Sprite_GetPortraitIndex(sp) < 0 then return end
	-- John 2026-10-24: the opener goes first. A click on a container is MoveToPoint + a queued UseContainer: caught
	-- as the walk starts (container nearest the walk's end), both dropped when handled.
	if a.m_actionID == A_MOVE then
		local nextA
		EEex_Utility_IterateCPtrList(sp.m_queuedActions, function(q) nextA = q return true end)
		if not nextA or nextA.m_actionID ~= A_USECONTAINER then return end
		local ob = nearContainer(sp, a.m_dest.x, a.m_dest.y)
		if not ob then return end
		S.clicker = sp
		local ok, handled = pcall(onContainerClick, sp, ob)
		S.clicker = nil
		if not ok then S.lastError = tostring(handled) return end
		if handled then a.m_actionID = A_NONE nextA.m_actionID = A_NONE end
		return
	end
	if a.m_actionID ~= A_USECONTAINER then return end
	-- A click on a container: MoveToPoint to its use point, then UseContainer() with no target, so the
	-- container is the one whose use point she now stands on.
	local ob = nearContainer(sp)
	if #S.clickLog > 40 then table.remove(S.clickLog, 1) end
	S.clickLog[#S.clickLog + 1] = 'UseContainer near ' .. tostring(ob and ob.m_id)
	if not ob then return end
	S.clicker = sp
	local ok, handled = pcall(onContainerClick, sp, ob)
	S.clicker = nil
	if not ok then S.lastError = tostring(handled) return end
	if handled then a.m_actionID = A_NONE end
end
if not S.clickAdded2 then
	S.clickAdded2 = true
	EEex_Action_AddSpriteStartedActionListener(function(sp, a) SQAuto_OnStartedAction(sp, a) end)
end

S.PICK_STRREF = tonumber("SQ_AUTO_PICK_STRREF")
S.BASH_STRREF = tonumber("SQ_AUTO_BASH_STRREF")
S.NOTRAP_STRREF = tonumber("SQ_AUTO_NOTRAP_STRREF")
S.NOLOCK_STRREF = tonumber("SQ_AUTO_NOLOCK_STRREF")
S.GO_STRREF = tonumber("SQ_AUTO_GO_STRREF")  -- written by SadoQoL.tp2 (localized "I'll take care of the trap")

if not S.listenersAdded then
	S.listenersAdded = true
	local function pushTick()
		if not Infinity_IsMenuOnStack('SQAUTO_TICK') then Infinity_PushMenu('SQAUTO_TICK') end
	end
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQAUTO') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end

-- A reload brings the traps back: forget what was tried (ids and outcomes belong to the old session).
if not S.resetAdded then
	S.resetAdded = true
	EEex_Sprite_AddLoadedListener(function() S.tried, S.results, S.nostart, S.abandons, S.jobs = {}, {}, {}, {}, {} end)
end
