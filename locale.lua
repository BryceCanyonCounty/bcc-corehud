Locales = Locales or {}

-- Ensure the configured language table exists to avoid runtime errors.
local defaultLang = Config and Config.defaultlang or 'en'
Locales[defaultLang] = Locales[defaultLang] or {}

function _(str, ...) -- Translate string
    local lang = Config and Config.defaultlang or defaultLang

    if Locales[lang] ~= nil then
        if Locales[lang][str] ~= nil then
            return string.format(Locales[lang][str], ...)
        else
            return 'Translation [' .. lang .. '][' .. str .. '] does not exist'
        end
    else
        return 'Locale [' .. lang .. '] does not exist'
    end

end

function _U(str, ...) -- Translate string first char uppercase
	return tostring(_(str, ...):gsub("^%l", string.upper))
end
