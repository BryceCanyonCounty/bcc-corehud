local defaultNeedValue = tonumber(Config.InitialNeedValue) or 100.0
if defaultNeedValue < 0.0 then defaultNeedValue = 0.0 end
if defaultNeedValue > 100.0 then defaultNeedValue = 100.0 end

local DEFAULT_LAYOUT = {
    health = { x = 5.375, y = 75.269 },
    gold = { x = 2.742, y = 55.625 },
    tokens = { x = 4.497, y = 64.751 },
    messages = { x = 15.593, y = 91.166 },
    horse_health = { x = 15.802, y = 82.5 },
    bleed = { x = 3.979, y = 95.722 },
    money = { x = 2.834, y = 58.794 },
    hunger = { x = 10.532, y = 73.746 },
    exp = { x = 1.781, y = 61.531 },
    temperature_value = { x = 2.146, y = 87.465 },
    player_id = { x = 2.421, y = 52.695 },
    horse_dirt = { x = 16.062, y = 86.962 },
    temperature = { x = 14.031, y = 95.185 },
    thirst = { x = 12.821, y = 75.3 },
    horse_stamina = { x = 14.552, y = 78.482 },
    stress = { x = 2.667, y = 91.762 },
    stamina = { x = 8.03, y = 73.767 },
    logo = { x = 2.761, y = 70.711 },
    voice = { x = 2.145, y = 82.804 },
    clean_stats = { x = 3.292, y = 78.537 },
}

local playerStates = {}
local characterSources = {}
local characterNeeds = {}
local pendingCharacterRequests = {}

local NUMERIC_FIELDS = {
    { key = 'innerhealth',        min = 0, max = 15, default = 0, required = true },
    { key = 'outerhealth',        min = 0, max = 99, default = 0, required = true },
    { key = 'innerstamina',       min = 0, max = 15, default = 0, required = true },
    { key = 'outerstamina',       min = 0, max = 99, default = 0, required = true },
    { key = 'outerhunger',        min = 0, max = 99 },
    { key = 'outerthirst',        min = 0, max = 99 },
    { key = 'outerstress',        min = 0, max = 99 },
    { key = 'innerhorse_health',  min = 0, max = 15 },
    { key = 'outerhorse_health',  min = 0, max = 99 },
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

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
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

    local cached = characterSources[characterId]
    if cached ~= nil then
        local numeric = tonumber(cached)
        if numeric and GetPlayerName(numeric) ~= nil then
            return numeric
        end
        characterSources[characterId] = nil
        if Config.devMode then
            devPrint(('[Mailbox] stale cached src for %s removed'):format(characterId))
        end
    end

    if type(VorpCore) == 'table' and type(VorpCore.getUser) == 'function' then
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local user = VorpCore.getUser(src)
                if user then
                    local character = user.getUsedCharacter
                    if character and tostring(character.charIdentifier) == characterId then
                        characterSources[characterId] = src
                        if Config.devMode then
                            devPrint(('[Mailbox] resolved %s -> src %s via VORP'):format(characterId, tostring(src)))
                        end
                        return src
                    end
                end
            end
        end
    end

    if Config.devMode then
        devPrint(('[Mailbox] resolveSource failed for %s'):format(characterId))
    end
    return nil
end

local function pushMailboxCount(characterId, count)
    local src = resolveSource(characterId)
    if not src then return end
    if Config.devMode then
        devPrint(('[Mailbox] pushing count=%s to src=%s (char=%s)'):format(tostring(count), tostring(src),
        tostring(characterId)))
    end
    TriggerClientEvent('bcc-corehud:setMailboxCount', src, count)
end

local function toNonEmptyString(value)
    if value == nil then return nil end
    local str = tostring(value)
    if str == '' then return nil end
    return str
end

local function refreshMailboxCore(characterId)
    if not Config.EnableMailboxCore then return end
    if not characterId then return end

    local charIdStr = toNonEmptyString(characterId)
    if not charIdStr then return end

    local mailbox = MySQL.single.await(
        'SELECT mailbox_id, postal_code FROM bcc_mailboxes WHERE char_identifier = ? LIMIT 1',
        { charIdStr }
    )
    if not mailbox then
        pushMailboxCount(characterId, 0)
        return
    end

    local mailboxIdStr = toNonEmptyString(mailbox.mailbox_id)
    if not mailboxIdStr then
        pushMailboxCount(characterId, 0)
        return
    end

    local postalCodeStr = toNonEmptyString(mailbox.postal_code) or ''

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bcc_mailbox_messages WHERE is_read = 0 AND (to_char = ? OR to_char = ? OR to_char = ?)',
        { mailboxIdStr, postalCodeStr, charIdStr }
    ) or 0

    if Config.devMode then
        devPrint(('[Mailbox] char=%s mailbox=%s postal=%s count=%s'):format(
            tostring(characterId), tostring(mailboxIdStr), tostring(postalCodeStr), tostring(count)
        ))
    end

    pushMailboxCount(characterId, count)
