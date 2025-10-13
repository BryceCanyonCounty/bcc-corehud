function LoadCharacterRecord(characterId)
    local result = MySQL.query.await(
        'SELECT * FROM `bcc_corehud` WHERE `character_id` = ? LIMIT 1',
        { characterId }
    )
    return result and result[1] or nil
end

function PersistPalette(characterId, palette)
    local result = MySQL.prepare.await(
        'INSERT INTO `bcc_corehud` (`character_id`, `palette_json`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `palette_json` = VALUES(`palette_json`)',
        { characterId, json.encode(palette) }
    )

    return result and true or false
end

function PersistLayout(characterId, layout)
    local result = MySQL.prepare.await(
        'INSERT INTO `bcc_corehud` (`character_id`, `layout_json`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `layout_json` = VALUES(`layout_json`)',
        { characterId, json.encode(layout or {}) }
    )

    return result and true or false
end

function FetchCharacterBleedStage(charId, identifier)
    if not charId or not identifier then
        return nil
    end

    local rows = MySQL.query.await(
        'SELECT `bleed` FROM `characters` WHERE `charidentifier` = ? AND `identifier` = ? LIMIT 1',
        { charId, identifier }
    )

    if not rows or not rows[1] then
        return nil
    end

    local raw = rows[1].bleed
    if raw == nil then
        return nil
    end

    local stage = tonumber(raw)
    if not stage or stage ~= stage then
        return nil
    end

    stage = math.floor(stage + 0.5)
    if stage < 0 then stage = 0 end
    if stage > 2 then stage = 2 end

    return stage
end
