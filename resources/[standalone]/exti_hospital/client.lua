-- EX_Tii hospitals (client): the reception panel and the medical report card.

local ui = { open = false }

local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

local ERRORS = {
    too_far = 'اقترب من موظفة الاستقبال أكثر',
    healthy = 'صحتك كاملة، لا تحتاج إلى علاج',
    no_beds = 'كل الأسرّة مشغولة الآن، حاول بعد قليل',
    no_ems = 'لا يوجد مسعفون في الخدمة الآن',
    cant_carry = 'لا يوجد مكان في حقيبتك للتقرير',
    failed = 'حدث خطأ، حاول مرة أخرى',
}

local function notify(kind, text)
    lib.notify({ type = kind, description = text })
end

local function errorText(code, wait)
    if code == 'wait' then
        return ('انتظر %d دقيقة قبل أن تطلب هذا مرة أخرى'):format(wait or 1)
    end
    return ERRORS[code] or ERRORS.failed
end

---------------------------------------------------------------------------
-- the panel
---------------------------------------------------------------------------
local function close(tellUi)
    if not ui.open then return end
    ui.open = false
    SetNuiFocus(false, false)
    if tellUi ~= false then SendNUIMessage({ action = 'close' }) end
end

local function openReception(name)
    if ui.open or ui.busy or isDown() then return end
    ui.busy = true
    local info = lib.callback.await('exti_hospital:server:info', false, name)
    ui.busy = false
    if not info then return notify('error', ERRORS.too_far) end
    ui.open = true
    ui.mode = 'reception'
    ui.hospital = name
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'reception', data = info })
end

-- opened by the receptionist (exti_shops); a local event only, nobody can open it from outside
AddEventHandler('exti_hospital:client:openReception', function(name)
    openReception(name)
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    close(false)
end)

-- free treatment
RegisterNUICallback('treat', function(_, cb)
    if not ui.open or ui.mode ~= 'reception' then return cb({ ok = false }) end
    local ok, code = lib.callback.await('exti_hospital:server:treat', false, ui.hospital)
    cb({ ok = ok, error = not ok and (ERRORS[code] or ERRORS.failed) or nil })
    if ok then close() end
end)

-- check-up: the doctor examines you, then the report goes in your bag
local function runCheckup(name)
    local ok, code, wait = lib.callback.await('exti_hospital:server:startCheckup', false, name)
    if not ok then return notify('error', errorText(code, wait)) end
    local done = lib.progressCircle({
        duration = Config.checkupTime * 1000,
        position = 'bottom',
        label = 'الطبيب يفحصك...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
        anim = { dict = 'anim@heists@heist_corona@single_team', clip = 'single_team_loop_boss', flag = 49 },
    })
    if not done then return notify('error', 'أُلغي الفحص') end
    local finished, err, report = lib.callback.await('exti_hospital:server:finishCheckup', false)
    if not finished then return notify('error', errorText(err)) end
    notify('success', 'انتهى الفحص: التقرير الطبي في حقيبتك')
    Wait(400)
    TriggerEvent('exti_hospital:client:showReport', report)
end

RegisterNUICallback('checkup', function(_, cb)
    if not ui.open or ui.mode ~= 'reception' then return cb({ ok = false }) end
    cb({ ok = true })
    local name = ui.hospital
    close()
    CreateThread(function() runCheckup(name) end)
end)

-- call a medic
RegisterNUICallback('callMedic', function(_, cb)
    if not ui.open or ui.mode ~= 'reception' then return cb({ ok = false }) end
    local ok, code, wait = lib.callback.await('exti_hospital:server:callMedic', false, ui.hospital)
    if ok then
        cb({ ok = true, message = 'تم إبلاغ المسعفين، انتظر هنا قليلًا' })
    else
        cb({ ok = false, error = errorText(code, wait) })
    end
end)

-- close the reception panel when you walk away or go down
CreateThread(function()
    while true do
        if ui.open and ui.mode == 'reception' then
            local hospital = Config.hospitals[ui.hospital]
            if isDown() or cache.vehicle or not hospital
                or #(GetEntityCoords(cache.ped) - hospital.reception) > Config.reach + 0.5 then
                close()
            end
            Wait(300)
        else
            Wait(800)
        end
    end
end)

---------------------------------------------------------------------------
-- the medical report card (from the inventory, or someone shows you theirs)
---------------------------------------------------------------------------
local function closestPlayer()
    local player, _, coords = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
    if not player then return end
    return GetPlayerServerId(player), coords
end

RegisterNetEvent('exti_hospital:client:showReport', function(report, shownByOther)
    if type(report) ~= 'table' or not report.number then return end
    -- someone else's report never takes over your screen while you are busy
    if shownByOther and (IsNuiFocused() or cache.vehicle or isDown() or lib.progressActive()) then return end
    if ui.open then close() end
    pcall(function() exports.ox_inventory:closeInventory() end)
    ui.open = true
    ui.mode = 'report'
    ui.report = report
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'report', data = report, canShow = not shownByOther })
end)

RegisterNUICallback('showReport', function(_, cb)
    if not ui.open or ui.mode ~= 'report' or not ui.report then return cb({ ok = false }) end
    local target = closestPlayer()
    if not target then
        return cb({ ok = false, error = 'لا يوجد أحد قريب منك' })
    end
    TriggerServerEvent('exti_hospital:server:showReport', target, { number = ui.report.number })
    cb({ ok = true, message = 'أظهرت التقرير لأقرب شخص' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ui.open then SetNuiFocus(false, false) end
end)
