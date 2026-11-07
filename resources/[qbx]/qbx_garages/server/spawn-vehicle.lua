local logger = require '@qbx_core.modules.logger'

do -- EX_Tii: spot check (shared by the garages, impound lots and dealerships)
-- EX_Tii: is the place where a vehicle comes out free?
-- Used by the garages, the impound lots and the dealerships before a vehicle is made.
-- It looks at every vehicle and every person near the spot and uses the size of the
-- vehicle that will come out and the size of what is already there (car, bike, van,
-- truck, bus, boat, helicopter, plane), so a car in the next parking bay does not
-- count but anything that would touch the new vehicle does.

local MARGIN = 0.35 -- meters of free space kept around the new vehicle
local HEIGHT = 3.0  -- things this much higher or lower do not count (bridges, other floors)
local PERSON = 0.4  -- half the width of a person
local OBJECT = 0.5  -- half the width of a small object (cone, barrier, box)

local reserved = {} -- [spot key] = GetGameTimer() until which the spot is held
local function spotKey(x, y, z) return ('%.1f:%.1f:%.1f'):format(x, y, z) end

-- half length, half width (meters)
local SIZE = {
    car = { 2.45, 1.05 },
    big = { 2.75, 1.15 },   -- SUVs, off-road
    van = { 3.1, 1.25 },    -- vans, utility, emergency, service
    truck = { 5.0, 1.45 },  -- commercial, industrial, military
    bus = { 6.2, 1.45 },
    limo = { 3.6, 1.1 },
    bike = { 1.15, 0.45 },
    boat = { 4.0, 1.6 },
    heli = { 5.0, 5.0 },
    plane = { 7.0, 7.0 },
    trailer = { 5.0, 1.4 },
    train = { 10.0, 1.8 },
}

local BY_CATEGORY = {
    motorcycles = 'bike', cycles = 'bike',
    suvs = 'big', offroad = 'big',
    vans = 'van', utility = 'van', emergency = 'van', service = 'van',
    commercial = 'truck', industrial = 'truck', military = 'truck',
    boats = 'boat', helicopters = 'heli', planes = 'plane', trains = 'train',
}

local BY_TYPE = {
    bike = 'bike', boat = 'boat', submarine = 'boat', heli = 'heli', plane = 'plane',
    blimp = 'plane', trailer = 'trailer', train = 'train',
}

local BY_MODEL = {}
for name, group in pairs({
    bus = 'bus', coach = 'bus', airbus = 'bus', pbus = 'bus', pbus2 = 'bus', rentalbus = 'bus', tourbus = 'bus',
    firetruk = 'truck', trash = 'truck', trash2 = 'truck', stretch = 'limo', patriot2 = 'limo',
}) do
    BY_MODEL[joaat(name) & 0xFFFFFFFF] = group
end

local byHash -- qbx_core vehicle list keyed by model hash (loaded on first use)

local function unsigned(hash)
    return math.tointeger(hash) and (hash & 0xFFFFFFFF) or hash
end

local function vehicleInfo(hash)
    if byHash == nil then
        local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByHash() end)
        byHash = {}
        if ok and type(list) == 'table' then
            for key, entry in pairs(list) do
                if math.tointeger(key) then byHash[unsigned(key)] = entry end
            end
        end
    end
    return byHash[hash]
end

---@param model string|number|nil
---@param vehicleType string?
---@return number halfLength, number halfWidth
local function sizeOf(model, vehicleType)
    local hash = type(model) == 'string' and joaat(model) or tonumber(model)
    hash = hash and unsigned(math.tointeger(hash) or 0)
    local group = hash and BY_MODEL[hash]
    if not group and hash then
        local info = vehicleInfo(hash)
        group = info and (BY_CATEGORY[info.category] or BY_TYPE[info.type])
    end
    if not group and vehicleType then group = BY_TYPE[vehicleType] end
    local size = SIZE[group or 'car']
    return size[1], size[2]
end

-- do two boxes (center, heading, half length, half width) touch? (separating axis test)
local function boxesTouch(ax, ay, ah, aL, aW, bx, by, bh, bL, bW)
    local ar, br = math.rad(ah), math.rad(bh)
    local afx, afy = -math.sin(ar), math.cos(ar)
    local arx, ary = afy, -afx
    local bfx, bfy = -math.sin(br), math.cos(br)
    local brx, bry = bfy, -bfx
    local dx, dy = bx - ax, by - ay
    local axes = { afx, afy, arx, ary, bfx, bfy, brx, bry }
    for i = 1, 7, 2 do
        local x, y = axes[i], axes[i + 1]
        local d = math.abs(dx * x + dy * y)
        local ra = aL * math.abs(afx * x + afy * y) + aW * math.abs(arx * x + ary * y)
        local rb = bL * math.abs(bfx * x + bfy * y) + bW * math.abs(brx * x + bry * y)
        if d > ra + rb + MARGIN then return false end
    end
    return true
