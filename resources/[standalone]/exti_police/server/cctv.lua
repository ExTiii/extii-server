-- =====================================================================
-- EX_Tii Police (server): the CCTV cameras. config.lua + what admins aimed with /cctvspot
-- (data/cctv.json), shared in GlobalState for the tablet and the viewer.
-- =====================================================================

local C = Config.cctv
local getPlayer, onDuty, notify = POL.getPlayer, POL.onDuty, POL.notify
local RES = GetCurrentResourceName()
local FILE = 'data/cctv.json'

local saved = {}
do
    local raw = LoadResourceFile(RES, FILE)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then saved = data end
end

local function num(v) return tonumber(v) end
local cameras = {}
local function build()
    cameras = {}
    for i, cam in ipairs(C.cameras) do
        local s = saved[tostring(i)]
        local c = { label = cam.label, area = cam.area, coords = cam.coords, rot = cam.rot }
        if type(s) == 'table' and num(s.x) and num(s.y) and num(s.z) then
            c.coords = vec3(num(s.x), num(s.y), num(s.z))
            c.rot = vec3(num(s.rx) or cam.rot.x, num(s.ry) or cam.rot.y, num(s.rz) or cam.rot.z)
        end
        cameras[i] = c
    end
    GlobalState.exti_police_cctv = cameras
end
build()

-- /cctvspot <n>: the camera n goes where you are looking from (aim with your own camera first)
lib.addCommand('cctvspot', {
    help = 'نقل كاميرا المراقبة رقم n إلى زاوية نظرك الحالية (للإدارة)',
    params = {
        { name = 'n', type = 'number', help = 'رقم الكاميرا (من التابلت)' },
        { name = 'reset', type = 'string', help = 'reset = إرجاعها إلى config.lua', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local n = math.tointeger(tonumber(args.n))
    if not n or not C.cameras[n] then return notify(source, 'error', ('الكاميرات من 1 إلى %d'):format(#C.cameras)) end
    if args.reset == 'reset' then
        saved[tostring(n)] = nil
    else
        -- the officer's game sends his camera position and rotation
        TriggerClientEvent('exti_police:client:cctvAsk', source, n)
        return
    end
    SaveResourceFile(RES, FILE, json.encode(saved, { indent = true }), -1)
    build()
    notify(source, 'success', ('رجعت الكاميرا %d إلى مكانها الأصلي'):format(n))
end)

RegisterNetEvent('exti_police:server:cctvPlace', function(n, pos, rot)
    local src = source
    if not IsPlayerAceAllowed(src, 'group.admin') and not IsPlayerAceAllowed(src, 'command.cctvspot') then return end
    n = math.tointeger(tonumber(n))
    if not n or not C.cameras[n] or type(pos) ~= 'table' or type(rot) ~= 'table' then return end
    if not (num(pos.x) and num(pos.y) and num(pos.z) and num(rot.x) and num(rot.z)) then return end
    saved[tostring(n)] = { x = num(pos.x), y = num(pos.y), z = num(pos.z), rx = num(rot.x), ry = num(rot.y) or 0.0, rz = num(rot.z) }
    SaveResourceFile(RES, FILE, json.encode(saved, { indent = true }), -1)
    build()
    lib.print.info(('[cctvspot] camera %d moved by %s'):format(n, GetPlayerName(src) or src))
    notify(src, 'success', ('حُفظت الكاميرا %d بزاوية نظرك'):format(n))
end)

-- the tablet's list
lib.callback.register('exti_police:server:tab_cctv', function(source)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local out = {}
    for i, c in ipairs(cameras) do out[i] = { id = i, label = c.label, area = c.area, x = c.coords.x, y = c.coords.y } end
    return { cameras = out }
end)
