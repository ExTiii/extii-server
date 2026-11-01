-- =====================================================================
-- EX_Tii Police (server): the CCTV cameras.
-- The list is built from the city itself: one camera in every shop / bank (behind the counter,
-- looking at the customers: exti_shops), one over the pumps of every gas station (exti_fuel), plus
-- the extra ones in config.lua (stations, hospital...) and the ones admins add with /cctvadd.
-- Admins aim any camera with /cctvspot <n>. Everything saved in data/cctv.json.
-- =====================================================================

local C = Config.cctv
local getPlayer, onDuty, notify = POL.getPlayer, POL.onDuty, POL.notify
local RES = GetCurrentResourceName()
local FILE = 'data/cctv.json'

local saved = { aimed = {}, custom = {} }   -- aimed[key] = { x,y,z,rx,ry,rz }, custom = { { label, area, x,y,z,rx,ry,rz } }
do
    local raw = LoadResourceFile(RES, FILE)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then
        if type(data.aimed) == 'table' or type(data.custom) == 'table' then
            saved.aimed = type(data.aimed) == 'table' and data.aimed or {}
            saved.custom = type(data.custom) == 'table' and data.custom or {}
        else
            -- the first version saved { ["n"] = {...} } for the config cameras
            for k, v in pairs(data) do saved.aimed['cfg:' .. k] = v end
        end
    end
end
local function persist() SaveResourceFile(RES, FILE, json.encode(saved, { indent = true }), -1) end

local function num(v) return tonumber(v) end

-- another resource's config.lua, read as data (no side effects: it only fills a Config table)
local function readConfig(resource)
    local code = LoadResourceFile(resource, 'config.lua')
    if not code then return nil end
    local env = setmetatable({ Config = {} }, { __index = _G })
    local fn = load(code, '@' .. resource .. '/config.lua', 't', env)
    if not fn then return nil end
    local ok, err = pcall(fn)
    if not ok then lib.print.warn(('[cctv] %s/config.lua stopped early (%s): using what it set before that'):format(resource, tostring(err))) end
    return next(env.Config) and env.Config or nil
end

-- the camera's yaw so that it looks from `from` towards `to` (GTA heading: 0 = north, counter-clockwise)
local function yawTowards(from, to)
    local dx, dy = to.x - from.x, to.y - from.y
    return math.deg(math.atan(-dx, dy))
end

-- the places: from the running resource (export) when it is up, else from its config file
local function stores()
    if GetResourceState('exti_shops') == 'started' then
        local ok, list, types = pcall(function() return exports.exti_shops:Stores() end)
        if ok and type(list) == 'table' then return list, types end
    end
    local ok, cfg = pcall(readConfig, 'exti_shops')
    if ok and type(cfg) == 'table' and type(cfg.stores) == 'table' then return cfg.stores, cfg.types end
    lib.print.warn('[cctv] could not read the shops (exti_shops): no shop / bank cameras')
    return nil
end

local function stations()
    if GetResourceState('exti_fuel') == 'started' then
        local ok, list = pcall(function() return exports.exti_fuel:Stations() end)
        if ok and type(list) == 'table' then return list end
    end
    local ok, cfg = pcall(readConfig, 'exti_fuel')
    if ok and type(cfg) == 'table' and type(cfg.stations) == 'table' then return cfg.stations end
    lib.print.warn('[cctv] could not read the gas stations (exti_fuel): no pump cameras')
    return nil
end

local function shopCameras()
    local out = {}
    local list, typesList = stores()
    if not list then return out end
    local types = type(typesList) == 'table' and typesList or {}
    for _, s in ipairs(list) do
        local t = types[s.type]
        local c = s.clerk
        if t and type(c) == 'table' and num(c.x) and (C.shopTypes == nil or C.shopTypes[s.type]) then
            -- behind and above the clerk, looking the way he looks: the counter and the whole floor
            local h = math.rad(num(c.w) or 0.0)
            local fx, fy = -math.sin(h), math.cos(h)
            local back = C.shopBack or 1.6
            local pos = vec3(c.x - fx * back, c.y - fy * back, c.z + (C.shopHeight or 2.3))
            out[#out + 1] = {
                key = ('shop:%s:%s'):format(s.type, s.area or ''),
                label = ('%s · %s'):format(t.label or s.type, s.area or ''), area = s.area or '', kind = s.type == 'bank' and 'bank' or 'shop',
                coords = pos, rot = vec3(C.shopPitch or -22.0, 0.0, num(c.w) or 0.0),
            }
        end
    end
    return out
