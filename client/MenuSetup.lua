PaletteMenu = PaletteMenu or {}
local PM = PaletteMenu

local CORE_PALETTE_ORDER = {
    'health',
    'stamina',
    'hunger',
    'thirst',
    'stress',
    'temperature',
    'horse_health',
    'horse_stamina',
    'horse_dirt',
    'voice'
}

local CORE_LABELS = {
    health = 'Health',
    stamina = 'Stamina',
    hunger = 'Hunger',
    thirst = 'Thirst',
    stress = 'Stress',
    temperature = 'Temperature',
    horse_health = 'Horse Health',
    horse_stamina = 'Horse Stamina',
    horse_dirt = 'Horse Dirtiness',
    voice = 'Voice'
}

local COLORFUL_PRESET = {
    health = { hue = 280, saturation = 65 },
    stamina = { hue = 205, saturation = 70 },
    hunger = { hue = 25, saturation = 78 },
    thirst = { hue = 195, saturation = 70 },
    stress = { hue = 5, saturation = 82 },
    temperature = { hue = 50, saturation = 80 },
    horse_health = { hue = 145, saturation = 65 },
    horse_stamina = { hue = 210, saturation = 70 },
    horse_dirt = { hue = 44, saturation = 78 },
    voice = { hue = 165, saturation = 65 }
}

