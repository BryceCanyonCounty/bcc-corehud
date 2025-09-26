local VORPcore = exports.vorp_core:GetCore()

local function file_exists(path)
    local file = LoadResourceFile(GetCurrentResourceName(), path)
    return file ~= nil
end

local distEntry = 'ui/dist/index.html'

if not file_exists(distEntry) then
    print('^1[BCC-CoreHUD]^0 Missing built UI files (' .. distEntry .. ').')
    print('^3Run `yarn install` and `yarn build` inside the ui folder to generate the production build.^0')
end

local saveEnabled = Config.SaveToDatabase ~= false
local tableName = Config.DatabaseTable or 'bcc_corehud'
local persistQuery = nil

if type(tableName) ~= 'string' or tableName == '' or tableName:find('[^%w_]') then
    print('^1[BCC-CoreHUD]^0 Invalid Config.DatabaseTable value. Disabling database persistence.')
    saveEnabled = false
end

if saveEnabled then
    if type(MySQL) ~= 'table' or not MySQL.prepare or not MySQL.prepare.await then
        print('^1[BCC-CoreHUD]^0 MySQL library not found. Disabling database persistence for this resource.')
        saveEnabled = false
    end
end

if saveEnabled then
    persistQuery = string.format([[INSERT INTO `%s`
        (character_id, innerhealth, outerhealth, innerstamina, outerstamina, innerhorse_health, outerhorse_health, innerhorse_stamina, outerhorse_stamina, innerhorse_dirt, outerhorse_dirt, innertemperature, outertemperature, effect_health_inside, effect_stamina_inside, effect_horse_health_inside, effect_horse_stamina_inside, effect_horse_dirt_inside, effect_horse_dirt_next, effect_temperature_inside, effect_temperature_next, horse_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            innerhealth = VALUES(innerhealth),
            outerhealth = VALUES(outerhealth),
            innerstamina = VALUES(innerstamina),
            outerstamina = VALUES(outerstamina),
            innerhorse_health = VALUES(innerhorse_health),
            outerhorse_health = VALUES(outerhorse_health),
            innerhorse_stamina = VALUES(innerhorse_stamina),
            outerhorse_stamina = VALUES(outerhorse_stamina),
            innerhorse_dirt = VALUES(innerhorse_dirt),
            outerhorse_dirt = VALUES(outerhorse_dirt),
            innertemperature = VALUES(innertemperature),
            outertemperature = VALUES(outertemperature),
            effect_health_inside = VALUES(effect_health_inside),
            effect_stamina_inside = VALUES(effect_stamina_inside),
            effect_horse_health_inside = VALUES(effect_horse_health_inside),
            effect_horse_stamina_inside = VALUES(effect_horse_stamina_inside),
            effect_horse_dirt_inside = VALUES(effect_horse_dirt_inside),
            effect_horse_dirt_next = VALUES(effect_horse_dirt_next),
            effect_temperature_inside = VALUES(effect_temperature_inside),
            effect_temperature_next = VALUES(effect_temperature_next),
            horse_active = VALUES(horse_active)
    ]], tableName)

end

local function toBoundedNumber(value, minValue, maxValue, defaultValue)
    local number = tonumber(value)
    if number == nil then
        return defaultValue
    end
    if minValue ~= nil and number < minValue then
        number = minValue
    end
    if maxValue ~= nil and number > maxValue then
        number = maxValue
    end
    return number
end

local function toEffect(value)
    if type(value) == 'string' and value ~= '' then
        return value
    end
    return nil
end

RegisterNetEvent('bcc-corehud:saveCores', function(snapshot)
    if not saveEnabled or type(snapshot) ~= 'table' then
        return
    end

    local src = source
    local user = VORPcore and VORPcore.getUser(src)
    if not user or not user.getUsedCharacter then
        return
    end

    local character = user.getUsedCharacter
    if not character or not character.charIdentifier then
        return
    end

    local charId = tostring(character.charIdentifier)
    if not charId or charId == '' then
        return
    end

    local payload = {
        innerhealth = toBoundedNumber(snapshot.innerhealth, 0, 15, 0) or 0,
        outerhealth = toBoundedNumber(snapshot.outerhealth, 0, 99, 0) or 0,
        innerstamina = toBoundedNumber(snapshot.innerstamina, 0, 15, 0) or 0,
        outerstamina = toBoundedNumber(snapshot.outerstamina, 0, 99, 0) or 0,
        innerhorse_health = toBoundedNumber(snapshot.innerhorse_health, 0, 15, nil),
        outerhorse_health = toBoundedNumber(snapshot.outerhorse_health, 0, 99, nil),
        innerhorse_stamina = toBoundedNumber(snapshot.innerhorse_stamina, 0, 15, nil),
        outerhorse_stamina = toBoundedNumber(snapshot.outerhorse_stamina, 0, 99, nil),
        innerhorse_dirt = toBoundedNumber(snapshot.innerhorse_dirt, 0, 15, nil),
        outerhorse_dirt = toBoundedNumber(snapshot.outerhorse_dirt, 0, 99, nil),
        innertemperature = toBoundedNumber(snapshot.innertemperature, 0, 15, nil),
        outertemperature = toBoundedNumber(snapshot.outertemperature, 0, 99, nil),
        effect_health_inside = toEffect(snapshot.effect_health_inside),
        effect_stamina_inside = toEffect(snapshot.effect_stamina_inside),
        effect_horse_health_inside = toEffect(snapshot.effect_horse_health_inside),
        effect_horse_stamina_inside = toEffect(snapshot.effect_horse_stamina_inside),
        effect_horse_dirt_inside = toEffect(snapshot.effect_horse_dirt_inside),
        effect_horse_dirt_next = toEffect(snapshot.effect_horse_dirt_next),
        effect_temperature_inside = toEffect(snapshot.effect_temperature_inside),
        effect_temperature_next = toEffect(snapshot.effect_temperature_next),
        horse_active = snapshot.horse_active and 1 or 0
    }

    local params = {
        charId,
        payload.innerhealth,
        payload.outerhealth,
        payload.innerstamina,
        payload.outerstamina,
        payload.innerhorse_health,
        payload.outerhorse_health,
        payload.innerhorse_stamina,
        payload.outerhorse_stamina,
        payload.innerhorse_dirt,
        payload.outerhorse_dirt,
        payload.innertemperature,
        payload.outertemperature,
        payload.effect_health_inside,
        payload.effect_stamina_inside,
        payload.effect_horse_health_inside,
        payload.effect_horse_stamina_inside,
        payload.effect_horse_dirt_inside,
        payload.effect_horse_dirt_next,
        payload.effect_temperature_inside,
        payload.effect_temperature_next,
        payload.horse_active
    }

    local ok, err = pcall(MySQL.prepare.await, persistQuery, params)
    if not ok then
        print(string.format('^1[BCC-CoreHUD]^0 Failed to persist core snapshot for character %s: %s', charId, err or 'unknown error'))
    end
end)
