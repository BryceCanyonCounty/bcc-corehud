local config = Config or {}
local updateInterval = config.UpdateInterval or 1000
local updateIntervalSeconds = (type(updateInterval) == 'number' and updateInterval > 0 and updateInterval or 1000) / 1000.0
local autoShowHud = config.AutoShowHud ~= false
local lowCoreThreshold = config.LowCoreWarning or 25.0
local debugEnabled = config.Debug == true
local saveToDatabase = config.SaveToDatabase ~= false
local saveInterval = config.SaveInterval or 15000
local horseDirtyThreshold = config.HorseDirtyThreshold
if horseDirtyThreshold == nil then
    horseDirtyThreshold = 4
end

local coldTempThreshold = config.TemperatureColdThreshold
if coldTempThreshold == false then
    coldTempThreshold = nil
else
    coldTempThreshold = coldTempThreshold or -3.0
end

local hotTempThreshold = config.TemperatureHotThreshold

if hotTempThreshold == false then
    hotTempThreshold = nil
else
    hotTempThreshold = hotTempThreshold or 26.0
end

local showTemperatureAlways = config.AlwaysShowTemperature ~= false
local temperatureMin = type(config.TemperatureMin) == 'number' and config.TemperatureMin or -15.0
local temperatureMax = type(config.TemperatureMax) == 'number' and config.TemperatureMax or 40.0

local needsResourceName = config.NeedsResourceName
if type(needsResourceName) ~= 'string' or needsResourceName == '' then
    needsResourceName = nil
end
local hungerWarningEffect = config.HungerWarningEffect or 'starving'
local thirstWarningEffect = config.ThirstWarningEffect or 'parched'
local stressWarningEffect = config.StressWarningEffect or 'stressed'

local voiceCoreEnabled = config.EnableVoiceCore ~= false
local voiceMaxRange = type(config.VoiceMaxRange) == 'number' and config.VoiceMaxRange or 12.0
if voiceMaxRange <= 0 then
    voiceMaxRange = 12.0
end
local voiceTalkingLabel = config.VoiceTalkingLabel or 'talking'

if PaletteMenu and PaletteMenu.Init then
    PaletteMenu:Init({ debugEnabled = debugEnabled })
end

local hudVisible = nil
local lastPersistTick = 0
local lastPersistedSnapshot = nil
local needsErrorLogged = false
local voiceErrorLogged = false

local NATIVE_GET_ATTRIBUTE_CORE_VALUE = 0x36731AC041289BB1
local NATIVE_GET_PED_STAMINA = 0x775A1CA7893AA8B5
local NATIVE_GET_PED_MAX_STAMINA = 0xCB42AFE2B613EE55
local NATIVE_GET_ATTRIBUTE_RANK = 0xA4C8E23E29040DE0

local HORSE_DIRTINESS_ATTRIBUTE_INDEX = 16

local REQUIRED_PERSIST_NUMBERS = {
    { key = 'innerhealth', min = 0, max = 15, default = 0 },
    { key = 'outerhealth', min = 0, max = 99, default = 0 },
    { key = 'innerstamina', min = 0, max = 15, default = 0 },
    { key = 'outerstamina', min = 0, max = 99, default = 0 }
}

local OPTIONAL_PERSIST_NUMBERS = {
    { key = 'innerhorse_health', min = 0, max = 15 },
    { key = 'outerhorse_health', min = 0, max = 99 },
    { key = 'innerhorse_stamina', min = 0, max = 15 },
    { key = 'outerhorse_stamina', min = 0, max = 99 },
    { key = 'innerhorse_dirt', min = 0, max = 15 },
    { key = 'outerhorse_dirt', min = 0, max = 99 },
    { key = 'innertemperature', min = 0, max = 15 },
    { key = 'outertemperature', min = 0, max = 99 }
}

local PERSIST_STRINGS = {
    'effect_health_inside',
    'effect_stamina_inside',
    'effect_horse_health_inside',
    'effect_horse_stamina_inside',
    'effect_horse_dirt_inside',
    'effect_horse_dirt_next',
    'effect_temperature_inside',
    'effect_temperature_next'
}

local encodeJson = (json and json.encode) or function(value)
    return tostring(value)
end

