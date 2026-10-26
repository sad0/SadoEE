--[[
SadoQoL component #14 - Chests in the ground bar (John 2026-10-23).

The quick loot bar (WORLD_QUICKLOOT, "ground items") lists only ground piles near the selected character. It now also
lists the items of the containers (chests, drawers, bodies...) in the same range that are unlocked, not trapped (an
armed trap, detected or not, hides the container until it is disarmed) and in the character's line of sight.
Their items mix with the ground items: component #3 sorts the whole bar and builds the virtual stacks.

How: CGameSprite::UpdateVisibleGroundItems keeps the objects in range whose container type is 4 (pile). The
"cmp ax, 4 / jne skip" there goes to a stub: a pile goes on as before, any other container asks
Lua SQChest_Allowed(container, sprite). Clicking an entry passes its slotId + containerId to the engine (SwapItemGround),
which takes from any container. Bytes are checked first; SQChest.status says why when skipped.
Tuning live from the EEex console:  SQChest.ENABLED = false
--]]

SQChest = SQChest or {}
local T = SQChest

T.ENABLED = T.ENABLED ~= false

local TYPE_PILE = 4
local FLAG_LOCKED, FLAG_DISABLED = 0x1, 0x20

local function los(area, sp, bx, by)
	local ok, res = pcall(function()
		return EEex_RunWithStackManager({
			{ ["name"] = "a", ["struct"] = "CPoint", ["constructor"] = { ["variant"] = "fromXY", ["args"] = { sp.m_pos.x, sp.m_pos.y } } },
			{ ["name"] = "b", ["struct"] = "CPoint", ["constructor"] = { ["variant"] = "fromXY", ["args"] = { bx, by } } } },
			function(m)
				return area:CheckLOS(m:getUD("a"), m:getUD("b"), sp:virtual_GetVisibleTerrainTable(), 0, 0)
			end)
	end)
	if not ok then T.lastError = tostring(res) return false end
	return res ~= 0 and res ~= false
end

-- called by the engine for every non-pile container in the bar's range
function SQChest_Allowed(c, sp)
	if not T.ENABLED then return false end
	local ok, res = pcall(function()
		if c.m_containerType == TYPE_PILE then return true end
		if EEex_BAnd(c.m_dwFlags, FLAG_LOCKED + FLAG_DISABLED) ~= 0 then return false end
		if c.m_trapActivated ~= 0 then return false end
		return los(sp.m_pArea, sp, c.m_pos.x, c.m_pos.y)
	end)
	if not ok then T.lastError = tostring(res) return false end
	return res
end

-- ---- engine patch ----
local CMP_PILE = SQ_Addr(0x14038662E)     -- 66 83 F8 04 | 0F 85 rel32: container type 4 (pile) or skip the object
local KEEP = SQ_Addr(0x140386638)         -- next instruction: list the container's items
local SKIP = SQ_Addr(0x140386805)         -- next object

local function byteAt(a) return EEex_ReadU8(a) % 256 end
local function rel32(at)          -- target of a 6-byte 0F 8x rel32 jump
	local rel = byteAt(at + 2) + byteAt(at + 3) * 0x100 + byteAt(at + 4) * 0x10000 + byteAt(at + 5) * 0x1000000
	if rel >= 0x80000000 then rel = rel - 0x100000000 end
	return at + 6 + rel
end

local function patch()
	if T.status then return end
	local b = { 0x66, 0x83, 0xF8, 0x04, 0x0F, 0x85 }
	for i, v in ipairs(b) do
		if byteAt(CMP_PILE + i - 1) ~= v then T.status = 'skipped: unexpected engine code' end
	end
	if not T.status and rel32(CMP_PILE + 4) ~= SKIP then T.status = 'skipped: unexpected engine code' end
	if T.status then print('[SadoQoL] chests in ground bar: ' .. T.status) return end
	-- r15 = CGameSprite, [rsp+0x50] = CGameContainer (r14 gets it at KEEP anyway, so it is free here)
	local stub = EEex_JITNear(EEex_FlattenTable({
		{[[
			cmp ax, 4
			je keep
			mov r14, qword ptr ss:[rsp+0x50]
			#MAKE_SHADOW_SPACE(32)
		]]},
		EEex_GenLuaCall('SQChest_Allowed', {
			['args'] = {
				function(rspOffset) return { 'mov qword ptr ss:[rsp+#$(1)], r14 #ENDL', { rspOffset } }, 'CGameContainer' end,
				function(rspOffset) return { 'mov qword ptr ss:[rsp+#$(1)], r15 #ENDL', { rspOffset } }, 'CGameSprite' end,
			},
			['returnType'] = EEex_LuaCallReturnType.Boolean,
		}),
		{[[
			jmp no_error
			call_error:
			xor rax, rax
			no_error:
			#DESTROY_SHADOW_SPACE
			test rax, rax
			jnz keep
			jmp ]], SKIP, [[ #ENDL
			keep:
			jmp ]], KEEP, [[ #ENDL
		]]},
	}))
	local rel = stub - (CMP_PILE + 5)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of range') end
	if rel < 0 then rel = rel + 0x100000000 end
	EEex_DisableCodeProtection()
	EEex_WriteU8(CMP_PILE, 0xE9)
	for i = 0, 3 do EEex_WriteU8(CMP_PILE + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
	for i = 5, 9 do EEex_WriteU8(CMP_PILE + i, 0x90) end
	EEex_EnableCodeProtection()
	T.status = 'patched'
end

do
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] chests in ground bar: ' .. T.status) end
end