local function clampValue(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function PM:Debug(...)
    if not self.debugEnabled then
        return
    end

    print('[BCC-CoreHUD][Palette]', ...)
end

function PM:CreateDefaultSettings()
    local settings = { default = { hue = 0, saturation = 0 } }
    for _, key in ipairs(CORE_PALETTE_ORDER) do
        settings[key] = { hue = 0, saturation = 0 }
    end
    return settings
end

function PM:Init(options)
    options = options or {}
    self.debugEnabled = options.debugEnabled == true
    self.settings = self:CreateDefaultSettings()
    self.sliderRefs = {}
    self.featherMenu = nil
    self.menuHandle = nil
    self.pageHandle = nil
    self.menuOpen = false
    self.lastSave = 0
    self.saveTimer = nil
    self.pendingSave = false
    self.applying = false
    self:SendPaletteToUI()
    TriggerServerEvent('bcc-corehud:palette:request')
end

local function mergeInto(target, source)
    if type(source) ~= 'table' then
        return target
    end

    if type(target) ~= 'table' then
        target = {}
    end

    for key, value in pairs(source) do
        target[key] = value
    end

    return target
end

function PM:Reset()
    self:ApplySnapshot(nil)
    self:QueueSave()
end

function PM:ApplyPreset(preset)
    self:ApplySnapshot(preset or COLORFUL_PRESET)
    self:QueueSave()
end

function PM:GetSnapshot()
    local snapshot = {}
    for _, key in ipairs(CORE_PALETTE_ORDER) do
        local entry = self.settings[key] or { hue = 0, saturation = 0 }
        snapshot[key] = {
            hue = clampValue(tonumber(entry.hue) or 0, 0, 360),
            saturation = clampValue(tonumber(entry.saturation) or 0, 0, 100)
        }
    end

    local default = self.settings.default or { hue = 0, saturation = 0 }
    snapshot.default = {
        hue = clampValue(tonumber(default.hue) or 0, 0, 360),
        saturation = clampValue(tonumber(default.saturation) or 0, 0, 100)
    }
    return snapshot
end

function PM:ComputePaletteEntry(hue, saturation)
    local function hsl(h, s, l, a)
        h = clampValue(math.floor(h + 0.5), 0, 360)
        s = clampValue(math.floor(s + 0.5), 0, 100)
        l = clampValue(math.floor(l + 0.5), 0, 100)

        if a ~= nil then
            a = clampValue(a, 0.0, 1.0)
            return ('hsla(%d, %d%%, %d%%, %.2f)'):format(h, s, l, a)
        end

        return ('hsl(%d, %d%%, %d%%)'):format(h, s, l)
    end

    local accent = hsl(hue, saturation, 58)
    local background = hsl(hue, math.floor(saturation * 0.45), 18, 0.6)
    local track = hsl(hue, math.max(12, math.floor(saturation * 0.35)), 85, 0.35)
    local border = hsl(hue, math.max(20, math.floor(saturation * 0.75)), 70, 0.45)

    return {
        accent = accent,
        icon = '#ffffff',
        background = background,
        track = track,
        border = border,
        shadow = '0 18px 28px rgba(8, 13, 23, 0.45)'
    }
end

function PM:BuildUiPayload()
    local payload = {}
    for _, key in ipairs(CORE_PALETTE_ORDER) do
        local entry = self.settings[key] or { hue = 0, saturation = 0 }
        payload[key] = self:ComputePaletteEntry(entry.hue, entry.saturation)
    end

    local defaultEntry = self.settings.default or { hue = 0, saturation = 0 }
    payload.default = self:ComputePaletteEntry(defaultEntry.hue, defaultEntry.saturation)
    return payload
end

function PM:SendPaletteToUI()
    SendNUIMessage({
        type = 'palette',
        palette = self:BuildUiPayload()
    })
end

function PM:RefreshSliders()
    if not self.pageHandle then
        return
    end

    local canBroadcast = self:IsMenuActive()

    for _, key in ipairs(CORE_PALETTE_ORDER) do
        local refs = self.sliderRefs[key]
        local settings = self.settings[key]
        if refs and settings then
            local huePayload = { value = settings.hue, start = settings.hue }
            if refs.hueId then
                local element = self.pageHandle.RegisteredElements and
                    self.pageHandle.RegisteredElements[refs.hueId]
                if element then
                    element.data = mergeInto(element.data, huePayload)
                end

                local class = self.pageHandle.RegistedElementsClasses and
                    self.pageHandle.RegistedElementsClasses[refs.hueId]
                if class and class ~= refs.hue then
                    -- keep element class in sync in case feather regenerates references
                    refs.hue = class
                end
            end

            if refs.hue and canBroadcast then
                local ok, err = pcall(refs.hue.update, refs.hue, huePayload)
                if not ok then
                    self:Debug('Failed to update hue slider', key, err)
                end
            end

            local satPayload = { value = settings.saturation, start = settings.saturation }
            if refs.saturationId then
                local element = self.pageHandle.RegisteredElements and
                    self.pageHandle.RegisteredElements[refs.saturationId]
                if element then
                    element.data = mergeInto(element.data, satPayload)
                end

                local class = self.pageHandle.RegistedElementsClasses and
                    self.pageHandle.RegistedElementsClasses[refs.saturationId]
                if class and class ~= refs.saturation then
                    refs.saturation = class
                end
            end

            if refs.saturation and canBroadcast then
                local ok, err = pcall(refs.saturation.update, refs.saturation, satPayload)
                if not ok then
                    self:Debug('Failed to update saturation slider', key, err)
                end
            end
        end
    end
end

function PM:IsMenuActive()
    if not FeatherMenu or not self.menuId then
        return false
    end

    local active = FeatherMenu.activeMenu
    if type(active) ~= 'table' or active.menuID ~= self.menuId then
        return false
    end

    return true
end

function PM:EnsureFeather()
    if FeatherMenu ~= nil then
        return true
    end

    if GetResourceState('feather-menu') ~= 'started' then
        self:Debug('feather-menu resource is not started')
        return false
    end

    local ok, menu = pcall(function()
        return exports['feather-menu']:initiate()
    end)

    if not ok or not menu then
        self:Debug('Failed to initiate feather-menu: ' .. tostring(menu))
        return false
    end

    FeatherMenu = menu
    return true
end

function PM:EnsureMenu()
    if self.menuHandle then
        return true
    end

    if not self:EnsureFeather() then
        return false
    end

    local menuRef = self

    self.menuId = 'bcc-corehud:palette'

    self.menuHandle = FeatherMenu:RegisterMenu(self.menuId, {
        top = '3%',
        left = '3%',
        ['720width'] = '400px',
        ['1080width'] = '500px',
        ['2kwidth'] = '600px',
        ['4kwidth'] = '800px',
        style = {
            --['background-image'] = 'url("nui://bcc-craft/assets/background.png")',
            --['background-size'] = 'cover',  
            --['background-repeat'] = 'no-repeat',
                --['background-position'] = 'center',
                --['background-color'] = 'rgba(55, 33, 14, 0.7)', -- A leather-like brown
                --['border'] = '1px solid #654321', 
                --['font-family'] = 'Times New Roman, serif', 
                --['font-size'] = '38px',
                --['color'] = '#ffffff', 
                --['padding'] = '10px 20px',
                --['margin-top'] = '5px',
                --['cursor'] = 'pointer', 
                --['box-shadow'] = '3px 3px #333333', 
                --['text-transform'] = 'uppercase', 
        },
        contentslot = {
            style = {
                ['height'] = '450px',
                ['min-height'] = '300px'
            }
        },
    }, {
        closed = function()
            menuRef.menuOpen = false
            DisplayRadar(true)
        end,
        opened = function()
            menuRef.menuOpen = true
            DisplayRadar(false)
            menuRef:RefreshSliders()
        end
    })

    FeatherHudMenu = self.menuHandle

    self.pageHandle = self.menuHandle:RegisterPage('bcc-corehud:palette:main')

    self.pageHandle:RegisterElement('header', {
        value = 'HUD Palette',
        slot = 'header'
    })

    self.pageHandle:RegisterElement('subheader', {
        value = 'Adjust the HUD colors in real-time',
        slot = 'header'
    })

    self.pageHandle:RegisterElement('line', {
        slot = 'header'
    })

    for _, key in ipairs(CORE_PALETTE_ORDER) do
        local label = CORE_LABELS[key] or key
        local settings = self.settings[key]
        local entryRefs = {}

        self.pageHandle:RegisterElement('subheader', {
            value = label,
            slot = 'content',
            style = {
                ['margin-top'] = '6px'
            }
        })

        local statKey = key
        entryRefs.hueId = ('bcc-corehud:palette:%s:hue'):format(statKey)
        entryRefs.hue = self.pageHandle:RegisterElement('slider', {
            id = entryRefs.hueId,
            label = 'Hue',
            start = settings.hue,
            slot = 'content',
            min = 0,
            max = 360,
            steps = 1
        }, function(data)
            self:OnSliderChanged(statKey, 'hue', data.value)
        end)

        entryRefs.saturationId = ('bcc-corehud:palette:%s:saturation'):format(statKey)
        entryRefs.saturation = self.pageHandle:RegisterElement('slider', {
            id = entryRefs.saturationId,
            label = 'Saturation',
            start = settings.saturation,
            slot = 'content',
            min = 0,
            max = 100,
            steps = 1
        }, function(data)
            self:OnSliderChanged(statKey, 'saturation', data.value)
        end)

        self.pageHandle:RegisterElement('line', {
            slot = 'content'
        })

        self.sliderRefs[statKey] = entryRefs
    end

    self.pageHandle:RegisterElement('button', {
        label = 'Apply Colorful Preset',
        slot = 'footer'
    }, function()
        self:ApplyPreset(COLORFUL_PRESET)
    end)

    self.pageHandle:RegisterElement('button', {
        label = 'Reset to White',
        slot = 'footer'
    }, function()
        self:Reset()
    end)

    self.pageHandle:RegisterElement('bottomline', {
        slot = 'footer'
    })

    return true
end

function PM:Open()
    if not self:EnsureMenu() then
        print('[BCC-CoreHUD] Feather menu is unavailable. Ensure `feather-menu` is running.')
        return
    end

    if not self:IsMenuActive() then
        self.menuHandle:Open({ startupPage = self.pageHandle })
    else
        self:RefreshSliders()
    end
end

function PM:Rebuild()
    self:SendPaletteToUI()
end

function PM:ApplySnapshot(snapshot)
    self.applying = true

    if type(snapshot) ~= 'table' then
        self.settings = self:CreateDefaultSettings()
    else
        local settings = self:CreateDefaultSettings()
        for _, key in ipairs(CORE_PALETTE_ORDER) do
            local entry = snapshot[key]
            if type(entry) == 'table' then
                settings[key].hue = clampValue(tonumber(entry.hue) or 0, 0, 360)
                settings[key].saturation = clampValue(tonumber(entry.saturation) or 0, 0, 100)
            end
        end

        if type(snapshot.default) == 'table' then
            settings.default.hue = clampValue(tonumber(snapshot.default.hue) or 0, 0, 360)
            settings.default.saturation = clampValue(tonumber(snapshot.default.saturation) or 0, 0, 100)
        end

        self.settings = settings
    end

    self:SendPaletteToUI()
    self:RefreshSliders()

    self.applying = false
end

function PM:OnSliderChanged(statKey, field, value)
    local entry = self.settings[statKey]
    if not entry then
        return
    end

    local numeric = tonumber(value) or 0
    if field == 'hue' then
        entry.hue = clampValue(math.floor(numeric + 0.5), 0, 360)
    else
        entry.saturation = clampValue(math.floor(numeric + 0.5), 0, 100)
    end

    self:SendPaletteToUI()

    if not self.applying then
        self:QueueSave()
    end
end

function PM:SendSave()
    local snapshot = self:GetSnapshot()
    TriggerServerEvent('bcc-corehud:palette:save', snapshot)
    self.lastSave = GetGameTimer()
end

function PM:QueueSave()
    if self.saveTimer then
        self.pendingSave = true
        return
    end

    self.saveTimer = true
    CreateThread(function()
        Wait(1500)
        self.saveTimer = false
        self:SendSave()
        if self.pendingSave then
            self.pendingSave = false
            self:QueueSave()
        end
    end)
end

RegisterNetEvent('bcc-corehud:palette:apply', function(snapshot)
    PaletteMenu:ApplySnapshot(snapshot)
end)
