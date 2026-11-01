-- EX_Tii Fuel (server): the server decides everything — which pump, how close you are, which vehicle,
-- how much is missing, the price, the money, how long the pump runs and how much went in.
-- The game only says "this pump, this vehicle, up to this %, pay with cash/bank" and "stop".
--
-- The fuel level lives on the vehicle: Entity(vehicle).state.fuel (0-100), the same value the HUD,
-- garages, impound lots, job vehicles, vehiclehandler and the mechanic already use.

local sessions = {}   -- [src] = a pump running for this player
local canJobs = {}    -- [src] = jerry can being filled at a pump / poured into a vehicle
local busy = {}       -- [src] = true while a callback is working
local fillingVeh = {} -- [vehicle] = src (one pump per vehicle)
local lastDriver = {} -- [vehicle] = src (who may send the last fuel report after getting out)
local lastReport = {} -- [src] = game timer
local justFilled = {} -- [vehicle] = { level, untilMs } (a report sent before the driver saw the new level is ignored)

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function balances(player)
    local m = player.PlayerData.money or {}
    return math.floor(tonumber(m.cash) or 0), math.floor(tonumber(m.bank) or 0)
end

local function notify(src, kind, text)
    TriggerClientEvent('ox_lib:notify', src, { type = kind, description = text })
end

local function isNumber(v) return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge end

local function flat(a, b) return #(vec2(a.x, a.y) - vec2(b.x, b.y)) end

---------------------------------------------------------------------------
-- vehicles: is it fuel or electric, how big is the tank / battery
---------------------------------------------------------------------------
local categories
local function categoryOf(model)
    if not categories then
        categories = {}
        local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
        if ok and type(list) == 'table' then
            for name, v in pairs(list) do
                if type(v) == 'table' and type(v.category) == 'string' then
                    local hash = type(v.hash) == 'number' and v.hash or joaat(v.model or name)
                    categories[hash & 0xFFFFFFFF] = v.category
                end
            end
        end
    end
    return categories[(tonumber(model) or 0) & 0xFFFFFFFF]
end

local NO_FUEL_TYPES = { trailer = true, train = true }
local NO_FUEL_CATEGORIES = { cycles = true, trains = true }
local TANK_BY_TYPE = { bike = 15, boat = 150, submarine = 150, heli = 300, plane = 400, blimp = 300 }

