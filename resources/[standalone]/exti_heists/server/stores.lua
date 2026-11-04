-- =====================================================================
-- EX_Tii heists: store robberies (the 20 stores of exti_shops)
--   Tier 1 register: gun on the clerk -> he opens the till (10 s) -> empty it. Look away: he may press the
--   silent alarm, or drop behind the counter (then the till is lockpicked). No gun: lockpick the till
--   (he presses the alarm straight away).
--   Tier 2 safe (back room): the dial, then a 2-minute time lock while the alarm rings, then the cash.
-- =====================================================================
local C = Config
local R, S = C.register, C.storeSafe

local stores = {}    -- [index] = { index, area, type, layout, clerk = vec4 }
local state = {}     -- [index] = { phase = 'held'|'open'|'cower'|'emptied', by, mode, at, alarm, rolled, called }
local safes = {}     -- [index] = { phase = 'timelock'|'ready', by, mode, readyAt }
local down = {}      -- [index] = os.time() he was shot (he lies behind the counter until shotResetMinutes)
local spots = { safes = {} }   -- [key] = { x, y, z, h, copied }  (data/spots.json, placed with /heistspots)

local function clerkPos(st) return vec3(st.clerk.x, st.clerk.y, st.clerk.z) end
local function keyOf(s) return ('%.1f,%.1f'):format(s.clerk.x, s.clerk.y) end
local function layoutOf(s)
    if s.type == 'liquor' then return 'liquor' end
    if s.type == 'fuel' then
        for _, a in ipairs(C.storeLayouts.ltd) do if a == s.area then return 'ltd' end end
    end
    return '247'
end

local function publish()
    local phases = {}
    for i, st in pairs(state) do phases[i] = st.phase end
    for i, sf in pairs(safes) do phases[i] = phases[i] or 'safe' end
    GlobalState['exti_heists:stores'] = phases
    local timers = {}
    for i, sf in pairs(safes) do timers[i] = { phase = sf.phase, readyAt = sf.readyAt, by = sf.by } end
    GlobalState['exti_heists:safes'] = timers
    local d = {}
    for i in pairs(down) do d[i] = true end
    GlobalState['exti_heists:clerkDown'] = d
end

CreateThread(function()
    while GetResourceState('exti_shops') ~= 'started' do Wait(500) end
    local ok, list = pcall(function() return exports.exti_shops:Stores() end)
    for i, s in ipairs(ok and list or {}) do
        if C.storeTypes[s.type] then
            stores[i] = { index = i, area = s.area, type = s.type, clerk = s.clerk, key = keyOf(s), layout = layoutOf(s) }
        end
    end
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/spots.json')
    local okj, data = pcall(json.decode, raw or '')
    if okj and type(data) == 'table' and type(data.safes) == 'table' then spots.safes = data.safes end
    -- the stores without an admin spot take GTA's own safe in their back room
    for _, st in pairs(stores) do
        if not spots.safes[st.key] then
            local best, bd
            for _, p in ipairs(C.storeSafeSpots or {}) do
                local d = #(p - vec3(st.clerk.x, st.clerk.y, st.clerk.z))
                if d < 14.0 and (not bd or d < bd) then best, bd = p, d end
            end
            if best then spots.safes[st.key] = { x = best.x, y = best.y, z = best.z, builtin = true } end
        end
    end
    GlobalState['exti_heists:spots'] = spots
    publish()
end)

local function storeKey(i, what) return ('store:%s:%d'):format(what, i) end

-- the alarm: the police card always (cops below the minimum still hear it); no-police mode also sends the NPC security
local function call(i, label, number, src, extra, mode)
    local st = stores[i]
    if mode and not mode.police and src and not mode.npcSent then mode.npcSent = true; H.npcRespond({ src }, clerkPos(st), 'store') end
    if GetResourceState('exti_police') ~= 'started' then return end
    pcall(function()
        exports.exti_police:AddCall({
            kind = 'alarm', label = label, coords = { x = st.clerk.x, y = st.clerk.y, z = st.clerk.z },
            text = ('%s%s'):format(st.area or '', extra and (' · ' .. extra) or ''), number = number, suspect = src,
        })
    end)
end

local function isFirearm(src)
    local ok, w = pcall(function() return exports.ox_inventory:GetCurrentWeapon(src) end)
    if not ok or type(w) ~= 'table' or not w.name then return false end
    local okI, item = pcall(function() return exports.ox_inventory:Items(w.name) end)
    return okI and type(item) == 'table' and item.ammoname ~= nil
