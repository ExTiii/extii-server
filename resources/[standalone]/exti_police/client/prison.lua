-- =====================================================================
-- EX_Tii Police (client): the prison.
-- The officer: the intake circle at the gate (E with the cuffed person next to you opens the
-- charge sheet with the سجن buttons). The prisoner: the uniform, the time card on screen, the
-- yard jobs that cut the time, no vehicles, and the escape check.
-- =====================================================================

local P = Config.prison

local PRISON_ERRORS = {
    not_at_prison = 'السجن يكون عند بوابة بولينغبروك فقط: خذه إلى هناك',
    no_jail = 'هذه المخالفات بلا سجن',
    not_inmate = 'أنت لست سجينًا',
}
for k, v in pairs(PRISON_ERRORS) do POL.ERRORS[k] = v end

-- the spots (config.lua + what admins moved), from the server
local prison = GlobalState.exti_police_prison
local function readPrison(value)
    if type(value) ~= 'table' then return end
    prison = value
end
AddStateBagChangeHandler('exti_police_prison', 'global', function(_, _, value) readPrison(value) end)
CreateThread(function()
    while type(prison) ~= 'table' do
        Wait(1000)
        prison = GlobalState.exti_police_prison
    end
end)

local function toVec3(v) return vec3(v.x, v.y, v.z) end

-- the prison on the map (everyone sees it: it is Bolingbroke)
local prisonBlip
local function placeBlip()
    if prisonBlip and DoesBlipExist(prisonBlip) then RemoveBlip(prisonBlip) end
    local c = toVec3(prison.intake)
    prisonBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(prisonBlip, 188)
    SetBlipColour(prisonBlip, 4)
    SetBlipScale(prisonBlip, 0.765)
    SetBlipAsShortRange(prisonBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('سجن بولينغبروك')
    EndTextCommandSetBlipName(prisonBlip)
end
CreateThread(function()
    while type(prison) ~= 'table' do Wait(500) end
    placeBlip()
end)
AddStateBagChangeHandler('exti_police_prison', 'global', function() SetTimeout(200, function() if type(prison) == 'table' then placeBlip() end end) end)

---------------------------------------------------------------------------
-- being inside
---------------------------------------------------------------------------
local jailed = nil   -- { remaining, minutes, escaped, since = GetGameTimer() }
local workBusy = false

local function remainingNow()
    if not jailed then return 0 end
    if jailed.escaped then return jailed.remaining end
    return math.max(0, jailed.remaining - math.floor((GetGameTimer() - jailed.since) / 1000))
end

local function wearUniform()
    local ped = cache.ped
    local female = GetEntityModel(ped) == `mp_f_freemode_01`
    for _, c in ipairs(P.uniform[female and 'female' or 'male'] or {}) do
        SetPedComponentVariation(ped, c[1], c[2], c[3], 0)
    end
    for _, prop in ipairs({ 0, 1, 2, 6, 7 }) do ClearPedProp(ped, prop) end
end

local function ownClothes()
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

local teleporting = false
local function teleport(to, heading)
    if teleporting then return end
    teleporting = true
    DoScreenFadeOut(400)
    Wait(450)
    local ped = cache.ped
    -- still attached to the officer / sitting in his car: let go first
    if IsEntityAttachedToAnyPed(ped) then DetachEntity(ped, true, false) end
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        local t0 = GetGameTimer()
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() - t0 < 1500 do Wait(50) end
        if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
    end
    SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
    Wait(300)
    DoScreenFadeIn(500)
    teleporting = false
end

local function uniformOn()
    local ped = cache.ped
    local female = GetEntityModel(ped) == `mp_f_freemode_01`
    local top = (P.uniform[female and 'female' or 'male'] or {})[1]
    return top and GetPedDrawableVariation(ped, top[1]) == top[2]
end

local function hud(show)
    SendNUIMessage({ action = 'prison', open = show, data = show and { remaining = remainingNow(), minutes = jailed.minutes, escaped = jailed.escaped } or nil })
end

-- the time card once a second, the escape check, no cars
local function insideLoop()
    CreateThread(function()
        local awaySince = nil
        while jailed do
            local p = GetEntityCoords(cache.ped)
            local outside = prison and #(p - toVec3(prison.center)) > (prison.radius or P.radius)
            -- prison is prison: outside the grounds (walked, brought, teleported) = back in the cell now
            if outside and not teleporting and not IsEntityDead(cache.ped) then
                jailed.escaped = false
                local sp = prison and prison.spawn or P.spawn
                teleport(sp, sp.w)
                TriggerServerEvent('exti_police:server:prisonAway', true)
                POL.notify('error', 'لا يمكنك مغادرة السجن قبل انتهاء مدتك')
            end
            hud(true)
            Wait(1000)
        end
    end)
    CreateThread(function()
        while jailed do
            if not LocalPlayer.state.cuffed then -- an officer may still move a cuffed inmate by car
                DisableControlAction(0, 23, true) -- enter vehicle
                DisableControlAction(0, 75, true) -- exit vehicle (keeps F from doing odd things)
                if cache.vehicle and not jailed.escaped and not teleporting then
                    TaskLeaveVehicle(cache.ped, cache.vehicle, 16)
                end
            end
            Wait(0)
        end
    end)
    -- the uniform stays on (a respawn or a skin reload puts his own clothes back)
    CreateThread(function()
        while jailed do
            Wait(5000)
            if jailed and not jailed.escaped and not teleporting and not uniformOn() then wearUniform() end
        end
    end)
end

RegisterNetEvent('exti_police:client:jailed', function(data)
    if type(data) ~= 'table' then return end
    local first = jailed == nil
    jailed = { remaining = data.remaining or 0, minutes = data.minutes or 0, escaped = data.escaped == true, since = GetGameTimer() }
    if first then
        -- into the cells, in uniform
        local sp = prison and prison.spawn or P.spawn
        teleport(sp, sp.w)
        wearUniform()
        pcall(function() exports.ox_inventory:closeInventory() end)
        POL.notify('warning', ('أنت في السجن: %d دقيقة. اعمل في الساحة لتقليل المدة'):format(math.ceil(jailed.remaining / 60)))
        insideLoop()
    else
        -- the server tells us again (after a death, a restart, coming back from an escape): back into
        -- the cells when we are away from them, and the uniform on again
        local sp = prison and prison.spawn or P.spawn
        local p = GetEntityCoords(cache.ped)
        if not jailed.escaped and #(p - toVec3(sp)) > 50.0 then teleport(sp, sp.w) end
        wearUniform()
    end
    hud(true)
end)

RegisterNetEvent('exti_police:client:released', function(why)
    if not jailed then return end
    jailed = nil
    workBusy = false
    if POL.prompt then POL.prompt(nil) end
    hud(false)
    local out = prison and prison.release or P.release
    teleport(out, out.w)
    ownClothes()
    POL.notify('success', why == 'admin' and 'أطلقت الإدارة سراحك' or why == 'officer' and 'أطلقت الشرطة سراحك' or 'انتهت مدتك: أنت حر')
end)

-- a new body (respawn) keeps the uniform
lib.onCache('ped', function()
    if jailed then SetTimeout(1500, function() if jailed then wearUniform() end end) end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    jailed = nil
    hud(false)
end)

-- still inside after a script restart
CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.injail and not jailed then
        local s = lib.callback.await('exti_police:server:prisonStatus', false)
        if s then
            jailed = { remaining = s.remaining, minutes = s.minutes, escaped = s.escaped, since = GetGameTimer() }
            wearUniform()
            insideLoop()
        end
    end
end)

