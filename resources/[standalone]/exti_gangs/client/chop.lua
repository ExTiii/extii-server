-- =====================================================================
-- EX_Tii gangs: the Chop Shop work in the HQ garage (game side).
--   Look at the car -> [E] check it -> start -> 4 stages of real work, each part with its own mini game:
--     1 doors        unscrew the hinge bolts (hold on each bolt)       -> the door comes off
--     2 wheels       loosen the lug nuts in a star pattern            -> the wheel comes off
--     3 hood, trunk  pry it open with the bar (hit the green zone)    -> it comes off
--     4 frame        cut along the line with the torch                -> the car is gone
--   The server checks every stage and its time; the game only shows the work.
-- =====================================================================
local chopping = nil      -- { veh, stage }
local gameP = nil

local DOORS = { { i = 0, bone = 'door_dside_f', name = 'الباب الأمامي الأيسر' }, { i = 1, bone = 'door_pside_f', name = 'الباب الأمامي الأيمن' },
                { i = 2, bone = 'door_dside_r', name = 'الباب الخلفي الأيسر' }, { i = 3, bone = 'door_pside_r', name = 'الباب الخلفي الأيمن' } }
local WHEELS = { { i = 0, bone = 'wheel_lf', name = 'العجلة الأمامية اليسرى' }, { i = 1, bone = 'wheel_rf', name = 'العجلة الأمامية اليمنى' },
                 { i = 4, bone = 'wheel_lr', name = 'العجلة الخلفية اليسرى' }, { i = 5, bone = 'wheel_rr', name = 'العجلة الخلفية اليمنى' } }
local LIDS = { { i = 4, bone = 'bonnet', name = 'غطاء المحرك' }, { i = 5, bone = 'boot', name = 'صندوق السيارة' } }
local STAGES = { 'فكّ الأبواب', 'فكّ العجلات', 'غطاء المحرك والصندوق', 'قصّ الهيكل' }

RegisterNUICallback('chopgame', function(req, cb)
    SetNuiFocus(false, false)
    local p = gameP; gameP = nil
    if p then p:resolve(req and req.done == true) end
    cb(true)
end)

local function minigame(game, title, extra)
    if gameP then local old = gameP; gameP = nil; old:resolve(false) end   -- a game still open: it counts as stopped
    gameP = promise.new()
    SendNUIMessage({ action = 'chopgame', game = game, title = title, extra = extra })
    SetNuiFocus(true, true)
    return Citizen.Await(gameP)
end

GC.minigame = minigame

local function control(veh)
    local t = GetGameTimer()
    NetworkRequestControlOfEntity(veh)
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 2000 do Wait(20); NetworkRequestControlOfEntity(veh) end
    return NetworkHasControlOfEntity(veh)
end

local function bonePos(veh, bone)
    local idx = GetEntityBoneIndexByName(veh, bone)
    if idx == -1 then return nil end
    return GetWorldPositionOfEntityBone(veh, idx)
end

-- walk to a part: a marker on it, [E] there, [G] to stop the chop
local function goTo(veh, pos, label)
    while true do
        if not DoesEntityExist(veh) then return false end
        local d = #(GetEntityCoords(PlayerPedId()) - pos)
        DrawMarker(0, pos.x, pos.y, pos.z + 0.55, 0, 0, 0, 0, 0, 0, 0.22, 0.22, 0.22, 232, 181, 71, 190, true, true, 2, false, nil, nil, false)
        if d < 1.4 then
            lib.showTextUI(('[E] %s   ·   [G] إيقاف'):format(label), { position = 'left-center' })
            if IsControlJustReleased(0, 38) then lib.hideTextUI(); return true end
        else
            lib.showTextUI(('اذهب إلى: %s   ·   [G] إيقاف'):format(label), { position = 'left-center' })
        end
        if IsControlJustReleased(0, 47) then lib.hideTextUI(); return false end
        Wait(0)
    end
end

local function face(veh, pos)
    local here = GetEntityCoords(PlayerPedId())
    SetEntityHeading(PlayerPedId(), GetHeadingFromVector_2d(pos.x - here.x, pos.y - here.y))
