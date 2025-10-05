-- ---------- config ----------
local CORE_KEYS = {
    { key = 'health',        label = 'Health' },
    { key = 'stamina',       label = 'Stamina' },
    { key = 'hunger',        label = 'Hunger' },
    { key = 'thirst',        label = 'Thirst' },
    { key = 'stress',        label = 'Stress' },
    { key = 'messages',      label = 'Messages' },
    { key = 'clean_stats',   label = 'Cleanliness' },
    { key = 'money',        label = 'Money' },
    { key = 'gold',         label = 'Gold' },
    { key = 'exp',          label = 'Experience' },
    { key = 'tokens',       label = 'Tokens' },
    { key = 'logo',         label = 'Logo' },
    { key = 'temperature',   label = 'Temperature' },
    { key = 'horse_health',  label = 'Horse Health' },
    { key = 'horse_stamina', label = 'Horse Stamina' },
    { key = 'horse_dirt',    label = 'Horse Dirtiness' },
    { key = 'voice',         label = 'Voice' },
}
local LAST_PALETTE_SNAPSHOT = nil

local function clamp(v, lo, hi)
    v = tonumber(v) or 0; if v < lo then return lo end; if v > hi then return hi end; return v
end
local function numberFromSlider(v)
    if type(v) == "table" then
        local n = v.value
        if type(n) == "table" then n = n.value end
        return tonumber(n) or 0
    end
    return tonumber(v) or 0
end

-- defaults
local PALETTE = {
    health        = { hue = 280, saturation = 65 },
    stamina       = { hue = 205, saturation = 70 },
    hunger        = { hue = 25, saturation = 78 },
    thirst        = { hue = 195, saturation = 70 },
    stress        = { hue = 5, saturation = 82 },
    messages      = { hue = 335, saturation = 75 },
    clean_stats   = { hue = 120, saturation = 70 },
    money         = { hue = 140, saturation = 65 },
    gold          = { hue = 45,  saturation = 80 },
    exp           = { hue = 210, saturation = 70 },
    tokens        = { hue = 275, saturation = 72 },
    logo          = { hue = 0,   saturation = 0 },
    temperature   = { hue = 50, saturation = 80 },
    horse_health  = { hue = 145, saturation = 65 },
    horse_stamina = { hue = 210, saturation = 70 },
    horse_dirt    = { hue = 44, saturation = 78 },
    voice         = { hue = 165, saturation = 65 },
}

-- colorful preset
local COLORFUL_PRESET = {
    health        = { hue = 280, saturation = 65 },
    stamina       = { hue = 205, saturation = 70 },
    hunger        = { hue = 25, saturation = 78 },
    thirst        = { hue = 195, saturation = 70 },
    stress        = { hue = 5, saturation = 82 },
    messages      = { hue = 335, saturation = 75 },
    clean_stats   = { hue = 120, saturation = 70 },
    money         = { hue = 140, saturation = 65 },
    gold          = { hue = 45,  saturation = 80 },
    exp           = { hue = 210, saturation = 70 },
    tokens        = { hue = 275, saturation = 72 },
    logo          = { hue = 0,   saturation = 0 },
    temperature   = { hue = 50, saturation = 80 },
    horse_health  = { hue = 145, saturation = 65 },
    horse_stamina = { hue = 210, saturation = 70 },
    horse_dirt    = { hue = 44, saturation = 78 },
    voice         = { hue = 165, saturation = 65 },
}

-- all-white preset
local function makeWhitePreset()
    local p = {}
    for _, spec in ipairs(CORE_KEYS) do p[spec.key] = { hue = 0, saturation = 0 } end
    return p
end
local WHITE_PRESET = makeWhitePreset()

-- keep both ids and handles so we can read & update
local SLIDER_REFS = {} -- [key] = { hueId=..., hue=<class>, satId=..., saturation=<class> }
local PALETTE_PAGE = nil

-- ---------- NUI payload ----------
local function hsl(h, s, l, a)
    h = clamp(math.floor(h + 0.5), 0, 360)
    s = clamp(math.floor(s + 0.5), 0, 100)
    l = clamp(math.floor(l + 0.5), 0, 100)
    if a ~= nil then return ('hsla(%d, %d%%, %d%%, %.2f)'):format(h, s, l, clamp(a, 0, 1)) end
    return ('hsl(%d, %d%%, %d%%)'):format(h, s, l)
end

local function computePaletteEntry(hue, sat)
    return {
        accent     = hsl(hue, sat, 58),
        icon       = '#ffffff',
        background = hsl(hue, math.floor(sat * 0.45), 18, 0.6),
        track      = hsl(hue, math.max(12, math.floor(sat * 0.35)), 85, 0.35),
        border     = hsl(hue, math.max(20, math.floor(sat * 0.75)), 70, 0.45),
        shadow     = '0 18px 28px rgba(8, 13, 23, 0.45)',
    }
end

