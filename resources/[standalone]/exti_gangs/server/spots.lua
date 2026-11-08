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
        -- an admin's spot is for that day only (the fence moves every day)
        if type(data.fenceAdmin) == 'table' and data.fenceAdmin.day then
            spots.fenceAdmin = { day = tostring(data.fenceAdmin.day), x = data.fenceAdmin.x, y = data.fenceAdmin.y, z = data.fenceAdmin.z, h = data.fenceAdmin.h }
        end
        spots.blackmarket = pos4(data.blackmarket)
        -- the fence's daily spots, edited in game with /fencespots (else the list in config.lua)
        if type(data.fenceList) == 'table' then
            local list = {}
            for _, d in ipairs(data.fenceList) do local p = pos4(d); if p then p.label = type(d.label) == 'string' and d.label or nil; list[#list + 1] = p end end
            if #list > 0 then spots.fenceList = list end
        end
    end
end
GANG.spots = spots

-- where the fence is today
local function fenceToday()
    local day = os.date('%Y-%m-%d')
    local a = spots.fenceAdmin
    if a and a.day == day and num(a.x) then return { x = a.x, y = a.y, z = a.z, h = num(a.h) and a.h or 0.0 } end
    local list = GANG.fenceList()
    if #list == 0 then return nil end
    local p = list[(tonumber(os.date('%j')) + tonumber(os.date('%Y'))) % #list + 1]
    return { x = p.x, y = p.y, z = p.z, h = p.h, snap = true }
end
-- the daily spots: { x, y, z, h, label }
function GANG.fenceList()
    if spots.fenceList and #spots.fenceList > 0 then return spots.fenceList end
    local out = {}
    for i, p in ipairs(C.fence.spots or {}) do out[i] = { x = p.x, y = p.y, z = p.z, h = p.w or 0.0 } end
    return out
end
GANG.fenceToday = fenceToday

local function publish()
    spots.fence = fenceToday()
    GlobalState['exti_gangs:spots'] = spots
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(spots, { indent = true }), -1)
end
spots.fence = fenceToday()
GlobalState['exti_gangs:spots'] = spots
GANG.publishSpots = publish
-- a new day: he moves
CreateThread(function()
    local last = spots.fence and ('%.1f,%.1f'):format(spots.fence.x, spots.fence.y)
    while true do
        Wait(5 * 60 * 1000)
        local f = fenceToday()
        local now = f and ('%.1f,%.1f'):format(f.x, f.y)
        if now ~= last then last = now; publish() end
    end
end)

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
        if GANG.weedPotRemoved then GANG.weedPotRemoved(a, nil) end
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
        spots.fenceAdmin = { day = os.date('%Y-%m-%d'), x = here.x, y = here.y, z = here.z, h = here.h }
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


---------------------------------------------------------------------------
-- /fencespots (admins): the fence's daily spots. Add one where you stand, remove one, go to one,
-- or put him where you stand for today only. Saved in data/spots.json (wins over config.lua).
---------------------------------------------------------------------------
local function fenceMenu(source)
    local list = GANG.fenceList()
    local f = fenceToday()
    local out = {}
    for i, p in ipairs(list) do
        out[i] = { x = p.x, y = p.y, z = p.z, h = p.h, label = p.label, today = f ~= nil and math.abs(f.x - p.x) < 0.5 and math.abs(f.y - p.y) < 0.5 }
    end
    TriggerClientEvent('exti_gangs:client:fenceSpots', source, out, spots.fenceAdmin and spots.fenceAdmin.day == os.date('%Y-%m-%d'))
end
lib.addCommand('fencespots', { help = 'أماكن المصرّف اليومية (للإدارة)', restricted = 'group.admin' }, function(source) fenceMenu(source) end)

lib.callback.register('exti_gangs:server:fenceSpots', function(source, what, i, label)
    if not isAdmin(source) then return false end
    local ped = GetPlayerPed(source)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    -- the first change copies the config list, then the copy is what counts
    if not spots.fenceList then spots.fenceList = GANG.fenceList() end
    local list = spots.fenceList
    local msg
    if what == 'add' then
        if #list >= 30 then return false, 'الحد 30 مكانًا' end
        list[#list + 1] = { x = c.x, y = c.y, z = c.z, h = h, label = type(label) == 'string' and label:sub(1, 40) or nil }
        msg = ('أُضيف المكان رقم %d'):format(#list)
    elseif what == 'remove' then
        i = math.tointeger(i)
        if not i or not list[i] then return false end
        if #list <= 1 then return false, 'لا بد من مكان واحد على الأقل' end
        table.remove(list, i)
        msg = 'حُذف المكان'
    elseif what == 'move' then
        i = math.tointeger(i)
        if not i or not list[i] then return false end
        list[i] = { x = c.x, y = c.y, z = c.z, h = h, label = list[i].label }
        msg = ('نُقل المكان رقم %d إلى حيث تقف'):format(i)
    elseif what == 'today' then
        spots.fenceAdmin = { day = os.date('%Y-%m-%d'), x = c.x, y = c.y, z = c.z, h = h }
        msg = 'المصرّف هنا اليوم فقط'
    elseif what == 'today_clear' then
        spots.fenceAdmin = nil
        msg = 'رجع المصرّف لمكان اليوم من القائمة'
    else
        return false
    end
    publish()
    GANG.log('-', GANG.charName(GANG.player(source)), 'fence_' .. what, tostring(i or ''))
    SetTimeout(200, function() fenceMenu(source) end)
    return true, msg
end)
