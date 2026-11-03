--[[
SadoQoL component #10 - Rest camp (John 2026-10-23).

A quiet camp (area SQCAMP: the Clairiere, our own 40x30-tile map, E:/AI/bg3d/tools/build_camp3d.py, 2026-11-02) reached
from the world map: a torn parchment with a tent and a fire sits over the Travel button (red under the mouse).
 - Elsewhere it reads "Camp": the party goes to the camp, 0 hours. The origin (area + leader position) is saved.
 - In the camp it still reads "Camp" and carries the party marker (WMDAG); the engine's marker, which would sit on
   the origin, is hidden. Clicking the parchment (tooltip "Back") or the origin on the map brings the party back to the origin spot, 0 hours.
The camp is not on any world map, so the engine still takes the origin (the last world map area) as the current
place: travelling from the camp to another destination costs the time it would from the origin. Rest there is
normal (8 hours) and safe (the ARE has no rest encounters). The camp is in no world map, so the engine gives its
edges no travel: the ARE has travel regions (cursor only, no destination: the south-east corner, BG2EE the road's two
ends); a party member stopping in one gets the engine's own map-edge action, LeaveArea("", point, direction) (action 91,
what CGameArea::OnActionButtonClickTravel queues): the engine then checks the party is gathered and opens the world map. (Opening it from Lua,
worldMapScreen:StartWorldMap + SelectEngine inside a menu tick, left the interface dead.)
The parchment shows only when the world map was opened to travel (same rule as the Travel button).
--]]

SQCamp = SQCamp or {}
local T = SQCamp

T.AREA = 'SQCAMP'
-- the camp map's spots come from M_SQ0CMP.lua (SQCampSite, the Clairiere, every game); the BD5000 crop's below are
-- only a fallback
local SITE = SQCampSite or {}
T.ENTRY_X, T.ENTRY_Y = 634, 520        -- south of the campfire
if SITE.ENTRY then T.ENTRY_X, T.ENTRY_Y = SITE.ENTRY[1], SITE.ENTRY[2] end
T.STR_CAMP = tonumber("SQ_CAMP_STR_CAMP")
T.STR_BACK = tonumber("SQ_CAMP_STR_BACK")
-- parchment over the Travel button (WORLD_MAP: Travel button at 783,715 230x40)
local X, Y, W, H = 832, 593, 132, 118
local LABEL_Y, LABEL_H = 683, 24
-- Infinity UI++ lays its map out by screen size (rgWorldMap1 / 2 / 4, in its WORLD_MAP onOpen) and has no Travel
-- button there: the parchment goes to the map's bottom-right corner (John 2026-11-02).
local IUI_MAPS, IUI_MARGIN = { 'rgWorldMap1', 'rgWorldMap2', 'rgWorldMap4' }, 12
local function iuiCorner()
	if type(rgGetCustomizedPortraitList) ~= 'function' then return nil end
	for _, name in ipairs(IUI_MAPS) do
		local ok, x, y, w, h = pcall(Infinity_GetArea, name)
		if ok and w and h and w > 0 and h > 0 then return x + w - W - IUI_MARGIN, y + h - H - IUI_MARGIN end
	end
end
local function place()
	local x, y = iuiCorner()
	if not x or (x == X and y == Y) then return end
	X, Y, LABEL_Y = x, y, y + 90
	EEex_Menu_SetTemplateArea('WORLD_MAP', 'SQCAMP_TEMPLATE_Button', 1, X, Y, W, H)
	EEex_Menu_SetTemplateArea('WORLD_MAP', 'SQCAMP_TEMPLATE_Label', 1, X, LABEL_Y, W, LABEL_H)
	EEex_Menu_SetTemplateArea('WORLD_MAP', 'SQCAMP_TEMPLATE_Marker', 1, X + 41, Y + 14, 50, 50)
end

-- exit bands, as in tools/build_camp.py (EXITS): x1, y1, x2, y2
-- the exit: the south-east corner after the last tree (same polygon as tools/build_camp.py EXITS), and the
-- gathering point on the path, away from the screen edge (John 2026-10-23)
T.EXIT_POLY = { { 830, 959 }, { 830, 760 }, { 1000, 600 }, { 1279, 520 }, { 1279, 959 } }
T.EXIT_POLYS = SITE.EXITS or { T.EXIT_POLY }
T.PERIOD = 250

local function leader() return EEex_Sprite_GetInPortrait(0) end
local function currentArea()
	local a = EEex_Area_GetVisible()
	return a and a.m_resref:get():upper() or ''