end

-- a clerk behind the counter waits 3 minutes at most, then the shop calms down
local function cowerTimeout(i)
    local st = state[i]
    SetTimeout(180 * 1000, function()
        if state[i] == st and st.phase == 'cower' then state[i] = nil; H.setCooldown(storeKey(i, 'till'), 5 * 60); publish() end
    end)
end

local function finish(i)
    -- the clerk is shaken for a while, then the shop opens again
    SetTimeout(90 * 1000, function()
        if state[i] and state[i].phase == 'emptied' then state[i] = nil; publish() end
    end)
end

---------------------------------------------------------------------------
-- Tier 1: the register
---------------------------------------------------------------------------
RegisterNetEvent('exti_heists:server:holdUp', function(i)
    local src = source
    i = math.tointeger(i)
    local st = i and stores[i]
    if not st or state[i] then return end
    if not H.near(src, clerkPos(st), 9.0) then return end
    if H.isCopOnDuty(src) then return end
    if not isFirearm(src) then return end
    local left = H.cooldownLeft(storeKey(i, 'till'))
    if left > 0 then return H.notify(src, ('أُفرغ الصندوق قبل قليل · %s'):format(H.mmss(left)), 'error') end
    local mode = H.modeFor(R.tier)
    if not mode then return end
    state[i] = { phase = 'held', by = src, mode = mode, at = H.now(), alarm = false, rolled = false }
    H.setHeat(src, R.tier)
    publish()
    TriggerClientEvent('exti_heists:client:holdUp', src, i, R.aimSeconds, H.modeText(mode))
    H.log(src, 'store_holdup', ('%s #%d · %s'):format(st.area, i, H.modeText(mode)))
    local started = state[i]
    SetTimeout(R.aimSeconds * 1000, function()
        if state[i] == started and started.phase == 'held' then
            started.phase = 'open'; started.openAt = H.now(); publish()
            TriggerClientEvent('exti_heists:client:tillOpen', src, i)
            -- nobody empties it within 90 s: he closes it again and the shop calls it in
            SetTimeout(90 * 1000, function()
                if state[i] == started and started.phase == 'open' then
                    started.phase = 'emptied'; publish(); finish(i)
                    if not started.alarm then call(i, C.calls.register, 'صاحب المحل', started.by, nil, started.mode) end
                end
            end)
        end
    end)
end)

-- the robber looked away for `secs` seconds
RegisterNetEvent('exti_heists:server:lookAway', function(i, secs)
    local src = source
    i = math.tointeger(i)
    local st = i and state[i]
    if not st or st.by ~= src or st.phase ~= 'held' then return end
    secs = tonumber(secs) or 0
    -- (EX_Tii: no dice any more: look away and he ALWAYS presses the silent alarm, the game warns you first)
    if secs >= R.lookAwaySeconds and not st.alarm then
        st.alarm = true
        call(i, C.calls.register, 'إنذار صامت', src, nil, st.mode)
        H.log(src, 'store_silent_alarm', stores[i].area)
        TriggerClientEvent('exti_heists:client:silentAlarm', src, i)
    end
    if secs >= R.cowerSeconds then
        st.phase = 'cower'; publish()
        TriggerClientEvent('exti_heists:client:clerkCowers', src, i)
        cowerTimeout(i)
        if not st.alarm then st.alarm = true; call(i, C.calls.register, 'إنذار صامت', src, nil, st.mode) end
    end
end)

