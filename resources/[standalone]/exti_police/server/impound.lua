-- =====================================================================
-- EX_Tii police: impound a vehicle (Z wheel -> حجز المركبة). The officer picks the release fee
-- ($500 - $5,000) and writes why; the car goes to the impound lots, the owner pays the fee there
-- to get it back. Every impound is in the police log.
-- =====================================================================
local getPlayer, onDuty, nameOf = POL.getPlayer, POL.onDuty, POL.nameOf
local FEES = { [500] = true, [1000] = true, [2500] = true, [5000] = true }
local IMPOUNDED = 2          -- qbx_vehicles VehicleState.IMPOUNDED
local DEPOT = 'impoundlot'   -- qbx_garages: the car impound lots (any of them)
local busy = {}

lib.callback.register('exti_police:server:impound', function(source, netId, fee, reason)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if busy[source] then return false, 'wait' end
    fee = math.tointeger(tonumber(fee))
    if not fee or not FEES[fee] then return false, 'amount' end
    reason = type(reason) == 'string' and reason:gsub('[%c<>]', ''):sub(1, 120) or ''
    if #reason < 3 then return false, 'reason' end
    local veh = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, 'vehicle' end
    local ped = GetPlayerPed(source)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'in_vehicle' end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 then return false, 'too_far' end
    for seat = -1, 7 do if GetPedInVehicleSeat(veh, seat) ~= 0 then return false, 'occupied' end end
    if Entity(veh).state.exti_police_fleet or Entity(veh).state.exti_police then return false, 'fleet' end
    local cls = GetVehicleType(veh)
    if cls == 'boat' or cls == 'heli' or cls == 'plane' or cls == 'submarine' then return false, 'kind' end

    busy[source] = true
    local plate = GetVehicleNumberPlateText(veh):match('^%s*(.-)%s*$')
    local vehicleId = Entity(veh).state.vehicleid
    if not vehicleId then
        local ok, id = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(veh)) end)
        vehicleId = ok and id or nil
    end
    local owned
    if vehicleId then
        local ok, row = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
        owned = ok and row or nil
    end
    if owned then
        local props = type(owned.props) == 'table' and owned.props or nil
        if props then
            local fuel = Entity(veh).state.fuel
            if type(fuel) == 'number' then props.fuelLevel = math.floor(fuel + 0.5) end
            props.bodyHealth = GetVehicleBodyHealth(veh)
            props.engineHealth = GetVehicleEngineHealth(veh)
        end
        local okS, saved = pcall(function()
            return exports.qbx_vehicles:SaveVehicle(veh, { state = IMPOUNDED, depotPrice = fee, garage = DEPOT, props = props })
        end)
        if not okS or not saved then busy[source] = nil; return false, 'failed' end
        local okD = pcall(function() exports.qbx_core:DeleteVehicle(veh) end)
        if not okD and DoesEntityExist(veh) then DeleteEntity(veh) end
        local owner = owned.citizenid and exports.qbx_core:GetPlayerByCitizenId(owned.citizenid)
        if owner then
            exports.qbx_core:Notify(owner.PlayerData.source,
                ('حجزت الشرطة مركبتك (%s): %s. استلمها من أي ساحة حجز مقابل %s$'):format(plate, reason, lib.math.groupdigits(fee)), 'error', 12000)
        end
    else
        DeleteEntity(veh)   -- (not a player's car: it just goes away)
    end
    POL.log(source, 'impound', ('%s · %s · %s'):format(plate, owned and owned.citizenid or 'local', reason), fee, 'bank')
    lib.logger(source, 'police', ('impounded %s (%s) fee %d$: %s'):format(plate, owned and owned.citizenid or 'local', fee, reason))
    busy[source] = nil
    return true, { plate = plate, owned = owned ~= nil }
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