end

local function playAnim(dict, clip, flag)
    lib.requestAnimDict(dict)
    TaskPlayAnim(PlayerPedId(), dict, clip, 3.0, 3.0, -1, flag or 1, 0, false, false, false)
end

-- one part: walk there, play the mini game, take the part off
local function part(veh, p, game, title, anim, takeOff)
    local pos = bonePos(veh, p.bone)
    if not pos then return true end -- the car hasn't got this part
    if not goTo(veh, pos, p.name) then return false end
    face(veh, pos)
    playAnim(anim[1], anim[2], anim[3])
    local done = minigame(game, title .. ' · ' .. p.name)
    ClearPedTasks(PlayerPedId())
    if not done then return false end
    if control(veh) then takeOff() end
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    return true
end

-- the server wants each stage to last at least this long: finish the rest with a progress bar
local function padTo(startedAt, seconds, label)
    local left = seconds - (GetGameTimer() - startedAt) / 1000
    if left <= 0.5 then return true end
    return lib.progressBar({
        duration = math.floor(left * 1000), label = label, canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },
    })
end

local function stop(veh)
    lib.hideTextUI()
    ClearPedTasks(PlayerPedId())
    lib.callback.await('exti_gangs:server:chopCancel', false)
    chopping = nil
    GC.notify('توقف التفكيك (الأدوات المستعملة ضاعت)', 'error')
end

local function runChop(veh, stageSeconds)
    chopping = { veh = veh, stage = 0 }
    local need = math.floor(stageSeconds * 0.85) + 2
    for stage = 1, 4 do
        local t0 = GetGameTimer()
        GC.notify(('المرحلة %d من 4: %s'):format(stage, STAGES[stage]), 'inform', 4000)
        local ok = true
        if stage == 1 then
            for _, d in ipairs(DOORS) do
                if GetIsDoorValid(veh, d.i) and not IsVehicleDoorDamaged(veh, d.i) then
                    ok = part(veh, d, 'bolts', 'فكّ براغي المفصلات', { 'mini@repair', 'fixing_a_ped', 1 }, function() SetVehicleDoorBroken(veh, d.i, true) end)
                    if not ok then break end
                end
            end
        elseif stage == 2 then
            for _, w in ipairs(WHEELS) do
                ok = part(veh, w, 'lugnuts', 'فكّ صواميل العجلة', { 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1 }, function()
                    SetVehicleTyreBurst(veh, w.i, true, 1000.0)
                    BreakOffVehicleWheel(veh, w.i, false, true, true, false)
                end)
                if not ok then break end
            end
        elseif stage == 3 then
            for _, l in ipairs(LIDS) do
                if GetIsDoorValid(veh, l.i) and not IsVehicleDoorDamaged(veh, l.i) then
                    ok = part(veh, l, 'pry', 'اخلع بالعتلة', { 'mini@repair', 'fixing_a_ped', 1 }, function() SetVehicleDoorBroken(veh, l.i, true) end)
                    if not ok then break end
                end
            end
        else
            local c = GetEntityCoords(veh)
            ok = goTo(veh, c + vec3(0, 0, 0.2), 'قصّ الهيكل بالشعلة')
            if ok then
                TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_WELDING', 0, true)
                ok = minigame('torch', 'قصّ الهيكل بالشعلة')
                ClearPedTasks(PlayerPedId())
            end
        end
        if not ok then return stop(veh) end
        if not padTo(t0, need, ('تجمع القطع وتنظّف المكان... (%d/4)'):format(stage)) then return stop(veh) end
        local done, res = lib.callback.await('exti_gangs:server:chopStage', false, stage)
        if not done then
            if res == 'fast' then
                -- the server wants a little more time: wait and send it again
                Wait(3000)
                done, res = lib.callback.await('exti_gangs:server:chopStage', false, stage)
            end
            if not done then return stop(veh) end
        end
        chopping.stage = stage
        if stage == 4 then
            chopping = nil
            local r = res
            PlaySoundFrontend(-1, 'Bus_Schedule_Pickup', 'DLC_PRISON_BREAK_HEIST_SOUNDS', false)
            GC.notify(('انتهى التفكيك! $%d مال غير نظيف (العصابة $%d)%s'):format(r.money, r.gang, r.wanted and ' · سيارة مطلوبة +30%' or ''), 'success', 9000)
            if r.mine > 0 then GC.notify(('حصّتك: $%d مال غير نظيف في حقيبتك'):format(r.mine), 'success', 8000) end
            GC.notify(('%d مفاتيح فتح%s إلى المخزن'):format(r.lockpicks, r.c4 > 0 and ' + C4' or ''), 'inform', 8000)
        end
    end
