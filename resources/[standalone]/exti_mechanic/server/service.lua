-- =====================================================================
-- EX_Tii Mechanic (server): SERVICE — the wear of every car, the diagnostics, the repairs (each
-- with its own mini-game on the mechanic's screen), wash and wax, and the repair kits rule.
--
-- How the wear works:
--  * the driver's game sends the distance it drove every few seconds; the server checks it (no
--    teleport-sized jumps) and takes a little off every part (Config.service.components[].life)
--  * cars people own and job cars (police / EMS / mechanic fleets) are saved in the database by
--    plate; a street car keeps its condition while the server runs
--  * the condition rides on the car (state bag exti_wear) so the driver's game can make the car
--    misbehave (weak brakes, stuck in first gear, smoke, a dead engine, burst tires…)
--  * only an on-duty mechanic next to the car, holding the part, can replace it, and only after
--    playing the repair's mini-game; the part is used up and the repair goes into the car's history
-- =====================================================================

local S = Config.service
local JOB = Config.job
local getPlayer, onDuty, nameOf, notify, pedOf = MEC.getPlayer, MEC.onDuty, MEC.nameOf, MEC.notify, MEC.pedOf

local COMP, ORDER = {}, {}
for i, c in ipairs(S.components) do COMP[c.id] = c ORDER[i] = c.id end
local RES = GetCurrentResourceName()

---------------------------------------------------------------------------
-- tables
---------------------------------------------------------------------------
local ready = false
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_wear` (
        `plate` VARCHAR(12) NOT NULL PRIMARY KEY,
        `model` VARCHAR(40) NULL,
        `ev` TINYINT NOT NULL DEFAULT 0,
        `km` DOUBLE NOT NULL DEFAULT 0,
        `data` LONGTEXT NOT NULL,
        `wax` INT NULL,
        `updated` INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_service` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `plate` VARCHAR(12) NOT NULL,
        `at` INT NOT NULL,
        `citizenid` VARCHAR(50) NULL,
        `name` VARCHAR(80) NULL,
        `what` VARCHAR(120) NOT NULL,
        `km` INT NULL,
        INDEX `plate_at` (`plate`, `at`)
    ) DEFAULT CHARSET=utf8mb4]])
    ready = true
end)

---------------------------------------------------------------------------
-- the records: [plate] = { plate, model, ev, km, c = { [id] = 0..100 }, persist, dirty, wax }
---------------------------------------------------------------------------
local wear = {}

local function plateOf(veh)
    local p = GetVehicleNumberPlateText(veh)
    p = p and p:gsub('^%s+', ''):gsub('%s+$', ''):upper() or nil
    return p ~= '' and p or nil
end

