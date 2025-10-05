hm, tm = 1.0, 1.0
local ACTIVITY_MIN, ACTIVITY_MAX = 0.1, 3.0

local activityDefaults = {
    idle   = { hunger = 0.70, thirst = 0.75 },
    walk   = { hunger = 1.00, thirst = 1.10 },
    run    = { hunger = 1.25, thirst = 1.60 },
    sprint = { hunger = 1.50, thirst = 2.20 },
    coast  = { hunger = 0.85, thirst = 0.90 },
    swim   = { hunger = 1.40, thirst = 2.20 }
}

local activityConfig = type(Config.ActivityMultipliers) == 'table' and Config.ActivityMultipliers or {}

local function getActivityMultiplier(name)
	local conf = activityConfig[name]
	local def = activityDefaults[name]
	local hunger, thirst
	if type(conf) == 'table' then
		hunger = tonumber(conf.hunger)
		thirst = tonumber(conf.thirst)
	end
	if not hunger and def then hunger = def.hunger end
	if not thirst and def then thirst = def.thirst end
	if not hunger then hunger = 1.0 end
	if not thirst then thirst = 1.0 end
	return hunger, thirst
end
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

function normalizeActivityMultipliers()
    hm = clamp(hm, ACTIVITY_MIN, ACTIVITY_MAX)
    tm = clamp(tm, ACTIVITY_MIN, ACTIVITY_MAX)
end

local function applyActivity(name)
	local hMult, tMult = getActivityMultiplier(name)
	hm = clamp(hMult, ACTIVITY_MIN, ACTIVITY_MAX)
	tm = clamp(tMult, ACTIVITY_MIN, ACTIVITY_MAX)
end

function idle()   applyActivity('idle') end
function walk()   applyActivity('walk') end
function run()    applyActivity('run') end
function sprint() applyActivity('sprint') end
function coast()  applyActivity('coast') end
function swim()   applyActivity('swim') end

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
