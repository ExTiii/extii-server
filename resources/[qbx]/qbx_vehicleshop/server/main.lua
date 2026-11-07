lib.versionCheck('Qbox-project/qbx_vehicleshop')
assert(lib.checkDependency('qbx_core', '1.17.2'), 'qbx_core v1.17.2 or higher is required')
assert(lib.checkDependency('qbx_vehicles', '1.4.1'), 'qbx_vehicles v1.4.1 or higher is required')

local config = require 'config.server'
local sharedConfig = require 'config.shared'
local catalog = require 'config.catalog'
local financeStorage = require 'server.storage'
local allowedVehicles = require 'server.vehicles'
COREVEHICLES = exports.qbx_core:GetVehiclesByName()

local saleTimeout = {}
local testDrives = {}
local busy = {}

-- EX_Tii: where a bought vehicle is parked when it cannot be brought out at the dealer
-- (public garages hand out any car of the right kind, free)
local FALLBACK_GARAGE = { pdm = 'ls_legion', boats = 'lsymc', air = 'intairport' }

-- ---------------------------------------------------------------------------
-- EX_Tii dealership panel: buy and test drive straight from the panel.
-- Everything is checked here (shop, model, price, money, space); the client
-- only says which car, which colour and how to pay.
-- ---------------------------------------------------------------------------

---@param colour any index sent by the panel (0 = factory colour)
---@return table? props, boolean valid
local function colourProps(colour)
    if colour == nil or colour == 0 then return nil, true end
    if math.type(colour) ~= 'integer' then return nil, false end
    local entry = catalog.colours[colour]
    if not entry then return nil, false end
    return { color1 = { entry.rgb[1], entry.rgb[2], entry.rgb[3] } }, true
end

---@param src number
---@param model any
---@return table? vehicle, string? shopId, table? shop, string? errorCode
local function checkRequest(src, model)
    if type(model) ~= 'string' then return nil, nil, nil, 'failed' end
    local vehicle = allowedVehicles.byModel[model]
    if not vehicle then return nil, nil, nil, 'not_sold' end

    local shopId = GetShopZone(src)
    local shop = shopId and sharedConfig.shops[shopId]
    if not shop or shop.type ~= 'free-use' then return nil, nil, nil, 'not_here' end
    if vehicle.shopType ~= shopId then return nil, nil, nil, 'not_sold' end

    return vehicle, shopId, shop
end

local function vehicleTitle(vehicle)
    if vehicle.brand and vehicle.brand ~= '' then
        return ('%s %s'):format(vehicle.brand, vehicle.name)
    end
    return vehicle.name or vehicle.model
end

---@param source number
---@param model string
---@param colour integer
---@param account 'cash'|'bank'
---@return boolean ok, string? errorCode, integer? vehicleId
lib.callback.register('exti_vshop:server:buy', function(source, model, colour, account)
    local src = source
    if not sharedConfig.enableFreeUseBuy then return false, 'failed' end
    if busy[src] then return false, 'busy' end
    if account ~= 'cash' and account ~= 'bank' then return false, 'failed' end
    if Player(src).state.isInTestDrive then return false, 'in_test' end

    local vehicle, _, shop, err = checkRequest(src, model)
    if not vehicle then return false, err end

    local props, colourOk = colourProps(colour)
    if not colourOk then return false, 'failed' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'failed' end

    local price = vehicle.price
    if (player.PlayerData.money[account] or 0) < price then return false, 'no_money' end

    local coords = GetClearSpawnArea(shop.vehicleSpawns, vehicle.model, src)
    if not coords then return false, 'no_space' end

    busy[src] = true
    -- EX_Tii: money and car are tracked separately so a failure never takes money without a car
    local charged, boughtId = false, nil
    local ok, result = pcall(function()
        if not config.removePlayerFunds(player, account, price, 'vehicle-bought-in-showroom') then
            return 'no_money'
        end
        charged = true

        local vehicleId = exports.qbx_vehicles:CreatePlayerVehicle({
            model = vehicle.model,
            citizenid = player.PlayerData.citizenid,
            props = props,
        })
        if not vehicleId then return 'failed' end
        boughtId = vehicleId

        local spawned, netId = pcall(SpawnVehicle, src, {
            coords = coords,
            vehicleId = vehicleId
        })

        if spawned and netId then
            exports.qbx_core:Notify(src, ('مبارك عليك %s الجديدة!'):format(vehicleTitle(vehicle)), 'success')
        else
            if not spawned then lib.print.error(('bought %s but the spawn failed for %s: %s'):format(vehicle.model, src, netId)) end
            -- it is yours: park it in a public garage so it can be taken out for free anywhere
            local garage = FALLBACK_GARAGE[vehicle.shopType or ''] or 'ls_legion'
            pcall(MySQL.update.await, 'UPDATE player_vehicles SET state = 1, garage = ? WHERE id = ?', { garage, vehicleId })
            exports.qbx_core:Notify(src, 'تم الشراء، لكن تعذّر إخراج المركبة هنا. ستجدها في أي مرآب.', 'inform', 9000)
        end

        lib.print.info(('%s (%s) bought %s for $%s with %s'):format(GetPlayerName(src), player.PlayerData.citizenid, vehicle.model, price, account))
        return true
    end)
    busy[src] = nil

    if charged and not boughtId then
        config.addPlayerFunds(player, account, price, 'vehicle-purchase-refund')
    end
    if not boughtId and ReleaseSpot then ReleaseSpot(coords) end
    if boughtId then return true, nil, boughtId end
    if not ok then
        lib.print.error(('buy failed for %s: %s'):format(src, result))
        return false, 'failed'
    end
    return false, result
end)

