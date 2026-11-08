-- =====================================================================
-- EX_Tii heists: the cartel stash (Tier 6), the ranch at La Fuente Blanca. Text the fence "مزرعة": a blue
-- USB, a cartel guard's keycard (the prep, "تحضير مزرعة") and $6,000 from your bank. Six armed men walk the
-- yard. The gate camera box first (the blue USB, the laptop game) keeps them half blind. Get to the barn,
-- break the crates open one by one. Seen, shot at, or loud: the alarm, and two more cars of them come.
-- =====================================================================
local C = Config
local S = C.stash
local KEY = 'stash:ranch'
local SITE = 'stash'

local st = { phase = 'idle', crates = {}, crew = {}, looted = {} }
local function publish()
    GlobalState['exti_heists:stash'] = { phase = st.phase, crates = st.crates, blind = st.blind, cooldown = H.cooldownLeft(KEY) }
end
CreateThread(function() Wait(1500); publish() end)

local function reset()
    H.guardEnd(SITE)
    st = { phase = 'idle', crates = {}, crew = {}, looted = {} }
    publish()
end
function H.resetStash() H.clearCooldown(KEY); reset() end

function H.startStash(src)
    if st.phase ~= 'idle' then return false, 'المزرعة محروسة أكثر من العادة الآن. لاحقًا' end
    local left = H.cooldownLeft(KEY)
    if left > 0 then return false, ('نقلوا المال. بعد %d دقيقة'):format(math.ceil(left / 60)) end
    if H.isCopOnDuty(src) then return false, 'cop' end
    if H.isHot(src) then return false, 'أنت مطلوب الآن. اهدأ أولًا' end
    local ok, need = H.canTier(src, S.tier, true)
    if not ok then return false, ('هؤلاء يقتلون. تحتاج سمعة %d'):format(need) end
    local mode, need2 = H.modeFor(S.tier)
    if not mode then return false, ('أحتاج %d شرطة في الخدمة'):format(need2 or 0) end
    if (exports.ox_inventory:Search(src, 'count', S.needs.usb) or 0) < 1 then return false, 'تحتاج فلاشة زرقاء لكاميرا البوابة' end
    if not H.hasPrep(src, S.needs.prep) then return false, ('ينقصك التحضير: %s. اضغط "تحضير مزرعة"'):format(C.preps[S.needs.prep].label) end
    local p = H.player(src)
    if not p or (p.PlayerData.money.bank or 0) < S.cost then return false, ('أحتاج %d$ من حسابك في البنك'):format(S.cost) end
    p.Functions.RemoveMoney('bank', S.cost, 'heist-setup')
    H.takePrep(src, S.needs.prep)
    st = { phase = 'on', crates = {}, crew = { [src] = true }, looted = {}, mode = mode, by = src, at = H.now() }
    H.setCooldown(KEY, S.cooldownMinutes * 60)
    H.setHeat(src, S.tier)
    local site = H.guardSite(SITE, S)
    site.onAlert = function(by)
        st.alarm = true
        local list = {}
        for x in pairs(st.crew) do list[#list + 1] = x end
        if mode.police and GetResourceState('exti_police') == 'started' then
            pcall(function()
                exports.exti_police:AddCall({ kind = 'alarm', label = C.calls.stash, coords = { x = S.center.x, y = S.center.y, z = S.center.z },
                    text = 'إطلاق نار كثيف في مزرعة لا فوينتي بلانكا', number = 'جار', suspect = by or list[1] })
            end)
        end
    end
    publish()
    H.log(src, 'stash_start', H.modeText(mode))
    -- 30 minutes and it's over
    local mark = st
    SetTimeout(30 * 60 * 1000, function()
        if st ~= mark then return end
        for x in pairs(mark.looted) do if GetPlayerName(x) and not (mark.repDone and mark.repDone[x]) then H.repFor(x, S.tier, mark.mode) end end
        reset()
    end)
    return true, S.center
end

-- the gate camera box: the blue USB, the laptop game
lib.callback.register('exti_heists:server:stashCamBegin', function(src)
    if st.phase ~= 'on' or st.blind or H.isCopOnDuty(src) or not H.near(src, S.camera, 2.2) then return false end
    if (exports.ox_inventory:Search(src, 'count', S.needs.usb) or 0) < 1 then return false, 'تحتاج فلاشة زرقاء' end
    exports.ox_inventory:RemoveItem(src, S.needs.usb, 1)
    st.crew[src] = true
    local lv = H.skillLevel(H.rec(src), 'hacking')
    return true, H.gameBegin(src, 'hack', { stash = true }), { tier = 2, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)
lib.callback.register('exti_heists:server:stashCamEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'hack', token, passed == true)
    if not ctx or not ctx.stash or st.phase ~= 'on' then return false end
    if not passed then H.guardRaise(SITE, src, 'camera'); return false, 'alarm' end
    st.blind = true; H.guardBlind(SITE); publish()
    H.addSkill(src, 'hacking')
    return true
end)

-- the crates (8 s each; with guards still standing and the yard calm, a crowbar is loud)
local opening = {}
lib.callback.register('exti_heists:server:stashCrateBegin', function(src, i)
    i = math.tointeger(i)
    local c = i and S.crates[i]
    if not c or st.phase ~= 'on' or st.crates[i] or H.isCopOnDuty(src) or not H.near(src, c, 2.0) then return false end
    opening[src] = { i = i, at = GetGameTimer() }
    st.crew[src] = true
    if not H.guardAlerted(SITE) and H.guardAlive(SITE) > 0 and math.random() < (st.blind and 0.25 or 0.6) then
        local mark = st
        SetTimeout(math.random(2000, 5000), function() if st == mark and st.phase == 'on' then H.guardRaise(SITE, src, 'noise') end end)
    end
    return true, S.crateSeconds
end)
lib.callback.register('exti_heists:server:stashCrateEnd', function(src)
    local o = opening[src]; opening[src] = nil
    if not o or st.phase ~= 'on' or st.crates[o.i] then return false end
    if GetGameTimer() - o.at < (S.crateSeconds - 1) * 1000 then return false end
    if not H.near(src, S.crates[o.i], 2.6) then return false end
    st.crates[o.i] = true; publish()
    H.touch(src, S.crates[o.i])
    local pay = H.payOf(S.money, st.mode)
    H.giveLoot(src, 'black_money', pay)
    local usb = not st.usbGiven and S.usb and math.random() < S.usb.chance * (st.mode.usb or 1)
    if usb then st.usbGiven = true; exports.ox_inventory:AddItem(src, S.usb.item, 1) end
    st.looted[src] = true
    H.log(src, 'stash_crate', ('%d · $%d%s'):format(o.i, pay, usb and ' + red USB' or ''))
    local n = 0
    for _ in pairs(st.crates) do n = n + 1 end
    if n >= #S.crates then
        st.phase = 'emptied'; publish()
        if H.contract then H.contract(src, 'stash') end
    end
    return true, { money = pay, usb = usb and S.usb.item or nil, left = #S.crates - n }
end)
AddEventHandler('playerDropped', function() opening[source] = nil end)

-- the Rep: once each, when he leaves the ranch
CreateThread(function()
    while true do
        Wait(4000)
        if st.phase ~= 'idle' and next(st.looted) then
            for x in pairs(st.looted) do
                st.repDone = st.repDone or {}
                if not st.repDone[x] and GetPlayerName(x) and not H.near(x, S.center, S.radius + 60.0) then
                    st.repDone[x] = true; H.repFor(x, S.tier, st.mode)
                end
            end
            if st.phase == 'emptied' and not st.resetting then
                local all = true
                for x in pairs(st.looted) do if not st.repDone[x] and GetPlayerName(x) then all = false end end
                if all then
                    st.resetting = true
                    local mark = st
                    SetTimeout(60000, function() if st == mark then reset() end end)
                end
            end
        end
    end
end)

H.registerHeist({ id = 'stash', label = S.label, tier = S.tier, where = 'فلاشة زرقاء + تحضير + 6,000$', status = function()
    if st.phase ~= 'idle' then return 'busy', 0, 'يُسرق الآن' end
    local left = H.cooldownLeft(KEY)
    if left > 0 then return 'cooldown', left end
    return 'ready', 0, 'اكتب للمصرّف "مزرعة"'
end })
