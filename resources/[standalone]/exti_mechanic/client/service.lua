-- =====================================================================
-- EX_Tii Mechanic (client): SERVICE at the car — "[E] صيانة المركبة" next to any car (on duty):
-- the menu shows every part with its %, the part you need and how many you carry; picking one runs
-- the repair's steps (each a small game: pour, torque, keys, hold, skill check, scrub) with the
-- right animation (bonnet open, under the car, at a wheel). Wash and wax are in the same menu.
-- =====================================================================

local S = Config.service

local function isElectric(veh)
    local ok, ev = pcall(GetIsVehicleElectric, GetEntityModel(veh))
    return ok and ev == true
end

local ERR = {
    no_car = 'لا توجد سيارة بجانبك', too_far = 'اقترب من السيارة', no_part = 'لا تحمل القطعة المطلوبة',
    not_this_car = 'هذه القطعة ليست في هذه السيارة', too_fast = 'لم تكتمل العملية', cancelled = 'أُلغيت العملية',
    off_duty = 'ابدأ مناوبتك في الورشة أولًا', wait = 'انتظر لحظة',
}
local function fail(code) lib.notify({ type = 'error', description = ERR[code] or 'حدث خطأ، حاول مرة أخرى' }) end

---------------------------------------------------------------------------
-- the small games (the page draws them; the answer comes back through mgDone)
---------------------------------------------------------------------------
local mgWaiting = nil
RegisterNUICallback('mgDone', function(data, cb)
    cb(true)
    if mgWaiting then
        local p = mgWaiting
        mgWaiting = nil
        SetNuiFocus(false, false)
        p:resolve(type(data) == 'table' and data.ok == true)
    end
end)

local function miniGame(kind, label, n, mouse)
    local p = promise.new()
    mgWaiting = p
    SetNuiFocus(true, mouse == true)
    SendNUIMessage({ action = 'mg', open = true, kind = kind, label = label, n = n })
    return Citizen.Await(p)
end

local function skill()
    local ok, res = pcall(lib.skillCheck, { 'easy', 'medium', { areaSize = 50, speedMultiplier = 1.2 } }, { 'w', 'a', 's', 'd' })
    return ok and res == true
end

local function wait(label, seconds)
    return lib.progressBar({
        duration = math.floor((seconds or 3) * 1000), label = label, useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
    }) == true
end

local function runStep(step)
    local kind, label, n = step[1], step[2], step[3]
    if kind == 'wait' then return wait(label, n) end
    if kind == 'skill' then
        lib.showTextUI(label, { position = 'top-center' })
        local ok = skill()
        lib.hideTextUI()
        return ok
    end
    return miniGame(kind, label, n, kind == 'scrub')
end

---------------------------------------------------------------------------
-- where to stand and how to look busy
---------------------------------------------------------------------------
local ANIM = {
    bonnet = { dict = 'mini@repair', clip = 'fixing_a_player' },
    under = { dict = 'amb@world_human_vehicle_mechanic@male@base', clip = 'base' },
    wheel = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
    wash = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base' },
}
local WHERE = {
    oil = 'under', pour = 'bonnet', filter = 'bonnet', plugs = 'bonnet', brakes = 'wheel', clutch = 'under',
    battery = 'under', wheel = 'wheel', wash = 'wash', wax = 'wash',
}

local function playAnim(name)
    local a = ANIM[name]
    if not a then return end
    if pcall(lib.requestAnimDict, a.dict, 3000) then
        TaskPlayAnim(cache.ped, a.dict, a.clip, 3.0, 3.0, -1, 1, 0, false, false, false)
    end
end

local function stopAnim()
    ClearPedTasks(cache.ped)
end

local function faceCar(veh, where)
    local target
    if where == 'wheel' then
        target = GetWorldPositionOfEntityBone(veh, GetEntityBoneIndexByName(veh, 'wheel_lf'))
    elseif where == 'bonnet' then
        local min, max = GetModelDimensions(GetEntityModel(veh))
        target = GetOffsetFromEntityInWorldCoords(veh, 0.0, max.y, 0.0)
    else
        target = GetEntityCoords(veh)
    end
    if target then TaskTurnPedToFaceCoord(cache.ped, target.x, target.y, target.z, 800) Wait(800) end
