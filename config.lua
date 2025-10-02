Config                          = {}

-- Locale key used by locale.lua (must exist in Locales table)
Config.defaultlang              = 'en'

-- Client HUD behaviour
Config.AutoShowHud              = true         -- Set to false to require manual /togglehud on spawn
Config.UpdateInterval           = 5000         -- Core refresh rate in milliseconds
Config.LowCoreWarning           = 25.0         -- Trigger status effects when cores fall below this percent
Config.devMode                  = true         -- Enable verbose client logging when true
Config.HorseDirtyThreshold      = 4            -- Attribute rank at/below which the horse shows the dirty icon (0-10, set false to disable)
Config.TemperatureColdThreshold = -3.0         -- World temperature (Celsius) at/below which cold icon appears
Config.TemperatureHotThreshold  = 26.0         -- World temperature (Celsius) at/above which hot icon appears
Config.TemperatureMin           = -15.0        -- Minimum world temperature mapped to the core (Celsius)
Config.TemperatureMax           = 40.0         -- Maximum world temperature mapped to the core (Celsius)
Config.AlwaysShowTemperature    = true         -- When true the temperature core is shown even without hot/cold effects
Config.HungerWarningEffect      = 'starving'   -- Label shown when hunger drops below LowCoreWarning
Config.ThirstWarningEffect      = 'parched'    -- Label shown when thirst drops below LowCoreWarning
Config.StressWarningEffect      = 'stressed'   -- Label shown when stress falls below LowCoreWarning
Config.NeedsAutoDecay           = true         -- When true and no external needs resource is configured, hunger/thirst decay over time
Config.NeedsDecayStartDelay     = 300.0        -- Seconds to wait before decay begins after a refill (5 minutes)
Config.HungerRate               = 0.10         -- Percent-per-second hunger decay applied once the delay expires
Config.ThirstRate               = 0.15         -- Percent-per-second thirst decay applied once the delay expires
Config.MountedHungerRate        = 0.10         -- Hunger decay rate applied while riding a mount
Config.MountedThirstRate        = 0.15         -- Thirst decay rate applied while riding a mount
Config.ActivityMultipliers      = {
    idle   = { hunger = 0.10, thirst = 0.15 }, -- applied repeatedly while almost still
    walk   = { hunger = 0.20, thirst = 0.30 }, -- gentle movement
    run    = { hunger = 0.45, thirst = 0.60 }, -- steady run
    sprint = { hunger = 0.65, thirst = 0.80 }, -- full sprint
    coast  = { hunger = 0.65, thirst = 0.40 }, -- default fallback when standing but not flagged idle
    swim   = { hunger = 0.65, thirst = 0.40 }  -- swimming effort
}
Config.InitialNeedValue         = 100.0        -- Default hunger/thirst value applied on spawn when using local decay

-- Simple temperature health/thirst damage
Config.MinTemp                  = -5.0                                   -- Temperatures below this deal health damage each HUD tick
Config.MaxTemp                  = 31.0                                   -- Temperatures above this deal health damage each HUD tick
Config.RemoveHealth             = 5                                      -- Health removed per tick while outside the safe temperature range
Config.HotTempThirstDrain       = 1.5                                    -- Percent thirst removed per tick while above Config.MaxTemp
Config.TempWarningMessage       = "You cannot stay in sun, find some cool places!" -- Notification shown when overheating
Config.TempWarningCooldown      = 10.0                                   -- Seconds between repeated overheat warnings
Config.DoHealthDamageFx         = true                                   -- Play the "MP_Downed" screen effect while taking temperature damage
Config.DoHealthPainSound        = true                                   -- Play the pain grunt when temperature damage applies

Config.StarvationDamageDelay    = 120.0                                  -- Seconds both hunger and thirst must be empty before health damage starts (set 0 to disable)
Config.StarvationDamageInterval = 10.0                                   -- Seconds between health damage ticks once starvation damage begins
Config.StarvationDamageAmount   = 3                                      -- Health removed each tick when starving/dehydrated (set 0 to disable)

