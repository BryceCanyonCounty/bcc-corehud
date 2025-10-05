Config                          = {}

-- Locale key used by locale.lua (must exist in Locales table)
Config.defaultlang              = 'en_lang'

-- Client HUD behaviour
Config.AutoShowHud              = true         -- Set to false to require manual /togglehud on spawn
Config.UpdateInterval           = 5000         -- Core refresh rate in milliseconds
Config.NeedsUpdateInterval      = 5000         -- Interval (ms) at which hunger/thirst/temperature logic runs
Config.LowCoreWarning           = 25.0         -- Trigger status effects when cores fall below this percent
Config.devMode                  = false         -- Enable verbose client logging when true
Config.HorseDirtyThreshold      = 4            -- Attribute rank at/below which the horse shows the dirty icon (0-10, set false to disable)
Config.TemperatureColdThreshold = -3.0         -- World temperature (Celsius) at/below which cold icon appears
Config.TemperatureHotThreshold  = 26.0         -- World temperature (Celsius) at/above which hot icon appears
Config.TemperatureMin           = -15.0        -- Minimum world temperature mapped to the core (Celsius)
Config.TemperatureMax           = 40.0         -- Maximum world temperature mapped to the core (Celsius)
Config.AlwaysShowTemperature    = true         -- When true the temperature core is shown even without hot/cold effects
Config.NeedsAutoDecay           = true         -- When true and no external needs resource is configured, hunger/thirst decay over time
Config.NeedsDecayStartDelay     = 300.0        -- Seconds to wait before decay begins after a refill (5 minutes)
--This multipliers drain the activity by tick(second)
Config.ActivityMultipliers      = {
    idle   = { hunger = 0.05, thirst = 0.07 }, -- applied repeatedly while almost still
    walk   = { hunger = 0.10, thirst = 0.20 }, -- gentle movement
    run    = { hunger = 0.45, thirst = 0.60 }, -- steady run
    sprint = { hunger = 0.65, thirst = 0.80 }, -- full sprint
    coast  = { hunger = 0.65, thirst = 0.40 }, -- default fallback when standing but not flagged idle
    swim   = { hunger = 0.65, thirst = 0.40 },  -- swimming effort
    mounted = { hunger = 0.08, thirst = 0.08 }
}
Config.InitialNeedValue         = 100.0        -- Default hunger/thirst value applied on spawn when using local decay

-- Simple temperature health/thirst damage
Config.MinTemp                  = -5.0                                   -- Temperatures below this deal health damage each HUD tick
Config.MaxTemp                  = 31.0                                   -- Temperatures above this deal health damage each HUD tick
Config.RemoveHealth             = 5                                      -- Health removed per tick while outside the safe temperature range
Config.HotTempThirstDrain       = 1.5                                    -- Percent thirst removed per tick while above Config.MaxTemp
Config.TempWarningCooldown      = 10.0                                   -- Seconds between repeated overheat warnings
Config.DoHealthDamageFx         = true                                   -- Play the "MP_Downed" screen effect while taking temperature damage
Config.DoHealthPainSound        = true                                   -- Play the pain grunt when temperature damage applies
Config.StarvationDamageDelay    = 120.0                                  -- Seconds both hunger and thirst must be empty before health damage starts (set 0 to disable)
Config.StarvationDamageInterval = 10.0                                   -- Seconds between health damage ticks once starvation damage begins
Config.StarvationDamageAmount   = 3                                      -- Health removed each tick when starving/dehydrated (set 0 to disable)

-- Voice indicator
Config.EnableVoiceCore          = true                             -- Toggle the voice range core
Config.VoiceMaxRange            = 50.0                             -- Maximum voice range (in metres) used to normalise the ring
Config.VoiceProximitySteps      = { 2.0, 15.0, 50.0 }              -- whisper / normal / shout
Config.VoiceDefaultStepIndex    = 2                                -- start on 15m
Config.VoiceCycleControl        = 0x446258B6                       -- example key/control (PGUP)

-- Mailbox indicator (integrates with bcc-mailbox)
Config.EnableMailboxCore        = true          -- Show a messages core when true
Config.MailboxResourceName      = 'bcc-mailbox' -- Resource providing the mailbox API/export
Config.MailboxMaxMessages       = 10            -- Count required to fill the ring (10 unread = full)
Config.MailboxUpdateInterval    = 30000         -- How often to refresh the count from the server (milliseconds)
Config.Notify                   = "feather-menu"
-- Clean stats indicator
Config.EnableCleanStatsCore     = true  -- Show a clean stats core when true
Config.MinCleanliness           = 60.0  -- Percent threshold that marks a player as dirty
Config.CleanRate                = 0.01  -- Percent-per-second cleanliness decay when not refreshed
Config.CleanPenaltyInterval     = 10.0  -- Seconds between health penalties while under the cleanliness threshold
Config.CleanHigherIsClean       = false -- When true, higher attribute values mean cleaner
Config.CleanWarningInterval     = 60.0  -- Seconds between hygiene warning notifications
Config.FlyEffect                = {
    enabled    = true,
    dict       = 'scr_mg_cleaning_stalls',
    name       = 'scr_mg_stalls_manure_flies',
    offset     = { x = 0.2, y = 0.0, z = -0.4 },
    rotation   = { x = 0.0, y = 0.0, z = 0.0 },
    axis       = { x = 0.0, y = 0.0, z = 0.0 },
    scale      = 1.0,
    boneMale   = 413,
    boneFemale = 464
}

Config.NeedWarningThreshold     = 10.0  -- Percent at/below which hunger/thirst warnings trigger
Config.NeedWarningInterval      = 120.0 -- Seconds between hunger/thirst warning notifications

-- Command bindings (set to false/nil to disable the command entirely)
Config.CommandToggleHud         = 'togglehud'
Config.CommandLayout            = 'hudlayout'
Config.CommandPalette           = 'hudpalette'
Config.CommandClearFx           = 'clearfx'
Config.CommandHeal              = 'hudheal'

-- Currency/XP indicators (values provided via events/exports)
Config.EnableMoneyCore          = true -- Displays current money amount
Config.EnableGoldCore           = true -- Displays gold balance
Config.EnableExpCore            = true -- Displays experience value
Config.EnableTokensCore         = true -- Displays tokens or premium points

-- Logo / watermark indicator
Config.EnableLogoCore           = true                                      -- Set true to show a draggable logo slot
Config.LogoImage                = 'https://hoinarii.ro/assets/img/logo.png' -- Path/URL served by NUI for the logo image

-- Database persistence (requires oxmysql)
Config.SaveInterval             = 15000 -- Minimum delay between persisted snapshots per player (milliseconds)

Config.NeedItems                = Config.NeedItems or {}

if type(AddNeedItems) ~= 'function' then
    function AddNeedItems(list)
        if type(list) ~= 'table' then return end
        for _, entry in ipairs(list) do
            Config.NeedItems[#Config.NeedItems + 1] = entry
        end
    end
end

Config.Prompts = { 
    Drop = "Drop",                    
    DropKey = 0x3B24C470,              -- F
    Smoke = "Smoke",
    Chewing = "Chew",
    SmokeKey = 0x07B8BEAF,             -- LMB
    Change = "Change",
    ChangeKey = 0xD51B784F,            -- E
}