-- shots in the store: `direct` = at the clerk (he goes down behind the counter), else near him (he panics)
local shotAsked = {}
RegisterNetEvent('exti_heists:server:clerkShot', function(i, direct)
    local src = source
    i = math.tointeger(i)
    local s = i and stores[i]
    if not s or H.isCopOnDuty(src) then return end
    if (shotAsked[src] or 0) > GetGameTimer() then return end
    shotAsked[src] = GetGameTimer() + 1500
    if not H.near(src, clerkPos(s), direct and 25.0 or 15.0) then return end
    local st = state[i]
    if direct and not down[i] then
        down[i] = H.now()
        local mode = st and st.mode or H.modeFor(R.tier)
        if not st and mode then
            -- nobody was holding him: the till now needs a lockpick (no cooldown skip)
            if H.cooldownLeft(storeKey(i, 'till')) <= 0 then
                st = { phase = 'cower', by = src, mode = mode, at = H.now(), alarm = true, rolled = true, shot = true }
                state[i] = st; cowerTimeout(i)
            end
        elseif st and st.phase == 'held' then
            st.phase = 'cower'; cowerTimeout(i)
        end
        if st then st.alarm = true; st.shot = true end
        H.setHeat(src, R.tier)
        publish()
        TriggerClientEvent('exti_heists:client:clerkShot', src, i)
        call(i, 'إطلاق نار في متجر', 'بلاغ من الشارع', src, 'أُصيب صاحب المحل', mode)
        H.log(src, 'store_clerk_shot', s.area)
        local at = down[i]
        SetTimeout(R.shotResetMinutes * 60 * 1000, function() if down[i] == at then down[i] = nil; publish() end end)
    elseif not direct and st and not st.alarm and (st.phase == 'held' or st.phase == 'open') then
        st.alarm = true
        call(i, 'إطلاق نار في متجر', 'إنذار صامت', src, nil, st.mode)
        H.log(src, 'store_shots', s.area)
    end
end)

-- empty the open till
lib.callback.register('exti_heists:server:grabTill', function(src, i)
    i = math.tointeger(i)
    local st = i and state[i]
    if not st or st.phase ~= 'open' or st.by ~= src then return false end
    if not H.near(src, clerkPos(stores[i]), 3.2) then return false end
    if H.now() - (st.openAt or 0) < R.grabSeconds - 1 then return false end
    st.phase = 'emptied'; publish()
    H.touch(src, clerkPos(stores[i]))
    local pay = H.payOf(R.pay, st.mode)
    H.giveLoot(src, 'black_money', pay)
    H.setCooldown(storeKey(i, 'till'), R.cooldownMinutes * 60)
    H.repFor(src, R.tier, st.mode)
    H.log(src, 'store_till', ('%s · $%d · %s'):format(stores[i].area, pay, H.modeText(st.mode)))
    if H.contract then H.contract(src, 'store') end
    if not st.alarm then
        SetTimeout(R.reportDelay * 1000, function() call(i, C.calls.register, 'صاحب المحل', src, nil, st.mode) end)
    end
    finish(i)
    return true, pay
end)

---------------------------------------------------------------------------
-- the till by lockpick (the clerk dropped down, or you came without a gun)
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:tillPickBegin', function(src, i)
    i = math.tointeger(i)
    local s = i and stores[i]
    if not s or not H.near(src, clerkPos(s), 3.2) or H.isCopOnDuty(src) then return false end
    local st = state[i]
    if st and not (st.phase == 'cower' and st.by == src) then return false end
    if not st then
        local left = H.cooldownLeft(storeKey(i, 'till'))
        if left > 0 then return false, ('أُفرغ الصندوق قبل قليل · %s'):format(H.mmss(left)) end
    end
    if (exports.ox_inventory:Search(src, 'count', 'lockpick') or 0) < 1 then return false, 'تحتاج مفتاح فتح (lockpick)' end
    if not st then
        -- no gun: he sees you and presses the alarm straight away
        local mode = H.modeFor(R.tier); if not mode then return false end
        st = { phase = 'cower', by = src, mode = mode, at = H.now(), alarm = true, rolled = true }
        state[i] = st; publish()
        H.setHeat(src, R.tier)
        cowerTimeout(i)
        call(i, C.calls.registerQuiet, 'إنذار صامت', src, 'يكسر قفل الصندوق', mode)
        H.log(src, 'store_till_pick', ('%s · %s'):format(s.area, H.modeText(mode)))
    end
    local lv = H.skillLevel(H.rec(src), 'lockpick')
    return true, H.gameBegin(src, 'lockpick', { store = i }), { pins = 5, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:tillPickEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'lockpick', token, passed == true)
    local i = ctx and ctx.store
    local st = i and state[i]
    if not st or st.by ~= src or st.phase ~= 'cower' then return false end
    if not passed then
        -- the pick may break (less often with skill)
        local lv = H.skillLevel(H.rec(src), 'lockpick')
        if math.random() < math.max(0.1, 0.45 - (lv - 1) * 0.08) then
            exports.ox_inventory:RemoveItem(src, 'lockpick', 1)
            return false, 'broke'
        end
        return false, 'failed'
    end
    if not H.near(src, clerkPos(stores[i]), 3.5) then return false end
    st.phase = 'emptied'; publish()
    H.touch(src, clerkPos(stores[i]))
    local pay = H.payOf(R.pay, st.mode)
    H.giveLoot(src, 'black_money', pay)
    H.setCooldown(storeKey(i, 'till'), R.cooldownMinutes * 60)
    H.addSkill(src, 'lockpick')
    H.repFor(src, R.tier, st.mode)
    H.log(src, 'store_till', ('%s · $%d (lockpick) · %s'):format(stores[i].area, pay, H.modeText(st.mode)))
    if H.contract then H.contract(src, 'store') end
    finish(i)
    return true, pay
