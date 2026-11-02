-- =====================================================================
-- EX_Tii Mechanic (client): what tuning step 2 puts on a car (state bag exti_carmods)
--  * engine swap: everyone hears the new engine; the driver's game gives it the new power
--  * nitro: the driver holds LEFT SHIFT while accelerating; a bar shows what is left in the bottle
--  * the dyno: when the mechanic runs it from the tablet, the driver's game revs the car and
--    measures it
-- =====================================================================

local T = Config.tuning
local NOS = T.nitro or {}

local function modsOf(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not NetworkGetEntityIsNetworked(veh) then return nil end
    return Entity(veh).state.exti_carmods
end

---------------------------------------------------------------------------
-- engine sound (every car around) and power (the car you drive)
---------------------------------------------------------------------------
local soundOf = {}   -- [veh] = the engine sound set on it (false = its own)
local baseForce = {} -- [veh] = the car's own drive force (before the swap)

local function setSound(veh, engine)
    local want = engine or false
    if soundOf[veh] == want then return end
    if want then
        ForceVehicleEngineAudio(veh, want)
    elseif soundOf[veh] then
        ForceVehicleEngineAudio(veh, GetEntityArchetypeName(veh))
    end
    soundOf[veh] = want
end
MEC.setEngineSound = setSound

CreateThread(function()
    while true do
        local p = GetEntityCoords(cache.ped)
        local seen = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - p) < 120.0 then
                local m = modsOf(veh)
                if m and m.engine or soundOf[veh] then setSound(veh, m and m.engine or nil) end
                seen[veh] = true
            end
        end
        for veh in pairs(soundOf) do if not seen[veh] and not DoesEntityExist(veh) then soundOf[veh] = nil end end
        for veh in pairs(baseForce) do if not DoesEntityExist(veh) then baseForce[veh] = nil end end
        Wait(1500)
    end
end)

AddStateBagChangeHandler('exti_carmods', '', function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if veh and veh ~= 0 then setSound(veh, value and value.engine or nil) end
end)

-- the power: only the driver's game drives the car
CreateThread(function()
    while true do
        local veh = cache.vehicle
        if veh and GetPedInVehicleSeat(veh, -1) == cache.ped then
            local m = modsOf(veh)
            local power = m and tonumber(m.power) or 1.0
            if not baseForce[veh] then baseForce[veh] = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce') end
            local want = baseForce[veh] * power
            if math.abs(GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce') - want) > 0.0005 then
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce', want)
            end
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)

---------------------------------------------------------------------------
-- nitro
---------------------------------------------------------------------------
local fx, boosting = {}, false
local EXHAUSTS = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'exhaust_5', 'exhaust_6', 'exhaust_7', 'exhaust_8' }

