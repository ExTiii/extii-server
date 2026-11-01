-- =====================================================================
-- EX_Tii Police (client): the public forms — anyone fills a paper form at the front desk; officers
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
        if open and (POL.isDown() or (open.mode == 'inbox' and not POL.onDuty())
            or #(GetEntityCoords(cache.ped) - open.coords) > Config.reachPoint + 2.5) then
            close(true)
        end
        Wait(open and 500 or 1500)
    end
end)

function POL.openForms(spot)
    if open then return end
    local data, err = lib.callback.await('exti_police:server:formsInfo', false)
    if not data then return POL.error(err) end
    open = { mode = 'citizen', coords = spot.coords }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'forms', open = true, mode = 'citizen', data = data })
end

function POL.openInbox(spot)
    if open then return end
    local data, err = lib.callback.await('exti_police:server:inbox', false)
    if not data then return POL.error(err) end
    open = { mode = 'inbox', coords = spot.coords }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'forms', open = true, mode = 'inbox', data = data })
end

RegisterNUICallback('formSubmit', function(data, cb)
    if not open or open.mode ~= 'citizen' or type(data) ~= 'table' then return cb({ ok = false }) end
    cb(lib.callback.await('exti_police:server:formSubmit', false, data.type, data.fields) or { ok = false })
end)

RegisterNUICallback('formGet', function(data, cb)
    if not open or open.mode ~= 'inbox' or type(data) ~= 'table' then return cb({}) end
    cb(lib.callback.await('exti_police:server:formGet', false, tonumber(data.id)) or {})
end)

RegisterNUICallback('formAction', function(data, cb)
    if not open or open.mode ~= 'inbox' or type(data) ~= 'table' then return cb({}) end
    local res = lib.callback.await('exti_police:server:formAction', false, tonumber(data.id), data.action, data.note) or {}
    if res.text then POL.notify('error', POL.ERRORS[res.text] or res.text) end
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