end)

---------------------------------------------------------------------------
-- Tier 2: the back-room safe
---------------------------------------------------------------------------
local function safeSpot(i)
    local s = stores[i]
    local p = s and spots.safes[s.key]
    return p and vec3(p.x, p.y, p.z) or nil
end

lib.callback.register('exti_heists:server:safeBegin', function(src, i)
    i = math.tointeger(i)
    local s = i and stores[i]
    local pos = s and safeSpot(i)
    if not pos or not H.near(src, pos, 2.2) or H.isCopOnDuty(src) then return false end
    if safes[i] then return false, 'الخزنة مفتوحة الآن' end
    local left = H.cooldownLeft(storeKey(i, 'safe'))
    if left > 0 then return false, ('الخزنة فارغة الآن · %s'):format(H.mmss(left)) end
    local ok, need = H.canTier(src, S.tier, true)
    if not ok then return false, ('تحتاج سمعة %d لهذه الخزنة'):format(need) end
    local mode = H.modeFor(S.tier); if not mode then return false end
    local lv = H.skillLevel(H.rec(src), 'breaching')
    return true, H.gameBegin(src, 'safedial', { store = i, mode = mode }), { numbers = 3, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:safeEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'safedial', token, passed == true)
    local i = ctx and ctx.store
    if not i or safes[i] or H.cooldownLeft(storeKey(i, 'safe')) > 0 then return false end
    if not passed then return false, 'failed' end
    if not H.near(src, safeSpot(i), 2.6) then return false end
    H.touch(src, safeSpot(i))
    safes[i] = { phase = 'timelock', by = src, mode = ctx.mode, readyAt = H.now() + S.timelockSeconds }
    publish()
    H.setHeat(src, S.tier)
    H.addSkill(src, 'breaching')
    call(i, C.calls.safe, 'إنذار الخزنة', src, 'قفل الوقت يعمل', ctx.mode)
    H.log(src, 'store_safe_open', ('%s · %s'):format(stores[i].area, H.modeText(ctx.mode)))
    local sf = safes[i]
    SetTimeout(S.timelockSeconds * 1000, function()
        if safes[i] == sf then sf.phase = 'ready'; publish(); TriggerClientEvent('exti_heists:client:safeReady', sf.by, i) end
    end)
    -- not emptied within 5 minutes of the time lock: it locks again
    SetTimeout((S.timelockSeconds + 300) * 1000, function()
        if safes[i] == sf then safes[i] = nil; H.setCooldown(storeKey(i, 'safe'), S.cooldownMinutes * 60); publish() end
    end)
    return true, S.timelockSeconds
end)

lib.callback.register('exti_heists:server:safeLoot', function(src, i)
    i = math.tointeger(i)
    local sf = i and safes[i]
    if not sf or sf.phase ~= 'ready' or H.now() < sf.readyAt then return false end
    if not H.near(src, safeSpot(i), 2.4) or H.isCopOnDuty(src) then return false end
    safes[i] = nil; publish()
    H.setCooldown(storeKey(i, 'safe'), S.cooldownMinutes * 60)
    local pay = H.payOf(S.pay, sf.mode)
    H.giveLoot(src, 'black_money', pay)
    local usb = math.random() < S.usb.chance * (sf.mode.usb or 1)
    if usb then exports.ox_inventory:AddItem(src, S.usb.item, 1) end
    H.repFor(src, S.tier, sf.mode)
    if H.contract then H.contract(src, 'storesafe') end
    H.log(src, 'store_safe_loot', ('%s · $%d%s · %s'):format(stores[i].area, pay, usb and ' + green USB' or '', H.modeText(sf.mode)))
    return true, pay, usb
end)