local function partsFor(ev)
    local list = {}
    for _, id in ipairs(ORDER) do
        local c = COMP[id]
        if (ev and c.ev) or (not ev and c.ice) then list[#list + 1] = id end
    end
    return list
end

-- a plate that belongs to a player or to a job fleet is saved; anything else only lives in memory
local persistCache = {}
local function persists(plate)
    if persistCache[plate] ~= nil then return persistCache[plate] end
    local found = false
    local okP, row = pcall(function() return MySQL.scalar.await('SELECT 1 FROM `player_vehicles` WHERE `plate` = ? OR TRIM(`plate`) = ? LIMIT 1', { plate, plate }) end)
    if okP and row then found = true end
    if not found then
        for _, t in ipairs({ 'exti_mechanic_fleet', 'exti_police_fleet', 'exti_ems_fleet' }) do
            local ok, r = pcall(function() return MySQL.scalar.await(('SELECT 1 FROM `%s` WHERE `plate` = ? LIMIT 1'):format(t), { plate }) end)
            if ok and r then found = true break end
        end
    end
    persistCache[plate] = found
    return found
end

local function newRecord(plate, model, ev, persist)
    local rec = { plate = plate, model = model, ev = ev == true, km = 0.0, c = {}, persist = persist, dirty = persist }
    for _, id in ipairs(partsFor(rec.ev)) do
        if persist then
            rec.c[id] = 100.0
        else
            rec.c[id] = math.random(S.streetStart[1], S.streetStart[2]) + 0.0
        end
    end
    return rec
end

local function loadRecord(plate, model, ev)
    local rec = wear[plate]
    if rec then
        -- the car type may only be known later (the first driver's game tells)
        if ev ~= nil and rec.ev ~= (ev == true) and rec.km < 1 then
            local fresh = newRecord(plate, rec.model or model, ev, rec.persist)
            wear[plate] = fresh
            return fresh
        end
        return rec
    end
    local persist = persists(plate)
    if persist then
        local row = MySQL.single.await('SELECT * FROM `exti_mechanic_wear` WHERE `plate` = ?', { plate })
        if row then
            local ok, data = pcall(json.decode, row.data or '')
            rec = { plate = plate, model = row.model or model, ev = tonumber(row.ev) == 1, km = tonumber(row.km) or 0.0,
                c = {}, persist = true, dirty = false, wax = tonumber(row.wax) }
            for _, id in ipairs(partsFor(rec.ev)) do
                local v = ok and type(data) == 'table' and tonumber(data[id]) or nil
                rec.c[id] = v and math.max(0.0, math.min(100.0, v)) or 100.0
            end
            wear[plate] = rec
            return rec
        end
    end
    rec = newRecord(plate, model, ev, persist)
    wear[plate] = rec
    return rec
end

local function save(rec)
    if not rec.persist then rec.dirty = false return end
    local data = {}
    for id, v in pairs(rec.c) do data[id] = math.floor(v * 10 + 0.5) / 10 end
    MySQL.query('INSERT INTO `exti_mechanic_wear` (`plate`, `model`, `ev`, `km`, `data`, `wax`, `updated`) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `model` = VALUES(`model`), `ev` = VALUES(`ev`), `km` = VALUES(`km`), `data` = VALUES(`data`), `wax` = VALUES(`wax`), `updated` = VALUES(`updated`)',
        { rec.plate, rec.model, rec.ev and 1 or 0, math.floor(rec.km * 100) / 100, json.encode(data), rec.wax, os.time() })
    rec.dirty = false
end

CreateThread(function()
    while true do
        Wait((S.saveEvery or 60) * 1000)
        for _, rec in pairs(wear) do if rec.dirty then save(rec) end end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RES then return end
    for _, rec in pairs(wear) do if rec.dirty then save(rec) end end
end)

-- what rides on the car for everyone's game (whole numbers keep it small)
local function compact(rec)
    local c = {}
    for id, v in pairs(rec.c) do c[id] = math.floor(v + 0.5) end
    return { ev = rec.ev, km = math.floor(rec.km), c = c, wax = rec.wax }
end

local function publish(veh, rec)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        Entity(veh).state:set('exti_wear', compact(rec), true)
    end
end

local function vehicleOf(netId)
    netId = math.tointeger(tonumber(netId))
    if not netId then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

---------------------------------------------------------------------------
-- the driver's game
---------------------------------------------------------------------------
-- getting in: the car's condition (made the first time it is seen)
lib.callback.register('exti_mechanic:server:wearSync', function(source, netId, ev, model)
    if not ready then return false end
    local veh = vehicleOf(netId)
    if not veh then return false end
    local plate = plateOf(veh)
    if not plate then return false end
    local rec = loadRecord(plate, type(model) == 'string' and model:sub(1, 40) or nil, ev == true)
    publish(veh, rec)
    -- the nitro and the swapped engine ride on the car too
    if MEC.carModsPublish then pcall(MEC.carModsPublish, veh, plate) end
    return compact(rec)
end)

-- the distance driven since the last report (metres; fast = metres above the "hard driving" speed)
local lastReport = {}
RegisterNetEvent('exti_mechanic:server:wearDrive', function(netId, meters, fast)
    local src = source
    if not ready then return end
    local veh = vehicleOf(netId)
    local ped = pedOf(src)
    if not veh or not ped or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    local now = os.time()
    local dt = now - (lastReport[src] or (now - (S.reportEvery or 20)))
    lastReport[src] = now
    dt = math.max(1, math.min(dt, 120))
    meters = tonumber(meters) or 0
    fast = tonumber(fast) or 0
    -- nothing faster than ~340 km/h counts (teleports, broken reports)
    meters = math.max(0, math.min(meters, dt * 95))
    fast = math.max(0, math.min(fast, meters))
    if meters < 1 then return end
    local plate = plateOf(veh)
    if not plate then return end
    local rec = loadRecord(plate)
    local km = meters / 1000
    rec.km = rec.km + km
    local hard = (fast / 1000) * 0.5
    for id, v in pairs(rec.c) do
        local life = COMP[id] and COMP[id].life or 300
        local loss = (km + hard) / life * 100 * (0.9 + math.random() * 0.2)
        rec.c[id] = math.max(0.0, v - loss)
    end
    rec.dirty = rec.persist
    publish(veh, rec)
end)

AddEventHandler('playerDropped', function() lastReport[source] = nil end)

---------------------------------------------------------------------------
-- the mechanic's side
---------------------------------------------------------------------------
local function itemCount(src, name)
    local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, name) end)
    return ok and tonumber(n) or 0