---@param source number
---@param model string
---@param colour integer
---@return boolean ok, string? errorCode
lib.callback.register('exti_vshop:server:testDrive', function(source, model, colour)
    local src = source
    if not sharedConfig.enableTestDrive then return false, 'failed' end
    if busy[src] then return false, 'busy' end
    if Player(src).state.isInTestDrive or testDrives[src] then return false, 'in_test' end

    local vehicle, _, shop, err = checkRequest(src, model)
    if not vehicle then return false, err end

    local props, colourOk = colourProps(colour)
    if not colourOk then return false, 'failed' end

    local coords = GetClearSpawnArea(shop.vehicleSpawns, vehicle.model, src)
    if not coords then return false, 'no_space' end

    busy[src] = true
    local plate = 'TEST' .. lib.string.random('1111')
    local ok, netId = pcall(SpawnVehicle, src, {
        modelName = vehicle.model,
        coords = coords,
        plate = plate,
        props = props,
    })
    busy[src] = nil
    if not ok or not netId then
        if ReleaseSpot then ReleaseSpot(coords) end
        return false, 'failed'
    end

    local testDrive = shop.testDrive
    local session = {
        netId = netId,
        plate = plate, -- EX_Tii: only ever delete the test car itself
        endBehavior = testDrive.endBehavior,
        returnLocation = shop.returnLocation
    }
    testDrives[src] = session

    Player(src).state:set('isInTestDrive', testDrive.limit, true)
    SetTimeout(math.floor(testDrive.limit * 60000), function()
        if testDrives[src] ~= session then return end
        Player(src).state:set('isInTestDrive', nil, true)
    end)

    return true
end)

AddStateBagChangeHandler('isInTestDrive', nil, function(bagName, _, value)
    if value then return end

    local plySrc = GetPlayerFromStateBagName(bagName)
    if not plySrc then return end
    local testDrive = testDrives[plySrc]
    if not testDrive then return end
    local netId = testDrive.netId
    local endBehavior = testDrive.endBehavior
    if not netId or endBehavior == 'none' then
        testDrives[plySrc] = nil
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    -- EX_Tii: the id may belong to another vehicle by now (test car already removed)
    if vehicle ~= 0 and DoesEntityExist(vehicle) and testDrive.plate
        and qbx.string.trim(GetVehicleNumberPlateText(vehicle)) ~= testDrive.plate then
        vehicle = 0
    end

    if endBehavior == 'return' then
        local coords = testDrive.returnLocation
        local plyPed = GetPlayerPed(plySrc)
        if #(GetEntityCoords(plyPed) - coords) > 10 then -- don't teleport if they are standing near the spot
            SetEntityCoords(plyPed, coords.x, coords.y, coords.z, false, false, false, false)
        end
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    elseif endBehavior == 'destroy' then
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    testDrives[plySrc] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if cache.resource ~= resourceName then return end

    for player, _ in pairs(testDrives) do
        Player(player).state:set('isInTestDrive', nil, true)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    local testDrive = testDrives[src]
    local vehicle = testDrive and testDrive.netId and NetworkGetEntityFromNetworkId(testDrive.netId)
    if vehicle and DoesEntityExist(vehicle)
        and (not testDrive.plate or qbx.string.trim(GetVehicleNumberPlateText(vehicle)) == testDrive.plate) then
        DeleteEntity(vehicle)
    end
    testDrives[src] = nil
end)

