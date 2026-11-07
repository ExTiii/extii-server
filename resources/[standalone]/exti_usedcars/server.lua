-- EX_Tii used-car lot (server): listings, buying, the parking places.
local catalog = {}
do
    local src = LoadResourceFile('qbx_vehicleshop', 'config/catalog.lua')
    local ok, data = pcall(function() return src and load(src, '@qbx_vehicleshop/config/catalog.lua')() end)
    if ok and type(data) == 'table' then
        for _, v in ipairs(data.vehicles or {}) do catalog[joaat(v.model)] = v end
    else
        print('^3[exti_usedcars] could not read the dealership catalog: nothing can be listed^0')
    end
end

local GARAGED, OUT = 1, 0          -- qbx_vehicles states
local LOT = 'exti_usedlot'         -- the "garage" a listed car is kept in (it has no owner while it is listed)
local listings = {}                -- [id] = row
local busy = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end
local function nameOf(p) local c = p.PlayerData.charinfo or {} return ('%s %s'):format(c.firstname or '', c.lastname or '') end
local function money(n) return lib.math.groupdigits(n) end

---------------------------------------------------------------------------
-- places (KVP): the manager, the parking places
---------------------------------------------------------------------------
local function v4(t) return t and vec4(t.x, t.y, t.z, t.w or 0.0) or nil end
local function loadSpot()
    local saved = json.decode(GetResourceKvpString('spot') or 'null')
    return type(saved) == 'table' and saved.x and v4(saved) or Config.spot
