-- =====================================================================
-- EX_Tii EMS (server): the garages like the video — the team's vehicles (each with its own plate
-- and its own trunk that keeps what you leave in it between shifts), park out / park in, open the
-- trunk from the garage, and the leader buys / sells vehicles with the EMS bank account.
-- Ground vehicles at the garage, helicopters at the pad.
-- =====================================================================

local JOB = Config.job
local F = Config.fleet

local getPlayer, isMedic, onDuty, nameOf = EMS.getPlayer, EMS.isMedic, EMS.onDuty, EMS.nameOf
local pedOf, near, notify = EMS.pedOf, EMS.near, EMS.notify
local vehicles, equipment, busy = EMS.vehicles, EMS.equipment, EMS.busy

local fleet = {}    -- [id] = { id, plate, model, kind, fuel, engine, body, price, out = { src, entity } }
local byPlate = {}  -- [plate] = id
local ready = false

local function trunkId(id) return 'exti_ems_trunk_' .. id end

local function hospitalOf(name)
    return type(name) == 'string' and Config.hospitals[name] or nil
end

-- the garage spot for this kind of vehicle (ground = garage, air = heli pad)
local function spotOf(h, kind)
    return h and (kind == 'air' and h.heli or kind == 'ground' and h.garage) or nil
end

local function isBoss(player)
    return isMedic(player) and player.PlayerData.job.isboss == true
end

