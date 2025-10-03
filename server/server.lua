local Config = Config or {}
BccUtils = exports['bcc-utils'].initiate()
local Core = nil
if exports and exports.vorp_core and exports.vorp_core.GetCore then
    Core = exports.vorp_core:GetCore()
end

local saveEnabled = true
local debugEnabled = Config.devMode == true
local tableName = 'bcc_corehud'

local defaultNeedValue = tonumber(Config.InitialNeedValue) or 100.0
if defaultNeedValue < 0.0 then defaultNeedValue = 0.0 end
if defaultNeedValue > 100.0 then defaultNeedValue = 100.0 end

local DEFAULT_LAYOUT = {
    money = { x = 92.624, y = 18.185 },
    gold = { x = 92.729, y = 20.573 },
    exp = { x = 92.574, y = 23.056 },
    tokens = { x = 93.406, y = 25.63 },
    player_id = { x = 91.584, y = 28.167 },
    health = { x = 11.469, y = 74.636 },
    stamina = { x = 8.969, y = 73.782 },
    hunger = { x = 4.437, y = 76.911 },
    thirst = { x = 6.521, y = 74.668 },
    stress = { x = 3.292, y = 93.444 },
    clean_stats = { x = 15.75, y = 89.0 },
    messages = { x = 14.865, y = 93.204 },
    voice = { x = 2.042, y = 84.748 },
    logo = { x = 1.771, y = 78.397 },
    temperature = { x = 2.833, y = 80.629 },
    temperature_value = { x = 2.146, y = 89.687 },
    horse_health = { x = 15.073, y = 80.37 },
    horse_stamina = { x = 13.563, y = 76.815 },
    horse_dirt = { x = 15.906, y = 84.556 }
}

local playerStates = {}
local characterSources = {}
local characterNeeds = {}
local pendingCharacterRequests = {}

local NUMERIC_FIELDS = {
    { key = 'innerhealth', min = 0, max = 15, default = 0, required = true },
    { key = 'outerhealth', min = 0, max = 99, default = 0, required = true },
    { key = 'innerstamina', min = 0, max = 15, default = 0, required = true },
    { key = 'outerstamina', min = 0, max = 99, default = 0, required = true },
    { key = 'outerhunger', min = 0, max = 99 },
    { key = 'outerthirst', min = 0, max = 99 },
    { key = 'outerstress', min = 0, max = 99 },
    { key = 'innerhorse_health', min = 0, max = 15 },
    { key = 'outerhorse_health', min = 0, max = 99 },
    { key = 'innerhorse_stamina', min = 0, max = 15 },
    { key = 'outerhorse_stamina', min = 0, max = 99 }
}

local STRING_FIELDS = {}

local NUMERIC_INDEX = {}
for _, entry in ipairs(NUMERIC_FIELDS) do
    NUMERIC_INDEX[entry.key] = entry
end

local STRING_INDEX = {}

local NEED_KEYS = { 'hunger', 'thirst', 'stress' }

local BALANCE_EVENT_MAP = {
    Money = { cacheKey = 'money', event = 'bcc-corehud:setMoney' },
    Gold  = { cacheKey = 'gold', event = 'bcc-corehud:setGold' },
    Rol   = { cacheKey = 'tokens', event = 'bcc-corehud:setTokens' },
    Xp    = { cacheKey = 'exp', event = 'bcc-corehud:setExp' }
}

local function debugPrint(...)
    if not debugEnabled then
        return
    end
    local args = { ... }
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    print('[BCC-CoreHUD][server]', table.concat(args, ' '))
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function toPercent(value)
    if value == nil then return nil end
    local number = tonumber(value)
    if not number then return nil end
    return clamp(number, 0.0, 100.0)
end

local function ensurePlayerState(src)
    local state = playerStates[src]
    if not state then
        state = { needs = {}, palette = nil, layout = nil, balances = {} }
        playerStates[src] = state
        return state
    end

    if not state.balances then
        state.balances = {}
    end
    return state
