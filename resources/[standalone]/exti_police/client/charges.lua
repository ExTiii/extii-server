-- =====================================================================
-- EX_Tii Police (client): the charge sheet. From the Z wheel (الشرطة → مخالفة) next to a person:
-- the officer ticks the offences, writes a note, and the fine goes to the person's bank as a bill.
-- =====================================================================

local S = Config.street

local CHARGE_ERRORS = {
    pick = 'اختر مخالفة واحدة على الأقل',
    too_many = 'عدد المخالفات في المحضر الواحد كبير',
    no_fine = 'هذه المخالفات بلا غرامة',
    no_bank = 'البنك لا يعمل الآن، حاول بعد قليل',
    soon = 'السجن يأتي في التحديث القادم',
    wait = 'انتظر لحظة',
}
for k, v in pairs(CHARGE_ERRORS) do POL.ERRORS[k] = v end

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
        if sheet and not sheet.done then
            local pid = GetPlayerFromServerId(sheet.target)
            local ped = pid ~= -1 and GetPlayerPed(pid) or 0
            if not POL.onDuty() or POL.isDown() or ped == 0
                or #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > S.reach + 3.0 then
                close()
            end
        end
        Wait(sheet and 500 or 1500)
    end
end)

function POL.openCharge(target)
    if sheet then return end
    if not POL.onDuty() then return POL.error('off_duty') end
    local data, err = lib.callback.await('exti_police:server:chargeOpen', false, target)
    if not data then return POL.error(err) end
    sheet = { target = target }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'charge', open = true, data = data })
end

RegisterNUICallback('chargeIssue', function(data, cb)
    if not sheet or type(data) ~= 'table' then return cb({ ok = false, e = 'failed' }) end
    local ok, err = lib.callback.await('exti_police:server:chargeIssue', false, sheet.target, data.ids, data.note, data.mode)
    if not ok then return cb({ ok = false, e = err or 'failed', text = POL.ERRORS[err] or POL.ERRORS.failed }) end
    if sheet then sheet.done = true end -- the person may be teleported away now: the sheet shows its card first
    POL.notify('success', ok.jailed and ('تم السجن: %d دقيقة'):format(ok.jail or 0) or ('تم تحرير المخالفة: $%d'):format(ok.fine or 0))
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
