-- =====================================================================
-- EX_Tii heists (game side): store robberies. Point a gun at the clerk, keep it on him while he empties
-- the till, grab the cash. Look away and he may press the silent alarm or drop behind the counter.
-- The back-room safe: the dial, then the time lock while the bell rings.
-- =====================================================================
local C = Config
local R, S = C.register, C.storeSafe

local stores = {}        -- [index] = { index, area, type, clerk = vec4, key }
CreateThread(function()
    while GetResourceState('exti_shops') ~= 'started' do Wait(500) end
    local ok, list = pcall(function() return exports.exti_shops:Stores() end)
    for i, s in ipairs(ok and list or {}) do
        if C.storeTypes[s.type] then stores[i] = { index = i, area = s.area, type = s.type, clerk = s.clerk, key = ('%.1f,%.1f'):format(s.clerk.x, s.clerk.y) } end
    end
end)

local phases, safeTimers, spots, downs = {}, {}, {}, {}
local function readState()
    phases = GlobalState['exti_heists:stores'] or {}
    safeTimers = GlobalState['exti_heists:safes'] or {}
    spots = GlobalState['exti_heists:spots'] or {}
    downs = GlobalState['exti_heists:clerkDown'] or {}
end
readState()
AddStateBagChangeHandler('exti_heists:stores', 'global', function(_, _, v) phases = v or {} end)
AddStateBagChangeHandler('exti_heists:clerkDown', 'global', function(_, _, v) downs = v or {} end)
AddStateBagChangeHandler('exti_heists:safes', 'global', function(_, _, v) safeTimers = v or {} end)
AddStateBagChangeHandler('exti_heists:spots', 'global', function(_, _, v) spots = v or {} end)

local function clerkOf(i) local ok, ped = pcall(function() return exports.exti_shops:Clerk(i) end); return ok and ped or nil end
local function clerkPos(s) return vec3(s.clerk.x, s.clerk.y, s.clerk.z) end
-- the till: GTA's own register on the counter next to the clerk (found once it has loaded), else a guess
local TILLS = { `prop_till_01`, `prop_till_01_dam`, `prop_till_02`, `prop_till_03` }
local tills = {}
local function tillPos(s)
    local i = s.index
    if tills[i] then return tills[i] end
    local c = clerkPos(s)
    for _, m in ipairs(TILLS) do
        local o = GetClosestObjectOfType(c.x, c.y, c.z, 2.5, m, false, false, false)
        if o ~= 0 and DoesEntityExist(o) then tills[i] = GetEntityCoords(o); return tills[i] end
    end
    local h = math.rad(s.clerk.w)
    return c + vec3(-math.sin(h), math.cos(h), 0.0) * 0.75
end
-- standing at the till: across the counter, height doesn't matter much
local function atTill(here, s)
    local t = tillPos(s)
    return #(vec2(here.x, here.y) - vec2(t.x, t.y)) < 1.5 and math.abs(here.z - t.z) < 2.0
end

