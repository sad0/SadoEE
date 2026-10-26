--[[
Party Stash: more than 6 party members (PROTOTYPE, John GO 2026-10-23). Requires EEex. BGEE / BG2EE / EET, x64,
v2.6.6.0 and v2.7.3.0. Does nothing until PSXP7_Enable(n) is called (EEex console or test bridge).

The engine keeps the party in two fixed arrays inside CInfGame: m_characters int[6] (+0x6600, join order) and
m_charactersPortrait int[6] (+0x6618, portrait order); the count m_nCharacters (+0x6630) stays where it is.
PSXP7_Enable(n):
  1. allocates two int[n] arrays (copies the current 6 ids, -1 after);
  2. redirects every engine access to the old arrays (414 instructions per build, listed by genlua.py in
     M_PSXP7S.lua): each one becomes a jump to a stub that loads the new array's address minus the field offset
     into the instruction's own base register, runs the original instruction unchanged, restores the register
     (unless the instruction overwrote it) and jumps back. Flags are untouched (push / mov imm / pop);
  3. raises the reviewed party-size bounds ("cmp x, 6" -> n) where a loop or check must see the extra members
     (AddCharacterToParty, the slot/portrait lookups, save/load, selection, destroy). Every other "6" stays: the
     extra members are then simply skipped there (multiplayer arrays, banter, scripts' Player1-6...).
Every site's bytes are checked before anything is written: a different build or another patch = nothing done.
Known limits: portrait indexes 6 and 7 are special values in CInfGame::SwapItemPersonal (ground, container), so
the inventory screen cannot use them; Player7+ do not exist as script objects; the UI shows 6 portraits.
--]]

PSXP7 = PSXP7 or {}
local Z = PSXP7

local OFF_CHARS, OFF_PORTRAITS = 0x6600, 0x6618

-- EngineGlobals exists before EEex_EngineGlobal_CBaldurChitin (needed by the startup auto-enable).
local function gamePtr()
	local chitin = EEex_EngineGlobal_CBaldurChitin or (EngineGlobals and EngineGlobals.g_pBaldurChitin)
	return EEex_UDToPtr(chitin.m_pObjectGame)
end

local function hexBytes(s)
	local out = {}
	for i = 1, #s, 2 do out[#out + 1] = tonumber(s:sub(i, i + 1), 16) end
	return out
end

local function bytesAt(addr, bytes)
	for i, b in ipairs(bytes) do
		if EEex_ReadU8(addr + i - 1) ~= b then return false end
	end
	return true
end

local function le(v, n)
	local out = {}
	for i = 1, n do out[i] = v % 256 v = math.floor(v / 256) end
	return out
end

-- The build whose every site matches the running code, or nil.
local function findBuild()
	for build, t in pairs(PSXP7_SITES or {}) do
		local ok = true
		for _, s in ipairs(t.redirect) do
			if not bytesAt(s[1], hexBytes(s[6])) then ok = false break end
		end
		if ok then
			for _, a in ipairs(t.bounds) do
				if EEex_ReadU8(a) ~= 6 then ok = false break end
			end
		end
		if ok and t.offsets then
			for _, o in ipairs(t.offsets) do
				if not bytesAt(o[1], hexBytes(o[7])) then ok = false break end
			end
		end
		if ok and t.pick then
			for _, k in ipairs(t.pick) do
				if not bytesAt(k[1], hexBytes(k[5])) then ok = false break end
			end
		end
		if ok and t.maxchar then
			for _, a in ipairs(t.maxchar.guards) do if EEex_ReadU8(a) ~= 6 then ok = false break end end
			for _, r in ipairs(t.maxchar.refs) do if EEex_ReadU8(r[2] + EEex_Read32(r[1])) ~= 6 then ok = false break end end
		end
		if ok and t.clears then
			if not bytesAt(t.clears.remove[1], hexBytes(t.clears.remove[2])) then ok = false end
		end
		if ok and t.gather then
			for _, r in ipairs(t.gather.refs) do if EEex_Read32(r[2] + EEex_Read32(r[1])) ~= t.gather.base then ok = false break end end
		end
		if ok and t.formation then
			if not bytesAt(t.formation.site, hexBytes(t.formation.orig)) then ok = false end
		end
		if ok and t.piles then
			for _, k in ipairs(t.piles.sites) do if not bytesAt(k[1], hexBytes(k[6])) then ok = false break end end
		end
		if ok and t.names then
			for _, r in ipairs(t.names) do if EEex_ReadU8(r[1]) ~= 7 or EEex_ReadU8(r[2]) ~= 5 then ok = false break end end
		end
		if ok and t.objects then
			if not bytesAt(t.objects[1], hexBytes(t.objects[2])) then ok = false end
		end
		if ok and t.marshal then
			if EEex_ReadU32(t.marshal.size) ~= 0x870 or EEex_ReadU32(t.marshal.copy) ~= 6 then ok = false end
			for _, m in ipairs(t.marshal.sites) do
				if not bytesAt(m[1], hexBytes(m[3])) then ok = false break end
			end
		end
		if ok then return build, t end
	end
end

-- 8 little-endian bytes of a signed integer (exact below 2^53: no float rounding).
local function le64(v)
	local out = le(v % 2 ^ 32, 4)
	for _, x in ipairs(le(math.floor(v / 2 ^ 32) % 2 ^ 32, 4)) do out[#out + 1] = x end
	return out
end

local function pushReg(r) return r >= 8 and { 0x41, 0x50 + r - 8 } or { 0x50 + r } end
local function popReg(r) return r >= 8 and { 0x41, 0x58 + r - 8 } or { 0x58 + r } end
local function movImm(r, v)
	local t = { r >= 8 and 0x49 or 0x48, 0xB8 + r % 8 }
	for _, x in ipairs(le64(v)) do t[#t + 1] = x end
	return t
end
-- lea b, [b + s] (adds without touching the flags)
local function leaAdd(b, s)
	local rex = 0x48 + (b >= 8 and 4 or 0) + (s >= 8 and 2 or 0) + (b >= 8 and 1 or 0)
	local sib = (s % 8) * 8 + b % 8
	if b % 8 == 5 then return { rex, 0x8D, 0x44 + (b % 8) * 8, sib, 0x00 } end -- rbp/r13 need a disp8
	return { rex, 0x8D, 0x04 + (b % 8) * 8, sib }
end

-- add r, s (64-bit)
local function addReg(r, s)
	return { 0x48 + (s >= 8 and 4 or 0) + (r >= 8 and 1 or 0), 0x01, 0xC0 + (s % 8) * 8 + r % 8 }
end

-- Field offset kept in a register (mov r32, 0x66xx / add r64, 0x66xx, then [reg + game]): the offset becomes
-- offset + delta, so reg + game lands in the new array (2026-10-23: the box selection, CGameArea::OnActionButtonUp,
-- reads the portraits through mov r15d, 0x6618 / mov esi, [r15 + rax]).
local function offsetStub(o, delta)
	local reg, kind, form, value, scratch = o[3], o[4], o[5], o[6], o[8]
	local v = value + delta[kind]
	local code = {}
	local function emit(t) for _, b in ipairs(t) do code[#code + 1] = b end end
	if form == 0 then
		emit(movImm(reg, v))
	else
		emit(pushReg(scratch)) emit(movImm(scratch, v)) emit(addReg(reg, scratch)) emit(popReg(scratch))
	end
	return code
end

local function rel32(from, to) local r = to - from return le(r < 0 and r + 2 ^ 32 or r, 4) end
local function cat(...)
	local out = {}
	for _, t in ipairs({ ... }) do for _, b in ipairs(t) do out[#out + 1] = b end end
	return out
end

-- Stub for one site: the base register gets delta = newArray - oldArray added (whatever it holds: this, this + i*4,
-- a walking pointer), the original instruction runs unchanged, then delta is taken back off (unless the
-- instruction overwrote the base). Scratch register s (unused by the instruction) carries delta; push/mov/lea/pop
-- leave the flags alone. Fixed 2026-10-23: the first version loaded an absolute base, which dropped a pre-added index
-- (CInfGame::OnPortraitLClick: lea rsi, [rcx + rax*4] / mov eax, [rsi + 0x6618]).
local function stubCode(s, delta)
	local reg, kind, nopop, hex, scratch = s[3], s[4], s[5], s[6], s[7]
	local d = delta[kind]
	local code = {}
	local function emit(t) for _, b in ipairs(t) do code[#code + 1] = b end end
	emit(pushReg(scratch)) emit(movImm(scratch, d)) emit(leaAdd(reg, scratch)) emit(popReg(scratch))
	emit(hexBytes(hex))
	if nopop == 0 then
		emit(pushReg(scratch)) emit(movImm(scratch, -d)) emit(leaAdd(reg, scratch)) emit(popReg(scratch))
	end
	return code
end

local function writeBytes(addr, code)
	for i, b in ipairs(code) do EEex_WriteU8(addr + i - 1, b) end
end

-- Writes `code` + "jmp back" into a new near stub; returns the site's patch bytes (jmp stub + nops up to `len`).
local function makeStub(siteAddr, len, code, size)
	local back = siteAddr + len
	local stub = EEex_AllocNear((size or #code) + 5)
	if type(code) == 'function' then code = code(stub) end
	local rel = back - (stub + #code + 5)
	code[#code + 1] = 0xE9
	for _, b in ipairs(le(rel < 0 and rel + 2 ^ 32 or rel, 4)) do code[#code + 1] = b end
	writeBytes(stub, code)
	local j = stub - (siteAddr + 5)
	local site = { 0xE9 }
	for _, b in ipairs(le(j < 0 and j + 2 ^ 32 or j, 4)) do site[#site + 1] = b end
	for _ = 6, len do site[#site + 1] = 0x90 end
	return site
end

-- Script objects Player7..PlayerN (John 2026-10-23: global-script blocks of other mods, e.g. cdtweaks' auto-haste,
-- only name Player1-6). OBJECT.IDS gets 160 Player7 ... (159 + n - 6) PlayerN. CAIObjectType::Decode switches on the
-- object id (cases 1-114): ids FIRST.. are sent to the Player6 case with k = id - (FIRST - 6) left in a cell, and that
-- case's load of m_characters[5] reads m_characters[k] instead when the cell is set (then clears it).
Z.FIRST_ID = 160
-----------------------
-- Formations 8+      --
-----------------------
-- CAIGroup::GetOffsets places members 0-6 from a fixed table (12 formations x 7 points, in search-map cells:
-- x 16 px, y 12 px, y > 0 = behind) and lets members 7+ keep their current position relative to the leader.
-- John (2026-10-23, relayed by BOT): adapt the formations, not only scale them: tighter ranks that multiply in both
-- dimensions as the party grows. Up to 7 members: the game's own tables, unchanged. From 8: every formation is
-- rebuilt for the party size by PSXP7_FormTick() (rule per vanilla table, by its rank in memory), spacing FORM_SX x
-- FORM_SY cells, front row first, centre out.
Z.FORM_N, Z.FORM_SX, Z.FORM_SY = 32, 2, 2 -- John: tighter (was 3 x 3)
local function grid(c, w, sx, sy, y0, shift)
	local o, rows = {}, math.ceil(c / w)
	for r = 0, rows - 1 do
		local cnt = math.min(w, c - #o)
		local order = {}
		for j = 0, cnt - 1 do order[#order + 1] = j end
		local mid = (cnt - 1) / 2
		table.sort(order, function(p, q) local dp, dq = math.abs(p - mid), math.abs(q - mid) if dp ~= dq then return dp < dq end return p < q end)
		for _, j in ipairs(order) do
			local x = (j - mid) * sx + ((shift and r % 2 == 1) and sx / 2 or 0)
			o[#o + 1] = { math.floor(x + 0.5), (y0 or 0) + r * sy }
		end
	end
	return o
end
local function wedgeAll(c, sx, sy)
	local o, r = { { 0, 0 } }, 1
	while #o < c do
		local cnt = 2 * r + 1
		for _, j in ipairs((function() local t = {} for j = 0, cnt - 1 do t[#t + 1] = j end
			table.sort(t, function(p, q) return math.abs(p - r) < math.abs(q - r) end) return t end)()) do
			if #o < c then o[#o + 1] = { (j - r) * sx, r * sy } end
		end
		r = r + 1
	end
	return o
end
local function rings(c, r0, step)
	local o, r = { { 0, 0 } }, r0
	while #o < c do
		local cnt = math.max(6, math.floor(2 * math.pi * r / (step + 1))) -- chord ~ step + 1 cells
		for i = 0, cnt - 1 do
			if #o >= c then break end
			local a = 2 * math.pi * i / cnt
			local x, y = math.floor(r * math.sin(a) + 0.5), math.floor(r * math.cos(a) * 0.75 + 0.5)
			local free = true
			for _, q in ipairs(o) do if math.abs(q[1] - x) < Z.FORM_SX and math.abs(q[2] - y) < Z.FORM_SY then free = false break end end
			if free then o[#o + 1] = { x, y } end
		end
		r = r + step
	end
	return o
end
local function width(c, f) return math.max(2, math.ceil(math.sqrt(c / f))) end
-- c members -> c points. sx, sy = spacing.
Z.FORM_RULES = {
	[0] = function(c, sx, sy) return rings(c, 3, Z.FORM_SX + 0.5) end, -- gather: tight rings around the leader
	[1] = function(c, sx, sy) -- T: a front bar, then a wide column behind it
		local w = width(c, 1)
		local bar = grid(math.min(c, w), w, sx, sy, 0)
		local rest = grid(c - #bar, math.max(2, math.ceil(w / 2)), sx, sy, sy)
		for _, q in ipairs(rest) do bar[#bar + 1] = q end
		return bar end,
	[2] = function(c, sx, sy) local r = math.ceil(math.sqrt(c / 4)) return grid(c, math.ceil(c / r), sx, sy, 0) end, -- line: ranks
	[3] = function(c, sx, sy) return grid(c, math.max(3, math.floor(math.sqrt(c) + 0.5)), sx, sy, 0) end, -- block: about square
	[4] = function(c, sx, sy) return grid(c, width(c, 3), sx, sy, 0) end, -- column of 2: wider column
	[5] = function(c, sx, sy) return rings(c, 3, Z.FORM_SX + 0.5) end, -- protect: rings
	[6] = function(c, sx, sy) return grid(c, width(c, 4), sx, sy, 0, true) end, -- zigzag: staggered columns
	[7] = function(c, sx, sy) return wedgeAll(c, sx, sy) end, -- small arrow: filled wedge
	[8] = function(c, sx, sy) return wedgeAll(c, sx, sy) end, -- arrow: filled wedge
	[9] = function(c, sx, sy) return grid(c, width(c, 4), sx, sy, 0) end, -- column: columns side by side
	[10] = function(c, sx, sy) return grid(c, width(c, 4), sx, sy, 0, true) end, -- zigzag
}
-- Writes formation id's c points (c > 7: our rules; c <= 7: the vanilla 7) into the engine-facing table.
local function fillFormations(f, tbl, n, c)
	local first = math.huge
	for _, a in ipairs(f.tables) do first = math.min(first, a) end
	for id = 0, 11 do
		local src = f.tables[id + 1]
		local pts = {}
		for j = 0, 6 do pts[#pts + 1] = { EEex_Read32(src + j * 8), EEex_Read32(src + j * 8 + 4) } end
		if c > 7 then
			local rule = Z.FORM_RULES[math.floor((src - first) / 0x38)]
			local ok, r = pcall(rule or function() end, math.min(c, n), Z.FORM_SX, Z.FORM_SY)
			if ok and type(r) == 'table' and #r > 0 then pts = r end
		end
		for j = 0, n - 1 do
			local q = pts[j + 1] or pts[#pts]
			EEex_Write32(tbl + (id * n + j) * 8, q[1])
			EEex_Write32(tbl + (id * n + j) * 8 + 4, q[2])
		end
	end
end
local function formationTable(f, n)
	local tbl = EEex_Malloc(12 * n * 8)
	fillFormations(f, tbl, n, 7)
	return tbl
end
-- World tick: rebuild the formations when the party size changes.
function PSXP7_FormTick(force)
	if not Z.formTable or not Z.build then return end
	local c = Infinity_GetNumCharacters()
	if c == Z.formCount and not force then return end
	Z.formCount = c
	fillFormations(PSXP7_SITES[Z.build].formation, Z.formTable, Z.FORM_N, c)
end

local function objectStubs(o, n, chars, jumps)
	local cell = EEex_Malloc(8)
	EEex_Write32(cell, -1)
	local first, count = Z.FIRST_ID, n - 6
	local dispatch, back, default, case26, p6, p6back = o[1], o[3], o[4], o[5], o[6], o[8]
	-- dispatch (replaces dec eax / cmp eax, 0x71 - eax = object id; EEex hooks the "ja default" that follows, so the
	-- normal path goes back to it with the cmp's flags)
	jumps[#jumps + 1] = { dispatch, makeStub(dispatch, 5, function(stub)
		return cat({ 0x3D }, le(first, 4), { 0x72, 43 }, { 0x3D }, le(first + count, 4), { 0x73, 36 },
			{ 0x41, 0x53 }, movImm(11, cell), { 0x2D }, le(first - 6, 4), { 0x41, 0x89, 0x03 }, { 0x41, 0x5B },
			{ 0xFF, 0x25, 0, 0, 0, 0 }, le64(case26),
			{ 0xFF, 0xC8 }, { 0x83, 0xF8, 0x71 })
	end, 55) }
	-- Player6 case's load (replaces mov eax, [rcx + 0x6614])
	jumps[#jumps + 1] = { p6, makeStub(p6, 6, function(stub)
		return cat({ 0x41, 0x53 }, movImm(11, cell), { 0x41, 0x8B, 0x03 }, { 0x83, 0xF8, 0xFF }, { 0x74, 28 },
			{ 0x41, 0xC7, 0x03, 0xFF, 0xFF, 0xFF, 0xFF }, movImm(11, chars), { 0x41, 0x8B, 0x04, 0x83 }, { 0x41, 0x5B },
			{ 0xE9 }, rel32(stub + 48, p6back),
			movImm(11, chars + 20), { 0x41, 0x8B, 0x03 }, { 0x41, 0x5B })
	end, 63) }
	Z.objectCell = cell
end


-- CInfGame::Marshal (save) builds the GAM party entries (0x168 bytes each) in a stack array of 6 at rbp-0x80:
-- a 7th entry overwrites the stack cookie (crash 0xC0000409, found 2026-10-23). They go to a heap buffer of n.
local ENTRY = 0x168
local function marshalPatch(t, n, jumps)
	local buf = EEex_Malloc(n * ENTRY)
	for _, m in ipairs(t.marshal.sites) do
		local code = hexBytes(m[4])
		for _, b in ipairs(le(buf + m[5], 8)) do code[#code + 1] = b end
		for _, b in ipairs(hexBytes(m[6])) do code[#code + 1] = b end
		jumps[#jumps + 1] = { m[1], makeStub(m[1], m[2], code) }
	end
	return buf
end

-- CScreenInventory::SwapWithSlot (picking up an item) keeps the members who can use it best in a stack array of 8
-- ([rbp + i*8 + 0xE0], the stack cookie right after it): with a party of 9+ tied members it wrote past
-- it -> __report_gsfailure, 0xC0000409 (John 2026-10-23, 26 members, item taken from the stash grid). Its 3 accesses
-- go to a heap array of n instead: store [rbp + rdi*8 + 0xE0] / store [rbp + 0xE0] (first slot) / load rax.
Z.BEST = {
	['2.7.3.0'] = { { 0x1402D17B3, 8, 'store', '488984fde0000000' }, { 0x1402D17CD, 7, 'first', '488985e0000000' },
		{ 0x1402D1815, 8, 'load', '488b84cde0000000' } },
	['2.6.6.0'] = { { 0x1402D1133, 8, 'store', '488984fde0000000' }, { 0x1402D114D, 7, 'first', '488985e0000000' },
		{ 0x1402D1195, 8, 'load', '488b84cde0000000' } },
}
local function bestCode(kind, buf)
	if kind == 'store' then -- push rcx / rcx = buf / mov [rcx + rdi*8], rax / pop rcx
		return cat({ 0x51 }, movImm(1, buf), { 0x48, 0x89, 0x04, 0xF9 }, { 0x59 })
	elseif kind == 'first' then -- push rcx / rcx = buf / mov [rcx], rax / pop rcx
		return cat({ 0x51 }, movImm(1, buf), { 0x48, 0x89, 0x01 }, { 0x59 })
	end
	return cat(movImm(0, buf), { 0x48, 0x8B, 0x04, 0xC8 }) -- rax = buf / mov rax, [rax + rcx*8]
end

-- Save guard (John 2026-10-24, before SadoEE 1.0): CInfGame::Marshal writes the GAM party header from m_nCharacters
-- but one entry per non -1 m_characters id: a stale or doubled id there wrote N+1 entries over party[0]'s CRE. Right
-- before its party loop (movsx eax, [rsi + 0x6630], rsi = game) a stub rebuilds m_characters from the real party:
-- ids that are not in m_charactersPortrait[0..count-1], or a second copy, become -1; a member missing from it goes to
-- the first free entry. Same rule as PSXP7_Sanitize() (the tick), but inside every save, whatever the screen.
Z.SAVE_GUARD = { ['2.7.3.0'] = { 0x14028281F, '0fbf8630660000' }, ['2.6.6.0'] = { 0x14028231F, '0fbf8630660000' } }
-- Tiny assembler: items are byte tables, label names (strings), { jcc opcode, label } (rel8 jumps) or
-- { { opcode bytes }, label, 'near' } (rel32 jumps).
local function assemble(items)
	local pos, labels, size = {}, {}, 0
	for i, it in ipairs(items) do
		pos[i] = size
		if type(it) == 'string' then labels[it] = size
		elseif it[3] == 'near' then size = size + #it[1] + 4
		elseif type(it[2]) == 'string' then size = size + 2
		else size = size + #it end
	end
	local out = {}
	for i, it in ipairs(items) do
		if type(it) == 'table' then
			if it[3] == 'near' then
				for _, b in ipairs(it[1]) do out[#out + 1] = b end
				local rel = labels[it[2]] - (pos[i] + #it[1] + 4)
				if rel < 0 then rel = rel + 2 ^ 32 end
				for _ = 1, 4 do out[#out + 1] = rel % 256 rel = math.floor(rel / 256) end
			elseif type(it[2]) == 'string' then
				local rel = labels[it[2]] - (pos[i] + 2)
				assert(rel >= -128 and rel <= 127, 'rel8 out of range')
				out[#out + 1] = it[1]
				out[#out + 1] = rel < 0 and rel + 256 or rel
			else
				for _, b in ipairs(it) do out[#out + 1] = b end
			end
		end
	end
	return out
end
local JGE, JE, JS, JMP = 0x7D, 0x74, 0x78, 0xEB
local function saveGuardCode(chars, ports, n, orig)
	return assemble({
		{ 0x50, 0x51, 0x52, 0x41, 0x50, 0x41, 0x51, 0x41, 0x52, 0x41, 0x53 }, -- push rax rcx rdx r8 r9 r10 r11
		cat({ 0x49, 0xB8 }, le64(chars)), cat({ 0x49, 0xB9 }, le64(ports)), -- r8 = chars, r9 = portraits
		{ 0x4C, 0x0F, 0xBF, 0x96, 0x30, 0x66, 0x00, 0x00 },        -- movsx r10, word [rsi + 0x6630] (count)
		{ 0x49, 0x83, 0xFA, n }, { { 0x0F, 0x8F }, 'done', 'near' }, -- cmp r10, n / jg done (never: safety)
		{ 0x45, 0x31, 0xDB },                                       -- xor r11d, r11d
		'l1', { 0x49, 0x83, 0xFB, n }, { JGE, 'p2' },               -- i < n
		{ 0x43, 0x8B, 0x0C, 0x98 }, { 0x83, 0xF9, 0xFF }, { JE, 'next1' }, -- ecx = chars[i], -1 -> next
		{ 0x31, 0xD2 },                                             -- j = 0
		'dup', { 0x4C, 0x39, 0xDA }, { JGE, 'mem' },                -- j < i
		{ 0x41, 0x39, 0x0C, 0x90 }, { JE, 'clear' },                -- chars[j] == id -> second copy
		{ 0x48, 0xFF, 0xC2 }, { JMP, 'dup' },
		'mem', { 0x4C, 0x89, 0xD2 },                                -- k = count
		'mloop', { 0x48, 0xFF, 0xCA }, { JS, 'clear' },             -- --k < 0 -> not a member
		{ 0x41, 0x39, 0x0C, 0x91 }, { JE, 'next1' },                -- portraits[k] == id -> keep
		{ JMP, 'mloop' },
		'clear', { 0x43, 0xC7, 0x04, 0x98, 0xFF, 0xFF, 0xFF, 0xFF }, -- chars[i] = -1
		'next1', { 0x49, 0xFF, 0xC3 }, { JMP, 'l1' },
		'p2', { 0x45, 0x31, 0xDB },                                 -- k = 0
		'l2', { 0x4D, 0x39, 0xD3 }, { JGE, 'done' },                -- k < count
		{ 0x43, 0x8B, 0x0C, 0x99 }, { 0x83, 0xF9, 0xFF }, { JE, 'next2' }, -- ecx = portraits[k]
		{ 0x31, 0xD2 },
		'find', { 0x48, 0x83, 0xFA, n }, { JGE, 'add' },
		{ 0x41, 0x39, 0x0C, 0x90 }, { JE, 'next2' },                -- already in chars
		{ 0x48, 0xFF, 0xC2 }, { JMP, 'find' },
		'add', { 0x31, 0xD2 },
		'free', { 0x48, 0x83, 0xFA, n }, { JGE, 'next2' },
		{ 0x41, 0x83, 0x3C, 0x90, 0xFF }, { JE, 'put' },            -- chars[j] == -1
		{ 0x48, 0xFF, 0xC2 }, { JMP, 'free' },
		'put', { 0x41, 0x89, 0x0C, 0x90 },                          -- chars[j] = id
		'next2', { 0x49, 0xFF, 0xC3 }, { JMP, 'l2' },
		'done', { 0x41, 0x5B, 0x41, 0x5A, 0x41, 0x59, 0x41, 0x58, 0x5A, 0x59, 0x58 }, -- pop r11 r10 r9 r8 rdx rcx rax
		orig,                                                       -- movsx eax, word [rsi + 0x6630]
	})
end

-- No buff icons on small portraits (John 2026-10-25: the bottom bar's 38x53 minis): CGameSprite::RenderPortrait
-- draws the portrait icon list (sprite + 0x4CC8) after the HP and the frame; a stub at that loop's first load jumps
-- to the "empty list" exit when the portrait is under 60 px high (rect bottom [rbp-4] - top [rbp-0xC]). The game's
-- bar (90 px) and the 7+ columns (a tenth of the screen height) keep their icons.
Z.NO_ICONS = { ['2.7.3.0'] = { 0x14037033D, 0x140370431 }, ['2.6.6.0'] = { 0x14036FCFD, 0x14036FDF1 } }
Z.NO_ICONS_ORIG = '498b86c84c0000' -- mov rax, [r14 + 0x4CC8]
Z.NO_ICONS_H = 60

-- CScreenWorld::RemoveCharacterFromParty ("Modifier le groupe", John 2026-10-25) finds the leaver in the pick list
-- (redirected) but then shifts the list down through "add rdx, 0x286 / lea rdx, [rsi + rdx*4]" = the OLD in-struct
-- int[10] at +0xA18: our list kept the leaver (the next click removed the wrong member: a dog -> a human) and, past
-- 10 entries, the shift wrote over the list count at +0xA40 and the next fields (the panel came up empty). Those 11
-- bytes now give rdx = pick list + index * 4.
Z.PICK_SHIFT = { ['2.7.3.0'] = 0x1402F8AEB, ['2.6.6.0'] = 0x1402F84AB }
Z.PICK_SHIFT_ORIG = '4881c286020000488d1496' -- add rdx, 0x286 / lea rdx, [rsi + rdx*4]

function PSXP7_Enable(n)
	n = math.floor(tonumber(n) or 8)
	if Z.enabled then return true, 'already enabled (' .. Z.n .. ')' end
	if n < 7 or n > 32 then return false, 'n must be 7-32' end
	local build, t = findBuild()
	if not build then return false, 'unknown build or code already patched' end
	local game = gamePtr()
	if not game or game == 0 then return false, 'CInfGame not created yet' end
	if t.pick then -- checked before anything is written: a half-patched engine would be worse than none
		local okWs, ws = pcall(function() return EEex_UDToPtr(EngineGlobals.g_pBaldurChitin.m_pEngineWorld) end)
		if not okWs or not ws or ws == 0 then return false, 'CScreenWorld not created yet' end
		Z.wsPtr = ws
	end
	local pickShift = t.pick and Z.PICK_SHIFT[build]
	if pickShift and not bytesAt(pickShift, hexBytes(Z.PICK_SHIFT_ORIG)) then pickShift = nil print('[PSXP7] pick list shift bytes differ: not patched') end
	local noIcons = Z.NO_ICONS[build]
	if noIcons and not bytesAt(noIcons[1], hexBytes(Z.NO_ICONS_ORIG)) then noIcons = nil print('[PSXP7] RenderPortrait bytes differ: icons kept') end
	local guard = Z.SAVE_GUARD[build]
	if guard and not bytesAt(guard[1], hexBytes(guard[2])) then guard = nil print('[PSXP7] Marshal bytes differ: no save guard') end
	local best = Z.BEST[build]
	for _, b in ipairs(best or {}) do
		if not bytesAt(b[1], hexBytes(b[4])) then best = nil print('[PSXP7] SwapWithSlot bytes differ: its patch is skipped') break end
	end
	if t.piles then
		local okInv, inv = pcall(function() return EEex_UDToPtr(EngineGlobals.g_pBaldurChitin.m_pEngineInventory) end)
		if not okInv or not inv or inv == 0 then return false, 'CScreenInventory not created yet' end
		Z.invPtr = inv
	end
	-- New arrays: [0] m_characters[n], [n*4] m_charactersPortrait[n].
	local mem = EEex_Malloc(n * 8)
	for i = 0, n - 1 do
		EEex_Write32(mem + i * 4, i < 6 and EEex_Read32(game + OFF_CHARS + i * 4) or -1)
		EEex_Write32(mem + n * 4 + i * 4, i < 6 and EEex_Read32(game + OFF_PORTRAITS + i * 4) or -1)
	end
	-- CInfGame is allocated once at startup: its address is a constant for the whole session.
	local delta = { [0] = mem - (game + OFF_CHARS), [1] = mem + n * 4 - (game + OFF_PORTRAITS) }
	Z.game = game
	-- Stubs first (not reachable yet), then the jumps into them.
	local jumps = {}
	EEex_DisableCodeProtection()
	local p6 = t.objects and t.objects[6]
	local destroy = t.clears and t.clears.destroy
	for _, s in ipairs(t.redirect) do
		if s[1] ~= p6 then -- the Decode Player6 load gets its own stub (objectStubs)
			local code = stubCode(s, delta)
			if s[1] == destroy then
				-- CInfGame::DestroyGame (every load / new game) clears m_characters with 3 qword stores of r13 (-1) = 6 entries:
				-- entries 6+ kept the previous game's ids (crash #4 in CGameSprite::Marshal, BOT playtest). Clear them too.
				code = cat(code, { 0x50 }, movImm(0, mem + 24))
				local k = 0
				while k + 8 <= (n - 6) * 4 do code = cat(code, { 0x4C, 0x89, 0x68, k }) k = k + 8 end
				if k < (n - 6) * 4 then code = cat(code, { 0x44, 0x89, 0x68, k }) end
				code = cat(code, { 0x58 })
			end
			jumps[#jumps + 1] = { s[1], makeStub(s[1], s[2], code) }
		end
	end
	-- CInfGame::RemoveCharacterFromParty clears the leaver's id in m_characters with 6 unrolled compares: entries 6+ too
	-- (ebp = id, r12d = -1), then the 2 instructions replaced by the jump.
	if t.clears then
		local r = t.clears.remove
		local code = cat({ 0x50, 0x52 }, movImm(0, mem + 24), { 0xBA }, le(n - 6, 4),
			{ 0x39, 0x28, 0x75, 0x03, 0x44, 0x89, 0x20, 0x48, 0x83, 0xC0, 0x04, 0xFF, 0xCA, 0x75, 0xF1 },
			{ 0x5A, 0x58 }, hexBytes(r[2]))
		jumps[#jumps + 1] = { r[1], makeStub(r[1], 8, code) }
	end
	if t.objects then objectStubs(t.objects, n, mem, jumps) end
	-- CScreenInventory::FetchGroundPile keeps per-portrait ground piles in int[6] at +0x688 and fetched flags in int[6]
	-- at +0x6A0: from portrait 7 on it wrote over the screen's next fields (+0x6C4 = "character holding the item" ->
	-- "This character is too far away" when equipping member 8, John 2026-10-23). Both go to int[n] arrays.
	if t.piles then
		local inv = Z.invPtr
		local piles, fetched = EEex_Malloc(n * 4), EEex_Malloc(n * 4)
		for i = 0, n - 1 do EEex_Write32(piles + i * 4, -1) EEex_Write32(fetched + i * 4, 0) end
		local pd = { [0] = piles - (inv + 0x688), [1] = fetched - (inv + 0x6A0) }
		local clearAt = {}
		for _, c in ipairs(t.piles.clears) do clearAt[c[1]] = c[2] end
		for _, k in ipairs(t.piles.sites) do
			local code = stubCode(k, pd)
			local src = clearAt[k[1]]
			if src then -- 3rd qword store of the flags: clear entries 6..n-1 too (mov [r11 + d8], src)
				code = cat(code, pushReg(11), movImm(11, fetched + 24))
				local d = 0
				while d + 8 <= (n - 6) * 4 do code = cat(code, { 0x4D - (src >= 8 and 0 or 4), 0x89, 0x43 + (src % 8) * 8, d }) d = d + 8 end
				if d < (n - 6) * 4 then code = cat(code, { 0x45 - (src >= 8 and 0 or 4), 0x89, 0x43 + (src % 8) * 8, d }) end
				code = cat(code, popReg(11))
			end
			jumps[#jumps + 1] = { k[1], makeStub(k[1], k[2], code) }
		end
		Z.pileMem, Z.fetchedMem = piles, fetched
	end
	-- Formations (CAIGroup::GetOffsets): members 0..FORM_N-1 of formations 0-11 read our table; formation 12 ("keep
	-- relative positions") and groups past FORM_N keep the engine's way.
	if t.formation then
		local f, N = t.formation, Z.FORM_N
		local tbl = formationTable(f, N)
		Z.formTable = tbl
		jumps[#jumps + 1] = { f.site, makeStub(f.site, 6, function(stub)
			-- cmp rbx, N / jae engine / cmp esi, 11 / ja engine / rax = tbl[esi * N + rbx] / jmp store / engine: cmp rbx, 7 / jl near
			-- (N = 32: esi * N * 8 = esi << 8)
			return cat({ 0x48, 0x83, 0xFB, N, 0x73, 45 }, { 0x83, 0xFE, 0x0B, 0x77, 40 },
				{ 0x51, 0x48, 0x89, 0xF1, 0x48, 0xC1, 0xE1, 0x08 }, movImm(0, tbl), { 0x48, 0x01, 0xC8, 0x48, 0x8B, 0x04, 0xD8, 0x59 },
				{ 0xFF, 0x25, 0, 0, 0, 0 }, le64(f.store),
				{ 0x48, 0x83, 0xFB, 0x07, 0x0F, 0x8C }, rel32(stub + 61, f.near))
		end, 61) }
	end
	-- "Party full, pick who leaves" (CScreenWorld::StartPickParty, crash 25 found by the BOT playtest at 16 + Imoen):
	-- its list is int[10] at CScreenWorld + 0xA18 (every member but the protagonist + the newcomers) -> int[n + 16].
	if t.pick then
		local ws = Z.wsPtr
		local pick = EEex_Malloc((n + 16) * 4)
		for i = 0, n + 15 do EEex_Write32(pick + i * 4, -1) end
		local pdelta = { [0] = pick - (ws + 0xA18) }
		for _, k in ipairs(t.pick) do
			local code = stubCode({ k[1], k[2], k[3], 0, k[4], k[5], k[6] }, pdelta)
			jumps[#jumps + 1] = { k[1], makeStub(k[1], k[2], code) }
		end
		Z.pickMem, Z.pickWs = pick, ws
		if pickShift then -- shl rdx, 2 / movabs rax, pick / add rdx, rax (rax is free: the loop reloads it)
			jumps[#jumps + 1] = { pickShift, makeStub(pickShift, 11, cat({ 0x48, 0xC1, 0xE2, 0x02, 0x48, 0xB8 }, le64(pick),
				{ 0x48, 0x01, 0xC2 })) }
			Z.pickShift = pickShift
		end
	end
	for _, o in ipairs(t.offsets or {}) do
		jumps[#jumps + 1] = { o[1], makeStub(o[1], o[2], offsetStub(o, delta)) }
	end
	if noIcons then
		jumps[#jumps + 1] = { noIcons[1], makeStub(noIcons[1], 7, function(stub)
			-- push rcx / mov ecx, [rbp-4] / sub ecx, [rbp-0xC] / cmp ecx, H / pop rcx / jl skip / mov rax, [r14+0x4CC8]
			return cat({ 0x51, 0x8B, 0x4D, 0xFC, 0x2B, 0x4D, 0xF4, 0x83, 0xF9, Z.NO_ICONS_H, 0x59, 0x0F, 0x8C },
				rel32(stub + 17, noIcons[2]), hexBytes(Z.NO_ICONS_ORIG))
		end, 24) }
		Z.noIcons = noIcons
	end
	if guard then
		jumps[#jumps + 1] = { guard[1], makeStub(guard[1], 7, saveGuardCode(mem, mem + n * 4, n, hexBytes(guard[2]))) }
		Z.saveGuard = guard
	end
	if best then
		local buf = EEex_Malloc(n * 8)
		for _, b in ipairs(best) do jumps[#jumps + 1] = { b[1], makeStub(b[1], b[2], bestCode(b[3], buf)) } end
		Z.bestMem, Z.bestSites = buf, best
	end
	local nRedirect = #jumps
	Z.marshalBuf = marshalPatch(t, n, jumps)
	for _, j in ipairs(jumps) do writeBytes(j[1], j[2]) end
	for _, a in ipairs(t.bounds) do EEex_WriteU8(a, n) end
	-- Names of party members with a custom name are the special strrefs -2 - slot (CGameSprite::GetNameRef), accepted
	-- by "lea eax, [r + 7] / cmp eax, 5 / ja" = 6 slots: members 7+ showed "Invalid: 16777207" in feedback (John).
	for _, r in ipairs(t.names or {}) do EEex_WriteU8(r[1], n + 1) EEex_WriteU8(r[2], n - 1) end
	-- The game's MAX_CHARACTERS byte (6, .rdata) bounds the party loops of area transitions, scripted teleports
	-- (LeaveAreaLUAPanic: Gorion's cutscene), world-map travel and store start (found by the BOT playtest, 2026-10-23):
	-- those reads point to a byte of ours (n) instead; the "i < 6 -> m_characters[i]" guards in them say n.
	-- "Gather your party" (John 2026-10-23: exits are a pain with a big party): the squared radius read by
	-- CGameSprite::LeaveArea / LeaveAreaName comes from a cell of ours, scaled by PSXP7_GatherTick().
	if t.gather then
		local cell = EEex_AllocNear(8)
		EEex_Write32(cell, t.gather.base)
		Z.gatherOrig, Z.gatherCell, Z.gatherBase = {}, cell, t.gather.base
		for i, r in ipairs(t.gather.refs) do
			Z.gatherOrig[i] = EEex_Read32(r[1])
			EEex_Write32(r[1], cell - r[2])
		end
	end
	if t.maxchar then
		local cell = EEex_AllocNear(8)
		EEex_WriteU8(cell, n)
		Z.maxOrig = {}
		for i, r in ipairs(t.maxchar.refs) do
			Z.maxOrig[i] = EEex_Read32(r[1])
			local d = cell - r[2]
			EEex_Write32(r[1], d)
		end
		for _, a in ipairs(t.maxchar.guards) do EEex_WriteU8(a, n) end
	end
	EEex_Write32(t.marshal.size, n * ENTRY) -- memset of the party entries
	EEex_Write32(t.marshal.copy, n) -- loop copying the entries into the GAM (mov eax, 6)
	EEex_EnableCodeProtection()
	Z.enabled, Z.n, Z.mem, Z.build, Z.jumps = true, n, mem, build, jumps
	print(string.format('[PSXP7] party size %d enabled on %s: %d accesses redirected, %d bounds raised, save buffer %d',
		n, build, nRedirect, #t.bounds, #jumps - nRedirect))
	return true
end

-- Puts the original code back (members 7+ are dropped from the arrays' copy; the count is clamped to 6).
-- `only` (optional) = set of redirect indexes to leave patched, for bisecting a fault.
function PSXP7_Disable(only)
	if not Z.enabled then return false, 'not enabled' end
	local t = PSXP7_SITES[Z.build]
	PSXP7_Mirror()
	EEex_DisableCodeProtection()
	for i, s in ipairs(t.redirect) do
		if not (only and only[i]) then writeBytes(s[1], hexBytes(s[6])) end
	end
	if not only then
		for _, a in ipairs(t.bounds) do EEex_WriteU8(a, 6) end
		for _, r in ipairs(t.names or {}) do EEex_WriteU8(r[1], 7) EEex_WriteU8(r[2], 5) end
		for _, m in ipairs(t.marshal.sites) do writeBytes(m[1], hexBytes(m[3])) end
		for _, o in ipairs(t.offsets or {}) do writeBytes(o[1], hexBytes(o[7])) end
		if t.objects then writeBytes(t.objects[1], hexBytes(t.objects[2])) end
		for _, k in ipairs(t.piles and t.piles.sites or {}) do writeBytes(k[1], hexBytes(k[6])) end
		if t.formation then writeBytes(t.formation.site, hexBytes(t.formation.orig)) end
		if t.clears then writeBytes(t.clears.remove[1], hexBytes(t.clears.remove[2])) end
		for _, k in ipairs(t.pick or {}) do writeBytes(k[1], hexBytes(k[5])) end
		for _, b in ipairs(Z.bestSites or {}) do writeBytes(b[1], hexBytes(b[4])) end
		if Z.saveGuard then writeBytes(Z.saveGuard[1], hexBytes(Z.saveGuard[2])) end
		if Z.noIcons then writeBytes(Z.noIcons[1], hexBytes(Z.NO_ICONS_ORIG)) end
		if Z.pickShift then writeBytes(Z.pickShift, hexBytes(Z.PICK_SHIFT_ORIG)) end
		if t.gather and Z.gatherOrig then
			for i, r in ipairs(t.gather.refs) do EEex_Write32(r[1], Z.gatherOrig[i]) end
		end
		if t.maxchar and Z.maxOrig then
			for i, r in ipairs(t.maxchar.refs) do EEex_Write32(r[1], Z.maxOrig[i]) end
			for _, a in ipairs(t.maxchar.guards) do EEex_WriteU8(a, 6) end
		end
		EEex_Write32(t.marshal.size, 0x870)
		EEex_Write32(t.marshal.copy, 6)
	end
	EEex_EnableCodeProtection()
	if not only then
		local game = gamePtr()
		if EEex_ReadU16(game + 0x6630) > 6 then EEex_Write16(game + 0x6630, 6) end
		Z.enabled = false
	end
	return true
end

-- Re-patches only the redirect sites whose index is in `set` (after PSXP7_Disable(), stubs are kept): bisecting.
function PSXP7_Repatch(set)
	if not Z.jumps then return false end
	EEex_DisableCodeProtection()
	for i in pairs(set) do writeBytes(Z.jumps[i][1], Z.jumps[i][2]) end
	EEex_EnableCodeProtection()
	return true
end

-- Party arrays as Lua tables (works before and after PSXP7_Enable).
function PSXP7_Party()
	local game, chars, ports = gamePtr(), {}, {}
	local n = Z.enabled and Z.n or 6
	local cBase = Z.enabled and Z.mem or game + OFF_CHARS
	local pBase = Z.enabled and Z.mem + n * 4 or game + OFF_PORTRAITS
	for i = 0, n - 1 do
		chars[i] = EEex_Read32(cBase + i * 4)
		ports[i] = EEex_Read32(pBase + i * 4)
	end
	return { count = EEex_ReadS16 and EEex_ReadS16(game + 0x6630) or EEex_ReadU16(game + 0x6630), size = n,
		chars = chars, portraits = ports }
end

-- The engine no longer reads the old in-struct arrays: they get a copy of the first 6 entries, so Lua code that
-- reads them through the EEex bindings (other mods: m_charactersPortrait:get(i)) still sees the first 6 members.
-- Keeps the two party arrays consistent (John 2026-10-24, corrupt EET saves): m_characters (join order, holes = -1)
-- must hold exactly the ids of m_charactersPortrait[0..count-1]. A stale id (an ex-member left there, or one id twice)
-- made CInfGame::Marshal write 16 party entries for a count of 15: the 16th overwrote party[0]'s CRE in the GAM, and
-- the save crashed on load. Every tick: portraits past the count -> -1, m_characters ids that are not a current member
-- (or a second copy) -> -1, a member missing from m_characters -> first free entry. Returns the number of fixes.
function PSXP7_Sanitize()
	if not Z.enabled then return 0 end
	local game, n, mem = gamePtr(), Z.n, Z.mem
	local count = EEex_ReadU16(game + 0x6630)
	if count > n then return 0 end
	local P, fixes, member = mem + n * 4, 0, {}
	for i = 0, n - 1 do
		local id = EEex_Read32(P + i * 4)
		if i < count then
			if id ~= -1 then member[id] = false end
		elseif id ~= -1 then
			EEex_Write32(P + i * 4, -1) fixes = fixes + 1
		end
	end
	for i = 0, n - 1 do
		local id = EEex_Read32(mem + i * 4)
		if id ~= -1 then
			if member[id] == false then member[id] = true
			else EEex_Write32(mem + i * 4, -1) fixes = fixes + 1 end
		end
	end
	for id, seen in pairs(member) do
		if not seen then
			for i = 0, n - 1 do
				if EEex_Read32(mem + i * 4) == -1 then EEex_Write32(mem + i * 4, id) fixes = fixes + 1 break end
			end
		end
	end
	if fixes > 0 then
		Z.sanitizeLog = (Z.sanitizeLog or 0) + fixes
		print(string.format('[PSXP7] party arrays: %d stale entries fixed', fixes))
	end
	return fixes
end

function PSXP7_Mirror()
	if not Z.enabled then return end
	pcall(PSXP7_Sanitize)
	local game = gamePtr()
	for i = 0, 5 do
		EEex_Write32(game + OFF_CHARS + i * 4, EEex_Read32(Z.mem + i * 4))
		EEex_Write32(game + OFF_PORTRAITS + i * 4, EEex_Read32(Z.mem + Z.n * 4 + i * 4))
	end
end

-- EEex's own party getters, wrapped to read the new arrays (all n entries).
local function slotId(kind, i)
	if type(i) ~= 'number' or i < 0 or i >= Z.n then return -1 end
	return EEex_Read32(Z.mem + kind * Z.n * 4 + i * 4)
end
local function indexOf(kind, sprite)
	local id = sprite.m_id
	for i = 0, Z.n - 1 do if slotId(kind, i) == id then return i end end
	return -1
end
if not Z.wrapped then
	Z.wrapped = true
	local getSprite, getId = EEex_Sprite_GetInPortrait, EEex_Sprite_GetInPortraitID
	local getPortrait, getChar = EEex_Sprite_GetPortraitIndex, EEex_Sprite_GetCharacterIndex
	EEex_Sprite_GetInPortrait = function(i)
		if not Z.enabled then return getSprite(i) end
		return EEex_GameObject_Get(slotId(1, i))
	end
	EEex_Sprite_GetInPortraitID = function(i)
		if not Z.enabled then return getId(i) end
		return slotId(1, i)
	end
	EEex_Sprite_GetPortraitIndex = function(sprite)
		if not Z.enabled then return getPortrait(sprite) end
		return indexOf(1, sprite)
	end
	EEex_Sprite_GetCharacterIndex = function(sprite)
		if not Z.enabled then return getChar(sprite) end
		return indexOf(0, sprite)
	end
	CGameSprite.getPortraitIndex = EEex_Sprite_GetPortraitIndex
	CGameSprite.getCharacterIndex = EEex_Sprite_GetCharacterIndex
end

-- Adds a creature (object id) to the party through the engine, in the first free portrait slot.
-- CInfGame::AddCharacterToParty(this, id, portrait = -1 -> next slot); returns 1 on success.
Z.ADD = { ['2.7.3.0'] = 0x14026D2D0, ['2.6.6.0'] = 0x14026D070 }
Z.ADD_PROLOGUE = { 0x40, 0x53, 0x55, 0x56, 0x57, 0x41, 0x57, 0x48, 0x83, 0xEC, 0x40 }
function PSXP7_Add(id)
	if not Z.enabled then return false, 'not enabled' end
	local f = Z.ADD[Z.build]
	if not f then return false, 'no AddCharacterToParty address for ' .. Z.build end
	if not bytesAt(f, Z.ADD_PROLOGUE) then return false, 'AddCharacterToParty prologue mismatch' end
	if not _G.PSXP7_Eng_AddCharacterToParty then
		if not (PStash and PStash.buildStub) then return false, 'needs Party Stash (stub builder)' end
		PStash.buildStub('PSXP7_AddCharacterToParty', f, 3) -- exposed as PStash_Eng_PSXP7_AddCharacterToParty
		_G.PSXP7_Eng_AddCharacterToParty = _G.PStash_Eng_PSXP7_AddCharacterToParty
	end
	return PSXP7_Eng_AddCharacterToParty(gamePtr(), id, 0xFFFF) % 256 ~= 0
end

-- Test switch: an override file PSXP7ON.2DA (any content) enables the patch (n = PSXP7_N or 8) before any save is loaded (no
-- `io` in the game's Lua). Override files are only seen after a game restart. CInfGame does not exist yet when the UI
-- file loads: the switch is read then, and the enable is retried on every menu push until it works (the main menu
-- pushes several before a game can be loaded).
local function autoEnable()
	if Z.enabled or not Z.autoWanted then return end
	local ok, res, why = pcall(PSXP7_Enable, tonumber(PSXP7_N) or 8) -- PSXP7_N: optional, set in M_PSXP7C.lua
	if ok and res then Z.autoWanted = false print('[PSXP7] auto-enabled') elseif not ok then
		Z.autoWanted = false print('[PSXP7] auto-enable error: ' .. tostring(res)) end
end
if not Z.autoHooked then
	Z.autoHooked = true
	EEex_Menu_AddMainFileLoadedListener(function()
		local ok, h = pcall(EEex_Resource_Demand, 'PSXP7ON', '2DA')
		Z.autoWanted = ok and h ~= nil
		autoEnable()
	end)
	local push = Infinity_PushMenu
	Infinity_PushMenu = function(...)
		local r = table.pack(push(...))
		if Z.autoWanted then pcall(autoEnable) end
		return table.unpack(r, 1, r.n)
	end
end

-----------------------
-- Portrait bar 7+    --
-----------------------
-- PSXP7_BAR (PSXP7.menu): a second portrait bar left of the game's (RIGHT_SIDEBAR, 80 wide), same look at 2/3 size,
-- for members 7+ (John 2026-10-23). Engine portrait buttons: the render, click and tooltip read the redirected arrays
-- and are bounded by m_nCharacters. Right-click = inventory, drop an item = give it (the 6 / 7 compared in
-- CInfGame::SwapItemPersonal come from the item / slot, not the portrait: checked 2026-10-23, items moved both ways).
Z.BAR_W = 54
-- Infinity_IsMenuOnStack returns 1 / nil, not a boolean.
local function onStack(m) local r = Infinity_IsMenuOnStack(m) return r ~= nil and r ~= false and r ~= 0 end
-- Screens wider than the game's (Party Stash's inventory page) cover the columns: there, the party gets one bar at the
-- bottom of the screen instead (PSXP7_BOTTOM, John 2026-10-23), centered, scrolled when it does not fit. John
-- 2026-10-25: also on the character sheet and the spellbooks; in a spellbook only the members who have spells of it.
Z.BOTTOM_MENUS = { 'INVENTORY', 'CHARACTER', 'MAGE', 'PRIEST' }
local function bottomMenu()
	for _, m in ipairs(Z.BOTTOM_MENUS) do if onStack(m) then return m end end
	return nil
end
local function bottomMode() return bottomMenu() ~= nil end
function PSXP7_BarVisible()
	if Z.pendingMove and Z.processPending then Z.processPending() end
	return Z.enabled == true and Infinity_GetNumCharacters() > 6 and onStack('RIGHT_SIDEBAR') and not bottomMode()
end
function PSXP7_BottomVisible()
	if Z.pendingMove and Z.processPending then Z.processPending() end
	return Z.enabled == true and Infinity_GetNumCharacters() > 6 and bottomMode()
end

-- The 7+ columns (PSXP7_BAR, John 2026-10-25): only the portraits, no backdrop and no tab, touching, 10 per column
-- filling the screen height (7-16 next to the game's bar, then 17-26, 27-32 further left). Placed by
-- PSXP7_ColumnsLayout() (Infinity_SetArea on PSXP7_C6..31) when the party or the screen size changes.
Z.COL_ASPECT = 64 / 90 -- the game's portrait shape
function PSXP7_ColumnsLayout()
	if not PSXP7_BarVisible() then return false end
	local n = Infinity_GetNumCharacters()
	local sw, sh = Infinity_GetScreenSize()
	local key = n .. 'x' .. sw .. 'x' .. sh
	if Z.colKey == key then return true end
	Z.colKey = key
	local ph = math.floor(sh / 10)
	local pw = math.floor(ph * Z.COL_ASPECT)
	Z.colW, Z.colAreas = pw, {}
	for i = 6, 31 do
		if i < n then
			local k = i - 6
			local x, y = sw - 80 - (math.floor(k / 10) + 1) * pw, (k % 10) * ph
			pcall(Infinity_SetArea, 'PSXP7_C' .. i, x, y, pw, ph)
			Z.colAreas[i] = { x, y, pw, ph }
		else
			pcall(Infinity_SetArea, 'PSXP7_C' .. i, -100, -100, 1, 1)
		end
	end
	return true
end

-- The bottom bar: the whole party in one row (John: members 1-6 too), scrolled with the mouse wheel over the bar or
-- the arrows at both ends when it does not fit. Portrait buttons PSXP7_B0..31 (one per member), arrows PSXP7_BL /
-- PSXP7_BR. In the MAGE / PRIEST spellbooks, only the members who know spells of that book.
Z.BOT_PW, Z.BOT_PH, Z.BOT_GAP, Z.BOT_ARROW = 38, 53, 3, 22 -- John 2026-10-23: 38x53, over the page's bottom frame
Z.botScroll = Z.botScroll or 0
local function knowsSpells(sp, book)
	local it = book == 'MAGE' and EEex_Sprite_GetKnownMageSpellsIterator or EEex_Sprite_GetKnownPriestSpellsIterator
	if not it then return true end
	local ok, res = pcall(function() for _ in it(sp) do return true end return false end)
	return not ok or res
end
-- Portrait indexes shown in the bottom bar, cached for a second (spell lists change rarely).
local function botMembers()
	local menu = bottomMenu()
	local n = Infinity_GetNumCharacters()
	local now = Infinity_GetClockTicks()
	local c = Z.botMembers
	if c and c.menu == menu and c.n == n and now < c.expires then return c.list end
	local list = {}
	for i = 0, n - 1 do
		local keep = true
		if menu == 'MAGE' or menu == 'PRIEST' then
			local sp = EEex_Sprite_GetInPortrait(i)
			keep = sp ~= nil and knowsSpells(sp, menu)
		end
		if keep then list[#list + 1] = i end
	end
	Z.botMembers = { menu = menu, n = n, expires = now + 1000, list = list }
	return list
end
local function botGeometry()
	local list = botMembers()
	local m = #list
	local sw, sh = Infinity_GetScreenSize()
	local step = Z.BOT_PW + Z.BOT_GAP
	local fit = math.max(1, math.floor((sw - 16) / step))
	local scrolls = m > fit
	if scrolls then fit = math.max(1, math.floor((sw - 16 - 2 * (Z.BOT_ARROW + Z.BOT_GAP)) / step)) end
	return m, sw, sh, step, fit, scrolls, list
end
function PSXP7_BottomScroll(d)
	local m, _, _, _, fit = botGeometry()
	local s = math.max(0, math.min(m - fit, Z.botScroll + d))
	if s ~= Z.botScroll then Z.botScroll = s Z.botKey = nil end
end
function PSXP7_BottomCanScroll(d)
	if not PSXP7_BottomVisible() then return false end
	local m, _, _, _, fit, scrolls = botGeometry()
	if not scrolls then return false end
	return d < 0 and Z.botScroll > 0 or d > 0 and Z.botScroll < m - fit
end
-- Places the portraits, the arrows and the backdrop (PSXP7_BBG) when the party, the screen, the shown members or the
-- scroll change.
function PSXP7_BottomLayout()
	if not PSXP7_BottomVisible() then return false end
	local m, sw, sh, step, fit, scrolls, list = botGeometry()
	Z.botScroll = scrolls and math.max(0, math.min(m - fit, Z.botScroll)) or 0
	local key = table.concat({ table.concat(list, ','), sw, sh, Z.botScroll }, 'x')
	if Z.botKey == key then return true end
	Z.botKey = key
	local pw, ph, gap, aw = Z.BOT_PW, Z.BOT_PH, Z.BOT_GAP, Z.BOT_ARROW
	local shown = math.min(m, fit)
	local rowW = math.max(0, shown * step - gap) + (scrolls and 2 * (aw + gap) or 0)
	local x0 = math.floor((sw - rowW) / 2)
	local top = sh - ph - 1
	local px = x0 + (scrolls and aw + gap or 0)
	local pos = {}
	for k, i in ipairs(list) do pos[i] = k - 1 end
	Z.botAreas = {}
	for i = 0, 31 do
		local k = pos[i] and (pos[i] - Z.botScroll)
		if k and k >= 0 and k < shown then
			pcall(Infinity_SetArea, 'PSXP7_B' .. i, px + k * step, top, pw, ph)
			Z.botAreas[i] = { px + k * step, top, pw, ph }
		else
			pcall(Infinity_SetArea, 'PSXP7_B' .. i, -100, -100, 1, 1)
		end
	end
	pcall(Infinity_SetArea, 'PSXP7_BL', scrolls and x0 or -100, scrolls and top or -100, aw, ph)
	pcall(Infinity_SetArea, 'PSXP7_BR', scrolls and (x0 + rowW - aw) or -100, scrolls and top or -100, aw, ph)
	if shown > 0 then
		pcall(Infinity_SetArea, 'PSXP7_BBG', x0 - 3, top - 2, rowW + 6, sh - top + 2)
		Z.botRect = { x0 - 3, top - 2, rowW + 6, sh - top + 2 }
	else
		pcall(Infinity_SetArea, 'PSXP7_BBG', -100, -100, 1, 1)
		Z.botRect = nil
	end
	return true
end
-- The portrait (0-based) of our bars under the mouse, or nil: the 7+ columns and the bottom bar (their placed areas).
local function ourPortraitAt(mx, my)
	if not mx then return nil end
	local areas = PSXP7_BarVisible() and Z.colAreas or (PSXP7_BottomVisible() and Z.botAreas) or nil
	for i, r in pairs(areas or {}) do
		if mx >= r[1] and mx < r[1] + r[3] and my >= r[2] and my < r[2] + r[4] then return i end
	end
	return nil
end
-- Portrait moves asked by a drop are done on the next frame (PSXP7_BarVisible / PSXP7_BottomVisible run every
-- frame, PSXP7_BarTick as a fallback), not inside the SDL event. Z.dragLog keeps the last drops (debug).
Z.dragLog = Z.dragLog or {}
local function dragLog(msg)
	table.insert(Z.dragLog, msg)
	if #Z.dragLog > 20 then table.remove(Z.dragLog, 1) end
end
local function processPending()
	local m = Z.pendingMove
	if not m then return end
	Z.pendingMove = nil
	local ok, res = pcall(PSXP7_MoveMember, m[1], m[2])
	dragLog(string.format('move %d -> %d: %s', m[1], m[2], tostring(ok and res or res)))
end
Z.processPending = processPending
-- SDL events (EEex sees the mouse only through this hook, as SadoQoL #12 does):
-- - the mouse wheel over the bottom bar scrolls it;
-- - a portrait drag (draggedPortrait, set by every portrait's actionSimpleDrag) released over a portrait: the target is
--   the hovered one (mouseOverPortrait, set by every portrait's actionEnter: the game's bar, the columns, the bottom
--   bar), else the one of our bars under the mouse. The menus' actionSimpleDrop did not reach our buttons (John
--   2026-10-23: 1-6 -> 7+ and 7+ -> 7+ did nothing). Not consumed, so the UI ends its drag as usual; draggedPortrait
--   is cleared, so a drop that does reach swapPortraits / PSXP7_DropPortrait afterwards does nothing.
if not Z.wheelHooked and EEex_Key_Hook_AfterEventsPoll then
	Z.wheelHooked = true
	local orig = EEex_Key_Hook_AfterEventsPoll
	EEex_Key_Hook_AfterEventsPoll = function(event)
		local ok, used = pcall(function()
			if event.type == SDL_EventType.SDL_MOUSEBUTTONUP and event.button.button == 1 and draggedPortrait ~= nil
				and Z.enabled == true then
				local src = draggedPortrait
				local dest = type(mouseOverPortrait) == 'number' and mouseOverPortrait >= 0 and mouseOverPortrait or nil
				if dest == nil then dest = ourPortraitAt(Infinity_GetMousePosition()) end
				dragLog(string.format('drop %s on %s (hover %s)', tostring(src), tostring(dest), tostring(mouseOverPortrait)))
				if dest ~= nil then
					draggedPortrait = nil
					if dest ~= src then Z.pendingMove = { src, dest } end
				end
				return false
			end
			-- An item dropped on our portraits goes through their own actiondrag "Infinity_SwapWithPortrait(n)" (works:
			-- John 2026-10-23, bottom bar). Calling it here too gave the item twice and crashed (0xC0000409,
			-- __report_gsfailure, test BGEE 2.7.3): never add an item path here.
			if event.type ~= SDL_EventType.SDL_MOUSEWHEEL or event.wheel.y == 0 or not Z.botRect then return false end
			if not PSXP7_BottomVisible() then return false end
			local mx, my = Infinity_GetMousePosition()
			local r = Z.botRect
			if not mx or mx < r[1] or mx > r[1] + r[3] or my < r[2] or my > r[2] + r[4] then return false end
			PSXP7_BottomScroll(event.wheel.y > 0 and -1 or 1)
			return true
		end)
		if ok and used then return true end
		return orig(event)
	end
end

-- Drag and drop on the portraits (John 2026-10-23): a portrait dropped on another is INSERTED there, the members in
-- between shift by one; it works in every bar (the game's 1-6, the columns 7+, the bottom bar), member 1 included.
-- The engine's swap (CInfGame::SwapCharacters, no bound: it reads the redirected arrays) is applied step by step
-- between neighbours. World screen: worldScreen:SwapPortraits (the game's own path, it also re-sorts the group);
-- other screens (the inventory's bottom bar): SwapCharacters + CAIGroup::Sort through Party Stash's stub builder.
Z.SWAP = { ['2.7.3.0'] = 0x14028F970, ['2.6.6.0'] = 0x14028F3B0 }
Z.SWAP_PROLOGUE = { 0x48, 0x89, 0x6C, 0x24, 0x20, 0x56, 0x57, 0x41, 0x56, 0x48, 0x83, 0xEC, 0x20 }
Z.SORT = { ['2.7.3.0'] = 0x14011B070, ['2.6.6.0'] = 0x14011B050 } -- CAIGroup::Sort(game + 0x66B0)
-- The engine's swap itself (no screen guard: worldScreen:SwapPortraits silently refuses in some states and only works
-- on the world screen); worldScreen:SwapPortraits only when Party Stash's stub builder is missing.
local function engineSwap(a, b)
	local f = Z.SWAP[Z.build]
	if f and bytesAt(f, Z.SWAP_PROLOGUE) and PStash and PStash.buildStub then
		if not _G.PStash_Eng_PSXP7_SwapCharacters then PStash.buildStub('PSXP7_SwapCharacters', f, 3) end
		PStash_Eng_PSXP7_SwapCharacters(gamePtr(), a, b)
		return true
	end
	if worldScreen ~= nil then
		worldScreen:SwapPortraits(a, b)
		Z.sortedBySwap = true
		return true
	end
	return false
end
local function resort()
	if Z.sortedBySwap then Z.sortedBySwap = nil return end -- SwapPortraits did it
	local f = Z.SORT[Z.build]
	if not f or not (PStash and PStash.buildStub) then return end
	if not _G.PStash_Eng_PSXP7_GroupSort then PStash.buildStub('PSXP7_GroupSort', f, 1) end
	PStash_Eng_PSXP7_GroupSort(gamePtr() + 0x66B0)
end
-- Moves the member at portrait `from` to portrait `to` (0-based), the others shift by one.
function PSXP7_MoveMember(from, to)
	local n = Infinity_GetNumCharacters()
	if type(from) ~= 'number' or type(to) ~= 'number' or from == to or from < 0 or to < 0 or from >= n or to >= n then
		return false
	end
	local d = to > from and 1 or -1
	for i = from, to - d, d do
		if not engineSwap(i, i + d) then return false end
	end
	pcall(resort)
	return true
end
-- actionSimpleDrop of every portrait button (and the game's own swapPortraits, replaced while the patch is on)
function PSXP7_DropPortrait(dest)
	local src = draggedPortrait
	draggedPortrait = nil
	if src ~= nil then pcall(PSXP7_MoveMember, src, dest) end
end
local function hookSwapPortraits()
	if Z.enabled ~= true or type(swapPortraits) ~= 'function' or swapPortraits == Z.ourSwap then return end
	Z.gameSwap = swapPortraits
	Z.ourSwap = function(dest) PSXP7_DropPortrait(dest) end
	swapPortraits = Z.ourSwap
end
Z.hookSwapPortraits = function()
	hookSwapPortraits()
	if type(pushSidebars) == 'function' and pushSidebars ~= Z.ourPushSidebars then
		local orig = pushSidebars
		Z.ourPushSidebars = function(...)
			local r = table.pack(orig(...))
			if Z.enabled == true and Infinity_GetNumCharacters() > 6 then
				pcall(function()
					if onStack('PSXP7_BOTTOM') then Infinity_PopMenu('PSXP7_BOTTOM') end
					Z.botKey = nil
					Infinity_PushMenu('PSXP7_BOTTOM')
				end)
			end
			return table.unpack(r, 1, r.n)
		end
		pushSidebars = Z.ourPushSidebars
	end
end

-- Kept above the wide screen: pushed again right after it.
if not Z.bottomHooked then
	Z.bottomHooked = true
	local push = Infinity_PushMenu
	Infinity_PushMenu = function(...)
		local m = ...
		local r = table.pack(push(...))
		for _, w in ipairs(Z.BOTTOM_MENUS) do
			if m == w and Z.enabled == true and Infinity_GetNumCharacters() > 6 then
				pcall(function()
					if onStack('PSXP7_BOTTOM') then Infinity_PopMenu('PSXP7_BOTTOM') end
					Z.botKey = nil
					push('PSXP7_BOTTOM')
				end)
			end
		end
		return table.unpack(r, 1, r.n)
	end
end
-- Width taken left of the game's portrait bar (0 when hidden): other bars there (Party Stash companion bar) shift by it.
function PSXP7_BarWidth()
	if not PSXP7_BarVisible() then return 0 end
	local c = Infinity_GetNumCharacters()
	return (c > 26 and 3 or c > 16 and 2 or 1) * (Z.colW or Z.BAR_W) -- 10 per column: 7-16, 17-26, 27-32 (John)
end

-- Gather radius scale: x1 up to 6 members, then members / 6 (x2 at 12, x3 at 18), at most x4 (John: "rayon élargi").
Z.GATHER_MAX = 4
function PSXP7_GatherScale() return math.min(Z.GATHER_MAX, math.max(1, Infinity_GetNumCharacters() / 6)) end
function PSXP7_GatherTick()
	if not Z.gatherCell then return end
	local f = PSXP7_GatherScale()
	local v = math.floor(Z.gatherBase * f * f)
	if v ~= Z.gatherValue then EEex_Write32(Z.gatherCell, v) Z.gatherValue = v end
end

-- Called from the world-screen tick (M_PSXENG.lua).
function PSXP7_BarTick()
	if Z.pendingMove and Z.processPending then pcall(Z.processPending) end
	pcall(PSXP7_GatherTick)
	if Z.hookSwapPortraits then pcall(Z.hookSwapPortraits) end -- drag and drop = insertion, in the game's bar too
	pcall(PSXP7_FormTick)
	if PSXP7_KickTick then
		if not Z.removeHooked and PSXP7_HookPickRemove then Z.removeHooked = select(2, pcall(PSXP7_HookPickRemove)) == true end
		pcall(PSXP7_KickTick)
	end
	local want = Z.enabled == true and Infinity_GetNumCharacters() > 6
	if want ~= onStack('PSXP7_BAR') then
		pcall(function() if want then Infinity_PushMenu('PSXP7_BAR') else Infinity_PopMenu('PSXP7_BAR') end end)
	end
	if want ~= onStack('PSXP7_BOTTOM') then
		pcall(function() if want then Infinity_PushMenu('PSXP7_BOTTOM') else Infinity_PopMenu('PSXP7_BOTTOM') end end)
	end
	-- extra rows of the "party full" panel while the game's one is open
	local pick = Z.enabled == true and not Z.PICK_OFF and onStack('WORLD_PICKPARTY')
	if pick ~= onStack('PSXP7_PICK') then
		pcall(function() if pick then Infinity_PushMenu('PSXP7_PICK') else Infinity_PopMenu('PSXP7_PICK') end end)
	end
end

if not Z.barHooked then
	Z.barHooked = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('PSXP7') end)
end

-- For other mods' party loops (they say `for p = 0, 5`): `for p = 0, PSXP7_LastPortrait() do` covers every member
-- (6 without this patch, nil members skipped by EEex_Sprite_GetInPortrait as usual).
function PSXP7_LastPortrait() return math.max(5, (Infinity_GetNumCharacters() or 6) - 1) end

-- Extra portraits of the "party full" panel (PSXP7_PICK, over WORLD_PICKPARTY which shows entries 0-6).
function PSXP7_PickVisible(i)
	return Z.enabled == true and worldScreen ~= nil and worldScreen:GetPickPartyCharacterId(i) ~= -1
end

-----------------------
-- Kick-out dialogue  --
-----------------------
-- "Modifier le groupe" (pick-party panel) removes a member with a queued leave action, which switches an NPC's
-- dialogue to its PDIALOG.2DA POST_DIALOG_FILE, but nothing is said: John (2026-10-23) wants the NPC's own kick-out
-- dialogue ("where should I wait?"), as when dismissing it by talking; its later "join again" talk is that same
-- POST dialogue. Once the removed one is out of the party, it starts a dialogue with Player1 (NPCs with a POST
-- dialogue only; PSXP7.KICK_DIALOG = false turns it off).
if Z.KICK_DIALOG == nil then Z.KICK_DIALOG = true end
Z.pendingKick = Z.pendingKick or {}
local function postDialog(sp)
	local dv = string.upper(sp.m_scriptName:get() or '')
	if dv == '' or dv == 'NONE' then return nil end
	if not Z.pdialog then
		local ok, arr = pcall(EEex_Resource_Load2DA, 'PDIALOG')
		if not ok then return nil end
		Z.pdialog = arr
	end
	local ok, post = pcall(function() return Z.pdialog:getAtLabels('POST_DIALOG_FILE', dv) end)
	if not ok or not post or post == '' or post == '*' or post == '0' then return nil end -- '0' = the 2DA default (no row)
	local okRes, h = pcall(EEex_Resource_Demand, post, 'DLG')
	if not okRes or h == nil then return nil end
	return post
end
function Z.pcDialog()
	if Z.hasPcDialog == nil then local ok, h = pcall(EEex_Resource_Demand, 'PSXP7PC', 'DLG') Z.hasPcDialog = ok and h ~= nil end
	return Z.hasPcDialog
end
function PSXP7_KickTick()
	for id, since in pairs(Z.pendingKick) do
		local sp = EEex_GameObject_Get(id)
		if not sp or Infinity_GetClockTicks() - since > 30000 then
			Z.pendingKick[id] = nil
		elseif EEex_Sprite_GetPortraitIndex(sp) < 0 and not Infinity_IsMenuOnStack('WORLD_PICKPARTY') then
			Z.pendingKick[id] = nil
			if Z.KICK_DEBUG then print(string.format('[PSXP7] kick: %s out of the party, ea %d, post %s', EEex_Sprite_GetName(sp), sp.m_typeAI.m_EnemyAlly, tostring(postDialog(sp)))) end
			if postDialog(sp) then
				EEex_Action_QueueResponseStringOnAIBase('StartDialogNoSet(Player1)', sp)
			elseif Z.pcDialog() then -- player-made character: the generic PSXP7PC dialogue (PSXP7CAMP mod)
				-- the engine gives a removed player-made character the MULTIJ dialogue (multiplayer) and a queued
				-- SetDialogue came too late: the dialogue resref is written directly (checked live 2026-10-23)
				sp.m_dialog:set('PSXP7PC')
				EEex_Action_QueueResponseStringOnAIBase('StartDialogNoSet(Player1)', sp)
			end
		end
	end
end
function PSXP7_HookPickRemove()
	if worldScreen == nil then return false end
	local mt = getmetatable(worldScreen)
	if not mt then return false end
	if rawget(mt, '__psxRemoveHooked') then return true end
	local orig = rawget(mt, 'RemoveCharacterFromParty')
	if type(orig) ~= 'function' then return false end
	rawset(mt, '__psxRemoveHooked', true)
	rawset(mt, 'RemoveCharacterFromParty', function(self, ...)
		local ok, id = pcall(function() return self:GetPickPartyRemoveCharacterId() end)
		local r = table.pack(orig(self, ...))
		if Z.KICK_DIALOG and ok and id and id ~= -1 then Z.pendingKick[id] = Infinity_GetClockTicks() end
		if Z.KICK_DEBUG then print('[PSXP7] kick: removed id ' .. tostring(id)) end
		return table.unpack(r, 1, r.n)
	end)
	return true
end
if not Z.kickHooked then
	Z.kickHooked = true
	EEex_Menu_AddMainFileLoadedListener(function() pcall(PSXP7_HookPickRemove) end)
end