end

local function fuelCameras()
    local out = {}
    local list = stations()
    if not list then return out end
    for _, st in ipairs(list) do
        local center = st.center
        if type(center) == 'table' and num(center.x) then
            -- on the far side of the pumps, up on the canopy, looking back over all of them
            local far, farD = nil, 0
            for _, p in ipairs(st.pumps or {}) do
                local d = #(vec3(p.x, p.y, p.z) - vec3(center.x, center.y, center.z))
                if d > farD then far, farD = p, d end
            end
            local dx, dy = 0.0, 1.0
            if far and farD > 0.5 then dx, dy = (center.x - far.x) / farD, (center.y - far.y) / farD end
            local dist = math.max(C.fuelDistance or 11.0, farD + 4.0)
            local pos = vec3(center.x + dx * dist, center.y + dy * dist, center.z + (C.fuelHeight or 5.5))
            out[#out + 1] = {
                key = ('fuel:%s'):format(tostring(st.id)),
                label = ('محطة وقود · %s'):format((st.label or ''):gsub('%s*%(.-%)%s*$', '')), area = (st.label or ''):gsub('%s*%(.-%)%s*$', ''), kind = 'fuel',
                coords = pos, rot = vec3(C.fuelPitch or -28.0, 0.0, yawTowards(pos, center)),
            }
        end
    end
    return out
end

