--[[
SadoQoL component #11 - Attack-move (John 2026-10-23).

RTS-style attack-move: a mouse input (component #12, Mouse 4 by default) sends the selected party members towards the
point under the cursor in the game's current formation (the engine's own ground-click move). Every member is on its own (checked every PERIOD
ms): while IT sees no enemy it walks on; when it sees some, a fighter attacks the nearest one it sees (then the next),
a spellcaster stops and lets its AI script decide (spells included). The order ends when everyone has arrived and
nobody sees an enemy. A normal ground click (move) cancels it.

(An Attack-button + ground click version was dropped: the engine greys the cursor and refuses ground clicks in
attack mode before CGameArea::OnActionButtonClickGround.) The mouse binding lives in #12 (M_SQMB.lua).
Engine patch (bytes checked first; SQAtkM.status says why when skipped): in CGameArea::OnActionButtonClickGround the
"je move" for game state 0 goes to a stub calling Lua SQAttackMove_Cancel first: a normal move click ends the order.
--]]

SQAtkM = SQAtkM or {}
local T = SQAtkM

T.ENABLED = T.ENABLED ~= false
T.PERIOD = T.PERIOD or 250
T.ARRIVE = T.ARRIVE or 48             -- px: close enough to the destination
T.SIGHT = T.SIGHT or 448              -- px: enemies the party can see (with a line of sight check)

local ATTACK_ACTION = 3               -- Attack(O:Target*) in ACTION.IDS
local MOVE_ACTION = 23                -- MoveToPoint(P:Target*)
local CASTER_CLASSES = { [1] = true, [3] = true, [11] = true, [19] = true, [21] = true,   -- mage, cleric, druid,
	[7] = true, [8] = true, [13] = true, [14] = true, [15] = true, [17] = true, [18] = true } -- sorcerer, shaman, multis