end

local function itemLabel(name)
    local ok, items = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and type(items) == 'table' and items.label or name
end

local function nearCar(src, veh, extra)
    local ped = pedOf(src)
    return ped and #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= (S.reach + (extra or 1.0))
end

local function history(plate, n)
    local rows = MySQL.query.await('SELECT `at`, `name`, `what`, `km` FROM `exti_mechanic_service` WHERE `plate` = ? ORDER BY `id` DESC LIMIT ?', { plate, n or 10 }) or {}
    return rows
end

-- what the repair menu and the diagnostics app show
local function report(src, veh, rec, withHistory)
    local list = {}
    for _, id in ipairs(ORDER) do
        local v = rec.c[id]
        if v then
            local c = COMP[id]
            list[#list + 1] = { id = id, label = c.label, pct = math.floor(v + 0.5), part = c.part, partLabel = itemLabel(c.part),
                count = c.count, have = itemCount(src, c.part) }
        end
    end
    local out = {
        plate = rec.plate, model = rec.model, ev = rec.ev, km = math.floor(rec.km), parts = list,
        engine = math.floor(GetVehicleEngineHealth(veh) / 10 + 0.5), body = math.floor(GetVehicleBodyHealth(veh) / 10 + 0.5),
        wax = rec.wax and rec.wax > os.time() and rec.wax or nil, now = os.time(),
        soap = itemCount(src, S.washItem), waxItems = itemCount(src, S.waxItem),
    }
    if withHistory then out.history = history(rec.plate, 12) end
    return out
end

local function mechanicAt(src, netId)
    local player = getPlayer(src)
    if not onDuty(player) then return nil, nil, 'off_duty' end
    local veh = vehicleOf(netId)
    if not veh then return nil, nil, 'no_car' end
    if not nearCar(src, veh, 3.0) then return nil, nil, 'too_far' end
    return player, veh
end

-- the repair menu at the car
lib.callback.register('exti_mechanic:server:serviceInfo', function(source, netId, ev, model)
    if not ready then return false, 'wait' end
    local player, veh, err = mechanicAt(source, netId)
    if not player then return false, err end
    local plate = plateOf(veh)
    if not plate then return false, 'no_car' end
    local rec = loadRecord(plate, type(model) == 'string' and model:sub(1, 40) or nil, ev)
    publish(veh, rec)
    local out = report(source, veh, rec, false)
    -- an open tuning order on this car: its changes are installed from the same menu
    out.tune = MEC.tuneFor and MEC.tuneFor(source, plate) or nil
    out.nitro = MEC.nitroFor and MEC.nitroFor(source, plate) or nil
    return out
end)

