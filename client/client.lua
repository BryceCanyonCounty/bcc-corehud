-- ==================
-- Config normalize
-- ==================
local Raw                  = Config or {}

local C                    = {
	updateIntervalMs         = (type(Raw.UpdateInterval) == 'number' and Raw.UpdateInterval > 0 and Raw.UpdateInterval or 1000),
	needsUpdateIntervalMs    = (type(Raw.NeedsUpdateInterval) == 'number' and Raw.NeedsUpdateInterval > 0 and Raw.NeedsUpdateInterval or 5000),
	needsDecayStartDelay     = math.max(0.0, tonumber(Raw.NeedsDecayStartDelay) or 300.0),
	starvationDamageDelay    = math.max(0.0, tonumber(Raw.StarvationDamageDelay) or 0.0),
	starvationDamageInterval = math.max(0.0, tonumber(Raw.StarvationDamageInterval) or 10.0),
	starvationDamageAmount   = math.max(0.0, tonumber(Raw.StarvationDamageAmount) or 4.0),
	mailboxMaxMessages       = math.max(1.0, tonumber(Raw.MailboxMaxMessages) or 10.0),
	mailboxUpdateInterval    = math.max(1000.0, tonumber(Raw.MailboxUpdateInterval) or 30000.0),
	minTempDamage            = tonumber(Raw.MinTemp) or Config.MinTemp or Config.TemperatureMin or -10.0,
	maxTempDamage            = tonumber(Raw.MaxTemp) or Config.MaxTemp or Config.TemperatureMax or 35.0,
	tempDamagePerTick        = math.max(0.0, tonumber(Raw.RemoveHealth) or Config.RemoveHealth or 0.0),
	hotTempThirstDrain       = math.max(0.0, tonumber(Raw.HotTempThirstDrain) or Config.HotTempThirstDrain or 0.0),
	tempWarnCooldown         = math.max(0.0, tonumber(Raw.TempWarningCooldown) or Config.TempWarningCooldown or 10.0),
}
local needsIntervalMs      = math.max(100.0, tonumber(C.needsUpdateIntervalMs) or 5000.0)
local updateIntervalSteps  = needsIntervalMs / 1000.0

local tempDamageFxEnabled  = (Raw.DoHealthDamageFx ~= false)
local tempPainSoundEnabled = (Raw.DoHealthPainSound ~= false)
local tempWarningMessage   = (type(Config.TempWarningMessage) == 'string' and Config.TempWarningMessage ~= '' and Config.TempWarningMessage) or
	nil
local lastTempWarnAt       = 0.0
local lastActivityLabel    = nil
local lastCoreDebug        = {}
local hudImmediate         = false

local function getAttributeBaseRankSafe(ped, attributeIndex)
	if ped == nil or ped == 0 then return 0 end
	if attributeIndex == nil then return 0 end
	local value = GetAttributeBaseRank(ped, attributeIndex)
	local n = tonumber(value)
	if n then return n end
	devPrint('GetAttributeBaseRank failed', value)
	return 0
end

local function logActivity(label)
	if label and label ~= lastActivityLabel then
		lastActivityLabel = label
		devPrint(('Activity %s hm=%.2f tm=%.2f'):format(label, hm or 0.0, tm or 0.0))
	end
end

local function debugCoreValue(label, inner, outer)
	if not Config.devMode then return end
	local function round2(v)
		if v == nil then return nil end
		return math.floor((tonumber(v) or 0) * 100 + 0.5) / 100
	end

	local currInner = round2(inner)
	local currOuter = round2(outer)
	local prev = lastCoreDebug[label]
	if not prev or prev.inner ~= currInner or prev.outer ~= currOuter then
		local innerMsg = currInner and ('%.2f'):format(currInner) or 'nil'
		local outerMsg = currOuter and ('%.2f'):format(currOuter) or 'nil'
		devPrint(('[CoreDbg] %s inner=%s outer=%s'):format(label, innerMsg, outerMsg))
		lastCoreDebug[label] = { inner = currInner, outer = currOuter }
	end
end