end
local function inCamp() return currentArea() == T.AREA end
-- The camp's people are created on the leader, in HIS area. While the party moves between areas the view can already
-- show the camp with the leader still elsewhere (or the reverse): they were made in the other area (two Faceless in
-- the ground A/B test, John 2026-11-03). Nobody is created until the leader stands in the camp shown.
function SQCamp_LeaderHere()
	local p, a = leader(), EEex_Area_GetVisible()
	return p and a and EEex_UDEqual(p.m_pArea, a) or false
end

-- Is the area on the engine's world map? Areas outside it (BG2's chapter 1 dungeon AR0602) have no place to travel
-- from: the map opened from there lists only the next destination, and travelling crashed in TravelToSelected
-- (2026-11-02). CWorldMap: m_cResRef (8), m_cHeader (8), m_pData (CWorldMapData per map), m_ppAreas (one
-- CWorldMapArea array per map). An unexpected layout answers true: the camp then behaves as before.
local function onWorldMap(res)
	local ok, found = pcall(function()
		local wm = EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_cWorldMap
		local w, data = EEex_UDToPtr(wm), EEex_UDToPtr(wm.m_pData)
		if data == 0 or EEex_ReadPtr(w + 16) ~= data then return nil end
		local pp = EEex_ReadPtr(w + 16 + EEex_PtrSize)
		if pp == 0 then return nil end
		for m = 0, wm.m_cHeader.m_nMapCount - 1 do
			local areas = EEex_ReadPtr(pp + m * EEex_PtrSize)
			local n = EEex_PtrToUD(data + m * CWorldMapData.sizeof, 'CWorldMapData').m_nAreas
			if areas ~= 0 then
				for i = 0, n - 1 do
					if EEex_PtrToUD(areas + i * CWorldMapArea.sizeof, 'CWorldMapArea').m_resCurrentArea:get():upper() == res then return true end
				end
			end
		end
		return false
	end)
	if not ok or found == nil then return true end
	return found
end
T.onWorldMap = onWorldMap

function SQCamp_Visible()
	local shown = worldMapScreen ~= nil and worldMapScreen:IsTravelButtonVisible() and leader() ~= nil
	if shown then pcall(place) end
	return shown
end

function SQCamp_Frame()
	local mx, my, mw, mh = EEex_Menu_GetArea('WORLD_MAP')
	if mx and EEex_Menu_IsCursorWithinRect(mx + X, my + Y, W, H) then return 1 end
	return 0
end

local function labelText()
	return T.STR_CAMP and Infinity_FetchString(T.STR_CAMP) or 'Camp'
end

-- The world map's area names (CScreenWorldMap): font FLOATTXT, tint 0xFAFAFA, drop shadow on (CAMPAIGN.2DA
-- MAP_DROPSHADOW / MAP_FONTCOLOR). Same here: style sqcamp_place + text shadow 1 in SQCAMP.menu.
local function ensureStyle()   -- UI.MENU defines 'styles' after M_ files load: called before loading SQCAMP.menu
	if styles and not styles.sqcamp_place then
		styles.sqcamp_place = { font = 'FLOATTXT', point = 14, color = 'B', useFontZoom = 0, halign = 'center', valign = 'center' }
	end
end
-- white with a drop shadow, like the world map's area names
function SQCamp_Text()
	return '^0xFFFFFFFF' .. labelText() .. '^-'
end

-- in the camp the parchment leads back to the origin: its tooltip says so (the label stays "Camp", John)
function SQCamp_Tooltip()
	if inCamp() and T.STR_BACK then return Infinity_FetchString(T.STR_BACK) end
	return labelText()
end

-- the party marker on the parchment while in the camp
function SQCamp_MarkerVisible() return SQCamp_Visible() and inCamp() end

-- every party member leaves for the same spot (the engine spreads them around it). LeaveAreaLUA, not
-- LeaveAreaLUAPanic, and no ClearActions(Myself) in the same response: it empties the queue, the move included.
local function moveParty(area, x, y)
	-- members 7+ of the >6-party prototype (M_PSXP7.lua) too, when it is installed
	local last = PSXP7_LastPortrait and PSXP7_LastPortrait() or 5
	for i = 0, last do
		local s = EEex_Sprite_GetInPortrait(i)
		if s then
			EEex_Action_QueueResponseStringOnAIBase(string.format(
				'LeaveAreaLUA("%s","",[%d.%d],0)', area, x, y), s)
		end
	end
end

