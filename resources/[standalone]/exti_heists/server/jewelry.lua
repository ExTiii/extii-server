-- =====================================================================
-- EX_Tii heists: the jewelry store (Tier 3), Vangelico. Two ways in:
--   quiet: a green USB at the security box on the roof (laptop hack, 2 tries): cameras and alarm off for
--          3 minutes; the cases are cut open with the glass cutter (no alarm until the 3 minutes are up)
--   loud:  smash the cases. Fast, the alarm goes off at once, the cameras describe you.
-- The whole store: once every 2 hours. The leader needs Rep 3.
-- =====================================================================
local C = Config
local J = C.jewelry
local KEY = 'jewelry:store'

local st = { phase = 'idle', cases = {}, quietUntil = 0, mode = nil, alarm = false, hackFails = 0, crew = {} }

local function publish()
    GlobalState['exti_heists:jewel'] = { phase = st.phase, cases = st.cases, quietUntil = st.quietUntil, alarm = st.alarm,
                                         cooldown = H.cooldownLeft(KEY) }
end
CreateThread(function() Wait(1500); publish() end)

local function inStore(src) return H.near(src, J.area, 16.0) end

local function reset()
    st = { phase = 'idle', cases = {}, quietUntil = 0, mode = nil, alarm = false, hackFails = 0, crew = {} }
    publish()
    TriggerClientEvent('exti_heists:client:jewelReset', -1)
end

local function alarm(src, quietLate)
    if st.alarm then return end
    st.alarm = true; publish()
    local list = {}
    for s in pairs(st.crew) do list[#list + 1] = s end
    if #list == 0 and src then list[1] = src end
    if GetResourceState('exti_police') == 'started' then
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = quietLate and C.calls.jewelryQuiet or C.calls.jewelry, coords = { x = J.area.x, y = J.area.y, z = J.area.z },
                text = quietLate and 'رجعت الكاميرات: الخزائن مفتوحة' or 'تحطيم خزائن العرض', number = 'إنذار فانجيليكو', suspect = list[1] })
        end)
    end
    if st.mode and not st.mode.police and #list > 0 then H.npcRespond(list, J.area, 'jewelry') end
    for s in pairs(st.crew) do TriggerClientEvent('exti_heists:client:jewelAlarm', s) end
    H.log(list[1], 'jewel_alarm', quietLate and 'quiet window over' or 'smash')
end

-- the job starts (the first hack or the first smash): mode, Rep, cooldown
local function begin(src)
    if st.phase ~= 'idle' then return true end
    local left = H.cooldownLeft(KEY)
    if left > 0 then return false, ('المحل فارغ: عاد بعد %s'):format(H.mmss(left)) end
    local ok, need = H.canTier(src, J.tier, true)
    if not ok then return false, ('تحتاج سمعة %d لهذا المحل'):format(need) end
    local mode, need2 = H.modeFor(J.tier)
    if not mode then return false, ('تحتاج %d شرطة في الخدمة'):format(need2 or 0) end
    st.phase, st.mode, st.leader = 'on', mode, src
    H.setCooldown(KEY, J.cooldownMinutes * 60)
    publish()
    H.log(src, 'jewel_start', H.modeText(mode))
    -- the store is done 12 minutes after it started, whatever happened
    SetTimeout(12 * 60 * 1000, function()
        if st.leader ~= src then return end
        for s in pairs(st.looted or {}) do if not (st.repDone and st.repDone[s]) and GetPlayerName(s) then H.repFor(s, J.tier, st.mode) end end
        reset()
    end)
    return true
end

---------------------------------------------------------------------------
-- the quiet way: the security box on the roof
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:jewelHackBegin', function(src)
    if H.isCopOnDuty(src) or not H.near(src, J.panel, 2.5) then return false end
    if st.quietUntil > H.now() or st.alarm then return false, 'الأنظمة معطّلة أو الإنذار يرن' end
    if st.hacked then return false, 'رجعت الأنظمة وغيّرت رموزها: لا اختراق ثانٍ الليلة' end
    if st.hackFails >= J.hackTries then return false end
    if (exports.ox_inventory:Search(src, 'count', 'usb_green') or 0) < 1 and not st.usbIn then return false, 'تحتاج فلاشة اختراق خضراء' end
    local ok, why = begin(src); if not ok then return false, why end
    -- the USB is used up the moment it goes in (two tries with it)
    if not st.usbIn then exports.ox_inventory:RemoveItem(src, 'usb_green', 1); st.usbIn = true; H.log(src, 'usb_used', 'green · jewelry') end
    st.crew[src] = true
    H.setHeat(src)
    local lv = H.skillLevel(H.rec(src), 'hacking')
    return true, H.gameBegin(src, 'hack', { jewel = true }), { tier = 1, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:jewelHackEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'hack', token, passed == true)
    if not ctx or not ctx.jewel then return false end
    if not passed then
        st.hackFails = st.hackFails + 1
        if st.hackFails >= J.hackTries then alarm(src); return false, 'alarm' end
        return false, 'again'
    end
    st.quietUntil = H.now() + J.quietSeconds
    st.hacked = true
    publish()
    H.addSkill(src, 'hacking')
    H.log(src, 'jewel_hacked', ('%ds quiet'):format(J.quietSeconds))
    -- the cameras come back: if cases were opened, now the alarm
    local mark = st.quietUntil
    SetTimeout(J.quietSeconds * 1000, function()
        if st.quietUntil == mark and st.phase ~= 'idle' and next(st.cases) then alarm(src, true) end
    end)
    return true, J.quietSeconds
