-- =====================================================================
-- EX_Tii Police (server): the locked doors in the stations (the armory). Locked for everyone;
-- an officer of the right rank, on duty, unlocks / locks with E; they lock again by themselves.
-- The state and the places live in GlobalState.exti_police_doors; admins move a door with /policedoor.
-- =====================================================================

local getPlayer, onDuty, grade, notify, nameOf = POL.getPlayer, POL.onDuty, POL.grade, POL.notify, POL.nameOf
local RES = GetCurrentResourceName()
local FILE = 'data/doors.json'

local moved = {}   -- [id] = { x, y, z } from /policedoor
do
    local ok, data = pcall(json.decode, LoadResourceFile(RES, FILE) or '')
    if ok and type(data) == 'table' then moved = data end
end

local doors = {}       -- [id] = { id, label, model, coords, minGrade, minGradeLabel, autoLock, locked }
local order = {}
local function publish()
    local out = {}
    for _, id in ipairs(order) do
        local d = doors[id]
        out[#out + 1] = { id = d.id, label = d.label, model = d.model, x = d.coords.x, y = d.coords.y, z = d.coords.z,
                          minGrade = d.minGrade, minGradeLabel = d.minGradeLabel, locked = d.locked }
    end
    GlobalState.exti_police_doors = out
end

for _, cfg in ipairs(Config.doors or {}) do
    local c = cfg.coords
    local m = moved[cfg.id]
    if type(m) == 'table' and tonumber(m.x) then c = vec3(tonumber(m.x), tonumber(m.y), tonumber(m.z)) end
    doors[cfg.id] = { id = cfg.id, label = cfg.label, model = cfg.model, coords = c, minGrade = cfg.minGrade or 0,
                      minGradeLabel = cfg.minGradeLabel, autoLock = cfg.autoLock or 0, locked = true, timer = 0 }
    order[#order + 1] = cfg.id
end
publish()

local function setLocked(d, locked, src)
    d.locked = locked
    d.timer = d.timer + 1
    publish()
    if not locked and d.autoLock > 0 then
        local my = d.timer
        SetTimeout(d.autoLock * 1000, function()
            if d.timer == my and not d.locked then
                d.locked = true
                publish()
            end
        end)
    end
end

-- E at the door
RegisterNetEvent('exti_police:server:door', function(id)
    local src = source
    local d = doors[id]
    local player = getPlayer(src)
    if not d or not player then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - d.coords) > 4.0 then return end
    if not onDuty(player) then return notify(src, 'error', 'الباب مقفل: للشرطة في الدوام فقط') end
    if grade(player) < d.minGrade then
        return notify(src, 'error', ('الباب مقفل: من رتبة %s فما فوق'):format(d.minGradeLabel or tostring(d.minGrade)))
    end
    setLocked(d, not d.locked, src)
    notify(src, d.locked and 'inform' or 'success', d.locked and ('أقفلت %s'):format(d.label) or ('فتحت %s · يُقفل وحده بعد %d ثانية'):format(d.label, d.autoLock))
    POL.log(src, d.locked and 'door_locked' or 'door_unlocked', d.label)
end)

-- /policedoor <id>: the door is where you stand (the game finds the door object next to you)
lib.addCommand('policedoor', {
    help = 'نقل باب مقفل إلى مكانك (للإدارة)',
    params = { { name = 'id', type = 'string', help = table.concat(order, ' / ') } },
    restricted = 'group.admin',
}, function(source, args)
    local d = doors[args.id]
    if not d then return notify(source, 'error', 'الأبواب: ' .. table.concat(order, ' / ')) end
    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    d.coords = vec3(c.x, c.y, c.z)
    moved[d.id] = { x = c.x, y = c.y, z = c.z }
    SaveResourceFile(RES, FILE, json.encode(moved, { indent = true }), -1)
    publish()
    notify(source, 'success', ('حُفظ مكان %s'):format(d.label))
end)