---@return { electric: boolean, capacity: number, price: number, rate: number }?
local function vehicleInfo(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    local vtype = GetVehicleType(vehicle)
    if NO_FUEL_TYPES[vtype] then return end
    local model = GetEntityModel(vehicle)
    local category = categoryOf(model)
    if category and NO_FUEL_CATEGORIES[category] then return end
    local electric = Config.electricModel(model)
    local capacity
    if electric then
        capacity = Config.batteryKWh[category] or (vtype == 'bike' and Config.batteryKWh.motorcycles) or Config.defaultBatteryKWh
    else
        capacity = Config.tankLiters[category] or TANK_BY_TYPE[vtype] or Config.defaultTankLiters
    end
    if not capacity or capacity <= 0 then return end
    return {
        electric = electric,
        capacity = capacity,
        price = electric and Config.pricePerKWh or Config.pricePerLiter,
        rate = electric and Config.kWhPerSecond or Config.litersPerSecond,
    }
end

---@return number? level 0-100 (nil = never set yet)
local function fuelOf(vehicle)
    local level = Entity(vehicle).state.fuel
    return isNumber(level) and clamp(level, 0.0, 100.0) or nil
end

---@return number level
local function setFuel(vehicle, level)
    level = clamp(math.floor(level * 10 + 0.5) / 10, 0.0, 100.0) + 0.0
    Entity(vehicle).state:set('fuel', level, true)
    return level
end

---------------------------------------------------------------------------
-- pumps
---------------------------------------------------------------------------
---@return table? station, vector3? pump
local function pumpAt(stationId, pumpIndex)
    if math.type(stationId) ~= 'integer' or math.type(pumpIndex) ~= 'integer' then return end
    local station = Config.stations[stationId]
    local pump = station and station.pumps[pumpIndex]
    if not pump then return end
    return station, pump
end

local function playerAtPump(src, pump)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return flat(p, pump) <= Config.pumpRadius + 1.2 and math.abs(p.z - pump.z) < 3.5
end

---@return number? vehicle, string? errorCode
local function vehicleAtPump(src, netId, pump)
    if math.type(netId) ~= 'integer' or netId <= 0 then return nil, 'no_vehicle' end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil, 'no_vehicle' end
    if GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(src) then return nil, 'no_vehicle' end
    local v = GetEntityCoords(vehicle)
    if flat(v, pump) > Config.vehicleReach + 1.5 or math.abs(v.z - pump.z) > 4.0 then return nil, 'vehicle_far' end
    if #(GetEntityVelocity(vehicle)) > 1.0 then return nil, 'vehicle_moving' end
    return vehicle
end

-- the first time a vehicle is seen it has no level yet: the game's own reading is used (new / AI cars)
local function levelOrHint(vehicle, info, hint)
    local level = fuelOf(vehicle)
    if level then return level end
    if not isNumber(hint) then return nil end
    hint = clamp(hint, 0.0, 100.0)
    if info.electric and hint <= 0.5 then hint = 100.0 end
    return setFuel(vehicle, hint)
end

local function quoteFor(info, from, to)
    local units = (to - from) / 100.0 * info.capacity
    local cost = math.max(Config.minPrice, math.ceil(units * info.price))
    local seconds = clamp(units / info.rate, Config.minSeconds, Config.maxSeconds)
    return units, cost, math.floor(seconds * 1000)
end

---------------------------------------------------------------------------
-- the panel: what this vehicle needs and what it costs
---------------------------------------------------------------------------
lib.callback.register('exti_fuel:server:quote', function(source, stationId, pumpIndex, netId, hint)
    local src = source
    local station, pump = pumpAt(stationId, pumpIndex)
    if not station or not playerAtPump(src, pump) then return false, 'too_far' end
    local vehicle, err = vehicleAtPump(src, netId, pump)
    if not vehicle then return false, err end
    if fillingVeh[vehicle] then return false, 'vehicle_busy' end
    local info = vehicleInfo(vehicle)
    if not info then return false, 'no_fuel' end
    local player = getPlayer(src)
    if not player then return false, 'failed' end

    local level = levelOrHint(vehicle, info, hint)
    if not level then return false, 'failed' end
    local cash, bank = balances(player)
    return true, nil, {
        station = station.label,
        electric = info.electric,
        level = level,
        capacity = info.capacity,
        price = info.price,
        rate = info.rate,
        minPrice = Config.minPrice,
        minSeconds = Config.minSeconds,
        maxSeconds = Config.maxSeconds,
        cash = cash,
        bank = bank,
        can = { price = Config.canPrice, liters = Config.canLiters }, -- the jerry can offer on the pump screen
    }
end)

---------------------------------------------------------------------------
-- a running pump
---------------------------------------------------------------------------
local ticking = false
local finish

local function refund(s, amount)
    if amount <= 0 then return end
    local reason = (s.electric and 'ev-charge-refund|' or 'fuel-refund|') .. s.label
    local player = getPlayer(s.src)
    if player and player.PlayerData.citizenid == s.cid then
        player.Functions.AddMoney(s.account, amount, reason)
        if s.leaving then pcall(function() player.Functions.Save() end) end
    else
        -- left the city / changed character: the money still comes back
        local ok, added = pcall(function() return exports.qbx_core:AddMoney(s.cid, s.account, amount, reason) end)
        if not ok or added == false then
            lib.print.error(('[exti_fuel] refund of $%d (%s) for %s failed: %s'):format(amount, s.account, s.cid, tostring(added)))
        end
    end
end

---@param why 'done'|'stopped'|'moved'|'walked'|'vehicle'|'gone'
function finish(src, why)
    local s = sessions[src]
    if not s then return end
    sessions[src] = nil
    if fillingVeh[s.vehicle] == src then fillingVeh[s.vehicle] = nil end

    local fraction = why == 'done' and 1.0 or clamp((GetGameTimer() - s.started) / s.duration, 0.0, 1.0)
    local exists = DoesEntityExist(s.vehicle)
    if not exists or fraction < 0.03 then fraction = 0.0 end

    local paid = 0
    if fraction > 0 then
        paid = fraction >= 1.0 and s.cost or math.min(s.cost, math.max(Config.minPrice, math.ceil(s.cost * fraction)))
    end
    local level
    if fraction > 0 then
        local now = fuelOf(s.vehicle) or s.from
        level = setFuel(s.vehicle, math.min(100.0, now + (s.to - s.from) * fraction))
        justFilled[s.vehicle] = { level = level, untilMs = GetGameTimer() + 4000 }
    end
    refund(s, s.cost - paid)

    local units = s.units * fraction
    lib.print.info(('%s (%s) %s %.1f %s at %s for $%d (%s, %s)'):format(GetPlayerName(src) or src, s.cid,
        s.electric and 'charged' or 'fuelled', units, s.electric and 'kWh' or 'L', s.label, paid, s.account, why))
    TriggerClientEvent('exti_fuel:client:finished', src, {
        why = why, electric = s.electric, units = units, paid = paid, refund = s.cost - paid, level = level,
    })
end

local function tick()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while next(sessions) do
            local now = GetGameTimer()
            for src, s in pairs(sessions) do
                local ped = GetPlayerPed(src)
                if not ped or ped == 0 then
                    finish(src, 'gone')
                elseif not DoesEntityExist(s.vehicle) then
                    finish(src, 'vehicle')
                elseif #(GetEntityCoords(s.vehicle) - s.vpos) > 1.5 then
                    finish(src, 'moved')
                elseif flat(GetEntityCoords(ped), s.pump) > Config.stopDistance then
                    finish(src, 'walked')
                elseif now - s.started >= s.duration then
                    finish(src, 'done')
                end
            end
            Wait(250)
        end
        ticking = false
    end)