end

local function sourceFromStateBagName(bagName)
    if type(bagName) ~= 'string' then
        return nil
    end

    if GetPlayerFromStateBagName then
        local player = GetPlayerFromStateBagName(bagName)
        if player then
            local num = tonumber(player)
            if num then
                return num
            end
        end
    end

    local id = bagName:match('player:(%d+)')
    return id and tonumber(id) or nil
end

local function pushBalanceValue(src, meta, rawValue)
    local state = ensurePlayerState(src)
    local balances = state.balances
    local cacheKey = meta.cacheKey

    if rawValue == nil then
        if balances[cacheKey] ~= nil then
            balances[cacheKey] = nil
            TriggerClientEvent(meta.event, src, nil)
        end
        return
    end

    local amount = tonumber(rawValue)
    if not amount then
        return
    end

    if balances[cacheKey] == amount then
        return
    end

    balances[cacheKey] = amount
    TriggerClientEvent(meta.event, src, amount)
end

local function syncBalancesFromState(src, data)
    if type(data) ~= 'table' then
        return
    end

    for stateKey, meta in pairs(BALANCE_EVENT_MAP) do
        pushBalanceValue(src, meta, data[stateKey])
    end
end

local function resolveSource(characterId)
    characterId = characterId and tostring(characterId) or nil
    if not characterId then return nil end
    local src = characterSources[characterId]
    if src and GetPlayerName(src) then
        return src
    end
    characterSources[characterId] = nil
    return nil
end

local function getUser(src)
    if not Core or not Core.getUser then
        return nil
    end
    local ok, result = pcall(Core.getUser, src)
    if not ok then
        debugPrint('getUser failed', result)
        return nil
    end
    return result
end

local function getCharacterFromUser(user)
    if not user then
        return nil
    end
    local character = user.getUsedCharacter
    if type(character) == 'function' then
        local ok, value = pcall(character, user)
        if ok then
            character = value
        else
            character = nil
        end
    end
    return character
end

local function getCharacterId(src)
    if not src then return nil end
    local user = getUser(src)
    if not user then return nil end
    local character = getCharacterFromUser(user)
    if not character then return nil end
    local identifier = character.charIdentifier or character.charidentifier or character.identifier
    if identifier == nil and type(character.charid) ~= 'nil' then
        identifier = character.charid
    end
    if identifier == nil then
        return nil
    end
    return tostring(identifier)
end

