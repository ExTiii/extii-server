-- =====================================================================
-- EX_Tii jobs: delivery driver (GoPostal)
-- depot: park the van in the gold circle -> [E] load 6 parcels
-- shop: [E] take a parcel from the back of the van -> walk in -> [E] hand it over at the counter
-- =====================================================================
local job = EXJ.config.jobs.delivery
local D = { round = nil, blip = nil, carrying = false, box = nil, busy = false, running = false }

local CARRY = { 'anim@heists@box_carry@', 'idle' }
local GIVE = { 'mp_common', 'givetake1_a' }
local BOX = `hei_prop_heist_box`

local function setBlip()
    EXJ.removeBlip(D.blip)
    D.blip = nil
    local r = D.round
    if not r then return end
    if r.stage == 'load' then
        D.blip = EXJ.blip(job.hq.dock, 478, 'تحميل الطرود', true) -- pick up: a crate
    elseif r.stage == 'stops' then
        local stop = r.stops[r.index]
        if stop then -- drop off: a parcel, and which stop it is
            D.blip = EXJ.blip(stop.coords, 501, ('توصيل %d من %d - %s'):format(r.index, r.total or #r.stops, stop.label), true)
        end
    end
end

local function dropBox()
    if D.box and DoesEntityExist(D.box) then DeleteEntity(D.box) end
    D.box = nil
    if D.carrying then StopAnimTask(cache.ped, CARRY[1], CARRY[2], 1.0) end
    D.carrying = false
end

local function vanBack(van)
    return EXJ.behind(van, 0.7)
end

local function takeBox(van)
    D.busy = true
    EXJ.clearPrompt('delivery')
    local back = vanBack(van)
    TaskTurnPedToFaceCoord(cache.ped, back.x, back.y, back.z, 500)
    if EXJ.takeControl(van) then
        SetVehicleDoorOpen(van, 2, false, false)
        SetVehicleDoorOpen(van, 3, false, false)
    end
    local ok = lib.progressBar({
        duration = 1600,
        label = 'تأخذ الطرد...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })
    if NetworkHasControlOfEntity(van) then
        SetVehicleDoorShut(van, 2, false)
        SetVehicleDoorShut(van, 3, false)
    end
    if ok then
        EXJ.loadModel(BOX)
        local box = CreateObject(BOX, 0.0, 0.0, 0.0, true, true, false)
        SetModelAsNoLongerNeeded(BOX)
        AttachEntityToEntity(box, cache.ped, GetPedBoneIndex(cache.ped, 60309), 0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
        D.box = box
        D.carrying = true
        EXJ.loadDict(CARRY[1])
        TaskPlayAnim(cache.ped, CARRY[1], CARRY[2], 8.0, -8.0, -1, 49, 0, false, false, false)
        CreateThread(function()
            while D.carrying do
                if not IsEntityPlayingAnim(cache.ped, CARRY[1], CARRY[2], 3) and not IsEntityPlayingAnim(cache.ped, GIVE[1], GIVE[2], 3) then
                    TaskPlayAnim(cache.ped, CARRY[1], CARRY[2], 8.0, -8.0, -1, 49, 0, false, false, false)
                end
                DisableControlAction(0, 21, true) -- no running with a parcel
                DisableControlAction(0, 22, true) -- no jumping
                Wait(0)
            end
        end)
        EXJ.notify('ادخل المتجر وسلّم الطرد عند الدائرة الذهبية', 'inform', 5000)
    end
    D.busy = false
end

local function handOver(stop)
    D.busy = true
    EXJ.clearPrompt('delivery')
    EXJ.loadDict(GIVE[1])
    StopAnimTask(cache.ped, CARRY[1], CARRY[2], 1.0)
    TaskPlayAnim(cache.ped, GIVE[1], GIVE[2], 8.0, -8.0, 1600, 48, 0, false, false, false)
    Wait(1100)
    local index = D.round.index
    local ok, result = lib.callback.await('exti_jobs:server:deliveryDrop', false, index)
    if ok then
        dropBox()
        if result and result.round then EXJ.setRound(result.round) end
        local r = D.round
        if r.stage == 'load' then
            EXJ.notify('سلّمت كل الطرود! عد إلى المستودع لتحميل جولة جديدة', 'success', 9000)
        else
            EXJ.notify(('سُلّم الطرد! التالي: %s (%d من %d)'):format(r.stops[r.index].label, r.index, r.total), 'success', 7000)
        end
    else
        TaskPlayAnim(cache.ped, CARRY[1], CARRY[2], 8.0, -8.0, -1, 49, 0, false, false, false)
        EXJ.notify(({
            truckfar = 'الشاحنة بعيدة جدًا عن المتجر',
            fast = 'انتظر لحظة ثم حاول مرة أخرى',
            far = 'قف داخل الدائرة الذهبية',
            truck = 'شاحنة التوصيل غير موجودة، عد إلى المشرف',
        })[result] or ('تعذّر تسليم الطرد (%s)'):format(tostring(result)), 'error')
    end
    D.busy = false
end

local function load()
    D.busy = true
    EXJ.clearPrompt('delivery')
    local ok = lib.progressBar({
        duration = 5000,
        label = 'تحميل الطرود في الشاحنة...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, combat = true },
    })
    if ok then
        local done, result = lib.callback.await('exti_jobs:server:deliveryLoad', false)
        if done and result then
            EXJ.setRound(result)
            EXJ.notify(('حمّلت %d طرود! أول توصيل: %s'):format(result.total, result.stops[1].label), 'success', 8000)
        elseif result == 'far' then
            EXJ.notify('أوقف الشاحنة داخل الدائرة الذهبية', 'error')
        elseif result == 'truck' then
            EXJ.notify('تحتاج إلى شاحنة التوصيل الخاصة بك', 'error')
        else
            EXJ.notify('تعذّر التحميل، حاول مرة أخرى', 'error')
        end
    end
    D.busy = false
end

local function loop()
    if D.running then return end
    D.running = true
    CreateThread(function()
        while EXJ.shift and EXJ.shift.job == 'delivery' and D.round do
            local sleep = 500
            local r = D.round
            local van = EXJ.vehicle()
            local me = GetEntityCoords(cache.ped)
            local onFoot = not cache.vehicle

            if D.carrying and cache.vehicle then dropBox() end

            if r.stage == 'load' then
                local dock = job.hq.dock
                if #(me - dock) < 90.0 then
                    sleep = 0
                    local inVan = van and cache.vehicle == van
                    local here = inVan and #(GetEntityCoords(van).xy - dock.xy) < job.hq.dockRadius
                    EXJ.drawCircle(dock, job.hq.dockRadius, here, true)
                    if here and not D.busy then
                        EXJ.prompt('delivery', '[E] حمّل الطرود')
                        if EXJ.pressedE() then load() end
                    else
                        EXJ.clearPrompt('delivery')
                    end
                else
                    EXJ.clearPrompt('delivery')
                end
            elseif r.stage == 'stops' and r.stops[r.index] then
                local stop = r.stops[r.index]
                local dist = #(me - stop.coords)
                local prompted = false
                if dist < 80.0 then
                    sleep = 0
                    local here = onFoot and #(me.xy - stop.coords.xy) < 1.0
                    local z = EXJ.drawCircle(stop.coords, 0.8, here, true)
                    if D.carrying then
                        if here and not D.busy and math.abs(me.z - z) < 2.5 then
                            EXJ.prompt('delivery', '[E] سلّم الطرد')
                            prompted = true
                            if EXJ.pressedE() then handOver(stop) end
                        end
                    elseif van and onFoot and #(GetEntityCoords(van) - stop.coords) < 120.0 then
                        local back = vanBack(van)
                        local atBack = #(me.xy - back.xy) < 1.6
                        EXJ.drawCircle(back, 0.7, atBack, false)
                        if atBack and not D.busy then
                            EXJ.prompt('delivery', '[E] خذ الطرد من الشاحنة')
                            prompted = true
                            if EXJ.pressedE() then takeBox(van) end
                        elseif here and not D.busy then
                            EXJ.prompt('delivery', 'خذ الطرد من خلف الشاحنة أولًا')
                            prompted = true
                        end
                    end
                end
                if not prompted then EXJ.clearPrompt('delivery') end
            end
            Wait(sleep)
        end
        EXJ.clearPrompt('delivery')
        D.running = false
    end)
end

EXJ.jobs.delivery = {
    target = function()
        local r = D.round
        if not r then return end
        if r.stage == 'load' then return job.hq.dock, true end
        local stop = r.stops[r.index]
        return stop and stop.coords, false
    end,
    start = function(round)
        D.round = round
        setBlip()
        EXJ.notify('استلم شاحنة التوصيل، ثم أوقفها في دائرة التحميل الذهبية لتحميل الطرود', 'success', 9000)
        loop()
    end,
    update = function(round)
        D.round = round
        setBlip()
        loop()
    end,
    stop = function()
        dropBox()
        EXJ.removeBlip(D.blip)
        D.blip = nil
        D.round = nil
        EXJ.clearPrompt('delivery')
    end,
}