end

---@return boolean ok, string? errorCode, table? session
lib.callback.register('exti_fuel:server:start', function(source, stationId, pumpIndex, netId, target, account)
    local src = source
    if busy[src] or sessions[src] or canJobs[src] then return false, 'busy' end
    if account ~= 'cash' and account ~= 'bank' then return false, 'failed' end
    if not isNumber(target) then return false, 'failed' end
    target = clamp(math.floor(target + 0.5), 1, 100) + 0.0

    local station, pump = pumpAt(stationId, pumpIndex)
    if not station or not playerAtPump(src, pump) then return false, 'too_far' end
    local vehicle, err = vehicleAtPump(src, netId, pump)
    if not vehicle then return false, err end
    if fillingVeh[vehicle] then return false, 'vehicle_busy' end
    local info = vehicleInfo(vehicle)
    if not info then return false, 'no_fuel' end
    local player = getPlayer(src)
    if not player then return false, 'failed' end

    local from = fuelOf(vehicle)
    if not from then return false, 'failed' end
    if target - from < 1.0 then return false, 'tank_full' end

    local units, cost, duration = quoteFor(info, from, target)
    local cash, bank = balances(player)
    if (account == 'cash' and cash or bank) < cost then return false, 'no_money' end

    busy[src] = true
    local reason = (info.electric and 'ev-charge|' or 'fuel|') .. station.label
    local ok, paid = pcall(function() return player.Functions.RemoveMoney(account, cost, reason) end)
    busy[src] = nil
    if not ok or not paid then return false, 'no_money' end

    -- someone may have started on this vehicle while the money was taken
    if fillingVeh[vehicle] or sessions[src] then
        player.Functions.AddMoney(account, cost, (info.electric and 'ev-charge-refund|' or 'fuel-refund|') .. station.label)
        return false, 'vehicle_busy'
    end

    sessions[src] = {
        src = src, cid = player.PlayerData.citizenid, account = account, label = station.label,
        vehicle = vehicle, vpos = GetEntityCoords(vehicle), pump = pump, electric = info.electric,
        from = from, to = target, units = units, cost = cost, duration = duration, started = GetGameTimer(),
    }
    fillingVeh[vehicle] = src
    tick()

    return true, nil, {
        electric = info.electric, from = from, to = target, units = units, cost = cost, duration = duration,
    }
end)

