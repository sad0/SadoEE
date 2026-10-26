--[[
Quest chronicle (John 2026-10-24): Decard, the old scholar of the camp, opens a page listing every quest of the
installed games (BG1, SoD, BG2, ToB), searchable. Requires EEex. BGEE / BG2EE / EET, v2.6.6 and v2.7.3.

1. The quests: the game's own quest table (`quests`, built by the game from BGEE.LUA's buildQuestsTable and kept up
   to date by its journal: updateJournalEntry). Titles and journal entries come from the game, in its language.
2. The status of each quest is the journal's: done (ENTRY_TYPE_COMPLETE), in progress, never seen.
3. Hints and full solution: PSXQ_DATA (M_PSXQD.lua, the install language's copy of quests/data/<lang>.lua, built
   by quests/build_q_lua.py from quests/text/*.json), keyed by the title strref. It also gives each quest its game,
   chapter, place and kind (main story / companion / side quest).
4. Page (PSXQ.menu, build_q_menu.py): the camp merchant's notice board. Left: games and kinds, status filters.
   Middle: search (words separated by spaces must all match: title, journal, hints, place; case and accents
   ignored), the quest list, the selected quest's journal / hints / full solution. Right: the selected quest.
Opened by Decard's dialogue: EEex_LuaAction("PSXQ_Open()").
Console: PSXQ.DEBUG = true   PSXQ_Open()
--]]

PSXQ = PSXQ or {}
local Q = PSXQ
Q.DEBUG = Q.DEBUG or false
Q.cat = Q.cat or 'all'
Q.expanded = Q.expanded or {}
Q.show = Q.show or { active = true, none = true, done = true }
Q.view = Q.view or 'journal'
qFindText = qFindText or ''

local function log(...)
	if Q.DEBUG then print('[PSXQ] ' .. string.format(...)) end
end

-- English UI strings; the installed language's M_PSXQD.lua may override them (PSXQ_Strings).
Q.EN = {
	q_title = 'Quests', q_all = 'All quests', q_bg1 = "Baldur's Gate", q_sod = 'Siege of Dragonspear',
	q_bg2 = 'Shadows of Amn', q_tob = 'Throne of Bhaal', q_mods = 'Mods', q_mod_quest = "Quest added by the mod %s.\nNo hints or solution for mods' quests.", q_main = 'Main story', q_companion = 'Companions',
	q_side = 'Side quests', q_search = 'Search', q_active = 'In progress', q_done = 'Done', q_none = 'Never seen',
	q_status_active = 'In progress', q_status_done = 'Done', q_status_none = 'Not started',
	q_journal = 'Journal', q_hints = 'Hints', q_solution = 'Full solution', q_close = 'Close',
	q_count = '%d quests: %d done, %d in progress', q_select = 'Choose a quest in the list.',
	q_not_started = 'You have not started this quest yet.\n\nHints and the full solution are behind the buttons on the right.',
	q_no_hints = 'No hints for this quest yet.', q_no_solution = 'No solution written for this quest yet.',
	q_chapter = 'Chapter %s', q_any = 'Any time', q_completed = 'Quest completed.', q_spoiler = 'Spoilers!',
	q_skin = 'Board: %s', q_skin_1 = 'pinned notices', q_skin_2 = 'painted', q_none_found = 'No quest matches.',
}
local function T(key, ...)
	local s = (PSXQ_Strings and PSXQ_Strings[key]) or Q.EN[key] or key
	if select('#', ...) > 0 then return string.format(s, ...) end
	return s
end
PSXQ_T = T

-- Search folding (the camp merchant's): lower case and Latin accents dropped (UTF-8 U+00C0-U+00FF, Œ/œ), so
-- "beregost" finds "Bérégost" (string.lower leaves non-ASCII letters alone).
local FOLD = {}
do
	local runs = { { 0x80, 0x85, 'a' }, { 0x86, 0x86, 'ae' }, { 0x87, 0x87, 'c' }, { 0x88, 0x8B, 'e' }, { 0x8C, 0x8F, 'i' },
		{ 0x90, 0x90, 'd' }, { 0x91, 0x91, 'n' }, { 0x92, 0x96, 'o' }, { 0x98, 0x98, 'o' }, { 0x99, 0x9C, 'u' },
		{ 0x9D, 0x9D, 'y' }, { 0x9F, 0x9F, 'ss' }, { 0xA0, 0xA5, 'a' }, { 0xA6, 0xA6, 'ae' }, { 0xA7, 0xA7, 'c' },
		{ 0xA8, 0xAB, 'e' }, { 0xAC, 0xAF, 'i' }, { 0xB1, 0xB1, 'n' }, { 0xB2, 0xB6, 'o' }, { 0xB8, 0xB8, 'o' },
		{ 0xB9, 0xBC, 'u' }, { 0xBD, 0xBD, 'y' }, { 0xBF, 0xBF, 'y' } }
	for _, r in ipairs(runs) do
		for b = r[1], r[2] do FOLD[string.char(0xC3, b)] = r[3] end
	end
	FOLD[string.char(0xC5, 0x92)], FOLD[string.char(0xC5, 0x93)] = 'oe', 'oe'
end
local function fold(s)
	s = tostring(s or ''):gsub('[\195\197][\128-\191]', function(c) return FOLD[c] end)
	return string.lower(s)
end

local GAMES = { 'bg1', 'sod', 'bg2', 'tob', 'mods' }
local KINDS = { 'main', 'companion', 'side' }
local STATUS_RANK = { active = 1, none = 2, done = 3 }

-----------------------
-- Quest rows         --
-----------------------

-- Which game a quest without data belongs to, from its title strref. EET: BG2's strings first, then BG1's (from
-- 200000) and SoD's (from 240000). BGEE: SoD's strings from 40000. BG2EE: BG2 (ToB needs the data).
local function guessGame(strref)
	if Q.kind == 'eet' then
		if strref >= 240000 then return 'sod' elseif strref >= 200000 then return 'bg1' end
		return 'bg2'
	elseif Q.kind == 'bgee' then
		return strref >= 40000 and 'sod' or 'bg1'
	end
	return 'bg2'
end

local function detectKind()
	local eet, bg2 = false, false
	for _, q in pairs(quests or {}) do
		local t = tonumber(q.text) or 0
		if t >= 200000 then eet = true end
		if t == 74295 then bg2 = true end
	end
	return eet and 'eet' or (bg2 and 'bg2ee' or 'bgee')
end

local function statusOf(q)
	if q.stateType == const.ENTRY_TYPE_COMPLETE then return 'done' end
	if q.stateType ~= nil and q.stateType ~= const.ENTRY_TYPE_NONE then return 'active' end
	return 'none'
end

-- The received journal entries of a quest, oldest first.
local function received(q)
	local out = {}
	for _, o in pairs(q.objectives or {}) do
		for _, e in pairs(o.entries or {}) do
			if e.stateType ~= nil and e.stateType ~= const.ENTRY_TYPE_NONE then out[#out + 1] = e end
		end
	end
	table.sort(out, function(a, b) return (a.recvTime or 0) < (b.recvTime or 0) end)
	return out
end

local function entryText(e)
	local t = e.text
	if type(t) == 'number' then t = Infinity_FetchString(t) end
	return tostring(t or '')
end

-- Rows (one per quest of the game's table), rebuilt when the page opens. Search texts are kept per language.
local function buildRows()
	Q.kind = detectKind()
	local rows = {}
	for i, q in pairs(quests or {}) do
		local strref = tonumber(q.text) or -1
		-- data keys are EET strrefs: BGEE's own strings sit 200000 lower there (BG2EE's are the same)
		local d = PSXQ_DATA and (PSXQ_DATA[strref] or (Q.kind == 'bgee' and PSXQ_DATA[strref + 200000])) or {}
		local title = Infinity_FetchString(strref) or ''
		-- quests without any journal entry can never show up in the journal: left out (7 in EET)
		local n = 0
		for _, o in pairs(q.objectives or {}) do n = n + #(o.entries or {}) end
		if title ~= '' and n > 0 then
			local r = { idx = i, strref = strref, title = title, data = d, game = d.g or guessGame(strref),
				kind = d.k or 'side', status = statusOf(q) }
			if not d.k and fold(title):find('important events', 1, true) then r.kind = 'main' end
			rows[#rows + 1] = r
		end
	end
	table.sort(rows, function(a, b) return a.idx < b.idx end)
	-- the mods' quests (PSXQ_MODS, M_PSXQM.lua built at install): grouped per mod by their entries' first line (the
	-- quest's title, as the game's journal shows it); status from the journal's loose entries (not in `quests`)
	local got = {}
	for _, e in pairs(looseEntries or {}) do
		local id = tonumber(e.text)
		if id then got[id] = e end
	end
	local groups, mods = {}, {}
	for _, m in ipairs(PSXQ_MODS or {}) do
		local mod, id, t = m[1], m[2], m[3]
		local text = Infinity_FetchString(id) or ''
		local title = (text:match('^%s*([^\r\n]+)') or ''):gsub('%s+$', '')
		if title ~= '' then
			local key = mod .. '\n' .. title
			local r = groups[key]
			if not r then
				r = { idx = 100000 + #rows + 1, mod = mod, title = title, data = {}, game = 'mods', kind = 'side',
					status = 'none', entries = {} }
				groups[key] = r
				rows[#rows + 1] = r
				if not mods[mod] then mods[mod] = true end
			end
			r.entries[#r.entries + 1] = id
			local e = got[id]
			if e and e.stateType ~= const.ENTRY_TYPE_NONE then
				if e.stateType == const.ENTRY_TYPE_COMPLETE or t == 2 then r.status = 'done'
				elseif r.status == 'none' then r.status = 'active' end
			end
		end
	end
	Q.mods = {}
	for m in pairs(mods) do Q.mods[#Q.mods + 1] = m end
	table.sort(Q.mods, function(a, b) return string.lower(a) < string.lower(b) end)
	Q.rows = rows
	Q.findText = Q.findText or {}
end

-- Folded text the search looks into: title, every journal entry of the quest, hints, place, chapter.
local function findText(r)
	local s = Q.findText[r.idx]
	if s then return s end
	local parts = { r.title, r.data.w or '', r.data.c or '' }
	for _, h in ipairs(r.data.h or {}) do parts[#parts + 1] = h end
	if r.mod then
		parts[#parts + 1] = r.mod
		for _, id in ipairs(r.entries) do parts[#parts + 1] = Infinity_FetchString(id) or '' end
	else
		local q = quests[r.idx]
		for _, o in pairs(q and q.objectives or {}) do
			for _, e in pairs(o.entries or {}) do parts[#parts + 1] = entryText(e) end
		end
	end
	s = fold(table.concat(parts, '\n'))
	Q.findText[r.idx] = s
	return s
end

local function words()
	local out = {}
	for w in fold(qFindText or ''):gmatch('%S+') do out[#out + 1] = w end
	return out
end

local function inCategory(r, cat)
	if cat == 'all' then return true end
	local g, k = cat:match('^([^:]+):?(.*)$')
	if r.game ~= g then return false end
	if k == '' then return true end
	if g == 'mods' then return r.mod == k end
	return r.kind == k
end

-----------------------
-- Tree (left notice) --
-----------------------

qTreeList = qTreeList or {}
qTreeRow = qTreeRow or 1
local function counts(cat)
	local n, done = 0, 0
	for _, r in ipairs(Q.rows or {}) do
		if inCategory(r, cat) then
			n = n + 1
			if r.status == 'done' then done = done + 1 end
		end
	end
	return n, done
end

local function buildTree()
	local rows = { { key = 'all', text = T('q_all'), depth = 0 } }
	for _, g in ipairs(GAMES) do
		if counts(g) > 0 then
			rows[#rows + 1] = { key = g, text = (Q.expanded[g] and '- ' or '+ ') .. T('q_' .. g), depth = 0 }
			if Q.expanded[g] and g == 'mods' then
				for _, m in ipairs(Q.mods or {}) do
					rows[#rows + 1] = { key = 'mods:' .. m, text = '      ' .. m, depth = 1 }
				end
			elseif Q.expanded[g] then
				for _, k in ipairs(KINDS) do
					local key = g .. ':' .. k
					if counts(key) > 0 then rows[#rows + 1] = { key = key, text = '      ' .. T('q_' .. k), depth = 1 } end
				end
			end
		end
	end
	for i = #qTreeList, 1, -1 do qTreeList[i] = nil end
	for i, r in ipairs(rows) do qTreeList[i] = r end
end

function PSXQ_TreeClick()
	local r = qTreeList[qTreeRow]
	if not r then return end
	if r.depth == 0 and r.key ~= 'all' then
		local open = not (Q.expanded[r.key] and Q.cat == r.key)
		Q.expanded = {}
		Q.expanded[r.key] = open or nil
	end
	Q.cat = r.key
	buildTree()
	Q.dirty = true
end
function PSXQ_TreeText(row)
	local r = qTreeList[row]
	if not r then return '' end
	local n, done = counts(r.key)
	return string.format('%s  %d/%d', r.text, done, n)
end
function PSXQ_TreeSelected(row) local r = qTreeList[row] return r ~= nil and r.key == Q.cat end

-- Status filters (the game's round toggles).
function PSXQ_ToggleShow(which) Q.show[which] = not Q.show[which] Q.dirty = true end
function PSXQ_ShowFrame(which) return Q.show[which] and 2 or 0 end
function PSXQ_ShowText(which) return T('q_' .. which) end

-----------------------
-- Quest list         --
-----------------------

qListRows = qListRows or {}
qListRow = qListRow or 0
local function viewKey()
	return table.concat({ Q.cat, qFindText or '', tostring(Q.show.active), tostring(Q.show.none),
		tostring(Q.show.done), tostring(#(Q.rows or {})) }, '|')
end

local function rebuildList()
	local key = viewKey()
	if not Q.dirty and Q.listKey == key then return end
	Q.dirty, Q.listKey = false, key
	local ws = words()
	local out = {}
	for _, r in ipairs(Q.rows or {}) do
		if inCategory(r, Q.cat) and Q.show[r.status] then
			local ok = true
			if #ws > 0 then
				local s = findText(r)
				for _, w in ipairs(ws) do
					if not s:find(w, 1, true) then ok = false break end
				end
			end
			if ok then out[#out + 1] = r end
		end
	end
	local gameRank = { bg1 = 1, sod = 2, bg2 = 3, tob = 4, mods = 5 }
	local kindRank = { main = 1, companion = 2, side = 3 }
	table.sort(out, function(a, b)
		if a.game ~= b.game then return (gameRank[a.game] or 9) < (gameRank[b.game] or 9) end
		if a.kind ~= b.kind then return (kindRank[a.kind] or 9) < (kindRank[b.kind] or 9) end
		-- main story: the scenario's order (data field o, John 2026-10-24), whatever the status
		if a.kind == 'main' then
			local oa, ob = (a.data.o or 0) > 0 and a.data.o or 9999, (b.data.o or 0) > 0 and b.data.o or 9999
			if oa ~= ob then return oa < ob end
		end
		if a.status ~= b.status then return STATUS_RANK[a.status] < STATUS_RANK[b.status] end
		local fa, fb = fold(a.title), fold(b.title)
		if fa ~= fb then return fa < fb end
		return a.idx < b.idx
	end)
	for i = #qListRows, 1, -1 do qListRows[i] = nil end
	qListRow = 0
	for i, r in ipairs(out) do
		qListRows[i] = r
		if r.idx == Q.sel then qListRow = i end
	end
end

function PSXQ_ListText(row)
	rebuildList()
	local r = qListRows[row]
	return r and r.title or ''
end
function PSXQ_ListStatus(row)
	local r = qListRows[row]
	return r and T('q_status_' .. r.status) or ''
end
function PSXQ_ListSelected(row) local r = qListRows[row] return r ~= nil and r.idx == Q.sel end
function PSXQ_ListClick()
	local r = qListRows[qListRow]
	if not r then return end
	Q.sel, Q.view = r.idx, 'journal'
end
function PSXQ_SearchEdit() Q.dirty = true return 1 end
function PSXQ_CountText()
	rebuildList()
	if #qListRows == 0 then return T('q_none_found') end
	local done, active = 0, 0
	for _, r in ipairs(qListRows) do
		if r.status == 'done' then done = done + 1 elseif r.status == 'active' then active = active + 1 end
	end
	return T('q_count', #qListRows, done, active)
end

-----------------------
-- Selected quest     --
-----------------------

local function selRow()
	if not Q.sel then return nil end
	for _, r in ipairs(Q.rows or {}) do if r.idx == Q.sel then return r end end
	return nil
end

function PSXQ_HasSel() return selRow() ~= nil end
function PSXQ_SelTitle() local r = selRow() return r and r.title or T('q_select') end
function PSXQ_SelInfo()
	local r = selRow()
	if not r then return '' end
	local lines = { r.mod and (T('q_mods') .. ': ' .. r.mod) or T('q_' .. r.game) }
	local c = r.data.c
	if c and c ~= '' then lines[#lines + 1] = (c == 'any') and T('q_any') or T('q_chapter', c) end
	if r.data.w and r.data.w ~= '' then lines[#lines + 1] = r.data.w end
	lines[#lines + 1] = ''
	lines[#lines + 1] = T('q_status_' .. r.status)
	return table.concat(lines, '\n')
end

function PSXQ_SetView(v) if selRow() then Q.view = v end end
function PSXQ_ViewIs(v) return Q.view == v end
function PSXQ_ViewText(v)
	local s = T('q_' .. v)
	return Q.view == v and ('> ' .. s .. ' <') or s
end

function PSXQ_DetailTitle()
	local r = selRow()
	if not r then return '' end
	return r.title .. '  -  ' .. T('q_' .. Q.view)
end

function PSXQ_DetailText()
	local r = selRow()
	if not r then return T('q_select') end
	if r.mod and Q.view ~= 'journal' then return T('q_mod_quest', r.mod) end
	if r.mod then
		local got = {}
		for _, e in pairs(looseEntries or {}) do got[tonumber(e.text) or -1] = e end
		local es = {}
		for _, id in ipairs(r.entries) do
			local e = got[id]
			if e and e.stateType ~= const.ENTRY_TYPE_NONE then es[#es + 1] = e end
		end
		table.sort(es, function(a, b) return (a.recvTime or 0) < (b.recvTime or 0) end)
		if #es == 0 then return T('q_not_started') end
		local out = {}
		for _, e in ipairs(es) do
			local stamp = e.timeStamp and tostring(e.timeStamp) or ''
			out[#out + 1] = (stamp ~= '' and (stamp .. '\n') or '') .. entryText(e)
		end
		return table.concat(out, '\n\n')
	end
	if Q.view == 'hints' then
		local h = r.data.h or {}
		if #h == 0 then return T('q_no_hints') end
		local out = {}
		for i, s in ipairs(h) do out[#out + 1] = i .. '. ' .. s end
		return table.concat(out, '\n\n')
	elseif Q.view == 'solution' then
		return (r.data.s and r.data.s ~= '') and r.data.s or T('q_no_solution')
	end
	local q = quests[r.idx]
	local es = q and received(q) or {}
	if #es == 0 then return T('q_not_started') end
	local out = {}
	for _, e in ipairs(es) do
		local stamp = e.timeStamp and tostring(e.timeStamp) or ''
		out[#out + 1] = (stamp ~= '' and (stamp .. '\n') or '') .. entryText(e)
	end
	if r.status == 'done' then out[#out + 1] = T('q_completed') end
	return table.concat(out, '\n\n')
end

-----------------------
-- Page               --
-----------------------

-- The camp merchant's board look (PSXGMBA / PSXGMBB), shared with its page when installed.
function PSXQ_Skin()
	if PSXGM_Skin then return PSXGM_Skin() end
	return 2
end
function PSXQ_NextSkin()
	if PSXGM_NextSkin then PSXGM_NextSkin() end
end
function PSXQ_SkinText()
	if PSXGM_SkinText then return PSXGM_SkinText() end
	return T('q_skin', T('q_skin_' .. PSXQ_Skin()))
end
function PSXQ_CanSkin() return PSXGM_NextSkin ~= nil end

function PSXQ_OnOpen()
	buildRows()
	buildTree()
	Q.dirty = true
	qFindText = qFindText or ''
end

-- A full page (M_PSXPG.lua, John 2026-10-24): the game paused, the world veiled, the portrait bars still usable.
function PSXQ_Open()
	if type(quests) ~= 'table' then return end
	if PSXPG_Open then PSXPG_Open('PSXQ_PAGE') return end
	if not Infinity_IsMenuOnStack('PSXQ_PAGE') then Infinity_PushMenu('PSXQ_PAGE') end
end
function PSXQ_Close()
	if PSXPG_Close then PSXPG_Close('PSXQ_PAGE') return end
	if Infinity_IsMenuOnStack('PSXQ_PAGE') then Infinity_PopMenu('PSXQ_PAGE') end
end
-- The dialogue's check (Decard's reply shows when the page is installed).
function PSXQ_Installed() return true end

if not Q.listenersAdded then
	Q.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function()
		EEex_Menu_LoadFile('PSXQ')
	end)
	EEex_GameState_AddInitializedListener(function()
		Q.findText, Q.sel, Q.rows = {}, nil, nil
	end)
end
