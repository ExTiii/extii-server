-- =====================================================================
-- EX_Tii gangs: places set in game by an admin with /gangspots (saved in data/spots.json)
--   hq[gang] = { laptop, stash, deposit, locker, bench, garage, door_out (outside), door_in (inside) }
--   collect  = { crates = { {x,y,z,h}, ... } }   (the shared collection point)
--   fence    = { x, y, z, h }                     (buys stolen parts)
-- =====================================================================
local FILE = 'data/spots.json'
local KINDS = { laptop = true, stash = true, deposit = true, locker = true, bench = true, garage = true, door_out = true, door_in = true, dropbox = true, washer = true, press = true, workbench = true, weedtable = true }
local MAX_CRATES = 12

local function num(v) return type(v) == 'number' and v == v and v > -20000 and v < 20000 end
local function pos4(t) if type(t) == 'table' and num(t.x) and num(t.y) and num(t.z) then return { x = t.x, y = t.y, z = t.z, h = num(t.h) and t.h or 0.0 } end end

local spots = { hq = {}, collect = { crates = {} }, fence = nil }
do
    local ok, data = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), FILE) or '')
    if ok and type(data) == 'table' then
        for gang, set in pairs(type(data.hq) == 'table' and data.hq or {}) do
            if type(gang) == 'string' and type(set) == 'table' then
                spots.hq[gang] = {}
                for k, v in pairs(set) do if KINDS[k] then spots.hq[gang][k] = pos4(v) end end
                -- real doors: { x, y, z, model }
                if type(set.doors) == 'table' then
                    local list = {}
                    for _, d in ipairs(set.doors) do
                        local p = pos4(d)
                        local mdl = math.tointeger(tonumber(d.model))
                        if p and mdl and #list < C.realDoor.max then p.model = mdl; list[#list + 1] = p end
                    end
                    if #list > 0 then spots.hq[gang].doors = list end
                end
                -- weed pots: { x, y, z, h }
                if type(set.pots) == 'table' then
                    local list = {}
                    for _, d in ipairs(set.pots) do local p = pos4(d); if p and #list < C.weed.pots then list[#list + 1] = p end end
                    if #list > 0 then spots.hq[gang].pots = list end
                end
            end
        end
        for _, c in ipairs(type(data.collect) == 'table' and type(data.collect.crates) == 'table' and data.collect.crates or {}) do
            local p = pos4(c); if p and #spots.collect.crates < MAX_CRATES then spots.collect.crates[#spots.collect.crates + 1] = p end
        end
        spots.fence = pos4(data.fence)
        spots.blackmarket = pos4(data.blackmarket)
    end
end
GANG.spots = spots

local function publish()
    GlobalState['exti_gangs:spots'] = spots
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(spots, { indent = true }), -1)
end
GlobalState['exti_gangs:spots'] = spots
GANG.publishSpots = publish

function GANG.spot(g, kind)
    local set = spots.hq[g.name]
    return set and set[kind] or nil
end

local function isAdmin(src) return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command') end

lib.addCommand('gangspots', { help = 'وضع أماكن العصابات (المقرات ونقطة الجمع والمصرّف)', restricted = 'group.admin' }, function(source)
    local list = {}
    for name, g in pairs(GANG.gangs) do list[#list + 1] = { name = name, label = g.label, type = g.type } end
    TriggerClientEvent('exti_gangs:client:spotsMenu', source, list)
end)

-- what: 'hq' (gang, kind) | 'crate_add' | 'crate_remove' (index) | 'crates_clear' | 'fence' | 'hq_clear' (gang)
lib.callback.register('exti_gangs:server:spotSave', function(source, what, a, b)
    if not isAdmin(source) then return false end
    local ped = GetPlayerPed(source)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local here = { x = c.x, y = c.y, z = c.z, h = h }
    if what == 'hq' then
        if not GANG.gangs[a] or not KINDS[b] then return false end
        spots.hq[a] = spots.hq[a] or {}
        spots.hq[a][b] = here
        if b == 'stash' then GANG.registerStash(GANG.gangs[a]) end
    elseif what == 'hq_clear' then
        if type(a) ~= 'string' then return false end
        spots.hq[a] = nil
    elseif what == 'crate_add' then
        if #spots.collect.crates >= MAX_CRATES then return false, 'max' end
        spots.collect.crates[#spots.collect.crates + 1] = here
    elseif what == 'crate_remove' then
        local i = math.type(a) == 'integer' and a or nil
        if not i or not spots.collect.crates[i] then return false end
        table.remove(spots.collect.crates, i)
    elseif what == 'crates_clear' then
        spots.collect.crates = {}
    elseif what == 'fence' then
        spots.fence = here
    elseif what == 'blackmarket' then
        spots.blackmarket = here
    elseif what == 'pot_add' then
        if not GANG.gangs[a] then return false end
        spots.hq[a] = spots.hq[a] or {}
        local list = spots.hq[a].pots or {}
        if #list >= C.weed.pots then return false, 'max' end
        list[#list + 1] = here
        spots.hq[a].pots = list
    elseif what == 'pot_remove' then
        local list = spots.hq[a] and spots.hq[a].pots
        local i = math.type(b) == 'integer' and b or nil
        if not list or not i or not list[i] then return false end
        table.remove(list, i)
        if GANG.weedPotRemoved then GANG.weedPotRemoved(a, i) end
    elseif what == 'pots_clear' then
        if spots.hq[a] then spots.hq[a].pots = nil end
        if GANG.weedPotRemoved then GANG.weedPotRemoved(a, nil) end
    else
        return false
    end
    publish()
    GANG.log(type(a) == 'string' and a or '-', GANG.charName(GANG.player(source)), 'spot_' .. what, type(b) == 'string' and b or '')
    return true
end)