---------------------------------------------------------------------------
-- the clerk (every player's game shows the same fear)
---------------------------------------------------------------------------
local shownPhase = {}
local CLERK_ANIM = {
    held = { 'mp_am_hold_up', 'holdup_victim_20s', 0 },   -- hands up, then he opens the till for you
    open = false,                                         -- (he goes on with the same movement)
    cower = { 'amb@code_human_cower_stand@male@base', 'base', 1 },
    emptied = { 'amb@code_human_cower_stand@male@base', 'base', 1 },
}
local DEAD = { 'dead', 'dead_a', 1 }
local shownDown = {}
local function speak(ped, line) if ped and DoesEntityExist(ped) then PlayPedAmbientSpeechNative(ped, line, 'SPEECH_PARAMS_FORCE_SHOUTED') end end
CreateThread(function()
    while true do
        local here = GetEntityCoords(cache.ped)
        for i, s in pairs(stores) do
            local ph = phases[i]
            if ph == 'safe' then ph = nil end
            local near = #(here - clerkPos(s)) < 60.0
            -- shot: he lies behind the counter (over everything else) until the shop opens again
            local isDown = downs[i] == true
            if near and isDown ~= (shownDown[i] == true) then
                local ped = clerkOf(i)
                if ped and DoesEntityExist(ped) then
                    if isDown then
                        HC.anim(ped, DEAD[1], DEAD[2], DEAD[3])
                        ApplyPedBlood(ped, 0, 0.0, 0.0, 0.0, 'wound_sheet')
                        ApplyPedBlood(ped, 3, 0.0, 0.0, 0.0, 'wound_sheet')
                    else
                        ClearPedBloodDamage(ped)
                        pcall(function() exports.exti_shops:ClerkReset(i) end)
                        shownPhase[i] = '?'   -- (and his robbery pose is drawn again below)
                    end
                    shownDown[i] = isDown
                end
            end
            if not isDown and ph ~= shownPhase[i] and near then
                local ped = clerkOf(i)
                if ped and DoesEntityExist(ped) then
                    local a = ph and CLERK_ANIM[ph]
                    if ph and a then
                        HC.anim(ped, a[1], a[2], a[3])
                        if ph == 'held' then
                            speak(ped, 'GENERIC_FRIGHTENED_HIGH')
                            -- after the till movement he keeps his hands up
                            SetTimeout(19000, function()
                                if (phases[i] == 'held' or phases[i] == 'open') and not downs[i] then local p2 = clerkOf(i); HC.anim(p2, 'missminuteman_1ig_2', 'handsup_base', 1) end
                            end)
                        elseif ph == 'cower' then speak(ped, 'GENERIC_SHOCKED_HIGH') end
                    elseif not ph then
                        pcall(function() exports.exti_shops:ClerkReset(i) end)
                    end
                    shownPhase[i] = ph
                end
            elseif not near and #(here - clerkPos(s)) >= 90.0 then
                shownPhase[i] = nil; shownDown[i] = nil; tills[i] = nil   -- (his ped is gone; drawn again when you come back)
            end
        end
        Wait(400)
    end
end)

---------------------------------------------------------------------------
-- the hold-up
---------------------------------------------------------------------------
local mine = nil   -- { i, lookAway = 0, sent2 = false, sentCower = false, untilOpen }
local lastTry, lastShot = 0, 0
RegisterNetEvent('exti_heists:client:holdUp', function(i, secs, modeText)
    mine = { i = i, lookAway = 0, sent2 = false, sentCower = false, untilOpen = GetGameTimer() + secs * 1000 }
    HC.notify(('أبقِ السلاح عليه حتى يفتح الصندوق · %s'):format(modeText), 'inform', 7000)
end)
RegisterNetEvent('exti_heists:client:tillOpen', function(i)
    if mine and mine.i == i then HC.notify('فتح الصندوق: خذ المال', 'success') end
end)
RegisterNetEvent('exti_heists:client:clerkCowers', function(i)
    if mine and mine.i == i then HC.notify('اختبأ خلف الطاولة: اكسر قفل الصندوق', 'warning', 6000) end
end)
RegisterNetEvent('exti_heists:client:silentAlarm', function(i)
    if mine and mine.i == i then HC.notify('أبعدت السلاح عنه: ضغط زر الإنذار الصامت', 'error', 6000) end
end)
RegisterNetEvent('exti_heists:client:clerkShot', function(i)
    HC.notify('أطلقت النار على صاحب المحل: الشرطة في الطريق · اكسر قفل الصندوق (lockpick)', 'error', 8000)
    if not mine or mine.i ~= i then mine = { i = i, lookAway = 0, sent2 = true, sentCower = true, untilOpen = 0 } end
end)

local function grabTill(i, s)
    HC.prompt(nil)
    local ped = cache.ped
    TaskTurnPedToFaceCoord(ped, tillPos(s).x, tillPos(s).y, tillPos(s).z, 600)
    Wait(600)
    local done = lib.progressBar({
        duration = R.grabSeconds * 1000, label = 'تفرغ الصندوق...', useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'oddjobs@shop_robbery@rob_till', clip = 'loop', flag = 1 },
    })
    if not done then return end
    local ok, pay = lib.callback.await('exti_heists:server:grabTill', false, i)
    if ok then HC.notify(('أخذت %d$ مالًا قذرًا · اخرج بسرعة'):format(pay), 'success', 7000); mine = nil end
end

