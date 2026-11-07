-- =====================================================================
-- EX_Tii Mechanic (client): the bill sheet. From the Z wheel (الورشة → فاتورة) next to the customer:
-- the mechanic ticks the services, writes a note, and the bill goes to the customer's bank.
-- Also the workshop's slice of the Z wheel (the tablet, the bill).
-- =====================================================================

local REACH = Config.billReach or 3.0

local CHARGE_ERRORS = {
    pick = 'اختر خدمة واحدة على الأقل',
    too_many = 'عدد الخدمات في الفاتورة الواحدة كبير',
    no_fine = 'هذه الخدمات بلا سعر',
    no_bank = 'البنك لا يعمل الآن، حاول بعد قليل',
    nobody = 'لا يوجد زبون بجانبك',
    wait = 'انتظر لحظة',
    no_owner = 'هذه السيارة ليست ملك أحد',
    owner_away = 'صاحب السيارة ليس في المدينة الآن',
    own_car = 'هذه سيارتك أنت',
    not_workshop = 'هذا داخل الورشة فقط',
    no_car = 'لا توجد سيارة بجانبك',
}
for k, v in pairs(CHARGE_ERRORS) do MEC.ERRORS[k] = v end

local sheet = nil -- { target = serverId, ped }

local function close(tellPage)
    if not sheet then return end
    sheet = nil
    SetNuiFocus(false, false)
    if tellPage ~= false then SendNUIMessage({ action = 'charge', open = false }) end
end

-- the person walks away, the officer goes off duty / down: the sheet closes
CreateThread(function()
    while true do
        if sheet and not sheet.done and not sheet.receipt then
            local pid = GetPlayerFromServerId(sheet.target)
            local ped = pid ~= -1 and GetPlayerPed(pid) or 0
            if not MEC.onDuty() or MEC.isDown() or ped == 0
                or #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > REACH + 3.0 then
                close()
            end
        end
        Wait(sheet and 500 or 1500)
    end
end)

function MEC.openCharge(target)
    if sheet then return end
    if not MEC.onDuty() then return MEC.error('off_duty') end
    local data, err = lib.callback.await('exti_mechanic:server:chargeOpen', false, target)
    if not data then return MEC.error(err) end
    sheet = { target = target }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'charge', open = true, data = data })
end

-- EX_Tii (Moe): the receipt for the car next to you goes to its owner (from the tablet's scan)
function MEC.openReceipt(veh)
    if sheet then return end
    if not MEC.onDuty() then return MEC.error('off_duty') end
    if not veh or not DoesEntityExist(veh) or not NetworkGetEntityIsNetworked(veh) then return MEC.error('no_car') end
    local data, err = lib.callback.await('exti_mechanic:server:receiptOpen', false, NetworkGetNetworkIdFromEntity(veh))
    if not data then return MEC.error(err) end
    sheet = { target = data.target.id, receipt = true }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'charge', open = true, data = data })
end

RegisterNUICallback('chargeIssue', function(data, cb)
    if not sheet or type(data) ~= 'table' then return cb({ ok = false, e = 'failed' }) end
    local ok, err = lib.callback.await('exti_mechanic:server:chargeIssue', false, sheet.target, data.ids, data.note, data.mode)
    if not ok then return cb({ ok = false, e = err or 'failed', text = MEC.ERRORS[err] or MEC.ERRORS.failed }) end
    if sheet then sheet.done = true end -- the person may be teleported away now: the sheet shows its card first
    MEC.notify('success', ('أُرسلت الفاتورة: $%d'):format(ok.fine or 0))
    cb({ ok = true, r = ok })
end)

RegisterNUICallback('chargeClose', function(_, cb)
    cb(true)
    close(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if sheet then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------------
-- the Z wheel: the workshop's slice (exti_radial asks for it)
---------------------------------------------------------------------------
local function closestPlayer(radius)
    local me = GetEntityCoords(cache.ped)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= cache.playerId then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                local d = #(me - GetEntityCoords(ped))
                if d <= radius and (not bestD or d < bestD) then best, bestD = GetPlayerServerId(pid), d end
            end
        end
    end
    return best
end

-- (the old Z-wheel bill: gone)

exports('RadialMenu', function()
    if not MEC.isCop() or cache.vehicle then return nil end
    local items = { { id = 'tablet', label = 'التابلت', icon = 'tablet-screen-button', action = 'event', arg = { name = 'exti_mechanic:client:tablet' } } }
    if not MEC.onDuty() then
        items[#items + 1] = { id = 'duty', label = 'ابدأ الدوام من الورشة', icon = 'wrench', disabled = true }
        return { label = 'الورشة', icon = 'wrench', items = items }
    end
    -- EX_Tii (Moe): no bill to whoever stands next to you. The bill (receipt) goes to the car's owner
    -- from the tablet: الفحص -> إرسال الإيصال للمالك.
    return { label = 'الورشة', icon = 'wrench', items = items }
end)
