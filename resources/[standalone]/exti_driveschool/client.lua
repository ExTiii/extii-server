-- =====================================================================
-- EX_Tii Driving School (client): the instructors, the screen (choose a licence, theory), and the
-- practical test: the school vehicle, the checkpoints, the speed limit, the damage check, the card
-- on screen. Car and truck follow the roads, the boat the coast, the helicopter the sky and lands.
-- =====================================================================

local S = GlobalState.exti_driveschool     -- { schools, order, licences } from the server
AddStateBagChangeHandler('exti_driveschool', 'global', function(_, _, v) if type(v) == 'table' then S = v end end)
CreateThread(function() while type(S) ~= 'table' do Wait(1000) S = GlobalState.exti_driveschool end end)

local ERR = {
    too_far = 'اقترب من المدرّب',
    busy = 'اختبارك جارٍ بالفعل',
    has = 'عندك هذه الرخصة بالفعل',
    suspended = 'هذه الرخصة مسحوبة من الشرطة، راجعهم أولًا',
    locked = 'تحتاج رخصة السيارات أولًا',
    wait = 'انتظر قليلًا قبل المحاولة التالية',
    no_money = 'ليس معك ما يكفي',
    timeout = 'انتهى وقت الاختبار النظري',
    nocar = 'لم تظهر مركبة المدرسة: أُعيد لك المبلغ، اضغط E عند المدرّب وابدأ من جديد',
    failed = 'حدث خطأ، حاول مرة أخرى',
}
local function notify(kind, text) lib.notify({ type = kind, description = text }) end
local function fail(code) notify('error', ERR[code] or ERR.failed) end