lib.callback.register('exti_fuel:server:stop', function(source)
    if not sessions[source] then return false end
    finish(source, 'stopped')
    return true
end)

---------------------------------------------------------------------------
-- the driver's game: the level goes down while driving (only down, the pump is the only way up)
---------------------------------------------------------------------------
RegisterNetEvent('exti_fuel:server:report', function(level, netId)
    local src = source
    if not isNumber(level) or math.type(netId) ~= 'integer' then return end
    local now = GetGameTimer()
    if lastReport[src] and now - lastReport[src] < 400 then return end
    lastReport[src] = now

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == ped then
        lastDriver[vehicle] = src
    elseif lastDriver[vehicle] ~= src or (driver ~= 0 and driver ~= ped)
        or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 12.0 then
        return -- only the driver (or the one who just got out)
    end
    if fillingVeh[vehicle] then return end
    local filled = justFilled[vehicle]
    if filled then
        if now < filled.untilMs and level < filled.level - 0.5 then return end
        if now >= filled.untilMs then justFilled[vehicle] = nil end
    end

    level = clamp(level, 0.0, 100.0)
    local current = fuelOf(vehicle)
    if current == nil then
        local info = vehicleInfo(vehicle)
        if info and info.electric and level <= 0.5 then level = 100.0 end
        setFuel(vehicle, level)
    elseif level < current then
        setFuel(vehicle, level)
    end
end)

---------------------------------------------------------------------------
-- jerry can: fill it at a pump, pour it into a vehicle anywhere
---------------------------------------------------------------------------
local function heldCan(src)
    local ok, weapon = pcall(function() return exports.ox_inventory:GetCurrentWeapon(src) end)
    if not ok or type(weapon) ~= 'table' or weapon.name ~= Config.canItem or type(weapon.metadata) ~= 'table' then return end
    return weapon
end

local function canLevel(weapon)
    local m = weapon.metadata
    return clamp(tonumber(m.durability) or tonumber(m.ammo) or 0, 0, 100)
end

local function setCan(src, weapon, level)
    level = clamp(math.floor(level + 0.5), 0, 100)
    weapon.metadata.durability = level
    weapon.metadata.ammo = level
    exports.ox_inventory:SetMetadata(src, weapon.slot, weapon.metadata)
    return level
end

local function payAuto(player, cost)
    local cash, bank = balances(player)
    if cash >= cost then return 'cash' end
    if bank >= cost then return 'bank' end
end

-- fill the can at a pump
lib.callback.register('exti_fuel:server:canStart', function(source, stationId, pumpIndex)
    local src = source
    if busy[src] or sessions[src] or canJobs[src] then return false, 'busy' end
    local station, pump = pumpAt(stationId, pumpIndex)
    if not station or not playerAtPump(src, pump) then return false, 'too_far' end
    local weapon = heldCan(src)
    if not weapon then return false, 'no_can' end
    local player = getPlayer(src)
    if not player then return false, 'failed' end

    local missing = 100 - canLevel(weapon)
    if missing < 2 then return false, 'can_full' end
    -- the fuel has weight too (ox_inventory: a full can is 15 kg heavier than an empty one)
    local okWeight, canCarry = pcall(function() return exports.ox_inventory:CanCarryWeight(src, math.ceil(15000 * missing / 100)) end)
    if okWeight and canCarry == false then return false, 'too_heavy' end
    local liters = missing / 100 * Config.canLiters
    local cost = math.max(Config.minPrice, math.ceil(liters * Config.pricePerLiter))
    if not payAuto(player, cost) then return false, 'no_money' end
    local duration = math.floor(clamp(liters / Config.litersPerSecond, 3, 15) * 1000)

    canJobs[src] = {
        kind = 'refill', slot = weapon.slot, pump = pump, label = station.label,
        from = 100 - missing, liters = liters, cost = cost, duration = duration, started = GetGameTimer(),
    }
    return true, nil, { duration = duration, liters = liters, cost = cost }
end)