local function paletteSnapshotToNuiPayload(snapshot)
    local out = {}
    if type(snapshot) == 'table' then
        for _, spec in ipairs(CORE_KEYS) do
            local k = spec.key; local e = snapshot[k]
            if type(e) == 'table' then
                local h = clamp(tonumber(e.hue) or 0, 0, 360)
                local s = clamp(tonumber(e.saturation) or 0, 0, 100)
                out[k] = computePaletteEntry(h, s)
            end
        end
    end
    out.default = computePaletteEntry(0, 0)
    return { type = 'palette', palette = out }
end

local function pushPaletteToHud(snapshot)
    LAST_PALETTE_SNAPSHOT = snapshot
    SendNUIMessage(paletteSnapshotToNuiPayload(snapshot))
end

local function requestPaletteFromServer()
    local result = BccUtils.RPC:CallAsync('bcc-corehud:palette:request', {})

    if not result then
        devPrint('[bcc-corehud:palette:request] RPC failed or returned false')
        return false
    end

    devPrint('[bcc-corehud:palette:request] RPC completed successfully')
    return true
end

-- Ask once when the resource starts (handles resource reloads)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        -- give NUI a moment if it’s loading
        CreateThread(function()
            Wait(300)
            requestPaletteFromServer()
        end)
    end
end)

RegisterNUICallback('paletteReady', function(_, cb)
    if LAST_PALETTE_SNAPSHOT then
        pushPaletteToHud(LAST_PALETTE_SNAPSHOT)
    else
        -- nothing cached yet: ask server
        requestPaletteFromServer()
    end
    if cb then cb('ok') end
end)

local function buildPalettePayload()
    local out = {}
    for _, spec in ipairs(CORE_KEYS) do
        local k = spec.key
        local e = PALETTE[k] or { hue = 0, saturation = 0 }
        out[k] = computePaletteEntry(e.hue, e.saturation)
    end
    out.default = computePaletteEntry(0, 0) -- fallback theme
    return { type = 'palette', palette = out }
end

local function sendPaletteToNui()
    SendNUIMessage(buildPalettePayload())
end

-- ---------- state setters ----------
local function updateSliderHandle(handle, newValue)
    if handle and handle.update then handle:update({ value = newValue }) end
end

local function setHue(statKey, value, reflectSliders)
    local v = clamp(value, 0, 360)
    PALETTE[statKey] = PALETTE[statKey] or { hue = 0, saturation = 0 }
    PALETTE[statKey].hue = v
    if reflectSliders and SLIDER_REFS[statKey] then updateSliderHandle(SLIDER_REFS[statKey].hue, v) end
end

local function setSaturation(statKey, value, reflectSliders)
    local v = clamp(value, 0, 100)
    PALETTE[statKey] = PALETTE[statKey] or { hue = 0, saturation = 0 }
    PALETTE[statKey].saturation = v
    if reflectSliders and SLIDER_REFS[statKey] then updateSliderHandle(SLIDER_REFS[statKey].saturation, v) end
end

local function getSnapshot()
    local snap = {}
    for _, spec in ipairs(CORE_KEYS) do
        local k = spec.key
        local e = PALETTE[k] or { hue = 0, saturation = 0 }
        snap[k] = { hue = clamp(e.hue, 0, 360), saturation = clamp(e.saturation, 0, 100) }
    end
    return snap
end

local function savePalette(reason)
    local snapshot = getSnapshot()
    local ok = BccUtils.RPC:CallAsync('bcc-corehud:palette:save', {
        snapshot = snapshot,
        reason = reason or 'manual_save'
    })

    if not ok then
        devPrint('[bcc-corehud:palette:save] RPC failed or rejected')
    else
        devPrint('[bcc-corehud:palette:save] RPC success')
    end
end

local function applyPreset(preset, shouldSave)
    if type(preset) ~= 'table' then return end
    for _, spec in ipairs(CORE_KEYS) do
        local k = spec.key
        local src = preset[k]
        if type(src) == 'table' then
            setHue(k, src.hue or 0, true)
            setSaturation(k, src.saturation or 0, true)
        end
    end
    sendPaletteToNui()
    if shouldSave then savePalette('preset') end
end

BccUtils.RPC:Register('bcc-corehud:palette:apply', function(params, cb)
    local snapshot = params and (params.snapshot or params)
    if type(snapshot) ~= 'table' then
        if cb then cb(false) end
        devPrint('[palette:apply] bad_payload')
        return
    end

    -- apply inline
    for _, spec in ipairs(CORE_KEYS) do
        local k   = spec.key
        local src = snapshot[k]
        if type(src) == 'table' then
            setHue(k, tonumber(src.hue) or 0, true)         -- reflect sliders
            setSaturation(k, tonumber(src.saturation) or 0, true)
        end
    end

    LAST_PALETTE_SNAPSHOT = getSnapshot() -- cache normalized
    sendPaletteToNui()                    -- build from PALETTE

    if cb then cb(true) end
end)