local function pickTill(i, s)
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:tillPickBegin', false, i)
    if not ok then if token then HC.notify(token, 'error') end return end
    if not mine or mine.i ~= i then mine = { i = i, lookAway = 0, sent2 = true, sentCower = true, untilOpen = 0 } end
    local ped = cache.ped
    TaskTurnPedToFaceCoord(ped, tillPos(s).x, tillPos(s).y, tillPos(s).z, 600)
    Wait(500)
    HC.anim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1)
    local passed = HC.play('lockpick', params, 'قفل الصندوق')
    ClearPedTasks(ped)
    local res, why = lib.callback.await('exti_heists:server:tillPickEnd', false, token, passed)
    if res then HC.notify(('أخذت %d$ مالًا قذرًا · اخرج بسرعة'):format(why), 'success', 7000); mine = nil
    elseif why == 'broke' then HC.notify('انكسر مفتاح الفتح', 'error')
    elseif why == 'failed' then HC.notify('لم يُفتح القفل: حاول مرة أخرى', 'error') end
end

---------------------------------------------------------------------------
-- the safe
---------------------------------------------------------------------------
local bell = nil
local function bellOn(pos)
    if bell then return end
    bell = GetSoundId()
    PlaySoundFromCoord(bell, 'Burglar_Bell', pos.x, pos.y, pos.z, 'Generic_Alarms', false, 30, false)
end
local function bellOff() if bell then StopSound(bell); ReleaseSoundId(bell); bell = nil end end

