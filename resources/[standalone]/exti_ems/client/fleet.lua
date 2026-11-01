-- =====================================================================
-- EX_Tii EMS (client): the garage screen like the video — the team's vehicles with their stats,
-- park out, open the trunk, the stretcher / wheelchair, and (the leader) the vehicle shop.
-- Park in: drive onto the garage spot and press E.
-- =====================================================================

local open = nil -- { hospital, kind, coords }

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
        if open and (EMS.isDown() or not EMS.onDuty() or cache.vehicle or #(GetEntityCoords(cache.ped) - open.coords) > Config.reachPoint + 4.0) then
            close(true)
        end
        Wait(open and 500 or 1500)
    end
end)

function EMS.openGarage(spot, kind)
    if open then return end
    local data, err = lib.callback.await('exti_ems:server:garage', false, spot.hospital, kind)
    if not data then return EMS.error(err) end
    open = { hospital = spot.hospital, kind = kind, coords = spot.coords }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'garage', open = true, data = withStats(data) })
end

-- drive onto the garage spot / helicopter pad and press E
function EMS.parkIn(spot)
    local ok, err = lib.callback.await('exti_ems:server:parkIn', false, spot.hospital)
    if not ok then return EMS.error(err) end
    EMS.notify('success', 'أدخلت المركبة للمرآب، وكل ما في صندوقها باقٍ فيه')
end

local function errorText(err)
    return EMS.ERRORS[err] or EMS.ERRORS.failed
end

---------------------------------------------------------------------------
-- [E] at the back of a team vehicle: its own trunk (the doors open like in the video)
---------------------------------------------------------------------------
local trunkBusy = false

local function openFleetTrunk(veh)
    if trunkBusy or not DoesEntityExist(veh) then return end
    trunkBusy = true
    local ok, err = lib.callback.await('exti_ems:server:vehicleTrunk', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then trunkBusy = false return EMS.error(err) end
    local doors = {}
    if not Entity(veh).state.exti_ems_air then
        doors = GetIsDoorValid(veh, 5) and { 5 } or { 2, 3 }
    end
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

EMS.openFleetTrunk = openFleetTrunk

-- the "[E]" line when you stand at the back of one of the team's vehicles (the side door of the
-- helicopter)
function EMS.trunkPrompt(p)
    if cache.vehicle or trunkBusy or not EMS.onDuty() then return end
    local veh = lib.getClosestVehicle(p, 8.0, false)
    -- only real, shared vehicles (cars that exist only on this screen have no shared state)
    if not veh or not NetworkGetEntityIsNetworked(veh) or not Entity(veh).state.exti_ems_fleet then return end
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local spots
    if Entity(veh).state.exti_ems_air then
        spots = { GetOffsetFromEntityInWorldCoords(veh, max.x + 0.5, 0.0, 0.0), GetOffsetFromEntityInWorldCoords(veh, min.x - 0.5, 0.0, 0.0) }
    else
        spots = { GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.35, 0.0) }
    end
    for _, s in ipairs(spots) do
        if #(vec3(p.x, p.y, p.z) - s) < 1.5 then
            return '[E] صندوق المركبة', function() openFleetTrunk(veh) end
        end
    end
end

RegisterNUICallback('garageOut', function(data, cb)
    if not open then return cb({ ok = false }) end
    local hospital = open.hospital
    local ok, netId, extra = lib.callback.await('exti_ems:server:parkOut', false, hospital, tonumber(data and data.id))
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
    EMS.notify('success', ('خذ بالك عليها: %s'):format(extra and extra.plate or ''))
end)

RegisterNUICallback('garageTrunk', function(data, cb)
    if not open then return cb({ ok = false }) end
    local hospital = open.hospital
    local ok, err = lib.callback.await('exti_ems:server:openTrunk', false, hospital, tonumber(data and data.id))
    if not ok then return cb({ ok = false, error = errorText(err) }) end
    cb({ ok = true })
    close(true)
end)

RegisterNUICallback('garageBuy', function(data, cb)
    if not open then return cb({ ok = false }) end
    local ok, view = lib.callback.await('exti_ems:server:buyVehicle', false, open.hospital, data and data.model)
    if not ok then return cb({ ok = false, error = errorText(view) }) end
    cb({ ok = true, data = withStats(view) })
end)

RegisterNUICallback('garageSell', function(data, cb)
    if not open then return cb({ ok = false }) end
    local ok, view = lib.callback.await('exti_ems:server:sellVehicle', false, open.hospital, tonumber(data and data.id))
    if not ok then return cb({ ok = false, error = errorText(view) }) end
    cb({ ok = true, data = withStats(view) })
end)

RegisterNUICallback('garageEquipment', function(data, cb)
    cb(true)
    if not open then return end
    close(true)
    local kind = data and data.kind
    if (kind == 'stretcher' or kind == 'wheelchair') and EMS.takeEquipment then EMS.takeEquipment(kind) end
end)

RegisterNUICallback('garageClose', function(_, cb)
    cb(true)
    close(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
end)