end

RegisterNetEvent('bcc-corehud:server:refreshMailbox', function(characterId)
    if source ~= 0 then
        return
    end
    refreshMailboxCore(characterId)
end)

exports('RefreshMailboxCore', function(characterId)
    refreshMailboxCore(characterId)
end)

local function clearSourceState(src)
    if not src then
        return
    end

    pendingCharacterRequests[src] = nil

    local state = playerStates[src]
    if not state then
        return
    end

    local characterId = state.characterId
    if characterId and characterSources[characterId] == src then
        characterSources[characterId] = nil
    end

    playerStates[src] = nil
end

CreateThread(function()
    while true do
        local interval = math.max(1000, tonumber(Config.MailboxUpdateInterval) or 30000)
        Wait(interval)

        if Config.EnableMailboxCore then
            for characterId in pairs(characterSources) do
                refreshMailboxCore(characterId)
            end
        end
    end
end)

local function linkSourceToCharacter(src, characterId)
    characterId = characterId and tostring(characterId) or nil
    if not characterId then
        devPrint("Missing characterId for src:", src)
        return
    end

    devPrint(("Linking src=%s to characterId=%s"):format(tostring(src), tostring(characterId)))

    local state = ensurePlayerState(src)
    local previousCharacter = state.characterId and tostring(state.characterId) or nil
    local changedCharacter = previousCharacter ~= characterId

    if previousCharacter and previousCharacter ~= characterId then
        if characterSources[previousCharacter] == src then
            devPrint(("Removing old mapping: characterSources[%s] = %s"):format(tostring(previousCharacter),
                tostring(src)))
            characterSources[previousCharacter] = nil
        else
            devPrint("No old mapping found for previous character")
        end

        -- wipe cached state when the player switches characters
        devPrint("Clearing cached state for src:", src)
        state.palette = nil
        state.layout = nil
        state.needs = {}
        state.snapshot = nil
        state.balances = {}
    end

    -- store the new mapping
    state.characterId = characterId
    characterSources[characterId] = src

    if changedCharacter then
        refreshMailboxCore(characterId)
    end

    --devPrint(("[linkSourceToCharacter] ✅ Linked src=%s <-> characterId=%s"):format(tostring(src), tostring(characterId)))
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
        devPrint("[sanitizeSnapshot] ❌ Invalid snapshot payload type:", type(data))
        return nil
    end

    local sanitized = {}

    for _, entry in ipairs(NUMERIC_FIELDS) do
        local key = entry.key
        local value = data[key]
        local number = tonumber(value)

        if number ~= nil then
            local original = number
            if entry.min and number < entry.min then
                --devPrint(("[sanitizeSnapshot] ⚠️ '%s' below min (%s < %s) → clamped"):format(key, tostring(number), tostring(entry.min)))
                number = entry.min
            end
            if entry.max and number > entry.max then
                --devPrint(("[sanitizeSnapshot] ⚠️ '%s' above max (%s > %s) → clamped"):format(key, tostring(number), tostring(entry.max)))
                number = entry.max
            end
            sanitized[key] = math.floor(number + 0.5)
            --devPrint(("[sanitizeSnapshot] ✅ Numeric key '%s' = %s (raw=%s)"):format(key, sanitized[key], tostring(original)))
        elseif entry.required then
            sanitized[key] = entry.default or 0
            --devPrint(("[sanitizeSnapshot] ℹ️ Missing required key '%s' → defaulted to %s"):format(key, tostring(sanitized[key])))
        else
            sanitized[key] = nil
            --devPrint(("[sanitizeSnapshot] ⏩ Optional key '%s' not provided / invalid"):format(key))
        end
    end

    for _, key in ipairs(STRING_FIELDS) do
        local value = data[key]
        if type(value) == 'string' and value ~= '' then
            if #value > 32 then
                --devPrint(("[sanitizeSnapshot] ⚠️ String key '%s' too long (%d chars) → truncated"):format(key, #value))
                value = value:sub(1, 32)
            end
            sanitized[key] = value
            --devPrint(("[sanitizeSnapshot] ✅ String key '%s' = '%s'"):format(key, value))
        else
            sanitized[key] = nil
            --devPrint(("[sanitizeSnapshot] ⏩ String key '%s' missing or empty"):format(key))
        end
    end

    --devPrint("[sanitizeSnapshot]Sanitization complete, total keys:", tostring(#(NUMERIC_FIELDS) + #(STRING_FIELDS)))
    return sanitized
end

local SNAPSHOT_COLUMNS = {}
for _, entry in ipairs(NUMERIC_FIELDS) do
    SNAPSHOT_COLUMNS[#SNAPSHOT_COLUMNS + 1] = entry.key
end
for _, key in ipairs(STRING_FIELDS) do
    SNAPSHOT_COLUMNS[#SNAPSHOT_COLUMNS + 1] = key
end

function PersistSnapshot(characterId, snapshot)
    local insertColumns = "`character_id`"
    local placeholders  = "?"
    local updates       = "`character_id` = VALUES(`character_id`)"

    for _, column in ipairs(SNAPSHOT_COLUMNS) do
        insertColumns = insertColumns .. ", `" .. column .. "`"
        placeholders  = placeholders .. ", ?"
        updates       = updates .. ", `" .. column .. "` = VALUES(`" .. column .. "`)"
    end

    -- Params
    local params = { characterId }

    for _, column in ipairs(SNAPSHOT_COLUMNS) do
        local value = snapshot[column]
        local numericMeta = NUMERIC_INDEX[column]

        if numericMeta then
            local number = tonumber(value)
            if number ~= nil then
                if numericMeta.min and number < numericMeta.min then number = numericMeta.min end
                if numericMeta.max and number > numericMeta.max then number = numericMeta.max end
                number = math.floor(number + 0.5)
                if numericMeta.min and number < numericMeta.min then number = numericMeta.min end
                if numericMeta.max and number > numericMeta.max then number = numericMeta.max end
                value = number
            elseif numericMeta.required then
                value = numericMeta.default or numericMeta.min or 0
            else
                value = nil
            end

            if value ~= nil and type(value) ~= "number" then
                devPrint("Invalid numeric payload", column, tostring(value))
                value = numericMeta.required and (numericMeta.default or numericMeta.min or 0) or nil
            end
        elseif STRING_INDEX[column] then
            if type(value) == "string" and value ~= "" then
                if #value > 32 then value = value:sub(1, 32) end
            else
                value = nil
            end
        end

        params[#params + 1] = value
    end

    -- Inline query string inside MySQL call
    MySQL.query.await(
        "INSERT INTO `bcc_corehud` (" ..
        insertColumns .. ") VALUES (" .. placeholders .. ") ON DUPLICATE KEY UPDATE " .. updates,
        params
    )

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

BccUtils.RPC:Register('bcc-corehud:saveCores', function(params, cb, src)
    local payload = params and params.payload

    if type(payload) ~= 'table' then
        cb(false)
        devPrint('[bcc-corehud:saveCores] bad_payload')
        return
    end

    local user = VorpCore.getUser(src)
    if not user then
        cb(false)
        devPrint('[bcc-corehud:saveCores] no_user')
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        cb(false)
        devPrint('[bcc-corehud:saveCores] no_character')
        return
    end

    local characterId = character.charIdentifier
    if not characterId or characterId == "" then
        cb(false)
        devPrint("Missing or empty characterId, aborting snapshot handling")
        return
    end

    if not payload or type(payload) ~= "table" then
        cb(false)
        devPrint("Invalid or missing payload (type: " .. tostring(type(payload)) .. ")")
        return
    end

    linkSourceToCharacter(src, characterId)

    local sanitized = sanitizeSnapshot(payload)
    if not sanitized then
        cb(false)
        devPrint(("Snapshot payload invalid for characterId=%s"):format(tostring(characterId)))
        return
    end

    local numKeys = 0
    for _ in pairs(sanitized) do numKeys = numKeys + 1 end

    ensurePlayerState(src).snapshot = sanitized
    updateNeedsFromSnapshot(characterId, payload)

    devPrint("Persisting snapshot to database...")
    if PersistSnapshot(characterId, sanitized) then
        devPrint(("Snapshot stored successfully for characterId=%s"):format(tostring(characterId)))
    else
        devPrint(("Snapshot persistence failed for characterId=%s"):format(tostring(characterId)))
    end

    cb(true)
end)

local function applyStoredPalette(src, characterId)
    local row = LoadCharacterRecord(characterId)
    if not row then
        return
    end

    local state = ensurePlayerState(src)

    if row.palette_json then
        local ok, decoded = pcall(json.decode, row.palette_json)
        if ok and type(decoded) == 'table' then
            BccUtils.RPC:Notify('bcc-corehud:palette:apply', { snapshot = decoded }, src)
            state.palette = decoded
        end
    end

    local layout = decodeLayout(row.layout_json)
    if not layout then
        layout = sanitizeLayout(cloneDefaultLayout())
        if layout then
            PersistLayout(characterId, layout)
        end
    end
    state.layout = layout
    BccUtils.RPC:Notify('bcc-corehud:layout:apply', { layout = state.layout }, src)
    BccUtils.RPC:Notify('bcc-corehud:layout:apply', { layout = layout }, src)
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

BccUtils.RPC:Register('bcc-corehud:palette:request', function(params, cb, src)
    local user = VorpCore.getUser(src)
    if not user then
        devPrint('[palette:request] no_user', src)
        cb(false)
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        devPrint('[palette:request] no_character', src)
        cb(false)
        return
    end

    local characterId = character.charIdentifier
    linkSourceToCharacter(src, characterId)

    local state = ensurePlayerState(src)
    if state.palette then
        BccUtils.RPC:Notify('bcc-corehud:palette:apply', { snapshot = state.palette }, src)
        BccUtils.RPC:Notify('bcc-corehud:layout:apply', { layout = state.layout }, src)
        if state.needs and next(state.needs) then
            pushNeedsToClient(src, state.needs)
        end

        cb(true)
        return
    end

    applyStoredPalette(src, characterId)
    cb(true)
end)

BccUtils.RPC:Register('bcc-corehud:palette:save', function(params, cb, src)
    local snapshot = params and params.snapshot

    if type(snapshot) ~= 'table' then
        cb(false)
        devPrint('[palette:save] bad_payload')
        return
    end

    local user = VorpCore.getUser(src)
    if not user then
        cb(false)
        devPrint('[palette:save] no_user')
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        cb(false)
        devPrint('[palette:save] no_character')
        return
    end

    local characterId = character.charIdentifier
    linkSourceToCharacter(src, characterId)

    local sanitized = sanitizePalette(snapshot)
    if not sanitized then
        cb(false)
        devPrint('[palette:save] invalid_payload')
        return
    end

    ensurePlayerState(src).palette = sanitized
    BccUtils.RPC:Notify('bcc-corehud:palette:apply', { snapshot = sanitized }, src)

    if PersistPalette(characterId, sanitized) then
        devPrint('[palette:save] stored for', characterId)
    end

    cb(true)
end)

BccUtils.RPC:Register('bcc-corehud:layout:request', function(params, cb, src)
    local user = VorpCore.getUser(src)
    if not user then
        devPrint('[layout:request] no_user', src)
        cb(false)
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        devPrint('[layout:request] no_character', src)
        cb(false)
        return
    end

    local characterId = character.charIdentifier
    linkSourceToCharacter(src, characterId)

    local state = ensurePlayerState(src)
    if state.layout then
        BccUtils.RPC:Notify('bcc-corehud:layout:apply', { layout = state.layout }, src)
        cb(true)
        return
    end

    local layout
    local row = LoadCharacterRecord(characterId)
    if row then
        layout = decodeLayout(row.layout_json)
    end

    if not layout then
        layout = sanitizeLayout(cloneDefaultLayout())
        if layout then
            PersistLayout(characterId, layout)
        end
    end

    state.layout = layout
    BccUtils.RPC:Notify('bcc-corehud:layout:apply', { layout = layout }, src)
    cb(true)
end)

-- Save layout RPC
BccUtils.RPC:Register('bcc-corehud:layout:save', function(params, cb, src)
    local payload = params and params.layout
    if type(payload) ~= 'table' then
        cb(false)
        devPrint('[layout:save] bad_payload', src)
        return
    end

    local user = VorpCore.getUser(src)
    if not user then
        cb(false)
        devPrint('[layout:save] no_user', src)
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        cb(false)
        devPrint('[layout:save] no_character', src)
        return
    end

    local characterId = character.charIdentifier
    linkSourceToCharacter(src, characterId)

    local sanitized = sanitizeLayout(payload)
    local state = ensurePlayerState(src)
    state.layout = sanitized

    BccUtils.RPC:Notify('bcc-corehud:layout:apply', { layout = sanitized }, src)
    if PersistLayout(characterId, sanitized) then
        devPrint('[layout:save] layout stored for', characterId)
    end

    cb(true)
end)

BccUtils.RPC:Register('bcc-corehud:layout:reset', function(params, cb, src)
    local user = VorpCore.getUser(src)
    if not user then
        cb(false)
        devPrint('[layout:reset] no_user', src)
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        cb(false)
        devPrint('[layout:reset] no_character', src)
        return
    end

    local characterId = character.charIdentifier
    linkSourceToCharacter(src, characterId)

    local state = ensurePlayerState(src)
    state.layout = nil
    BccUtils.RPC:Notify('bcc-corehud:layout:apply', {}, src)

    if PersistLayout(characterId, nil) then
        devPrint('[layout:reset] layout reset for', characterId)
    end

    cb(true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    clearSourceState(src)
end)

RegisterNetEvent('bcc-corehud:clientStopped', function()
    clearSourceState(source)
end)

-- GetPlayerNeeds
exports('GetPlayerNeeds', function(target)
    if target == nil then return nil end

    local characterId
    if type(target) == 'number' then
        local src = target

        local user = VorpCore.getUser(src)
        if not user then return nil end

        local character = user.getUsedCharacter
        if not character then return nil end

        local identifier = character.charIdentifier
        if identifier == nil and type(character.charid) ~= 'nil' then
            identifier = character.charid
        end
        if identifier == nil then return nil end

        characterId = tostring(identifier)
    else
        characterId = tostring(target)
    end

    return getCharacterNeedsWithFallback(characterId)
end)

-- GetPlayerNeed
exports('GetPlayerNeed', function(target, stat)
    if target == nil then return nil end

    local characterId
    if type(target) == 'number' then
        local src = target

        local user = VorpCore.getUser(src)
        if not user then return nil end

        local character = user.getUsedCharacter
        if not character then return nil end

        local identifier = character.charIdentifier
        if identifier == nil and type(character.charid) ~= 'nil' then
            identifier = character.charid
        end
        if identifier == nil then return nil end

        characterId = tostring(identifier)
    else
        characterId = tostring(target)
    end

    stat = stat and stat:lower() or nil
    local needs = getCharacterNeeds(characterId)
    if not needs then return defaultNeedValue end

    local value = needs[stat]
    if value == nil then return defaultNeedValue end
    return value
end)

-- SetPlayerNeed
exports('SetPlayerNeed', function(target, stat, value)
    if target == nil then return nil end

    local characterId
    if type(target) == 'number' then
        local src = target

        local user = VorpCore.getUser(src)
        if not user then return nil end

        local character = user.getUsedCharacter
        if not character then return nil end

        local identifier = character.charIdentifier
        if identifier == nil and type(character.charid) ~= 'nil' then
            identifier = character.charid
        end
        if identifier == nil then return nil end

        characterId = tostring(identifier)
    else
        characterId = tostring(target)
    end

    return setCharacterNeed(characterId, stat, value)
end)

-- AddPlayerNeed
exports('AddPlayerNeed', function(target, stat, delta)
    if target == nil then return nil end

    local characterId
    if type(target) == 'number' then
        local src = target

        local user = VorpCore.getUser(src)
        if not user then return nil end

        local character = user.getUsedCharacter
        if not character then return nil end

        local identifier = character.charIdentifier
        if identifier == nil and type(character.charid) ~= 'nil' then
            identifier = character.charid
        end
        if identifier == nil then return nil end

        characterId = tostring(identifier)
    else
        characterId = tostring(target)
    end

    stat = stat and stat:lower() or nil
    return addCharacterNeed(characterId, stat, delta)
end)

local function applyNeedModifiers(src, modifiers)
    local user = VorpCore.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter
    if not character then return nil end
    local characterId = character.charIdentifier
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
        devPrint('^3[BCC-CoreHUD]^0 vorp_inventory export missing; skipping need item registration')
        return
    end

    local entries = Config.NeedItems or {}
    if type(entries) ~= 'table' then
        return
    end

    local resourceName = GetCurrentResourceName()

    for _, entry in ipairs(entries) do
        local itemName = entry.item
        if type(itemName) == 'string' and itemName ~= '' then
            local entryConfig = entry
            local function handleNeedItem(data)
                local src = data.source
                exports.vorp_inventory:closeInventory(src)

                if entryConfig.remove ~= false then
                    if data.item and data.item.id then
                        exports.vorp_inventory:subItemById(src, data.item.id)
                    else
                        exports.vorp_inventory:subItem(src, itemName, 1)
                    end
                end

                if entryConfig.give and entryConfig.give.item then
                    local giveCount = tonumber(entryConfig.give.count) or 1
                    if giveCount > 0 then
                        exports.vorp_inventory:addItem(src, entryConfig.give.item, giveCount)
                    end
                end

                applyNeedModifiers(src, entryConfig)

                TriggerClientEvent('bcc-corehud:playConsumeAnim', src, {
                    prop = entryConfig.prop,
                    animation = entryConfig.animation or entryConfig.anim,
                    duration = entryConfig.duration
                })

                local staminaValue = tonumber(entryConfig.stamina)
                if staminaValue and staminaValue > 0 then
                    if staminaValue > 100 then staminaValue = 100 end
                    TriggerClientEvent('bcc-corehud:setStaminaCore', src, staminaValue)
                end

                local healthValue = tonumber(entryConfig.health or entryConfig.healthCore)
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

                queueOverpower(0, entryConfig.OuterCoreHealthGold)
                queueOverpower(0, entryConfig.InnerCoreHealthGold)
                queueOverpower(1, entryConfig.OuterCoreStaminaGold)
                queueOverpower(1, entryConfig.InnerCoreStaminaGold)

                if #overpower > 0 then
                    TriggerClientEvent('bcc-corehud:applyAttributeOverpower', src, overpower)
                end
            end

            local ok, err = pcall(function()
                exports.vorp_inventory:registerUsableItem(itemName, handleNeedItem, resourceName)
            end)

            if not ok then
                local message = ('[BCC-CoreHUD] Failed to register need item "%s": %s'):format(
                    tostring(itemName), tostring(err)
                )
                if devPrint then
                    devPrint(message)
                else
                    print('^1' .. message .. '^0')
                end
            end
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
    if not src then
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

local function toNum(v)
    v = tonumber(v); return (v and v == v) and v or 0
end

BccUtils.RPC:Register('bcc-corehud:getBalances', function(params, cb, src)
    local target = tonumber(params and params.targetId) or src
    if not target then
        cb({ ok = false, message = 'Target not online' })
        return
    end

    -- Optional: allow refreshing others only if caller has an ACE
    if target ~= src and not IsPlayerAceAllowed(src, 'bcc-corehud.refresh.others') then
        cb({ ok = false, message = 'Not allowed to inspect another player' })
        return
    end

    local user = VorpCore.getUser(target)
    if not user then
        cb({ ok = false, message = 'User not found' })
        return
    end

    local character = user.getUsedCharacter
    if not character then
        cb({ ok = false, message = 'Character not found' })
        return
    end

    local data = {
        money  = toNum(character.money),
        gold   = toNum(character.gold),
        rol    = toNum(character.rol),
        xp     = toNum(character.xp),
        target = target
    }

    cb({ ok = true, data = data })
end)

BccUtils.RPC:Register('bcc-corehud:bleed:request', function(params, cb, src)
    if Config.EnableBleedCore ~= true then
        if devPrint then devPrint('[bleed:request] disabled', src) end
        cb({ ok = false, reason = 'disabled' })
        return
    end
    if type(Config.BleedCore) == 'table' and Config.BleedCore.UseBccMedical == false then
        if devPrint then devPrint('[bleed:request] integration_disabled', src) end
        cb({ ok = false, reason = 'integration_disabled' })
        return
    end

    local user = VorpCore.getUser(src)
    if not user then
        if devPrint then devPrint('[bleed:request] no_user', src) end
        cb({ ok = false, reason = 'no_user' })
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        if devPrint then devPrint('[bleed:request] no_character', src) end
        cb({ ok = false, reason = 'no_character' })
        return
    end

    local stage = FetchCharacterBleedStage(character.charIdentifier, character.identifier) or 0
    local state = ensurePlayerState(src)
    state.bleedStage = stage

    cb({ ok = true, bleed = stage, stage = stage })
end)

-- Check for version updates
BccUtils.Versioner.checkFile(GetCurrentResourceName(), "https://github.com/BryceCanyonCounty/bcc-corehud")