local voiceSteps     = (function()
	local src = Config.VoiceProximitySteps
	local tmp = {}
	if type(src) == 'table' then
		for _, v in ipairs(src) do
			local n = tonumber(v); if n and n > 0 then tmp[#tmp + 1] = n end
		end
	end
	table.sort(tmp)
	local out = {}
	for i = 1, #tmp do if i == 1 or tmp[i] ~= tmp[i - 1] then out[#out + 1] = tmp[i] end end
	if #out == 0 then out = { 2.0, 15.0, 50.0 } end
	return out
end)()

local voiceStepMax   = voiceSteps[#voiceSteps]
local voiceStepIndex = math.floor((tonumber(Config.VoiceDefaultStepIndex) or 2) + 0.5)
if voiceStepIndex < 1 then voiceStepIndex = 1 end
if voiceStepIndex > #voiceSteps then voiceStepIndex = #voiceSteps end
if not Config.VoiceMaxRange or Config.VoiceMaxRange <= 0 then Config.VoiceMaxRange = 50.0 end

local cleanStatsPercent = nil
local moneyAmount, goldAmount, expAmount, tokensAmount = nil, nil, nil, nil
local logoImage = Config.LogoImage

local mailboxCount, lastMailboxRequest = nil, 0

-- =======================
-- UI/Layout helpers (kept)
-- =======================
local hudVisible, hudPreference, hudSuppressed = nil, Config.AutoShowHud, false
local characterSelected = Config.devMode == true
local hudLayoutEditing = false

local function sendLayoutToNui(payload)
	SendNUIMessage({ type = 'layout', positions = payload or {} })
end

local function setLayoutEditing(enabled, opts)
	local on = enabled == true
	local skipSave = type(opts) == 'table' and opts.skipSave == true
	if hudLayoutEditing == on then
		if not on then
			SetNuiFocus(false, false)
			SendNUIMessage({ type = 'layoutEdit', editing = false })
		end
		return
	end
	hudLayoutEditing = on
	SetNuiFocus(on, on)
	local saveLabel = _U('hud_save_layout')
	if type(saveLabel) ~= 'string' then saveLabel = 'Save Layout' end
	SendNUIMessage({ type = 'layoutEdit', editing = on, label = saveLabel })
	if not on and not skipSave then
		SendNUIMessage({ type = 'layoutRequestSave' })
	end
end

local function applyHudVisibility()
	local shouldShow = hudPreference and characterSelected and not hudSuppressed
	if hudVisible ~= shouldShow then
		if not shouldShow and hudLayoutEditing then
			setLayoutEditing(false, { skipSave = true })
		end
		hudVisible = shouldShow
		devPrint('HUD visibility set', hudVisible, 'suppressed', hudSuppressed, 'characterSelected', characterSelected)
		SendNUIMessage({ type = "toggle", visible = hudVisible })
	end
end

local function hideRdrHudIcons()
	local icons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
	for _, i in ipairs(icons) do UitutorialSetRpgIconVisibility(i, 2) end
end

-- =============
-- Needs state
-- =============
local localNeedsState = { hunger = nil, thirst = nil, stress = nil }
local needsDecayTrackers, currentTemperatureEffect = {}, nil
local starvationTimer, starvationElapsed, starvationDelaySatisfied = 0.0, 0.0, false
local needsErrorLogged, voiceErrorLogged = false, false

local tempFxActive = false

local function convertCleanlinessRankToPercent(rank)
	local value = tonumber(rank)
	if value == nil then return nil end
	value = clamp(value, 0.0, 100.0)
	return clamp(100.0 - value, 0.0, 100.0)
end

local consumeAnimations = {
	eat = {
		dict = 'mech_inventory@eating@multi_bite@sphere_d8-2_sandwich',
		clip = 'quick_right_hand',
		defaultProp = 'P_BREAD05X',
		attach = { x = 0.1, y = -0.01, z = -0.07, rx = -90.0, ry = 100.0, rz = 0.0 },
		duration = 2000
	},
	drink = {
		dict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a',
		clip = 'idle_a',
		defaultProp = 'P_BOTTLE008X',
		attach = { x = 0.05, y = -0.07, z = -0.05, rx = -75.0, ry = 60.0, rz = 0.0 },
		duration = 4000
	}
}

local activeConsumeProp = nil

local function cleanupConsumeProp()
	if activeConsumeProp then
		if DoesEntityExist(activeConsumeProp) then
			DetachEntity(activeConsumeProp, true, true)
			DeleteObject(activeConsumeProp)
		end
		activeConsumeProp = nil
	end
end

local function playConsumeAnimation(spec)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return
	end

	local animType = 'eat'
	local propName = nil
	local duration = nil

	if type(spec) == 'table' then
		if type(spec.animation) == 'string' and spec.animation ~= '' then
			animType = spec.animation:lower()
		elseif type(spec.anim) == 'string' and spec.anim ~= '' then
			animType = spec.anim:lower()
		end
		if type(spec.prop) == 'string' and spec.prop ~= '' then
			propName = spec.prop
		end
		if spec.duration ~= nil then
			duration = tonumber(spec.duration)
		end
	elseif type(spec) == 'string' and spec ~= '' then
		propName = spec
	end

	local animDef = consumeAnimations[animType] or consumeAnimations.eat
	local dict = animDef.dict
	local clip = animDef.clip
	local defaultDuration = animDef.duration or 2000
	local attach = animDef.attach

	local modelName = propName or animDef.defaultProp or 'P_BREAD05X'
	local modelHash = GetHashKey(modelName)

	RequestAnimDict(dict)
	local attempts = 0
	while not HasAnimDictLoaded(dict) and attempts < 50 do
		attempts = attempts + 1
		Wait(50)
	end
	if not HasAnimDictLoaded(dict) then
		return
	end

	RequestModel(modelHash)
	attempts = 0
	while not HasModelLoaded(modelHash) and attempts < 50 do
		attempts = attempts + 1
		Wait(50)
	end
	if not HasModelLoaded(modelHash) then
		RemoveAnimDict(dict)
		return
	end

	local position = GetEntityCoords(ped)
	local prop = CreateObject(modelHash, position.x, position.y, position.z, true, true, false)
	if not prop or prop == 0 then
		RemoveAnimDict(dict)
		SetModelAsNoLongerNeeded(modelHash)
		return
	end

	do
		local t = animType
		if t == 'cigarette' or t == 'cigarette' or t == 'cigaret' then
			TriggerEvent('bcc-corehud:prop:cigaret')
			return
		elseif t == 'cigar' then
			TriggerEvent('bcc-corehud:prop:cigar')
			return
		elseif t == 'pipe' or t == 'pipe_smoker' then
			TriggerEvent('bcc-corehud:prop:pipe_smoker')
			return
		elseif t == 'chew' or t == 'chewing' or t == 'chewingtobacco' then
			TriggerEvent('bcc-corehud:prop:chewingtobacco')
			return
		end
	end

	cleanupConsumeProp()
	activeConsumeProp = prop

	local boneIndex = GetEntityBoneIndexByName(ped, 'SKEL_R_HAND')
	AttachEntityToEntity(prop, ped, boneIndex, attach.x, attach.y, attach.z, attach.rx, attach.ry, attach.rz, true, true, false, true, 1, true)

	TaskPlayAnim(ped, dict, clip, 1.0, 1.0, -1, 31, 0.0, false, false, false)
	Wait(duration and math.max(0, duration) or defaultDuration)

	ClearPedTasks(ped)
	cleanupConsumeProp()

	RemoveAnimDict(dict)
	SetModelAsNoLongerNeeded(modelHash)
end

local lastNeedWarningAt = { hunger = 0, thirst = 0 }

local function maybeNotifyNeed(stat, currentPercent, previousPercent)
	if stat ~= 'hunger' and stat ~= 'thirst' then return end
	local threshold = tonumber(Config.NeedWarningThreshold) or 0
	if threshold <= 0 then return end
	if currentPercent == nil or currentPercent > threshold then return end
	if previousPercent ~= nil and previousPercent <= threshold then return end

	local now = GetGameTimer()
	local intervalMs = math.max(0.0, (tonumber(Config.NeedWarningInterval) or 0.0) * 1000.0)
	if intervalMs > 0 and (now - (lastNeedWarningAt[stat] or 0)) < intervalMs then
		return
	end

	local message
	if stat == 'hunger' then
		message = _U('hud_hunger_warning')
	else
		message = _U('hud_thirst_warning')
	end
	if type(message) == 'string' and message ~= '' then
		lastNeedWarningAt[stat] = now
		Notify(message, 'warning')
	end
end

local function startTemperatureFx()
	if tempFxActive or not tempDamageFxEnabled then return end
	AnimpostfxPlay('MP_Downed')
	tempFxActive = true
end

local function stopTemperatureFx()
	if not tempFxActive then return end
	AnimpostfxStop('MP_Downed')
	tempFxActive = false
end

local function vec3(configValue, defaults)
	defaults = defaults or { x = 0.0, y = 0.0, z = 0.0 }
	if type(configValue) ~= 'table' then
		return { x = defaults.x, y = defaults.y, z = defaults.z }
	end
	local x = tonumber(configValue.x or configValue[1]) or defaults.x
	local y = tonumber(configValue.y or configValue[2]) or defaults.y
	local z = tonumber(configValue.z or configValue[3]) or defaults.z
	return { x = x, y = y, z = z }
end

local flyEffectCfg = type(Config.FlyEffect) == 'table' and Config.FlyEffect or {}
local CLEANLINESS_FLIES = {
	enabled = flyEffectCfg.enabled ~= false,
	dict = tostring(flyEffectCfg.dict or 'scr_mg_cleaning_stalls'),
	name = tostring(flyEffectCfg.name or 'scr_mg_stalls_manure_flies'),
	offset = vec3(flyEffectCfg.offset, { x = 0.2, y = 0.0, z = -0.4 }),
	rotation = vec3(flyEffectCfg.rotation, { x = 0.0, y = 0.0, z = 0.0 }),
	axis = vec3(flyEffectCfg.axis, { x = 0.0, y = 0.0, z = 0.0 }),
	scale = tonumber(flyEffectCfg.scale) or 1.0,
	boneMale = tonumber(flyEffectCfg.boneMale) or 413,
	boneFemale = tonumber(flyEffectCfg.boneFemale) or 464
}

local function isPlayerBathing()
	local state = LocalPlayer and LocalPlayer.state
	if not state then return false end
	local status = state.isBathingActive
	if status == nil then return false end
	return status == true or status == 1
end
local cleanlinessFxHandle = nil
local cleanlinessFxRequested = false
local cleanlinessFxActive = false
local lastCleanlinessPenaltyAt = 0
local lastCleanlinessWarningAt = 0
local cleanlinessWarningInitialized = false
local cleanlinessWasBelowThreshold = false

local function maybeNotifyCleanliness(percent, opts)
	if not Config.EnableCleanStatsCore or not Config.MinCleanliness then return end

	local force = type(opts) == 'table' and opts.force == true

	if percent == nil then
		cleanlinessWarningInitialized = false
		cleanlinessWasBelowThreshold = false
		return
	end

	if percent >= Config.MinCleanliness then
		cleanlinessWasBelowThreshold = false
		cleanlinessWarningInitialized = false
		return
	end

	if not cleanlinessWarningInitialized then
		cleanlinessWarningInitialized = true
	end

	local intervalMs = math.max(0.0, (tonumber(Config.CleanWarningInterval) or 0.0) * 1000.0)
	local now = GetGameTimer()

	if cleanlinessWasBelowThreshold and not force and intervalMs > 0 and (now - lastCleanlinessWarningAt) < intervalMs then
		return
	end

	local message = _U('hud_clean_warning')
	if type(message) ~= 'string' or message == '' then return end

	cleanlinessWasBelowThreshold = true
	lastCleanlinessWarningAt = now
	Notify(message, 'warning')
end

local function stopCleanlinessFlies()
	if cleanlinessFxHandle and DoesParticleFxLoopedExist(cleanlinessFxHandle) then
		StopParticleFxLooped(cleanlinessFxHandle, false)
	end
	cleanlinessFxHandle = nil
	cleanlinessFxActive = false
	cleanlinessFxRequested = false
end

local function updateCleanlinessFlies(cleanPercent)
	if not Config.EnableCleanStatsCore or not Config.MinCleanliness or not CLEANLINESS_FLIES.enabled then
		if cleanlinessFxActive then stopCleanlinessFlies() end
		return
	end

	local bathing = isPlayerBathing()
	if bathing then
		stopCleanlinessFlies()
		return
	end

	if type(cleanPercent) ~= 'number' then
		stopCleanlinessFlies()
		return
	end

	if cleanPercent >= Config.MinCleanliness then
		stopCleanlinessFlies()
		return
	end

	maybeNotifyCleanliness(cleanPercent)

	if cleanlinessFxActive then
		if cleanlinessFxHandle and not DoesParticleFxLoopedExist(cleanlinessFxHandle) then
			stopCleanlinessFlies()
		end
		return
	end

	local dictHash = GetHashKey(CLEANLINESS_FLIES.dict)
	if not HasNamedPtfxAssetLoaded(dictHash) then
		if not cleanlinessFxRequested then
			RequestNamedPtfxAsset(dictHash)
			cleanlinessFxRequested = true
		end
		return
	end
	cleanlinessFxRequested = false
	UseParticleFxAsset(CLEANLINESS_FLIES.dict)

	local ped = PlayerPedId()
	if ped == 0 then return end

	local pedIsMale = IsPedMale(ped) == true
	local boneIndex = pedIsMale and CLEANLINESS_FLIES.boneMale or CLEANLINESS_FLIES.boneFemale

	cleanlinessFxHandle = StartNetworkedParticleFxLoopedOnEntityBone(
		CLEANLINESS_FLIES.name,
		ped,
		CLEANLINESS_FLIES.offset.x,
		CLEANLINESS_FLIES.offset.y,
		CLEANLINESS_FLIES.offset.z,
		CLEANLINESS_FLIES.rotation.x,
		CLEANLINESS_FLIES.rotation.y,
		CLEANLINESS_FLIES.rotation.z,
		boneIndex,
		CLEANLINESS_FLIES.scale,
		CLEANLINESS_FLIES.axis.x,
		CLEANLINESS_FLIES.axis.y,
		CLEANLINESS_FLIES.axis.z
	)
	if cleanlinessFxHandle then
		cleanlinessFxActive = true
	else
		stopCleanlinessFlies()
	end
end

local function applyCleanlinessPenalty(percent, opts)
	if not Config.EnableCleanStatsCore or not Config.MinCleanliness then return end
	if percent == nil or percent >= Config.MinCleanliness then return end
	local ped = PlayerPedId(); if ped == 0 then return end
	if isPlayerBathing() then return end

	local force = type(opts) == 'table' and opts.force == true
	maybeNotifyCleanliness(percent, opts)
	local interval = math.max(0.0, tonumber(Config.CleanPenaltyInterval) or 10.0) * 1000.0
	local now = GetGameTimer()
	if not force and interval > 0 and (now - lastCleanlinessPenaltyAt) < interval then
		return
	end
	lastCleanlinessPenaltyAt = now

	if Config.DoHealthDamageFx then
		updateCleanlinessFlies(percent)
	end
	if Config.DoHealthPainSound then
		PlayPain(ped, 9, 1, true, true)
	end
	local damage = tonumber(Config.RemoveHealth) or 0
	if damage <= 0 then return end
	local health = GetEntityHealth(ped)
	if health and health > 0 then
		SetEntityHealth(ped, math.max(0, health - damage))
	end
end

local function applySimpleTemperatureDamage(ped, temperature)
	local damage = C.tempDamagePerTick or 0.0
	if damage <= 0.0 or ped == 0 or IsEntityDead(ped) then
		stopTemperatureFx()
		return false, false
	end
	local below = C.minTempDamage and temperature < C.minTempDamage
	local above = C.maxTempDamage and temperature > C.maxTempDamage
	if not below and not above then
		stopTemperatureFx()
		return false, false
	end

	if tempDamageFxEnabled then startTemperatureFx() else stopTemperatureFx() end

	local health = GetEntityHealth(ped)
	if not health or health <= 0 then
		stopTemperatureFx()
		return above, below
	end

	if tempPainSoundEnabled then PlayPain(ped, 9, 1, true, true) end
	local newHealth = math.max(0, math.floor(health - damage))
	if newHealth < health then SetEntityHealth(ped, newHealth) end

	return above, below
end

local function setMailboxCount(value)
	if not Config.EnableMailboxCore then
		mailboxCount = nil
		return
	end
	if value == nil then
		mailboxCount = nil
		return
	end
	local n = tonumber(value)
	if not n then return end
	if n < 0 then n = 0 end
	mailboxCount = n
end

local function setCleanStatsPercent(value)
	if not Config.EnableCleanStatsCore then
		cleanStatsPercent = nil
		stopCleanlinessFlies()
		return
	end
	if value == nil then
		cleanStatsPercent = nil
		stopCleanlinessFlies()
		return
	end
	local n = tonumber(value)
	if not n then return end
	cleanStatsPercent = clamp(n, 0.0, 100.0)
	updateCleanlinessFlies(cleanStatsPercent)
end

local function setMoneyAmount(value)
	if not Config.EnableMoneyCore then
		moneyAmount = nil; return
	end
	local n = tonumber(value)
	if n == nil then
		moneyAmount = nil
		return
	end
	moneyAmount = n
end

local function setGoldAmount(value)
	if not Config.EnableGoldCore then
		goldAmount = nil; return
	end
	local n = tonumber(value)
	if n == nil then
		goldAmount = nil
		return
	end
	goldAmount = n
end

local function setExpAmount(value)
	if not Config.EnableExpCore then
		expAmount = nil; return
	end
	local n = tonumber(value)
	if n == nil then
		expAmount = nil
		return
	end
	expAmount = n
end

local function setTokensAmount(value)
	if not Config.EnableTokensCore then
		tokensAmount = nil; return
	end
	local n = tonumber(value)
	if n == nil then
		tokensAmount = nil
		return
	end
	tokensAmount = n
end

local function setLogoAsset(path)
	if not Config.EnableLogoCore then
		logoImage = nil
		return
	end
	if type(path) == 'string' and path ~= '' then
		logoImage = path
	else
		if type(Config.LogoImage) == 'string' and Config.LogoImage ~= '' then
			logoImage = Config.LogoImage
		else
			logoImage = nil
		end
	end
end

local function prettyNumber(n)
	if n == nil then return '0' end
	local decimals = 0
	if math.abs(n % 1) > 0.001 then
		decimals = 2
	end
	local multiplier = 10 ^ decimals
	local rounded
	if decimals > 0 then
		if n >= 0 then
			rounded = math.floor(n * multiplier + 0.5) / multiplier
		else
			rounded = math.ceil(n * multiplier - 0.5) / multiplier
		end
	else
		rounded = (n >= 0) and math.floor(n + 0.5) or math.ceil(n - 0.5)
	end

	local sign = ''
	if rounded < 0 then
		sign = '-'
		rounded = -rounded
	end

	local integerPart = math.floor(rounded)
	local fraction = ''
	if decimals > 0 then
		local fractionValue = math.floor((rounded - integerPart) * multiplier + 0.5)
		local fractionDigits = tostring(fractionValue)
		if #fractionDigits < decimals then
			fractionDigits = string.rep('0', decimals - #fractionDigits) .. fractionDigits
		end
		fraction = '.' .. fractionDigits
	end

	local digits = tostring(integerPart):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
	return sign .. digits .. fraction
end

if Config.EnableLogoCore then
	setLogoAsset(Config.LogoImage)
else
	logoImage = nil
end

local _balancesRequested = false
local _lastBalancesAt = 0

local function applyBalances(data)
	if not data then return end
	if Config.EnableMoneyCore then TriggerEvent('bcc-corehud:setMoney', data.money) end
	if Config.EnableGoldCore then TriggerEvent('bcc-corehud:setGold', data.gold) end
	if Config.EnableExpCore then TriggerEvent('bcc-corehud:setExp', data.xp) end
	if Config.EnableTokensCore then TriggerEvent('bcc-corehud:setTokens', data.rol) end
end

local function refreshBalancesAsync(force)
	if _balancesRequested and not force then return end
	_balancesRequested = true

	CreateThread(function()
		local res = BccUtils.RPC:CallAsync('bcc-corehud:getBalances', {})
		if res and res.ok and res.data then
			applyBalances(res.data)
			_lastBalancesAt = GetGameTimer()
		end
		-- allow another request after a short cooldown
		Wait(500)
		_balancesRequested = false
	end)
end

CreateThread(function()
	Wait(1500)
	refreshBalancesAsync(false)
end)

RegisterNetEvent('vorp:SelectedCharacter', function(charId)
    characterSelected = true
    devPrint('[bcc-corehud] Character selected: ' .. tostring(charId))

    if characterSelected then
        -- Request HUD layout
        local layoutOk = BccUtils.RPC:CallAsync('bcc-corehud:layout:request', {})
        if layoutOk then
            devPrint('[bcc-corehud] Layout successfully loaded')
        else
            devPrint('^1[bcc-corehud]^0 Failed to load layout')
        end

        -- Request HUD palette
        local paletteOk = BccUtils.RPC:CallAsync('bcc-corehud:palette:request', {})
        if paletteOk then
            devPrint('[bcc-corehud] Palette successfully loaded')
        else
            devPrint('^1[bcc-corehud]^0 Failed to load palette')
        end
    end

    -- Reapply HUD visibility if your script handles toggle states
    applyHudVisibility()
end)

local REQUIRED_PERSIST_NUMBERS = {
	{ key = 'innerhealth',  min = 0, max = 15, default = 0 },
	{ key = 'outerhealth',  min = 0, max = 99, default = 0 },
	{ key = 'innerstamina', min = 0, max = 15, default = 0 },
	{ key = 'outerstamina', min = 0, max = 99, default = 0 },
}
local OPTIONAL_PERSIST_NUMBERS = {
	{ key = 'outerhunger',        min = 0, max = 99 },
	{ key = 'outerthirst',        min = 0, max = 99 },
	{ key = 'outerstress',        min = 0, max = 99 },
	{ key = 'innerhorse_health',  min = 0, max = 15 },
	{ key = 'outerhorse_health',  min = 0, max = 99 },
	{ key = 'innerhorse_stamina', min = 0, max = 15 },
	{ key = 'outerhorse_stamina', min = 0, max = 99 },
}
local PERSIST_STRINGS = {}

local function setLocalNeedValue(stat, value, options)
	if stat ~= 'hunger' and stat ~= 'thirst' and stat ~= 'stress' then return end

	-- ignore/reset delay unless explicitly told not to (kept for API compatibility)
	local resetDelay = not (type(options) == 'table' and options.resetDelay == false)

	if value == nil then
		localNeedsState[stat] = nil
		-- keep tracker value cleared if other code reads it, but no timers/rates
		if needsDecayTrackers[stat] then needsDecayTrackers[stat].value = nil end
		return
	end

	local n = tonumber(value); if not n then return end
	n = clamp(n, 0.0, 100.0)

	local previous = localNeedsState[stat]
	localNeedsState[stat] = n

	-- warnings (unchanged)
	if stat == 'hunger' or stat == 'thirst' then
		maybeNotifyNeed(stat, n, previous)

		-- Mirror only: keep a value field so any reads of needsDecayTrackers don't crash,
		-- but DO NOT set rate/delay (we're using per-tick absolute drains now).
		local tr = needsDecayTrackers[stat]
		if not tr then
			tr = { delay = 0.0, value = nil, rate = 0.0 }
			needsDecayTrackers[stat] = tr
		end
		tr.value = n
		tr.delay = 0.0
		tr.rate  = 0.0
	end
end

if Config.NeedsAutoDecay then
	if localNeedsState.hunger == nil then setLocalNeedValue('hunger', Config.InitialNeedValue) end
	if localNeedsState.thirst == nil then setLocalNeedValue('thirst', Config.InitialNeedValue) end
end

-- ======================
-- Layout/needs API/events
-- ======================
local function applyLocalNeedsUpdate(payload)
	if type(payload) ~= 'table' then return end
	if payload.hunger ~= nil then setLocalNeedValue('hunger', payload.hunger) end
	if payload.thirst ~= nil then setLocalNeedValue('thirst', payload.thirst) end
	if payload.stress ~= nil then setLocalNeedValue('stress', payload.stress) end
end

RegisterNetEvent('bcc-corehud:setNeeds', function(payload)
	if payload == nil then
		setLocalNeedValue('hunger', nil); setLocalNeedValue('thirst', nil); setLocalNeedValue('stress', nil)
		return
	end
	applyLocalNeedsUpdate(payload)
end)

BccUtils.RPC:Register('bcc-corehud:layout:apply', function(params, cb)
    local layout = nil
    if type(params) == 'table' then
        layout = params.layout or params
    end

    if type(layout) == 'table' then
        sendLayoutToNui(layout)
    else
        sendLayoutToNui(nil)
    end

    if cb then cb(true) end
end)


RegisterNetEvent('bcc-corehud:setNeed', function(stat, value)
	if type(stat) ~= 'string' then return end
	stat = stat:lower()
	if stat == 'hunger' or stat == 'thirst' or stat == 'stress' then setLocalNeedValue(stat, value) end
end)

RegisterNetEvent('bcc-corehud:playConsumeAnim', function(propName)
	playConsumeAnimation(propName)
end)

exports('PlayConsumeAnimation', playConsumeAnimation)

RegisterNetEvent('bcc-corehud:setStaminaCore', function(value)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return
	end

	local amount = tonumber(value)
	if not amount or amount == 0 then
		return
	end

	local current = tonumber(GetAttributeCoreValue(ped, 1)) or 0
	local nextValue = clamp(current + amount, 0.0, 100.0)
	SetAttributeCoreValue(ped, 1, nextValue)
end)

RegisterNetEvent('bcc-corehud:setHealthCore', function(value)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return
	end

	local amount = tonumber(value)
	if not amount or amount == 0 then
		return
	end

	local current = tonumber(GetAttributeCoreValue(ped, 0)) or 0
	local nextValue = clamp(current + amount, 0.0, 100.0)
	SetAttributeCoreValue(ped, 0, nextValue)
end)

RegisterNetEvent('bcc-corehud:applyAttributeOverpower', function(entries)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return
	end

	if type(entries) ~= 'table' then
		return
	end

	for _, spec in ipairs(entries) do
		if type(spec) == 'table' then
			local attribute = tonumber(spec.attribute or spec.index or spec.core)
			local amount = tonumber(spec.amount or spec.value)
			if attribute and amount then
				amount = clamp(amount, 0.0, 100.0)
				if amount > 0.0 then
					local enable = spec.enable
					if enable == nil then enable = spec.enabled end
					EnableAttributeOverpower(ped, attribute, amount, enable ~= false)
				end
			end
		end
	end
end)

RegisterNetEvent('hud:client:changeValue', function(stat, value)
	if type(stat) ~= 'string' then return end
	stat = stat:lower()
	if stat == 'hunger' or stat == 'thirst' or stat == 'stress' then setLocalNeedValue(stat, value) end
end)

exports('SetNeeds', function(payload)
	if payload == nil then
		setLocalNeedValue('hunger', nil); setLocalNeedValue('thirst', nil); setLocalNeedValue('stress', nil)
		return
	end
	applyLocalNeedsUpdate(payload)
end)

exports('SetNeed', function(stat, value)
	if type(stat) ~= 'string' then return end
	stat = stat:lower()
	if stat == 'hunger' or stat == 'thirst' or stat == 'stress' then setLocalNeedValue(stat, value) end
end)

exports('AddNeed', function(stat, delta)
	stat = tostring(stat or ''):lower()
	if stat ~= 'hunger' and stat ~= 'thirst' and stat ~= 'stress' and stat ~= 'clean_stats' then return end
	local d = tonumber(delta) or 0.0
	if stat == 'clean_stats' then
		if not Config.EnableCleanStatsCore then return end
		local current = cleanStatsPercent or 100.0
		local nextValue = clamp(current + d, 0.0, 100.0)
		setCleanStatsPercent(nextValue)
		applyCleanlinessPenalty(nextValue, { force = true })
		return
	end

	local cur = tonumber(localNeedsState[stat]) or 0.0
	setLocalNeedValue(stat, math.max(0.0, math.min(100.0, cur + d)))
end)

RegisterNetEvent('bcc-corehud:setMailboxCount', function(value)
	setMailboxCount(value)
end)

exports('SetMailboxCount', function(value)
	setMailboxCount(value)
end)

RegisterNetEvent('bcc-corehud:setCleanStats', function(value)
	setCleanStatsPercent(value)
end)

exports('SetCleanStats', function(value)
	setCleanStatsPercent(value)
end)

RegisterNetEvent('bcc-corehud:setMoney', function(value)
	setMoneyAmount(value)
end)

exports('SetMoney', function(value)
	setMoneyAmount(value)
end)

RegisterNetEvent('bcc-corehud:setGold', function(value)
	setGoldAmount(value)
end)

exports('SetGold', function(value)
	setGoldAmount(value)
end)

RegisterNetEvent('bcc-corehud:setExp', function(value)
	setExpAmount(value)
end)

exports('SetExp', function(value)
	setExpAmount(value)
end)

RegisterNetEvent('bcc-corehud:setTokens', function(value)
	setTokensAmount(value)
end)

exports('SetTokens', function(value)
	setTokensAmount(value)
end)

RegisterNetEvent('bcc-corehud:setLogo', function(value)
	setLogoAsset(value)
end)

exports('SetLogo', function(value)
	setLogoAsset(value)
end)

-- ==========================
-- Key loop: voice step cycle
-- ==========================
local function setTalkerProximity(m)
	if type(MumbleSetTalkerProximity) == 'function' then MumbleSetTalkerProximity(m) end
	if type(MumbleSetAudioInputDistance) == 'function' then MumbleSetAudioInputDistance(m) end
	if type(MumbleSetAudioOutputDistance) == 'function' then MumbleSetAudioOutputDistance(m) end
	if Config.devMode then print(('[BCC-CoreHUD] Voice proximity set: %.1fm'):format(m)) end
end

local function applyVoiceStep(idx, skipNotify)
	if idx < 1 then idx = #voiceSteps end
	if idx > #voiceSteps then idx = 1 end
	voiceStepIndex = idx

	local metres = voiceSteps[voiceStepIndex]
	setTalkerProximity(metres)

	if not skipNotify then
		local localeKey =
			(voiceStepIndex == 1 and "hud_voice_mode_whisper")
			or (voiceStepIndex == #voiceSteps and "hud_voice_mode_shout")
			or "hud_voice_mode_normal"

		Notify(_U(localeKey), "info")
	end

	if hudVisible then
		hudImmediate = true
	end
end

local function cycleVoiceStep(dir)
	applyVoiceStep(voiceStepIndex + (dir or 1), false)
end

CreateThread(function()
	local debounceMs, last = 0, 180
	while true do
		Wait(0)
		if IsPauseMenuActive() or hudLayoutEditing then goto continue end
		if IsControlJustPressed(0, Config.VoiceCycleControl) then
			local now = GetGameTimer()
			if now - last >= debounceMs then
				if Config.EnableVoiceCore then cycleVoiceStep(1) end
				last = now
			end
		end
		::continue::
	end
end)

local lastPersistTick, lastPersistedSnapshot = 0, nil
function RequestLayoutFromServer()
    local success = BccUtils.RPC:CallAsync('bcc-corehud:layout:request', {})

    if success then
        devPrint('[bcc-corehud:layout:request] Layout request completed successfully')
    else
        devPrint('^1[bcc-corehud:layout:request]^0 Layout request failed')
    end

    return success
end

local function truthy(v) return v == true or v == 1 or v == -1 end

CreateThread(function()
  local lastSuppressed = nil
  while true do
    Wait(100)

    local ped           = PlayerPedId()
    local paused        = IsPauseMenuActive()
    local cinematicOpen = IsInCinematicMode()
    local cinematicCam  = IsCinematicCamRendering() or false
    local mapOpen       = IsUiappActiveByHash(`MAP`)
    local loading       = IsLoadingScreenVisible() or false
    -- FIXED: only true when SHOP_BROWSING is actually active
    local shopBrowsing  = IsUiappActiveByHash(`SHOP_BROWSING`)

    local dead = (ped ~= 0 and IsEntityDead(ped))

    local suppressed = paused
      or loading
      or truthy(cinematicOpen)
      or cinematicCam == true
      or truthy(mapOpen)
      or dead
      or truthy(shopBrowsing)

    if suppressed ~= lastSuppressed then
      lastSuppressed = suppressed
      hudSuppressed = suppressed
      applyHudVisibility()
    end
  end
end)

CreateThread(function()
	hideRdrHudIcons()
	Wait(500)

	if characterSelected then
		RequestLayoutFromServer()
	end
	if Config.EnableVoiceCore then applyVoiceStep(voiceStepIndex, true) end

	local needsWaitMs = math.floor(needsIntervalMs + 0.5)
	while true do
		Wait(needsWaitMs)

		do
			local ped = PlayerPedId()
			local tempNow = 0.0
			if ped ~= 0 then
				local c = GetEntityCoords(ped)
				local t = GetTemperatureAtCoords(c.x, c.y, c.z)
				tempNow = tonumber(t) or 0.0
			end
			if Config.TemperatureColdThreshold and tempNow <= Config.TemperatureColdThreshold then
				currentTemperatureEffect = 'cold'
			elseif Config.TemperatureHotThreshold and tempNow >= Config.TemperatureHotThreshold then
				currentTemperatureEffect = 'hot'
			else
				currentTemperatureEffect = nil
			end

			if Config.NeedsAutoDecay then
				local ped = PlayerPedId()

				-- activity label
				local label = 'idle'
				if ped ~= 0 then
					if IsPedOnMount(ped) then
						label = 'mounted'
					elseif IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
						label = 'swim'
					elseif IsPedSprinting(ped) then
						label = 'sprint'
					elseif IsPedRunning(ped) then
						label = 'run'
					elseif IsPedWalking(ped) then
						label = 'walk'
					elseif IsPedStill(ped) then
						label = 'idle'
					else
						label = 'idle'
					end
				end

				if label == 'mounted' and (type(Config.ActivityMultipliers) ~= 'table' or not Config.ActivityMultipliers.mounted) then
					label = 'run'
				end

				if label ~= lastActivityLabel then
					logActivity(label)
					lastActivityLabel = label
					if hudVisible then hudImmediate = true end
				end

				-- absolute per-tick drains
				local conf = (type(Config.ActivityMultipliers) == 'table' and Config.ActivityMultipliers[label]) or {}
				local hungerDrain = tonumber(conf.hunger) or 0.0
				local thirstDrain = tonumber(conf.thirst) or 0.0

				local function applyDrain(stat, dec)
					if dec <= 0 then return end
					local cur = localNeedsState[stat]
					if cur == nil or cur <= 0 then return end
					local nextVal = clamp(cur - dec, 0.0, 100.0)
					setLocalNeedValue(stat, nextVal, { resetDelay = false })
					devPrint(("[decay] %s %s %.2f -> %.2f (%.2f removed)"):format(label, stat, cur, nextVal, dec))
				end

				-- apply drains now (per tick)
				applyDrain('hunger', hungerDrain)
				applyDrain('thirst', thirstDrain)

				-- recompute empties AFTER drain
				local isHungerEmpty = localNeedsState.hunger ~= nil and localNeedsState.hunger <= 0.0
				local isThirstEmpty = localNeedsState.thirst ~= nil and localNeedsState.thirst <= 0.0

				-- starvation (unchanged logic)
				if C.starvationDamageAmount > 0.0 then
					if isHungerEmpty and isThirstEmpty then
						starvationElapsed = starvationElapsed + updateIntervalSteps
						if starvationElapsed >= C.starvationDamageDelay then
							if not starvationDelaySatisfied then
								starvationDelaySatisfied = true
								if C.starvationDamageInterval > 0.0 then starvationTimer = C.starvationDamageInterval end
							end
							if C.starvationDamageInterval <= 0.0 then
								if ped ~= 0 and not IsEntityDead(ped) then
									local dmg = math.floor(C.starvationDamageAmount + 0.5)
									if dmg > 0 then ChangeEntityHealth(ped, -dmg, 0, 0) end
								end
							else
								starvationTimer = starvationTimer + updateIntervalSteps
								if starvationTimer >= C.starvationDamageInterval then
									starvationTimer = starvationTimer - C.starvationDamageInterval
									if ped ~= 0 and not IsEntityDead(ped) then
										local dmg = math.floor(C.starvationDamageAmount + 0.5)
										if dmg > 0 then ChangeEntityHealth(ped, -dmg, 0, 0) end
									end
								end
							end
						else
							starvationTimer = 0.0
						end
					else
						starvationElapsed, starvationTimer, starvationDelaySatisfied = 0.0, 0.0, false
					end
				else
					starvationElapsed, starvationTimer, starvationDelaySatisfied = 0.0, 0.0, false
				end

				-- heat drain + warning (keep as you had)
				local isHot = false
				if ped ~= 0 and not IsEntityDead(ped) then
					isHot = select(1, applySimpleTemperatureDamage(ped, tempNow))
				else
					stopTemperatureFx()
				end

				if isHot and C.hotTempThirstDrain > 0 then
					local curThirst = localNeedsState.thirst
					if curThirst ~= nil and curThirst > 0 then
						local drain = C.hotTempThirstDrain
						if drain > 0 then
							local newThirst = clamp(curThirst - drain, 0.0, 100.0)
							if newThirst ~= curThirst then
								setLocalNeedValue('thirst', newThirst, { resetDelay = false })
							end
						end
					end
				end

				if isHot and tempWarningMessage then
					local now = GetGameTimer() / 1000.0
					if now - lastTempWarnAt >= C.tempWarnCooldown then
						lastTempWarnAt = now
						Notify(_U('hud_temp_warning_overheat'), 'warning', 5000)
					end
				elseif not isHot then
					lastTempWarnAt = 0.0
				end
			end
		end
	end
end)

CreateThread(function()
	while true do
		if hudImmediate then
			hudImmediate = false
			Wait(0)
		else
			Wait(500)
		end

		if hudVisible then
			local ped = PlayerPedId()
			if ped ~= 0 then
				local function getCore(p, idx)
					local v = GetAttributeCoreValue(p, idx)
					return clamp(tonumber(v) or 0.0, 0.0, 100.0)
				end
				local function healthPct(p)
					local h, mh = GetEntityHealth(p), GetEntityMaxHealth(p);
					if not mh or mh <= 0 then
						return 0.0
					end
					return clamp((h / mh) * 100.0, 0.0, 100.0)
				end
				local function staminaPct(p)
					if p == PlayerPedId() then
						local playerRaw = GetPlayerStamina(PlayerId())
						if playerRaw ~= nil then
							return clamp(asPercent(playerRaw), 0.0, 100.0)
						end
					end

					local st = GetPedStamina(p)
					local pedDesc = (p == PlayerPedId()) and 'player' or ('ped-' .. tostring(p))
					--devPrint(('GetPedStamina(%s) returned %s'):format(pedDesc, tostring(st)))
					if st then
						st = tonumber(st)
						local mst = nil
						if p == PlayerPedId() then
							local playerMax = GetPlayerMaxStamina(PlayerId())
							if playerMax ~= nil then
								mst = tonumber(playerMax)
							end
						end
						if not mst then
							mst = GetPedMaxStamina(p)
							--devPrint(('GetPedMaxStamina(%s) returned %s'):format(pedDesc, tostring(mst)))
						end
						if mst and mst > 0.0 then
							return clamp((st / mst) * 100.0, 0.0, 100.0)
						end
						return clamp(st, 0.0, 100.0)
					end
					return getCore(p, 1)
				end

				local healthCore       = getCore(ped, 0)
				local staminaCore      = getCore(ped, 1)
				local playerHealthPct  = healthPct(ped)
				local playerStaminaPct = staminaPct(ped)
				local horse            = (IsPedOnMount(ped) and GetMount(ped) or 0)

				local horseHealthCore, horseStaminaCore, horseHealthPct, horseStaminaPct
				if horse ~= 0 then
					horseHealthCore  = getCore(horse, 0)
					horseStaminaCore = getCore(horse, 1)
					horseHealthPct   = healthPct(horse)
					horseStaminaPct  = staminaPct(horse)
				end

				if Config.devMode then
					debugCoreValue('player-health', healthCore, playerHealthPct)
					debugCoreValue('player-stamina', staminaCore, playerStaminaPct)
					if horse ~= 0 then
						debugCoreValue('horse-health', horseHealthCore, horseHealthPct)
						debugCoreValue('horse-stamina', horseStaminaCore, horseStaminaPct)
					else
						debugCoreValue('horse-health', nil, nil)
						debugCoreValue('horse-stamina', nil, nil)
					end
				end

				local function eff(pct, low, label) return (pct <= low) and label or nil end

				local needsData
				if not needsData and (localNeedsState.hunger or localNeedsState.thirst or localNeedsState.stress) then
					needsData = {
						hunger = localNeedsState.hunger,
						thirst = localNeedsState.thirst,
						stress = localNeedsState.stress
					}
				end

				local hungerInner, hungerOuter, hungerInside, hungerNext
				local thirstInner, thirstOuter, thirstInside, thirstNext
				local stressInner, stressOuter, stressInside, stressNext

				local function pctOrNil(v) return v == nil and nil or asPercent(v) end
				if needsData then
					if needsData.hunger ~= nil then
						local p = pctOrNil(tonumber(needsData.hunger))
						if p ~= nil then
							hungerInner, hungerOuter = toCoreState(p), toCoreMeter(p)
							hungerInside = eff(p, Config.LowCoreWarning, _U("hud_need_hunger_low"))
							hungerNext = tostring(round(p)) .. '%'
						end
					end

					if needsData.thirst ~= nil then
						local p = pctOrNil(tonumber(needsData.thirst))
						if p ~= nil then
							thirstInner, thirstOuter = toCoreState(p), toCoreMeter(p)
							thirstInside = eff(p, Config.LowCoreWarning, _U("hud_need_thirst_low"))
							thirstNext = tostring(round(p)) .. '%'
						end
					end

					if needsData.stress ~= nil then
						local p = pctOrNil(tonumber(needsData.stress))
						if p ~= nil then
							stressInner, stressOuter = toCoreState(p), toCoreMeter(p)
							stressInside = eff(p, Config.LowCoreWarning, _U("hud_need_stress_low"))
							stressNext = tostring(round(p)) .. '%'
						end
					end
				end

				local coords = GetEntityCoords(ped)
				local worldTemp = tonumber(GetTemperatureAtCoords(coords.x, coords.y, coords.z)) or 0.0
				if Config.TemperatureColdThreshold and worldTemp <= Config.TemperatureColdThreshold then
					currentTemperatureEffect = 'cold'
				elseif Config.TemperatureHotThreshold and worldTemp >= Config.TemperatureHotThreshold then
					currentTemperatureEffect = 'hot'
				else
					currentTemperatureEffect = nil
				end
				local tmin, tmax = Config.TemperatureMin, Config.TemperatureMax
				if tmin > tmax then tmin, tmax = tmax, tmin end
				local tspan = tmax - tmin
				local tempPct = (tspan < 0.001) and 50.0 or clamp(((worldTemp - tmin) / tspan) * 100.0, 0.0, 100.0)

				local tempInner, tempOuter, tempInside, tempNext = nil, nil, nil, nil
				local tempValInner, tempValOuter, tempValNext = nil, nil, nil
				if tempPct ~= nil then
					tempValInner, tempValOuter = 15, 99
					tempValNext = tostring(round(worldTemp)) .. '°'
				end
				if currentTemperatureEffect then
					tempInner, tempOuter = 15, 99
					tempInside = currentTemperatureEffect
				end

				local horseDirtInner, horseDirtOuter, horseDirtInside = nil, nil, nil
				if horse ~= 0 then
					local rank = getAttributeBaseRankSafe(horse, 16)
					--devPrint('Horse cleanliness rank', rank)
					if rank <= Config.HorseDirtyThreshold then
						horseDirtInner, horseDirtOuter, horseDirtInside = 15, 99, "horse_dirty"
					end
				end

				local voice
				if Config.EnableVoiceCore then
					local talking
					if type(MumbleIsPlayerTalking) == 'function' then
						talking = MumbleIsPlayerTalking(PlayerId())
					end
					if talking ~= nil then
						local prox = 0.0
						if type(MumbleGetTalkerProximity) == 'function' then
							prox = tonumber(MumbleGetTalkerProximity()) or 0.0
						end
						if prox ~= prox or prox == math.huge or prox == -math.huge then prox = 0.0 end
						local effMax = math.max(Config.VoiceMaxRange or 12.0, voiceStepMax or 12.0)
						if effMax <= 0.0 then effMax = 12.0 end
						local percent = (effMax > 0.0) and clamp((prox / effMax) * 100.0, 0.0, 100.0) or 0.0
						voice = {
							inner = talking and 15 or 0,
							outer = toCoreMeter(percent),
							effectInside = (talking or nil),
							effectNext = (prox > 0.0) and (tostring(round(prox < 0 and 0 or prox)) .. 'm') or nil,
							talking = talking and true or false,
							proximity = prox,
							proximityPercent = percent
						}
					elseif Config.devMode and not voiceErrorLogged then
						devPrint('Voice talking check unavailable')
						voiceErrorLogged = true
					end
				end

				local messagesInner, messagesOuter, messagesEffectNext
				if Config.EnableMailboxCore and mailboxCount then
					local capped = mailboxCount
					if capped < 0 then capped = 0 end
					if C.mailboxMaxMessages > 0 then capped = math.min(capped, C.mailboxMaxMessages) end
					local pct = (C.mailboxMaxMessages > 0) and ((capped / C.mailboxMaxMessages) * 100.0) or 0.0
					messagesInner = toCoreState(pct)
					messagesOuter = toCoreMeter(pct)
					messagesEffectNext = tostring(math.floor(mailboxCount + 0.5))
				end

				local cleanInner, cleanOuter, cleanNext
				if Config.EnableCleanStatsCore then
					local cleanlinessRank = getAttributeBaseRankSafe(ped, 16)
					--devPrint('Player cleanliness rank', cleanlinessRank)
					local percentFromRank = convertCleanlinessRankToPercent(cleanlinessRank)
					local updatedFromAttribute = false
					if percentFromRank ~= nil then
						cleanStatsPercent = percentFromRank
						updatedFromAttribute = true
					elseif cleanlinessRank == 0 and cleanStatsPercent == nil then
						cleanStatsPercent = 0.0
					end

					local decayRate = tonumber(Config.CleanRate)
					if decayRate and decayRate > 0 and cleanStatsPercent ~= nil and not updatedFromAttribute and not isPlayerBathing() then
						local decay = decayRate * updateIntervalSteps
						if decay > 0 then
							cleanStatsPercent = math.max(0.0, cleanStatsPercent - decay)
						end
					end

					if cleanStatsPercent ~= nil then
						local pct = clamp(cleanStatsPercent, 0.0, 100.0)
						cleanInner = toCoreState(pct)
						cleanOuter = toCoreMeter(pct)
						cleanNext = tostring(round(pct)) .. '%'
					end

					updateCleanlinessFlies(cleanStatsPercent)
					applyCleanlinessPenalty(cleanStatsPercent)
				end
				if (Config.EnableMoneyCore and moneyAmount == nil)
					or (Config.EnableGoldCore and goldAmount == nil)
					or (Config.EnableExpCore and expAmount == nil)
					or (Config.EnableTokensCore and tokensAmount == nil) then
					refreshBalancesAsync(false) -- throttled; will no-op if recently called
				end
				local moneyInner, moneyOuter, moneyNext
				if Config.EnableMoneyCore and moneyAmount ~= nil then
					moneyInner, moneyOuter = 15, 99
					moneyNext = prettyNumber(moneyAmount)
				end

				local goldInner, goldOuter, goldNext
				if Config.EnableGoldCore and goldAmount ~= nil then
					goldInner, goldOuter = 15, 99
					goldNext = prettyNumber(goldAmount)
				end

				local expInner, expOuter, expNext
				if Config.EnableExpCore and expAmount ~= nil then
					expInner, expOuter = 15, 99
					expNext = 'XP ' .. prettyNumber(expAmount)
				end

				local tokensInner, tokensOuter, tokensNext
				if Config.EnableTokensCore and tokensAmount ~= nil then
					tokensInner, tokensOuter = 15, 99
					tokensNext = 'T ' .. prettyNumber(tokensAmount)
				end

				local playerIdInner, playerIdOuter, playerIdNext
				local serverId = GetPlayerServerId(PlayerId())
				if serverId ~= nil then
					playerIdInner, playerIdOuter = 15, 99
					playerIdNext = ('ID %s'):format(tostring(serverId))
				end

				local logoInner, logoOuter, logoMeta
				if Config.EnableLogoCore and logoImage then
					logoInner, logoOuter = 15, 99
					logoMeta = { logo = logoImage }
				end

				local snapshot = {
					innerhealth                   = toCoreState(healthCore),
					outerhealth                   = toCoreMeter(playerHealthPct),
					innerstamina                  = toCoreState(staminaCore),
					outerstamina                  = toCoreMeter(playerStaminaPct),

					innerhunger                   = hungerInner,
					outerhunger                   = hungerOuter,
					effect_hunger_inside          = hungerInside,
					effect_hunger_next            = hungerNext,

					innerthirst                   = thirstInner,
					outerthirst                   = thirstOuter,
					effect_thirst_inside          = thirstInside,
					effect_thirst_next            = thirstNext,

					innerstress                   = stressInner,
					outerstress                   = stressOuter,
					effect_stress_inside          = stressInside,
					effect_stress_next            = stressNext,

					innerhorse_health             = horseHealthCore and toCoreState(horseHealthCore) or nil,
					outerhorse_health             = horseHealthPct and toCoreMeter(horseHealthPct) or nil,
					innerhorse_stamina            = horseStaminaCore and toCoreState(horseStaminaCore) or nil,
					outerhorse_stamina            = horseStaminaPct and toCoreMeter(horseStaminaPct) or nil,

					effect_health_inside          = eff(healthCore, Config.LowCoreWarning, "wounded"),
					effect_stamina_inside         = eff(staminaCore, Config.LowCoreWarning, "drained"),
					effect_horse_health_inside    = (horse ~= 0) and
						eff(horseHealthCore or 100.0, Config.LowCoreWarning, "wounded") or nil,
					effect_horse_stamina_inside   = eff(horseStaminaCore or 100.0, Config.LowCoreWarning, "drained"),

					innerhorse_dirt               = horseDirtInner,
					outerhorse_dirt               = horseDirtOuter,
					effect_horse_dirt_inside      = horseDirtInside,

					innertemperature              = tempInner,
					outertemperature              = tempOuter,
					effect_temperature_inside     = tempInside,

					innertemperature_value        = tempValInner,
					outertemperature_value        = tempValOuter,
					effect_temperature_value_next = tempValNext,

					innerclean_stats              = cleanInner,
					outerclean_stats              = cleanOuter,
					effect_clean_stats_inside     = nil,
					effect_clean_stats_next       = cleanNext,

					innermoney                    = moneyInner,
					outermoney                    = moneyOuter,
					effect_money_inside           = nil,
					effect_money_next             = moneyNext,

					innergold                     = goldInner,
					outergold                     = goldOuter,
					effect_gold_inside            = nil,
					effect_gold_next              = goldNext,

					innerexp                      = expInner,
					outerexp                      = expOuter,
					effect_exp_inside             = nil,
					effect_exp_next               = expNext,

					innertokens                   = tokensInner,
					outertokens                   = tokensOuter,
					effect_tokens_inside          = nil,
					effect_tokens_next            = tokensNext,

					innerplayer_id                = playerIdInner,
					outerplayer_id                = playerIdOuter,
					effect_player_id_inside       = nil,
					effect_player_id_next         = playerIdNext,

					innerlogo                     = logoInner,
					outerlogo                     = logoOuter,
					effect_logo_inside            = nil,
					effect_logo_next              = nil,
					logo_image                    = logoMeta and logoMeta.logo or nil,

					innermessages                 = messagesInner,
					outermessages                 = messagesOuter,
					effect_messages_inside        = nil,
					effect_messages_next          = messagesEffectNext,

					innervoice                    = voice and voice.inner or nil,
					outervoice                    = voice and voice.outer or nil,
					effect_voice_inside           = voice and voice.effectInside or nil,
					effect_voice_next             = voice and voice.effectNext or nil,
					voice_talking                 = voice and (voice.talking and true or false) or nil,
					voice_proximity               = voice and voice.proximity or nil,
					voice_proximity_percent       = voice and voice.proximityPercent or nil
				}

				SendNUIMessage({ type = "hud", cores = snapshot })

				local function normNum(v, lo, hi)
					local n = tonumber(v); if not n then return nil end
					if lo and n < lo then n = lo end
					if hi and n > hi then n = hi end
					return round(n)
				end
				local normalized = {}
				for _, e in ipairs(REQUIRED_PERSIST_NUMBERS) do
					normalized[e.key] = normNum(snapshot[e.key], e.min, e.max) or e.default or 0
				end
				for _, e in ipairs(OPTIONAL_PERSIST_NUMBERS) do
					normalized[e.key] = normNum(snapshot[e.key], e.min, e.max)
				end
				for _, k in ipairs(PERSIST_STRINGS) do
					local v = snapshot[k]; normalized[k] = (type(v) == 'string' and v ~= '' and v or nil)
				end

				local function valueOrNilSent(v) return v == nil and '__nil' or v end
				local different = (not lastPersistedSnapshot)
				if not different then
					for _, e in ipairs(REQUIRED_PERSIST_NUMBERS) do
						if valueOrNilSent(normalized[e.key]) ~= valueOrNilSent(lastPersistedSnapshot[e.key]) then
							different = true
							break
						end
					end
				end
				if not different then
					for _, e in ipairs(OPTIONAL_PERSIST_NUMBERS) do
						if valueOrNilSent(normalized[e.key]) ~= valueOrNilSent(lastPersistedSnapshot[e.key]) then
							different = true
							break
						end
					end
				end
				if not different then
					for _, k in ipairs(PERSIST_STRINGS) do
						if valueOrNilSent(normalized[k]) ~= valueOrNilSent(lastPersistedSnapshot[k]) then
							different = true
							break
						end
					end
				end

				local now = GetGameTimer()
				if (not lastPersistedSnapshot) or (different and (now - lastPersistTick >= Config.SaveInterval)) then
					lastPersistedSnapshot = normalized
					lastPersistTick = now
					devPrint('Persisting snapshot', normalized)
					local res = BccUtils.RPC:CallAsync('bcc-corehud:saveCores', { payload = normalized })
					local success = (res == true) or (type(res) == 'table' and res.ok == true)
					if not success then
						devPrint('[bcc-corehud] saveCores RPC failed', res)
					end
				end
			else
				devPrint('No snapshot available')
			end
		end
	end
end)
-- ========
-- Commands
-- ========
local function setHudVisible(visible)
	hudPreference = visible == true
	applyHudVisibility()
end

function ToggleUI() setHudVisible(not hudPreference) end

local commandToggleHud = Config.CommandToggleHud
local commandLayout = Config.CommandLayout
local commandPalette = Config.CommandPalette
local commandClearFx = Config.CommandClearFx
local commandHeal = Config.CommandHeal

local function registerCommandIfAvailable(name, handler)
	if type(name) == 'string' and name ~= '' then
		RegisterCommand(name, handler, false)
	end
end

registerCommandIfAvailable(commandToggleHud, function()
	ToggleUI()
end)

registerCommandIfAvailable(commandLayout, function(_, args)
    if type(args) == 'table' and args[1] then
        local sub = tostring(args[1]):lower()

        if sub == 'reset' then
            setLayoutEditing(false, { skipSave = true })

            local success = BccUtils.RPC:CallAsync('bcc-corehud:layout:reset', {})
            if success then
                devPrint('[bcc-corehud:layout:reset] Layout reset successfully')
            else
                devPrint('^1[bcc-corehud:layout:reset]^0 Failed to reset layout')
            end

            return
        end
    end

    setLayoutEditing(not hudLayoutEditing)
end)

registerCommandIfAvailable(commandPalette, function()
	mainPaleteMenu()
end)

registerCommandIfAvailable(commandClearFx, function()
	AnimpostfxStopAll()
	Notify(_U('hud_fx_cleared'), 'info')
end)

registerCommandIfAvailable(commandHeal, function()
	setLocalNeedValue('hunger', 100.0)
	setLocalNeedValue('thirst', 100.0)
	setLocalNeedValue('stress', 0.0)
	if Config.EnableCleanStatsCore then
		setCleanStatsPercent(100.0)
	end
	Notify(_U('hud_needs_refilled'), 'success')
end)

-- ==========
-- NUI bridge
-- ==========
RegisterNUICallback("updatestate", function(data, cb)
	if type(data) == "table" and type(data.state) == "boolean" then
		devPrint('NUI updatestate', data.state)
		setHudVisible(data.state)
	end
	if cb then cb("ok") end
end)

RegisterNUICallback('setLayoutEditing', function(data, cb)
	local target = data and data.editing
	if type(target) == 'boolean' then
		setLayoutEditing(target, (data and data.skipSave == true) and { skipSave = true } or nil)
	end
	if cb then cb('ok') end
end)

RegisterNUICallback('saveLayout', function(data, cb)
    local function normNumber(n)
        n = tonumber(n) or 0
        if n < 0 then n = 0 end
        if n > 100 then n = 100 end
        return n
    end

    local raw = (type(data) == 'table' and (data.positions or data.layout or data)) or nil
    local normalized = {}

    if type(raw) == 'table' then
        for key, v in pairs(raw) do
            if type(v) == 'table' then
                -- accept x/y; or left/top; or array {x,y}
                local x = v.x or v.left or v.l or v[1]
                local y = v.y or v.top or v.t or v[2]

                -- accept strings
                x = tonumber(x)
                y = tonumber(y)

                if x and y then
                    -- if UI gives 0..1, promote to percent
                    if x <= 1 and y <= 1 then
                        x = x * 100
                        y = y * 100
                    end
                    normalized[key] = { x = normNumber(x), y = normNumber(y) }
                end
            end
        end
    end

    SendNUIMessage({ type = 'layout', positions = normalized })

    local success = BccUtils.RPC:CallAsync('bcc-corehud:layout:save', { layout = normalized })

    if success then
        devPrint('[bcc-corehud:layout:save] Layout saved successfully')
    else
        devPrint('^1[bcc-corehud:layout:save]^0 Failed to save layout')
    end

    if cb then cb('ok') end
end)