-- Voice indicator
Config.EnableVoiceCore          = true                             -- Toggle the voice range core
Config.VoiceMaxRange            = 50.0                             -- Maximum voice range (in metres) used to normalise the ring
Config.VoiceTalkingLabel        = 'talking'                        -- Label shown while the player is transmitting voice

Config.VoiceProximitySteps      = { 2.0, 15.0, 50.0 }              -- whisper / normal / shout
Config.VoiceProximityLabels     = { 'Whisper', 'Normal', 'Shout' } -- optional custom labels matching the steps
Config.VoiceDefaultStepIndex    = 2                                -- start on 15m
-- Use a control hash or a named control (GetHashKey name). Change to what you want.
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
Config.LogoImage                = '' -- Path/URL served by NUI for the logo image

-- Database persistence (requires oxmysql)
Config.SaveInterval             = 15000 -- Minimum delay between persisted snapshots per player (milliseconds)

Config.NeedItems                = {
    -- FOODS (eat)
    { item = 'apple',                                 thirst = 8,  hunger = 8,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_fruitsalad',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'knotmeat',                              thirst = 0,  hunger = 50, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_chocolate',                  thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3000, stamina = 2 },
    { item = 'consumable_apple',                      thirst = 0,  hunger = 1,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2500, stamina = 2 },
    { item = 'bread',                                 thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_beefstew',                   thirst = 0,  hunger = 50, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 5000, stamina = 2 },
    { item = 'cooked_game',                           thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'cooked_biggame',                        thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'cooked_bird',                           thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'cooked_mutton',                         thirst = 0,  hunger = 15, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'cooked_venison',                        thirst = 0,  hunger = 35, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_kidneybeans_can',            thirst = 0,  hunger = 20, stress = 0, remove = true, prop = 'P_TINNEDFOOD01X',   animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_salmon_can',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_TINNEDFOOD01X',   animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_steakpie',                   thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'cooked_pork',                           thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'steak',                                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_breakfast',                  thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_blueberrypie',               thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_bluegil',                    thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_polenta_cheese',             thirst = 0,  hunger = 20, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_lemoncake',                  thirst = 0,  hunger = 15, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3000, stamina = 2 },
    { item = 'consumable_donut',                      thirst = 0,  hunger = 10, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2500, stamina = 2 },
    { item = 'consumable_pretzel',                    thirst = 0,  hunger = 10, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3000, stamina = 2 },
    { item = 'consumable_spongecake',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_chickenpie',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_coffeecake',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_crumbcake',                  thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'Grape',                                 thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2000, stamina = 2 },
    { item = 'consumable_medicine',                   thirst = 0,  hunger = 30, stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 3000, stamina = 2 },
    { item = 'caramel',                               thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2500, stamina = 2 },
    { item = 'ciocolata',                             thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2500, stamina = 2 },
    { item = 'consumable_game',                       thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_herb_chanterelles',          thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3000, stamina = 2 },
    { item = 'consumable_herb_evergreen_huckleberry', thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2000, stamina = 2 },
    { item = 'consumable_herb_oregano',               thirst = 0,  hunger = 1,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 1500, stamina = 2 },
    { item = 'consumable_peach',                      thirst = 0,  hunger = 1,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2000, stamina = 2 },
    { item = 'consumable_herb_vanilla_flower',        thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2000, stamina = 2 },
    { item = 'consumable_herb_wintergreen_berry',     thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2000, stamina = 2 },
    { item = 'consumable_meat_greavy',                thirst = 0,  hunger = 5,  stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_pear',                       thirst = 1,  hunger = 1,  stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 2000, stamina = 2 },
    { item = 'consumable_jumari',                     thirst = 0,  hunger = 15, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_saltedcorn',                 thirst = 0,  hunger = 20, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_eggplantsalad',              thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_cabbagerolls',               thirst = 0,  hunger = 50, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 5000, stamina = 2 },
    { item = 'consumable_porkstew',                   thirst = 0,  hunger = 50, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 5000, stamina = 2 },
    { item = 'consumable_biggamestew',                thirst = 0,  hunger = 50, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 5000, stamina = 2 },
    { item = 'consumable_tripe_soup',                 thirst = 0,  hunger = 50, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 5000, stamina = 2 },
    { item = 'consumable_chicken_soup',               thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_chicken_stew',               thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_beef_cabbage',               thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_boiled_egg_polenta',         thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_fish_veggie_brine',          thirst = 10, hunger = 20, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_omelette_bacon',             thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_meat_pie',                   thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_chicken_pie',                thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_fruit_jam',                  thirst = 0,  hunger = 30, stress = 0, remove = true, prop = nil,                 animation = 'eat',   duration = 3000, stamina = 2 },
    { item = 'consumable_cow_cheese',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_honey_jar',                  thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_MUGCOFFEE01X',    animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'consumable_fruit_pie',                  thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'consumable_papanas',                    thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_fruit_tart',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_fruit_cake',                 thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_peachcobbler',               thirst = 0,  hunger = 20, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_jam_pancakes',               thirst = 0,  hunger = 25, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'consumable_salmon',                     thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_trout',                      thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'consumable_veggies',                    thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BOWL04X_STEW',    animation = 'eat',   duration = 4500, stamina = 2 },
    { item = 'cookedbluegil',                         thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 4000, stamina = 2 },
    { item = 'cheesecake',                            thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },
    { item = 'chococake',                             thirst = 0,  hunger = 30, stress = 0, remove = true, prop = 'P_BREAD05X',        animation = 'eat',   duration = 3500, stamina = 2 },

    -- DRINKS (drink)
    { item = 'water',                                 thirst = 25, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'consumable_coffee',                     thirst = 10, hunger = 0,  stress = 0, remove = true, prop = 'P_MUGCOFFEE01X',    animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'antipoison',                            thirst = 5,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 3000, stamina = 2 },
    { item = 'unique_ayahuasca_diablo',               thirst = 40, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 4500, stamina = 2 },
    { item = 'vodka',                                 thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'consumable_honey_manuka',               thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_MUGCOFFEE01X',    animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'moonshineplum',                         thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'beer',                                  thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'moonshineapple',                        thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'moonshinepeach',                        thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'moonshinepear',                         thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'soborno',                               thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'wine',                                  thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'whisky',                                thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'tequila',                               thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },
    { item = 'tropicalPunchMoonshine',                thirst = 20, hunger = 0,  stress = 0, remove = true, prop = 'P_BOTTLEBEER01X',   animation = 'drink', duration = 3500, stamina = 2 },

    -- MEDICAL (use)
    { item = 'syringe',                               thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 3000, stamina = 2 },
    { item = 'bandagesteril',                         thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 3000, stamina = 2 },
    { item = 'herbalremedy',                          thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 3000, stamina = 2 },
    { item = 'antibiotics',                           thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 3000, stamina = 2 },

    -- SMOKES (smoke)
    { item = 'cigarette',                             thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_CIGARETTE_CS01X', animation = 'smoke', duration = 8000, stamina = 2 },
    { item = 'cigar',                                 thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_CIGAR02X',        animation = 'smoke', duration = 9000, stamina = 2 },
    { item = 'pipe_smoker',                           thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_PIPE01X',         animation = 'smoke', duration = 9000, stamina = 2 },
    { item = 'pipe',                                  thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_PIPE01X',         animation = 'smoke', duration = 9000, stamina = 2 },
    { item = 'chewingtobacco',                        thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'smoke', duration = 7000, stamina = 2 },
    { item = 'peacepipe',                             thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_PIPE01X',         animation = 'smoke', duration = 9000, stamina = 2 },
    { item = 'cigaret',                               thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = 'P_CIGARETTE_CS01X', animation = 'smoke', duration = 8000, stamina = 2 },

    -- DRUGS (use)
    { item = 'opium',                                 thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 6000, stamina = 2 },
    { item = 'peyote',                                thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 6000, stamina = 2 },
    { item = 'hemp',                                  thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 6000, stamina = 2 },
    { item = 'heroin',                                thirst = 0,  hunger = 0,  stress = 0, remove = true, prop = nil,                 animation = 'use',   duration = 7000, stamina = 2 },
}