end)

---------------------------------------------------------------------------
-- the cases: cut (quiet, during the window) or smashed (loud)
---------------------------------------------------------------------------
local working = {}   -- [src] = { i, how, at }
local function rollCase()
    local total = 0
    for _, e in ipairs(J.loot) do total = total + e.weight end
    local r = math.random() * total
    for _, e in ipairs(J.loot) do r = r - e.weight; if r <= 0 then return e.item, math.random(e.amount[1], e.amount[2]) end end
end
local function lootCase(src, i)
    st.cases[i] = true; publish()
    local got = {}
    for _ = 1, math.random(J.rolls[1], J.rolls[2]) do
        local item, n = rollCase()
        if item then H.giveLoot(src, item, n); got[#got + 1] = { item = item, n = n } end
    end
    st.looted = st.looted or {}; st.looted[src] = true
    if H.contract then H.contract(src, 'jewel') end
    return got
end

lib.callback.register('exti_heists:server:jewelCaseBegin', function(src, i, how)
    i = math.tointeger(i)
    local cs = i and J.cases[i]
    if not cs or st.cases[i] or H.isCopOnDuty(src) or not H.near(src, cs.pos, 1.8) then return false end
    if how == 'cut' then
        if st.quietUntil <= H.now() then return false, 'الكاميرات تعمل: عطّلها أولًا من لوحة الأمن على السطح' end
        st.crew[src] = true
        local lv = H.skillLevel(H.rec(src), 'breaching')
        return true, H.gameBegin(src, 'glasscut', { case = i }), { time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
    end
    -- smash: needs something in your hands
    if GetSelectedPedWeapon(GetPlayerPed(src)) == `WEAPON_UNARMED` then return false, 'تحتاج شيئًا في يدك' end
    local ok, why = begin(src); if not ok then return false, why end
    st.crew[src] = true
    H.setHeat(src)
    working[src] = { i = i, at = GetGameTimer() }
    TriggerClientEvent('exti_heists:client:jewelSmashFx', -1, i, src)
    return true, 'smash'
end)

lib.callback.register('exti_heists:server:jewelSmashEnd', function(src)
    local w = working[src]; working[src] = nil
    if not w or st.cases[w.i] or GetGameTimer() - w.at < 3500 then return false end
    if not H.near(src, J.cases[w.i].pos, 2.2) then return false end
    local got = lootCase(src, w.i)
    alarm(src)
    return true, got
end)

lib.callback.register('exti_heists:server:jewelCutEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'glasscut', token, passed == true)
    local i = ctx and ctx.case
    if not i or st.cases[i] then return false end
    if not passed then
        -- the glass cracked loudly
        alarm(src)
        TriggerClientEvent('exti_heists:client:jewelSmashFx', -1, i, src)
        return false, 'cracked'
    end
    if not H.near(src, J.cases[i].pos, 2.2) then return false end
    local got = lootCase(src, i)
    H.addSkill(src, 'breaching')
    return true, got
end)

-- the Rep: once for each crew member who took something, when they leave the store
CreateThread(function()
    while true do
        Wait(3000)
        if st.phase ~= 'idle' and st.looted then
            for s in pairs(st.looted) do
                if not (st.repDone and st.repDone[s]) and not inStore(s) then
                    st.repDone = st.repDone or {}; st.repDone[s] = true
                    H.repFor(s, J.tier, st.mode)
                end
            end
            local all = 0
            for _ in pairs(st.cases) do all = all + 1 end
            if all >= #J.cases then st.phase = 'emptied'; publish() end
        end
    end
end)

AddEventHandler('playerDropped', function() working[source] = nil end)

-- admins (F1): the store ready again
function H.resetJewelry() H.clearCooldown(KEY); reset() end