---------------------------------------------------------------------------
-- the yard jobs
---------------------------------------------------------------------------
local function doWork(w, index)
    if workBusy or not jailed then return end
    workBusy = true
    local ok = lib.progressBar({
        duration = (w.seconds or 10) * 1000, label = w.label, useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { scenario = w.scenario },
    })
    ClearPedTasks(cache.ped)
    if ok then
        local res, err = lib.callback.await('exti_police:server:prisonWork', false, w.id, index)
        if not res then
            POL.error(err)
        elseif not res.released and jailed then
            jailed.remaining, jailed.since = res.remaining, GetGameTimer()
            POL.notify('success', ('-%d دقيقة · باقي %d دقيقة'):format(w.minutes, math.ceil(res.remaining / 60)))
            hud(true)
        end
    end
    workBusy = false
end

---------------------------------------------------------------------------
-- the circles and the E texts (the main loop in client/main.lua asks for them)
---------------------------------------------------------------------------
local GOLD = { 32, 201, 151 }
local WHITE = { 255, 255, 255 }
local DRAW = 25.0

local function drawCircle(c, size, color, bright)
    local alpha = bright and 210 or 140
    DrawMarker(1, c.x, c.y, c.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.3, color[1], color[2], color[3], alpha, false, false, 2, false, nil, nil, false)
end

-- what is drawn this frame
local near = {}
CreateThread(function()
    while true do
        local list = {}
        if prison and not POL.isDown() then
            local p = GetEntityCoords(cache.ped)
            if jailed then
                for _, w in ipairs(prison.works or {}) do
                    for i, s in ipairs(w.spots or {}) do
                        local c = toVec3(s)
                        if #(p - c) < DRAW then list[#list + 1] = { coords = c, work = w, index = i, reach = 2.0, size = 1.1, color = GOLD } end
                    end
                end
            elseif POL.onDuty() then
                local c = toVec3(prison.intake)
                if #(p - c) < DRAW then list[#list + 1] = { coords = c, intake = true, reach = prison.intakeRadius or P.intakeRadius, size = (prison.intakeRadius or P.intakeRadius) * 2, color = WHITE } end
            end
        end
        near = list
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if #near == 0 then
            Wait(500)
        else
            local p = GetEntityCoords(cache.ped)
            for i = 1, #near do
                local s = near[i]
                drawCircle(s.coords, s.size, s.color, #(p - s.coords) < s.reach)
            end
            Wait(0)
        end
    end
end)

-- the text and the action for the E loop
function POL.prisonPrompt(p)
    if cache.vehicle or workBusy then return nil end
    for i = 1, #near do
        local s = near[i]
        if #(p - s.coords) < s.reach then
            if s.intake then
                local target = POL.closestCuffedPlayer and POL.closestCuffedPlayer() or nil
                if not target then return 'بوابة السجن: قيّد الشخص وقف معه هنا', nil end
                return '[E] تسليم السجين', function() POL.openCharge(target) end
            elseif s.work and jailed then
                return ('[E] %s · -%d دقيقة'):format(s.work.label, s.work.minutes), function() doWork(s.work, s.index) end
            end
        end
    end
    return nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if jailed then hud(false) end
    if prisonBlip and DoesBlipExist(prisonBlip) then RemoveBlip(prisonBlip) end
end)
