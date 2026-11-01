-- =====================================================================
-- EX_Tii Mechanic (client): the public forms — anyone fills a paper form at the front desk; officers
-- on duty read them in the inbox at the desk computer.
-- =====================================================================

local open = nil -- { mode = 'citizen'|'inbox', coords }

local function close(tellPage)
    if not open then return end
    open = nil
    SetNuiFocus(false, false)
    if tellPage then SendNUIMessage({ action = 'forms', open = false }) end
end

-- walking away / going down closes it (and the inbox when you go off duty)
CreateThread(function()
    while true do
        if open and (MEC.isDown() or (open.mode == 'inbox' and not MEC.onDuty())
            or #(GetEntityCoords(cache.ped) - open.coords) > Config.reachPoint + 2.5) then
            close(true)
        end
        Wait(open and 500 or 1500)
    end
end)

function MEC.openForms(spot)
    if open then return end
    local data, err = lib.callback.await('exti_mechanic:server:formsInfo', false)
    if not data then return MEC.error(err) end
    open = { mode = 'citizen', coords = spot.coords }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'forms', open = true, mode = 'citizen', data = data })
end

function MEC.openInbox(spot)
    if open then return end
    local data, err = lib.callback.await('exti_mechanic:server:inbox', false)
    if not data then return MEC.error(err) end
    open = { mode = 'inbox', coords = spot.coords }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'forms', open = true, mode = 'inbox', data = data })
end

RegisterNUICallback('formSubmit', function(data, cb)
    if not open or open.mode ~= 'citizen' or type(data) ~= 'table' then return cb({ ok = false }) end
    cb(lib.callback.await('exti_mechanic:server:formSubmit', false, data.type, data.fields) or { ok = false })
end)

RegisterNUICallback('formGet', function(data, cb)
    if not open or open.mode ~= 'inbox' or type(data) ~= 'table' then return cb({}) end
    cb(lib.callback.await('exti_mechanic:server:formGet', false, tonumber(data.id)) or {})
end)

RegisterNUICallback('formAction', function(data, cb)
    if not open or open.mode ~= 'inbox' or type(data) ~= 'table' then return cb({}) end
    local res = lib.callback.await('exti_mechanic:server:formAction', false, tonumber(data.id), data.action, data.note) or {}
    if res.text then MEC.notify('error', MEC.ERRORS[res.text] or res.text) end
    cb({ items = res.items, item = res.item })
end)

RegisterNUICallback('formClose', function(_, cb)
    cb(true)
    close(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
end)