local cameras = {}
local function build()
    local list = {}
    for i, cam in ipairs(C.cameras) do
        list[#list + 1] = { key = 'cfg:' .. i, label = cam.label, area = cam.area, kind = cam.kind or 'city', coords = cam.coords, rot = cam.rot }
    end
    for _, c in ipairs(shopCameras()) do list[#list + 1] = c end
    for _, c in ipairs(fuelCameras()) do list[#list + 1] = c end
    for i, c in ipairs(saved.custom) do
        if num(c.x) then
            list[#list + 1] = { key = 'custom:' .. i, label = c.label or ('كاميرا %d'):format(i), area = c.area or '', kind = 'custom',
                                coords = vec3(num(c.x), num(c.y), num(c.z)), rot = vec3(num(c.rx) or -20.0, num(c.ry) or 0.0, num(c.rz) or 0.0) }
        end
    end
    -- what admins aimed wins
    for _, c in ipairs(list) do
        local s = saved.aimed[c.key]
        if type(s) == 'table' and num(s.x) and num(s.y) and num(s.z) then
            c.coords = vec3(num(s.x), num(s.y), num(s.z))
            c.rot = vec3(num(s.rx) or c.rot.x, num(s.ry) or c.rot.y, num(s.rz) or c.rot.z)
            c.aimed = true
        end
    end
    cameras = list
    GlobalState.exti_police_cctv = cameras
    lib.print.info(('[cctv] %d cameras'):format(#cameras))
end
-- exti_shops / exti_fuel may start after us
build()
CreateThread(function()
    Wait(3000)
    build()
    Wait(15000)
    build()
end)
AddEventHandler('onResourceStart', function(res)
    if res == 'exti_shops' or res == 'exti_fuel' then SetTimeout(1000, build) end
end)

local function isAdmin(src) return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command.cctvspot') end

-- /cctvspot <n> [reset]: the camera n goes where you are looking from (aim with your own camera first)
lib.addCommand('cctvspot', {
    help = 'نقل كاميرا المراقبة رقم n إلى زاوية نظرك الحالية؛ reset يرجعها (للإدارة)',
    params = {
        { name = 'n', type = 'number', help = 'رقم الكاميرا (من التابلت)' },
        { name = 'reset', type = 'string', help = 'reset = إرجاعها إلى مكانها الأصلي', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local n = math.tointeger(tonumber(args.n))
    local cam = n and cameras[n]
    if not cam then return notify(source, 'error', ('الكاميرات من 1 إلى %d'):format(#cameras)) end
    if args.reset == 'reset' then
        saved.aimed[cam.key] = nil
        persist()
        build()
        return notify(source, 'success', ('رجعت الكاميرا %d إلى مكانها الأصلي'):format(n))
    end
    TriggerClientEvent('exti_police:client:cctvAsk', source, n)
end)

-- /cctvadd <label...>: a new camera where you are looking from
lib.addCommand('cctvadd', {
    help = 'كاميرا مراقبة جديدة بزاوية نظرك الحالية (للإدارة)',
    params = { { name = 'label', type = 'string', help = 'اسم الكاميرا (مثال: مدخل المطار)' } },
    restricted = 'group.admin',
}, function(source, args, raw)
    local label = (raw or ''):gsub('^/?cctvadd%s*', ''):match('^%s*(.-)%s*$')
    if label == '' then label = args.label end
    if not label or label == '' then return notify(source, 'error', '/cctvadd <اسم الكاميرا>') end
    TriggerClientEvent('exti_police:client:cctvAsk', source, 0, label:sub(1, 40))
end)

-- /cctvdel <n>: remove a camera added with /cctvadd
lib.addCommand('cctvdel', {
    help = 'حذف كاميرا أضافها الأدمن بـ /cctvadd (للإدارة)',
    params = { { name = 'n', type = 'number', help = 'رقم الكاميرا (من التابلت)' } },
    restricted = 'group.admin',
}, function(source, args)
    local n = math.tointeger(tonumber(args.n))
    local cam = n and cameras[n]
    if not cam then return notify(source, 'error', ('الكاميرات من 1 إلى %d'):format(#cameras)) end
    local idx = tonumber(cam.key:match('^custom:(%d+)$'))
    if not idx then return notify(source, 'error', 'هذه كاميرا أساسية: استعمل /cctvspot لتعديلها فقط') end
    table.remove(saved.custom, idx)
    -- the aimed overrides of the custom ones shift with them
    local aimed = {}
    for k, v in pairs(saved.aimed) do
        local i = tonumber(k:match('^custom:(%d+)$'))
        if not i then aimed[k] = v elseif i < idx then aimed[k] = v elseif i > idx then aimed['custom:' .. (i - 1)] = v end
    end
    saved.aimed = aimed
    persist()
    build()
    notify(source, 'success', ('حُذفت الكاميرا "%s"'):format(cam.label))
end)

RegisterNetEvent('exti_police:server:cctvPlace', function(n, pos, rot, label)
    local src = source
    if not isAdmin(src) then return end
    n = math.tointeger(tonumber(n))
    if not n or type(pos) ~= 'table' or type(rot) ~= 'table' then return end
    if not (num(pos.x) and num(pos.y) and num(pos.z) and num(rot.x) and num(rot.z)) then return end
    local entry = { x = num(pos.x), y = num(pos.y), z = num(pos.z), rx = num(rot.x), ry = num(rot.y) or 0.0, rz = num(rot.z) }
    if n == 0 then
        if type(label) ~= 'string' or label == '' then return end
        entry.label = label:sub(1, 40)
        saved.custom[#saved.custom + 1] = entry
        persist()
        build()
        lib.print.info(('[cctv] camera "%s" added by %s'):format(entry.label, GetPlayerName(src) or src))
        return notify(src, 'success', ('أُضيفت الكاميرا "%s" (رقم %d)'):format(entry.label, #cameras))
    end
    local cam = cameras[n]
    if not cam then return end
    saved.aimed[cam.key] = entry
    persist()
    build()
    lib.print.info(('[cctv] camera %d (%s) aimed by %s'):format(n, cam.key, GetPlayerName(src) or src))
    notify(src, 'success', ('حُفظت الكاميرا %d بزاوية نظرك'):format(n))
end)

-- the tablet's list
lib.callback.register('exti_police:server:tab_cctv', function(source)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local out = {}
    for i, c in ipairs(cameras) do out[i] = { id = i, label = c.label, area = c.area, kind = c.kind, x = c.coords.x, y = c.coords.y } end
    return { cameras = out }
end)
