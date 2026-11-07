-- EX_Tii used cars (server): checks the car is really yours, pays, removes it from your garage list.
local catalog = {}
do
    local src = LoadResourceFile('qbx_vehicleshop', 'config/catalog.lua')
    local ok, data = pcall(function() return src and load(src, '@qbx_vehicleshop/config/catalog.lua')() end)
    if ok and type(data) == 'table' then
        for _, v in ipairs(data.vehicles or {}) do catalog[joaat(v.model)] = v end
    else
        print('^3[exti_usedcars] could not read the dealership catalog: nothing can be sold^0')
    end
end

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- the spot (moved by an admin, kept across restarts)
local function loadSpot()
    local saved = json.decode(GetResourceKvpString('spot') or 'null')
    if type(saved) == 'table' and saved.x then return vec4(saved.x, saved.y, saved.z, saved.w or 0.0) end
    return Config.spot
end
GlobalState:set('exti_usedcars:spot', loadSpot(), true)

lib.addCommand('usedcarspot', { help = 'تاجر المركبات المستعملة يقف مكانك', restricted = 'group.admin' }, function(source)
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    local spot = vec4(c.x, c.y, c.z, GetEntityHeading(ped))
    SetResourceKvp('spot', json.encode({ x = spot.x, y = spot.y, z = spot.z, w = spot.w }))
    GlobalState:set('exti_usedcars:spot', spot, true)
    exports.qbx_core:Notify(source, 'وقف تاجر المركبات المستعملة مكانك', 'success')
end)

local quotes = {}   -- [src] = { netId, vehicleId, price, token }

-- your car next to the buyer: the price, or why he won't buy it
local function check(src, netId)
    local player = getPlayer(src)
    if not player then return nil, 'failed' end
    local ped = GetPlayerPed(src)
    local spot = GlobalState['exti_usedcars:spot'] or Config.spot
    if #(GetEntityCoords(ped) - spot.xyz) > 4.0 then return nil, 'far' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return nil, 'inside' end
    local veh = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'nocar' end
    if #(GetEntityCoords(veh) - spot.xyz) > Config.carReach then return nil, 'nocar' end
    for seat = -1, 7 do if GetPedInVehicleSeat(veh, seat) ~= 0 then return nil, 'people' end end
    local vehicleId = Entity(veh).state.vehicleid
    if not vehicleId then
        local ok, id = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(veh)) end)
        vehicleId = ok and id or nil
    end
    if not vehicleId then return nil, 'notyours' end
    local ok, row = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    if not ok or not row or row.citizenid ~= player.PlayerData.citizenid then return nil, 'notyours' end
    local fin = false
    pcall(function() fin = MySQL.scalar.await('SELECT 1 FROM vehicle_financing WHERE vehicleId = ? LIMIT 1', { vehicleId }) ~= nil end)
    if fin then return nil, 'financed' end
    local item = catalog[GetEntityModel(veh)]
    if not item or not item.price then return nil, 'unknown' end
    local health = (math.max(0.0, GetVehicleEngineHealth(veh)) + math.max(0.0, GetVehicleBodyHealth(veh))) / 2000.0
    local condition = Config.minCondition + (1.0 - Config.minCondition) * math.min(1.0, health)
    local price = math.floor(item.price * Config.share * condition / 10 + 0.5) * 10
    return { veh = veh, vehicleId = vehicleId, price = price, label = ((item.brand and item.brand .. ' ') or '') .. (item.name or ''), plate = GetVehicleNumberPlateText(veh), player = player }
end

lib.callback.register('exti_usedcars:server:quote', function(source, netId)
    local q, why = check(source, netId)
    if not q then return false, why end
    quotes[source] = { netId = netId, vehicleId = q.vehicleId, price = q.price, token = math.random(100000, 999999), at = os.time() }
    return true, { price = q.price, label = q.label, plate = q.plate, token = quotes[source].token }
end)

lib.callback.register('exti_usedcars:server:sell', function(source, token)
    local quote = quotes[source]
    quotes[source] = nil
    if not quote or quote.token ~= token or os.time() - quote.at > 60 then return false, 'failed' end
    local q, why = check(source, quote.netId)
    if not q then return false, why end
    if q.vehicleId ~= quote.vehicleId then return false, 'failed' end
    local price = math.min(q.price, quote.price)   -- (more damage since the quote = never more money)
    -- the car leaves first (nothing is paid for a car that is still there)
    DeleteEntity(q.veh)
    local okDel = pcall(function() exports.qbx_vehicles:DeletePlayerVehicles('vehicleId', q.vehicleId) end)
    if not okDel then return false, 'failed' end
    pcall(function() MySQL.query.await('DELETE FROM garage_shared_keys WHERE vehicle_id = ?', { q.vehicleId }) end)
    pcall(function() MySQL.query.await('DELETE FROM garage_vehicle_names WHERE vehicle_id = ?', { q.vehicleId }) end)
    pcall(function() MySQL.query.await('DELETE FROM garage_favourites WHERE vehicle_id = ?', { q.vehicleId }) end)
    q.player.Functions.AddMoney('bank', price, 'used-car-sold')
    lib.logger(source, 'usedcars', ('sold %s (%s, id %d) for %d$'):format(q.label, q.plate, q.vehicleId, price))
    return true, price
end)

AddEventHandler('playerDropped', function() quotes[source] = nil end)