end
local function loadSlots()
    local saved = json.decode(GetResourceKvpString('slots') or '[]')
    local out = {}
    for _, s in ipairs(type(saved) == 'table' and saved or {}) do out[#out + 1] = v4(s) end
    return out
end
local slots = loadSlots()
GlobalState:set('exti_usedcars:spot', loadSpot(), true)
GlobalState:set('exti_usedcars:slots', slots, true)

-- what every game needs to show the cars (no seller details except his citizen id, to know "it's mine")
local function publish()
    local list = {}
    for id, l in pairs(listings) do
        list[#list + 1] = { id = id, slot = l.slot, price = l.price, label = l.label, props = l.props, seller = l.seller_cid }
    end
    GlobalState:set('exti_usedcars:list', list, true)
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_usedcars` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `vehicle_id` INT NOT NULL,
        `seller_cid` VARCHAR(50) NOT NULL,
        `seller_name` VARCHAR(100) NULL,
        `model` VARCHAR(50) NOT NULL,
        `label` VARCHAR(100) NULL,
        `plate` VARCHAR(15) NULL,
        `price` INT NOT NULL,
        `slot` INT NOT NULL,
        `created` INT NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `vehicle_id` (`vehicle_id`)
    )]])
    local rows = MySQL.query.await('SELECT * FROM `exti_usedcars`') or {}
    for _, r in ipairs(rows) do
        local ok, veh = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(r.vehicle_id) end)
        if ok and veh then
            r.props = veh.props
            listings[r.id] = r
        else
            MySQL.query.await('DELETE FROM `exti_usedcars` WHERE `id` = ?', { r.id })   -- (the car is gone)
        end
    end
    publish()
end)

lib.addCommand('usedcarspot', { help = 'مدير معرض السيارات المستعملة يقف مكانك', restricted = 'group.admin' }, function(source)
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    local spot = vec4(c.x, c.y, c.z, GetEntityHeading(ped))
    SetResourceKvp('spot', json.encode({ x = spot.x, y = spot.y, z = spot.z, w = spot.w }))
    GlobalState:set('exti_usedcars:spot', spot, true)
    exports.qbx_core:Notify(source, 'وقف مدير المعرض مكانك', 'success')
end)

lib.addCommand('usedcarslot', {
    help = 'مكان سيارة في معرض السيارات المستعملة (اجلس في سيارة مركونة جيدًا)', restricted = 'group.admin',
    params = { { name = 'what', type = 'string', help = 'clear = امسح كل الأماكن', optional = true } },
}, function(source, args)
    if args.what == 'clear' then
        slots = {}
    else
        local ped = GetPlayerPed(source)
        local veh = GetVehiclePedIsIn(ped, false)
        local e = veh ~= 0 and veh or ped
        local c = GetEntityCoords(e)
        slots[#slots + 1] = vec4(c.x, c.y, c.z, GetEntityHeading(e))
    end
    local save = {}
    for _, s in ipairs(slots) do save[#save + 1] = { x = s.x, y = s.y, z = s.z, w = s.w } end
    SetResourceKvp('slots', json.encode(save))
    GlobalState:set('exti_usedcars:slots', slots, true)
    exports.qbx_core:Notify(source, args.what == 'clear' and 'مُسحت كل أماكن المعرض' or ('أُضيف مكان رقم %d في المعرض'):format(#slots), 'success')
end)

---------------------------------------------------------------------------
-- selling: the seller's car next to the manager -> on the lot
---------------------------------------------------------------------------
local function nearManager(src)
    local spot = GlobalState['exti_usedcars:spot'] or Config.spot
    return #(GetEntityCoords(GetPlayerPed(src)) - spot.xyz) <= 4.0, spot
end

local function freeSlot()
    local used = {}
    for _, l in pairs(listings) do used[l.slot] = true end
    for i = 1, #slots do if not used[i] then return i end end
end

local function carToSell(src, netId)
    local player = getPlayer(src)
    if not player then return nil, 'failed' end
    local near, spot = nearManager(src)
    if not near then return nil, 'far' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return nil, 'inside' end
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
    return { veh = veh, vehicleId = vehicleId, row = row, item = item, player = player,
             label = ((item.brand and item.brand .. ' ') or '') .. (item.name or ''), plate = GetVehicleNumberPlateText(veh):match('^%s*(.-)%s*$') }
end

local function bounds(price)
    local lo = math.ceil(price * Config.minShare / 50) * 50
    local hi = math.floor(price * Config.maxShare / 50) * 50
    return lo, hi
end

lib.callback.register('exti_usedcars:server:quote', function(source, netId)
    local q, why = carToSell(source, netId)
    if not q then return false, why end
    local mine = 0
    for _, l in pairs(listings) do if l.seller_cid == q.player.PlayerData.citizenid then mine = mine + 1 end end
    if mine >= Config.perSeller then return false, 'many' end
    if #slots == 0 then return false, 'noslots' end
    if not freeSlot() then return false, 'full' end
    local lo, hi = bounds(q.item.price)
    return true, { label = q.label, plate = q.plate, price = q.item.price, min = lo, max = hi }
end)

lib.callback.register('exti_usedcars:server:list', function(source, netId, price)
    if busy[source] then return false, 'wait' end
    busy[source] = true
    local function done(...) busy[source] = nil return ... end
    local q, why = carToSell(source, netId)
    if not q then return done(false, why) end
    local lo, hi = bounds(q.item.price)
    price = math.floor((tonumber(price) or 0) / 50 + 0.5) * 50
    if price < lo or price > hi then return done(false, 'price') end
    local mine = 0
    for _, l in pairs(listings) do if l.seller_cid == q.player.PlayerData.citizenid then mine = mine + 1 end end
    if mine >= Config.perSeller then return done(false, 'many') end
    local slot = freeSlot()
    if not slot then return done(false, 'full') end
    -- the car as it is now (damage, fuel) goes on the lot
    local props = type(q.row.props) == 'table' and q.row.props or {}
    props.bodyHealth = GetVehicleBodyHealth(q.veh)
    props.engineHealth = GetVehicleEngineHealth(q.veh)
    local fuel = Entity(q.veh).state.fuel
    if type(fuel) == 'number' then props.fuelLevel = math.floor(fuel + 0.5) end
    local okSave = pcall(function()
        exports.qbx_vehicles:SaveVehicle(q.veh, { state = GARAGED, garage = LOT, props = props })
    end)
    if not okSave then return done(false, 'failed') end
    -- nobody owns it while it is on the lot (it is in nobody's garage list); old shared keys are gone
    local okOwner = pcall(function() exports.qbx_vehicles:SetPlayerVehicleOwner(q.vehicleId, nil) end)
    if not okOwner then return done(false, 'failed') end
    pcall(function() MySQL.query.await('DELETE FROM garage_shared_keys WHERE vehicle_id = ?', { q.vehicleId }) end)
    pcall(function() MySQL.query.await('DELETE FROM garage_favourites WHERE vehicle_id = ?', { q.vehicleId }) end)
    pcall(function() exports.qbx_core:DeleteVehicle(q.veh) end)
    if DoesEntityExist(q.veh) then DeleteEntity(q.veh) end
    local cid = q.player.PlayerData.citizenid
    local id = MySQL.insert.await('INSERT INTO `exti_usedcars` (`vehicle_id`, `seller_cid`, `seller_name`, `model`, `label`, `plate`, `price`, `slot`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { q.vehicleId, cid, nameOf(q.player), q.row.modelName or tostring(q.item.model), q.label, q.plate, price, slot, os.time() })
    if not id then
        pcall(function() exports.qbx_vehicles:SetPlayerVehicleOwner(q.vehicleId, cid) end)   -- nothing is lost
        return done(false, 'failed')
    end
    listings[id] = { id = id, vehicle_id = q.vehicleId, seller_cid = cid, seller_name = nameOf(q.player), model = q.row.modelName,
                     label = q.label, plate = q.plate, price = price, slot = slot, props = props }
    publish()
    lib.logger(source, 'usedcars', ('listed %s (%s, id %d) for %d$'):format(q.label, q.plate, q.vehicleId, price))
    return done(true, { price = price, label = q.label })
end)

---------------------------------------------------------------------------
-- a car leaves the lot: to the buyer, or back to the seller. It comes out right where it stood.
---------------------------------------------------------------------------
local function handOver(src, l, newOwner)
    local okO = pcall(function() exports.qbx_vehicles:SetPlayerVehicleOwner(l.vehicle_id, newOwner) end)
    if not okO then return false end
    listings[l.id] = nil
    MySQL.query.await('DELETE FROM `exti_usedcars` WHERE `id` = ?', { l.id })
    publish()
    Wait(400)   -- (every game removes its copy of the car first)
    local s = slots[l.slot] or (GlobalState['exti_usedcars:spot'] or Config.spot)
    local props = l.props or {}
    props.lockState = 1
    local ok, netId, veh = pcall(qbx.spawnVehicle, { spawnSource = s, model = props.model or joaat(l.model), props = props })
    if not ok or not veh or veh == 0 then
        -- could not make the car here: it waits in the garage list (any public garage)
        pcall(function() MySQL.update.await('UPDATE player_vehicles SET state = ?, garage = ? WHERE id = ?', { GARAGED, 'sandy_shores', l.vehicle_id }) end)
        exports.qbx_core:Notify(src, 'السيارة في مرآبك الآن (موقف ساندي شورز)', 'inform', 8000)
        return true
    end
    Entity(veh).state:set('vehicleid', l.vehicle_id, false)
    if tonumber(props.fuelLevel) then Entity(veh).state:set('fuel', math.max(0.0, math.min(100.0, props.fuelLevel + 0.0)), true) end
    pcall(function() exports.qbx_vehicles:SaveVehicle(veh, { state = OUT }) end)
    TriggerClientEvent('vehiclekeys:client:SetOwner', src, props.plate or l.plate)
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    return true, netId
end

local function payOffline(cid, amount)
    return MySQL.update.await("UPDATE `players` SET `money` = JSON_SET(`money`, '$.bank', CAST(JSON_EXTRACT(`money`, '$.bank') AS DECIMAL(15,0)) + ?) WHERE `citizenid` = ?", { amount, cid }) or 0
end

lib.callback.register('exti_usedcars:server:buy', function(source, id)
    local l = listings[tonumber(id)]
    if not l then return false, 'gone' end
    if busy[source] or l.buying then return false, 'wait' end
    local player = getPlayer(source)
    if not player then return false, 'failed' end
    local cid = player.PlayerData.citizenid
    if l.seller_cid == cid then return false, 'own' end
    local s = slots[l.slot]
    if not s or #(GetEntityCoords(GetPlayerPed(source)) - s.xyz) > 6.0 then return false, 'far' end
    local m = player.PlayerData.money or {}
    local account = (tonumber(m.bank) or 0) >= l.price and 'bank' or ((tonumber(m.cash) or 0) >= l.price and 'cash' or nil)
    if not account then return false, 'money' end
    busy[source], l.buying = true, true
    if not player.Functions.RemoveMoney(account, l.price, 'used-car-bought') then busy[source], l.buying = nil, nil; return false, 'money' end
    local ok = handOver(source, l, cid)
    if not ok then
        player.Functions.AddMoney(account, l.price, 'used-car-refund')
        busy[source], l.buying = nil, nil
        return false, 'failed'
    end
    -- the seller gets the money in his bank (in the city or not)
    local seller = exports.qbx_core:GetPlayerByCitizenId(l.seller_cid)
    if seller then
        seller.Functions.AddMoney('bank', l.price, 'used-car-sold')
        exports.qbx_core:Notify(seller.PlayerData.source, ('بيعت سيارتك %s في معرض السيارات المستعملة: %s$ في حسابك البنكي'):format(l.label or '', money(l.price)), 'success', 10000)
    else
        payOffline(l.seller_cid, l.price)
    end
    lib.logger(source, 'usedcars', ('bought %s (%s, id %d) for %d$ from %s'):format(l.label or '?', l.plate or '?', l.vehicle_id, l.price, l.seller_cid))
    busy[source] = nil
    return true, { label = l.label, price = l.price }
end)

lib.callback.register('exti_usedcars:server:takeBack', function(source, id)
    local l = listings[tonumber(id)]
    if not l then return false, 'gone' end
    if busy[source] or l.buying then return false, 'wait' end
    local player = getPlayer(source)
    if not player or l.seller_cid ~= player.PlayerData.citizenid then return false, 'failed' end
    if not nearManager(source) then return false, 'far' end
    busy[source], l.buying = true, true
    local ok = handOver(source, l, player.PlayerData.citizenid)
    busy[source] = nil
    if not ok then l.buying = nil return false, 'failed' end
    lib.logger(source, 'usedcars', ('took back %s (%s, id %d) from the lot'):format(l.label or '?', l.plate or '?', l.vehicle_id))
    return true, { label = l.label }
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
