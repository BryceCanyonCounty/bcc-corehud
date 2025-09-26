local config = Config or {}
local updateInterval = config.UpdateInterval or 1000
local autoShowHud = config.AutoShowHud ~= false
local lowCoreThreshold = config.LowCoreWarning or 25.0
local debugEnabled = config.Debug == true
local saveToDatabase = config.SaveToDatabase ~= false
local saveInterval = config.SaveInterval or 15000
local horseDirtyThreshold = config.HorseDirtyThreshold or 4

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

local hudVisible = false
local lastPersistTick = 0
local lastPersistedSnapshot = nil

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

local function asPercent(value)
    if value == nil then
        return 0.0
    end

    if value <= 1.0 then
        return value * 100.0
    end

    return clamp(value, 0.0, 100.0)
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

    for _, entry in ipairs(OPTIONAL_PERSIST_NUMBERS) do
        local value = normalizeNumeric(snapshot[entry.key], entry.min, entry.max)
        if value ~= nil then
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
    if horseDirtyThreshold <= 0 then
        return false
    end

    local dirtRank = getHorseDirtRank(horse)
    return dirtRank >= horseDirtyThreshold
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

    local temperatureEffect = computeTemperatureEffect(getWorldTemperature())

    local temperatureInner = nil
    local temperatureOuter = nil
    local temperatureInsideEffect = nil
    local temperatureNextEffect = nil

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

    return {
        innerhealth = toCoreState(healthCore),
        outerhealth = toCoreMeter(getHealthPercent(ped)),
        innerstamina = toCoreState(staminaCore),
        outerstamina = toCoreMeter(getPlayerStaminaPercent()),
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
    Wait(500)
    if autoShowHud then
        setHudVisible(true)
    end

    while true do
        Wait(updateInterval)

        if hudVisible then
            pushHudSnapshot()
        end
    end
end)

RegisterCommand("togglehud", function()
    ToggleUI()
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