-- pour the can into a vehicle
lib.callback.register('exti_fuel:server:pourStart', function(source, netId)
    local src = source
    if busy[src] or sessions[src] or canJobs[src] then return false, 'busy' end
    if math.type(netId) ~= 'integer' or netId <= 0 then return false, 'no_vehicle' end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false, 'no_vehicle' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.canReach + 3.0 then return false, 'vehicle_far' end
    if fillingVeh[vehicle] then return false, 'vehicle_busy' end
    local info = vehicleInfo(vehicle)
    if not info then return false, 'no_fuel' end
    if info.electric then return false, 'electric' end
    local weapon = heldCan(src)
    if not weapon then return false, 'no_can' end

    local can = canLevel(weapon)
    if can < 1 then return false, 'can_empty' end
    local level = fuelOf(vehicle)
    if not level then return false, 'failed' end
    if 100 - level < 1 then return false, 'tank_full' end

    local canLiters = can / 100 * Config.canLiters
    local needLiters = (100 - level) / 100 * info.capacity
    local liters = math.min(canLiters, needLiters)
    local duration = math.floor(clamp(liters / Config.canPourLitersPerSecond, 3, 15) * 1000)

    canJobs[src] = {
        kind = 'pour', slot = weapon.slot, vehicle = vehicle, capacity = info.capacity,
        can = can, liters = liters, duration = duration, started = GetGameTimer(),
    }
    fillingVeh[vehicle] = src
    return true, nil, { duration = duration, liters = liters }
end)

local function endCanJob(src)
    local job = canJobs[src]
    canJobs[src] = nil
    if job and job.vehicle and fillingVeh[job.vehicle] == src then fillingVeh[job.vehicle] = nil end
    return job
end

---@return boolean ok, string? errorCode, table? result
lib.callback.register('exti_fuel:server:canFinish', function(source, completed)
    local src = source
    local job = endCanJob(src)
    if not job then return false, 'failed' end

    local elapsed = GetGameTimer() - job.started
    local fraction = clamp(elapsed / job.duration, 0.0, 1.0)
    if completed == true and elapsed >= job.duration - 750 then fraction = 1.0 end
    if fraction < 0.05 then return false, 'cancelled' end

    local weapon = heldCan(src)
    if not weapon or weapon.slot ~= job.slot then return false, 'no_can' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'failed' end

    if job.kind == 'refill' then
        if not playerAtPump(src, job.pump) then return false, 'too_far' end
        local player = getPlayer(src)
        if not player then return false, 'failed' end
        local liters = job.liters * fraction
        local cost = fraction >= 1.0 and job.cost or math.max(Config.minPrice, math.ceil(job.cost * fraction))
        local account = payAuto(player, cost)
        if not account then return false, 'no_money' end
        busy[src] = true
        local ok, paid = pcall(function() return player.Functions.RemoveMoney(account, cost, 'fuel-can|' .. job.label) end)
        busy[src] = nil
        if not ok or not paid then return false, 'no_money' end
        local level = setCan(src, weapon, job.from + liters / Config.canLiters * 100)
        return true, nil, { kind = 'refill', liters = liters, paid = cost, can = level }
    end

    -- pour (never more than the can holds right now)
    local vehicle = job.vehicle
    if not DoesEntityExist(vehicle) then return false, 'no_vehicle' end
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.canReach + 3.0 then return false, 'vehicle_far' end
    local liters = math.min(job.liters * fraction, canLevel(weapon) / 100 * Config.canLiters)
    if liters <= 0 then return false, 'can_empty' end
    local now = fuelOf(vehicle) or 0.0
    local level = setFuel(vehicle, math.min(100.0, now + liters / job.capacity * 100))
    justFilled[vehicle] = { level = level, untilMs = GetGameTimer() + 4000 }
    local can = setCan(src, weapon, canLevel(weapon) - liters / Config.canLiters * 100)
    return true, nil, { kind = 'pour', liters = liters, level = level, can = can }
end)

