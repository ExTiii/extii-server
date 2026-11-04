-- =====================================================================
-- EX_Tii heists (game side): the negotiator's phone call. The server runs the talk (server/negotiate.lua);
-- this shows the call box and reads the keys 1-4 while answers are on the screen. No mouse: you keep
-- moving and aiming. While you answer, keys 1-4 don't use your inventory slots.
-- =====================================================================
local KEYS = { 157, 158, 160, 164 }   -- 1 2 3 4 (the number row)
local nOpts = 0
local keysOff = false
HC.negActive = false

local function hotkeys(off)
    if off == keysOff then return end
    keysOff = off
    LocalPlayer.state:set('invHotkeys', not off, false)
end

RegisterNetEvent('exti_heists:client:negRing', function()
    HC.negActive = true
    SendNUIMessage({ action = 'call', ring = true })
    PlaySoundFrontend(-1, 'Remote_Ring', 'Phone_SoundSet_Michael', true)
    SetTimeout(1300, function() PlaySoundFrontend(-1, 'Remote_Ring', 'Phone_SoundSet_Michael', true) end)
end)

RegisterNetEvent('exti_heists:client:negCall', function(p)
    if type(p) ~= 'table' then return end
    HC.negActive = true
    p.action = 'call'
    SendNUIMessage(p)
    if p.say and not p.typing then PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true) end
    nOpts = type(p.opts) == 'table' and #p.opts or (p.typing and 0 or nOpts)
    if p.close and p.close > 0 then
        nOpts = 0
        SetTimeout(p.close * 1000, function() if nOpts == 0 then hotkeys(false) end end)
    end
end)

-- the response is over: put the phone away
AddEventHandler('exti_heists:client:npcEnd', function()
    HC.negActive, nOpts = false, 0
    hotkeys(false)
    SendNUIMessage({ action = 'call', hide = true })
end)

CreateThread(function()
    while true do
        if nOpts > 0 then
            hotkeys(true)
            for i = 1, math.min(nOpts, #KEYS) do
                DisableControlAction(0, KEYS[i], true)
                if IsDisabledControlJustReleased(0, KEYS[i]) then
                    nOpts = 0
                    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
                    TriggerServerEvent('exti_heists:server:negPick', i)
                    break
                end
            end
            Wait(0)
        else
            if keysOff then hotkeys(false) end
            Wait(250)
        end
    end
end)

-- Z wheel: pick the call up again
function HC.negItem()
    if not HC.negActive then return nil end
    return { id = 'negotiator', label = 'المفاوض', icon = 'phone', action = 'event', arg = { name = 'exti_heists:client:negReopen', data = {} } }
end
AddEventHandler('exti_heists:client:negReopen', function() TriggerServerEvent('exti_heists:server:negReopen') end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and keysOff then LocalPlayer.state:set('invHotkeys', true, false) end
end)