local function partyMembers()
	local out = {}
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(p)
		if s then out[#out + 1] = s end
	end
	return out
end

local seeScript
local function sees(member, o)
	seeScript = seeScript or EEex_Trigger_ParseConditionalString('See(EEex_LuaObject)')
	EEex_LuaObject = o
	return EEex_Trigger_EvalScriptFileConditionalAsAIBase(seeScript, member)
end

-- living hostiles of the area, with the party members that see each one
local function enemiesSeen(members)
	local area = EEex_Area_GetVisible()
	local out = {}
	if not area then return out end
	local inParty = {}
	for _, m in ipairs(members) do inParty[m.m_id] = true end
	local s2 = T.SIGHT * T.SIGHT
	for _, list in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[list], function(id)
			local o = EEex_GameObject_Get(id)
			if o and o.m_objectType == 49 and not inParty[id] then
				local sp = EEex_GameObject_CastUserType(o)
				if sp.m_typeAI.m_EnemyAlly >= 200 and EEex_BAnd(sp.m_baseStats.m_generalState, 0xFC0) == 0 then
					local foe = { id = id, x = sp.m_pos.x, y = sp.m_pos.y, sp = sp, seenBy = {} }
					for _, m in ipairs(members) do
						local dx, dy = m.m_pos.x - foe.x, m.m_pos.y - foe.y
						if dx * dx + dy * dy <= s2 and sees(m, o) then foe.seenBy[m.m_id] = true end
					end
					out[#out + 1] = foe
				end
			end
		end)
	end
	return out
end

-- Queued actions wait for the current one (a march would end before the attack starts): clear it right now.
local function interrupt(s)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('ClearActions(Myself)', s)
end

local function moveTo(s, x, y)
	EEex_Action_QueueResponseStringOnAIBase(string.format('MoveToPoint([%d.%d])', x, y), s)
end

-- Attack(target): the target is resolved when the action runs, so the queued action gets the id written in.
local function attack(s, foe)
	interrupt(s)
	EEex_LuaObject = foe.sp
	EEex_Action_QueueResponseStringOnAIBase('Attack(EEex_LuaObject)', s)
	EEex_Utility_IterateCPtrList(s.m_queuedActions, function(a)
		if a.m_actionID == ATTACK_ACTION then a.m_acteeID.m_Instance = foe.id end
	end)
end

-- world point under the mouse cursor (the viewport maths of BGBot's fog markers, inverted)
local function cursorWorld()
	local game = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
	local inf = game.m_gameAreas:get(game.m_visibleArea).m_cInfinity
	local vp = inf.rViewPort
	local sw, sh = Infinity_GetScreenSize()
	local mx, my = EEex_Menu_GetMousePos()
	return math.floor(inf.nNewX + mx * vp.right / sw), math.floor(inf.nNewY + my * vp.bottom / sh)
end

-- The engine's ground click (CGameArea::OnActionButtonClickGround, game state 0) on (x, y) for the selected members;
-- returns { [sprite id] = { x, y } } of their move destinations. The click's own cancel hook is muted meanwhile.
-- The engine ignores a click on the very same point twice: the point alternates by 1 px.
-- The right-click drag (native): CGameArea keeps the drag start at +0x4D0 and a drag flag at +0x4D8. While the flag
-- is set, CGameArea::AIUpdate draws the formation preview at the start, turned by the mouse, every frame; and
-- OnActionButtonClickGround targets the drag start, turned the same way by the click point (= the release point).
local function dragFacingSupported()
	for i, b in ipairs({ 0x41, 0x83, 0xBE, 0xD8, 0x04, 0x00, 0x00, 0x00 }) do
		if EEex_ReadU8(SQ_Addr(0x140186A9B) + i - 1) % 256 ~= b then return false end
	end
	for i, b in ipairs({ 0x41, 0x8B, 0x86, 0xD0, 0x04, 0x00, 0x00 }) do
		if EEex_ReadU8(SQ_Addr(0x140186AA5) + i - 1) % 256 ~= b then return false end
	end
	return true
end

local function groupMove(x, y, fx, fy)
	local out = {}
	local area = EEex_Area_GetVisible()
	local game = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
	if not area or game.m_nState ~= 0 then return out end
	T.flip = not T.flip
	local px, py, dragged = T.flip and x + 1 or x, y, false
	if fx and fy and (fx ~= 0 or fy ~= 0) and dragFacingSupported() then
		local a = EEex_UDToPtr(area)
		EEex_Write32(a + 0x4D0, px)
		EEex_Write32(a + 0x4D4, py)
		EEex_Write32(a + 0x4D8, 1)
		-- the click point is the release point, as in the native drag (John: "vers l'avant")
		local n = math.sqrt(fx * fx + fy * fy)
		px, py, dragged = math.floor(px + fx / n * 64 + 0.5), math.floor(py + fy / n * 64 + 0.5), true
	end
	T.issuing = true
	local ok, err = pcall(EEex_RunWithStackManager,
		{ { name = 'pt', struct = 'CPoint', constructor = { variant = 'fromXY', args = { px, py } } } },
		function(m) area:OnActionButtonClickGround(m:getUD('pt')) end)
	T.issuing = false
	if dragged then
		-- as the native drag's end (CGameArea::OnFormationButtonUp): flag off, cursor back to normal (CInfGame +0x4041 = 4;
		-- left as is, the cursor kept the "turn the formation" look, John 2026-10-23)
		EEex_Write32(EEex_UDToPtr(area) + 0x4D8, 0)
		EEex_WriteU8(EEex_UDToPtr(game) + 0x4041, 4)
	end
	if not ok then T.lastError = 'group move: ' .. tostring(err) return out end
	for _, s in ipairs(EEex_Sprite_GetAllSelected()) do
		local a = s.m_curAction
		if a.m_actionID == MOVE_ACTION then
			out[s.m_id] = { a.m_dest.x, a.m_dest.y }
		else
			EEex_Utility_IterateCPtrList(s.m_queuedActions, function(q)
				if q.m_actionID == MOVE_ACTION then out[s.m_id] = { q.m_dest.x, q.m_dest.y } return true end
			end)
		end
	end
	return out
end

-- attack-move order to (x, y) for the selected party members
-- append (Shift held): with an attack-move running, (x, y) becomes the next waypoint (formation kept). Otherwise the
-- new order replaces the current one at once (John 2026-10-23), in the game's formation.
function SQAttackMove_At(x, y, append, fx, fy)
	if not T.ENABLED then return end
	local sel = EEex_Sprite_GetAllSelected and EEex_Sprite_GetAllSelected() or {}
	local inParty = {}
	for _, m in ipairs(partyMembers()) do inParty[m.m_id] = true end
	local group = {}
	for _, s in ipairs(sel) do if inParty[s.m_id] then group[#group + 1] = s end end
	if #group == 0 then return end
	local order = (append and T.order) or nil
	if order then
		-- Shift: the next waypoint for each member, at its place in the formation of the first order
		for _, s in ipairs(group) do
			local o = order.members[s.m_id]
			if o then o.wp[#o.wp + 1] = { x + o.dx, y + o.dy } end
		end
		T.next = 0
		return
	end
	-- The game's own move order, as a ground click (John 2026-10-23: "appliquer la formation"): the engine places
	-- every member in the current formation (Party Stash's ones for 7+). Each member's destination is read back:
	-- its place, kept for the walk after each fight and for the Shift waypoints.
	local dest = groupMove(x, y, fx, fy)
	order = { members = {} }
	local cx, cy = 0, 0
	for _, s in ipairs(group) do cx, cy = cx + s.m_pos.x, cy + s.m_pos.y end
	cx, cy = cx / #group, cy / #group
	for _, s in ipairs(group) do
		local d = dest[s.m_id]
		local tx = d and d[1] or math.floor(x + (s.m_pos.x - cx) * 0.5)   -- fallback: the old offsets
		local ty = d and d[2] or math.floor(y + (s.m_pos.y - cy) * 0.5)
		order.members[s.m_id] = { wp = { { tx, ty } }, i = 1, fighting = false, dx = tx - x, dy = ty - y }
		if not d then interrupt(s) moveTo(s, tx, ty) end
	end
	T.order = order
	T.next = 0
end

function SQAttackMove_Cancel() if not T.issuing then T.order = nil end end

-- Every member on its own (John): it walks to its point while it sees no enemy; when it sees some, it attacks the
-- nearest one it sees (spellcasters: their AI script decides), then the next one, then walks on.
function SQAttackMove_Tick()
	local now = Infinity_GetClockTicks()
	if not T.order or (T.next and now < T.next) then return false end
	T.next = now + T.PERIOD
	local ok, err = pcall(function()
		local members = {}
		for _, m in ipairs(partyMembers()) do if T.order.members[m.m_id] then members[#members + 1] = m end end
		if #members == 0 then T.order = nil return end
		local foes = enemiesSeen(members)
		local over = true
		for _, m in ipairs(members) do
			local o = T.order.members[m.m_id]
			local cur = m.m_curAction.m_actionID
			local idle = cur == 0 and m.m_queuedActions.m_nCount == 0
			local best, bd
			for _, f in ipairs(foes) do
				if f.seenBy[m.m_id] then
					local d = (f.x - m.m_pos.x) ^ 2 + (f.y - m.m_pos.y) ^ 2
					if not bd or d < bd then best, bd = f, d end
				end
			end
			if best then
				over = false
				if CASTER_CLASSES[m.m_typeAI.m_Class] then
					if not o.fighting then interrupt(m) end      -- stop walking; the AI script fights
				elseif cur ~= ATTACK_ACTION or not o.fighting then
					attack(m, best)
				end
				o.fighting = true
			else
				local w = o.wp[o.i]
				local dx, dy = w[1] - m.m_pos.x, w[2] - m.m_pos.y
				local arrived = dx * dx + dy * dy <= T.ARRIVE * T.ARRIVE
				if arrived and o.i < #o.wp then                     -- next waypoint (Shift orders)
					o.i = o.i + 1
					w = o.wp[o.i]
					arrived = false
					moveTo(m, w[1], w[2])
				end
				if not arrived then
					over = false
					if o.fighting then interrupt(m) end
					if o.fighting or idle then moveTo(m, w[1], w[2]) end
				end
				o.fighting = false
			end
		end
		if over then T.order = nil end
	end)
	if not ok then T.lastError = tostring(err) T.order = nil end
	return false
end

-- ---- engine patches ----
local CLICK_GROUND = SQ_Addr(0x1401868E0)
local JE_MOVE, JE_MOVE_TARGET = SQ_Addr(0x140186911), SQ_Addr(0x140186A08)       -- 0F 84 rel32: state 0 -> move
local JNE_OTHER, JNE_OTHER_TARGET = SQ_Addr(0x14018691A), SQ_Addr(0x140186B27)   -- 0F 85 rel32: state not 1 -> return
local SET_STATE, UPDATE_BUTTONS = SQ_Addr(0x14018AC40), SQ_Addr(0x14026A6C0)

local function byteAt(a) return EEex_ReadU8(a) % 256 end
local function rel32(at) -- target of a 6-byte 0F 8x rel32 jump
	local rel = byteAt(at + 2) + byteAt(at + 3) * 0x100 + byteAt(at + 4) * 0x10000 + byteAt(at + 5) * 0x1000000
	if rel >= 0x80000000 then rel = rel - 0x100000000 end
	return at + 6 + rel
end
local function setRel32(at, target)
	local rel = target - (at + 6)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of range') end
	if rel < 0 then rel = rel + 0x100000000 end
	for i = 0, 3 do EEex_WriteU8(at + 2 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
end

local function patch()
	if T.status then return end
	if not (byteAt(JE_MOVE) == 0x0F and byteAt(JE_MOVE + 1) == 0x84 and rel32(JE_MOVE) == JE_MOVE_TARGET
			and byteAt(JNE_OTHER) == 0x0F and byteAt(JNE_OTHER + 1) == 0x85 and rel32(JNE_OTHER) == JNE_OTHER_TARGET) then
		T.status = 'skipped: unexpected engine code'
		print('[SadoQoL] attack-move: ' .. T.status)
		return
	end
	-- rdi = CInfGame, rbx = CPoint* (the clicked point), edx = game state
	local cancelStub = EEex_JITNear(EEex_FlattenTable({
		{[[
			#MAKE_SHADOW_SPACE(32)
		]]},
		EEex_GenLuaCall('SQAttackMove_Cancel', {}),
		{[[
			call_error:
			#DESTROY_SHADOW_SPACE
			jmp ]], JE_MOVE_TARGET, [[ #ENDL
		]]},
	}))
	EEex_DisableCodeProtection()
	setRel32(JE_MOVE, cancelStub)
	EEex_EnableCodeProtection()
	T.status = 'patched'
end

do
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] attack-move: ' .. T.status) end
end

-- attack-move to the point under the mouse cursor: bound to a mouse input by #12 (M_SQMB.lua, Mouse 4 by default)
local function shiftDown()
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left Shift')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Shift'))
end

function SQAttackMove_AtCursor()
	local ok, err = pcall(function()
		local x, y = cursorWorld()
		SQAttackMove_At(x, y, shiftDown())
	end)
	if not ok then T.lastError = tostring(err) end
end

-- Press and drag (John 2026-10-23, like the native right-click drag): the press point is the destination, the
-- release point gives the way the formation faces. A short drag (< DRAG_MIN px) is a plain click.
T.DRAG_MIN = T.DRAG_MIN or 24
-- While the button is held, the area is put in drag mode at the press point: the engine draws the formation
-- preview there, turned by the mouse, like during a right-click drag (John 2026-10-23: "la preview").
local function previewOn(x, y)
	local area = EEex_Area_GetVisible()
	if not area or EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_nState ~= 0 or not dragFacingSupported() then return end
	local a = EEex_UDToPtr(area)
	EEex_Write32(a + 0x4D0, x)
	EEex_Write32(a + 0x4D4, y)
	EEex_Write32(a + 0x4D8, 1)
	T.previewArea = a
end
local function previewOff()
	if T.previewArea then
		EEex_Write32(T.previewArea + 0x4D8, 0)
		EEex_WriteU8(EEex_UDToPtr(EEex_EngineGlobal_CBaldurChitin.m_pObjectGame) + 0x4041, 4)   -- normal cursor
		T.previewArea = nil
	end
end

function SQAttackMove_Begin()
	local ok, err = pcall(function()
		local x, y = cursorWorld()
		T.drag = { x, y, shiftDown() }
		if not T.drag[3] then previewOn(x, y) end   -- Shift: a waypoint, no facing
	end)
	if not ok then T.lastError = tostring(err) end
end

function SQAttackMove_End()
	local d = T.drag
	T.drag = nil
	pcall(previewOff)
	if not d then return end
	local ok, err = pcall(function()
		local x, y = cursorWorld()
		local fx, fy = x - d[1], y - d[2]
		if fx * fx + fy * fy < T.DRAG_MIN * T.DRAG_MIN then fx, fy = nil, nil end
		SQAttackMove_At(d[1], d[2], d[3], fx, fy)
	end)
	if not ok then T.lastError = tostring(err) end
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQATKM_TICK') then Infinity_PushMenu('SQATKM_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQATKM') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
