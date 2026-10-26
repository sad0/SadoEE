-- SadoQoL #18 (was the AutoRoller mod, M_AROLL.lua, John 2026-10-12; folded into SadoQoL 2026-10-23).
-- AutoRoller: rerolls abilities for a set duration and keeps the best score.
-- Score = sum of the six abilities + exceptional strength tier * weight.

autoRoller = {
	maxWeight = 20,
	minDuration = 5,
	maxDuration = 60,
	frameBudgetMs = 12, -- rolling time per frame, keeps the UI responsive
	running = false,
	endTick = 0,
	rolls = 0,
	best = nil,
	bestStr = nil,
	fighter = false,
}

local function autoRoller_clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function autoRoller_loadINI(key, default, lo, hi)
	local v = tonumber(Infinity_GetINIValue('AutoRoller', key, default)) or default
	return autoRoller_clamp(v, lo, hi)
end

autoRoller.weight = autoRoller_loadINI('StrWeight', 5, 0, autoRoller.maxWeight)
autoRoller.duration = autoRoller_loadINI('Duration', 10, autoRoller.minDuration, autoRoller.maxDuration)

-- Exceptional strength tiers, matching the game's bonus brackets.
function autoRoller_strTier(pct)
	if pct == nil then return 0 end
	if pct == 0 or pct >= 100 then return 5 end
	if pct >= 91 then return 4 end
	if pct >= 76 then return 3 end
	if pct >= 51 then return 2 end
	if pct >= 1 then return 1 end
	return 0
end

-- Parses a roll value like 17, "17" or "18/76". Returns base, exceptional percent or nil.
function autoRoller_parse(roll)
	local s = tostring(roll or '')
	local base, pct = string.match(s, '^%s*(%d+)%s*/%s*(%d+)')
	if base then return tonumber(base), tonumber(pct) end
	return tonumber(string.match(s, '(%d+)')) or 0, nil
end

-- Returns the current score, the strength text and the raw ability total.
function autoRoller_score()
	local total, tier = 0, 0
	local str = chargen.ability[1] and tostring(chargen.ability[1].roll) or ''
	for i = 1, 6 do
		local ab = chargen.ability[i]
		local base, pct = autoRoller_parse(ab and ab.roll)
		total = total + base
		if i == 1 and pct ~= nil then
			autoRoller.fighter = true
			if base == 18 then tier = autoRoller_strTier(pct) end
		end
	end
	return total + tier * autoRoller.weight, str, total
end

function autoRoller_start()
	autoRoller.running = true
	autoRoller.rolls = 0
	autoRoller.fighter = false
	autoRoller.best = nil
	autoRoller.endTick = Infinity_GetClockTicks() + autoRoller.duration * 1000
	-- Start from the stored roll (previous runs or a manual Store), rescored with the current weight.
	if createCharScreen:IsAbilityRecallButtonClickable() then
		createCharScreen:OnAbilityRecallButtonClick()
		autoRoller.best, autoRoller.bestStr, autoRoller.bestTotal = autoRoller_score()
	end
end

function autoRoller_stop()
	autoRoller.running = false
	if autoRoller.best ~= nil then
		createCharScreen:OnAbilityRecallButtonClick()
	end
end

function autoRoller_toggle()
	if autoRoller.running then
		autoRoller_stop()
	else
		autoRoller_start()
	end
end

-- Called every frame through the status label.
function autoRoller_tick()
	if not autoRoller.running then return end
	local now = Infinity_GetClockTicks()
	if now >= autoRoller.endTick + 1000 then
		-- Stale run: the screen was closed while rolling.
		autoRoller.running = false
		return
	end
	if now >= autoRoller.endTick then
		autoRoller_stop()
		return
	end
	local frameEnd = now + autoRoller.frameBudgetMs
	repeat
		createCharScreen:OnAbilityReRollButtonClick()
		autoRoller.rolls = autoRoller.rolls + 1
		local s, str, total = autoRoller_score()
		if autoRoller.best == nil or s > autoRoller.best then
			autoRoller.best, autoRoller.bestStr, autoRoller.bestTotal = s, str, total
			createCharScreen:OnAbilityStoreButtonClick()
		end
	until Infinity_GetClockTicks() >= frameEnd
end

function autoRoller_changeWeight(delta)
	autoRoller.weight = autoRoller_clamp(autoRoller.weight + delta, 0, autoRoller.maxWeight)
	Infinity_SetINIValue('AutoRoller', 'StrWeight', autoRoller.weight)
end

function autoRoller_changeDuration(delta)
	autoRoller.duration = autoRoller_clamp(autoRoller.duration + delta, autoRoller.minDuration, autoRoller.maxDuration)
	Infinity_SetINIValue('AutoRoller', 'Duration', autoRoller.duration)
end

function autoRoller_buttonText()
	if autoRoller.running then
		local left = math.max(0, autoRoller.endTick - Infinity_GetClockTicks()) / 1000
		return string.format('Stop (%.1fs)', left)
	end
	return 'Auto-Roll'
end

function autoRoller_weightText()
	return '18/xx weight: ' .. autoRoller.weight
end

function autoRoller_durationText()
	return 'Duration: ' .. autoRoller.duration .. 's'
end

local function autoRoller_thousands(n)
	local s = tostring(n)
	repeat
		local k
		s, k = string.gsub(s, '^(%d+)(%d%d%d)', '%1 %2')
	until k == 0
	return s
end

function autoRoller_statusText()
	autoRoller_tick()
	if autoRoller.best == nil then
		return ''
	end
	-- Show the raw total; the 18/xx weight only affects the ranking.
	local text = 'Best: ' .. autoRoller.bestTotal
	if autoRoller.fighter and autoRoller.bestStr then
		text = text .. '  STR ' .. autoRoller.bestStr
	end
	if autoRoller.rolls > 0 then
		text = text .. '\n' .. autoRoller_thousands(autoRoller.rolls) .. ' rolls'
	end
	return text
end

-- one line (BG2 layout: under the Store / Recall / Reroll / Auto-Roll row); it also drives the rolling, as statusText
function autoRoller_statusLine()
	return (string.gsub(autoRoller_statusText(), '\n', '   -   '))
end