end

--- What stands where a vehicle of this model would come out.
---@param spot vector4 where the vehicle comes out (x, y, z, heading)
---@param model string|number|nil the vehicle that will come out
---@param ignorePed integer? the player who asked (never blocks his own vehicle)
---@return { entity: integer, kind: 'vehicle'|'person' }[]
function SpotBlockers(spot, model, ignorePed)
    local found = {}
    if not spot then return found end
    local sx, sy, sz, sh = spot.x + 0.0, spot.y + 0.0, spot.z + 0.0, (spot.w or 0.0) + 0.0
    local L, W = sizeOf(model)
    -- nothing further away than this can touch the new vehicle (10.2 = corner of the biggest box)
    local reach = math.sqrt(L * L + W * W) + 10.2 + MARGIN

    -- another vehicle is already on its way out here (a few seconds while it is made)
    local until_ = reserved[spotKey(sx, sy, sz)]
    if until_ and until_ > GetGameTimer() then
        found[#found + 1] = { entity = 0, kind = 'reserved' }
    end

    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        local veh = vehicles[i]
        if DoesEntityExist(veh) then
            local c = GetEntityCoords(veh)
            local dx, dy = c.x - sx, c.y - sy
            if math.abs(c.z - sz) < HEIGHT and dx * dx + dy * dy < reach * reach then
                local vL, vW = sizeOf(GetEntityModel(veh), GetVehicleType(veh))
                if boxesTouch(sx, sy, sh, L, W, c.x, c.y, GetEntityHeading(veh), vL, vW) then
                    found[#found + 1] = { entity = veh, kind = 'vehicle' }
                end
            end
        end
    end

    local peds = GetAllPeds()
    for i = 1, #peds do
        local ped = peds[i]
        if ped ~= ignorePed and DoesEntityExist(ped) and GetVehiclePedIsIn(ped, false) == 0 then
            local c = GetEntityCoords(ped)
            local dx, dy = c.x - sx, c.y - sy
            if math.abs(c.z - sz) < HEIGHT and dx * dx + dy * dy < reach * reach
                and boxesTouch(sx, sy, sh, L, W, c.x, c.y, 0.0, PERSON, PERSON) then
                found[#found + 1] = { entity = ped, kind = 'person' }
            end
        end
    end

    -- things put on the ground by scripts (police cones, barriers, boxes...); never removed
    local objects = GetAllObjects()
    for i = 1, #objects do
        local obj = objects[i]
        if DoesEntityExist(obj) and GetEntityAttachedTo(obj) == 0 then
            local c = GetEntityCoords(obj)
            local dx, dy = c.x - sx, c.y - sy
            if math.abs(c.z - sz) < HEIGHT and dx * dx + dy * dy < reach * reach
                and boxesTouch(sx, sy, sh, L, W, c.x, c.y, 0.0, OBJECT, OBJECT) then
                found[#found + 1] = { entity = obj, kind = 'object' }
            end
        end
    end
    return found
end

--- Hold a spot for a few seconds while a vehicle is being made there, so a second
--- player at the same moment does not get the same spot.
---@param spot vector4|vector3
---@param ms integer?
---@return boolean held false when another vehicle is already coming out there
function ReserveSpot(spot, ms)
    if not spot then return false end
    local key, now = spotKey(spot.x + 0.0, spot.y + 0.0, spot.z + 0.0), GetGameTimer()
    if reserved[key] and reserved[key] > now then return false end
    reserved[key] = now + (ms or 8000)
    return true
end

---@param spot vector4|vector3
function ReleaseSpot(spot)
    if not spot then return end
    reserved[spotKey(spot.x + 0.0, spot.y + 0.0, spot.z + 0.0)] = nil
end

--- The message a player sees when the spot is not free (nil when it is free).
---@param blockers { entity: integer, kind: string }[]
---@return string?
function SpotBlockedMessage(blockers)
    if #blockers == 0 then return nil end
    for i = 1, #blockers do
        if blockers[i].kind == 'vehicle' then
            return 'لا يمكن إخراج المركبة: توجد مركبة أخرى في مكان الخروج. أبعدها ثم حاول مرة أخرى.'
        end
    end
    for i = 1, #blockers do
        if blockers[i].kind == 'reserved' then
            return 'مركبة أخرى تخرج من هذا المكان الآن. انتظر لحظات ثم حاول مرة أخرى.'
        end
    end
    for i = 1, #blockers do
        if blockers[i].kind == 'object' then
            return 'لا يمكن إخراج المركبة: يوجد عائق (حاجز أو أغراض) في مكان الخروج.'
        end
    end
    return 'لا يمكن إخراج المركبة: يوجد شخص يقف في مكان الخروج. انتظر حتى يبتعد ثم حاول مرة أخرى.'
end
end

local spawningVehicles = {}

---@param player table
---@param garage GarageConfig
---@return boolean
local function canAccessGarage(player, garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(player.PlayerData.source, garage.groups) then
        return false
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.PlayerData.source) then
        return false
    end
    return true
end

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    return exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

---@param player table
---@param depotPrice integer
---@return string?
local function payDepotPrice(player, depotPrice)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    if cashBalance >= depotPrice then
        return player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot') and 'cash'
    elseif bankBalance >= depotPrice then
        return player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot') and 'bank'
    end
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
local function spawnVehicle(source, vehicleId, garageName, accessPointIndex)
    if type(vehicleId) ~= 'number' or vehicleId % 1 ~= 0 then return end
    if type(garageName) ~= 'string' then return end
    if type(accessPointIndex) ~= 'number' or accessPointIndex % 1 ~= 0 then return end

    local player = exports.qbx_core:GetPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not player or not garage or not canAccessGarage(player, garage) then return end

    local accessPoint = garage.accessPoints[accessPointIndex]
    if not accessPoint then
        logger.log({
            source = source,
            message = string.format(
                'Attempted to spawn a vehicle from a non-existent access point index: %d for garage: %s',
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })

        return
    end

    local distanceBetweenPlayerAndAccessPoint = #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz)
    if distanceBetweenPlayerAndAccessPoint > 3 then
        logger.log({
            source = source,
            message = string.format(
                'Player attempted to spawn a vehicle but was too far from the access point. Distance: %.2f, Access Point Index: %d, Garage: %s',
                distanceBetweenPlayerAndAccessPoint,
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.anticheat,
            event = 'suspicious',
            color = 'white'
        })

        return
    end
    local garageType = GetGarageType(garageName)

    local spawnCoords = accessPoint.spawn or accessPoint.coords

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle and garageType ~= GarageType.DEPOT and not garage.shared then
        -- A friend's car whose keys were shared with this player, parked in this garage
        local sharedVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, {
            garage = not garage.skipGarageCheck and garageName or nil,
            states = garage.states or VehicleState.GARAGED,
        })
        if sharedVehicle and HasSharedAccess(source, sharedVehicle) then
            playerVehicle = sharedVehicle
        end
    end
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    if type(playerVehicle.props) ~= 'table' or type(playerVehicle.props.plate) ~= 'string'
        or type(playerVehicle.props.model) ~= 'number' then return end
    -- EX_Tii: garages take out any car parked anywhere, so make sure it is the right kind (car / aircraft / boat)
    if VehicleKind and VehicleKind(playerVehicle.modelName) ~= garage.vehicleType then
        exports.qbx_core:Notify(source, locale('error.not_correct_type'), 'error')
        return
    end

    -- EX_Tii: the vehicle only comes out when nothing stands where it would appear
    -- (another vehicle or a person). An empty game car that nobody owns is cleared away;
    -- anything else stops it and the player is told why. Nothing is paid before this.
    if SpotBlockers then
        local blockers = SpotBlockers(spawnCoords, playerVehicle.props.model, GetPlayerPed(source))
        -- another car is being brought out here right now: wait (never clear it away)
        for i = 1, #blockers do
            if blockers[i].kind == 'reserved' then
                exports.qbx_core:Notify(source, SpotBlockedMessage({ blockers[i] }), 'error', 7000)
                return
            end
        end
        local left = {}
        for i = 1, #blockers do
            local b = blockers[i]
            if b.kind == 'vehicle' and IsLooseVehicle and IsLooseVehicle(b.entity) then
                DeleteEntity(b.entity)
            elseif b.kind == 'vehicle' and ImpoundIfOwnerAway and ImpoundIfOwnerAway(b.entity) then
                -- EX_Tii: a car whose owner is not in the city went to the impound; the spot is free
            else
                left[#left + 1] = b
            end
        end
        local message = SpotBlockedMessage(left)
        if message then
            exports.qbx_core:Notify(source, message, 'error', 7000)
            return
        end
        -- hold the spot from now on (checked and held in one step, nothing waits in between)
        if ReserveSpot and not ReserveSpot(spawnCoords, 8000) then
            exports.qbx_core:Notify(source, SpotBlockedMessage({ { kind = 'reserved' } }), 'error', 7000)
            return
        end
    elseif Config.distanceCheck then
        local vehicles = GetAllVehicles()
        for i = 1, #vehicles do
            if #(GetEntityCoords(vehicles[i]) - spawnCoords.xyz) < Config.distanceCheck then
                exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
                return
            end
        end
    end

    -- EX_Tii: the spot is held (above) while the vehicle is made; every way out below lets it go
    local function freeSpot() if ReleaseSpot then ReleaseSpot(spawnCoords) end end

    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        freeSpot()
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
    end

    if not GaragesHooks('spawnVehicle', {source = source, vehicleId = vehicleId, garageName = garageName}) then freeSpot() return end

    local paidFrom
    local depotPrice
    if garageType == GarageType.DEPOT then
        OverrideFreeDepotPriceForOutVehicle(playerVehicle)
        depotPrice = tonumber(playerVehicle.depotPrice) or 0
        if depotPrice ~= depotPrice or depotPrice < 0 or depotPrice > 100000000 then
            freeSpot()
            return
        end

        if depotPrice > 0 then
            paidFrom = payDepotPrice(player, depotPrice)
            if not paidFrom then
                freeSpot()
                exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
                return
            end
        end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local success, netId, veh = pcall(qbx.spawnVehicle, {
        spawnSource = spawnCoords,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = warpPed,
    })

    if not success or not netId or not veh or veh == 0 or not DoesEntityExist(veh) then
        freeSpot()
        if paidFrom then
            player.Functions.AddMoney(paidFrom, depotPrice, 'depot-spawn-refund')
        end
        return
    end

    if not GaragesHooks('spawnedVehicle', {source = source, vehicleId = vehicleId, vehicle = veh, garageName = garageName}) then
        exports.qbx_core:DeleteVehicle(veh)
        freeSpot()
        if paidFrom then player.Functions.AddMoney(paidFrom, depotPrice, 'depot-spawn-refund') end
        return
    end

    Entity(veh).state:set('vehicleid', vehicleId, false)
    -- EX_Tii fuel: the car comes out with the level it was parked with (exti_fuel keeps it on the car)
    local fuelLevel = tonumber(playerVehicle.props.fuelLevel)
    if fuelLevel then Entity(veh).state:set('fuel', math.max(0.0, math.min(100.0, fuelLevel + 0.0)), true) end
    local saved, result = pcall(setVehicleStateToOut, vehicleId, veh, playerVehicle.modelName)
    if not saved or not result then
        exports.qbx_core:DeleteVehicle(veh)
        freeSpot()
        if paidFrom then player.Functions.AddMoney(paidFrom, depotPrice, 'depot-spawn-refund') end
        return
    end

    if Config.doorsLocked then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(exports.qbx_vehiclekeys.GiveKeys, exports.qbx_vehiclekeys, source, veh, true)
    end
    if playerVehicle.citizenid then
        pcall(GiveSharedKeys, veh, vehicleId, playerVehicle.citizenid)
    end

    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)
    return netId
end

lib.callback.register('qbx_garages:server:spawnVehicle', function(source, vehicleId, garageName, accessPointIndex)
    if type(vehicleId) ~= 'number' or vehicleId % 1 ~= 0 or spawningVehicles[vehicleId] then return end
    spawningVehicles[vehicleId] = true
    local success, result = pcall(spawnVehicle, source, vehicleId, garageName, accessPointIndex)
    spawningVehicles[vehicleId] = nil
    if not success then
        lib.print.error(result)
        return
    end
    return result
end)

function OverrideFreeDepotPriceForOutVehicle(vehicle)
    if VehicleState.OUT ~= vehicle.state then return end
    if vehicle.depotPrice and vehicle.depotPrice > 0 then return end

    vehicle.depotPrice = Config.calculateImpoundFee(vehicle.id, vehicle.modelName)
end
