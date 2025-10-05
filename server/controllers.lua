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
