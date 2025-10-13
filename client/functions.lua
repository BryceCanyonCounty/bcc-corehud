FeatherMenu = exports["feather-menu"].initiate()
BccUtils = exports["bcc-utils"].initiate()

BCCCoreHudMenu = FeatherMenu:RegisterMenu("bcc:corehud:mainmenu", {
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
    }
)

if Config.devMode then
    function devPrint(...)
        local args = { ... }
        for i = 1, #args do
            if type(args[i]) == "table" then
                args[i] = json.encode(args[i])
            elseif args[i] == nil then
                args[i] = "nil"
            else
                args[i] = tostring(args[i])
            end
        end
        print("^1[DEV MODE] ^4" .. table.concat(args, " ") .. "^0")
    end
else
    function devPrint(...) end
end
function Notify(message, typeOrDuration, maybeDuration)
    local notifyType = "info"
    local notifyDuration = 6000

    -- Detect which argument is which
    if type(typeOrDuration) == "string" then
        notifyType = typeOrDuration
        notifyDuration = tonumber(maybeDuration) or 6000
    elseif type(typeOrDuration) == "number" then
        notifyDuration = typeOrDuration
    end

    if Config.Notify == "feather-menu" then
        FeatherMenu:Notify({
            message = message,
            type = notifyType,
            autoClose = notifyDuration,
            position = "top-center",
            transition = "slide",
            icon = true,
            hideProgressBar = false,
            rtl = false,
            style = {},
            toastStyle = {},
            progressStyle = {}
        })
    elseif Config.Notify == "vorp-core" then
        -- Only message and duration supported
        VORPcore.NotifyRightTip(message, notifyDuration)
    else
        print("^1[Notify] Invalid Config.Notify: " .. tostring(Config.Notify))
    end
end
