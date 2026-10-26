--[[
SadoQoL component #6 - Endless ammo (John 2026-10-22).

Party members never use up arrows, bolts, bullets, darts or stackable throwing weapons: the stack never shrinks.
Too strong to be endless, so these are used up normally (John's quiz): Arrow of Slaying, Bolt of Polymorphing,
Arrow of Dispelling, Arrow of Antimagic +1, Dart of Stunning, Arrow of Detonation (T.EXCLUDE). Enemies are unchanged.

How: in CGameSprite::Swing a ranged / thrown shot does
	GetUsageCount(item, ability) ; dec ax ; SetUsageCount(item, ability, count)   (call at SET_CALL)
A hook before that call asks SQAmmo_Hook_Keep(sprite = rbx, item = r12); when it returns true the count argument
goes back to the old value (+1), so nothing is used up. The call bytes are checked first: another game build is left
untouched (SQAmmo.status says why). Hooks are installed once per game run (restart after editing this file).
Live: SQAmmo.ENABLED = false   SQAmmo.EXCLUDE["AROW05"] = true
--]]

SQAmmo = SQAmmo or {}
local T = SQAmmo

T.ENABLED = T.ENABLED ~= false
T.EXCLUDE = T.EXCLUDE or {
	AROW03 = true,     -- Arrow of Slaying
	BOLT05 = true,     -- Bolt of Polymorphing
	AROW07 = true,     -- Arrow of Dispelling
	BDAROW01 = true,   -- Arrow of Antimagic +1
	DART03 = true,     -- Dart of Stunning
	AROW06 = true,     -- Arrow of Detonation
}

local SET_CALL = SQ_Addr(0x1403B902A)           -- call CItem::SetUsageCount, right after "dec ax"
local SET_TARGET = SQ_Addr(0x140200710)
local AMMO_TYPES = { [5] = true, [14] = true, [24] = true, [31] = true }   -- arrows, bullets, darts, bolts

-- EEex_Sprite_GetPortraitIndex also sees members 7+ of the >6-party prototype (M_PSXP7.lua wraps it)
local function isParty(sprite)
	return EEex_Sprite_GetPortraitIndex(sprite) >= 0
end

-- Called from the Swing hook on every ranged / thrown shot (not per frame).
function SQAmmo_Hook_Keep(sprite, item)
	if not T.ENABLED or not sprite or not item then return false end
	local res = string.upper(item.pRes.resref:get())
	if T.EXCLUDE[res] or not isParty(sprite) then return false end
	local h = EEex_Resource_Demand(res, 'ITM')
	-- ammo, or a stack of throwing weapons (charged melee abilities also pass through Swing: left alone)
	return h ~= nil and (AMMO_TYPES[h.itemType] == true or h.maxStackable > 1)
end

local function hook()
	if T.status then return end
	local b = {}
	for i = 0, 4 do b[i] = EEex_ReadU8(SET_CALL + i) % 256 end
	local rel = b[1] + b[2] * 0x100 + b[3] * 0x10000 + b[4] * 0x1000000
	if rel >= 0x80000000 then rel = rel - 0x100000000 end
	local dec = { 0x66, 0xFF, 0xC8 }   -- "dec ax" at SET_CALL - 12
	local decOk = true
	for i, v in ipairs(dec) do
		if EEex_ReadU8(SET_CALL - 12 + i - 1) % 256 ~= v then decOk = false end
	end
	if b[0] ~= 0xE8 or SET_CALL + 5 + rel ~= SET_TARGET or not decOk then
		T.status = 'skipped: unexpected code in CGameSprite::Swing'
		print('[SadoQoL] endless ammo: ' .. T.status)
		return
	end
	EEex_DisableCodeProtection()
	EEex_HookBeforeCallWithLabels(SET_CALL, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(56)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rcx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rdx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], r8
			]]},
			EEex_GenLuaCall("SQAmmo_Hook_Keep", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rbx #ENDL", {rspOffset}}, "CGameSprite" end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r12 #ENDL", {rspOffset}}, "CItem" end,
				},
				["returnType"] = EEex_LuaCallReturnType.Boolean,
			}),
			{[[
				jmp sqammo_no_error

				call_error:
				xor rax, rax

				sqammo_no_error:
				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r8, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				test rax, rax
				jz sqammo_use_up
				inc r8d
				sqammo_use_up:
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
	EEex_EnableCodeProtection()
	T.status = 'hooked'
end

do
	local ok, err = pcall(hook)
	if not ok then T.status = 'error: ' .. tostring(err) print('[SadoQoL] endless ammo: ' .. T.status) end
end