---------------------------------------------------------------------------
-- the instructors and the map icons
---------------------------------------------------------------------------
local peds, blips = {}, {}
local function clearPeds()
    for _, p in pairs(peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    peds, blips = {}, {}
end
local function placePeds()
    clearPeds()
    for _, id in ipairs(S.order or {}) do
        local s = S.schools[id]
        if s then
            local c = s.coords
            local model = joaat(s.ped)
            if pcall(lib.requestModel, model, 5000) then
                local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, false)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
                SetModelAsNoLongerNeeded(model)
                peds[id] = ped
            end
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, s.blip.sprite)
            SetBlipColour(b, s.blip.colour)
            SetBlipScale(b, s.blip.scale or 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(s.label)
            EndTextCommandSetBlipName(b)
            blips[id] = b
        end
    end
end
CreateThread(function()
    while type(S) ~= 'table' do Wait(500) end
    placePeds()
end)
AddStateBagChangeHandler('exti_driveschool', 'global', function() SetTimeout(300, function() if type(S) == 'table' then placePeds() end end) end)

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
local ui = { open = false, school = nil }
local test = nil -- { licence, cfg, netId, veh, route, index, faults, overSince, damage0, started, blips, landedSince }

local function closeUi(tellPage)
    if not ui.open then return end
    ui.open = false
    SetNuiFocus(false, false)
    if tellPage ~= false then SendNUIMessage({ action = 'close' }) end
end

local function openUi(schoolId)
    if ui.open or test then return end
    local data, err = lib.callback.await('exti_driveschool:server:open', false, schoolId)
    if not data then return fail(err) end
    ui.open = true
    ui.school = schoolId
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterNUICallback('close', function(_, cb) cb(true) closeUi(false) end)

RegisterNUICallback('start', function(data, cb)
    local res, err = lib.callback.await('exti_driveschool:server:start', false, ui.school, data and data.licence, data and data.account)
    if not res then return cb({ ok = false, text = ERR[err] or ERR.failed }) end
    cb({ ok = true, questions = res.questions, seconds = res.seconds, licence = res.licence })
end)

local function startDrive()
    local netId, k = lib.callback.await('exti_driveschool:server:car', false)
    if not netId then return fail(k) end
    local cfg = S.licences[k] and S.licences[k].test
    if not cfg then return fail('failed') end
    local okWait, veh = pcall(lib.waitFor, function()
        local e = NetworkGetEntityFromNetworkId(netId)
        if e ~= 0 and DoesEntityExist(e) then return e end
    end, 'vehicle', 8000)
    if not okWait or not veh then
        TriggerServerEvent('exti_driveschool:server:cancel')
        return fail('failed')
    end
    -- the route: cars and trucks snap to the roads; boats and helicopters fly / sail straight to the points
    local route = {}
    for _, p in ipairs(cfg.route or {}) do
        local v = vec3(p.x, p.y, p.z)
        if cfg.snapToRoad then
            local ok, node = GetClosestVehicleNode(v.x, v.y, v.z, 1, 3.0, 0)
            if ok then v = node end
        end
        route[#route + 1] = v
    end
    -- back to the start: the vehicle spot (the helicopter lands there)
    local home = GetEntityCoords(veh)
    if cfg.snapToRoad then
        local ok, node = GetClosestVehicleNode(home.x, home.y, home.z, 1, 3.0, 0)
        if ok then home = node end
    end
    route[#route + 1] = home
    test = { licence = k, cfg = cfg, netId = netId, veh = veh, route = route, index = 1, faults = 0, overSince = nil,
             started = GetGameTimer(), damage0 = GetVehicleBodyHealth(veh), blips = {}, landedSince = nil }
    SendNUIMessage({ action = 'drive', open = true, data = { licence = k, limit = cfg.speedLimit, faults = cfg.maxFaults, total = #route, landing = cfg.landing == true } })
end

RegisterNUICallback('theory', function(data, cb)
    local res, err = lib.callback.await('exti_driveschool:server:theory', false, data and data.answers)
    if not res then
        cb({ ok = false, text = ERR[err] or ERR.failed })
        closeUi()
        return
    end
    cb({ ok = true, passed = res.passed, right = res.right, total = res.total, need = res.need })
    if res.passed then
        SetTimeout(2400, function()
            closeUi()
            startDrive()
        end)
    end
end)

---------------------------------------------------------------------------
-- the practical test
---------------------------------------------------------------------------
local function marker(i)
    local t = test
    if not t then return end
    for _, b in ipairs(t.blips) do RemoveBlip(b) end
    t.blips = {}
    local p = t.route[i]
    if not p then return end
    local b = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(b, 1)
    SetBlipColour(b, 5)
    SetBlipRoute(b, t.cfg.snapToRoad == true)
    SetBlipRouteColour(b, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(i == #t.route and 'نقطة النهاية' or ('نقطة %d'):format(i))
    EndTextCommandSetBlipName(b)
    t.blips[1] = b
end

local function endDrive(passed, why)
    local t = test
    if not t then return end
    test = nil
    for _, b in ipairs(t.blips) do RemoveBlip(b) end
    SendNUIMessage({ action = 'drive', open = false })
    local res = lib.callback.await('exti_driveschool:server:drive', false, passed, why, { faults = t.faults })
    local label = S.licences[t.licence] and S.licences[t.licence].label or 'الرخصة'
    if res and res.passed then
        notify('success', ('مبروك! نجحت: %s الآن في سجلك والبطاقة في حقيبتك'):format(label))
        SendNUIMessage({ action = 'result', passed = true, licence = t.licence, label = label })
    else
        local texts = { speed = 'رسبت: تجاوزت السرعة كثيرًا', damage = 'رسبت: صدمت المركبة', left = 'رسبت: تركت المركبة', time = 'رسبت: انتهى الوقت', cancel = 'ألغيت الاختبار' }
        notify('error', texts[res and res.why or why] or texts.cancel)
        SendNUIMessage({ action = 'result', passed = false, why = res and res.why or why, licence = t.licence, label = label })
    end
end

-- the sky and the water: the vehicle's own markers (no road route to follow)
local function drawPoint(t)
    local p = t.route[t.index]
    if not p then return end
    if t.cfg.snapToRoad then return end
    local r = t.cfg.checkpointRadius or 10.0
    if t.cfg.landing and t.index == #t.route then
        DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2, r * 2, 2.0, 61, 220, 151, 110, false, false, 2, false, nil, nil, false)
    else
        DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r, r, r, 246, 200, 74, 70, false, false, 2, false, nil, nil, false)
    end
end

CreateThread(function()
    while true do
        if not test then Wait(500) else
            local t = test
            local veh, cfg = t.veh, t.cfg
            if not DoesEntityExist(veh) then endDrive(false, 'cancel')
            elseif cache.vehicle ~= veh then
                -- out of the vehicle: a few seconds to get back in
                t.outSince = t.outSince or GetGameTimer()
                if GetGameTimer() - t.outSince > 8000 then endDrive(false, 'left') end
                Wait(200)
            else
                t.outSince = nil
                local p = GetEntityCoords(veh)
                local target = t.route[t.index]
                local kmh = GetEntitySpeed(veh) * 3.6
                -- speed (cars and trucks)
                local over = false
                if cfg.speedLimit then
                    over = kmh > cfg.speedLimit + 3
                    local wayOver = kmh > cfg.speedLimit + (cfg.speedInstant or 25)
                    if over then
                        t.overSince = t.overSince or GetGameTimer()
                        local grace = (cfg.speedGrace or 3) * 1000
                        if (GetGameTimer() - t.overSince > grace) or (wayOver and GetGameTimer() >= t.overSince) then
                            t.faults = t.faults + 1
                            t.overSince = GetGameTimer() + 3000 -- a pause before the next one counts
                            notify('error', ('مخالفة سرعة %d / %d · الحد %d كم/س'):format(t.faults, cfg.maxFaults, cfg.speedLimit))
                            PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                            if t.faults > cfg.maxFaults then endDrive(false, 'speed') goto continue end
                        end
                    else
                        t.overSince = nil
                    end
                end
                -- damage
                local dmg = t.damage0 - GetVehicleBodyHealth(veh)
                if dmg > cfg.maxDamage or GetVehicleEngineHealth(veh) < 600 then endDrive(false, 'damage') goto continue end
                -- time
                local leftMs = cfg.timeLimitMinutes * 60000 - (GetGameTimer() - t.started)
                if leftMs < 0 then endDrive(false, 'time') goto continue end
                -- the checkpoint
                local d = target and #(p - target) or 0
                if target and d < (cfg.checkpointRadius or 9.0) then
                    local last = t.index == #t.route
                    if last and cfg.landing then
                        -- the helicopter has to land and stop on the pad
                        if not IsEntityInAir(veh) and kmh < 3 then
                            t.landedSince = t.landedSince or GetGameTimer()
                            if GetGameTimer() - t.landedSince > 2000 then endDrive(true) goto continue end
                        else
                            t.landedSince = nil
                        end
                    else
                        PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
                        t.index = t.index + 1
                        if t.index > #t.route then endDrive(true) goto continue end
                        marker(t.index)
                    end
                end
                drawPoint(t)
                if (GetGameTimer() - (t.lastHud or 0)) > 200 then
                    t.lastHud = GetGameTimer()
                    local hint
                    if cfg.landing and t.index == #t.route then hint = 'landing'
                    elseif cfg.snapToRoad then hint = 'road'
                    else hint = 'free' end
                    SendNUIMessage({ action = 'hud', data = { kmh = math.floor(kmh), over = over, faults = t.faults, index = t.index, total = #t.route, dist = math.floor(d),
                        damage = math.floor(math.max(0, dmg)), maxDamage = cfg.maxDamage, left = math.max(0, math.floor(leftMs / 1000)), alt = math.floor(p.z), hint = hint,
                        overFor = (over and t.overSince and GetGameTimer() > t.overSince) and math.floor((GetGameTimer() - t.overSince) / 1000) or 0 } })
                end
                Wait(cfg.snapToRoad and 200 or 0)
            end
        end
        ::continue::
    end
end)

-- the first checkpoint once the vehicle is there
CreateThread(function()
    while true do
        Wait(250)
        if test and not test.blips[1] then marker(1) end
    end
end)

-- E at an instructor; /giveup during the test
CreateThread(function()
    while true do
        local sleep = 800
        if type(S) == 'table' and not ui.open and not test and not cache.vehicle and not IsNuiFocused() then
            local me = GetEntityCoords(cache.ped)
            local nearId, nearD
            for _, id in ipairs(S.order or {}) do
                local s = S.schools[id]
                if s then
                    local d = #(me - vec3(s.coords.x, s.coords.y, s.coords.z))
                    if d < 12.0 then sleep = 0 end
                    if d < 2.2 and (not nearD or d < nearD) then nearId, nearD = id, d end
                end
            end
            if nearId then
                lib.showTextUI(('[E] %s'):format(S.schools[nearId].label))
                if (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then
                    lib.hideTextUI()
                    openUi(nearId)
                end
            else
                lib.hideTextUI()
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('giveup', function()
    if test then
        TriggerServerEvent('exti_driveschool:server:cancel')
        endDrive(false, 'cancel')
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    if ui.open then SetNuiFocus(false, false) end
    clearPeds()
    if test then for _, b in ipairs(test.blips) do RemoveBlip(b) end end
    lib.hideTextUI()
end)