function SQCamp_Click()
	local p = leader()
	if not p then return end
	worldMapScreen:OnCancelButtonClick()
	if inCamp() then
		-- back to the origin. Clicking the origin on the map does it too, but a map opened from the exit corner
		-- does not always pass that click on (2026-10-23): the parchment is the sure way.
		local origin = EEex_Sprite_GetLocalString(p, 'SQCAMPOR')
		if origin and origin ~= '' then
			T.goBack = { origin, EEex_Sprite_GetLocalInt(p, 'SQCAMPX'), EEex_Sprite_GetLocalInt(p, 'SQCAMPY') }
		end
		return
	end
	if not onWorldMap(currentArea()) then return end   -- no way back through the world map from there
	do
		EEex_Sprite_SetLocalString(p, 'SQCAMPOR', currentArea())
		EEex_Sprite_SetLocalInt(p, 'SQCAMPX', p.m_pos.x)
		EEex_Sprite_SetLocalInt(p, 'SQCAMPY', p.m_pos.y)
		moveParty(T.AREA, T.ENTRY_X, T.ENTRY_Y)
	end
end

-- Called by the OnAreaMouseClick patch when the clicked area is the engine's current one (the origin, as the camp is
-- in no world map). From the camp: back to the origin spot. The engine then closes the map as usual.
function SQCamp_SameAreaClicked()
	local p = leader()
	if not p or not inCamp() then return end
	local origin = EEex_Sprite_GetLocalString(p, 'SQCAMPOR')
	if origin and origin ~= '' then
		-- done by the next camp tick, once the map is closed: the map opened from the exit corner leaves a pending
		-- LeaveArea on the member who walked there, and a LeaveAreaLUA queued behind it never ran ("gather your party")
		T.goBack = { origin, EEex_Sprite_GetLocalInt(p, 'SQCAMPX'), EEex_Sprite_GetLocalInt(p, 'SQCAMPY') }
	end
end

-- back to the origin: every member's actions cleared first (alone: ClearActions in the same response would empty
-- the queue, the move included), then all of them leave together
local function goBack()
	local b, now = T.goBack, Infinity_GetClockTicks()
	if not b.jumpedAt then
		-- 1) LeaveAreaLUA wants the party gathered: a party spread in the exit corner got "gather your party".
		-- Everyone jumps onto the leader first (2026-10-23).
		b.jumpedAt = now
		local l = leader()
		for i = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
			local s = EEex_Sprite_GetInPortrait(i)
			if s then
				EEex_Action_ExecuteResponseStringOnAIBaseInstantly('ClearActions(Myself)', s)
				if i > 0 then EEex_Action_QueueResponseStringOnAIBase(string.format('JumpToPoint([%d.%d])', l.m_pos.x, l.m_pos.y), s) end
			end
		end
	elseif now - b.jumpedAt > 600 then
		-- 2) then all of them leave together
		T.goBack, T.leaving, T.armed, T.disarmedAt = nil, nil, false, now
		moveParty(b[1], b[2], b[3])
	end
end

-- Engine patches (bytes checked first; SQCamp.patchStatus says why when skipped):
--  * CScreenWorldMap::DrawMap calls GetMarkerPosition at MARKER_CALL: a stub calls it and, in the camp (flag byte
--    written by the tick), moves the marker off-screen; the parchment draws it instead.
--  * CScreenWorldMap::OnAreaMouseClick, SAME_AREA: "cmp r8d, r12d ; je close" (clicked area == current area). A stub
--    calls SQCamp_SameAreaClicked() first, then closes like the engine.
local MARKER_CALL, GET_MARKER = SQ_Addr(0x1402FE8E5), SQ_Addr(0x140301B00)
local SAME_AREA, SAME_AREA_CLOSE, SAME_AREA_NEXT = SQ_Addr(0x140301F1A), SQ_Addr(0x140302620), SQ_Addr(0x140301F23)
local SAME_AREA_BYTES = { 0x45, 0x3B, 0xC4, 0x0F, 0x84, 0xFD, 0x06, 0x00, 0x00 }

local function byteAt(a) return EEex_ReadU8(a) % 256 end
local function relTarget(at)
	local rel = byteAt(at + 1) + byteAt(at + 2) * 0x100 + byteAt(at + 3) * 0x10000 + byteAt(at + 4) * 0x1000000
	if rel >= 0x80000000 then rel = rel - 0x100000000 end
	return at + 5 + rel
