-- =====================================================================
-- EX_Tii jobs: tow truck driver
-- broken-down car (gold ring around it) -> stand beside it -> [E] lift it onto the flatbed
-- drop yard (gold circle) -> [E] put it down -> paid, next car. 3 cars per round.
-- Abandoned player cars: walk up to the car near your flatbed, press E -> "اسحب المركبة المتروكة" -> to the impound
-- =====================================================================
local job = EXJ.config.jobs.tow
local T = { round = nil, blip = nil, dropBlip = nil, loaded = nil, busy = false, running = false, spawning = false, prepared = {}, slowZone = nil }

-- city traffic crawls past a broken-down car while the tow driver works there (nobody gets run over at the curb)
local function slowTraffic(pos)
    if pos and not T.slowZone then
        T.slowZone = AddRoadNodeSpeedZone(pos.x, pos.y, pos.z, 22.0, 2.5, false)
    elseif not pos and T.slowZone then
        RemoveRoadNodeSpeedZone(T.slowZone)
        T.slowZone = nil
    end
end

local function mission()
    return T.round and T.round.mission
end

local function nearestDrop(coords)
    local best, bestDist
    for _, drop in ipairs(job.drops) do
        local d = #(coords - drop.coords)
        if not bestDist or d < bestDist then best, bestDist = drop, d end
    end
    return best, bestDist
end

local function setBlips()
    EXJ.removeBlip(T.blip)
    EXJ.removeBlip(T.dropBlip)
    T.blip, T.dropBlip = nil, nil
    if T.loaded then
        local drop = nearestDrop(GetEntityCoords(cache.ped))
        T.dropBlip = EXJ.blip(drop.coords, 794, drop.label, true) -- drop off: bring the car here
        return
    end
    local m = mission()
    if m then
        local r = T.round
        local name = (r and r.index and r.total) and ('مركبة معطلة %d من %d'):format(r.index, r.total) or 'مركبة معطلة'
        T.blip = EXJ.blip(m.coords, 380, name, true) -- pick up: the broken-down car
    end
end

local function missionCar()
    local m = mission()
    if not m or not m.netId or not NetworkDoesEntityExistWithNetworkId(m.netId) then return nil end
    local car = NetworkGetEntityFromNetworkId(m.netId)
    -- EX_Tii: only the broken car made for this mission (a reused id could point at another car)
    if car == 0 or not DoesEntityExist(car) or not Entity(car).state.exti_broken then return nil end
    return car
end

-- make the broken-down car look broken: bonnet up, hazard lights, smoking engine
local function prepareCar(car, netId)
    if T.prepared[netId] or not EXJ.takeControl(car) then return end
    T.prepared[netId] = true
    SetVehicleOnGroundProperly(car)
    SetVehicleEngineHealth(car, 250.0)
    SetVehicleDoorOpen(car, 4, false, false)
    SetVehicleIndicatorLights(car, 0, true)
    SetVehicleIndicatorLights(car, 1, true)
    SetVehicleDoorsLocked(car, 1)
end

local function loadCar(car)
    local truck = EXJ.vehicle()
    if not truck then return EXJ.notify('تحتاج إلى شاحنة السحب الخاصة بك', 'error') end
    if T.loaded then return EXJ.notify('الشاحنة محمّلة بالفعل', 'error') end
    T.busy = true
    EXJ.clearPrompt('tow')
    local ok, kind, minutes = lib.callback.await('exti_jobs:server:towCanLoad', false, VehToNet(car))
    if not ok then
        T.busy = false
        local text = ({
            occupied = 'يوجد شخص داخل المركبة',
            truckfar = 'قرّب الشاحنة من المركبة',
            far = 'اقترب من المركبة',
            notmission = 'هذه المركبة ليست ضمن مهامك',
            notabandoned = ('هذه المركبة ليست متروكة بعد، يمكن سحبها بعد %s دقيقة'):format(minutes or '?'),
            truck = 'لا يمكن سحب شاحنة سحب',
            loaded = 'الشاحنة محمّلة بالفعل',
        })[kind] or 'لا يمكنك سحب هذه المركبة'
        return EXJ.notify(text, 'error')
    end
    TaskTurnPedToFaceEntity(cache.ped, car, 800)
    Wait(800)
    local done = lib.progressBar({
        duration = 5000,
        label = 'ربط المركبة ورفعها على الشاحنة...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 },
    })
    ClearPedTasks(cache.ped)
    if not done or not DoesEntityExist(car) or not DoesEntityExist(truck) then
        lib.callback.await('exti_jobs:server:towCancelLoad', false)
        T.busy = false
        return
    end
    EXJ.takeControl(car)
    SetVehicleDoorShut(car, 4, true)
    SetVehicleIndicatorLights(car, 0, false)
    SetVehicleIndicatorLights(car, 1, false)
    AttachEntityToEntity(car, truck, GetEntityBoneIndexByName(truck, 'bodyshell'), 0.0, -2.35, 1.15, 0.0, 0.0, 0.0, true, true, false, true, 0, true)
    FreezeEntityPosition(car, true)
    T.loaded = car
    T.loadedKind = kind
    setBlips()
    local drop = nearestDrop(GetEntityCoords(truck))
    EXJ.notify(kind == 'abandoned' and ('خذ المركبة إلى %s لحجزها'):format(drop.label) or ('خذ المركبة إلى %s'):format(drop.label), 'inform', 7000)
    T.busy = false