-- the diagnostics app on the tablet (the game fills in the car next to the mechanic)
function MEC.diagScan(src, netId, ev, model)
    if not ready then return false, 'wait' end
    local player, veh, err = mechanicAt(src, netId)
    if not player then return false, err end
    local plate = plateOf(veh)
    if not plate then return false, 'no_car' end
    local rec = loadRecord(plate, type(model) == 'string' and model:sub(1, 40) or nil, ev)
    publish(veh, rec)
    local r = report(src, veh, rec, true)
    r.modelName = type(model) == 'string' and model:lower():sub(1, 40) or nil
    return r
end

---------------------------------------------------------------------------
-- a repair: start (checks + the recipe), the mini-game runs on the mechanic's screen, done
---------------------------------------------------------------------------
local pending = {} -- [src] = { kind, comp, veh, netId, started, steps }

local function stepsOf(recipe, times)
    local r = S.recipes[recipe] or {}
    return #r * (times or 1)
end

lib.callback.register('exti_mechanic:server:repairStart', function(source, netId, compId)
    local player, veh, err = mechanicAt(source, netId)
    if not player then return false, err end
    local c = COMP[compId]
    if not c then return false, 'failed' end
    local plate = plateOf(veh)
    local rec = plate and loadRecord(plate)
    if not rec or not rec.c[compId] then return false, 'not_this_car' end
    if itemCount(source, c.part) < c.count then return false, 'no_part' end
    local times = c.game == 'wheels' and 4 or 1
    local recipe = c.game == 'wheels' and 'wheel' or c.game
    pending[source] = { kind = 'repair', comp = compId, veh = veh, plate = plate, started = os.time(), steps = stepsOf(recipe, times) }
    return { recipe = recipe, times = times, steps = S.recipes[recipe], label = c.label }
end)

lib.callback.register('exti_mechanic:server:repairDone', function(source, success)
    local p = pending[source]
    pending[source] = nil
    if not p or p.kind ~= 'repair' then return false, 'failed' end
    if success ~= true then return false, 'cancelled' end
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if not DoesEntityExist(p.veh) or not nearCar(source, p.veh, 3.0) then return false, 'too_far' end
    -- a mini-game cannot be skipped: every step takes at least a second
    if os.time() - p.started < math.max(3, p.steps) then return false, 'too_fast' end
    local c = COMP[p.comp]
    local okR, removed = pcall(function() return exports.ox_inventory:RemoveItem(source, c.part, c.count) end)
    if not okR or not removed then return false, 'no_part' end
    local rec = loadRecord(p.plate)
    rec.c[p.comp] = 100.0
    rec.dirty = rec.persist
    save(rec)
    publish(p.veh, rec)
    MySQL.insert('INSERT INTO `exti_mechanic_service` (`plate`, `at`, `citizenid`, `name`, `what`, `km`) VALUES (?, ?, ?, ?, ?, ?)',
        { p.plate, os.time(), player.PlayerData.citizenid, nameOf(player), ('تغيير %s'):format(c.label), math.floor(rec.km) })
    MEC.log(source, 'repair', ('%s · %s'):format(p.plate, c.label))
    MEC.xp(source, 15, ('تغيير %s'):format(c.label), ('repair:%s:%s'):format(p.plate, p.comp))
    lib.logger(source, 'mechanic', ('replaced %s on %s'):format(p.comp, p.plate))
    return { pct = 100, label = c.label }
end)

-- wash / wax
lib.callback.register('exti_mechanic:server:cleanStart', function(source, netId, kind)
    local player, veh, err = mechanicAt(source, netId)
    if not player then return false, err end
    if kind ~= 'wash' and kind ~= 'wax' then return false, 'failed' end
    local item = kind == 'wax' and S.waxItem or S.washItem
    if itemCount(source, item) < 1 then return false, 'no_part' end
    pending[source] = { kind = kind, veh = veh, plate = plateOf(veh), started = os.time(), steps = 3 }
    return { recipe = kind, times = 1, steps = S.recipes[kind] }
end)

