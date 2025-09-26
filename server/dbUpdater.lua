local saveEnabled = Config.SaveToDatabase ~= false
local autoCreate = Config.AutoCreateTable ~= false
local tableName = Config.DatabaseTable or 'bcc_corehud'

if saveEnabled and autoCreate then
    CreateThread(function()
        if type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then
            print('^1[BCC-CoreHUD]^0 MySQL library missing; database table will not be created automatically.')
            return
        end

        if type(tableName) ~= 'string' or tableName == '' or tableName:find('[^%w_]') then
            print('^1[BCC-CoreHUD]^0 Invalid Config.DatabaseTable value. Skipping auto creation.')
            return
        end

        local columns = [[
            `character_id` VARCHAR(64) NOT NULL,
            `innerhealth` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `outerhealth` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `innerstamina` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `outerstamina` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `innerhorse_health` TINYINT UNSIGNED DEFAULT NULL,
            `outerhorse_health` TINYINT UNSIGNED DEFAULT NULL,
            `innerhorse_stamina` TINYINT UNSIGNED DEFAULT NULL,
            `outerhorse_stamina` TINYINT UNSIGNED DEFAULT NULL,
            `innerhorse_dirt` TINYINT UNSIGNED DEFAULT NULL,
            `outerhorse_dirt` TINYINT UNSIGNED DEFAULT NULL,
            `innertemperature` TINYINT UNSIGNED DEFAULT NULL,
            `outertemperature` TINYINT UNSIGNED DEFAULT NULL,
            `effect_health_inside` VARCHAR(32) DEFAULT NULL,
            `effect_stamina_inside` VARCHAR(32) DEFAULT NULL,
            `effect_horse_health_inside` VARCHAR(32) DEFAULT NULL,
            `effect_horse_stamina_inside` VARCHAR(32) DEFAULT NULL,
            `effect_horse_dirt_inside` VARCHAR(32) DEFAULT NULL,
            `effect_horse_dirt_next` VARCHAR(32) DEFAULT NULL,
            `effect_temperature_inside` VARCHAR(32) DEFAULT NULL,
            `effect_temperature_next` VARCHAR(32) DEFAULT NULL,
            `horse_active` TINYINT(1) NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`character_id`)
        ]]

        local query = string.format([[CREATE TABLE IF NOT EXISTS `%s` (
            %s
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]], tableName, columns)

        local ok, err = pcall(function()
            MySQL.query.await(query)
        end)


        if ok then
            local alters = {
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `innerhorse_dirt` TINYINT UNSIGNED DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `outerhorse_dirt` TINYINT UNSIGNED DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `innertemperature` TINYINT UNSIGNED DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `outertemperature` TINYINT UNSIGNED DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `effect_horse_dirt_inside` VARCHAR(32) DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `effect_horse_dirt_next` VARCHAR(32) DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `effect_temperature_inside` VARCHAR(32) DEFAULT NULL', tableName),
                string.format('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `effect_temperature_next` VARCHAR(32) DEFAULT NULL', tableName)
            }

            for _, stmt in ipairs(alters) do
                MySQL.query.await(stmt)
            end

            print('^2[BCC-CoreHUD]^0 Database table `' .. tableName .. '` verified.')
        else
            print('^1[BCC-CoreHUD]^0 Failed to create table `' .. tableName .. '`:', err)
        end
    end)
elseif saveEnabled then
    print('^3[BCC-CoreHUD]^0 Config.AutoCreateTable disabled; skipping automatic database setup.')
end
