-- =====================================================================
-- EX_Tii builder (server): keeps the placed objects in data/builds.json and shares them with everyone
-- (GlobalState.extiBuilds). Only admins can add / remove (/build is admin only and every change is checked).
-- =====================================================================
local FILE = 'data/builds.json'

local function load()
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local ok, d = pcall(json.decode, raw or '')
    if ok and type(d) == 'table' and type(d.list) == 'table' then return d end
    return { nextId = 1, list = {} }
end
local data = load()

local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(data, { indent = true }), -1)
    GlobalState.extiBuilds = data.list
end
GlobalState.extiBuilds = data.list

local function isAdmin(src) return IsPlayerAceAllowed(src, 'command.build') end

local function say(src, text, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform', duration = 5000 })
end

lib.addCommand('build', {
    help = 'Builder (admin): place any GTA object where you look',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('exti_builder:open', source)
end)

local function num(v) v = tonumber(v) return v and v == v and v or nil end   -- (a number, not NaN)
local function r(v, d) local m = 10 ^ d return math.floor(v * m + 0.5) / m end

-- a new object: returns its id
lib.callback.register('exti_builder:add', function(src, model, name, x, y, z, rx, ry, rz)
    if not isAdmin(src) then return false end
    model, x, y, z, rx, ry, rz = num(model), num(x), num(y), num(z), num(rx), num(ry), num(rz)
    if not (model and x and y and z and rx and ry and rz) then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(x, y, z)) > 80.0 then return false end
    if #data.list >= Config.maxObjects then
        say(src, ('وصلت للحد الأقصى (%d قطعة)'):format(Config.maxObjects), 'error')
        return false
    end
    local id = data.nextId
    data.nextId = id + 1
    data.list[#data.list + 1] = {
        id = id, m = math.floor(model), n = type(name) == 'string' and name:sub(1, 64) or nil,
        x = r(x, 3), y = r(y, 3), z = r(z, 3), rx = r(rx, 2), ry = r(ry, 2), rz = r(rz, 2),
    }
    save()
    lib.logger(src, 'builder', ('placed %s (#%d) at %.1f %.1f %.1f'):format(tostring(name or model), id, x, y, z))
    return id
end)

-- remove one (by its id)
lib.callback.register('exti_builder:remove', function(src, id)
    if not isAdmin(src) then return false end
    id = num(id)
    for i, o in ipairs(data.list) do
        if o.id == id then
            if #(GetEntityCoords(GetPlayerPed(src)) - vec3(o.x, o.y, o.z)) > 120.0 then return false end
            table.remove(data.list, i)
            save()
            lib.logger(src, 'builder', ('removed %s (#%d)'):format(tostring(o.n or o.m), id))
            return true
        end
    end
    return false
end)
