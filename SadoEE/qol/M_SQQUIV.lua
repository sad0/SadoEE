--[[
SadoQoL component #6 - Endless ammo, the quiver part (John 2026-10-24).

Like the fist in an empty weapon slot: a party member with a bow, a crossbow or a sling in a weapon slot gets basic
+0 ammo of that kind (SQAROW / SQBOLT / SQBULL, copies of AROW01 / BOLT01 / BULL01 made by the tp2: no weight, no
price, not droppable) in the first empty quiver slot; endless ammo (M_SQAMMO.lua) keeps the stack from shrinking.
  - one per launcher kind, only while such a launcher is in a weapon slot (else it goes);
  - it never leaves the quiver: found anywhere else (backpack, another slot, the hand) it is destroyed;
  - created on the world screen and on the inventory page (paused there too: a bow just equipped gets its ammo at
    once and is the weapon in hand, John 2026-10-24), never on the store screen (script actions run instantly there
    crash the game); only when the backpack has room (CreateItem fills the backpack first, then the item moves).
  - a launcher selected without ammo (the engine then shows the fist) gets selected again, on the new ammo.
Live: SQQuiv.ENABLED = false
--]]

SQQuiv = SQQuiv or {}
local Q = SQQuiv

Q.ENABLED = Q.ENABLED ~= false
Q.PERIOD = Q.PERIOD or 500

local AMMO_FOR = { [15] = 'SQAROW', [27] = 'SQBOLT', [18] = 'SQBULL' } -- launcher item type -> our ammo
local OURS = { SQAROW = true, SQBOLT = true, SQBULL = true }
local QUIVER = { 11, 12, 13 }
local WEAPONS = { 35, 36, 37, 38 }
local DEAD_STATES = 0x800 + 0x80 + 0x40 + 0x40000

local function resOf(it) return string.upper(it.pRes.resref:get()) end

local function itemType(res)
	local h = EEex_Resource_Demand(res, 'ITM')
	return h and h.itemType
end

local function lastPortrait()
	return PSXP7_LastPortrait and PSXP7_LastPortrait() or 5
end

-- Our ammo kinds this sprite should have: { SQAROW = true, ... }
local function wanted(sp)
	local out = {}
	local items = sp.m_equipment.m_items
	for _, i in ipairs(WEAPONS) do
		local it = items:get(i)
		local ammo = it and AMMO_FOR[itemType(resOf(it))]
		if ammo then out[ammo] = true end
	end
	return out
end

-- Removes ours from every slot but the quiver, and from the quiver when not wanted; returns the kinds in the quiver.
local function clean(sp, want)
	local items, have = sp.m_equipment.m_items, {}
	for i = 0, 38 do
		local it = items:get(i)
		if it and OURS[resOf(it)] then
			local res = resOf(it)
			local inQuiver = i >= 11 and i <= 13
			if not inQuiver or not want[res] or have[res] then
				items:set(i, nil)
				Q.dirty = true
			else
				have[res] = true
			end
		end
	end
	return have
end

local function firstEmpty(items, from, to)
	for i = from, to do
		if not items:get(i) then return i end
	end
end

-- CreateItem into the backpack, then the new item moves to the quiver slot.
local function give(sp, res, slot)
	local items = sp.m_equipment.m_items
	if not firstEmpty(items, 18, 33) then return false end
	local before = {}
	for i = 18, 33 do before[i] = items:get(i) ~= nil end
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly('CreateItem("' .. res .. '",0,0,0)', sp)
	for i = 18, 33 do
		local it = items:get(i)
		if it and not before[i] and resOf(it) == res then
			items:set(i, nil)
			items:set(slot, it)
			Q.dirty = true
			-- the launcher in hand (or the fist the engine fell back to) fires this ammo: select it
			local eq = sp.m_equipment
			local sel = eq.m_selectedWeapon
			local cur = items:get(sel)
			local curType = cur and itemType(resOf(cur))
			if (curType and AMMO_FOR[curType] == res) or sel == 10 then eq.m_selectedWeapon = slot end
			return true
		end
	end
	return false
end

local function step()
	Q.dirty = false
	local eng = e:GetActiveEngine()
	local canCreate = eng == worldScreen or (eng ~= storeScreen and Infinity_IsMenuOnStack('INVENTORY'))
	-- the hand (inventory screen): ours picked up goes away
	local inv = EEex_EngineGlobal_CBaldurChitin.m_pEngineInventory
	local held = inv and inv.m_pTempItem
	if held and OURS[resOf(held)] then inv.m_pTempItem = nil end
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and EEex_BAnd(sp.m_derivedStats.m_generalState, DEAD_STATES) == 0 then
			local want = wanted(sp)
			local have = clean(sp, want)
			if canCreate then
				for res in pairs(want) do
					if not have[res] then
						local slot = firstEmpty(sp.m_equipment.m_items, QUIVER[1], QUIVER[#QUIVER])
						if slot then give(sp, res, slot) end
					end
				end
			end
		end
	end
end

function SQQuiv_Tick()
	if not Q.ENABLED then return false end
	local now = Infinity_GetClockTicks()
	if Q.next and now < Q.next then return false end
	Q.next = now + Q.PERIOD
	local ok, err = pcall(step)
	if not ok then Q.lastError = tostring(err) end
	-- the inventory page shows the change at once (its slots are rebuilt from the sprites)
	if Q.dirty and Infinity_IsMenuOnStack('INVENTORY') then pcall(Infinity_ActivateInventory) end
	return false
end

if not Q.listenersAdded then
	Q.listenersAdded = true
	local function pushTick()
		if not Infinity_IsMenuOnStack('SQQUIV_TICK') then Infinity_PushMenu('SQQUIV_TICK') end
	end
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQQUIV') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
end