-- ---------- live drag watcher ----------
local function isMenuActive()
    if not FeatherMenu or not FeatherMenu.activeMenu then return false end
    -- If you register your menu with Feather, you can also check menuID here.
    return FeatherMenu.activeMenu ~= nil
end

local LIVE_WATCHER_RUNNING = false
local function startLiveWatcher()
    if LIVE_WATCHER_RUNNING then return end
    LIVE_WATCHER_RUNNING = true
    CreateThread(function()
        while isMenuActive() do
            local dirty = false
            if PALETTE_PAGE and PALETTE_PAGE.RegisteredElements then
                for _, spec in ipairs(CORE_KEYS) do
                    local k = spec.key
                    local refs = SLIDER_REFS[k]
                    if refs then
                        local hueElem = PALETTE_PAGE.RegisteredElements[refs.hueId]
                        if hueElem and hueElem.data then
                            local hv = clamp(numberFromSlider(hueElem.data.value), 0, 360)
                            if hv ~= PALETTE[k].hue then
                                setHue(k, hv, false); dirty = true
                            end
                        end
                        local satElem = PALETTE_PAGE.RegisteredElements[refs.satId]
                        if satElem and satElem.data then
                            local sv = clamp(numberFromSlider(satElem.data.value), 0, 100)
                            if sv ~= PALETTE[k].saturation then
                                setSaturation(k, sv, false); dirty = true
                            end
                        end
                    end
                end
            end
            if dirty then sendPaletteToNui() end
            Wait(50) -- ~20 fps while dragging feels smooth without being heavy
        end
        LIVE_WATCHER_RUNNING = false
    end)
end

-- ---------- Menu ----------
function mainPaleteMenu()
    local page = BCCCoreHudMenu:RegisterPage('bcc-corehud:palette:page')
    PALETTE_PAGE = page

    page:RegisterElement('header', { value = 'HUD Palette', slot = 'header' })
    page:RegisterElement('subheader', { value = 'Adjust the HUD colors', slot = 'header' })
    page:RegisterElement('line', { slot = 'header' })

    local toggleCmd = Config.CommandToggleHud
    local toggleLabel = toggleCmd and ('Toggle HUD Visibility (/%s)'):format(toggleCmd) or 'Toggle HUD Visibility'
    page:RegisterElement('button', { label = toggleLabel, slot = 'content' }, function()
        if type(ToggleUI) == 'function' then
            ToggleUI()
        elseif toggleCmd and type(ExecuteCommand) == 'function' then
            ExecuteCommand(toggleCmd)
        end
    end)

    local paletteCmd = Config.CommandPalette
    local paletteLabel = paletteCmd and ('Reopen Palette Menu (/%s)'):format(paletteCmd) or 'Reopen Palette Menu'
    page:RegisterElement('button', { label = paletteLabel, slot = 'content' }, function()
        if paletteCmd and type(ExecuteCommand) == 'function' then
            ExecuteCommand(paletteCmd)
        end
    end)
    page:RegisterElement('line', { slot = 'content' })

    -- footer actions
    page:RegisterElement('button', { label = 'Apply Colors', slot = 'footer' }, function()
        sendPaletteToNui()
        savePalette('apply_colors')
    end)
    page:RegisterElement('button', { label = 'Apply Colorful Preset', slot = 'footer' }, function()
        applyPreset(COLORFUL_PRESET, true)
    end)
    page:RegisterElement('button', { label = 'Reset to White', slot = 'footer' }, function()
        applyPreset(WHITE_PRESET, true)
    end)

    -- sliders
    for _, spec in ipairs(CORE_KEYS) do
        local k     = spec.key
        local label = spec.label
        local entry = PALETTE[k] or { hue = 0, saturation = 0 }

        page:RegisterElement('subheader', { value = label, slot = 'content', style = { ['margin-top'] = '8px' } })

        local hueId = ('bcc-corehud:palette:%s:hue'):format(k)
        local hueHandle = page:RegisterElement('slider', {
            id    = hueId,
            label = 'Hue',
            slot  = 'content',
            start = entry.hue,
            min   = 0,
            max   = 360,
            steps = 1
        }, function(data)
            -- still handle commit events
            setHue(k, numberFromSlider(data), false)
            sendPaletteToNui()
        end)

        local satId = ('bcc-corehud:palette:%s:saturation'):format(k)
        local satHandle = page:RegisterElement('slider', {
            id    = satId,
            label = 'Saturation',
            slot  = 'content',
            start = entry.saturation,
            min   = 0,
            max   = 100,
            steps = 1
        }, function(data)
            setSaturation(k, numberFromSlider(data), false)
            sendPaletteToNui()
        end)

        SLIDER_REFS[k] = { hueId = hueId, hue = hueHandle, satId = satId, saturation = satHandle }
        page:RegisterElement('line', { slot = 'content' })
    end

    BCCCoreHudMenu:Open({ startupPage = page })
    -- kick off the realtime watcher so colors update during drag
    startLiveWatcher()
end
