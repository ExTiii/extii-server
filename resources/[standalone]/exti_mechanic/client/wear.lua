-- =====================================================================
-- EX_Tii Mechanic (client): the WEAR you feel while driving.
-- The driver's game reports the distance (the server takes it off every part) and reads the car's
-- condition (state bag exti_wear) to make the car misbehave, like the video:
--   brake pads / fluid low      -> weaker brakes, at 0 the car barely stops
--   clutch / gearbox oil at 0   -> stuck in first gear, 30 km/h at most (slipping before that)
--   spark plugs low             -> misfires (the power cuts out for a moment)
--   oil / coolant / air low     -> smoke from the engine; oil or coolant at 0 -> the engine dies
--   tires at 0                  -> a tire bursts; low -> less grip
--   EV battery low / motor at 0 -> slower / 30 km/h at most
-- Repairing a part brings the car back to normal at once.
-- =====================================================================

local S = Config.service
local WARN = S.warnAt or 15

local function now() return GetCloudTimeAsInt() end

---------------------------------------------------------------------------
-- reporting the distance (driver only)
---------------------------------------------------------------------------
local synced = {}   -- [veh] = true once the server sent its condition this ride

local function isElectric(veh)
    local ok, ev = pcall(GetIsVehicleElectric, GetEntityModel(veh))
    return ok and ev == true
end

local function modelName(veh)
    return GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or ''
end

-- only real road vehicles wear (no bikes without engines, boats, planes, trains)
local function wears(veh)
    local class = GetVehicleClass(veh)
    return class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 and class ~= 21
end

CreateThread(function()
    local meters, fast, lastSend, lastPos = 0.0, 0.0, 0, nil
    local current = nil
    while true do
        local veh = cache.vehicle
        if veh and cache.seat == -1 and wears(veh) and NetworkGetEntityIsNetworked(veh) then
            if current ~= veh then
                current, meters, fast, lastPos, lastSend = veh, 0.0, 0.0, GetEntityCoords(veh), GetGameTimer()
                local netId = NetworkGetNetworkIdFromEntity(veh)
                CreateThread(function()
                    local data = lib.callback.await('exti_mechanic:server:wearSync', false, netId, isElectric(veh), modelName(veh))
                    if data then synced[veh] = true end
                end)
            end
            local p = GetEntityCoords(veh)
            local step = #(p - lastPos)
            lastPos = p
            -- a jump (teleport, respawn) does not count
            if step < 60.0 then
                meters = meters + step
                if GetEntitySpeed(veh) * 3.6 > 140.0 then fast = fast + step end
            end
            if GetGameTimer() - lastSend > (S.reportEvery or 20) * 1000 then
                if meters >= 5.0 then
                    TriggerServerEvent('exti_mechanic:server:wearDrive', NetworkGetNetworkIdFromEntity(veh), meters, fast)
                end
                meters, fast, lastSend = 0.0, 0.0, GetGameTimer()
            end
            Wait(1000)
        else
            if current and DoesEntityExist(current) and meters >= 5.0 then
                TriggerServerEvent('exti_mechanic:server:wearDrive', NetworkGetNetworkIdFromEntity(current), meters, fast)
            end
            current, meters, fast = nil, 0.0, 0.0
            Wait(1500)
        end
    end
end)

---------------------------------------------------------------------------
-- the effects
---------------------------------------------------------------------------
local orig = {}     -- [veh] = { brake, traction }
local applied = {}  -- [veh] = what we changed
local warned = {}   -- [veh] = true once the driver was told

local function wearOf(veh)
    local st = Entity(veh).state.exti_wear
    return type(st) == 'table' and type(st.c) == 'table' and st or nil
end

local function pct(st, id)
    local v = st.c[id]
    return v == nil and 100 or tonumber(v) or 100
end

local function remember(veh)
    if orig[veh] then return orig[veh] end
    orig[veh] = {
        brake = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce'),
        traction = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax'),
    }
    return orig[veh]
end

local function setHandling(veh, field, value)
    if math.abs(GetVehicleHandlingFloat(veh, 'CHandlingData', field) - value) > 0.001 then
        SetVehicleHandlingFloat(veh, 'CHandlingData', field, value)
    end
end

local misfiring = false
local function misfire(ms)
    if misfiring then return end
    misfiring = true
    CreateThread(function()
        local untilT = GetGameTimer() + ms
        while GetGameTimer() < untilT do
            DisableControlAction(0, 71, true) -- accelerate
            Wait(0)
        end
        misfiring = false
    end)
end

local function restore(veh)
    local o = orig[veh]
    if o and DoesEntityExist(veh) then
        setHandling(veh, 'fBrakeForce', o.brake)
        setHandling(veh, 'fTractionCurveMax', o.traction)
        SetEntityMaxSpeed(veh, 999.0)
    end
    applied[veh] = nil
end