local function flames(veh, on)
    for _, h in ipairs(fx) do StopParticleFxLooped(h, false) end
    fx = {}
    if not on then return end
    if not HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') then
        RequestNamedPtfxAsset('veh_xs_vehicle_mods')
        local t = GetGameTimer() + 1000
        while not HasNamedPtfxAssetLoaded('veh_xs_vehicle_mods') and GetGameTimer() < t do Wait(0) end
    end
    for _, bone in ipairs(EXHAUSTS) do
        local idx = GetEntityBoneIndexByName(veh, bone)
        if idx ~= -1 then
            UseParticleFxAssetNextCall('veh_xs_vehicle_mods')
            fx[#fx + 1] = StartParticleFxLoopedOnEntityBone('veh_nitrous', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, idx, 1.0, false, false, false)
        end
    end
end

local function startBoost(veh)
    boosting = true
    SetVehicleBoostActive(veh, true)
    AnimpostfxPlay('RaceTurbo', 0, false)
    flames(veh, true)
end

local function stopBoost(veh)
    if not boosting then return end
    boosting = false
    if veh and DoesEntityExist(veh) then SetVehicleBoostActive(veh, false) end
    AnimpostfxStop('RaceTurbo')
    flames(veh, false)
end

local hud = { show = false, amt = -1 }
local function showHud(show, amt)
    amt = amt and math.floor(amt + 0.5) or 0
    if hud.show == show and (not show or hud.amt == amt) then return end
    hud.show, hud.amt = show, amt
    SendNUIMessage({ action = 'nos', show = show, amt = amt })
end

CreateThread(function()
    local localAmt, lastServer, used, lastSend, carOf = nil, nil, 0.0, 0, nil
    while true do
        local veh = cache.vehicle
        local m = veh and modsOf(veh)
        if m and m.nitro and GetPedInVehicleSeat(veh, -1) == cache.ped then
            if carOf ~= veh then carOf, localAmt, lastServer = veh, nil, nil end
            local srv = tonumber(m.amt) or 0
            -- the server is the truth; a refill (higher) takes over at once
            if not localAmt or (lastServer and srv > lastServer + 0.5) then localAmt = srv end
            if srv < localAmt - 5 then localAmt = srv end
            lastServer = srv
            local want = localAmt > 0 and IsControlPressed(0, 21) and IsControlPressed(0, 71) and GetEntitySpeed(veh) > 2.0 and not IsPauseMenuActive()
            if want then
                if not boosting then startBoost(veh) end
                SetVehicleCheatPowerIncrease(veh, NOS.power or 2.2)
                local dt = GetFrameTime()
                used = used + dt
                localAmt = math.max(0.0, localAmt - dt * 100.0 / (NOS.seconds or 15))
            elseif boosting then
                stopBoost(veh)
            end
            if used > 0 and (GetGameTimer() - lastSend > 1000 or not boosting) then
                TriggerServerEvent('exti_mechanic:server:nitroUse', NetworkGetNetworkIdFromEntity(veh), used)
                used, lastSend = 0.0, GetGameTimer()
            end
            showHud(true, localAmt)
            Wait(0)
        else
            if boosting then stopBoost(carOf) end
            if used > 0 and carOf and DoesEntityExist(carOf) then
                TriggerServerEvent('exti_mechanic:server:nitroUse', NetworkGetNetworkIdFromEntity(carOf), used)
                used = 0.0
            end
            carOf = nil
            showHud(false)
            Wait(400)
        end
    end
end)

---------------------------------------------------------------------------
-- the dyno (this game is the driver of the car on the dyno)
---------------------------------------------------------------------------
local function wearFactor(veh)
    local st = NetworkGetEntityIsNetworked(veh) and Entity(veh).state.exti_wear
    local c = st and st.c or {}
    local f = 1.0
    for _, id in ipairs({ 'engine_oil', 'spark_plugs', 'air_filter', 'battery', 'motor' }) do
        local v = tonumber(c[id])
        if v and v < 30 then f = f - (30 - v) / 30 * 0.08 end
    end
    return math.max(0.6, f)
end

local function measure(veh)
    SetVehicleModKit(veh, 0)
    local force = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
    local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass')
    local eng = GetVehicleMod(veh, 11) + 1
    local trans = GetVehicleMod(veh, 13) + 1
    local turbo = IsToggleModOn(veh, 18) and 1 or 0
    local hp = force * mass * 0.85 * (1 + eng * 0.06 + turbo * 0.12) * wearFactor(veh)
    local nm = hp * 1.32
    local top = GetVehicleEstimatedMaxSpeed(veh) * 3.6 * (1 + eng * 0.015 + turbo * 0.02 + trans * 0.01)
    local zero = 1.3 + 0.9 * mass / math.max(hp, 1) * (1 - trans * 0.03) * (1 - turbo * 0.05)
    zero = math.max(1.9, math.min(25.0, zero))
    return { hp = math.floor(hp + 0.5), nm = math.floor(nm + 0.5), top = math.floor(top + 0.5), zero = math.floor(zero * 10 + 0.5) / 10,
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)) }
end

lib.callback.register('exti_mechanic:client:dynoRun', function(netId)
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= cache.ped then return false end
    local result = measure(veh)
    lib.notify({ type = 'inform', description = 'الداينو يعمل… لا تتحرك' })
    FreezeEntityPosition(veh, true)
    -- hear the engine, not the radio (the driver's own station is put back after)
    local station = GetPlayerRadioStationName()
    SetVehicleEngineOn(veh, true, true, false)
    ShakeGameplayCam('ROAD_VIBRATION_SHAKE', 0.6)
    local t0 = GetGameTimer()
    local popped = false
    while GetGameTimer() - t0 < 8000 do
        local k = (GetGameTimer() - t0) / 8000
        local rpm = k < 0.8 and 0.2 + 0.8 * (k / 0.8) or 1.0 - (k - 0.8) / 0.2 * 0.75
        SetVehicleCurrentRpm(veh, rpm)
        SetVehicleRadioEnabled(veh, false)
        SetVehRadioStation(veh, 'OFF')
        if k > 0.8 and not popped then popped = true SetVehicleBoostActive(veh, true) end
        Wait(0)
    end
    SetVehicleBoostActive(veh, false)
    StopGameplayCamShaking(true)
    SetVehicleRadioEnabled(veh, true)
    if station and station ~= '' and station ~= 'OFF' then SetVehRadioStation(veh, station) end
    FreezeEntityPosition(veh, false)
    return result
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if boosting then stopBoost(cache.vehicle) end
end)