end

local function unloadCar()
    local truck, car = EXJ.vehicle(), T.loaded
    if not truck or not car or not DoesEntityExist(car) then
        T.loaded = nil
        return
    end
    T.busy = true
    EXJ.clearPrompt('tow')
    local done = lib.progressBar({
        duration = 5000,
        label = 'إنزال المركبة...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if not done then T.busy = false return end
    EXJ.takeControl(car)
    FreezeEntityPosition(car, false)
    Wait(200)
    AttachEntityToEntity(car, truck, 20, 0.0, -9.5, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
    DetachEntity(car, true, true)
    SetVehicleOnGroundProperly(car)
    T.loaded = nil
    Wait(250)
    local ok, result = lib.callback.await('exti_jobs:server:towDeliver', false, VehToNet(car))
    if ok and result then
        if result.round then EXJ.setRound(result.round) else setBlips() end
        local r = T.round
        if result.abandoned then
            EXJ.notify('سُلّمت المركبة إلى ساحة الحجز', 'success', 6000)
        elseif r.index == 1 then
            EXJ.notify(('اكتملت الجولة! جولة جديدة: %d مركبات، الأولى محددة على الخريطة'):format(r.total), 'success', 8000)
        else
            EXJ.notify(('سلّمت المركبة! المركبة التالية (%d من %d) محددة على الخريطة'):format(r.index, r.total), 'success', 7000)
        end
    else
        lib.callback.await('exti_jobs:server:towCancelLoad', false)
        setBlips()
        if result == 'notdrop' then EXJ.notify('أنزل المركبة داخل ساحة التسليم', 'error')
        elseif result == 'fast' then EXJ.notify('انتظر قليلًا ثم حاول مرة أخرى', 'error') end
    end
    T.busy = false
end

-- the closest car (not your truck, not the job's car) you stand next to, near your flatbed
local function abandonedCandidate(me, truck)
    local truckPos = GetEntityCoords(truck)
    if #(me - truckPos) > 25.0 then return end
    local job = missionCar()
    local best, bestDist
    local pool = GetGamePool('CVehicle')
    for i = 1, #pool do
        local veh = pool[i]
        -- EX_Tii: only empty player cars can be abandoned ones (no game traffic, no work vehicles)
        if veh ~= truck and veh ~= job and not IsEntityAttached(veh) and NetworkGetEntityIsNetworked(veh)
            and IsVehicleSeatFree(veh, -1) and not Entity(veh).state.exti_job and not Entity(veh).state.exti_broken then
            local pos = GetEntityCoords(veh)
            local d = #(me - pos)
            if d < 3.0 and #(pos - truckPos) < 15.0 and (not bestDist or d < bestDist) then
                best, bestDist = veh, d
            end
        end
    end
    return best
end

local function loop()
    if T.running then return end
    T.running = true
    CreateThread(function()
        while EXJ.shift and EXJ.shift.job == 'tow' and T.round do
            local sleep = 500
            local me = GetEntityCoords(cache.ped)
            local truck = EXJ.vehicle()
            local onFoot = not cache.vehicle
            local prompted = false

            if T.loaded then
                slowTraffic(nil)
                if not DoesEntityExist(T.loaded) then
                    T.loaded = nil
                    lib.callback.await('exti_jobs:server:towCancelLoad', false)
                    setBlips()
                else
                    local drop, dist = nearestDrop(me)
                    if dist < 120.0 then
                        sleep = 0
                        local inside = truck and #(GetEntityCoords(truck).xy - drop.coords.xy) < job.dropRadius
                        EXJ.drawCircle(drop.coords, job.dropRadius, inside, true)
                        if inside and not T.busy then
                            EXJ.prompt('tow', '[E] أنزل المركبة')
                            prompted = true
                            if EXJ.pressedE() then unloadCar() end
                        end
                    end
                end
            else
                local m = mission()
                if m then
                    local dist = #(me - m.coords)
                    -- EX_Tii: also ask again (every few seconds) when the car is gone - police, admin, a thief -
                    -- the server then makes a new one
                    local askAgain = m.netId and not missionCar() and GetGameTimer() - (T.lastAsk or 0) > 5000
                    if (not m.netId or askAgain) and dist < 140.0 and not T.spawning then
                        T.spawning = true
                        T.lastAsk = GetGameTimer()
                        local fresh = not m.netId
                        CreateThread(function()
                            -- parked city cars standing on that curb spot go away first
                            if fresh then
                                ClearAreaOfVehicles(m.coords.x, m.coords.y, m.coords.z, 6.0, false, false, false, false, false)
                            end
                            local netId = lib.callback.await('exti_jobs:server:towSpawn', false)
                            local cur = mission()
                            if netId and cur then cur.netId = netId end
                            T.spawning = false
                        end)
                    end
                    local car = missionCar()
                    if car then
                        local carPos = GetEntityCoords(car)
                        slowTraffic(#(me - carPos) < 90.0 and carPos or nil)
                        if #(me - carPos) < 90.0 then
                            sleep = 0
                            prepareCar(car, m.netId)
                            local close = onFoot and #(me - carPos) < 3.6
                            EXJ.drawCircle(carPos, 3.0, close, true)
                            if close and not T.busy then
                                if not truck or #(GetEntityCoords(truck) - carPos) > 15.0 then
                                    EXJ.prompt('tow', 'قرّب شاحنة السحب من المركبة')
                                else
                                    EXJ.prompt('tow', '[E] ارفع المركبة على الشاحنة')
                                    if EXJ.pressedE() then loadCar(car) end
                                end
                                prompted = true
                            end
                        end
                    end
                end
            end
            -- EX_Tii: abandoned player cars: walk up to one close to your flatbed and press E
            if not prompted and not T.loaded and onFoot and not T.busy and truck then
                local car = abandonedCandidate(me, truck)
                if car then
                    sleep = 0
                    EXJ.prompt('tow', '[E] اسحب المركبة المتروكة')
                    prompted = true
                    if EXJ.pressedE() then loadCar(car) end
                end
            end
            if not prompted then EXJ.clearPrompt('tow') end
            Wait(sleep)
        end
        EXJ.clearPrompt('tow')
        slowTraffic(nil)
        T.running = false
    end)
end

-- abandoned player cars: walk up to one near your flatbed and press E (see loop above; no third eye)

EXJ.jobs.tow = {
    target = function()
        if T.loaded then return nearestDrop(GetEntityCoords(cache.ped)).coords, true end
        local m = mission()
        return m and m.coords, false
    end,
    start = function(round)
        T.round = round
        setBlips()
        EXJ.notify('استلم شاحنة السحب من الساحة، ثم اتبع العلامة إلى المركبة المعطلة', 'success', 9000)
        loop()
    end,
    update = function(round)
        T.round = round
        setBlips()
        loop()
    end,
    stop = function()
        local car, truck = T.loaded, EXJ.vehicle()
        if car and DoesEntityExist(car) and EXJ.takeControl(car) then
            FreezeEntityPosition(car, false)
            DetachEntity(car, true, true)
        end
        T.loaded = nil
        EXJ.removeBlip(T.blip)
        EXJ.removeBlip(T.dropBlip)
        T.blip, T.dropBlip = nil, nil
        T.round = nil
        T.prepared = {}
        slowTraffic(nil)
        EXJ.clearPrompt('tow')
    end,
}
