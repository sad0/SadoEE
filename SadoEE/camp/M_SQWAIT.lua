--[[
SadoQoL component #16 - Waiting at the rest camp (John 2026-10-23).

After any member leaves the party through the "Modify party" screen (a recruited NPC or a player-created character),
if the ex-member still stands near the party, he asks (dialogue SQKICK): "Shall I wait for you at the camp?"
 - Yes: he goes to the rest camp (SQCAMP) and waits around the fire.
 - No: he stays where he is.
An NPC's own leaving dialogue runs first; SQKICK comes once it is over and only if he is still here (an NPC sent
away for good walks off). Back in the party: a recruited NPC with his usual dialogue; a player-created character
(no dialogue of his own) gets SQKICK, whose "Join us" state brings him back (his old dialogue is restored).

How: a tick menu (SQWAIT_TICK) compares the party with the previous look; a member gone (alive, not in the party)
is pending; when no dialogue runs and he is idle near the leader, he starts SQKICK with Player1
(StartDialogOverride). Local variables on the creature: SQWAITCAMP = 1 while waiting at the camp, SQWAITDLG = his
old dialogue (player-created characters only).
--]]

SQWait = SQWait or {}
local T = SQWait

T.ENABLED = T.ENABLED ~= false
T.PERIOD = T.PERIOD or 300
T.NEAR = T.NEAR or 600                 -- px: an ex-member farther from the leader is not asked
T.CAMP = 'SQCAMP'
T.FIRE = T.FIRE or { 638, 385 }        -- camp fire (SQCAMP.ARE): waiting places in rings around it
T.KEEP_CLEAR = { { 553, 338 }, { 723, 301 }, { 560, 445 }, { 205, 382 } }   -- priest, merchant, scholar, Withers
local SITE = SQCampSite
if SITE and SITE.FIRE then   -- BG2EE's camp
	T.FIRE = SITE.FIRE
	T.KEEP_CLEAR = { SITE.PRIEST, SITE.MERCH, SITE.CAIN, SITE.WITHERS }
end
T.created = T.created or {}            -- [id] = true: no dialogue of his own when he left (player-created)
T.pending = T.pending or {}            -- [id] = time he left the party (refreshed while a dialogue runs)
T.tries = T.tries or {}                -- [id] = questions sent that did not open yet

local function partyIds()
	local out = {}
	for p = 0, (PSXP7_LastPortrait and PSXP7_LastPortrait() or 5) do
		local s = EEex_Sprite_GetInPortrait(p)
		if s then out[s.m_id] = true end
	end
	return out
end

local function alive(sp)
	return EEex_BAnd(sp.m_baseStats.m_generalState, 0xFC0) == 0
end

