Config = {}

-- Locale key used by locale.lua (must exist in Locales table)
Config.defaultlang = 'en'

-- Client HUD behaviour
Config.AutoShowHud = false       -- Set to false to require manual /togglehud on spawn
Config.UpdateInterval = 1000    -- Core refresh rate in milliseconds
Config.LowCoreWarning = 25.0    -- Trigger status effects when cores fall below this percent
Config.Debug = true            -- Enable verbose client logging when true
Config.HorseDirtyThreshold = 4  -- Attribute rank at/below which the horse shows the dirty icon (0-10, set false to disable)
Config.TemperatureColdThreshold = -3.0 -- World temperature (Celsius) at/below which cold icon appears
Config.TemperatureHotThreshold = 26.0  -- World temperature (Celsius) at/above which hot icon appears
Config.TemperatureMin = -15.0   -- Minimum world temperature mapped to the core (Celsius)
Config.TemperatureMax = 40.0    -- Maximum world temperature mapped to the core (Celsius)
Config.AlwaysShowTemperature = true -- When true the temperature core is shown even without hot/cold effects

Config.NeedsResourceName = false -- Resource providing a GetNeedsData export (false/nil skips polling)
Config.HungerWarningEffect = 'starving' -- Label shown when hunger drops below LowCoreWarning
Config.ThirstWarningEffect = 'parched' -- Label shown when thirst drops below LowCoreWarning
Config.StressWarningEffect = 'stressed' -- Label shown when stress falls below LowCoreWarning
Config.NeedsAutoDecay = true -- When true and no external needs resource is configured, hunger/thirst decay over time

Config.NeedsDecayStartDelay = 300.0 -- Seconds to wait before decay begins after a refill (5 minutes)
Config.HungerDecayDuration = 1800.0 -- Seconds for hunger to drain from full to empty once decay starts (30 minutes)
Config.ThirstDecayDuration = 1200.0 -- Seconds for thirst to drain from full to empty once decay starts (20 minutes)
Config.InitialNeedValue = 100.0 -- Default hunger/thirst value applied on spawn when using local decay
Config.HotThirstMultiplier = 2.0 -- Multiplier applied to thirst decay when the player is overheating (set to 1.0 to disable)
Config.HotThirstBypassDelay = true -- When true, the thirst decay delay is removed while overheating
Config.CrossNeedDecayMultiplier = 1.5 -- When one core is empty, the other decays faster by this multiplier
Config.StarvationDamageDelay = 120.0 -- Seconds both hunger and thirst must be empty before health damage starts (set 0 to disable)
Config.StarvationDamageInterval = 10.0 -- Seconds between health damage ticks once starvation damage begins
Config.StarvationDamageAmount = 4.0 -- Health removed each tick when starving/dehydrated (set 0 to disable)
Config.HotTemperatureDamagePerSecond = 0.5 -- Health damage applied per second while overheating (set 0 to disable)
Config.ColdTemperatureDamagePerSecond = 0.5 -- Health damage applied per second while freezing (set 0 to disable)
Config.TemperatureDamageDelay = 5.0 -- Seconds to wait before temperature damage starts after an effect triggers

-- Palette persistence
-- Voice indicator
Config.EnableVoiceCore = true   -- Toggle the voice range core
Config.VoiceMaxRange = 12.0     -- Maximum voice range (in metres) used to normalise the ring
Config.VoiceTalkingLabel = 'talking' -- Label shown while the player is transmitting voice

-- Database persistence (requires oxmysql)
Config.SaveToDatabase = true    -- Disable if you do not want to store core snapshots server-side
Config.SaveInterval = 15000     -- Minimum delay between persisted snapshots per player (milliseconds)
Config.DatabaseTable = 'bcc_corehud' -- Database table used for persistence (exists automatically)

-- Optional consumable registration (requires vorp_inventory)
Config.RegisterNeedItems = true -- Set true to auto-register items defined below
Config.NeedItems = {
    
    {
        item = 'copper',      -- item name in vorp_inventory
        thirst = 1,               -- amount to add to thirst (negative to reduce)
        hunger = 25,                -- optional hunger adjustment
        stress = 0,                -- optional stress adjustment
        remove = true,             -- remove the used item (default true)
        --give = { item = 'emptyBottle', count = 1 }, -- optional reward item
        closeInventory = true      -- close inventory before applying effects (default true)
    }
    -- Add more entries as needed
    
}