---------------------------------------------------------------------------
-- admins: /heistspots — stand in front of a store's safe, save it, copy it to the stores built the same way
---------------------------------------------------------------------------
local function isAdmin(src) return IsPlayerAceAllowed(src, 'group.admin') end
local function saveSpots()
    local keep = { safes = {} }
    for k, v in pairs(spots.safes) do if not v.builtin then keep.safes[k] = v end end
    SaveResourceFile(GetCurrentResourceName(), 'data/spots.json', json.encode(keep, { indent = true }), -1)
    GlobalState['exti_heists:spots'] = spots
end
local function nearestStore(src)
    local here = H.coords(src); if not here then return nil end
    local best, bd
    for i, s in pairs(stores) do
        local d = #(here - clerkPos(s))
        if d < 25.0 and (not bd or d < bd) then best, bd = i, d end
    end
    return best
end

lib.addCommand('heistspots', { help = 'أماكن السطو: خزنة المتجر', restricted = 'group.admin' }, function(src)
    local i = nearestStore(src)
    if not i then return H.notify(src, 'قف داخل متجر (24/7 أو LTD أو محل مشروبات)', 'error') end
    local s = stores[i]
    TriggerClientEvent('exti_heists:client:spotsMenu', src, i, s.area, s.layout, spots.safes[s.key] ~= nil)
end)

lib.callback.register('exti_heists:server:spotSave', function(src, what, i)
    if not isAdmin(src) then return false end
    i = math.tointeger(i)
    local s = i and stores[i]; if not s then return false end
    if what == 'safe' then
        local ped = GetPlayerPed(src)
        local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
        if #(c - clerkPos(s)) > 25.0 then return false end
        spots.safes[s.key] = { x = c.x, y = c.y, z = c.z, h = h }
        saveSpots()
        return true, 'حُفظت الخزنة'
    elseif what == 'clear' then
        spots.safes[s.key] = nil; saveSpots(); return true, 'مُسحت'
    elseif what == 'copy' then
        local sp = spots.safes[s.key]; if not sp then return false, 'ضع الخزنة هنا أولًا' end
        -- the spot in the clerk's own frame, then into every store with the same room
        local function frame(cl) local h = math.rad(cl.w); return vec3(math.cos(h), math.sin(h), 0.0), vec3(-math.sin(h), math.cos(h), 0.0) end
        local r0, f0 = frame(s.clerk)
        local dx, dy = sp.x - s.clerk.x, sp.y - s.clerk.y
        local a, b, up = dx * r0.x + dy * r0.y, dx * f0.x + dy * f0.y, sp.z - s.clerk.z
        local dh = sp.h and (sp.h - s.clerk.w) or nil
        local n = 0
        for _, o in pairs(stores) do
            if o ~= s and o.layout == s.layout and not (spots.safes[o.key] and not spots.safes[o.key].copied) then
                local r, f = frame(o.clerk)
                local p = vec3(o.clerk.x, o.clerk.y, o.clerk.z) + r * a + f * b
                spots.safes[o.key] = { x = p.x, y = p.y, z = o.clerk.z + up, h = dh and (o.clerk.w + dh) % 360 or nil, copied = true }
                n = n + 1
            end
        end
        saveSpots()
        return true, ('نُسخت الخزنة إلى %d متجر بنفس الشكل'):format(n)
    end
    return false
end)

-- admins (F1): clear every store cooldown
function H.resetStores()
    for k in pairs(H.cooldowns) do if k:sub(1, 6) == 'store:' then H.clearCooldown(k) end end
    state, safes, down = {}, {}, {}
    publish()
end

AddEventHandler('playerDropped', function()
    local src = source
    for i, st in pairs(state) do if st.by == src and st.phase ~= 'emptied' then state[i] = nil end end
    publish()
end)

-- the Crew app's heist board
H.registerHeist({ id = 'register', label = 'صندوق محل', tier = R.tier, where = '20 محلًا', status = function() return 'ready', 0, ('كل محل كل %d دقيقة'):format(R.cooldownMinutes) end })
H.registerHeist({ id = 'storesafe', label = 'خزنة محل', tier = S.tier, where = 'الغرفة الخلفية', status = function() return 'ready', 0, ('كل خزنة كل %d دقيقة'):format(S.cooldownMinutes) end })