end

---------------------------------------------------------------------------
-- the garage prompt: a parked car inside the chop garage
---------------------------------------------------------------------------
local function nearestCar(center, radius)
    local ped = PlayerPedId()
    local here = GetEntityCoords(ped)
    local best, bd = nil, 3.5
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - center) <= radius then
            local d = #(GetEntityCoords(veh) - here)
            if d < bd and IsVehicleSeatFree(veh, -1) then best, bd = veh, d end
        end
    end
    return best
end

local function startChop(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local class = GetVehicleClass(veh)
    local ok, info = lib.callback.await('exti_gangs:server:chopPreview', false, netId, class)
    if not ok then return GC.notify(info, 'error') end
    local lines = {
        ('**الفئة:** %s'):format(info.tier),
        ('**أدوات التفكيك:** %d من المخزن'):format(info.tools),
        ('**الوقت:** حوالي %d دقائق'):format(info.minutes),
        ('**المال غير النظيف:** $%d – $%d'):format(info.money[1], info.money[2]),
    }
    if info.wanted then lines[#lines + 1] = '**سيارة مطلوبة اليوم: +30%**' end
    if info.owned then lines[#lines + 1] = 'هذه سيارة لاعب: تذهب لساحة الحجز ويدفع صاحبها رسوم الاسترجاع.' end
    local answer = lib.alertDialog({ header = 'تفكيك السيارة؟', content = table.concat(lines, '  \n'), centered = true, cancel = true, labels = { confirm = 'ابدأ', cancel = 'لا' } })
    if answer ~= 'confirm' then return end
    local started, res = lib.callback.await('exti_gangs:server:chopStart', false, netId, class)
    if not started then return GC.notify(res, 'error') end
    runChop(veh, res.stageSeconds)
end

local promptOn = false
local function prompt(text)
    if text then lib.showTextUI(text, { position = 'left-center' }); promptOn = true
    elseif promptOn then lib.hideTextUI(); promptOn = false end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local my = GC.my()
        local hq = my and my.type == 'chop' and my.rank >= 1 and GC.spots().hq and GC.spots().hq[my.name]
        local garage = hq and hq.garage
        if garage and not chopping then
            local center = vec3(garage.x, garage.y, garage.z)
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - center) < C.chop.garageRadius + 4.0 then
                sleep = 0
                DrawMarker(1, center.x, center.y, center.z - 1.0, 0, 0, 0, 0, 0, 0, C.chop.garageRadius * 2, C.chop.garageRadius * 2, 0.4, 232, 181, 71, 35, false, false, 2, false, nil, nil, false)
                if not IsPedInAnyVehicle(ped, false) then
                    local veh = nearestCar(center, C.chop.garageRadius)
                    if veh then
                        prompt('[E] افحص السيارة للتفكيك')
                        if IsControlJustReleased(0, 38) then prompt(nil); startChop(veh) end
                    else
                        prompt(nil)
                    end
                else
                    prompt(nil)
                end
            end
        end
        if sleep > 0 then prompt(nil) end
        Wait(sleep)
    end
end)

-- the admin panel's test button: play any minigame straight away (nothing is given or taken)
exports('TestMinigame', function(game)
    CreateThread(function()
        local done = minigame(game, 'تجربة: ' .. tostring(game), { stacks = 3, bags = 6, label = 'لوحة الإدارة' })
        lib.notify({ description = done and 'انتهت التجربة: نجحت' or 'أوقفت التجربة', type = done and 'success' or 'inform' })
    end)
end)