local function effects(veh, st)
    local o = remember(veh)
    local a = applied[veh] or {}
    applied[veh] = a

    -- brakes
    local brakes = math.min(pct(st, 'brake_pads'), pct(st, 'brake_fluid'))
    local bf = 1.0
    if brakes <= 0 then bf = 0.22 elseif brakes < WARN then bf = 0.45 + 0.55 * (brakes / WARN) end
    setHandling(veh, 'fBrakeForce', o.brake * bf)

    -- grip
    local tires = pct(st, 'tires')
    setHandling(veh, 'fTractionCurveMax', o.traction * (tires < WARN and 0.85 or 1.0))
    if tires <= 0 and math.random() < 0.04 and GetEntitySpeed(veh) > 8.0 then
        local wheels = { 0, 1, 4, 5 }
        local w = wheels[math.random(#wheels)]
        if not IsVehicleTyreBurst(veh, w, false) then SetVehicleTyreBurst(veh, w, true, 1000.0) end
    end

    -- the drivetrain: stuck in first gear
    local stuck
    if st.ev then
        stuck = pct(st, 'motor') <= 0
    else
        stuck = math.min(pct(st, 'clutch'), pct(st, 'trans_fluid')) <= 0
    end
    local cap = 999.0
    if stuck then cap = 30.0 / 3.6
    elseif st.ev and pct(st, 'battery') <= 0 then cap = 50.0 / 3.6
    elseif st.ev and pct(st, 'battery') < WARN then cap = 90.0 / 3.6 end
    if a.cap ~= cap then SetEntityMaxSpeed(veh, cap) a.cap = cap end

    -- misfires / a slipping clutch
    local running = GetIsVehicleEngineRunning(veh) and GetEntitySpeed(veh) > 3.0
    if running and not st.ev then
        if pct(st, 'spark_plugs') < WARN and math.random() < (pct(st, 'spark_plugs') <= 0 and 0.35 or 0.15) then misfire(350) end
        if not stuck and math.min(pct(st, 'clutch'), pct(st, 'trans_fluid')) < WARN and math.random() < 0.12 then misfire(500) end
    end
    if running and st.ev and pct(st, 'motor') < WARN and math.random() < 0.12 then misfire(400) end

    -- the engine: smoke, then it dies
    if not st.ev then
        local oil, cool, air = pct(st, 'engine_oil'), pct(st, 'coolant'), pct(st, 'air_filter')
        local engine = GetVehicleEngineHealth(veh)
        if GetIsVehicleEngineRunning(veh) and (oil <= 0 or cool <= 0) then
            -- no oil or no coolant: it overheats and dies within about a minute of running
            if engine > 0 then SetVehicleEngineHealth(veh, math.max(0.0, engine - 8.0)) end
        elseif (oil < WARN or cool < WARN or air < WARN) and engine > 360.0 then
            SetVehicleEngineHealth(veh, 360.0) -- the smoke
        end
    end
end

CreateThread(function()
    while true do
        local veh = cache.vehicle
        if veh and cache.seat == -1 then
            local st = wearOf(veh)
            if st then
                effects(veh, st)
                if not warned[veh] then
                    warned[veh] = true
                    local worst, label = 100, nil
                    for _, c in ipairs(S.components) do
                        local v = st.c[c.id]
                        if v and v < worst then worst, label = v, c.label end
                    end
                    if label and worst < WARN then
                        lib.notify({ type = 'warning', description = ('هذه السيارة تحتاج صيانة: %s %d%%. اذهب إلى الميكانيكي'):format(label, worst), duration = 7000 })
                    end
                end
            end
            Wait(500)
        else
            for v in pairs(applied) do
                if v ~= cache.vehicle then restore(v) end
            end
            Wait(1000)
        end
    end
end)

-- repaired: back to normal now (the state bag changes; the loop above does the rest)
AddStateBagChangeHandler('exti_wear', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if not veh or veh == 0 or veh ~= cache.vehicle then return end
    if type(value) == 'table' and type(value.c) == 'table' then
        local all = true
        for _, v in pairs(value.c) do if v < WARN then all = false break end end
        if all then
            warned[veh] = nil
            restore(veh)
            orig[veh] = nil
        end
    end
end)

---------------------------------------------------------------------------
-- wash and wax
---------------------------------------------------------------------------
RegisterNetEvent('exti_mechanic:client:clean', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)
end)

-- a waxed car gets dirty much more slowly (the driver's game keeps the dirt down)
CreateThread(function()
    while true do
        Wait(30000)
        local veh = cache.vehicle
        if veh and cache.seat == -1 then
            local st = Entity(veh).state.exti_wear
            local wax = type(st) == 'table' and tonumber(st.wax) or nil
            if wax and wax > now() then
                local dirt = GetVehicleDirtLevel(veh)
                if dirt > 0.5 then SetVehicleDirtLevel(veh, math.max(0.0, dirt - 0.4)) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for v in pairs(applied) do restore(v) end
end)
