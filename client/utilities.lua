function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function round(v) return math.floor(v + 0.5) end

function asPercent(v)
    if v == nil then return 0.0 end
    if v <= 1.0 then return v * 100.0 end
    return clamp(v, 0.0, 100.0)
end

function toCoreState(p) return clamp(round(clamp(p, 0.0, 100.0) * 15.0 / 100.0), 0, 15) end

function toCoreMeter(p) return clamp(round(clamp(p, 0.0, 100.0) * 99.0 / 100.0), 0, 99) end

encodeJson = (json and json.encode) or tostring

function TableToString(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. TableToString(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end