local function debugPrint(label, ...)
    if not debugEnabled then
        return
    end

    local parts = {}
    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        if type(arg) == 'table' then
            parts[#parts + 1] = encodeJson(arg)
        else
            parts[#parts + 1] = tostring(arg)
        end
    end

    if #parts > 0 then
        print(('[BCC-CoreHUD] %s: %s'):format(label, table.concat(parts, ' | ')))
    else
        print(('[BCC-CoreHUD] %s'):format(label))
    end
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function round(value)
    return math.floor(value + 0.5)
end

local function toCoreState(value)
    local clamped = clamp(value, 0.0, 100.0)
    return clamp(round(clamped * 15.0 / 100.0), 0, 15)
end

local function toCoreMeter(value)
    local clamped = clamp(value, 0.0, 100.0)
    return clamp(round(clamped * 99.0 / 100.0), 0, 99)
end

local initialNeedValue = clamp(tonumber(config.InitialNeedValue) or 100.0, 0.0, 100.0)
local needsDecayStartDelay = math.max(0.0, tonumber(config.NeedsDecayStartDelay) or 300.0)
local hungerDecayDuration = math.max(1.0, tonumber(config.HungerDecayDuration) or 1800.0)
local thirstDecayDuration = math.max(1.0, tonumber(config.ThirstDecayDuration) or 1200.0)
local autoDecayActive = (config.NeedsAutoDecay ~= false) and needsResourceName == nil
local hotThirstMultiplier = tonumber(config.HotThirstMultiplier) or 2.0
if hotThirstMultiplier < 1.0 then
    hotThirstMultiplier = 1.0
end
local hotThirstBypassDelay = config.HotThirstBypassDelay ~= false

local function asPercent(value)
    if value == nil then
        return 0.0
    end

    if value <= 1.0 then
        return value * 100.0
    end

    return clamp(value, 0.0, 100.0)
end

local function toPercentOrNil(value)
    if value == nil then
        return nil
    end

    return asPercent(value)
end

local function mapTemperatureToPercent(temperature)
    if type(temperature) ~= 'number' then
        return nil
    end

    local minTemp = temperatureMin
    local maxTemp = temperatureMax

    if minTemp > maxTemp then
        minTemp, maxTemp = maxTemp, minTemp
    end

    local span = maxTemp - minTemp
    if span < 0.001 then
        return 50.0
    end

    local normalised = (temperature - minTemp) / span
    return clamp(normalised * 100.0, 0.0, 100.0)
end

local function getWorldTemperature()
    local ped = PlayerPedId()
    if ped == 0 then
        return 0.0
    end

    local coords = GetEntityCoords(ped)
    local success, temp = pcall(GetTemperatureAtCoords, coords.x, coords.y, coords.z)
    if not success then
        debugPrint('Temperature native failed', temp)
        return 0.0
    end

    return tonumber(temp) or 0.0
end

local function computeTemperatureEffect(temperature)
    if coldTempThreshold and temperature <= coldTempThreshold then
        return 'cold'
    end
    if hotTempThreshold and temperature >= hotTempThreshold then
        return 'hot'
    end
    return nil
end

local function isResourceActive(name)
    if type(name) ~= 'string' or name == '' then
        return false
    end

    local state = GetResourceState(name)
    return state == 'started'
end

local localNeedsState = {
    hunger = nil,
    thirst = nil,
    stress = nil
}

local needsDecayTrackers = {}
local currentTemperatureEffect = nil

local function getDecayDuration(stat)
    if stat == 'hunger' then
        return hungerDecayDuration
    end
    if stat == 'thirst' then
        return thirstDecayDuration
    end
    return nil
end

local function ensureDecayTracker(stat)
    if not autoDecayActive then
        return nil
    end

    local tracker = needsDecayTrackers[stat]
    if not tracker then
        tracker = { delay = needsDecayStartDelay, value = nil }
        needsDecayTrackers[stat] = tracker
    end

    tracker.duration = getDecayDuration(stat)
    return tracker
end

local function setLocalNeedValue(stat, value, options)
    if stat ~= 'hunger' and stat ~= 'thirst' and stat ~= 'stress' then
        return
    end

    local resetDelay = true
    if type(options) == 'table' and options.resetDelay == false then
        resetDelay = false
    end

    if value == nil then
        localNeedsState[stat] = nil
        if needsDecayTrackers[stat] then
            needsDecayTrackers[stat].value = nil
        end
        return
    end

    local numeric = tonumber(value)
    if numeric == nil then
        return
    end

    local clampedValue = clamp(numeric, 0.0, 100.0)
    localNeedsState[stat] = clampedValue

    if autoDecayActive and (stat == 'hunger' or stat == 'thirst') then
        local tracker = ensureDecayTracker(stat)
        if tracker then
            tracker.value = clampedValue
            if resetDelay then
                tracker.delay = needsDecayStartDelay
            end
        end
    end
end

local function processNeedsDecay(deltaSeconds)
    if not autoDecayActive then
        return
    end

    for _, stat in ipairs({ 'hunger', 'thirst' }) do
        local current = localNeedsState[stat]
        if current ~= nil then
            local tracker = ensureDecayTracker(stat)
            if tracker then
                local duration = tracker.duration
                if duration and duration > 0 then
                    local activeHot = stat == 'thirst' and currentTemperatureEffect == 'hot'
                    local decayMultiplier = 1.0
                    if activeHot then
                        if hotThirstBypassDelay and tracker.delay and tracker.delay > 0 then
                            tracker.delay = 0
                        end
                        decayMultiplier = hotThirstMultiplier
                    end

                    if tracker.delay and tracker.delay > 0 then
                        tracker.delay = tracker.delay - deltaSeconds
                        if tracker.delay < 0 then
                            tracker.delay = 0
                        end
                    else
                        if current > 0 then
                            local decayAmount = (deltaSeconds / duration) * 100.0 * decayMultiplier
                            if decayAmount > 0 then
                                local newValue = clamp(current - decayAmount, 0.0, 100.0)
                                if newValue ~= current then
                                    setLocalNeedValue(stat, newValue, { resetDelay = false })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

if autoDecayActive then
    if localNeedsState.hunger == nil then
        setLocalNeedValue('hunger', initialNeedValue)
    end
    if localNeedsState.thirst == nil then
        setLocalNeedValue('thirst', initialNeedValue)
    end
end

local function applyLocalNeedsUpdate(payload)
    if type(payload) ~= 'table' then
        return
    end

    if payload.hunger ~= nil then
        setLocalNeedValue('hunger', payload.hunger)
    end

    if payload.thirst ~= nil then
        setLocalNeedValue('thirst', payload.thirst)
    end

    if payload.stress ~= nil then
        setLocalNeedValue('stress', payload.stress)
    end
end

RegisterNetEvent('bcc-corehud:setNeeds', function(payload)
    if payload == nil then
        setLocalNeedValue('hunger', nil)
        setLocalNeedValue('thirst', nil)
        setLocalNeedValue('stress', nil)
        return
    end

    applyLocalNeedsUpdate(payload)
end)

RegisterNetEvent('bcc-corehud:setNeed', function(stat, value)
    if type(stat) ~= 'string' then
        return
    end

    local normalized = stat:lower()
    if normalized == 'hunger' or normalized == 'thirst' or normalized == 'stress' then
        setLocalNeedValue(normalized, value)
    end
end)

RegisterNetEvent('hud:client:changeValue', function(stat, value)
    if type(stat) ~= 'string' then
        return
    end

    local normalized = stat:lower()
    if normalized == 'hunger' or normalized == 'thirst' or normalized == 'stress' then
        setLocalNeedValue(normalized, value)
    end
end)

exports('SetNeeds', function(payload)
    if payload == nil then
        setLocalNeedValue('hunger', nil)
        setLocalNeedValue('thirst', nil)
        setLocalNeedValue('stress', nil)
        return
    end

    applyLocalNeedsUpdate(payload)
end)

exports('SetNeed', function(stat, value)
    if type(stat) ~= 'string' then
        return
    end

    local normalized = stat:lower()
    if normalized == 'hunger' or normalized == 'thirst' or normalized == 'stress' then
        setLocalNeedValue(normalized, value)
    end
end)

local function getNeedsSnapshot()
    if needsResourceName then
        if not isResourceActive(needsResourceName) then
            if debugEnabled and not needsErrorLogged then
                debugPrint('Needs resource inactive', needsResourceName)
                needsErrorLogged = true
            end
        else
            local success, result = pcall(function()
                return exports[needsResourceName]:GetNeedsData()
            end)

            if success and type(result) == 'table' then
                needsErrorLogged = false
                return result
            end

            if debugEnabled and not success and not needsErrorLogged then
                debugPrint('Needs export failed', result)
                needsErrorLogged = true
            end
        end
    end

    if localNeedsState.hunger == nil and localNeedsState.thirst == nil and localNeedsState.stress == nil then
        return nil
    end

    return {
        hunger = localNeedsState.hunger,
        thirst = localNeedsState.thirst,
        stress = localNeedsState.stress
    }
end

local function getVoiceTelemetry()
    if not voiceCoreEnabled then
        return nil
    end

    local successTalking, isTalking = pcall(MumbleIsPlayerTalking, PlayerId())
    if not successTalking then
        if debugEnabled and not voiceErrorLogged then
            debugPrint('Voice talking check failed', isTalking)
            voiceErrorLogged = true
        end
        return nil
    end

    local successProximity, proximity = pcall(MumbleGetTalkerProximity)
    if not successProximity then
        if debugEnabled and not voiceErrorLogged then
            debugPrint('Voice proximity check failed', proximity)
            voiceErrorLogged = true
        end
        proximity = 0.0
    else
        voiceErrorLogged = false
    end

    proximity = tonumber(proximity) or 0.0
    if proximity ~= proximity or proximity == math.huge or proximity == -math.huge then
        proximity = 0.0
    end

    local effectiveMaxRange = voiceMaxRange
    if effectiveMaxRange <= 0.0 then
        effectiveMaxRange = 12.0
    end

    local percent = 0.0
    if effectiveMaxRange > 0.0 then
        percent = clamp((proximity / effectiveMaxRange) * 100.0, 0.0, 100.0)
    end

    local effectInside = nil
    if isTalking then
        effectInside = voiceTalkingLabel
    end

    local effectNext = nil
    if proximity > 0.0 then
        local metres = round(proximity)
        if metres < 0 then
            metres = 0
        end
        effectNext = tostring(metres) .. 'm'
    end

    return {
        inner = isTalking and 15 or 0,
        outer = toCoreMeter(percent),
        effectInside = effectInside,
        effectNext = effectNext
    }
end

local function normalizeNumeric(value, minValue, maxValue)
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    if minValue ~= nil and number < minValue then
        number = minValue
    end
    if maxValue ~= nil and number > maxValue then
        number = maxValue
    end
    return round(number)
end

local function normalizeSnapshotForPersistence(snapshot)
    local result = {}

    for _, entry in ipairs(REQUIRED_PERSIST_NUMBERS) do
        local value = normalizeNumeric(snapshot[entry.key], entry.min, entry.max) or entry.default or 0
        result[entry.key] = value
    end

    local horseValuesPresent = false
        local horseOptionalKeys = {
        innerhorse_health = true,
        outerhorse_health = true,
        innerhorse_stamina = true,
        outerhorse_stamina = true,
        innerhorse_dirt = true,
        outerhorse_dirt = true
    }

    for _, entry in ipairs(OPTIONAL_PERSIST_NUMBERS) do
        local value = normalizeNumeric(snapshot[entry.key], entry.min, entry.max)
        if value ~= nil and horseOptionalKeys[entry.key] then
            horseValuesPresent = true
        end
        result[entry.key] = value
    end

    for _, key in ipairs(PERSIST_STRINGS) do
        local value = snapshot[key]
        if type(value) == 'string' and value ~= '' then
            result[key] = value
        else
            result[key] = nil
        end
    end

    local horseActive = snapshot.horse_active == true or snapshot.horse_active == 1
    if horseValuesPresent then
        horseActive = true
    end
    result.horse_active = horseActive

    return result
end

local function getHorseDirtRank(horse)
    if not horse or horse == 0 then
        return 0
    end

    local success, rank = pcall(Citizen.InvokeNative, NATIVE_GET_ATTRIBUTE_RANK, horse,
        HORSE_DIRTINESS_ATTRIBUTE_INDEX, Citizen.ResultAsInteger())
    if not success then
        debugPrint('Dirt native failed', 'horse', horse, 'error', rank)
        return 0
    end

    return tonumber(rank) or 0
end

local function isHorseDirty(horse)
    if type(horseDirtyThreshold) ~= 'number' then
        return false
    end

    if horseDirtyThreshold <= 0 then
        return false
    end

    local dirtRank = getHorseDirtRank(horse)

    -- Rank 0 can mean either "unknown" or "perfectly clean" depending on the
    -- native response. Treat it as clean unless the fallback reports dirt.
    if dirtRank > 0 then
        return dirtRank <= horseDirtyThreshold
    end

    -- Fallback to the direct dirt level measurement (0.0 clean -> 1.0 filthy).
    local success, dirtLevel = pcall(Citizen.InvokeNative, 0x2B3451FA1E3142E2, horse)
    if success then
        dirtLevel = tonumber(dirtLevel) or 0.0
        if dirtLevel > 0.0 then
            return dirtLevel >= 0.35 -- configurable threshold via rank when available
        end
    end

    return false
end

local function valueOrSentinel(value)
    if value == nil then
        return '__nil'
    end
    return value
end

local function snapshotsDifferent(a, b)
    if not b then
        return true
    end

    for _, entry in ipairs(REQUIRED_PERSIST_NUMBERS) do
        if valueOrSentinel(a[entry.key]) ~= valueOrSentinel(b[entry.key]) then
            return true
        end
    end

    for _, entry in ipairs(OPTIONAL_PERSIST_NUMBERS) do
        if valueOrSentinel(a[entry.key]) ~= valueOrSentinel(b[entry.key]) then
            return true
        end
    end

    for _, key in ipairs(PERSIST_STRINGS) do
        if valueOrSentinel(a[key]) ~= valueOrSentinel(b[key]) then
            return true
        end
    end

    if valueOrSentinel(a.horse_active and 1 or 0) ~= valueOrSentinel(b.horse_active and 1 or 0) then
        return true
    end

    return false
end

local function persistSnapshot(normalized)
    lastPersistedSnapshot = normalized
    lastPersistTick = GetGameTimer()
    debugPrint('Persisting snapshot', normalized)
    TriggerServerEvent('bcc-corehud:saveCores', normalized)
end

local function maybePersistSnapshot(snapshot)
    if not saveToDatabase then
        return
    end

    local normalized = normalizeSnapshotForPersistence(snapshot)

    if not lastPersistedSnapshot then
        persistSnapshot(normalized)
        return
    end

    if not snapshotsDifferent(normalized, lastPersistedSnapshot) then
        return
    end

    local now = GetGameTimer()
    if now - lastPersistTick < saveInterval then
        return
    end

    persistSnapshot(normalized)
end

local function getCoreValue(ped, index)
    if not ped or ped == 0 then
        return 0.0
    end

    local success, coreValue = pcall(Citizen.InvokeNative, NATIVE_GET_ATTRIBUTE_CORE_VALUE, ped, index,
        Citizen.ResultAsInteger())
    if not success then
        debugPrint('Core native failed', 'ped', ped, 'index', index, 'error', coreValue)
        return 0.0
    end

    return clamp(tonumber(coreValue) or 0.0, 0.0, 100.0)
end

local function getHealthPercent(ped)
    if not ped or ped == 0 then
        return 0.0
    end

    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    if not maxHealth or maxHealth <= 0 then
        return 0.0
    end

    return clamp((health / maxHealth) * 100.0, 0.0, 100.0)
end

local function getPedStaminaPercent(ped)
    if not ped or ped == 0 then
        return 0.0
    end

    local success, stamina = pcall(Citizen.InvokeNative, NATIVE_GET_PED_STAMINA, ped, Citizen.ResultAsFloat())
    if success and stamina then
        stamina = tonumber(stamina)
        if stamina then
            local successMax, maxStamina = pcall(Citizen.InvokeNative, NATIVE_GET_PED_MAX_STAMINA, ped,
                Citizen.ResultAsFloat())
            if successMax and maxStamina and maxStamina > 0.0 then
                return clamp((stamina / maxStamina) * 100.0, 0.0, 100.0)
            end
            return clamp(stamina, 0.0, 100.0)
        end
    else
        debugPrint('Stamina native failed', 'ped', ped, 'error', stamina)
    end

    if ped == PlayerPedId() then
        local fallbackSuccess, raw = pcall(GetPlayerStamina, PlayerId())
        if fallbackSuccess then
            return asPercent(raw)
        end
    end

    return getCoreValue(ped, 1)
end

local function getPlayerStaminaPercent()
    local ped = PlayerPedId()
    if ped == 0 then
        return 0.0
    end

    return getPedStaminaPercent(ped)
end

local function computeEffect(corePercent, lowThreshold, effect)
    if corePercent <= lowThreshold then
        return effect
    end
    return nil
end

local function buildCoreSnapshot()
    local ped = PlayerPedId()
    if ped == 0 then
        return nil
    end

    local healthCore = getCoreValue(ped, 0)
    local staminaCore = getCoreValue(ped, 1)

    local horse = 0
    if IsPedOnMount(ped) then
        horse = GetMount(ped)
    end

    local horseHealthCore, horseStaminaCore
    local horseHealthPercent, horseStaminaPercent

    if horse ~= 0 then
        horseHealthCore = getCoreValue(horse, 0)
        horseStaminaCore = getCoreValue(horse, 1)
        horseHealthPercent = getHealthPercent(horse)
        horseStaminaPercent = getPedStaminaPercent(horse)
    end

    -- Effects when the inner core gets critically low
    local healthEffect = computeEffect(healthCore, lowCoreThreshold, "wounded")
    local staminaEffect = computeEffect(staminaCore, lowCoreThreshold, "drained")
    local horseHealthEffect = computeEffect(horseHealthCore or 100.0, lowCoreThreshold, "wounded")
    local horseStaminaEffect = computeEffect(horseStaminaCore or 100.0, lowCoreThreshold, "drained")

    local healthEffectNext = nil
    local staminaEffectNext = nil

    local needsData = getNeedsSnapshot()

    local hungerInner, hungerOuter, hungerEffectInside, hungerEffectNext = nil, nil, nil, nil
    local thirstInner, thirstOuter, thirstEffectInside, thirstEffectNext = nil, nil, nil, nil
    local stressInner, stressOuter, stressEffectInside, stressEffectNext = nil, nil, nil, nil

    if needsData then
        if needsData.hunger ~= nil then
            local hungerPercent = toPercentOrNil(tonumber(needsData.hunger))
            if hungerPercent ~= nil then
                hungerInner = toCoreState(hungerPercent)
                hungerOuter = toCoreMeter(hungerPercent)
                hungerEffectInside = computeEffect(hungerPercent, lowCoreThreshold, hungerWarningEffect)
                hungerEffectNext = string.format('%d%%', round(hungerPercent))
            end
        end

        if needsData.thirst ~= nil then
            local thirstPercent = toPercentOrNil(tonumber(needsData.thirst))
            if thirstPercent ~= nil then
                thirstInner = toCoreState(thirstPercent)
                thirstOuter = toCoreMeter(thirstPercent)
                thirstEffectInside = computeEffect(thirstPercent, lowCoreThreshold, thirstWarningEffect)
                thirstEffectNext = string.format('%d%%', round(thirstPercent))
            end
        end

        if needsData.stress ~= nil then
            local stressPercent = toPercentOrNil(tonumber(needsData.stress))
            if stressPercent ~= nil then
                stressInner = toCoreState(stressPercent)
                stressOuter = toCoreMeter(stressPercent)
                stressEffectInside = computeEffect(stressPercent, lowCoreThreshold, stressWarningEffect)
                stressEffectNext = string.format('%d%%', round(stressPercent))
            end
        end
    end

    local worldTemperature = getWorldTemperature()
    local temperatureEffect = computeTemperatureEffect(worldTemperature)

    currentTemperatureEffect = temperatureEffect

    local temperatureInner = nil
    local temperatureOuter = nil
    local temperatureInsideEffect = nil
    local temperatureNextEffect = nil

    local temperaturePercent = mapTemperatureToPercent(worldTemperature)
    if temperaturePercent and (showTemperatureAlways or temperatureEffect) then
        temperatureInner = toCoreState(temperaturePercent)
        temperatureOuter = toCoreMeter(temperaturePercent)
        temperatureInsideEffect = temperatureEffect
        temperatureNextEffect = string.format('%d°', round(worldTemperature))
    elseif temperatureEffect then
        temperatureInner = 15
        temperatureOuter = 99
        temperatureInsideEffect = temperatureEffect
    end

    local horseHealthInsideEffect = nil
    if horse ~= 0 then
        horseHealthInsideEffect = horseHealthEffect
    end

    local horseStaminaInsideEffect = nil
    if horse ~= 0 then
        horseStaminaInsideEffect = horseStaminaEffect
    end

    local horseDirtInner = nil
    local horseDirtOuter = nil
    local horseDirtInsideEffect = nil
    local horseDirtNextEffect = nil

    if horse ~= 0 and isHorseDirty(horse) then
        horseDirtInner = 15
        horseDirtOuter = 99
        horseDirtInsideEffect = "horse_dirty"
    end

    local voiceTelemetry = getVoiceTelemetry()

    return {
        innerhealth = toCoreState(healthCore),
        outerhealth = toCoreMeter(getHealthPercent(ped)),
        innerstamina = toCoreState(staminaCore),
        outerstamina = toCoreMeter(getPlayerStaminaPercent()),
        innerhunger = hungerInner,
        outerhunger = hungerOuter,
        effect_hunger_inside = hungerEffectInside,
        effect_hunger_next = hungerEffectNext,
        innerthirst = thirstInner,
        outerthirst = thirstOuter,
        effect_thirst_inside = thirstEffectInside,
        effect_thirst_next = thirstEffectNext,
        innerstress = stressInner,
        outerstress = stressOuter,
        effect_stress_inside = stressEffectInside,
        effect_stress_next = stressEffectNext,
        innerhorse_health = horseHealthCore and toCoreState(horseHealthCore) or nil,
        outerhorse_health = horseHealthPercent and toCoreMeter(horseHealthPercent) or nil,
        innerhorse_stamina = horseStaminaCore and toCoreState(horseStaminaCore) or nil,
        outerhorse_stamina = horseStaminaPercent and toCoreMeter(horseStaminaPercent) or nil,
        effect_health_inside = healthEffect,
        effect_health_next = healthEffectNext,
        effect_stamina_inside = staminaEffect,
        effect_stamina_next = staminaEffectNext,
        effect_horse_health_inside = horse ~= 0 and horseHealthInsideEffect or nil,
        effect_horse_stamina_inside = horse ~= 0 and horseStaminaInsideEffect or nil,
        innerhorse_dirt = horseDirtInner,
        outerhorse_dirt = horseDirtOuter,
        effect_horse_dirt_inside = horseDirtInsideEffect,
        effect_horse_dirt_next = horseDirtNextEffect,
        innertemperature = temperatureInner,
        outertemperature = temperatureOuter,
        effect_temperature_inside = temperatureInsideEffect,
        effect_temperature_next = temperatureNextEffect,
        innervoice = voiceTelemetry and voiceTelemetry.inner or nil,
        outervoice = voiceTelemetry and voiceTelemetry.outer or nil,
        effect_voice_inside = voiceTelemetry and voiceTelemetry.effectInside or nil,
        effect_voice_next = voiceTelemetry and voiceTelemetry.effectNext or nil,
        horse_active = horse ~= 0
    }
end

local function pushHudSnapshot()
    local snapshot = buildCoreSnapshot()
    if not snapshot then
        debugPrint('No snapshot available')
        return
    end

    debugPrint('Sending snapshot', snapshot)
    SendNUIMessage({
        type = "hud",
        cores = snapshot
    })

    maybePersistSnapshot(snapshot)
end

local function setHudVisible(visible)
    if hudVisible == visible then
        debugPrint('HUD visibility unchanged', visible)
        return
    end

    hudVisible = visible

    debugPrint('HUD visibility set', hudVisible)

    SendNUIMessage({
        type = "toggle",
        visible = hudVisible
    })

    if hudVisible then
        pushHudSnapshot()
    end
end

function ToggleUI()
    setHudVisible(not hudVisible)
end

-- Immediately initialise the HUD when the resource starts
CreateThread(function()
    if PaletteMenu and PaletteMenu.Rebuild then
        PaletteMenu:Rebuild()
    end
    Wait(500)
    setHudVisible(autoShowHud)

    while true do
        Wait(updateInterval)

        processNeedsDecay(updateIntervalSeconds)

        if hudVisible then
            pushHudSnapshot()
        end
    end
end)

RegisterCommand("togglehud", function()
    ToggleUI()
end, false)

RegisterCommand('hudpalette', function()
    if PaletteMenu and PaletteMenu.Open then
        PaletteMenu:Open()
    end
end, false)

RegisterNUICallback("updatestate", function(data, cb)
    if type(data) == "table" and type(data.state) == "boolean" then
        debugPrint('NUI updatestate', data.state)
        setHudVisible(data.state)
    end

    if cb then
        cb("ok")
    end
end)