end
local function writeRel(at, opcode, target)
	local rel = target - (at + 5)
	if rel < 0 then rel = rel + 0x100000000 end
	EEex_WriteU8(at, opcode)
	for i = 0, 3 do EEex_WriteU8(at + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
end

local function patchMap()
	if T.patchStatus then return end
	local ok = byteAt(MARKER_CALL) == 0xE8 and relTarget(MARKER_CALL) == GET_MARKER
	for i, b in ipairs(SAME_AREA_BYTES) do ok = ok and byteAt(SAME_AREA + i - 1) == b end
	if not ok then T.patchStatus = 'skipped: unexpected engine code' print('[SadoQoL] camp: ' .. T.patchStatus) return end
	T.flag = EEex_Malloc(8)
	EEex_WriteU8(T.flag, 0)
	local markerStub = EEex_JITNear({[[
		mov qword ptr ss:[rsp+8], rdx
		sub rsp, 0x28
		call ]], GET_MARKER, [[ #ENDL
		add rsp, 0x28
		mov rdx, qword ptr ss:[rsp+8]
		mov rax, ]], T.flag, [[ #ENDL
		cmp byte ptr ds:[rax], 0
		je sqcamp_marker_done
		mov dword ptr ds:[rdx], -20000
		mov dword ptr ds:[rdx+4], -20000
		sqcamp_marker_done:
		ret
	]]})
	local clickStub = EEex_JITNear(EEex_FlattenTable({
		{[[
			cmp r8d, r12d
			jne sqcamp_other_area
			#MAKE_SHADOW_SPACE(32)
		]]},
		EEex_GenLuaCall('SQCamp_SameAreaClicked', {}),
		{[[
			call_error:
			#DESTROY_SHADOW_SPACE
			jmp ]], SAME_AREA_CLOSE, [[ #ENDL
			sqcamp_other_area:
			jmp ]], SAME_AREA_NEXT, [[ #ENDL
		]]},
	}))
	EEex_DisableCodeProtection()
	writeRel(MARKER_CALL, 0xE8, markerStub)
	writeRel(SAME_AREA, 0xE9, clickStub)
	for i = 5, 8 do EEex_WriteU8(SAME_AREA + i, 0x90) end
	EEex_EnableCodeProtection()
	T.patchStatus = 'patched'
end
do
	local ok, err = pcall(patchMap)
	if not ok then T.patchStatus = 'error: ' .. tostring(err) print('[SadoQoL] camp: ' .. T.patchStatus) end
end

local function inPoly(poly, x, y)   -- point in polygon (ray casting)
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
		if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
		j = i
	end
	return inside
end
local function inExit(x, y)   -- the exit's index, or nil
	for i, poly in ipairs(T.EXIT_POLYS) do
		if inPoly(poly, x, y) then return i end
	end
	return nil
end

local function partyList()
	local out = {}
	for i = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(i)
		if s then out[#out + 1] = s end
	end
	return out
end

-- Saves that visited the camp before the Clairiere (v1.0.3, John 2026-11-02) keep their copy of the old map's ARE
-- (the BD5000 crop, or OH5300 on BG2EE): the new map's tiles show, with the old map's things at their old places.
-- Once, at the first visit (an old map's fire still burns at one of these spots), everything is set right in place:
-- the fire goes to the new fire, the old torches go out (an old save has no lanterns: an ARE's animations cannot be
-- added), the ambient sound and item piles follow the fire, the exit region becomes the new one, and the camp's people,
-- waiting ex-members and party go to their new spots. Tested on a v1.0.2 BGEE save (2026-11-02).
local OLD_FIRES = { { 634, 385 }, { 908, 609 } }   -- BD5000 crop, OH5300 crop (camp_bg2)
local SPOT_OF = { SQPRIEST = 'PRIEST', SQMERCH = 'MERCH', SQCAIN = 'CAIN', SQWITHER = 'WITHERS', SQNECRO = 'NECRO' }
local function near(x, y, pt, d) return (x - pt[1]) ^ 2 + (y - pt[2]) ^ 2 <= d * d end
local function jump(sp, x, y, face)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('ClearActions(Myself)', sp)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('JumpToPoint([%d.%d])', x, y), sp)
	if face then EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('SetSequence(SEQ_READY) Face(%d)', face), sp) end
end
-- the n-th place in rings round a point (the waiting ex-members', when Waiting at the camp #16 is not installed)
local function ring(c, n)
	local r, count = 120, 8
	while n >= count do n, r, count = n - count, r + 70, count + 8 end
	local a = 2 * math.pi * n / count
	return math.floor(c[1] + r * math.cos(a)), math.floor(c[2] + r * math.sin(a) * 0.75)
end
local function migrateLayout(area)
	local fire = SITE.FIRE
	if not fire then return end
	local statics, oldFire, newFire = {}, nil, false
	-- (an animation drawn under everything, flag "not drawn over", sits in the back list: BG2's fire pit, Compat 2026-11-02)
	for _, list in ipairs({ area.m_lVertSort, area.m_lVertSortBack }) do
		EEex_Utility_IterateCPtrList(list, function(id)
			local o = EEex_GameObject_Get(id)
			if not (o and o.m_objectType == 48) then return end
			local st = EEex_GameObject_CastUserType(o)
			table.insert(statics, st)
			if near(o.m_pos.x, o.m_pos.y, fire, 40) then newFire = true end
			for _, f in ipairs(OLD_FIRES) do
				if not oldFire and near(o.m_pos.x, o.m_pos.y, f, 40) then oldFire = st end
			end
		end)
	end
	if newFire or not oldFire then return end   -- the new map, or already done
	local dx, dy = fire[1] - oldFire.m_pos.x, fire[2] - oldFire.m_pos.y
	print('[SQCamp] old camp map in this save: moving its things to the Clairiere')
	for _, st in ipairs(statics) do
		if st == oldFire then
			st.m_pos.x, st.m_pos.y = fire[1], fire[2]
			st.m_header.m_posX, st.m_header.m_posY = fire[1], fire[2]
		else
			local f = st.m_header.m_dwFlags
			st.m_header.m_dwFlags = f - f % 2   -- bit 0 off: not shown
		end
	end
	local triggers = {}
	EEex_Utility_IterateCPtrList(area.m_lVertSortBack, function(id)
		local o = EEex_GameObject_Get(id)
		if not o then return end
		local t = EEex_GameObject_CastUserType(o)
		if o.m_objectType == 16 then   -- the fire's crackle
			o.m_pos.x, o.m_pos.y = o.m_pos.x + dx, o.m_pos.y + dy
		elseif o.m_objectType == 17 and t.m_containerType == 4 and t.m_lstItems.m_nCount > 0 then   -- items on the ground
			o.m_pos.x, o.m_pos.y = o.m_pos.x + dx, o.m_pos.y + dy
			local rb = t.m_rBounding
			rb.left, rb.top, rb.right, rb.bottom = rb.left + dx, rb.top + dy, rb.right + dx, rb.bottom + dy
			t.m_ptWalkToUse.x, t.m_ptWalkToUse.y = t.m_ptWalkToUse.x + dx, t.m_ptWalkToUse.y + dy
		elseif o.m_objectType == 65 then
			table.insert(triggers, t)
		end
	end)
	-- the exit regions: the first one with room for the new exit's points becomes it, the others are emptied
	local poly = T.EXIT_POLYS[1]
	for _, t in ipairs(triggers) do
		local ptr = t.m_pPolygon and EEex_UDToPtr(t.m_pPolygon) or 0
		local rb = t.m_rBounding
		if poly and ptr ~= 0 and t.m_nPolygon >= #poly then
			local l, tp, r, bt = math.huge, math.huge, 0, 0
			for i, pt in ipairs(poly) do
				EEex_WriteU32(ptr + (i - 1) * 8, pt[1]); EEex_WriteU32(ptr + (i - 1) * 8 + 4, pt[2])
				l, tp, r, bt = math.min(l, pt[1]), math.min(tp, pt[2]), math.max(r, pt[1]), math.max(bt, pt[2])
			end
			t.m_nPolygon = #poly
			rb.left, rb.top, rb.right, rb.bottom = l, tp, r, bt
			poly = nil
		else
			t.m_nPolygon = 0
			rb.left, rb.top, rb.right, rb.bottom = 0, 0, 1, 1
		end
	end
	local inParty, n, k = {}, 0, 0
	for i = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(i)
		if s then inParty[s.m_id] = true end
	end
	EEex_Utility_IterateCPtrList(area.m_lVertSort, function(id)
		local o = EEex_GameObject_Get(id)
		if not (o and o.m_objectType == 49) then return end
		local sp = EEex_GameObject_CastUserType(o)
		local spot = SITE[SPOT_OF[string.upper(sp.m_scriptName:get())] or '']
		if inParty[id] then
			local x, y = ring({ T.ENTRY_X, T.ENTRY_Y }, n)
			if n == 0 then x, y = T.ENTRY_X, T.ENTRY_Y end
			n = n + 1
			jump(sp, x, y)
		elseif spot then
			jump(sp, spot[1], spot[2], spot[3])
		elseif EEex_Sprite_GetLocalInt(sp, 'SQDUMMY') > 0 and SITE.NECRO_CENTER then   -- the necromancer's creatures
			jump(sp, ring(SITE.NECRO_CENTER, k % 8))
		else   -- waiting ex-members and anyone else: round the fire
			local x, y
			if SQWait and SQWait.place then x, y = SQWait.place(k) else x, y = ring(fire, k) end
			k = k + 1
			jump(sp, x, y)
		end
	end)
	if leader() then
		EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('MoveViewPoint([%d.%d],INSTANT)', T.ENTRY_X, T.ENTRY_Y), leader())
	end
end

-- The camp's people (SQCAMP.ARE actors, tools/build_camp.py). A save that visited the camp before one of them was
-- added keeps its old copy of the area: the missing ones are created at their spot (John 2026-10-23).
T.RESIDENTS = T.RESIDENTS or {
	{ 'SQPRIEST', 553, 338, 14 },
	{ 'SQMERCH', 723, 301, 2 },
}
-- BG2EE's camp: the same people at its own spots
for _, r in ipairs(T.RESIDENTS) do
	local at = (r[1] == 'SQPRIEST' and SITE.PRIEST) or (r[1] == 'SQMERCH' and SITE.MERCH)
	if at then r[2], r[3], r[4] = at[1], at[2], at[3] end
end
-- (the camp chest SQCHEST is gone, John 2026-10-24: the Old Scholar opens the Codex; see T.GONE)
T.spawnAt = T.spawnAt or {}
T.relooked = T.relooked or {}
T.renamed = T.renamed or {}
T.NAMED = { SQPRIEST = true, SQMERCH = true, SQCAIN = true, SQNECRO = true }   -- (Faceless: M_SQFACE.lua's faces)
-- the camp people's animations (SadoQoL.tp2 writes the same into their CREs)
T.LOOKS = { SQPRIEST = 0xC910, SQMERCH = 0xC800, SQCAIN = 0x6402 }   -- SQWITHER = Faceless: M_SQFACE.lua's disguises
-- camp people version: raise it when their CREs change in a way a save keeps (voice); they are remade once
T.PEOPLE_VERSION = 2
T.REMAKE = { SQPRIEST = true, SQMERCH = true }
-- camp people that no longer exist: removed from old saves when met
T.GONE = { SQCHEST = true }
-- camp people there must be only one of
T.ONE = { SQPRIEST = true, SQMERCH = true, SQCAIN = true, SQWITHER = true, SQNECRO = true }
-- creates a camp person now (not queued on the leader: shared with M_SQCAIN.lua)
function SQCamp_Create(res, x, y, face)
	local p = leader()
	if not p then return end
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('CreateCreature("%s",[%d.%d],%d)', res, x, y, face), p)
end
local function spawnResidents()
	local area = EEex_Area_GetVisible()
	if not area then return end
	local here, copies = {}, {}
	for _, list in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
		EEex_Utility_IterateCPtrList(area[list], function(id)
			local o = EEex_GameObject_Get(id)
			if o and o.m_objectType == 49 then
				local sp = EEex_GameObject_CastUserType(o)
				local name = string.upper(sp.m_scriptName:get())
				-- a save keeps the creature with the name strref of the install it was made under: another install (a
				-- new version adding strings) turned the merchant into "Shape him." (2026-11-02). The shown name is a
				-- copy made at load time, so such a one goes and comes back from today's CRE (once he is missing, the
				-- camp or the Old Scholar's own spawn makes him again at his spot).
				if T.NAMED[name] and not T.renamed[id] then
					T.renamed[id] = true
					local ok, h = pcall(EEex_Resource_Demand, name, 'CRE')
					local p = ok and h and EEex_UDToPtr(h) or 0
					if p ~= 0 and EEex_ReadU32(p + 8) ~= sp.m_baseStats.m_name then
						EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroySelf()', sp)
						return
					end
				end
				if T.ONE[name] then
					copies[name] = copies[name] or {}
					table.insert(copies[name], sp)
				end
				here[name] = true
				-- an older look kept in the save (John 2026-10-24: the game's animations): the current one, once
				if T.GONE[name] then
					EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroySelf()', sp)
					return
				end
				local want = T.LOOKS[name]
				if want and sp.m_animation.m_animation.m_animationID ~= want and not T.relooked[id] then
					T.relooked[id] = true
					EEex_GameObject_ApplyEffect(sp, { effectID = 53, durationType = 9, effectAmount = want,
						sourceID = sp.m_id, sourceTarget = sp.m_id })
				end
			end
		end)
	end
	-- a camp person found twice (a double spawn, Compat test 2026-10-25): the one nearest his spot stays
	for name, list in pairs(copies) do
		if #list > 1 then
			local spot = name == 'SQCAIN' and SQCain and SQCain.SPOT
			for _, r in ipairs(T.RESIDENTS) do if r[1] == name then spot = { r[2], r[3] } end end
			local keep, best = nil, nil
			for _, sp in ipairs(list) do
				local d = spot and (sp.m_pos.x - spot[1]) ^ 2 + (sp.m_pos.y - spot[2]) ^ 2 or sp.m_id
				if not best or d < best then keep, best = sp, d end
			end
			for _, sp in ipairs(list) do
				if sp ~= keep then EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroySelf()', sp) end
			end
		end
	end
	local now, p = Infinity_GetClockTicks(), leader()
	-- right after the area loads, its own actors may not be listed yet: a duplicate was made (2026-10-23).
	-- Wait until the party has been in the camp for 3 s.
	local key = EEex_UDToPtr(area)
	if T.spawnArea ~= key then T.spawnArea, T.spawnSince = key, now end
	if now - T.spawnSince < 3000 then return end
	-- once per save: the people of an older camp version go, and come back from today's CREs (look and voice,
	-- John 2026-10-24). Player1's local SQCAMPV holds the version done.
	if p and EEex_Sprite_GetLocalInt(p, 'SQCAMPV') < T.PEOPLE_VERSION then
		EEex_Sprite_SetLocalInt(p, 'SQCAMPV', T.PEOPLE_VERSION)
		for _, list in ipairs({ 'm_lVertSort', 'm_lVertSortBack' }) do
			EEex_Utility_IterateCPtrList(area[list], function(id)
				local o = EEex_GameObject_Get(id)
				if o and o.m_objectType == 49 then
					local sp = EEex_GameObject_CastUserType(o)
					if T.REMAKE[string.upper(sp.m_scriptName:get())] then
						EEex_Action_ExecuteResponseStringOnAIBaseInstantly('DestroySelf()', sp)
					end
				end
			end)
		end
		return   -- the next look (3 s throttle) creates them again
	end
	for _, r in ipairs(T.RESIDENTS) do
		-- once per camp visit, run at once: queued on the leader, it waited while he talked or the game was paused,
		-- and a second try queued meanwhile made a double (Compat test, 2026-10-25)
		if not here[r[1]] and p and T.spawnAt[r[1]] ~= key then
			T.spawnAt[r[1]] = key
			SQCamp_Create(r[1], r[2], r[3], r[4])
		end
	end
end

-- Exits as the game does them at a map edge (John 2026-10-25, "comme le jeu"): a party member stepping into an exit
-- gets the engine's own map-edge action, LeaveArea("", point, direction) (action 91, what a click on a map edge
-- queues). With the party gathered the engine opens the world map, else it says "You must gather your party"; nobody
-- is moved for the player. Once per step in: re-armed when nobody stands in an exit, or by a new move order there.
function SQCamp_Tick()
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + T.PERIOD
	local p = leader()
	if T.flag then EEex_WriteU8(T.flag, (p and inCamp()) and 1 or 0) end
	if not p or not inCamp() then
		-- elsewhere: armed for the next visit; not while the world map is up (no area then), or closing it with the
		-- party still in the exit would open it again
		if e:GetActiveEngine() == worldScreen then T.armed = true end
		return false
	end
	if not SQCamp_LeaderHere() then return false end
	if T.goBack and e:GetActiveEngine() == worldScreen then
		local ok, err = pcall(goBack)
		if not ok then T.lastError = 'back: ' .. tostring(err) end
		return false
	end
	local ok, err = pcall(spawnResidents)
	if not ok then T.lastError = 'residents: ' .. tostring(err) end
	local area = EEex_Area_GetVisible()
	if area and T.migrated ~= EEex_UDToPtr(area) and T.spawnArea == EEex_UDToPtr(area) and Infinity_GetClockTicks() - T.spawnSince >= 3000 then
		T.migrated = EEex_UDToPtr(area)   -- (once its objects are all listed, like the camp's people)
		local ok, err = pcall(migrateLayout, area)
		if not ok then T.lastError = 'layout: ' .. tostring(err) end
	end
	local party = partyList()
	local inside
	for _, s in ipairs(party) do
		if inExit(s.m_pos.x, s.m_pos.y) then inside = s break end
	end
	if not inside then
		T.armed = true
	elseif not T.armed and now - (T.disarmedAt or 0) > 1500 then
		-- disarmed (the map just closed) while standing in the exit: a new move order there re-arms it, standing
		-- still does not (no map popping up again and again)
		for _, s in ipairs(party) do
			if s.m_curAction.m_actionID == 23 and inExit(s.m_pos.x, s.m_pos.y) then T.armed = true break end
		end
	elseif T.armed and inside.m_curAction.m_actionID ~= 23 then   -- in the exit and stopped there
		T.armed, T.disarmedAt = false, now
		local origin = EEex_Sprite_GetLocalString(p, 'SQCAMPOR')
		if origin and origin ~= '' and not onWorldMap(origin) then
			-- came from an area outside the world map (an older save, or a call by hand): the map would offer no way
			-- back, so the exit leads straight back to the origin spot
			T.goBack = { origin, EEex_Sprite_GetLocalInt(p, 'SQCAMPX'), EEex_Sprite_GetLocalInt(p, 'SQCAMPY') }
		else
			EEex_Action_QueueResponseStringOnAIBase(string.format('LeaveArea("",[%d.%d],12)', inside.m_pos.x, inside.m_pos.y), inside)
		end
	end
	return false
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQCAMP_TICK') then Infinity_PushMenu('SQCAMP_TICK') end
end

local function inject()
	ensureStyle()
	EEex_Menu_InjectTemplateInstance('WORLD_MAP', 'SQCAMP_TEMPLATE_Button', 1, X, Y, W, H)
	EEex_Menu_InjectTemplateInstance('WORLD_MAP', 'SQCAMP_TEMPLATE_Label', 1, X, LABEL_Y, W, LABEL_H)
	EEex_Menu_InjectTemplateInstance('WORLD_MAP', 'SQCAMP_TEMPLATE_Marker', 1, X + 41, Y + 14, 50, 50)
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function()
		ensureStyle()   -- before the menu file: its label uses the style, a missing one aborts the load
		EEex_Menu_LoadFile('SQCAMP')
		inject()
	end)
	EEex_Menu_AddAfterMainFileReloadedListener(function()
		ensureStyle()   -- before the menu file: its label uses the style, a missing one aborts the load
		EEex_Menu_LoadFile('SQCAMP')
		inject()
		pushTick()
	end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
end

-- ---- Alt + drag moves the camp chest (John 2026-10-23: "déplaçable pour le caler") ----
-- Left button down with Alt over the chest grabs it; release drops it under the cursor (its place is saved with
-- the area, as any creature's).
local function cursorWorld()
	local game = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
	local inf = game.m_gameAreas:get(game.m_visibleArea).m_cInfinity
	local vp = inf.rViewPort
	local sw, sh = Infinity_GetScreenSize()
	local mx, my = EEex_Menu_GetMousePos()
	return math.floor(inf.nNewX + mx * vp.right / sw), math.floor(inf.nNewY + my * vp.bottom / sh)
end

local function altDown()
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left Alt')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Alt'))
end

local function chestSprite()
	local area = EEex_Area_GetVisible()
	if not area then return nil end
	local found
	EEex_Utility_IterateCPtrList(area.m_lVertSort, function(id)
		local o = EEex_GameObject_Get(id)
		if o and o.m_objectType == 49 then
			local sp = EEex_GameObject_CastUserType(o)
			if string.upper(sp.m_scriptName:get()) == 'SQCHEST' then found = sp return true end
		end
	end)
	return found
end

if not T.dragHooked and EEex_Key_Hook_AfterEventsPoll then
	T.dragHooked = true
	local orig = EEex_Key_Hook_AfterEventsPoll
	EEex_Key_Hook_AfterEventsPoll = function(event)
		local ok, consumed = pcall(function()
			if worldScreen ~= e:GetActiveEngine() or not inCamp() then return false end
			local down = event.type == SDL_EventType.SDL_MOUSEBUTTONDOWN and event.button.button == 1
			local up = event.type == SDL_EventType.SDL_MOUSEBUTTONUP and event.button.button == 1
			if down and altDown() then
				local c = chestSprite()
				if not c then return false end
				local x, y = cursorWorld()
				if (c.m_pos.x - x) ^ 2 + ((c.m_pos.y - y) * 4 / 3) ^ 2 > 40 * 40 then return false end
				T.draggingChest = c.m_id
				return true
			elseif up and T.draggingChest then
				local o = EEex_GameObject_Get(T.draggingChest)
				T.draggingChest = nil
				if o then
					local x, y = cursorWorld()
					EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('JumpToPoint([%d.%d])', x, y),
						EEex_GameObject_CastUserType(o))
				end
				return true
			end
			return false
		end)
		if not ok then T.lastError = 'chest drag: ' .. tostring(consumed) elseif consumed then return true end
		return orig(event)
	end
end
