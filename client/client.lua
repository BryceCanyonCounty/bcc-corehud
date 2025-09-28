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
local temperatureHotDamagePerSecond = math.max(0.0, tonumber(config.HotTemperatureDamagePerSecond) or 0.0)
local temperatureColdDamagePerSecond = math.max(0.0, tonumber(config.ColdTemperatureDamagePerSecond) or 0.0)
local temperatureDamageDelay = math.max(0.0, tonumber(config.TemperatureDamageDelay) or 5.0)

local needsResourceName = config.NeedsResourceName
if type(needsResourceName) ~= 'string' or needsResourceName == '' then
    needsResourceName = nil
end
local hungerWarningEffect = config.HungerWarningEffect or 'starving'
local thirstWarningEffect = config.ThirstWarningEffect or 'parched'
local stressWarningEffect = config.StressWarningEffect or 'stressed'

-- ===========================
-- Voice core + proximity steps
-- ===========================
local voiceCoreEnabled = config.EnableVoiceCore ~= false
local voiceMaxRange = type(config.VoiceMaxRange) == 'number' and config.VoiceMaxRange
if voiceMaxRange <= 0 then
    voiceMaxRange = 50.0
end
local voiceTalkingLabel = config.VoiceTalkingLabel or 'talking'

-- Steps to cycle (whisper/normal/shout). You can override in Config.VoiceProximitySteps = { 2.0, 5.0, 12.0 }
local voiceProximitySteps = {}
do
    local steps = config.VoiceProximitySteps
    local tmp = {}
    for _, v in ipairs(steps) do
        local n = tonumber(v)
        if n and n > 0 then tmp[#tmp+1] = n end
    end
    table.sort(tmp)
    for i = 1, #tmp do
        if i == 1 or tmp[i] ~= tmp[i-1] then
            voiceProximitySteps[#voiceProximitySteps+1] = tmp[i]
        end
    end
    if #voiceProximitySteps == 0 then voiceProximitySteps = { 2.0, 15.0, 50.0 } end
end

local voiceStepIndex = math.floor((tonumber(config.VoiceDefaultStepIndex) or 2) + 0.5)
if voiceStepIndex < 1 then voiceStepIndex = 1 end
if voiceStepIndex > #voiceProximitySteps then voiceStepIndex = #voiceProximitySteps end

-- Largest step used for HUD normalization
local voiceMaxStep = voiceProximitySteps[#voiceProximitySteps]

local function resolveControlHash(val)
    if type(val) == 'number' then return val end
    if type(val) == 'string' and val ~= '' then return GetHashKey(val) end
    return 0x26E9DC00 -- fallback control hash; override via Config.VoiceCycleControl
end
local voiceCycleControl = resolveControlHash(config.VoiceCycleControl)

local function setTalkerProximity(metres)
    pcall(MumbleSetTalkerProximity, metres)
    -- keep input/output distances similar (harmless if not supported on your build)
    pcall(MumbleSetAudioInputDistance, metres)
    pcall(MumbleSetAudioOutputDistance, metres)
    if debugEnabled then
        print(('[BCC-CoreHUD] Voice proximity set: %.1fm'):format(metres))
    end
end

local function applyVoiceStep(idx)
    if idx < 1 then idx = #voiceProximitySteps end
    if idx > #voiceProximitySteps then idx = 1 end
    voiceStepIndex = idx
    local metres = voiceProximitySteps[voiceStepIndex]
    setTalkerProximity(metres)
    -- optional toast (replace with your notify if desired)
    pcall(TriggerEvent, 'chat:addMessage', { args = { '^3Voice', ('Proximity: %.0fm'):format(metres) } })
end

local function cycleVoiceStep(dir)
    applyVoiceStep(voiceStepIndex + (dir or 1))
end
-- ===========================

if PaletteMenu and PaletteMenu.Init then
    PaletteMenu:Init({ debugEnabled = debugEnabled })
end

local hudVisible = nil
local hudPreference = autoShowHud
local hudSuppressed = false
local lastPersistTick = 0
local lastPersistedSnapshot = nil
local needsErrorLogged = false
local voiceErrorLogged = false

local NATIVE_GET_ATTRIBUTE_CORE_VALUE = 0x36731AC041289BB1
local NATIVE_GET_PED_STAMINA = 0x775A1CA7893AA8B5
local NATIVE_GET_PED_MAX_STAMINA = 0xCB42AFE2B613EE55
local NATIVE_GET_ATTRIBUTE_RANK = 0xA4C8E23E29040DE0

local HORSE_DIRTINESS_ATTRIBUTE_INDEX = 16
local NATIVE_HUD_SET_ICON_VISIBILITY = 0xC116E6DF68DCE667

local REQUIRED_PERSIST_NUMBERS = {
    { key = 'innerhealth', min = 0, max = 15, default = 0 },
    { key = 'outerhealth', min = 0, max = 99, default = 0 },
    { key = 'innerstamina', min = 0, max = 15, default = 0 },
    { key = 'outerstamina', min = 0, max = 99, default = 0 }
}

local OPTIONAL_PERSIST_NUMBERS = {
    { key = 'outerhunger', min = 0, max = 99 },
    { key = 'outerthirst', min = 0, max = 99 },
    { key = 'outerstress', min = 0, max = 99 },
    { key = 'innerhorse_health', min = 0, max = 15 },
    { key = 'outerhorse_health', min = 0, max = 99 },
    { key = 'innerhorse_stamina', min = 0, max = 15 },
    { key = 'outerhorse_stamina', min = 0, max = 99 }
}

local PERSIST_STRINGS = {}

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
-- (cross-decay removed)
local starvationDamageDelay = math.max(0.0, tonumber(config.StarvationDamageDelay) or 0.0)
local starvationDamageInterval = math.max(0.0, tonumber(config.StarvationDamageInterval) or 10.0)
local starvationDamageAmount = math.max(0.0, tonumber(config.StarvationDamageAmount) or 4.0)

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

local function computeActivityMultipliers()
    local hungerMultiplier = 1.0
    local thirstMultiplier = 1.0

    local ped = PlayerPedId()
    if ped == 0 then
        return hungerMultiplier, thirstMultiplier
    end

    local function applyIdleModifiers()
        hungerMultiplier = hungerMultiplier * 0.7
        thirstMultiplier = thirstMultiplier * 0.75
    end

    local function applyWalkingModifiers()
        hungerMultiplier = hungerMultiplier * 1.0
        thirstMultiplier = thirstMultiplier * 1.1
    end

    local function applyRunningModifiers()
        hungerMultiplier = hungerMultiplier * 1.25
        thirstMultiplier = thirstMultiplier * 1.6
    end

    local function applySprintingModifiers()
        hungerMultiplier = hungerMultiplier * 1.5
        thirstMultiplier = thirstMultiplier * 2.2
    end

    if IsPedOnMount(ped) then
        local mount = GetMount(ped)
        local mountSpeed = 0.0
        if mount ~= 0 then
            mountSpeed = GetEntitySpeed(mount)
        end

        if mountSpeed < 0.25 then
            applyIdleModifiers()
        elseif mountSpeed < 3.0 then
            applyWalkingModifiers()
        elseif mountSpeed < 6.5 then
            applyRunningModifiers()
        else
            applySprintingModifiers()
        end
    else
        local speed = GetEntitySpeed(ped)

        if speed < 0.25 then
            applyIdleModifiers()
        elseif IsPedSprinting(ped) then
            applySprintingModifiers()
        elseif IsPedRunning(ped) then
            applyRunningModifiers()
        elseif IsPedWalking(ped) then
            applyWalkingModifiers()
        else
            hungerMultiplier = hungerMultiplier * 0.85
            thirstMultiplier = thirstMultiplier * 0.9
        end
    end

    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
        hungerMultiplier = hungerMultiplier + 0.4
        thirstMultiplier = thirstMultiplier + 1.2
    end

    if hungerMultiplier < 0.1 then
        hungerMultiplier = 0.1
    end

    if thirstMultiplier < 0.1 then
        thirstMultiplier = 0.1
    end

    return hungerMultiplier, thirstMultiplier
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
local starvationTimer = 0.0
local starvationElapsed = 0.0
local starvationDelaySatisfied = false
local temperatureDamageTimer = 0.0
local hudLayoutEditing = false

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

local entityHealthChangeNative = 0x835F131E7DC8F97A

local function hideRdrHudIcons()
    local iconsToHide = {
        0, 1, -- stamina / stamina core
        2, 3, -- deadeye / deadeye core
        4, 5, -- health / health core
        6, 7, -- horse health / core
        8, 9, -- horse stamina / core
        10, 11 -- horse courage / core
    }

    for _, icon in ipairs(iconsToHide) do
        Citizen.InvokeNative(NATIVE_HUD_SET_ICON_VISIBILITY, icon, 2)
    end
end

local function changeEntityHealth(entity, delta)
    if entity == 0 or entity == nil then
        return false
    end

    if delta == nil or delta == 0 then
        return false
    end

    return Citizen.InvokeNative(entityHealthChangeNative, entity, delta, 0, 0)
end

local function applyStarvationDamage()
    if starvationDamageAmount <= 0.0 then
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or IsEntityDead(ped) then
        return
    end

    local currentHealth = GetEntityHealth(ped)
    if not currentHealth or currentHealth <= 0 then
        return
    end

    local damage = math.floor(starvationDamageAmount + 0.5)
    if damage <= 0 then
        return
    end

    changeEntityHealth(ped, -damage)
end

local function applyTemperatureDamage(deltaSeconds)
    if temperatureHotDamagePerSecond <= 0.0 and temperatureColdDamagePerSecond <= 0.0 then
        temperatureDamageTimer = 0.0
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or IsEntityDead(ped) then
        temperatureDamageTimer = 0.0
        return
    end

    local effect = currentTemperatureEffect
    if effect ~= 'hot' and effect ~= 'cold' then
        temperatureDamageTimer = 0.0
        return
    end

    local damagePerSecond = effect == 'hot' and temperatureHotDamagePerSecond or temperatureColdDamagePerSecond
    if damagePerSecond <= 0.0 then
        temperatureDamageTimer = 0.0
        return
    end

    temperatureDamageTimer = temperatureDamageTimer + deltaSeconds
    if temperatureDamageTimer < temperatureDamageDelay then
        return
    end

    local currentHealth = GetEntityHealth(ped)
    if not currentHealth or currentHealth <= 0 then
        return
    end

    local damage = damagePerSecond * deltaSeconds
    if damage <= 0.05 then
        return
    end

    changeEntityHealth(ped, -damage)
end

local function sendLayoutToNui(payload)
    SendNUIMessage({
        type = 'layout',
        positions = payload or {}
    })
end

local function setLayoutEditing(enabled, options)
    local shouldEnable = enabled == true
    local skipSave = type(options) == 'table' and options.skipSave == true

    if hudLayoutEditing == shouldEnable then
        if not shouldEnable then
            SendNUIMessage({ type = 'layoutEdit', editing = false })
        end
        return
    end

    hudLayoutEditing = shouldEnable
    SetNuiFocus(shouldEnable, shouldEnable)
    SendNUIMessage({ type = 'layoutEdit', editing = shouldEnable })

    if not shouldEnable and not skipSave then
        SendNUIMessage({ type = 'layoutRequestSave' })
    end
end

local function requestLayoutFromServer()
    TriggerServerEvent('bcc-corehud:layout:request')
end

local function processNeedsDecay(deltaSeconds)
    if not autoDecayActive then
        return
    end

    local isHungerEmpty = localNeedsState.hunger ~= nil and localNeedsState.hunger <= 0.0
    local isThirstEmpty = localNeedsState.thirst ~= nil and localNeedsState.thirst <= 0.0
    local hungerActivityMultiplier, thirstActivityMultiplier = computeActivityMultipliers()

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

                    -- (cross-need multiplier removed)

                    if stat == 'hunger' then
                        decayMultiplier = decayMultiplier * hungerActivityMultiplier
                    else
                        decayMultiplier = decayMultiplier * thirstActivityMultiplier
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

    if starvationDamageAmount > 0.0 then
        if isHungerEmpty and isThirstEmpty then
            starvationElapsed = starvationElapsed + deltaSeconds

            if starvationElapsed >= starvationDamageDelay then
                if not starvationDelaySatisfied then
                    starvationDelaySatisfied = true
                    if starvationDamageInterval > 0.0 then
                        starvationTimer = starvationDamageInterval
                    end
                end

                if starvationDamageInterval <= 0.0 then
                    applyStarvationDamage()
                else
                    starvationTimer = starvationTimer + deltaSeconds
                    if starvationTimer >= starvationDamageInterval then
                        starvationTimer = starvationTimer - starvationDamageInterval
                        applyStarvationDamage()
                    end
                end
            else
                starvationTimer = 0.0
            end
        else
            starvationElapsed = 0.0
            starvationTimer = 0.0
            starvationDelaySatisfied = false
        end
    else
        starvationElapsed = 0.0
        starvationTimer = 0.0
        starvationDelaySatisfied = false
    end

    applyTemperatureDamage(deltaSeconds)
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

RegisterNetEvent('bcc-corehud:layout:apply', function(payload)
    if type(payload) == 'table' then
        sendLayoutToNui(payload)
    else
        sendLayoutToNui(nil)
    end
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

    -- Normalize by the largest configured step so the ring shows 100% on "shout"
    local effectiveMaxRange = math.max(voiceMaxRange or 12.0, voiceMaxStep or 12.0)
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
        effectNext = effectNext,
        talking = isTalking and true or false,
        proximity = proximity,
        proximityPercent = percent
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

    for _, entry in ipairs(OPTIONAL_PERSIST_NUMBERS) do
        local value = normalizeNumeric(snapshot[entry.key], entry.min, entry.max)
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

    if dirtRank > 0 then
        return dirtRank <= horseDirtyThreshold
    end

    local success, dirtLevel = pcall(Citizen.InvokeNative, 0x2B3451FA1E3142E2, horse)
    if success then
        dirtLevel = tonumber(dirtLevel) or 0.0
        if dirtLevel > 0.0 then
            return dirtLevel >= 0.35
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
    local temperatureValueInner = nil
    local temperatureValueOuter = nil
    local temperatureValueNextEffect = nil

    local temperaturePercent = mapTemperatureToPercent(worldTemperature)
    if temperaturePercent then
        temperatureValueInner = 15
        temperatureValueOuter = 99
        temperatureValueNextEffect = string.format('%d°', round(worldTemperature))
    end

    if temperatureEffect then
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
        effect_horse_stamina_inside = horseStaminaInsideEffect,
        innerhorse_dirt = horseDirtInner,
        outerhorse_dirt = horseDirtOuter,
        effect_horse_dirt_inside = horseDirtInsideEffect,
        effect_horse_dirt_next = horseDirtNextEffect,
        innertemperature = temperatureInner,
        outertemperature = temperatureOuter,
        effect_temperature_inside = temperatureInsideEffect,
        effect_temperature_next = temperatureNextEffect,
        innertemperature_value = temperatureValueInner,
        outertemperature_value = temperatureValueOuter,
        effect_temperature_value_next = temperatureValueNextEffect,
        innervoice = voiceTelemetry and voiceTelemetry.inner or nil,
        outervoice = voiceTelemetry and voiceTelemetry.outer or nil,
        effect_voice_inside = voiceTelemetry and voiceTelemetry.effectInside or nil,
        effect_voice_next = voiceTelemetry and voiceTelemetry.effectNext or nil,
        voice_talking = voiceTelemetry and (voiceTelemetry.talking and true or false) or nil,
        voice_proximity = voiceTelemetry and voiceTelemetry.proximity or nil,
        voice_proximity_percent = voiceTelemetry and voiceTelemetry.proximityPercent or nil
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

local function computeHudSuppressed()
    if IsPauseMenuActive() then
        return true
    end

    local cinematicOpen = Citizen.InvokeNative(0x74F1D22EFA71FAB8)
    if cinematicOpen == true or cinematicOpen == 1 or cinematicOpen == -1 then
        return true
    end

    local mapOpen = Citizen.InvokeNative(0x25B7A0206BDFAC76, `MAP`)
    if mapOpen == true or mapOpen == 1 or mapOpen == -1 then
        return true
    end

    return false
end

-- ===========================
-- Key input loop: cycle voice
-- ===========================
CreateThread(function()
    local GROUP = 0
    local debounceMs = 180
    local last = 0

    while true do
        Wait(0)
        if IsPauseMenuActive() or hudLayoutEditing then goto continue end

        -- IsControlJustPressed (0x580417101DDB492F)
        if Citizen.InvokeNative(0x580417101DDB492F, GROUP, voiceCycleControl) then
            local now = GetGameTimer()
            if now - last >= debounceMs then
                if voiceCoreEnabled then
                    cycleVoiceStep(1)
                end
                last = now
            end
        end

        ::continue::
    end
end)
-- ===========================

local function applyHudVisibility()
    local shouldShow = hudPreference and not hudSuppressed

    if hudVisible == shouldShow then
        debugPrint('HUD visibility unchanged', shouldShow)
        return
    end

    if not shouldShow and hudLayoutEditing then
        setLayoutEditing(false, { skipSave = true })
    end

    hudVisible = shouldShow

    debugPrint('HUD visibility set', hudVisible, 'suppressed', hudSuppressed)

    SendNUIMessage({
        type = "toggle",
        visible = hudVisible
    })

    if hudVisible then
        pushHudSnapshot()
    end
end

local function setHudVisible(visible)
    hudPreference = visible == true
    applyHudVisibility()
end

function ToggleUI()
    setHudVisible(not hudPreference)
end

-- Immediately initialise the HUD when the resource starts
CreateThread(function()
    hideRdrHudIcons()

    if PaletteMenu and PaletteMenu.Rebuild then
        PaletteMenu:Rebuild()
    end

    Wait(500)

    hudPreference = autoShowHud
    hudSuppressed = computeHudSuppressed()
    applyHudVisibility()
    requestLayoutFromServer()

    -- Apply default voice proximity once up
    if voiceCoreEnabled then
        applyVoiceStep(voiceStepIndex)
    end

    while true do
        Wait(updateInterval)

        processNeedsDecay(updateIntervalSeconds)

        local suppressed = computeHudSuppressed()
        if suppressed ~= hudSuppressed then
            hudSuppressed = suppressed
            applyHudVisibility()
        end

        if hudVisible then
            pushHudSnapshot()
        end
    end
end)

RegisterCommand("togglehud", function()
    ToggleUI()
end, false)

RegisterCommand('hudlayout', function(_, args)
    if type(args) == 'table' and args[1] then
        local sub = tostring(args[1]):lower()
        if sub == 'reset' then
            setLayoutEditing(false, { skipSave = true })
            TriggerServerEvent('bcc-corehud:layout:reset')
            return
        end
    end

    setLayoutEditing(not hudLayoutEditing)
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

RegisterNUICallback('setLayoutEditing', function(data, cb)
    local targetState = data and data.editing
    if type(targetState) == 'boolean' then
        local options = nil
        if data.skipSave == true then
            options = { skipSave = true }
        end

        setLayoutEditing(targetState, options)
    end

    if cb then
        cb('ok')
    end
end)

RegisterNUICallback('saveLayout', function(data, cb)
    local positions = data and data.positions
    if type(positions) ~= 'table' then
        if cb then
            cb('invalid')
        end
        return
    end

    TriggerServerEvent('bcc-corehud:layout:save', positions)
    sendLayoutToNui(positions)

    if cb then
        cb('ok')
    end
end)
