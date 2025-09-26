Config = {}

-- Locale key used by locale.lua (must exist in Locales table)
Config.defaultlang = 'en'

-- Client HUD behaviour
Config.AutoShowHud = true       -- Set to false to require manual /togglehud on spawn
Config.UpdateInterval = 1000    -- Core refresh rate in milliseconds
Config.LowCoreWarning = 25.0    -- Trigger status effects when cores fall below this percent
Config.Debug = true            -- Enable verbose client logging when true
Config.HorseDirtyThreshold = 4  -- Attribute rank at/above which the horse shows the dirty icon (0-10)
Config.TemperatureColdThreshold = -3.0 -- World temperature (Celsius) at/below which cold icon appears
Config.TemperatureHotThreshold = 26.0  -- World temperature (Celsius) at/above which hot icon appears

-- Database persistence (requires oxmysql)
Config.SaveToDatabase = true    -- Disable if you do not want to store core snapshots server-side
Config.SaveInterval = 15000     -- Minimum delay between persisted snapshots per player (milliseconds)
Config.DatabaseTable = 'bcc_corehud' -- Table used to store the latest core snapshot per character
Config.AutoCreateTable = true   -- When true, the resource attempts to create the table automatically on startup
