-- Modern garage screen (server side): vehicle list, nicknames, favourites,
-- shared keys, moving a car to this garage, and giving a car to another player.
-- Everything a player asks for is checked here; the screen is never trusted.

local UI = Config.garageUi or {}
local MOVE_FEE = math.max(0, math.floor(tonumber(UI.moveFee) or 500))
local MAX_SHARES = math.max(0, math.floor(tonumber(UI.maxShares) or 5))
local TRANSFER_TIMEOUT = math.max(10, math.floor(tonumber(UI.transferTimeout) or 30))
local NICKNAME_MAX = 30
local USE_DISTANCE = 6.0

---------------------------------------------------------------------------
-- Database tables (created automatically, nothing to import by hand)
---------------------------------------------------------------------------
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS garage_vehicle_names (
            vehicle_id INT NOT NULL,
            owner VARCHAR(50) NOT NULL,
            nickname VARCHAR(64) NOT NULL,
            PRIMARY KEY (vehicle_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS garage_favourites (
            citizenid VARCHAR(50) NOT NULL,
            vehicle_id INT NOT NULL,
            PRIMARY KEY (citizenid, vehicle_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS garage_shared_keys (
            vehicle_id INT NOT NULL,
            owner VARCHAR(50) NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            name VARCHAR(100) NOT NULL DEFAULT '',
            PRIMARY KEY (vehicle_id, citizenid),
            KEY citizenid (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        -- Forget rows for cars that no longer exist
        MySQL.query.await('DELETE n FROM garage_vehicle_names n LEFT JOIN player_vehicles v ON v.id = n.vehicle_id WHERE v.id IS NULL')
        MySQL.query.await('DELETE f FROM garage_favourites f LEFT JOIN player_vehicles v ON v.id = f.vehicle_id WHERE v.id IS NULL')
        MySQL.query.await('DELETE s FROM garage_shared_keys s LEFT JOIN player_vehicles v ON v.id = s.vehicle_id WHERE v.id IS NULL')
        -- EX_Tii (runs once): cars already out on the street now cost the new fixed $500 at the impound
        if GetResourceKvpInt('exti_impound_fee_500') ~= 1 then
            MySQL.update.await('UPDATE player_vehicles SET depotprice = 500 WHERE state = 0')
            SetResourceKvpInt('exti_impound_fee_500', 1)
        end
        -- EX_Tii (runs once): cars parked in the old garages now belong to the nearest new garage
        if GetResourceKvpInt('exti_garages_v2') ~= 1 then
            local moves = {
                pillboxgarage = 'ls_legion', sapcounsel = 'ls_legion', littleseoul = 'ls_legion',
                motelgarage = 'ls_alta', caears24 = 'ls_alta', lagunapi = 'ls_alta',
                spanishave = 'ls_vespucci', beachp = 'ls_vespucci', airportp = 'ls_vespucci',
                dumbogarage = 'ls_grove',
                themotorhotel = 'sandy_route68', liqourparking = 'sandy_shores', shoreparking = 'sandy_shores',
                haanparking = 'paleto_east',
            }
            local moved = 0
            for old, new in pairs(moves) do
                moved = moved + (MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE garage = ?', { new, old }) or 0)
            end
            SetResourceKvpInt('exti_garages_v2', 1)
            lib.print.info(('[garages] moved %d parked cars to the new garages'):format(moved))
        end
    end)
    if not ok then lib.print.error('[garage screen] could not prepare database tables: ' .. tostring(err)) end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local lastAction = {}

---@return boolean allowed false when the player is clicking too fast
local function throttle(source, ms)
    local now = GetGameTimer()
    if lastAction[source] and now - lastAction[source] < (ms or 400) then return false end
    lastAction[source] = now
    return true
end

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

local function isInt(v)
    return type(v) == 'number' and v % 1 == 0
end

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return '' end
    return plate:match('^%s*(.-)%s*$'):upper()
end

--- Plates of every vehicle currently in the world
local function platesOnMap()
    local set = {}
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        set[normalizePlate(GetVehicleNumberPlateText(vehicles[i]))] = vehicles[i]
    end
    return set
end

local function findVehicleByPlate(plate)
    local wanted = normalizePlate(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if normalizePlate(GetVehicleNumberPlateText(vehicles[i])) == wanted then return vehicles[i] end
    end
end

local function charName(player)
    local info = player and player.PlayerData.charinfo
    if not info then return '' end
    local name = ('%s %s'):format(info.firstname or '', info.lastname or '')
    return (name:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function vehicleKind(modelName)
    local v = VEHICLES[modelName]
    if not v then return VehicleType.CAR end
    if v.category == 'helicopters' or v.category == 'planes' then return VehicleType.AIR end
    if v.category == 'boats' then return VehicleType.SEA end
    return VehicleType.CAR
end
VehicleKind = vehicleKind

local function vehicleLabel(modelName)
    local v = VEHICLES[modelName]
    if not v then return modelName or '' end
    local brand = v.brand and v.brand ~= '' and (v.brand .. ' ') or ''
    return brand .. (v.name or modelName)
end

local function canUseGarage(source, garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(source, garage.groups) then return false end
    if garage.canAccess ~= nil and not garage.canAccess(source) then return false end
    return true
end

--- A normal public garage: anyone can park their own cars here
local function isPublicGarage(garage)
    return garage and garage.type ~= GarageType.DEPOT and not garage.groups and not garage.shared and not garage.canAccess
end

local function isNearGarage(source, garage, accessPointIndex)
    if not isInt(accessPointIndex) then return false end
    local point = garage.accessPoints[accessPointIndex]
    if not point then return false end
    local ped = GetPlayerPed(source)
    if ped <= 0 then return false end
    return #(GetEntityCoords(ped) - point.coords.xyz) <= USE_DISTANCE
end

local function inClause(n)
    return string.rep('?', n, ',')
end

local function safeQuery(query, params)
    local ok, result = pcall(MySQL.query.await, query, params)
    if not ok then
        lib.print.error('[garage screen] query failed: ' .. tostring(result))
        return {}
    end
    return result or {}
end

local function percent(value, max)
    value = tonumber(value)
    if not value then return 100 end
    return math.max(0, math.min(100, math.floor(value / max * 100 + 0.5)))
end

local function financeOf(vehicleIds)
    if #vehicleIds == 0 or GetResourceState('qbx_vehicleshop') ~= 'started' then return {} end
    local rows = safeQuery(('SELECT vehicleId, balance, paymentamount, paymentsleft, financetime FROM vehicle_financing WHERE balance > 0 AND vehicleId IN (%s)'):format(inClause(#vehicleIds)), vehicleIds)
    local map = {}
    for i = 1, #rows do
        local r = rows[i]
        map[r.vehicleId] = {
            balance = math.floor(tonumber(r.balance) or 0),
            payment = math.floor(tonumber(r.paymentamount) or 0),
            left = math.floor(tonumber(r.paymentsleft) or 0),
            minutes = math.max(0, math.floor(tonumber(r.financetime) or 0)),
        }
    end
    return map
end

--- Is this car shared with the player by its current owner?
---@return boolean
function HasSharedAccess(source, playerVehicle)
    if type(playerVehicle) ~= 'table' or not playerVehicle.id or not playerVehicle.citizenid then return false end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    local ok, found = pcall(MySQL.scalar.await, 'SELECT 1 FROM garage_shared_keys WHERE vehicle_id = ? AND citizenid = ? AND owner = ? LIMIT 1', {
        playerVehicle.id, player.PlayerData.citizenid, playerVehicle.citizenid,
    })
    return ok and found ~= nil
end

--- Give keys to everyone the owner shared this car with who is online right now
function GiveSharedKeys(vehicle, vehicleId, ownerCitizenId)
    if GetResourceState('qbx_vehiclekeys') ~= 'started' or not DoesEntityExist(vehicle) then return end
    local rows = safeQuery('SELECT citizenid FROM garage_shared_keys WHERE vehicle_id = ? AND owner = ?', { vehicleId, ownerCitizenId })
    for i = 1, #rows do
        local friend = exports.qbx_core:GetPlayerByCitizenId(rows[i].citizenid)
        if friend then
            pcall(exports.qbx_vehiclekeys.GiveKeys, exports.qbx_vehiclekeys, friend.PlayerData.source, vehicle, true)
        end
    end
end

--- Loads one car the player owns (or nil)
local function ownedVehicle(source, vehicleId)
    if not isInt(vehicleId) then return end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    return exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid }), player
end

local function takeMoney(player, amount, reason)
    if amount <= 0 then return true end
    local money = player.PlayerData.money
    if (money.cash or 0) >= amount then return player.Functions.RemoveMoney('cash', amount, reason) end
    if (money.bank or 0) >= amount then return player.Functions.RemoveMoney('bank', amount, reason) end
    return false
end

---------------------------------------------------------------------------
-- The vehicle list for one garage
---------------------------------------------------------------------------
local function buildVehicle(v, ctx)
    local props = type(v.props) == 'table' and v.props or {}
    local plate = props.plate or ''
    local onMap = ctx.onMap[normalizePlate(plate)] ~= nil
    local isOwner = v.citizenid == ctx.citizenid
    local status
    if ctx.isDepot then
        status = 'impounded'
    elseif v.state == VehicleState.GARAGED then
        status = v.garage == ctx.garageName and 'here' or 'other'
    elseif v.state == VehicleState.IMPOUNDED or (v.state == VehicleState.OUT and not onMap) then
        status = 'impounded'
    else
        status = 'out'
    end

    if ctx.isDepot and v.state == VehicleState.OUT then
        OverrideFreeDepotPriceForOutVehicle(v)
    end

    local otherGarage = Garages[v.garage]
    local entry = {
        id = v.id,
        model = v.modelName,
        label = vehicleLabel(v.modelName),
        nickname = ctx.names[v.id],
        plate = plate,
        status = status,
        garageLabel = otherGarage and otherGarage.label or nil,
        depotPrice = math.floor(tonumber(v.depotPrice) or 0),
        fuel = percent(props.fuelLevel, 100),
        engine = percent(props.engineHealth or 1000, 1000),
        body = percent(props.bodyHealth or 1000, 1000),
        favourite = ctx.favourites[v.id] == true,
        owner = isOwner,
        ownerName = (not isOwner) and ctx.ownerNames[v.citizenid] or nil,
        sharedWith = isOwner and ctx.shares[v.id] or nil,
        finance = isOwner and ctx.finance[v.id] or nil,
        photo = ctx.photos[v.id], -- EX_Tii: version of the real photo of this car (nil = stock picture)
        colour = props.color1,    -- EX_Tii: the car's paint (GTA colour index, or {r,g,b} for a custom colour): the screen tints the picture
        colour2 = props.color2,
    }
    -- EX_Tii: a car parked in any garage comes out free at every garage
    entry.canTakeOut = (status == 'here' or (ctx.isPublic and status == 'other') or (ctx.isDepot and status == 'impounded')) and not onMap
    entry.canMoveHere = false
    return entry
end

lib.callback.register('qbx_garages:server:getGarageData', function(source, garageName)
    if type(garageName) ~= 'string' then return end
    local garage = Garages[garageName]
    local player = exports.qbx_core:GetPlayer(source)
    if not garage or not player or not canUseGarage(source, garage) then return end

    local citizenid = player.PlayerData.citizenid
    local isPublic = isPublicGarage(garage)
    local isDepot = garage.type == GarageType.DEPOT
    local list = {}

    if isPublic then
        -- Every car of this type the player owns, wherever it is, plus cars shared with them
        local own = exports.qbx_vehicles:GetPlayerVehicles({ citizenid = citizenid })
        for i = 1, #own do list[#list + 1] = own[i] end
        local shared = safeQuery('SELECT s.vehicle_id FROM garage_shared_keys s INNER JOIN player_vehicles v ON v.id = s.vehicle_id AND v.citizenid = s.owner WHERE s.citizenid = ?', { citizenid })
        for i = 1, #shared do
            local v = exports.qbx_vehicles:GetPlayerVehicle(shared[i].vehicle_id)
            if v and v.citizenid ~= citizenid then list[#list + 1] = v end
        end
    else
        list = exports.qbx_vehicles:GetPlayerVehicles(GetPlayerVehicleFilter(source, garageName))
    end

    -- Only this garage's vehicle type (cars, aircraft or boats)
    local filtered, ids, ownerIds = {}, {}, {}
    local onMap = platesOnMap()
    for i = 1, #list do
        local v = list[i]
        if vehicleKind(v.modelName) == garage.vehicleType then
            local hide = not isPublic and onMap[normalizePlate(type(v.props) == 'table' and v.props.plate or '')] ~= nil
            if not hide then
                filtered[#filtered + 1] = v
                ids[#ids + 1] = v.id
                if v.citizenid and v.citizenid ~= citizenid then ownerIds[#ownerIds + 1] = v.citizenid end
            end
        end
    end

    local ctx = {
        citizenid = citizenid,
        garageName = garageName,
        isPublic = isPublic,
        isDepot = isDepot,
        onMap = onMap,
        names = {},
        favourites = {},
        shares = {},
        ownerNames = {},
        finance = financeOf(ids),
        photos = {}, -- EX_Tii (Moe): car photos are off, the stock pictures are used
    }

    if #ids > 0 then
        local rows = safeQuery(('SELECT n.vehicle_id, n.nickname FROM garage_vehicle_names n INNER JOIN player_vehicles v ON v.id = n.vehicle_id AND v.citizenid = n.owner WHERE n.vehicle_id IN (%s)'):format(inClause(#ids)), ids)
        for i = 1, #rows do ctx.names[rows[i].vehicle_id] = rows[i].nickname end

        rows = safeQuery('SELECT vehicle_id FROM garage_favourites WHERE citizenid = ?', { citizenid })
        for i = 1, #rows do ctx.favourites[rows[i].vehicle_id] = true end

        local params = { citizenid }
        for i = 1, #ids do params[#params + 1] = ids[i] end
        rows = safeQuery(('SELECT vehicle_id, citizenid, name FROM garage_shared_keys WHERE owner = ? AND vehicle_id IN (%s)'):format(inClause(#ids)), params)
        for i = 1, #rows do
            local r = rows[i]
            ctx.shares[r.vehicle_id] = ctx.shares[r.vehicle_id] or {}
            local list2 = ctx.shares[r.vehicle_id]
            list2[#list2 + 1] = { citizenid = r.citizenid, name = r.name }
        end
    end

    if #ownerIds > 0 then
        local rows = safeQuery(('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(inClause(#ownerIds)), ownerIds)
        for i = 1, #rows do
            local ok, info = pcall(json.decode, rows[i].charinfo or '{}')
            if ok and type(info) == 'table' then
                ctx.ownerNames[rows[i].citizenid] = ('%s %s'):format(info.firstname or '', info.lastname or '')
            end
        end
    end

    local vehicles = {}
    for i = 1, #filtered do vehicles[#vehicles + 1] = buildVehicle(filtered[i], ctx) end

    return {
        name = garageName,
        label = garage.label,
        vehicleType = garage.vehicleType,
        isDepot = isDepot,
        isPublic = isPublic,
        moveFee = MOVE_FEE,
        maxShares = MAX_SHARES,
        vehicles = vehicles,
    }
end)

---------------------------------------------------------------------------
-- Nickname and favourite
---------------------------------------------------------------------------
lib.callback.register('qbx_garages:server:renameVehicle', function(source, vehicleId, nickname)
    if not throttle(source) then return false end
    local vehicle, player = ownedVehicle(source, vehicleId)
    if not vehicle then return false end
    if type(nickname) ~= 'string' then return false end

    nickname = (nickname:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''))
    local len = utf8.len(nickname)
    if not len then return false end -- not valid text
    if len > NICKNAME_MAX then return false end

    if len == 0 then
        MySQL.query.await('DELETE FROM garage_vehicle_names WHERE vehicle_id = ?', { vehicleId })
    else
        MySQL.query.await('INSERT INTO garage_vehicle_names (vehicle_id, owner, nickname) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE owner = VALUES(owner), nickname = VALUES(nickname)', {
            vehicleId, player.PlayerData.citizenid, nickname,
        })
    end
    return true
end)

lib.callback.register('qbx_garages:server:setFavourite', function(source, vehicleId, favourite)
    if not throttle(source, 250) then return false end
    if not isInt(vehicleId) then return false end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    local vehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not vehicle then return false end
    if vehicle.citizenid ~= player.PlayerData.citizenid and not HasSharedAccess(source, vehicle) then return false end

    if favourite then
        MySQL.query.await('INSERT IGNORE INTO garage_favourites (citizenid, vehicle_id) VALUES (?, ?)', { player.PlayerData.citizenid, vehicleId })
    else
        MySQL.query.await('DELETE FROM garage_favourites WHERE citizenid = ? AND vehicle_id = ?', { player.PlayerData.citizenid, vehicleId })
    end
    return true
end)

---------------------------------------------------------------------------
-- Move a car parked in another garage to this one (for a fee)
---------------------------------------------------------------------------
lib.callback.register('qbx_garages:server:moveVehicleHere', function(source, vehicleId, garageName, accessPointIndex)
    if not throttle(source, 800) then return false, 'busy' end
    if type(garageName) ~= 'string' then return false end
    local garage = Garages[garageName]
    if not isPublicGarage(garage) or not canUseGarage(source, garage) then return false, 'no_access' end
    if not isNearGarage(source, garage, accessPointIndex) then return false, 'too_far' end

    local vehicle, player = ownedVehicle(source, vehicleId)
    if not vehicle then return false, 'not_owner' end
    if vehicle.state ~= VehicleState.GARAGED or vehicle.garage == garageName then return false, 'not_parked' end
    if vehicleKind(vehicle.modelName) ~= garage.vehicleType then return false, 'wrong_type' end
    if findVehicleByPlate(vehicle.props and vehicle.props.plate) then return false, 'is_out' end

    if not takeMoney(player, MOVE_FEE, 'garage-move-vehicle') then return false, 'no_money' end

    local okUpdate, changed = pcall(MySQL.update.await, 'UPDATE player_vehicles SET garage = ?, state = ? WHERE id = ? AND citizenid = ? AND state = ?', {
        garageName, VehicleState.GARAGED, vehicleId, player.PlayerData.citizenid, VehicleState.GARAGED,
    })
    if not okUpdate or not changed or changed == 0 then
        if MOVE_FEE > 0 then player.Functions.AddMoney('bank', MOVE_FEE, 'garage-move-refund') end
        return false, 'failed'
    end
    return true
end)

---------------------------------------------------------------------------
-- Shared keys
---------------------------------------------------------------------------
lib.callback.register('qbx_garages:server:shareKeys', function(source, vehicleId, targetId, garageName, accessPointIndex)
    if not throttle(source, 800) then return false, 'busy' end
    local garage = type(garageName) == 'string' and Garages[garageName]
    if not garage or not isNearGarage(source, garage, accessPointIndex) then return false, 'too_far' end
    local vehicle, player = ownedVehicle(source, vehicleId)
    if not vehicle then return false, 'not_owner' end

    targetId = tonumber(targetId)
    if not targetId or targetId % 1 ~= 0 or targetId == source then return false, 'bad_player' end
    local target = exports.qbx_core:GetPlayer(targetId)
    if not target then return false, 'bad_player' end
    if target.PlayerData.citizenid == player.PlayerData.citizenid then return false, 'bad_player' end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM garage_shared_keys WHERE vehicle_id = ? AND owner = ?', { vehicleId, player.PlayerData.citizenid }) or 0
    if count >= MAX_SHARES then return false, 'too_many' end

    local name = charName(target)
    MySQL.query.await('INSERT INTO garage_shared_keys (vehicle_id, owner, citizenid, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE owner = VALUES(owner), name = VALUES(name)', {
        vehicleId, player.PlayerData.citizenid, target.PlayerData.citizenid, name,
    })

    -- If the car is out right now, the friend gets keys straight away
    local entity = findVehicleByPlate(vehicle.props and vehicle.props.plate)
    if entity and GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(exports.qbx_vehiclekeys.GiveKeys, exports.qbx_vehiclekeys, targetId, entity, true)
    end

    exports.qbx_core:Notify(targetId, locale('ui.keys_received', charName(player), vehicleLabel(vehicle.modelName)), 'success', 6000)
    return true, name
end)

lib.callback.register('qbx_garages:server:unshareKeys', function(source, vehicleId, citizenid)
    if not throttle(source, 400) then return false end
    if type(citizenid) ~= 'string' or #citizenid > 50 then return false end
    local vehicle, player = ownedVehicle(source, vehicleId)
    if not vehicle then return false end
    MySQL.query.await('DELETE FROM garage_shared_keys WHERE vehicle_id = ? AND owner = ? AND citizenid = ?', { vehicleId, player.PlayerData.citizenid, citizenid })
    MySQL.query.await('DELETE FROM garage_favourites WHERE vehicle_id = ? AND citizenid = ?', { vehicleId, citizenid })
    return true
end)

---------------------------------------------------------------------------
-- Give a car to another player (they must accept)
---------------------------------------------------------------------------
local pendingTransfers = {}
local transferBusy = {}

RegisterNetEvent('qbx_garages:server:answerTransfer', function(token, accepted)
    local pending = type(token) == 'string' and pendingTransfers[token]
    if not pending or pending.target ~= source then return end
    pendingTransfers[token] = nil
    pending.promise:resolve(accepted == true)
end)

local function isFinanced(vehicleId)
    if GetResourceState('qbx_vehicleshop') ~= 'started' then return false end
    local ok, financed = pcall(MySQL.scalar.await, 'SELECT 1 FROM vehicle_financing WHERE vehicleId = ? AND balance > 0 LIMIT 1', { vehicleId })
    return ok and financed ~= nil
end

lib.callback.register('qbx_garages:server:giveVehicle', function(source, vehicleId, targetId, garageName, accessPointIndex)
    if transferBusy[source] or not throttle(source, 1000) then return false, 'busy' end
    local garage = type(garageName) == 'string' and Garages[garageName]
    if not garage or not isNearGarage(source, garage, accessPointIndex) then return false, 'too_far' end
    local vehicle, player = ownedVehicle(source, vehicleId)
    if not vehicle then return false, 'not_owner' end
    if vehicle.state ~= VehicleState.GARAGED or findVehicleByPlate(vehicle.props and vehicle.props.plate) then return false, 'not_parked' end
    if isFinanced(vehicleId) then return false, 'financed' end

    targetId = tonumber(targetId)
    if not targetId or targetId % 1 ~= 0 or targetId == source then return false, 'bad_player' end
    local target = exports.qbx_core:GetPlayer(targetId)
    if not target or target.PlayerData.citizenid == player.PlayerData.citizenid then return false, 'bad_player' end

    transferBusy[source] = true
    local token = ('%d:%d:%d'):format(source, vehicleId, math.random(100000, 999999))
    local p = promise.new()
    pendingTransfers[token] = { target = targetId, promise = p }
    SetTimeout(TRANSFER_TIMEOUT * 1000, function()
        if pendingTransfers[token] then
            pendingTransfers[token] = nil
            p:resolve(false)
        end
    end)
    TriggerClientEvent('qbx_garages:client:askTransfer', targetId, token, {
        from = charName(player),
        label = vehicleLabel(vehicle.modelName),
        plate = vehicle.props and vehicle.props.plate or '',
        timeout = TRANSFER_TIMEOUT,
    })

    local accepted = Citizen.Await(p)
    transferBusy[source] = nil
    if not accepted then return false, 'declined' end

    -- Check everything again: things may have changed while waiting
    local still = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
    if not still or still.state ~= VehicleState.GARAGED or findVehicleByPlate(still.props and still.props.plate) or isFinanced(vehicleId) then
        return false, 'failed'
    end
    target = exports.qbx_core:GetPlayer(targetId)
    if not target then return false, 'bad_player' end

    local ok, err = exports.qbx_vehicles:SetPlayerVehicleOwner(vehicleId, target.PlayerData.citizenid)
    if ok == false then
        lib.print.error('[garage screen] transfer failed: ' .. json.encode(err))
        return false, 'failed'
    end

    MySQL.query.await('DELETE FROM garage_shared_keys WHERE vehicle_id = ?', { vehicleId })
    MySQL.query.await('DELETE FROM garage_favourites WHERE vehicle_id = ?', { vehicleId })
    MySQL.query.await('DELETE FROM garage_vehicle_names WHERE vehicle_id = ?', { vehicleId })

    exports.qbx_core:Notify(targetId, locale('ui.vehicle_received', vehicleLabel(vehicle.modelName), Garages[still.garage] and Garages[still.garage].label or ''), 'success', 7000)
    return true
end)

AddEventHandler('playerDropped', function()
    transferBusy[source] = nil
end)