end

---------------------------------------------------------------------------
-- one job (a repair, a wash, a wax) from start to finish
---------------------------------------------------------------------------
local working = false

local function runJob(veh, start, done)
    if working then return end
    working = true
    local job, err = start()
    if not job then working = false return fail(err) end
    local where = WHERE[job.recipe] or 'bonnet'
    if where == 'bonnet' then SetVehicleDoorOpen(veh, 4, false, false) end
    faceCar(veh, where)
    local ok = true
    for t = 1, (job.times or 1) do
        playAnim(where)
        for _, step in ipairs(job.steps or {}) do
            if not DoesEntityExist(veh) or #(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) > S.reach + 2.0 then ok = false break end
            if not runStep(step) then ok = false break end
            playAnim(where)
        end
        if not ok then break end
        if job.times and job.times > 1 and t < job.times then
            lib.notify({ type = 'success', description = ('تم الإطار %d من %d'):format(t, job.times) })
        end
    end
    stopAnim()
    if where == 'bonnet' then SetVehicleDoorShut(veh, 4, false) end
    if not ok then
        lib.callback.await('exti_mechanic:server:workCancel', false)
        working = false
        return lib.notify({ type = 'error', description = 'فشلت العملية، لم تُستهلك أي قطعة. حاول مرة أخرى' })
    end
    local res, e2 = done()
    working = false
    if not res then return fail(e2) end
    return res
end

local function repair(veh, comp, label)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local res = runJob(veh,
        function() return lib.callback.await('exti_mechanic:server:repairStart', false, netId, comp) end,
        function() return lib.callback.await('exti_mechanic:server:repairDone', false, true) end)
    if res then lib.notify({ type = 'success', description = ('تم تغيير %s: 100%%'):format(res.label or label) }) end
end

local function clean(veh, kind)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local res = runJob(veh,
        function() return lib.callback.await('exti_mechanic:server:cleanStart', false, netId, kind) end,
        function() return lib.callback.await('exti_mechanic:server:cleanDone', false, true) end)
    if res then lib.notify({ type = 'success', description = kind == 'wax' and 'لمعت السيارة! الواكس يحميها من الأوساخ لساعات' or 'السيارة نظيفة الآن' }) end
end

---------------------------------------------------------------------------
-- the menu
---------------------------------------------------------------------------
local function colorOf(p)
    if p >= 50 then return 'green' elseif p >= (S.warnAt or 15) then return 'yellow' end
    return 'red'
end

