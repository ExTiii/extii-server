-- =====================================================================
-- EX_Tii gangs (game side): car theft -> the police.
--   * the car keys script reports its attempts here (its config calls exti_gangs:client:theftAttempt):
--     we add "did an NPC see it" and send it to the server, which decides about the alert
--   * the police see the GPS tracker of a stolen fast car live on the map
--   * the thief can pull the tracker out (under the back of the car)
-- =====================================================================
local T = C.theft

local function isCop()
    local j = QBX and QBX.PlayerData and QBX.PlayerData.job
    return j ~= nil and j.name == 'police' and j.onduty == true
end

-- an NPC close by, alive, looking at me
local function witnessSaw()
    local me = PlayerPedId()
    local here = GetEntityCoords(me)
    for _, p in ipairs(GetGamePool('CPed')) do
        if p ~= me and not IsPedAPlayer(p) and IsPedHuman(p) and not IsPedDeadOrDying(p, true)
            and #(GetEntityCoords(p) - here) < T.witnessRadius and HasEntityClearLosToEntityInFront(p, me) then
            return true
        end
    end
    return false
end
lib.callback.register('exti_gangs:client:witness', function() return witnessSaw() end)
GC.witnessSaw = witnessSaw

-- from the car keys script (a local event: nothing outside this game can send it)
AddEventHandler('exti_gangs:client:theftAttempt', function(crime, vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    TriggerServerEvent('exti_gangs:server:theftAttempt', crime, NetworkGetNetworkIdFromEntity(vehicle), witnessSaw())
end)

---------------------------------------------------------------------------
-- the police: GPS tracker blips
---------------------------------------------------------------------------
local tblips = {}   -- [id] = { blip, seen }

local function dropBlip(id)
    local b = tblips[id]
    if b and DoesBlipExist(b.blip) then RemoveBlip(b.blip) end
    tblips[id] = nil
end

RegisterNetEvent('exti_gangs:client:tracker', function(id, c, label, left)
    local b = tblips[id]
    if not b then
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.9)
        SetBlipFlashes(blip, true)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('متتبع GPS: ' .. tostring(label))
        EndTextCommandSetBlipName(blip)
        b = { blip = blip }
        tblips[id] = b
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
        lib.notify({ title = 'متتبع GPS', description = ('سيارة مسروقة عليها متتبع: %s · تظهر على الخريطة %d ثانية'):format(label, left or 0),
                     type = 'inform', position = 'top', duration = 8000 })
    else
        SetBlipCoords(b.blip, c.x, c.y, c.z)
    end
    b.seen = GetGameTimer()
end)

RegisterNetEvent('exti_gangs:client:trackerEnd', function(id, why)
    if not tblips[id] then return end
    dropBlip(id)
    lib.notify({ title = 'متتبع GPS', description = why == 'pulled' and 'انقطعت إشارة المتتبع: السارق نزعه' or 'انتهت إشارة المتتبع',
                 type = 'inform', position = 'top' })
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for id, b in pairs(tblips) do if now - (b.seen or 0) > 15000 then dropBlip(id) end end
    end
end)

---------------------------------------------------------------------------
-- the thief: pull the tracker out
---------------------------------------------------------------------------
local pulling = false
local function pull(veh)
    pulling = true
    lib.hideTextUI()
    local ok, seconds = lib.callback.await('exti_gangs:server:pullBegin', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then pulling = false; return end
    local done = lib.progressBar({
        duration = seconds * 1000, label = 'تبحث عن المتتبع تحت السيارة...', canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@world_human_vehicle_mechanic@male@base', clip = 'base', flag = 1 },
    })
    local passed = done and lib.skillCheck({ 'medium', 'medium', 'hard' }, { 'e' }) or false
    ClearPedTasks(PlayerPedId())
    if not done then pulling = false; return GC.notify('أُلغيت', 'error') end
    local fin, why = lib.callback.await('exti_gangs:server:pullFinish', false, passed)
    if fin then GC.notify('نزعت المتتبع: الشرطة لم تعد ترى السيارة', 'success')
    else GC.notify(why == 'skill' and 'انزلقت يدك: حاول من جديد' or 'لم تنجح', 'error') end
    pulling = false
end

-- look for a tracked car every half second; only the [E] key is read every frame
local PULL_TEXT = '[E] انزع متتبع GPS'
local target = nil
CreateThread(function()
    while true do
        Wait(500)
        local found = nil
        local ped = PlayerPedId()
        if not pulling and not IsPedInAnyVehicle(ped, false) and not isCop() then
            local here = GetEntityCoords(ped)
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if Entity(veh).state.exti_tracker and #(GetEntityCoords(veh) - here) < 3.5 then found = veh break end
            end
        end
        target = found
    end
end)

CreateThread(function()
    local shown = false
    while true do
        if target and not pulling then
            local open, text = lib.isTextUIOpen()
            if not shown and not open then lib.showTextUI(PULL_TEXT, { position = 'left-center' }); shown = true end
            if IsControlJustReleased(0, 38) and shown then
                lib.hideTextUI(); shown = false
                pull(target)
            end
            Wait(0)
        else
            if shown then
                local open, text = lib.isTextUIOpen()
                if open and text == PULL_TEXT then lib.hideTextUI() end
                shown = false
            end
            Wait(300)
        end
    end
end)