local function withCharacterId(src, context, callback)
    if type(callback) ~= 'function' then
        return
    end

    local characterId = getCharacterId(src)
    if characterId then
        callback(characterId)
        return
    end

    if not GetPlayerName(src) then
        return
    end

    local entry = pendingCharacterRequests[src]
    if not entry then
        entry = { callbacks = {}, context = context, attempts = 0 }
        pendingCharacterRequests[src] = entry

        CreateThread(function()
            while entry.attempts < 80 do
                Wait(250)

                if not GetPlayerName(src) then
                    pendingCharacterRequests[src] = nil
                    return
                end

                local resolved = getCharacterId(src)
                if resolved then
                    pendingCharacterRequests[src] = nil
                    for _, cb in ipairs(entry.callbacks) do
                        local ok, err = pcall(cb, resolved)
                        if not ok then
                            print('^1[BCC-CoreHUD]^0 character callback error:', err)
                        end
                    end
                    return
                end

                entry.attempts = entry.attempts + 1
            end

            pendingCharacterRequests[src] = nil
            if debugEnabled then
                debugPrint('character resolution timed out', src, context or 'unknown')
            end
        end)
    end

    entry.callbacks[#entry.callbacks + 1] = callback
end

local function linkSourceToCharacter(src, characterId)
    if not characterId then return end
    ensurePlayerState(src).characterId = characterId
    characterSources[characterId] = src
end

local function parsePercentFromEffect(effect)
    if type(effect) ~= 'string' or effect == '' then
        return nil
    end
    local number = tonumber(effect:match('(-?%d+)'))
    if not number then
        return nil
    end
    return clamp(number, 0, 100)
end

local function decodeNeedPercent(snapshot, prefix)
    local effect = snapshot['effect_' .. prefix .. '_next']
    local fromEffect = parsePercentFromEffect(effect)
    if fromEffect then
        return fromEffect
    end

    local outerKey = 'outer' .. prefix
    local outerEntry = snapshot[outerKey]
    if outerEntry ~= nil then
        local outer = tonumber(outerEntry)
        if outer then
            return clamp(math.floor((outer / 99.0) * 100.0 + 0.5), 0, 100)
        end
    end

    local innerKey = 'inner' .. prefix
    local innerEntry = snapshot[innerKey]
    if innerEntry ~= nil then
        local inner = tonumber(innerEntry)
        if inner then
            return clamp(math.floor((inner / 15.0) * 100.0 + 0.5), 0, 100)
        end
    end

    return nil
end

local function updateNeedsFromSnapshot(characterId, snapshot)
    if not characterId or type(snapshot) ~= 'table' then
        return
    end

    local needs = characterNeeds[characterId]
    if not needs then
        needs = {}
        characterNeeds[characterId] = needs
    end

    for _, key in ipairs(NEED_KEYS) do
        local percent = decodeNeedPercent(snapshot, key)
        if percent then
            needs[key] = percent
        end
    end

    local src = resolveSource(characterId)
    if src then
        local state = ensurePlayerState(src)
        state.needs = state.needs or {}
        for k, v in pairs(needs) do
            state.needs[k] = v
        end
    end
end

local function sanitizeSnapshot(data)
    if type(data) ~= 'table' then
        return nil
    end

    local sanitized = {}

    for _, entry in ipairs(NUMERIC_FIELDS) do
        local value = data[entry.key]
        local number = tonumber(value)
        if number ~= nil then
            if entry.min and number < entry.min then number = entry.min end
            if entry.max and number > entry.max then number = entry.max end
            sanitized[entry.key] = math.floor(number + 0.5)
        elseif entry.required then
            sanitized[entry.key] = entry.default or 0
        else
            sanitized[entry.key] = nil
        end
    end

    for _, key in ipairs(STRING_FIELDS) do
        local value = data[key]
        if type(value) == 'string' and value ~= '' then
            if #value > 32 then
                value = value:sub(1, 32)
            end
            sanitized[key] = value
        else
            sanitized[key] = nil
        end
    end

    return sanitized
end

local function buildSnapshotQuery(columns)
    local insertColumns = { '`character_id`' }
    local placeholders = { '?' }
    local updates = {}

    for _, column in ipairs(columns) do
        insertColumns[#insertColumns + 1] = '`' .. column .. '`'
        placeholders[#placeholders + 1] = '?'
        updates[#updates + 1] = '`' .. column .. '`=VALUES(`' .. column .. '`)' 
    end

    local insertList = table.concat(insertColumns, ',')
    local placeholderList = table.concat(placeholders, ',')
    local updateList = table.concat(updates, ',')

    return 'INSERT INTO `' .. tableName .. '` (' .. insertList .. ') VALUES (' .. placeholderList .. ') ON DUPLICATE KEY UPDATE ' .. updateList
end

local SNAPSHOT_COLUMNS = {}
for _, entry in ipairs(NUMERIC_FIELDS) do
    SNAPSHOT_COLUMNS[#SNAPSHOT_COLUMNS + 1] = entry.key
end
for _, key in ipairs(STRING_FIELDS) do
    SNAPSHOT_COLUMNS[#SNAPSHOT_COLUMNS + 1] = key
end

local SNAPSHOT_QUERY = buildSnapshotQuery(SNAPSHOT_COLUMNS)

local function persistSnapshot(characterId, snapshot)
    if not saveEnabled then
        return true
    end

    if not MySQL or not MySQL.prepare then
        print('^1[BCC-CoreHUD]^0 oxmysql not loaded; skipping snapshot persistence')
        return false
    end

    local params = { characterId }

    for _, column in ipairs(SNAPSHOT_COLUMNS) do
        local value = snapshot[column]

        local numericMeta = NUMERIC_INDEX[column]
        if numericMeta then
            local number = tonumber(value)

            if number ~= nil then
                if numericMeta.min and number < numericMeta.min then
                    number = numericMeta.min
                end
                if numericMeta.max and number > numericMeta.max then
                    number = numericMeta.max
                end

                number = math.floor(number + 0.5)

                if numericMeta.min and number < numericMeta.min then
                    number = numericMeta.min
                end
                if numericMeta.max and number > numericMeta.max then
                    number = numericMeta.max
                end

                value = number
            elseif numericMeta.required then
                value = numericMeta.default or numericMeta.min or 0
            else
                value = nil
            end

            if value ~= nil and type(value) ~= 'number' then
                if debugEnabled then
                    debugPrint('Invalid numeric payload', column, tostring(value))
                end
                value = numericMeta.required and (numericMeta.default or numericMeta.min or 0) or nil
            end
        elseif STRING_INDEX[column] then
            if type(value) == 'string' and value ~= '' then
                if #value > 32 then
                    value = value:sub(1, 32)
                end
            else
                value = nil
            end
        end

        params[#params + 1] = value
    end

    local ok, err = pcall(function()
        MySQL.prepare.await(SNAPSHOT_QUERY, params)
    end)

    if not ok then
        if debugEnabled and json and json.encode then
            debugPrint('Snapshot params', json.encode(params))
        end
        print('^1[BCC-CoreHUD]^0 Failed to persist snapshot for character ' .. tostring(characterId) .. ': ' .. tostring(err))
        return false
    end

    return true
end

local function sanitizePalette(snapshot)
    if type(snapshot) ~= 'table' then
        return nil
    end

    local sanitized = {}
    for key, entry in pairs(snapshot) do
        if type(key) == 'string' and type(entry) == 'table' then
            local hue = tonumber(entry.hue)
            local saturation = tonumber(entry.saturation)
            if hue then
                hue = clamp(math.floor(hue + 0.5), 0, 360)
            else
                hue = 0
            end
            if saturation then
                saturation = clamp(math.floor(saturation + 0.5), 0, 100)
            else
                saturation = 0
            end
            sanitized[key] = { hue = hue, saturation = saturation }
        end
    end

    if not sanitized.default then
        sanitized.default = { hue = 0, saturation = 0 }
    end

    return sanitized
end

local function sanitizeLayout(layout)
    if type(layout) ~= 'table' then
        return nil
    end

    local sanitized = {}

    for key, value in pairs(layout) do
        if type(key) == 'string' and type(value) == 'table' then
            local x = tonumber(value.x)
            local y = tonumber(value.y)
            if x ~= nil and y ~= nil then
                x = clamp(x, 0, 100)
                y = clamp(y, 0, 100)

                sanitized[key] = {
                    x = math.floor(x * 1000 + 0.5) / 1000,
                    y = math.floor(y * 1000 + 0.5) / 1000
                }
            end
        end
    end

    if next(sanitized) == nil then
        return nil
    end

    return sanitized
end

local function cloneDefaultLayout()
    local copy = {}
    for key, value in pairs(DEFAULT_LAYOUT) do
        if type(value) == 'table' then
            copy[key] = { x = tonumber(value.x) or 0, y = tonumber(value.y) or 0 }
        end
    end
    return copy
end

local function decodeLayout(raw)
    if type(raw) ~= 'string' or raw == '' then
        return nil
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return nil
    end

    return sanitizeLayout(decoded)
end

local function persistPalette(characterId, palette)
    if not saveEnabled then
        return true
    end

    if not MySQL or not MySQL.prepare then
        print('^1[BCC-CoreHUD]^0 oxmysql not loaded; skipping palette persistence')
        return false
    end

    local encoded = json.encode(palette)
    local query = 'INSERT INTO `' .. tableName .. '` (`character_id`, `palette_json`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `palette_json` = VALUES(`palette_json`)' 

    local ok, err = pcall(function()
        MySQL.prepare.await(query, { characterId, encoded })
    end)

    if not ok then
        print('^1[BCC-CoreHUD]^0 Failed to persist palette for character ' .. tostring(characterId) .. ': ' .. tostring(err))
        return false
    end

    return true
end

local function persistLayout(characterId, layout)
    if not saveEnabled then
        return true
    end

    if not MySQL or not MySQL.prepare then
        print('^1[BCC-CoreHUD]^0 oxmysql not loaded; skipping layout persistence')
        return false
    end

    local encoded = layout and json.encode(layout) or nil
    local query = 'INSERT INTO `' .. tableName .. '` (`character_id`, `layout_json`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `layout_json` = VALUES(`layout_json`)' 

    local ok, err = pcall(function()
        MySQL.prepare.await(query, { characterId, encoded })
    end)

    if not ok then
        print('^1[BCC-CoreHUD]^0 Failed to persist layout for character ' .. tostring(characterId) .. ': ' .. tostring(err))
        return false
    end

    return true
end

local function loadCharacterRecord(characterId)
    if not saveEnabled then
        return nil
    end

    if not MySQL or not MySQL.query then
        return nil
    end

    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT * FROM `' .. tableName .. '` WHERE `character_id`=? LIMIT 1', { characterId })
    end)

    if not ok then
        print('^1[BCC-CoreHUD]^0 Failed to fetch snapshot for character ' .. tostring(characterId) .. ': ' .. tostring(rows))
        return nil
    end

    if not rows or not rows[1] then
        return nil
    end

    return rows[1]
end

local function pushNeedsToClient(src, needs)
    if not src or not needs then
        return
    end
    TriggerClientEvent('bcc-corehud:setNeeds', src, needs)
end

local function setCharacterNeed(characterId, stat, value)
    if not characterId then
        return nil
    end
    stat = stat and stat:lower() or nil
    local allowed = false
    for _, key in ipairs(NEED_KEYS) do
        if key == stat then
            allowed = true
            break
        end
    end
    if not allowed then
        return nil
    end

    local needs = characterNeeds[characterId]
    if not needs then
        needs = {}
        characterNeeds[characterId] = needs
    end

    if value == nil then
        needs[stat] = nil
        local src = resolveSource(characterId)
        if src then
            ensurePlayerState(src).needs[stat] = nil
            TriggerClientEvent('bcc-corehud:setNeed', src, stat, nil)
        end
        return nil
    end

    local clamped = clamp(math.floor((tonumber(value) or 0) + 0.5), 0, 100)
    needs[stat] = clamped

    local src = resolveSource(characterId)
    if src then
        ensurePlayerState(src).needs[stat] = clamped
        TriggerClientEvent('bcc-corehud:setNeed', src, stat, clamped)
    end

    return clamped
end

local function addCharacterNeed(characterId, stat, delta)
    local currentNeeds = characterNeeds[characterId]
    local current = (currentNeeds and currentNeeds[stat]) or defaultNeedValue
    return setCharacterNeed(characterId, stat, current + (tonumber(delta) or 0))
end

local function getCharacterNeeds(characterId)
    return characterNeeds[characterId]
end

local function getCharacterNeedsWithFallback(characterId)
    local needs = characterNeeds[characterId]
    return {
        hunger = needs and needs.hunger or defaultNeedValue,
        thirst = needs and needs.thirst or defaultNeedValue,
        stress = needs and needs.stress or defaultNeedValue
    }
end

local function handleSnapshotEvent(src, characterId, payload)
    if not characterId then
        return
    end
    linkSourceToCharacter(src, characterId)

    local sanitized = sanitizeSnapshot(payload)
    if not sanitized then
        debugPrint('snapshot payload invalid for', characterId)
        return
    end

    ensurePlayerState(src).snapshot = sanitized
    updateNeedsFromSnapshot(characterId, payload)

    if persistSnapshot(characterId, sanitized) then
        debugPrint('snapshot stored for', characterId)
    end
end

RegisterNetEvent('bcc-corehud:saveCores', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        return
    end
    withCharacterId(src, 'saveCores', function(characterId)
        if not GetPlayerName(src) then
            return
        end
        handleSnapshotEvent(src, characterId, payload)
    end)
end)

local function applyStoredPalette(src, characterId)
    local row = loadCharacterRecord(characterId)
    if not row then
        return
    end

    local state = ensurePlayerState(src)

    if row.palette_json then
        local ok, decoded = pcall(json.decode, row.palette_json)
        if ok and type(decoded) == 'table' then
            TriggerClientEvent('bcc-corehud:palette:apply', src, decoded)
            state.palette = decoded
        end
    end

    local layout = decodeLayout(row.layout_json)
    if not layout then
        layout = sanitizeLayout(cloneDefaultLayout())
        if layout then
            persistLayout(characterId, layout)
        end
    end
    state.layout = layout
    TriggerClientEvent('bcc-corehud:layout:apply', src, layout)

    local storedNeeds = getCharacterNeeds(characterId)
    local needs = {
        hunger = storedNeeds and storedNeeds.hunger or nil,
        thirst = storedNeeds and storedNeeds.thirst or nil,
        stress = storedNeeds and storedNeeds.stress or nil
    }

    for _, key in ipairs(NEED_KEYS) do
        if needs[key] == nil then
            needs[key] = decodeNeedPercent(row, key)
        end
        if needs[key] == nil then
            needs[key] = defaultNeedValue
        end
    end

    characterNeeds[characterId] = needs
    state.needs = needs
    pushNeedsToClient(src, needs)
end

RegisterNetEvent('bcc-corehud:palette:request', function()
    local src = source

    withCharacterId(src, 'palette:request', function(characterId)
        if not GetPlayerName(src) then
            return
        end

        linkSourceToCharacter(src, characterId)

        local state = ensurePlayerState(src)
        if state.palette then
            TriggerClientEvent('bcc-corehud:palette:apply', src, state.palette)
            TriggerClientEvent('bcc-corehud:layout:apply', src, state.layout)
            if state.needs and next(state.needs) then
                pushNeedsToClient(src, state.needs)
            end
            return
        end

        applyStoredPalette(src, characterId)
    end)
end)

RegisterNetEvent('bcc-corehud:palette:save', function(snapshot)
    local src = source

    withCharacterId(src, 'palette:save', function(characterId)
        if not GetPlayerName(src) then
            return
        end

        linkSourceToCharacter(src, characterId)

        local sanitized = sanitizePalette(snapshot)
        if not sanitized then
            debugPrint('palette save invalid payload for', characterId)
            return
        end

        ensurePlayerState(src).palette = sanitized
        TriggerClientEvent('bcc-corehud:palette:apply', src, sanitized)

        if persistPalette(characterId, sanitized) then
            debugPrint('palette stored for', characterId)
        end
    end)
end)

RegisterNetEvent('bcc-corehud:layout:request', function()
    local src = source

    withCharacterId(src, 'layout:request', function(characterId)
        if not GetPlayerName(src) then
            return
        end

        linkSourceToCharacter(src, characterId)

        local state = ensurePlayerState(src)
        if state.layout then
            TriggerClientEvent('bcc-corehud:layout:apply', src, state.layout)
            return
        end

        local layout = nil
        local row = loadCharacterRecord(characterId)
        if row then
            layout = decodeLayout(row.layout_json)
        end

        if not layout then
            layout = sanitizeLayout(cloneDefaultLayout())
            if layout then
                persistLayout(characterId, layout)
            end
        end

        state.layout = layout
        TriggerClientEvent('bcc-corehud:layout:apply', src, layout)
    end)
end)

RegisterNetEvent('bcc-corehud:layout:save', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        return
    end

    withCharacterId(src, 'layout:save', function(characterId)
        if not GetPlayerName(src) then
            return
        end

        linkSourceToCharacter(src, characterId)

        local sanitized = sanitizeLayout(payload)
        local state = ensurePlayerState(src)
        state.layout = sanitized

        TriggerClientEvent('bcc-corehud:layout:apply', src, sanitized)

        if persistLayout(characterId, sanitized) then
            debugPrint('layout stored for', characterId)
        end
    end)
end)

RegisterNetEvent('bcc-corehud:layout:reset', function()
    local src = source

    withCharacterId(src, 'layout:reset', function(characterId)
        if not GetPlayerName(src) then
            return
        end

        linkSourceToCharacter(src, characterId)

        local state = ensurePlayerState(src)
        state.layout = nil

        TriggerClientEvent('bcc-corehud:layout:apply', src, nil)

        if persistLayout(characterId, nil) then
            debugPrint('layout reset for', characterId)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local state = playerStates[src]
    if not state then
        return
    end
    if state.characterId then
        if characterSources[state.characterId] == src then
            characterSources[state.characterId] = nil
        end
    end
    playerStates[src] = nil
    pendingCharacterRequests[src] = nil
end)

local function resolveCharacterIdInput(target)
    if target == nil then
        return nil
    end

    if type(target) == 'number' then
        local src = target
        if GetPlayerName(src) then
            return getCharacterId(src)
        end
        return nil
    end

    return tostring(target)
end

exports('GetPlayerNeeds', function(target)
    local characterId = resolveCharacterIdInput(target)
    if not characterId then
        return nil
    end
    return getCharacterNeedsWithFallback(characterId)
end)

exports('GetPlayerNeed', function(target, stat)
    local characterId = resolveCharacterIdInput(target)
    if not characterId then
        return nil
    end
    stat = stat and stat:lower() or nil
    local needs = getCharacterNeeds(characterId)
    if not needs then
        return defaultNeedValue
    end
    local value = needs[stat]
    if value == nil then
        return defaultNeedValue
    end
    return value
end)

exports('SetPlayerNeed', function(target, stat, value)
    local characterId = resolveCharacterIdInput(target)
    if not characterId then
        return nil
    end
    return setCharacterNeed(characterId, stat, value)
end)

exports('AddPlayerNeed', function(target, stat, delta)
    local characterId = resolveCharacterIdInput(target)
    if not characterId then
        return nil
    end
    stat = stat and stat:lower() or nil
    return addCharacterNeed(characterId, stat, delta)
end)

local function applyNeedModifiers(src, modifiers)
    local characterId = getCharacterId(src)
    if not characterId then
        return
    end

    local updates = {}
    for _, key in ipairs(NEED_KEYS) do
        local amount = modifiers[key]
        if amount ~= nil then
            local value = addCharacterNeed(characterId, key, amount)
            updates[key] = value
        end
    end

    if next(updates) then
        pushNeedsToClient(src, updates)
    end
end

local function registerNeedItems()
    if not exports or not exports.vorp_inventory then
        print('^3[BCC-CoreHUD]^0 vorp_inventory export missing; skipping need item registration')
        return
    end

    local entries = Config.NeedItems or {}
    if type(entries) ~= 'table' then
        return
    end

    for _, entry in ipairs(entries) do
        local itemName = entry.item
        if type(itemName) == 'string' and itemName ~= '' then
            exports.vorp_inventory:registerUsableItem(itemName, function(data)
                local src = data.source
                exports.vorp_inventory:closeInventory(src)

                if entry.remove ~= false then
                    if data.item and data.item.id then
                        exports.vorp_inventory:subItemById(src, data.item.id)
                    else
                        exports.vorp_inventory:subItem(src, itemName, 1)
                    end
                end

                if entry.give and entry.give.item then
                    local giveCount = tonumber(entry.give.count) or 1
                    if giveCount > 0 then
                        exports.vorp_inventory:addItem(src, entry.give.item, giveCount)
                    end
                end

                applyNeedModifiers(src, entry)

                TriggerClientEvent('bcc-corehud:playConsumeAnim', src, {
                    prop = entry.prop,
                    animation = entry.animation or entry.anim,
                    duration = entry.duration
                })

                local staminaValue = tonumber(entry.stamina)
                if staminaValue and staminaValue > 0 then
                    if staminaValue > 100 then staminaValue = 100 end
                    TriggerClientEvent('bcc-corehud:setStaminaCore', src, staminaValue)
                end

                local healthValue = tonumber(entry.health or entry.healthCore)
                if healthValue and healthValue > 0 then
                    if healthValue > 100 then healthValue = 100 end
                    TriggerClientEvent('bcc-corehud:setHealthCore', src, healthValue)
                end

                local overpower = {}
                local function queueOverpower(attributeIndex, value)
                    local amount = tonumber(value)
                    if amount and amount ~= 0 then
                        if amount < 0 then amount = 0 end
                        if amount > 100 then amount = 100 end
                        overpower[#overpower + 1] = {
                            attribute = attributeIndex,
                            amount = amount,
                            enable = true
                        }
                    end
                end

                queueOverpower(0, entry.OuterCoreHealthGold)
                queueOverpower(0, entry.InnerCoreHealthGold)
                queueOverpower(1, entry.OuterCoreStaminaGold)
                queueOverpower(1, entry.InnerCoreStaminaGold)

                if #overpower > 0 then
                    TriggerClientEvent('bcc-corehud:applyAttributeOverpower', src, overpower)
                end
            end)
        end
    end
end

CreateThread(function()
    Wait(1000)
    registerNeedItems()
end)

-- Keep money/gold/xp/tokens in sync whenever VORP updates the Character state bag.
AddStateBagChangeHandler('Character', nil, function(bagName, key, value)
    local src = sourceFromStateBagName(bagName)
    if not src or not GetPlayerName(src) then
        return
    end

    if value == nil then
        for _, meta in pairs(BALANCE_EVENT_MAP) do
            pushBalanceValue(src, meta, nil)
        end
        return
    end

    syncBalancesFromState(src, value)
end)

local function toNum(v) v = tonumber(v); return (v and v == v) and v or 0 end

BccUtils.RPC:Register('bcc-corehud:getBalances', function(params, cb, src)
    local target = tonumber(params and params.targetId) or src
    if not target or not GetPlayerName(target) then
        cb({ ok = false, message = 'Target not online' })
        return
    end

    -- Optional: allow refreshing others only if caller has an ACE
    if target ~= src and not IsPlayerAceAllowed(src, 'bcc-corehud.refresh.others') then
        cb({ ok = false, message = 'Not allowed to inspect another player' })
        return
    end

    local user = getUser(target)
    if not user then
        cb({ ok = false, message = 'User not found' })
        return
    end

    local character = getCharacterFromUser(user)
    if not character then
        cb({ ok = false, message = 'Character not found' })
        return
    end

    local data = {
        money = toNum(character.money),
        gold  = toNum(character.gold),
        rol   = toNum(character.rol), -- we map this to HUD "tokens"
        xp    = toNum(character.xp),
        target = target
    }

    cb({ ok = true, data = data })
end)

-- Check for version updates
BccUtils.Versioner.checkFile(GetCurrentResourceName(), "https://github.com/BryceCanyonCounty/bcc-corehud")
