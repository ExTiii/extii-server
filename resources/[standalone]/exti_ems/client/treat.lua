-- =====================================================================
-- EX_Tii EMS (client): treatment mode, like the video.
-- The camera goes over the patient, points sit on the body parts, the treatment plan is on the
-- left and the medical items at the bottom. Every step is asked to the server (exti_medical),
-- which checks it and decides. The medic kneels the whole time (CPR when doing CPR).
-- =====================================================================

local tr = { on = false, target = nil, cam = nil, anim = nil }

-- where each body part's point sits (ped bones)
local POINTS = {
    head = 31086,     -- SKEL_Head
    neck = 39317,     -- SKEL_Neck_1
    chest = 24818,    -- SKEL_Spine3
    abdomen = 24816,  -- SKEL_Spine1
    back = 57597,     -- SKEL_Spine_Root (shown a bit to the side: the back is under him)
    r_arm = 43810,    -- SKEL_R_Forearm
    l_arm = 61163,    -- SKEL_L_Forearm
    r_leg = 36864,    -- SKEL_R_Calf
    l_leg = 63931,    -- SKEL_L_Calf
}

local ANIMS = {
    kneel = { 'amb@medic@standing@kneel@base', 'base' },
    tend = { 'amb@medic@standing@tendtodead@idle_a', 'idle_a' },
    cpr = { 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest' },
}
local ACTION_ANIM = { extract = 'tend', dress = 'tend', tourniquet = 'tend', infuse = 'tend', med = 'tend', cpr = 'cpr' }

local function exam() return GetResourceState('exti_medical') == 'started' end

local function ask(name, ...)
    local ok, a, b, c = pcall(lib.callback.await, name, false, ...)
    if not ok then return false, 'failed' end
    return a, b, c
end

local function patientPed()
    return tr.target and EMS.patientPed and EMS.patientPed(tr.target) or 0
end

-- ---------------------------------------------------------------------
-- the medic's body
-- ---------------------------------------------------------------------
local function play(name)
    local a = ANIMS[name]
    if not a then return end
    if tr.anim and tr.anim ~= name then
        local old = ANIMS[tr.anim]
        StopAnimTask(cache.ped, old[1], old[2], 2.0)
    end
    tr.anim = name
    if pcall(lib.requestAnimDict, a[1], 3000) and tr.on then
        TaskPlayAnim(cache.ped, a[1], a[2], 3.0, 3.0, -1, 1, 0, false, false, false)
    end
end

local function stopAnims()
    for _, a in pairs(ANIMS) do StopAnimTask(cache.ped, a[1], a[2], 2.0) end
    tr.anim = nil
end

-- ---------------------------------------------------------------------
-- the camera over the patient
-- ---------------------------------------------------------------------
local function makeCam(ped, standing)
    if standing then
        -- an awake patient on his feet: the camera in front of him
        local front = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.9, 0.35)
        local look = GetPedBoneCoords(ped, 24816, 0.0, 0.0, 0.0)
        local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', front.x, front.y, front.z, 0.0, 0.0, 0.0, 55.0, false, 2)
        PointCamAtCoord(cam, look.x, look.y, look.z - 0.15)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 700, true, true)
        return cam
    end
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local foot = GetPedBoneCoords(ped, 14201, 0.0, 0.0, 0.0) -- SKEL_L_Foot
    local mid = (head + foot) / 2
    local dir = head - foot
    local yaw = GetHeadingFromVector_2d(dir.x, dir.y) -- the head points up on the screen
    -- not through a ceiling: look how much room there is above him
    local height, fov = 2.55, 55.0
    local ray = StartShapeTestRay(mid.x, mid.y, mid.z + 0.2, mid.x, mid.y, mid.z + 3.2, 1, ped, 0)
    local status, hit, hitAt
    for _ = 1, 20 do
        status, hit, hitAt = GetShapeTestResult(ray)
        if status ~= 1 then break end
        Wait(0)
    end
    if (hit == true or hit == 1) and hitAt then
        local room = hitAt.z - mid.z - 0.25
        if room < height then
            height = math.max(1.2, room)
            fov = math.min(85.0, 55.0 * 2.55 / height)
        end
    end
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', mid.x, mid.y, mid.z + height, -89.5, 0.0, yaw, fov, false, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 700, true, true)
    return cam
end

local function dropCam()
    if tr.cam then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(tr.cam, false)
        tr.cam = nil
    end
end

-- ---------------------------------------------------------------------
-- open / close
-- ---------------------------------------------------------------------
-- always lets go of everything (focus, camera, kneeling), even if it was still opening
local function close(silent)
    local was, target = tr.on, tr.target
    tr.on = false
    tr.target = nil
    tr.gen = (tr.gen or 0) + 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'treatClose' })
    dropCam()
    stopAnims()
    if was and target and exam() then
        lib.callback('exti_medical:server:treatClose', false, function() end, target)
    end
    if was and not silent then EMS.notify('inform', 'خرجت من وضع العلاج') end
end
EMS.closeTreatment = close

