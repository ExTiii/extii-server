-- =====================================================================
-- EX_Tii Mechanic (client): the garage screen like the video — the team's vehicles with their
-- stats, park out, open the trunk, and (the leader) the vehicle shop and changing a plate.
-- Park in: drive onto the garage spot and press E.
-- =====================================================================

local open = nil -- { station, kind, coords }

local CLASS = {
    [0] = 'صغيرة', [1] = 'سيدان', [2] = 'دفع رباعي', [3] = 'كوبيه', [4] = 'عضلية', [5] = 'كلاسيكية',
    [6] = 'رياضية', [7] = 'خارقة', [8] = 'دراجة', [9] = 'طرق وعرة', [10] = 'صناعية', [11] = 'خدمات',
    [12] = 'فان', [14] = 'قارب', [15] = 'مروحية', [16] = 'طائرة', [17] = 'خدمة', [18] = 'طوارئ',
    [19] = 'عسكرية', [20] = 'تجارية',
}

local statsCache = {}
local function modelStats(model)
    if statsCache[model] then return statsCache[model] end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    local s = {
        speed = math.floor(GetVehicleModelEstimatedMaxSpeed(hash) * 3.6 + 0.5),
        accel = GetVehicleModelAcceleration(hash),
        brake = GetVehicleModelMaxBraking(hash),
        traction = GetVehicleModelMaxTraction(hash),
        seats = GetVehicleModelNumberOfSeats(hash),
        class = CLASS[GetVehicleClassFromName(hash)] or '',
    }
    statsCache[model] = s
    return s
end

local function withStats(data)
    if type(data) ~= 'table' then return data end
    for _, v in ipairs(data.vehicles or {}) do v.stats = modelStats(v.model) end
    for _, v in ipairs(data.shop or {}) do v.stats = modelStats(v.model) end
    return data
end

local function close(tellPage)
    if not open then return end
    open = nil
    SetNuiFocus(false, false)
    if tellPage then SendNUIMessage({ action = 'garage', open = false }) end
end

CreateThread(function()
    while true do
        if open and (MEC.isDown() or not MEC.onDuty() or cache.vehicle or #(GetEntityCoords(cache.ped) - open.coords) > Config.reachPoint + 4.0) then
            close(true)
        end
        Wait(open and 500 or 1500)
    end
end)

function MEC.openGarage(spot, kind)
    if open then return end
    local data, err = lib.callback.await('exti_mechanic:server:garage', false, spot.station, kind)
    if not data then return MEC.error(err) end
    open = { station = spot.station, kind = kind, coords = spot.coords }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'garage', open = true, data = withStats(data) })
end

-- drive onto the garage spot and press E
function MEC.parkIn(spot)
    local ok, err = lib.callback.await('exti_mechanic:server:parkIn', false, spot.station)
    if not ok then return MEC.error(err) end
    MEC.notify('success', 'أدخلت المركبة للمرآب، وكل ما في صندوقها باقٍ فيه')
end

local function errorText(err)
    return MEC.ERRORS[err] or MEC.ERRORS.failed
end

---------------------------------------------------------------------------
-- [E] at the back of a team vehicle: its own trunk (the doors open like in the video)
---------------------------------------------------------------------------
local trunkBusy = false

local function openFleetTrunk(veh)
    if trunkBusy or not DoesEntityExist(veh) then return end
    trunkBusy = true
    local ok, err = lib.callback.await('exti_mechanic:server:vehicleTrunk', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then trunkBusy = false return MEC.error(err) end
    local doors = GetIsDoorValid(veh, 5) and { 5 } or { 2, 3 }
    for _, d in ipairs(doors) do SetVehicleDoorOpen(veh, d, false, false) end
    TaskTurnPedToFaceEntity(cache.ped, veh, 800)
    CreateThread(function()
        -- shut them again when the trunk screen closes or you walk away
        local started = GetGameTimer()
        while DoesEntityExist(veh) and (LocalPlayer.state.invOpen or GetGameTimer() - started < 1500)
            and #(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) < 8.0 do
            Wait(300)
        end
        if DoesEntityExist(veh) then
            for _, d in ipairs(doors) do SetVehicleDoorShut(veh, d, false) end
        end
        trunkBusy = false
    end)
end

MEC.openFleetTrunk = openFleetTrunk

-- the "[E]" line when you stand at the back of one of the team's vehicles
function MEC.trunkPrompt(p)
    if cache.vehicle or trunkBusy or not MEC.onDuty() then return end
    local veh = lib.getClosestVehicle(p, 8.0, false)
    if not veh or not Entity(veh).state.exti_mechanic_fleet then return end
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local spots = { GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.35, 0.0) }
    for _, s in ipairs(spots) do
        if #(vec3(p.x, p.y, p.z) - s) < 1.5 then
            return '[E] صندوق المركبة', function() openFleetTrunk(veh) end
        end
    end
end

RegisterNUICallback('garageOut', function(data, cb)
    if not open then return cb({ ok = false }) end
    local station = open.station
    local ok, netId, extra = lib.callback.await('exti_mechanic:server:parkOut', false, station, tonumber(data and data.id))
    if not ok then return cb({ ok = false, error = errorText(netId) }) end
    cb({ ok = true })
    close(true)
    local found, veh = pcall(lib.waitFor, function()
        local v = NetworkGetEntityFromNetworkId(netId)
        if v ~= 0 and DoesEntityExist(v) then return v end
    end, nil, 5000)
    if not found or not veh then return end
    if type(extra) == 'table' then
        if extra.livery then SetVehicleLivery(veh, extra.livery) end
        if extra.engine then SetVehicleEngineHealth(veh, extra.engine + 0.0) end
        if extra.body then SetVehicleBodyHealth(veh, extra.body + 0.0) end
    end
    SetVehicleEngineOn(veh, true, true, false)
    MEC.notify('success', ('خذ بالك عليها: %s'):format(extra and extra.plate or ''))
end)

RegisterNUICallback('garageTrunk', function(data, cb)
    if not open then return cb({ ok = false }) end
    local station = open.station
    local ok, err = lib.callback.await('exti_mechanic:server:openTrunk', false, station, tonumber(data and data.id))
    if not ok then return cb({ ok = false, error = errorText(err) }) end
    cb({ ok = true })
    close(true)
end)

RegisterNUICallback('garageBuy', function(data, cb)
    if not open then return cb({ ok = false }) end
    local ok, view = lib.callback.await('exti_mechanic:server:buyVehicle', false, open.station, data and data.model)
    if not ok then return cb({ ok = false, error = errorText(view) }) end
    cb({ ok = true, data = withStats(view) })
end)

RegisterNUICallback('garageSell', function(data, cb)
    if not open then return cb({ ok = false }) end
    local ok, view = lib.callback.await('exti_mechanic:server:sellVehicle', false, open.station, tonumber(data and data.id))
    if not ok then return cb({ ok = false, error = errorText(view) }) end
    cb({ ok = true, data = withStats(view) })
end)

RegisterNUICallback('garagePlate', function(data, cb)
    if not open then return cb({ ok = false }) end
    local ok, view = lib.callback.await('exti_mechanic:server:setPlate', false, open.station, tonumber(data and data.id), data and data.plate)
    if not ok then return cb({ ok = false, error = errorText(view) }) end
    cb({ ok = true, data = withStats(view) })
end)

RegisterNUICallback('garageClose', function(_, cb)
    cb(true)
    close(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
end)