local function crackSafe(i, s, pos)
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:safeBegin', false, i)
    if not ok then if token then HC.notify(token, 'error') end return end
    local sp = spots.safes and spots.safes[s.key]
    if sp and sp.h then SetEntityHeading(cache.ped, sp.h)
    elseif sp then
        -- GTA's own safe: it stands against the wall; face the wall the spot is closest to
        local p = vec3(sp.x, sp.y, sp.z)
        local best, bd
        for a = 0, 315, 45 do
            local r = math.rad(a)
            local to = p + vec3(-math.sin(r), math.cos(r), 0.0) * 1.2
            local ray = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, p.z + 0.4, to.x, to.y, to.z + 0.4, 1, cache.ped, 7)
            local _, hit, pos = GetShapeTestResult(ray)
            if hit == 1 or hit == true then local d = #(pos - p); if not bd or d < bd then best, bd = a, d end end
        end
        if best then SetEntityHeading(cache.ped, best + 0.0) end
    end
    HC.anim(cache.ped, 'mini@safe_cracking', 'idle_base', 1)
    local passed = HC.play('safedial', params, 'خزنة المتجر')
    ClearPedTasks(cache.ped)
    local res, secs = lib.callback.await('exti_heists:server:safeEnd', false, token, passed)
    if res then HC.notify(('فُتح القفل: قفل الوقت يعمل · %s · الإنذار يرن'):format(('%d:%02d'):format(secs // 60, secs % 60)), 'warning', 8000)
    elseif passed == false then HC.notify('أفلت الرقم: حاول مرة أخرى', 'error') end
end
RegisterNetEvent('exti_heists:client:safeReady', function() HC.notify('انتهى قفل الوقت: افتح الخزنة', 'success', 7000) end)

local function lootSafe(i)
    HC.prompt(nil)
    local done = lib.progressBar({
        duration = 6000, label = 'تفرغ الخزنة...', canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 },
    })
    if not done then return end
    local ok, pay, usb = lib.callback.await('exti_heists:server:safeLoot', false, i)
    if ok then
        HC.notify(('أخذت %d$ مالًا قذرًا%s'):format(pay, usb and ' · ووجدت فلاشة خضراء!' or ''), 'success', 8000)
    end
end

---------------------------------------------------------------------------
-- the loop: near a store only
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 600
        local here = GetEntityCoords(cache.ped)
        local near, nd
        for i, s in pairs(stores) do
            local d = #(here - clerkPos(s))
            if d < 14.0 and (not nd or d < nd) then near, nd = i, d end
        end
        local text, act = nil, nil
        if near and HC.canAct() then
            sleep = 0
            local s = stores[near]
            local ph = phases[near]
            if ph == 'safe' then ph = nil end
            local clerk = clerkOf(near)

            -- 0) shots: at him (he goes down), or near him (he panics and presses the alarm)
            if IsPedShooting(cache.ped) and GetGameTimer() > (mine and mine.shotSent or lastShot) then
                lastShot = GetGameTimer() + 1500
                if mine then mine.shotSent = lastShot end
                local atHim = clerk and not downs[near] and (HC.aimingAt(clerk, 25.0) or HasEntityBeenDamagedByEntity(clerk, cache.ped, true))
                TriggerServerEvent('exti_heists:server:clerkShot', near, atHim and true or false)
                if clerk then ClearEntityLastDamageEntity(clerk) end
            end

            -- 1) a gun on the clerk starts it
            if not ph and not mine and clerk and not downs[near] and HC.aimingAt(clerk, 9.0) and GetGameTimer() - lastTry > 4000 then
                lastTry = GetGameTimer()
                TriggerServerEvent('exti_heists:server:holdUp', near)
            end

            -- 2) holding him: keep the gun on him
            if mine and mine.i == near and ph == 'held' then
                if HC.aimingAt(clerk, 14.0) then
                    mine.lookAway = 0
                else
                    mine.lookAway = mine.lookAway + GetFrameTime()
                    if mine.lookAway >= R.lookAwaySeconds and not mine.sent2 then mine.sent2 = true; TriggerServerEvent('exti_heists:server:lookAway', near, mine.lookAway) end
                    if mine.lookAway >= R.cowerSeconds and not mine.sentCower then mine.sentCower = true; TriggerServerEvent('exti_heists:server:lookAway', near, mine.lookAway) end
                end
                local left = math.max(0, (mine.untilOpen - GetGameTimer()) / 1000)
                if mine.lookAway > 0.2 and not mine.sent2 then
                    text = ('⚠ أعد السلاح عليه! سيضغط زر الإنذار خلال %d'):format(math.max(1, math.ceil(R.lookAwaySeconds - mine.lookAway)))
                else
                    text = ('أبقِ السلاح عليه... يفتح الصندوق · %d'):format(math.ceil(left))
                end
            end

            -- 3) the till
            if atTill(here, s) then
                if ph == 'open' and mine and mine.i == near then
                    text, act = '[E] أفرغ الصندوق', function() grabTill(near, s) end
                elseif (ph == 'cower' and mine and mine.i == near) or (not ph and not mine and HC.count('lockpick') > 0 and not IsPedArmed(cache.ped, 4)) then
                    text, act = '[E] اكسر قفل الصندوق', function() pickTill(near, s) end
                end
            end

            -- 4) the safe
            local sp = spots.safes and spots.safes[s.key]
            if sp then
                local pos = vec3(sp.x, sp.y, sp.z)
                local t = safeTimers[near]
                if t then bellOn(pos) end
                if #(here - pos) < 1.3 then
                    if not t then
                        text, act = '[E] افتح الخزنة (قرص الأرقام)', function() crackSafe(near, s, pos) end
                    elseif t.phase == 'timelock' then
                        local left = math.max(0, (t.readyAt or 0) - GetCloudTimeAsInt())
                        text = ('قفل الوقت: %d:%02d · الإنذار يرن'):format(left // 60, left % 60)
                    elseif t.phase == 'ready' then
                        text, act = '[E] خذ ما في الخزنة', function() lootSafe(near) end
                    end
                end
            end
            if not safeTimers[near] then bellOff() end
        else
            bellOff()
        end
        HC.prompt(text, 'stores')
        if act and (IsControlJustReleased(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then act() end
        if mine and (not near or (phases[mine.i] ~= 'held' and phases[mine.i] ~= 'open' and phases[mine.i] ~= 'cower')) then
            if not phases[mine.i] or phases[mine.i] == 'emptied' then mine = nil end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- admins: /heistspots
---------------------------------------------------------------------------
RegisterNetEvent('exti_heists:client:spotsMenu', function(i, area, layout, hasSafe)
    local LAYOUT = { ['247'] = '24/7', ltd = 'LTD', liquor = 'محل مشروبات' }
    local function save(what)
        local ok, msg = lib.callback.await('exti_heists:server:spotSave', false, what, i)
        HC.notify(msg or (ok and 'تم' or 'لم يُحفظ'), ok and 'success' or 'error')
    end
    lib.registerContext({ id = 'exti_heist_spots', title = ('أماكن السطو · %s (%s)'):format(area, LAYOUT[layout] or layout), options = {
        { title = 'خزنة المتجر هنا', description = 'قف أمام الخزنة ووجهك إليها', icon = 'vault', onSelect = function() save('safe') end },
        { title = 'انسخ الخزنة لكل المتاجر بنفس الشكل', description = hasSafe and ('كل متاجر ' .. (LAYOUT[layout] or layout)) or 'ضع الخزنة هنا أولًا', icon = 'copy', disabled = not hasSafe, onSelect = function() save('copy') end },
        { title = 'امسح خزنة هذا المتجر', icon = 'trash', disabled = not hasSafe, onSelect = function() save('clear') end },
    } })
    lib.showContext('exti_heist_spots')
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then bellOff(); HC.prompt(nil) end end)
