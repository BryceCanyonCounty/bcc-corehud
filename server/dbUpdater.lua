-- bcc-corehud: database bootstrap (always create table if missing)

CreateThread(function()
    if type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then
        print('^1[BCC-CoreHUD]^0 MySQL library missing; database table will not be created automatically.')
        return
    end

    -- Create the bcc_corehud table if it doesn't exist
    local tableName = 'bcc_corehud'

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `character_id` VARCHAR(64) NOT NULL,
            `innerhealth` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `outerhealth` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `innerstamina` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `outerstamina` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `outerhunger` TINYINT UNSIGNED DEFAULT NULL,
            `outerthirst` TINYINT UNSIGNED DEFAULT NULL,
            `outerstress` TINYINT UNSIGNED DEFAULT NULL,
            `innerhorse_health` TINYINT UNSIGNED DEFAULT NULL,
            `outerhorse_health` TINYINT UNSIGNED DEFAULT NULL,
            `innerhorse_stamina` TINYINT UNSIGNED DEFAULT NULL,
            `outerhorse_stamina` TINYINT UNSIGNED DEFAULT NULL,
            `palette_json` LONGTEXT NULL,
            `layout_json` LONGTEXT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`character_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]]):format(tableName))

    print(string.format(
        "Database table for \27[35m\27[1m*bcc-corehud*\27[0m (%s) created or verified \27[32msuccessfully\27[0m.",
        tableName
    ))
end)
