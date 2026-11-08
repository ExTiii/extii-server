local config = require 'config.client'

local function getNPCPedsInVehicle(vehicle)
    local otherPeds = {}
    for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if pedInSeat ~= 0 and not IsPedAPlayer(pedInSeat) then
            otherPeds[#otherPeds + 1] = pedInSeat
        end
    end
    return otherPeds
end

local function makePedFlee(ped)
    ClearPedTasks(ped)
    SetPedFleeAttributes(ped, 0, false)
    TaskReactAndFleePed(ped, cache.ped)
    TaskSmartFleePed(ped, cache.ped, 100.0, -1, false, false)
    ResetPedLastVehicle(ped) -- make ped forget about his last car, so he cant return to it
end

local function makePedsPutHandsUpAndScream(occupants, vehicle)
    for p = 1, #occupants do
        local occupant = occupants[p]
        CreateThread(function()
            Wait(math.random(100, 600)) --Random reaction time to increase realism
            local anim = config.anims.holdup.model[GetEntityModel(vehicle)]
                or config.anims.holdup.class[GetVehicleClass(vehicle)]
                or config.anims.holdup.default
            lib.playAnim(occupant, anim.dict, anim.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
            PlayPain(occupant, 6, 0)
        end)
    end
end

local function onCarjackSuccess(occupants, vehicle)
    for p = 1, #occupants do
        local ped = occupants[p]
        CreateThread(function()
            TaskLeaveVehicle(ped, vehicle, 256) -- flag 256 to leave door open
            PlayPain(ped, 6, 0)
            Wait(1250)
            PlayPain(ped, math.random(7, 8), 0)
            makePedFlee(ped)
        end)
    end
end

local function onCarjackFail(driver)
    exports.qbx_core:Notify(locale('notify.carjack_failed'), 'error')
    makePedFlee(driver)
end

local function carjackVehicle(driver, vehicle)
    local isCarjacking = true
    local occupants = getNPCPedsInVehicle(vehicle)

    CreateThread(function()
        while isCarjacking do
            TaskVehicleTempAction(occupants[1], vehicle, 6, 1)
            Wait(0)
        end
    end)

    makePedsPutHandsUpAndScream(occupants, vehicle)

    --Cancel progress bar if: Ped dies during robbery, car gets too far away
    CreateThread(function()
        while isCarjacking do
            local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(driver))
            if (IsPedDeadOrDying(driver, false) or distance > 7.5) and lib.progressActive() then
                lib.cancelProgress()
            end
            Wait(100)
        end
    end)

    if lib.progressCircle({
        duration = config.carjackingTimeInMs,
        label = locale('progress.attempting_carjack'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
    }) then
        if cache.weapon and isCarjacking then
            isCarjacking = false -- make this false to stop TaskVehicleTempAction from preventing ped to leave the car
            local success = lib.callback.await('qbx_vehiclekeys:server:carjack', false, VehToNet(vehicle), GetWeapontypeGroup(cache.weapon))
            if success then
                onCarjackSuccess(occupants, vehicle)
            else
                onCarjackFail(driver)
            end
            TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
            Wait(2000)
            SendPoliceAlertAttempt('carjack', vehicle)
        end
    else
        makePedFlee(driver)
    end

    Wait(config.delayBetweenCarjackingsInMs)
    isCarjacking = false
end

---Checks if the weapon cannot be used to steal keys from drivers.
---@param weaponHash number The current weapon hash.
---@return boolean `true` if the weapon cannot be used to carjacking, `false` otherwise.
local function getIsBlacklistedWeapon(weaponHash)
    return lib.table.contains(config.noCarjackWeapons, weaponHash)
end

local isWatchCarjackingAttemptRunning = false
local function watchCarjackingAttempts()
    if isWatchCarjackingAttemptRunning then return end
    isWatchCarjackingAttemptRunning = true
    CreateThread(function()
        while cache.weapon and not getIsBlacklistedWeapon(cache.weapon) do
            local aiming, target = GetEntityPlayerIsFreeAimingAt(cache.playerId)
            if aiming
                and DoesEntityExist(target)
                and IsPedInAnyVehicle(target, false)
                and not IsEntityDead(target)
                and not IsPedAPlayer(target)
            then
                local script = GetEntityScript(target)
                if not script then
                    local targetveh = GetVehiclePedIsIn(target, false)

                    if GetPedInVehicleSeat(targetveh, -1) == target
                        and not GetVehicleConfig(targetveh).carjackingImmune
                        and #(GetEntityCoords(cache.ped) - GetEntityCoords(target)) < 5.0
                    then
                        carjackVehicle(target, targetveh)
                    end
                end
            end
            Wait(100)
        end
        isWatchCarjackingAttemptRunning = false
    end)
end

if config.carjackEnable then
    AddEventHandler('ox_lib:cache:weapon', function()
        watchCarjackingAttempts()
    end)
    watchCarjackingAttempts()
end


---------------------------------------------------------------------------
-- EX_Tii (Moe):
--  * a driver pulled out of his car (F) just runs away, he never fights back or comes back for the car
--  * the cars NPCs are driving are never locked: you can always pull the driver out
---------------------------------------------------------------------------
CreateThread(function()
    local victim
    while true do
        local me = PlayerPedId()
        if IsPedJacking(me) then
            local t = GetJackTarget(me)
            if t and t ~= 0 and not IsPedAPlayer(t) then victim = t end
            Wait(100)
        else
            if victim and DoesEntityExist(victim) and not IsPedAPlayer(victim) then
                local v = victim; victim = nil
                SetBlockingOfNonTemporaryEvents(v, true)
                SetPedCombatAttributes(v, 46, false)   -- never fights
                SetPedCombatAttributes(v, 5, false)
                SetPedFleeAttributes(v, 0, false)
                ClearPedTasks(v)
                TaskSmartFleePed(v, me, 150.0, -1, false, false)
                ResetPedLastVehicle(v)
                SetTimeout(20000, function() if DoesEntityExist(v) and not IsPedAPlayer(v) then SetEntityAsNoLongerNeeded(v) end end)
            end
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        local me = PlayerPedId()
        local here = GetEntityCoords(me)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - here) < 40.0 then
                local driver = GetPedInVehicleSeat(veh, -1)
                -- an NPC at the wheel, not a player's car (those carry their lock state), and locked: unlock it
                if driver ~= 0 and not IsPedAPlayer(driver) and Entity(veh).state.doorslockstate == nil and Entity(veh).state.vehicleid == nil
                    and GetVehicleDoorLockStatus(veh) >= 2 then
                    SetVehicleDoorsLocked(veh, 1)
                    SetVehicleDoorsLockedForAllPlayers(veh, false)
                end
            end
        end
        Wait(1000)
    end
end)