-- The dialogue window is up. (worldScreen:GetInControlOfDialog() answers true with no dialogue at all on BGEE 2.7.3:
-- used here, nobody was ever asked; John's test 2026-10-28.)
local function inDialog()
	-- (1 or nil; the menu flag can lag right after another NPC's dialogue: the replies shown count too)
	return (Infinity_IsMenuOnStack('WORLD_DIALOG') or Infinity_IsMenuOnStack('WORLD_DIALOG_CONFIRM')
		or #(worldPlayerDialogChoices or {}) > 0) and true or false
end

local function dialogOf(sp)
	local ok, d = pcall(function() return sp.m_dialog:get() end)
	return ok and d or ''
end

-- the n-th free place around the fire (rings of 120, 190, 260 px), away from the camp's people
local function place(n)
	local k = 0
	for ring = 1, 3 do
		local r = 50 + 70 * ring
		local count = 8 * ring
		for i = 0, count - 1 do
			local a = 2 * math.pi * (i + 0.5 * ring) / count
			local x, y = math.floor(T.FIRE[1] + r * math.cos(a)), math.floor(T.FIRE[2] + r * math.sin(a) * 0.75)
			local clear = true
			for _, c in ipairs(T.KEEP_CLEAR) do
				if (c[1] - x) ^ 2 + (c[2] - y) ^ 2 < 60 * 60 then clear = false end
			end
			if clear then
				if k == n then return x, y end
				k = k + 1
			end
		end
	end
	return T.FIRE[1], T.FIRE[2] + 140
end

-- A player-created character has no dialogue: SQKICK becomes his (the old one is kept to be restored).
local function keepDialog(sp)
	if not T.created[sp.m_id] then return end
	local cur = dialogOf(sp)
	if string.upper(cur) ~= 'SQKICK' then EEex_Sprite_SetLocalString(sp, 'SQWAITDLG', cur) end
	EEex_Action_QueueResponseStringOnAIBase('SetDialog("SQKICK")', sp)
end

-- dialogue SQKICK (EEex_LuaTrigger / EEex_LuaAction run with the ex-member as their object)
function SQWait_Asking()
	local yes = T.asking ~= nil and EEex_LuaTrigger_Object ~= nil and T.asking == EEex_LuaTrigger_Object.m_id
	if yes then T.pending[T.asking] = nil end   -- the question is open: no more tries
	return yes
end

function SQWait_ToCamp()
	local sp = EEex_LuaAction_Object
	T.asking = nil
	if not sp then return end
	T.slot = (T.slot or -1) + 1
	local x, y = place(T.slot % 48)
	EEex_Sprite_SetLocalInt(sp, 'SQWAITCAMP', 1)
	keepDialog(sp)
	EEex_Action_QueueResponseStringOnAIBase(string.format('MoveGlobal("%s",Myself,[%d.%d])', T.CAMP, x, y), sp)
end

function SQWait_Stay()
	local sp = EEex_LuaAction_Object
	T.asking = nil
	if sp then keepDialog(sp) end
end

-- Back in the party (the "Join us" state): the old dialogue back, the camp mark gone.
function SQWait_Join()
	local sp = EEex_LuaAction_Object
	if not sp then return end
	EEex_Sprite_SetLocalInt(sp, 'SQWAITCAMP', 0)
	local old = EEex_Sprite_GetLocalString(sp, 'SQWAITDLG')
	EEex_Action_QueueResponseStringOnAIBase('SetDialog("' .. (old ~= '' and old or 'NONE') .. '")', sp)
	EEex_Action_QueueResponseStringOnAIBase('JoinParty()', sp)
end

local function tick()
	if e:GetActiveEngine() ~= worldScreen then return end
	local now = Infinity_GetClockTicks()
	local party = partyIds()
	if T.last then
		for id in pairs(T.last) do
			if not party[id] then
				local o = EEex_GameObject_Get(id)
				if o and o.m_objectType == 49 then
					local sp = EEex_GameObject_CastUserType(o)
					if alive(sp) then
						T.pending[id] = now
						local dlg = string.upper(dialogOf(sp))
						-- player-created: no dialogue, or SoD's MULTIG (area-bound, no rejoin at the camp)
						if dlg == '' or dlg == 'NONE' or dlg == 'MULTIG' then T.created[id] = true end
					end
				end
			end
		end
	end
	T.last = party
	-- While a dialogue runs (the ex-members' own leaving dialogues, another one being asked) the 60 s don't count:
	-- with two members sent away together (Tweaks Anthology's separate NPC pairs: Jaheira and Khalid), the second one
	-- waited through both dialogues and was forgotten before his turn (Jarno, G3, 2026-10-27).
	if inDialog() or T.asking then
		for id in pairs(T.pending) do T.pending[id] = now end
		return
	end
	local leader = EEex_Sprite_GetInPortrait(0)
	if not leader then return end
	for id, since in pairs(T.pending) do
		local o = EEex_GameObject_Get(id)
		local sp = o and o.m_objectType == 49 and EEex_GameObject_CastUserType(o)
		if not sp or party[id] or now - since > 60000 then
			T.pending[id] = nil
		elseif now - since > 800 and sp.m_curAction.m_actionID == 0 then
			local dx, dy = sp.m_pos.x - leader.m_pos.x, sp.m_pos.y - leader.m_pos.y
			T.tries[id] = (T.tries[id] or 0) + 1
			if not EEex_UDEqual(sp.m_pArea, leader.m_pArea) or dx * dx + dy * dy > T.NEAR * T.NEAR or T.tries[id] > 5 then
				T.pending[id], T.tries[id] = nil, nil
			else
				-- he stays pending until the question really opens (SQWait_Asking): a leaving dialogue's last
				-- actions (ChangeAIScript("",DEFAULT) in Khalid's and Jaheira's) can clear his queue right after
				-- (Jarno, G3, 2026-10-27: both sent away, neither asked)
				T.asking, T.askedAt = id, now
				EEex_Action_QueueResponseStringOnAIBase('StartDialogOverride("SQKICK",Player1)', sp)
				return
			end
		end
	end
end

function SQWait_Tick()
	if not T.ENABLED then return false end
	local now = Infinity_GetClockTicks()
	if T.next and now < T.next then return false end
	T.next = now + T.PERIOD
	-- a question that never opened (its queue cleared, blocked): asked again 4 s later (5 tries, then forgotten)
	if T.asking and not inDialog() and now - (T.askedAt or now) > 4000 then T.asking = nil end
	local ok, err = pcall(tick)
	if not ok then T.lastError = tostring(err) end
	return false
end

local function pushTick()
	if not Infinity_IsMenuOnStack('SQWAIT_TICK') then Infinity_PushMenu('SQWAIT_TICK') end
end

if not T.listenersAdded then
	T.listenersAdded = true
	EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('SQWAIT') end)
	EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
	EEex_GameState_AddInitializedListener(pushTick)
	EEex_Menu_AddAfterMainFileReloadedListener(pushTick)
	-- a reload: the party seen last belongs to the old session
	EEex_Sprite_AddLoadedListener(function() T.last, T.pending, T.tries, T.asking = nil, {}, {}, nil end)
end