function MEC.openService(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local info, err = lib.callback.await('exti_mechanic:server:serviceInfo', false, netId, isElectric(veh), GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
    if not info then return fail(err) end
    local options = {}
    options[#options + 1] = {
        title = ('%s  ·  %s كم%s'):format(info.plate, info.km, info.ev and '  ·  كهربائية' or ''),
        description = ('المحرك %d%%  ·  الهيكل %d%%  (يُصلحان بعُدة الإصلاح)'):format(math.max(0, info.engine), math.max(0, info.body)),
        icon = info.ev and 'bolt' or 'car', readOnly = true,
    }
    for _, p in ipairs(info.parts) do
        local enough = p.have >= p.count
        options[#options + 1] = {
            title = ('%s  %d%%'):format(p.label, p.pct),
            description = enough and ('تحتاج %d× %s (معك %d)'):format(p.count, p.partLabel, p.have)
                or ('تحتاج %d× %s · معك %d، اطلبها من متجر القطع'):format(p.count, p.partLabel, p.have),
            progress = p.pct, colorScheme = colorOf(p.pct),
            icon = p.pct < (S.warnAt or 15) and 'triangle-exclamation' or 'wrench',
            iconColor = p.pct < (S.warnAt or 15) and '#ff6b6b' or '#f2c230',
            disabled = not enough or p.pct >= 100,
            onSelect = function() repair(veh, p.id, p.label) end,
        }
    end
    options[#options + 1] = {
        title = 'غسيل', description = info.soap > 0 and ('بالإسفنجة والصابون (معك %d صابون)'):format(info.soap) or 'تحتاج صابون السيارات',
        icon = 'soap', iconColor = '#5ac8fa', disabled = info.soap < 1, onSelect = function() clean(veh, 'wash') end,
    }
    options[#options + 1] = {
        title = 'تلميع بالواكس', description = info.waxItems > 0 and ('يحمي السيارة من الأوساخ %d ساعات (معك %d)'):format(S.waxHours or 6, info.waxItems) or 'تحتاج علبة واكس',
        icon = 'star', iconColor = '#ffd659', disabled = info.waxItems < 1, onSelect = function() clean(veh, 'wax') end,
    }
    lib.registerContext({ id = 'exti_mechanic_service', title = 'صيانة المركبة', options = options })
    lib.showContext('exti_mechanic_service')
end

-- the "[E]" next to a car (on duty, on foot)
function MEC.servicePrompt(p)
    if working or cache.vehicle or not MEC.onDuty() then return end
    local veh = lib.getClosestVehicle(p, 3.0, false)
    if not veh or not NetworkGetEntityIsNetworked(veh) then return end
    local class = GetVehicleClass(veh)
    if class == 13 or class == 14 or class == 15 or class == 16 or class == 21 then return end
    return '[E] صيانة المركبة', function() MEC.openService(veh) end
end

---------------------------------------------------------------------------
-- the parts shop's boxes at the delivery spot
---------------------------------------------------------------------------
local box, boxBlip = nil, nil

local function deliverySpot()
    for name, st in pairs(Config.stations) do
        if st.delivery then return name, st.delivery end
    end
end

local function removeBox()
    if box and DoesEntityExist(box) then DeleteEntity(box) end
    if boxBlip and DoesBlipExist(boxBlip) then RemoveBlip(boxBlip) end
    box, boxBlip = nil, nil
end

CreateThread(function()
    local model = `prop_cardbordbox_04a`
    while true do
        local waiting = (tonumber(GlobalState.exti_mechanic_parts_ready) or 0) > 0
        local _, spot = deliverySpot()
        if waiting and spot and MEC.onDuty() then
            if not box or not DoesEntityExist(box) then
                if pcall(lib.requestModel, model, 5000) then
                    box = CreateObject(model, spot.x, spot.y, spot.z - 0.95, false, false, false)
                    PlaceObjectOnGroundProperly(box)
                    FreezeEntityPosition(box, true)
                    SetModelAsNoLongerNeeded(model)
                end
                boxBlip = AddBlipForCoord(spot.x, spot.y, spot.z)
                SetBlipSprite(boxBlip, 478)
                SetBlipColour(boxBlip, 5)
                SetBlipScale(boxBlip, 0.8)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName('طلبية قطع جاهزة')
                EndTextCommandSetBlipName(boxBlip)
            end
        elseif box or boxBlip then
            removeBox()
        end
        Wait(3000)
    end
end)

function MEC.collectParts(spot)
    if (tonumber(GlobalState.exti_mechanic_parts_ready) or 0) < 1 then
        return lib.notify({ type = 'inform', description = 'لا توجد طلبية جاهزة الآن. اطلب القطع من التابلت (متجر القطع)' })
    end
    if pcall(lib.requestAnimDict, 'anim@heists@box_carry@', 3000) then
        TaskPlayAnim(cache.ped, 'anim@heists@box_carry@', 'idle', 3.0, 3.0, -1, 49, 0, false, false, false)
    end
    local done = lib.progressBar({ duration = 4000, label = 'نقل الصناديق إلى رفّ القطع', canCancel = true, disable = { move = true, car = true, combat = true } })
    ClearPedTasks(cache.ped)
    if not done then return end
    local res, err = lib.callback.await('exti_mechanic:server:collectParts', false, spot.station)
    if not res then
        return lib.notify({ type = 'error', description = err == 'no_order' and 'لا توجد طلبية جاهزة' or err == 'too_far' and 'اقترب من نقطة الاستلام' or 'حدث خطأ، حاول مرة أخرى' })
    end
    if res.left > 0 then
        lib.notify({ type = 'warning', description = ('وُضعت %d قطعة على رفّ القطع، والرف ممتلئ: بقيت %d عند نقطة الاستلام'):format(res.moved, res.left) })
    else
        lib.notify({ type = 'success', description = ('وُضعت %d قطعة على رفّ القطع'):format(res.moved) })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then removeBox() end
end)
