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

local config = require 'config.server'
local allowedVehicles = require 'server.vehicles'

---@param vehicle string Vehicle model name to check if allowed for purchase/testdrive/etc.
---@param shop string? Shop name to check if vehicle is allowed in that shop
---@return boolean
function CheckVehicleList(vehicle, shop)
    if type(vehicle) ~= 'string' then return false end
    local allowedVeh = allowedVehicles.byModel[vehicle]
    return allowedVeh ~= nil and (not shop or allowedVeh.shopType == shop)
end

local shops = require 'config.shared'.shops
local shopZones = {}

---@param source number
---@return string?
function GetShopZone(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    for i = 1, #shopZones do
        local zone = shopZones[i]
        if zone:contains(coords) then
            return zone.name
        end
    end
end

-- Create shop zones for point checking
CreateThread(function()
    for shopName, shop in pairs(shops) do
        shopZones[#shopZones + 1] = lib.zones.poly({
            name = shopName,
            points = shop.zone.shape,
            thickness = 5,
        })

        for i = 1, #shop.showroomVehicles do
            local vehicle = shop.showroomVehicles[i]

            if not CheckVehicleList(vehicle.vehicle, shopName) then
                lib.print.warn(('Vehicle "%s" is a showroom vehicle for shop "%s" but is not allowed to be bought there'):format(vehicle.vehicle, shopName))
            end
        end
    end
end)

---@param price number
---@param cash number
---@param bank number
---@return 'cash'|'bank'|nil
function FindChargeableCurrencyType(price, cash, bank)
    if cash >= price then
        return 'cash'
    elseif bank >= price then
        return 'bank'
    else
        return
    end
end

---@param src number
---@param amount number
---@param reason string?
---@return boolean success if money was removed
function RemoveMoney(src, amount, reason)
    local player = exports.qbx_core:GetPlayer(src)
    local cash = player.PlayerData.money.cash
    local bank = player.PlayerData.money.bank
    local currencyType = FindChargeableCurrencyType(amount, cash, bank)

    if not currencyType then
        exports.qbx_core:Notify(src, locale('error.notenoughmoney'), 'error')
        return false
    end

    return config.removePlayerFunds(player, currencyType, amount, reason)
end

---@param spawns vector4[]
---@param model string? the vehicle that will come out (its size is used)
---@param src number? the player buying (never blocks his own vehicle)
---@return vector4 | nil
function GetClearSpawnArea(spawns, model, src)
    for i = 1, #spawns do
        local spawn = spawns[i]

        -- EX_Tii: free only when no vehicle and no person stands where the vehicle would appear
        if SpotBlockers then
            -- free, and held while the money, the database and the spawn run (nobody else gets it)
            if #SpotBlockers(spawn, model, src and GetPlayerPed(src) or nil) == 0
                and (not ReserveSpot or ReserveSpot(spawn, 10000)) then
                return spawn
            end
        elseif #lib.getNearbyVehicles(spawn.xyz) == 0 then
            return spawn
        end
    end
end

---@param src number
---@param data {coords: vector4, vehicleId?: number, modelName: string, plate?: string, props?: table}
---@return number|nil
function SpawnVehicle(src, data)
    local coords, vehicleId = data.coords, data.vehicleId
    local newVehicle = vehicleId and exports.qbx_vehicles:GetPlayerVehicle(vehicleId) or data
    if not newVehicle then return end

    -- EX_Tii: keep every saved property (paint colour etc.), not only the plate
    local props = type(newVehicle.props) == 'table' and newVehicle.props or {}
    local plate = newVehicle.plate or props.plate
    props.plate = plate

    local netId, vehicle = qbx.spawnVehicle({
        model = newVehicle.modelName,
        spawnSource = coords,
        warp = GetPlayerPed(src),
        props = props
    })

    if not netId or netId == 0 or not vehicle or vehicle == 0 then return end

    if vehicleId then
        Entity(vehicle).state:set('vehicleid', vehicleId, false)
    end

    -- EX_Tii fuel: new cars and test drives leave the showroom full (exti_fuel keeps the level on the car)
    local fuelLevel = tonumber(props.fuelLevel) or 100.0
    Entity(vehicle).state:set('fuel', math.max(0.0, math.min(100.0, fuelLevel + 0.0)), true)

    -- EX_Tii: the car exists now; a problem with the keys must not count as "no car"
    local keysOk, keysErr = pcall(config.giveKeys, src, plate, vehicle)
    if not keysOk then lib.print.error(('giving keys failed for %s: %s'):format(src, keysErr)) end

    return netId
end