local function newPlate()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ23456789'
    for _ = 1, 200 do
        local p = F.plate
        for _ = 1, 8 - #F.plate do
            local i = math.random(1, #chars)
            p = p .. chars:sub(i, i)
        end
        if not byPlate[p] then return p end
    end
end

local function registerTrunk(v)
    pcall(function()
        exports.ox_inventory:RegisterStash(trunkId(v.id), ('صندوق %s'):format(v.plate), F.trunk.slots, F.trunk.weight, nil, EMS.NOONE)
    end)
end

local function addRow(row)
    local v = {
        id = row.id, plate = row.plate, model = row.model, kind = row.kind,
        fuel = tonumber(row.fuel) or 100.0, engine = tonumber(row.engine) or 1000.0, body = tonumber(row.body) or 1000.0,
        price = tonumber(row.price) or 0,
    }
    fleet[v.id] = v
    byPlate[v.plate] = v.id
    return v
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_ems_fleet` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `plate` VARCHAR(8) NOT NULL UNIQUE,
        `model` VARCHAR(32) NOT NULL,
        `kind` VARCHAR(8) NOT NULL,
        `fuel` FLOAT NOT NULL DEFAULT 100,
        `engine` FLOAT NOT NULL DEFAULT 1000,
        `body` FLOAT NOT NULL DEFAULT 1000,
        `price` INT NOT NULL DEFAULT 0,
        `bought` INT NOT NULL DEFAULT 0
    )]])
    local rows = MySQL.query.await('SELECT * FROM `exti_ems_fleet`') or {}
    for _, r in ipairs(rows) do addRow(r) end
    if #rows > 0 then SetResourceKvpInt('fleet_started', 1) end
    if #rows == 0 and GetResourceKvpInt('fleet_started') ~= 1 then
        -- the very first time only: the vehicles the team starts with (free, so selling them gives nothing)
        SetResourceKvpInt('fleet_started', 1)
        for _, model in ipairs(F.start or {}) do
            local def = F.models[model]
            local plate = def and newPlate()
            if plate then
                local id = MySQL.insert.await('INSERT INTO `exti_ems_fleet` (`plate`, `model`, `kind`, `price`, `bought`) VALUES (?, ?, ?, ?, ?)',
                    { plate, model, def.kind, 0, os.time() })
                if id then addRow({ id = id, plate = plate, model = model, kind = def.kind, price = 0 }) end
            end
        end
    end
    -- ox_inventory may start after us
    for _ = 1, 60 do
        if GetResourceState('ox_inventory') == 'started' then break end
        Wait(2000)
    end
    for _, v in pairs(fleet) do registerTrunk(v) end
    ready = true
end)

---------------------------------------------------------------------------
-- what the garage screen shows
---------------------------------------------------------------------------
local function balance()
    local ok, money = pcall(function() return exports['Renewed-Banking']:getAccountMoney(JOB) end)
    return ok and tonumber(money) or nil
end

local function view(src, player, kind)
    local list = {}
    for _, v in pairs(fleet) do
        if v.kind == kind then
            local def = F.models[v.model] or {}
            local outBy
            if v.out then
                local p = getPlayer(v.out.src)
                outBy = p and nameOf(p) or nil
            end
            list[#list + 1] = {
                id = v.id, plate = v.plate, model = v.model, label = def.label or v.model,
                fuel = math.floor(v.fuel + 0.5), engine = math.floor(v.engine / 10 + 0.5), body = math.floor(v.body / 10 + 0.5),
                out = v.out ~= nil, outBy = outBy, mine = v.out ~= nil and v.out.src == src,
                sell = math.floor((v.price or 0) * (F.sellBack or 0.5)),
            }
        end
    end
    table.sort(list, function(a, b)
        if a.out ~= b.out then return not a.out end
        if a.model ~= b.model then return a.model < b.model end
        return a.id < b.id
    end)
    local shop = {}
    for model, def in pairs(F.models) do
        if def.kind == kind then shop[#shop + 1] = { model = model, label = def.label, price = def.price } end
    end
    table.sort(shop, function(a, b) return a.price < b.price end)
    local boss = isBoss(player)
    local count = 0
    for _ in pairs(fleet) do count = count + 1 end
    return {
        kind = kind, boss = boss, vehicles = list, shop = shop,
        balance = boss and balance() or nil, count = count, max = F.max,
        trunk = F.trunk.slots, hasOne = vehicles[src] ~= nil and DoesEntityExist(vehicles[src]),
    }
end

-- on duty, a medic, next to the garage of this kind
local function garageCheck(src, hospital, kind)
    local player = getPlayer(src)
    if not onDuty(player) then return nil, 'off_duty' end
    if kind ~= 'ground' and kind ~= 'air' then return nil, 'failed' end
    local spot = spotOf(hospitalOf(hospital), kind)
    if not spot or not near(src, spot.coords, Config.reachPoint + 2.0) then return nil, 'too_far' end
    if not ready then return nil, 'failed' end
    return player, spot
end

lib.callback.register('exti_ems:server:garage', function(source, hospital, kind)
    local player, err = garageCheck(source, hospital, kind)
    if not player then return false, err end
    return view(source, player, kind)
end)

---------------------------------------------------------------------------
-- park out / park in
---------------------------------------------------------------------------
lib.callback.register('exti_ems:server:parkOut', function(source, hospital, id)
    local player, spot = garageCheck(source, hospital, type(id) == 'number' and fleet[id] and fleet[id].kind or nil)
    if not player then return false, spot end
    local v = fleet[id]
    if v.out or v.selling then return false, 'vehicle_out' end
    if busy[source] then return false, 'failed' end
    local old = vehicles[source]
    if old and DoesEntityExist(old) then return false, 'has_one' end
    if not spot.spawn then return false, 'failed' end
    for _, other in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(other) - spot.spawn.xyz) < 3.0 then return false, 'spot' end
    end

    busy[source] = true
    v.out = { src = source, entity = 0 } -- nobody else takes it while it spawns
    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = v.model, spawnSource = spot.spawn, warp = pedOf(source) })
    busy[source] = nil
    if not ok or not netId or not veh or veh == 0 then v.out = nil return false, 'failed' end
    if not getPlayer(source) then DeleteEntity(veh) v.out = nil return false, 'failed' end

    v.out.entity = veh
    vehicles[source] = veh
    SetVehicleNumberPlateText(veh, v.plate)
    Entity(veh).state:set('fuel', v.fuel, true)
    Entity(veh).state:set('exti_ems', true, true)
    Entity(veh).state:set('exti_ems_fleet', v.id, true)
    Entity(veh).state:set('exti_ems_air', v.kind == 'air', true)
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(source, veh, true) end)
    pcall(function() exports.qbx_vehiclekeys:SetLockState(veh, 'unlock') end)
    lib.logger(source, 'ems', ('took %s (%s)'):format(v.model, v.plate))
    local def = F.models[v.model] or {}
    -- a wreck is patched up enough to drive back to a mechanic
    return true, netId, { livery = def.livery, engine = math.max(v.engine, 400.0), body = math.max(v.body, 400.0), fuel = v.fuel, plate = v.plate }
end)

local function fleetOfEntity(entity)
    for _, v in pairs(fleet) do
        if v.out and v.out.entity == entity then return v end
    end
end

-- keep what we know about how the vehicle is doing (fuel 0-100, engine / body 0-1000)
local function remember(v, state)
    if not state then return end
    v.fuel = math.max(0.0, math.min(100.0, tonumber(state.fuel) or v.fuel))
    v.engine = math.max(0.0, math.min(1000.0, tonumber(state.engine) or v.engine))
    v.body = math.max(0.0, math.min(1000.0, tonumber(state.body) or v.body))
end

local function saveState(v)
    MySQL.update('UPDATE `exti_ems_fleet` SET `fuel` = ?, `engine` = ?, `body` = ? WHERE `id` = ?', { v.fuel, v.engine, v.body, v.id })
end

-- back in the garage: keep its fuel and damage (the trunk keeps its items by itself)
local function store(v, state)
    local veh = v.out and v.out.entity
    remember(v, state)
    saveState(v)
    if v.out and vehicles[v.out.src] == veh then vehicles[v.out.src] = nil end
    v.out = nil
    if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
end

-- every 30 seconds: remember how the team's vehicles out in the city are doing, so one that
-- disappears without being parked (left alone and taken back by the impound, /dv...) goes back
-- to the garage the way it was (no free repairs, no free fuel)
CreateThread(function()
    while true do
        Wait(30000)
        for _, v in pairs(fleet) do
            local veh = v.out and v.out.entity
            if veh and veh ~= 0 and DoesEntityExist(veh) then
                pcall(function()
                    remember(v, { fuel = Entity(veh).state.fuel, engine = GetVehicleEngineHealth(veh), body = GetVehicleBodyHealth(veh) })
                end)
            end
        end
    end
end)

-- the vehicle you are driving goes back in (any of the team's vehicles, not only yours)
lib.callback.register('exti_ems:server:parkIn', function(source, hospital)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local ped = pedOf(source)
    local veh = ped and GetVehiclePedIsIn(ped, false) or 0
    if veh == 0 then return false, 'failed' end
    local v = fleetOfEntity(veh)
    if not v then return false, 'not_fleet' end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return false, 'driver' end
    local spot = spotOf(hospitalOf(hospital), v.kind)
    if not spot or #(GetEntityCoords(veh) - spot.coords) > (Config.vehicleReach or 4.0) + 6.0 then return false, 'too_far' end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    for _, e in pairs(equipment) do
        if e.vehicle == netId then return false, 'loaded' end
    end
    -- nobody else inside
    for seat = 0, 10 do
        local other = GetPedInVehicleSeat(veh, seat)
        if other and other ~= 0 and other ~= ped then return false, 'passengers' end
    end
    local state = Entity(veh).state
    store(v, { fuel = state.fuel, engine = GetVehicleEngineHealth(veh), body = GetVehicleBodyHealth(veh) })
    lib.logger(source, 'ems', ('parked %s (%s)'):format(v.model, v.plate))
    return true
end)

-- off duty / left the job / left the city: their vehicle goes back to the garage
function EMS.releaseVehicle(src)
    local veh = vehicles[src]
    vehicles[src] = nil
    if not veh then return end
    local v = fleetOfEntity(veh)
    if v then
        local state = DoesEntityExist(veh) and Entity(veh).state or nil
        store(v, state and { fuel = state.fuel, engine = GetVehicleEngineHealth(veh), body = GetVehicleBodyHealth(veh) } or nil)
    elseif DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
end

-- the vehicle disappeared (/dv, blown up and cleaned up...): it is back in the garage
function EMS.fleetGone(entity)
    local v = fleetOfEntity(entity)
    if not v then return end
    if vehicles[v.out.src] == entity then vehicles[v.out.src] = nil end
    v.out = nil
    saveState(v) -- the last fuel / damage we saw (at most 30 seconds old)
end

---------------------------------------------------------------------------
-- the trunk: the same items every shift (an ox_inventory stash per vehicle)
---------------------------------------------------------------------------
lib.callback.register('exti_ems:server:openTrunk', function(source, hospital, id)
    local v = type(id) == 'number' and fleet[id]
    if not v or v.selling then return false, 'failed' end
    local player, err = garageCheck(source, hospital, v.kind)
    if not player then return false, err end
    return exports.ox_inventory:forceOpenInventory(source, 'stash', trunkId(v.id)) and true or false, 'failed'
end)

-- [E] at the back of one of the team's vehicles (out in the city): its own trunk
lib.callback.register('exti_ems:server:vehicleTrunk', function(source, netId)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local veh = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) then return false, 'gone' end
    local v = fleetOfEntity(veh)
    if not v or v.selling then return false, 'not_fleet' end
    local ped = pedOf(source)
    if not ped or GetVehiclePedIsIn(ped, false) ~= 0 or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 8.0 then return false, 'too_far' end
    return exports.ox_inventory:forceOpenInventory(source, 'stash', trunkId(v.id)) and true or false, 'failed'
end)

-- the boot / glovebox of a team vehicle through ox_inventory (the ambulance and rescue car have
-- them turned off in ox_inventory/data/vehicles.lua; this catches any other model): the boot opens
-- the vehicle's own trunk, the glovebox stays shut (no random loot, nothing lost at park in)
local function hookTrunks()
    exports.ox_inventory:registerHook('openInventory', function(payload)
        local plate = type(payload.inventoryId) == 'string' and payload.inventoryId:sub(6) or nil
        local id = plate and byPlate[plate]
        if not id then return true end
        local src = payload.source
        local player = getPlayer(src)
        if payload.inventoryType == 'glovebox' then return false end
        if not isMedic(player) then
            notify(src, 'error', 'هذه مركبة الإسعاف، صندوقها للطاقم فقط')
            return false
        end
        SetTimeout(250, function()
            local v = fleet[id]
            if v and not v.selling then exports.ox_inventory:forceOpenInventory(src, 'stash', trunkId(id)) end
        end)
        return false
    end, { inventoryFilter = { '^trunk' .. F.plate, '^glove' .. F.plate }, typeFilter = { trunk = true, glovebox = true } })
end

CreateThread(function()
    for _ = 1, 60 do
        if GetResourceState('ox_inventory') == 'started' then break end
        Wait(2000)
    end
    if not pcall(hookTrunks) then print('^1[exti_ems] could not hook the EMS trunks into ox_inventory^0') end
end)

-- ox_inventory restarted: it forgot our trunks and the hook
AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= 'ox_inventory' then return end
    CreateThread(function()
        Wait(2000)
        for _, v in pairs(fleet) do registerTrunk(v) end
        pcall(hookTrunks)
    end)
end)

---------------------------------------------------------------------------
-- the leader: buy / sell vehicles (the EMS account in the bank pays)
---------------------------------------------------------------------------
lib.callback.register('exti_ems:server:buyVehicle', function(source, hospital, model)
    local def = type(model) == 'string' and F.models[model]
    if not def then return false, 'failed' end
    local player, err = garageCheck(source, hospital, def.kind)
    if not player then return false, err end
    if not isBoss(player) then return false, 'not_boss' end
    local count = 0
    for _ in pairs(fleet) do count = count + 1 end
    if count >= (F.max or 20) then return false, 'fleet_full' end
    local price = math.floor(tonumber(def.price) or 0)
    if price > 0 then
        local okPay, paid = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(JOB, price) end)
        if not okPay or not paid then return false, 'no_money' end
        pcall(function()
            exports['Renewed-Banking']:handleTransaction(JOB, 'مركبات الإسعاف', price, ('شراء %s'):format(def.label or model), nameOf(player), 'Vehicle Shop', 'withdraw')
        end)
    end
    local plate = newPlate()
    local id = plate and MySQL.insert.await('INSERT INTO `exti_ems_fleet` (`plate`, `model`, `kind`, `price`, `bought`) VALUES (?, ?, ?, ?, ?)',
        { plate, model, def.kind, price, os.time() })
    if not id then
        if price > 0 then pcall(function() exports['Renewed-Banking']:addAccountMoney(JOB, price) end) end
        return false, 'failed'
    end
    local v = addRow({ id = id, plate = plate, model = model, kind = def.kind, price = price })
    registerTrunk(v)
    lib.logger(source, 'ems', ('bought %s (%s) for $%d'):format(model, plate, price))
    return true, view(source, player, def.kind)
end)

lib.callback.register('exti_ems:server:sellVehicle', function(source, hospital, id)
    local v = type(id) == 'number' and fleet[id]
    if not v then return false, 'failed' end
    local player, err = garageCheck(source, hospital, v.kind)
    if not player then return false, err end
    if not isBoss(player) then return false, 'not_boss' end
    if v.out or v.selling then return false, 'vehicle_out' end
    v.selling = true -- nobody takes it out / opens it / sells it again while we wait for the database
    -- nothing may be lost: the trunk must be empty (money weighs nothing, so look at the items)
    local okInv, inv = pcall(function() return exports.ox_inventory:GetInventory(trunkId(v.id), false) end)
    if not okInv or (inv and type(inv.items) == 'table' and next(inv.items) ~= nil) then
        v.selling = nil
        return false, okInv and 'trunk_full' or 'failed'
    end
    fleet[v.id], byPlate[v.plate] = nil, nil
    local affected = MySQL.update.await('DELETE FROM `exti_ems_fleet` WHERE `id` = ?', { v.id })
    if affected ~= 1 then
        fleet[v.id], byPlate[v.plate], v.selling = v, v.id, nil
        return false, 'failed'
    end
    local refund = math.floor((v.price or 0) * (F.sellBack or 0.5))
    if refund > 0 then
        pcall(function()
            exports['Renewed-Banking']:addAccountMoney(JOB, refund)
            exports['Renewed-Banking']:handleTransaction(JOB, 'مركبات الإسعاف', refund, ('بيع %s (%s)'):format((F.models[v.model] or {}).label or v.model, v.plate), nameOf(player), 'Vehicle Shop', 'deposit')
        end)
    end
    lib.logger(source, 'ems', ('sold %s (%s) for $%d'):format(v.model, v.plate, refund))
    local p = getPlayer(source)
    return true, p and view(source, p, v.kind) or nil
end)