function EMS.openTreatment(target)
    target = tonumber(target)
    if not target or tr.on then return end
    if not exam() then return EMS.error('failed') end
    if not EMS.onDuty() then return EMS.error('off_duty') end
    if EMS.isDown() or cache.vehicle then return end
    if EMS.closeTablet then EMS.closeTablet() end
    Wait(100)
    local ped = EMS.patientPed and EMS.patientPed(target) or 0
    if ped == 0 then return EMS.error('too_far') end
    if target > 0 then
        local st = EMS.deathState and EMS.deathState(target)
        if st ~= 2 and st ~= 3 then EMS.notify('inform', 'بانتظار موافقة المريض…') end
    end
    TaskTurnPedToFaceEntity(cache.ped, ped, 800)
    local ok, view = ask('exti_medical:server:treatOpen', target)
    if not ok then return EMS.error(view) end
    tr.on = true
    tr.target = target
    tr.gen = (tr.gen or 0) + 1
    local gen = tr.gen
    local st = EMS.deathState and EMS.deathState(target)
    local standing = st ~= 2 and st ~= 3 and not IsEntityPlayingAnim(ped, 'amb@world_human_picnic@male@base', 'base', 3)
        and not IsEntityPlayingAnim(ped, 'amb@world_human_picnic@female@base', 'base', 3)
    if standing then TaskTurnPedToFaceEntity(cache.ped, ped, 800) else play('kneel') end
    local cam = makeCam(ped, standing)
    -- closed while the camera was being made (patient gone, medic down...): undo it
    if not tr.on or tr.gen ~= gen then
        if cam then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(cam, false)
        end
        stopAnims()
        return
    end
    tr.cam = cam
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'treatOpen', data = view })

    -- the points follow the body parts on the screen
    CreateThread(function()
        local last = {}
        while tr.on and tr.target == target and tr.gen == gen do
            local p = patientPed()
            if p ~= 0 then
                local pts, changed = {}, false
                for zone, bone in pairs(POINTS) do
                    local c = GetPedBoneCoords(p, bone, 0.0, 0.0, 0.0)
                    local on, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z)
                    pts[zone] = { x = math.floor(x * 10000) / 10000, y = math.floor(y * 10000) / 10000, on = on }
                    local l = last[zone]
                    if not l or l.on ~= on or math.abs(l.x - x) > 0.002 or math.abs(l.y - y) > 0.002 then changed = true end
                end
                if changed then
                    last = pts
                    SendNUIMessage({ action = 'treatPoints', pts = pts })
                end
            end
            Wait(80)
        end
    end)

    -- leave when the patient is gone / too far, or the medic can't go on
    CreateThread(function()
        while tr.on and tr.target == target and tr.gen == gen do
            Wait(500)
            local p = patientPed()
            local why
            if not EMS.onDuty() then why = 'سجّلت خروجك من الخدمة'
            elseif EMS.isDown() then why = 'أنت مصاب'
            elseif p == 0 then why = 'المريض لم يعد هنا'
            elseif #(GetEntityCoords(cache.ped) - GetEntityCoords(p)) > 3.6 then why = 'المريض بعيد عنك' end
            if why and tr.on then
                close(true)
                EMS.notify('error', why)
            end
        end
    end)
end

-- ---------------------------------------------------------------------
-- what the page asks
-- ---------------------------------------------------------------------
local function reply(cb, ok, data, extra)
    if ok then cb({ ok = true, data = data, extra = extra }) else cb({ ok = false, error = data or 'failed' }) end
end

RegisterNUICallback('treatProbe', function(data, cb)
    if not tr.on or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    local ok, res = ask('exti_medical:server:zone', tr.target, data.zone)
    reply(cb, ok, res)
end)

RegisterNUICallback('treatMeasure', function(data, cb)
    if not tr.on or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    local ok, res = ask('exti_medical:server:measure', tr.target, data.tool)
    reply(cb, ok, res)
end)

RegisterNUICallback('treatAsk', function(_, cb)
    if not tr.on then return cb({ ok = false, error = 'not_open' }) end
    local ok, res = ask('exti_medical:server:ask', tr.target)
    reply(cb, ok, res)
end)

RegisterNUICallback('treatBp', function(data, cb)
    if not tr.on or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    if data.stage == 'start' then
        local ok, res = ask('exti_medical:server:bpStart', tr.target)
        reply(cb, ok, res)
    elseif data.stage == 'finish' then
        local ok, res = ask('exti_medical:server:bpFinish', tr.target, data.token, data.sys, data.dia)
        reply(cb, ok, res)
    else
        cb({ ok = true })
    end
end)

RegisterNUICallback('treatStart', function(data, cb)
    if not tr.on or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    local ok, res = ask('exti_medical:server:treatStart', tr.target, data.action, data.wid, data.choice)
    if ok then play(ACTION_ANIM[data.action] or 'kneel') end
    reply(cb, ok, res)
end)

RegisterNUICallback('treatFinish', function(data, cb)
    if not tr.on or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    local ok, view, extra = ask('exti_medical:server:treatFinish', tr.target, data.token, data.result)
    if tr.on then play('kneel') end
    reply(cb, ok, view, extra)
end)

RegisterNUICallback('treatCancel', function(_, cb)
    cb({ ok = true })
    if tr.on then
        ask('exti_medical:server:treatCancel')
        play('kneel')
    end
end)

RegisterNUICallback('treatComplete', function(_, cb)
    if not tr.on then return cb({ ok = false, error = 'not_open' }) end
    local ok, view, extra = ask('exti_medical:server:treatComplete', tr.target)
    reply(cb, ok, view, extra)
end)

RegisterNUICallback('treatExit', function(_, cb)
    cb({ ok = true })
    close(true)
end)

-- if the page ever thinks treatment is open but the game does not: let go of the mouse
RegisterNUICallback('treatHello', function(_, cb)
    cb({ ok = tr.on })
    if not tr.on then SetNuiFocus(false, false) end
end)

RegisterNetEvent('exti_medical:client:treatUpdate', function(target, view)
    if tr.on and tr.target == target then
        SendNUIMessage({ action = 'treatView', data = view })
    end
end)

-- a test patient was removed while it was being treated
RegisterNetEvent('exti_medical:client:examGone', function(target)
    if tr.on and tr.target == target then
        close(true)
        EMS.notify('error', 'المريض لم يعد هنا')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if tr.on or tr.cam then
        SetNuiFocus(false, false)
        dropCam()
        stopAnims()
    end
end)
