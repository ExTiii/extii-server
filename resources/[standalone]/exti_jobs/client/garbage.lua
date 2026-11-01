-- =====================================================================
-- EX_Tii jobs: garbage collector
-- dumpster (gold circle) -> [E] take a bag -> carry it to the back of the truck -> [E] throw it in
-- 2-3 bags per dumpster, 6 dumpsters per round, then back to the depot to empty the truck
-- =====================================================================
local job = EXJ.config.jobs.garbage
local G = { round = nil, blip = nil, carrying = false, bag = nil, busy = false, running = false }

local WALK = { 'missfbi4prepp1', '_bag_walk_garbage_man' }
local THROW = { 'missfbi4prepp1', '_bag_throw_garbage_man' }
local BAG = `prop_cs_rub_binbag_01`

local function setBlip()
    EXJ.removeBlip(G.blip)
    G.blip = nil
    local r = G.round
    if not r then return end
    if r.stage == 'stops' then
        local stop = r.stops[r.index]
        if not stop then return end
        local street = EXJ.street(stop.coords)
        local name = ('حاوية قمامة %d من %d'):format(r.index, r.total or #r.stops)
        G.blip = EXJ.blip(stop.coords, 677, street and (name .. ' - ' .. street) or name, true) -- pick up: a dumpster
    elseif r.stage == 'return' then
        G.blip = EXJ.blip(job.hq.dock, 794, 'تفريغ الشاحنة', true) -- drop off: bring the truck here
    end
end

local function dropBag()
    if G.bag and DoesEntityExist(G.bag) then DeleteEntity(G.bag) end
    G.bag = nil
    if G.carrying then StopAnimTask(cache.ped, WALK[1], WALK[2], 1.0) end
    G.carrying = false
end

local function truckBack(truck)
    return EXJ.behind(truck, 0.8)
end

local function pickBag(stop)
    G.busy = true
    EXJ.clearPrompt('garbage')
    if stop.dumpster then TaskTurnPedToFaceCoord(cache.ped, stop.dumpster.x, stop.dumpster.y, stop.dumpster.z, 600) Wait(600) end
    local ok = lib.progressBar({
        duration = 1800,
        label = 'تأخذ كيس القمامة...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
    })
    if ok then
        EXJ.loadModel(BAG)
        local bag = CreateObject(BAG, 0.0, 0.0, 0.0, true, true, false)
        SetModelAsNoLongerNeeded(BAG)
        AttachEntityToEntity(bag, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
        G.bag = bag
        G.carrying = true
        EXJ.loadDict(WALK[1])
        TaskPlayAnim(cache.ped, WALK[1], WALK[2], 6.0, -6.0, -1, 49, 0, false, false, false)
        CreateThread(function()
            while G.carrying do
                if not IsEntityPlayingAnim(cache.ped, WALK[1], WALK[2], 3) and not IsEntityPlayingAnim(cache.ped, THROW[1], THROW[2], 3) then
                    TaskPlayAnim(cache.ped, WALK[1], WALK[2], 6.0, -6.0, -1, 49, 0, false, false, false)
                end
                Wait(400)
            end
        end)
    end
    G.busy = false
end

local function throwBag(truck)
    G.busy = true
    EXJ.clearPrompt('garbage')
    local back = truckBack(truck)
    TaskTurnPedToFaceCoord(cache.ped, back.x, back.y, back.z, 500)
    Wait(450)
    -- EX_Tii: ask the server first. Before, the bag was deleted before asking, so when the server said
    -- no (truck too far, too fast) the bag was gone and you had to walk back for another one.
    local ok, result = lib.callback.await('exti_jobs:server:garbageBag', false, G.round.index)
    if ok and result then
        EXJ.loadDict(THROW[1])
        TaskPlayAnim(cache.ped, THROW[1], THROW[2], 8.0, 8.0, 1100, 48, 0.0, false, false, false)
        Wait(900)
        dropBag()
        if result.round then EXJ.setRound(result.round) end
        local r = G.round
        if result.paid then
            if r.stage == 'return' then
                EXJ.notify('امتلأت الشاحنة! عد إلى المستودع وادخل الدائرة الذهبية لتفريغها', 'success', 9000)
            else
                EXJ.notify(('أحسنت! الحاوية التالية (%d من %d) محددة على الخريطة'):format(r.index, r.total), 'success', 6000)
            end
        else
            local left = result.bags - result.bagsDone
            EXJ.notify(left == 1 and 'بقي كيس واحد في هذه الحاوية' or ('بقي %d أكياس في هذه الحاوية'):format(left), 'inform', 3500)
        end
    elseif result == 'truckfar' then
        EXJ.notify('الشاحنة بعيدة عن الحاوية، قرّبها أكثر', 'error')
    elseif result == 'far' then
        EXJ.notify('اقترب من خلف الشاحنة', 'error')
    elseif result == 'fast' then
        EXJ.notify('لحظة… حاول مرة أخرى بعد ثوانٍ', 'error')
    elseif result == 'truck' then
        EXJ.notify('تحتاج إلى شاحنة النفايات الخاصة بك', 'error')
    end
    G.busy = false
end

local function unload()
    G.busy = true
    EXJ.clearPrompt('garbage')
    local ok = lib.progressBar({
        duration = 5000,
        label = 'تفريغ الشاحنة...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, combat = true },
    })
    if ok then
        local done, result = lib.callback.await('exti_jobs:server:garbageUnload', false)
        if done and result then
            EXJ.setRound(result)
            EXJ.notify(('فرّغت الشاحنة! جولة جديدة: %d حاويات، أول حاوية محددة على الخريطة'):format(result.total), 'success', 8000)
        elseif result == 'far' then
            EXJ.notify('ادخل بالشاحنة داخل الدائرة الذهبية', 'error')
        elseif result == 'truck' then
            EXJ.notify('تحتاج إلى شاحنة النفايات الخاصة بك', 'error')
        else
            EXJ.notify('تعذّر التفريغ، حاول مرة أخرى', 'error')
        end
    end
    G.busy = false
end

local function loop()
    if G.running then return end
    G.running = true
    CreateThread(function()
        while EXJ.shift and EXJ.shift.job == 'garbage' and G.round do
            local sleep = 500
            local r = G.round
            local truck = EXJ.vehicle()
            local me = GetEntityCoords(cache.ped)
            local onFoot = not cache.vehicle

            if G.carrying and cache.vehicle then dropBag() end

            if r.stage == 'stops' and r.stops[r.index] then
                local stop = r.stops[r.index]
                local dist = #(me - stop.coords)
                if dist < 70.0 then
                    sleep = 0
                    if G.carrying and truck then
                        local back = truckBack(truck)
                        local z = EXJ.drawCircle(back, 0.9, #(me.xy - back.xy) < 1.6, false)
                        if not G.busy and onFoot and #(me.xy - back.xy) < 1.6 and math.abs(me.z - z) < 2.5 then
                            EXJ.prompt('garbage', '[E] ارمِ الكيس في الشاحنة')
                            if EXJ.pressedE() then throwBag(truck) end
                        else
                            EXJ.clearPrompt('garbage')
                        end
                    else
                        local here = onFoot and #(me.xy - stop.coords.xy) < 1.0
                        local z = EXJ.drawCircle(stop.coords, 0.8, here, true)
                        if here and not G.busy and math.abs(me.z - z) < 2.5 then
                            if not truck then
                                EXJ.prompt('garbage', 'تحتاج إلى شاحنة النفايات')
                            elseif #(GetEntityCoords(truck) - stop.coords) > 38.0 then
                                EXJ.prompt('garbage', 'قرّب الشاحنة من الحاوية أولًا')
                            else
                                EXJ.prompt('garbage', ('[E] خذ كيس القمامة (%d من %d)'):format((r.bagsDone or 0) + 1, stop.bags))
                                if EXJ.pressedE() then pickBag(stop) end
                            end
                        else
                            EXJ.clearPrompt('garbage')
                        end
                    end
                else
                    EXJ.clearPrompt('garbage')
                end
            elseif r.stage == 'return' then
                local dock = job.hq.dock
                local dist = #(me - dock)
                if dist < 90.0 then
                    sleep = 0
                    local inTruck = truck and cache.vehicle == truck
                    local here = inTruck and #(GetEntityCoords(truck).xy - dock.xy) < job.hq.dockRadius
                    EXJ.drawCircle(dock, job.hq.dockRadius, here, true)
                    if here and not G.busy then
                        EXJ.prompt('garbage', '[E] فرّغ الشاحنة')
                        if EXJ.pressedE() then unload() end
                    else
                        EXJ.clearPrompt('garbage')
                    end
                else
                    EXJ.clearPrompt('garbage')
                end
            end
            Wait(sleep)
        end
        EXJ.clearPrompt('garbage')
        G.running = false
    end)
end

EXJ.jobs.garbage = {
    target = function()
        local r = G.round
        if not r then return end
        if r.stage == 'return' then return job.hq.dock, true end
        local stop = r.stops[r.index]
        return stop and stop.coords, false
    end,
    start = function(round)
        G.round = round
        setBlip()
        EXJ.notify('استلم شاحنة النفايات من الساحة، ثم اتبع العلامة إلى أول حاوية', 'success', 9000)
        loop()
    end,
    update = function(round)
        G.round = round
        setBlip()
        loop()
    end,
    stop = function()
        dropBag()
        EXJ.removeBlip(G.blip)
        G.blip = nil
        G.round = nil
        EXJ.clearPrompt('garbage')
    end,
}
