--[[
SadoQoL component #13 - Party keeps its gear on death (John 2026-10-23).

A dying creature drops its whole inventory on the ground (CGameEffectDeath::ApplyEffect calls
CGameSprite::DropInventory). For party members (EA 2 = PC) the call is skipped: equipment and backpack stay on the
corpse, ready when it is raised. Other DropInventory callers (leaving the party, imprisonment, multiplayer delete) are
left alone.
Engine patch (bytes checked first; SQKeep.status says why when skipped): the "call DropInventory" in the death effect
goes to a stub that returns at once for EA 2.
--]]

SQKeep = SQKeep or {}
local T = SQKeep

local CALL_DROP = SQ_Addr(0x1401B0452)        -- E8 rel32 in CGameEffectDeath::ApplyEffect, rcx = dying sprite
local DROP_INVENTORY = SQ_Addr(0x140392AF0)   -- CGameSprite::DropInventory
local EA_PC = 2                      -- sprite +0x38 (m_typeAI.m_EnemyAlly)

local function byteAt(a) return EEex_ReadU8(a) % 256 end
local function callTarget(at)
	local rel = byteAt(at + 1) + byteAt(at + 2) * 0x100 + byteAt(at + 3) * 0x10000 + byteAt(at + 4) * 0x1000000
	if rel >= 0x80000000 then rel = rel - 0x100000000 end
	return at + 5 + rel
end
local function setCall(at, target)
	local rel = target - (at + 5)
	if rel < -0x80000000 or rel > 0x7FFFFFFF then error('stub out of range') end
	if rel < 0 then rel = rel + 0x100000000 end
	for i = 0, 3 do EEex_WriteU8(at + 1 + i, math.floor(rel / 2 ^ (8 * i)) % 256) end
end

local function patch()
	if T.status then return end
	if not (byteAt(CALL_DROP) == 0xE8 and callTarget(CALL_DROP) == DROP_INVENTORY) then
		T.status = 'skipped: unexpected engine code'
		print('[SadoQoL] keep gear: ' .. T.status)
		return
	end
	local stub = EEex_JITNear({[[
		cmp byte ptr [rcx+0x38], ]], EA_PC, [[ #ENDL
		je keep
		jmp ]], DROP_INVENTORY, [[ #ENDL
		keep:
		ret
	]]})
	EEex_DisableCodeProtection()
	setCall(CALL_DROP, stub)
	EEex_EnableCodeProtection()
	T.status = 'patched'
end

do
	local ok, err = pcall(patch)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] keep gear: ' .. T.status) end
end