---------------------------------------------------------------------------
-- buying a jerry can at the pump (every station, every pump): from the pump screen, or straight
-- from the pump when no vehicle is parked at it
---------------------------------------------------------------------------
lib.callback.register('exti_fuel:server:canQuote', function(source, stationId, pumpIndex)
    local station, pump = pumpAt(stationId, pumpIndex)
    if not station or not playerAtPump(source, pump) then return false, 'too_far' end
    local player = getPlayer(source)
    if not player then return false, 'failed' end
    local cash, bank = balances(player)
    return true, nil, {
        price = Config.canPrice, liters = Config.canLiters, station = station.label,
        cash = cash, bank = bank,
    }
end)

---@return boolean ok, string? errorCode, table? balances
lib.callback.register('exti_fuel:server:buyCan', function(source, stationId, pumpIndex, account)
    local src = source
    if busy[src] then return false, 'busy' end
    if account ~= 'cash' and account ~= 'bank' then return false, 'failed' end
    local station, pump = pumpAt(stationId, pumpIndex)
    if not station or not playerAtPump(src, pump) then return false, 'too_far' end
    local player = getPlayer(src)
    if not player then return false, 'failed' end

    -- a full can weighs 19 kg (4 kg can + 15 kg fuel)
    local okWeight, canWeight = pcall(function() return exports.ox_inventory:CanCarryWeight(src, 19000) end)
    local okItem, canItem = pcall(function() return exports.ox_inventory:CanCarryItem(src, Config.canItem, 1) end)
    if (okWeight and canWeight == false) or not okItem or not canItem then return false, 'cant_carry' end

    local cash, bank = balances(player)
    if (account == 'cash' and cash or bank) < Config.canPrice then return false, 'no_money' end

    busy[src] = true
    local ok, result = pcall(function()
        if not player.Functions.RemoveMoney(account, Config.canPrice, 'shop-fuel') then return 'no_money' end
        if not exports.ox_inventory:AddItem(src, Config.canItem, 1) then
            player.Functions.AddMoney(account, Config.canPrice, 'shop-refund')
            return 'cant_carry'
        end
        return true
    end)
    busy[src] = nil
    if not ok then
        lib.print.error(('[exti_fuel] jerry can sale failed for %s: %s'):format(src, tostring(result)))
        return false, 'failed'
    end
    if result ~= true then return false, result end

    lib.print.info(('%s (%s) bought a jerry can at %s for $%d (%s)'):format(GetPlayerName(src) or src,
        player.PlayerData.citizenid, station.label, Config.canPrice, account))
    player = getPlayer(src) or player
    local newCash, newBank = balances(player)
    return true, nil, { cash = newCash, bank = newBank }
end)

---------------------------------------------------------------------------
-- leaving: an unfinished pump stops and the unused money comes back
---------------------------------------------------------------------------
local function leave(src)
    local s = sessions[src]
    if s then
        s.leaving = true
        finish(src, 'gone')
    end
    endCanJob(src)
    busy[src] = nil
    lastReport[src] = nil
end

AddEventHandler('playerDropped', function() leave(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) leave(src) end)

AddEventHandler('entityRemoved', function(entity)
    lastDriver[entity] = nil
    justFilled[entity] = nil
    if fillingVeh[entity] then fillingVeh[entity] = nil end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(sessions) do
        sessions[src].leaving = true
        finish(src, 'gone')
    end
end)

---------------------------------------------------------------------------
-- for other scripts
---------------------------------------------------------------------------
exports('GetFuel', function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return fuelOf(vehicle)
end)

exports('SetFuel', function(vehicle, level)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not isNumber(level) then return false end
    setFuel(vehicle, level)
    return true
end)

--- Stations() -> the gas stations with their pumps (the police CCTV builds its camera list from them)
exports('Stations', function()
    return Config.stations
end)