lib.callback.register('exti_mechanic:server:cleanDone', function(source, success)
    local p = pending[source]
    pending[source] = nil
    if not p or (p.kind ~= 'wash' and p.kind ~= 'wax') then return false, 'failed' end
    if success ~= true then return false, 'cancelled' end
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if not DoesEntityExist(p.veh) or not nearCar(source, p.veh, 3.0) then return false, 'too_far' end
    if os.time() - p.started < 3 then return false, 'too_fast' end
    local item = p.kind == 'wax' and S.waxItem or S.washItem
    local okR, removed = pcall(function() return exports.ox_inventory:RemoveItem(source, item, 1) end)
    if not okR or not removed then return false, 'no_part' end
    -- the dirt is kept by the car's owner game
    local owner = NetworkGetEntityOwner(p.veh)
    local netId = NetworkGetNetworkIdFromEntity(p.veh)
    if owner and owner > 0 then TriggerClientEvent('exti_mechanic:client:clean', owner, netId) end
    TriggerClientEvent('exti_mechanic:client:clean', source, netId)
    if p.kind == 'wax' and p.plate then
        local rec = loadRecord(p.plate)
        rec.wax = os.time() + (S.waxHours or 6) * 3600
        rec.dirty = rec.persist
        save(rec)
        publish(p.veh, rec)
    end
    if p.plate then
        MySQL.insert('INSERT INTO `exti_mechanic_service` (`plate`, `at`, `citizenid`, `name`, `what`, `km`) VALUES (?, ?, ?, ?, ?, ?)',
            { p.plate, os.time(), player.PlayerData.citizenid, nameOf(player), p.kind == 'wax' and 'غسيل وتلميع (واكس)' or 'غسيل', wear[p.plate] and math.floor(wear[p.plate].km) or nil })
    end
    MEC.log(source, p.kind == 'wax' and 'wax' or 'wash', p.plate or '')
    MEC.xp(source, p.kind == 'wax' and 10 or 6, p.kind == 'wax' and 'تلميع سيارة' or 'غسيل سيارة', ('clean:%s'):format(p.plate or '?'))
    return true
end)

lib.callback.register('exti_mechanic:server:workCancel', function(source)
    pending[source] = nil
    if MEC.tuneCancelWork then MEC.tuneCancelWork(source) end
    return true
end)

AddEventHandler('playerDropped', function() pending[source] = nil end)

---------------------------------------------------------------------------
-- for other scripts
---------------------------------------------------------------------------
--- CanUseKit(src) -> bool : the repair kits (vehiclehandler) are for on-duty mechanics only
exports('CanUseKit', function(src)
    return onDuty(getPlayer(src)) == true
end)

--- GetWear(plate) -> { ev, km, c = { id = % } } or nil
exports('GetWear', function(plate)
    plate = type(plate) == 'string' and plate:gsub('^%s+', ''):gsub('%s+$', ''):upper() or nil
    local rec = plate and wear[plate]
    return rec and compact(rec) or nil
end)

-- admins: /carwear [part] [percent] sets the car you sit in (testing the effects)
lib.addCommand('carwear', {
    help = 'Mechanic: set the wear of the car you are in (admin). /carwear all 5  or  /carwear engine_oil 0',
    params = {
        { name = 'part', help = 'all / engine_oil / brake_pads / clutch / tires …' },
        { name = 'pct', type = 'number', help = '0-100' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local ped = pedOf(source)
    local veh = ped and GetVehiclePedIsIn(ped, false) or 0
    if veh == 0 then return notify(source, 'error', 'اجلس في سيارة أولًا') end
    local plate = plateOf(veh)
    if not plate then return end
    local rec = loadRecord(plate)
    local pct = math.max(0, math.min(100, tonumber(args.pct) or 100)) + 0.0
    local part = tostring(args.part or 'all')
    if part == 'all' then
        for id in pairs(rec.c) do rec.c[id] = pct end
    elseif rec.c[part] then
        rec.c[part] = pct
    else
        return notify(source, 'error', 'هذه القطعة ليست في هذه السيارة')
    end
    rec.dirty = rec.persist
    save(rec)
    publish(veh, rec)
    notify(source, 'success', ('%s: %s = %d%%'):format(plate, part, pct))
end)