-- EX_Tii (Moe): no giving / transferring cars to other players any more (sell to the used-car buyer instead).
-- The old command stays here, switched off.
local TRANSFER_ON = false
-- Transfer vehicle to player in passenger seat
if TRANSFER_ON then lib.addCommand('transfervehicle', {
    help = locale('general.command_transfervehicle'),
    params = {
        {
            name = 'id',
            type = 'playerId',
            help = locale('general.command_transfervehicle_help')
        },
        {
            name = 'amount',
            type = 'number',
            help = locale('general.command_transfervehicle_amount'),
            optional = true
        }
    }
}, function(source, args)
    local buyerId = args.id
    local sellAmount = args.amount or 0

    if math.type(sellAmount) ~= 'integer' or sellAmount < 0 then return end

    if source == buyerId then
        return exports.qbx_core:Notify(source, locale('error.selftransfer'), 'error')
    end
    if saleTimeout[source] then
        return exports.qbx_core:Notify(source, locale('error.sale_timeout'), 'error')
    end
    if buyerId == 0 then
        return exports.qbx_core:Notify(source, locale('error.Invalid_ID'), 'error')
    end

    local ped = GetPlayerPed(source)
    local targetPed = GetPlayerPed(buyerId)
    if targetPed == 0 then
        return exports.qbx_core:Notify(source, locale('error.buyerinfo'), 'error')
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        return exports.qbx_core:Notify(source, locale('error.notinveh'), 'error')
    end

    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    if not vehicleId then
        return exports.qbx_core:Notify(source, locale('error.notowned'), 'error')
    end

    local player = exports.qbx_core:GetPlayer(source)
    local target = exports.qbx_core:GetPlayer(buyerId)
    if not player or not target then
        return exports.qbx_core:Notify(source, locale('error.buyerinfo'), 'error')
    end

    local row = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    local isFinanced = sharedConfig.finance.enable and financeStorage.fetchIsFinanced(vehicleId)

    if not row then return end

    if config.finance.preventSelling and isFinanced then
        return exports.qbx_core:Notify(source, locale('error.financed'), 'error')
    end

    if row.citizenid ~= player.PlayerData.citizenid then
        return exports.qbx_core:Notify(source, locale('error.notown'), 'error')
    end

    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > 5.0 then
        return exports.qbx_core:Notify(source, locale('error.playertoofar'), 'error')
    end

    local targetcid = target.PlayerData.citizenid

    saleTimeout[source] = true

    SetTimeout(config.saleTimeout, function()
        saleTimeout[source] = false
    end)

    if isFinanced then
        local financeData = financeStorage.fetchFinancedVehicleEntityById(vehicleId)
        local confirmFinance = lib.callback.await('qbx_vehicleshop:client:confirmFinance', buyerId, financeData)
        if not confirmFinance then
            return exports.qbx_core:Notify(source, locale('error.buyerdeclined'), 'error')
        end
    end

    lib.callback('qbx_vehicleshop:client:confirmTrade', buyerId, function(approved)
        if not approved then
            exports.qbx_core:Notify(source, locale('error.buyerdeclined'), 'error')
            return
        end

        -- EX_Tii: look again after the wait - money and owner may have changed meanwhile
        player = exports.qbx_core:GetPlayer(source)
        target = exports.qbx_core:GetPlayer(buyerId)
        if not player or not target or target.PlayerData.citizenid ~= targetcid then
            return exports.qbx_core:Notify(source, locale('error.buyerinfo'), 'error')
        end
        local stillOwned = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
        if not stillOwned then
            return exports.qbx_core:Notify(source, locale('error.notown'), 'error')
        end

        if sellAmount > 0 then
            local currencyType = FindChargeableCurrencyType(sellAmount, target.PlayerData.money.cash, target.PlayerData.money.bank)

            if not currencyType then
                return exports.qbx_core:Notify(source, locale('error.buyertoopoor'), 'error')
            end

            if not config.removePlayerFunds(target, currencyType, sellAmount, 'vehicle-bought-from-player') then
                return exports.qbx_core:Notify(source, locale('error.buyertoopoor'), 'error')
            end
            config.addPlayerFunds(player, currencyType, sellAmount, 'vehicle-sold-to-player')
        end

        exports.qbx_vehicles:SetPlayerVehicleOwner(row.id, targetcid)
        config.giveKeys(buyerId, row.plate, vehicle)

        local sellerMessage = sellAmount > 0 and locale('success.soldfor') .. lib.math.groupdigits(sellAmount) or locale('success.gifted')
        local buyerMessage = sellAmount > 0 and locale('success.boughtfor') .. lib.math.groupdigits(sellAmount) or locale('success.received_gift')

        exports.qbx_core:Notify(source, sellerMessage, 'success')
        exports.qbx_core:Notify(buyerId, buyerMessage, 'success')
        if isFinanced and SetHasFinanced then
            SetHasFinanced(buyerId, true)
        end
    end, GetEntityModel(vehicle), sellAmount)
end) end
