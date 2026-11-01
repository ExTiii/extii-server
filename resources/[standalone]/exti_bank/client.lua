-- EX_Tii Bank (client): the tablet at the bank teller and the ATM screen

local ui = { open = false }
local tablet -- the tablet prop in your hand

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    return pcall(lib.requestAnimDict, dict, 3000)
end

local function holdTablet()
    local ped = cache.ped
    local dict, clip = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'
    if loadDict(dict) then
        TaskPlayAnim(ped, dict, clip, 3.0, 3.0, -1, 49, 0, false, false, false)
    end
    local ok = pcall(lib.requestModel, `prop_cs_tablet`, 3000)
    if ok then
        local pos = GetEntityCoords(ped)
        tablet = CreateObject(`prop_cs_tablet`, pos.x, pos.y, pos.z + 0.2, true, true, false)
        AttachEntityToEntity(tablet, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(`prop_cs_tablet`)
    end
end

local function putTabletAway()
    if tablet and DoesEntityExist(tablet) then DeleteEntity(tablet) end
    tablet = nil
    StopAnimTask(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
end

local function useAtm()
    TaskStartScenarioInPlace(cache.ped, 'PROP_HUMAN_ATM', 0, true)
end

local function close(tellServer)
    if not ui.open then return end
    ui.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if ui.kind == 'bank' then putTabletAway() else ClearPedTasks(cache.ped) end
    PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if tellServer ~= false then lib.callback.await('exti_bank:server:close', false) end
    ui.kind = nil
end

local function open(kind)
    if ui.open or ui.opening then return end
    if cache.vehicle then return end
    ui.opening = true
    local data, why = lib.callback.await('exti_bank:server:open', false, kind)
    ui.opening = false
    if not data then
        local text = why == 'too_far' and 'اقترب من موظف البنك'
            or (kind == 'bank' and 'البنك مغلق الآن، حاول لاحقًا' or 'الصراف لا يعمل الآن، حاول لاحقًا')
        lib.notify({ type = 'error', description = text })
        return
    end
    ui.open, ui.kind = true, kind
    if kind == 'bank' then holdTablet() else useAtm() end
    PlaySoundFrontend(-1, kind == 'atm' and 'ATM_WINDOW' or 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterNetEvent('exti_bank:client:openTablet', function() open('bank') end)
RegisterNetEvent('exti_bank:client:openAtm', function() open('atm') end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    close()
end)

RegisterNUICallback('lookup', function(data, cb)
    if not ui.open then return cb(false) end
    cb(lib.callback.await('exti_bank:server:lookup', false, data and data.id))
end)

RegisterNUICallback('action', function(data, cb)
    if not ui.open or type(data) ~= 'table' then return cb({ ok = false, code = 'closed' }) end
    local result = lib.callback.await('exti_bank:server:action', false, data.action, {
        amount = tonumber(data.amount),
        target = tonumber(data.target),
        note = type(data.note) == 'string' and data.note or nil,
        account = type(data.account) == 'string' and data.account or nil,
    })
    if type(result) ~= 'table' then result = { ok = false, code = 'failed' } end
    if result.ok then
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
    elseif result.code == 'too_far' or result.code == 'too_far_atm' or result.code == 'closed' then
        CreateThread(function() Wait(1200) close(false) end)
    end
    cb(result)
end)

RegisterNUICallback('sound', function(data, cb)
    cb(true)
    if data and data.name == 'key' then PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end)

-- new balances while the tablet / ATM is open
RegisterNetEvent('exti_bank:client:balance', function(data)
    if not ui.open or type(data) ~= 'table' then return end
    SendNUIMessage({ action = 'balance', cash = data.cash, bank = data.bank, history = data.history, bills = data.bills })
end)

-- a new bill (a police fine...): pay it at the bank or the ATM
RegisterNetEvent('exti_bank:client:bill', function(data)
    if type(data) ~= 'table' then return end
    lib.notify({
        title = 'فاتورة جديدة',
        description = ('%s · $%s%s — ادفعها من البنك أو الصراف'):format(data.title or 'فاتورة', data.amount or 0,
            data.issuer and (' (' .. data.issuer .. ')') or ''),
        type = 'warning', duration = 9000,
    })
end)

RegisterNetEvent('exti_bank:client:billsReminder', function(data)
    if type(data) ~= 'table' then return end
    lib.notify({
        title = 'فواتير غير مدفوعة',
        description = ('لديك %d فاتورة بقيمة $%s — ادفعها من البنك أو الصراف'):format(data.count or 0, data.total or 0),
        type = 'warning', duration = 9000,
    })
end)

-- money from another player
RegisterNetEvent('exti_bank:client:received', function(data)
    if type(data) ~= 'table' then return end
    lib.notify({
        title = 'تحويل وارد',
        description = ('استلمت $%s من %s%s'):format(tostring(data.amount), tostring(data.name or ''),
            (data.note and data.note ~= '') and ('  \n«' .. data.note .. '»') or ''),
        type = 'success',
        icon = 'building-columns',
        duration = 9000,
    })
end)

-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

-- close if you walk away, get into a car or go down
CreateThread(function()
    local start
    while true do
        if ui.open then
            start = start or GetEntityCoords(cache.ped)
            if cache.vehicle or isDown() or #(GetEntityCoords(cache.ped) - start) > 3.0 then
                close()
            end
            Wait(300)
        else
            start = nil
            Wait(800)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ui.open then SetNuiFocus(false, false) end
    putTabletAway()
end)
