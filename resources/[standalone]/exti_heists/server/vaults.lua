-- =====================================================================
-- EX_Tii heists: banks (vaults). Fleeca now (Tier 4); Paleto and Pacific use the same engine (M4).
-- A bank is a list of steps, each a minigame at a spot (cut the alarm loop, hack the vault lock, ...),
-- then a time lock, the door swings open, and the deposit boxes are drilled one by one.
--   * one bank at a time in the whole city; each bank its own cooldown
--   * the mode (police / no police) locks at the first step; Tier 7+ never without real police
--   * the alarm: a failed step = at once; the vault hack = a late alarm (or at once without the panel cut)
--   * marked bills: the police get a trace while they are hot (exti_police)
-- =====================================================================
local C = Config

local st = {}   -- [id] = { phase, step (last done), mode, leader, crew = {}, doors = {}, lockers = {}, alarm, readyAt, cut }
local function blank() return { phase = 'idle', step = 0, crew = {}, doors = {}, lockers = {}, looted = {}, alarm = false } end
for id in pairs(C.vaults) do st[id] = blank() end

local function cdKey(id) return 'vault:' .. id end
local function dayKey() return os.date('%Y-%m-%d') end
-- today's hot Fleeca (the same all day, a new one tomorrow)
local function hotBranch()
    local list = {}
    for id, v in pairs(C.vaults) do if v.kind == 'fleeca' then list[#list + 1] = id end end
    table.sort(list)
    if #list == 0 then return nil end
    local n = 0
    for ch in dayKey():gmatch('%d') do n = n * 7 + tonumber(ch) end
    return list[(n % #list) + 1]
end
H.hotBranch = hotBranch

local function publish()
    local out = {}
    for id, s in pairs(st) do
        out[id] = { phase = s.phase, step = s.step, doors = s.doors, lockers = s.lockers, alarm = s.alarm,
                    lockLeft = s.readyAt and math.max(0, s.readyAt - H.now()) or nil, fuseLeft = s.fuseAt and math.max(0, s.fuseAt - H.now()) or nil,
                    cooldown = H.cooldownLeft(cdKey(id)) }
    end
    GlobalState['exti_heists:vaults'] = out
end
CreateThread(function() Wait(1500); publish() end)

-- another bank running right now?
function H.bankBusy(except)
    if not C.bankLock then return false end
    for id, s in pairs(st) do if id ~= except and s.phase ~= 'idle' and s.phase ~= 'done' then return true end end
    return false
end

local function crewList(s) local t = {} for x in pairs(s.crew) do t[#t + 1] = x end return t end
-- a step's / a box's spot (an admin's /heistspot fix wins over the config)
local function stepAt(id, k) return (H.spotFix and H.spotFix(id, k)) or C.vaults[id].steps[k].at end
local function boxAt(id, i) return (H.spotFix and H.spotFix(id, 'box' .. i)) or C.vaults[id].lockers[i] end

local function alarm(id, src, late)
    local v, s = C.vaults[id], st[id]
    if s.alarm then return end
    s.alarm = true; publish()
    local list = crewList(s)
    if #list == 0 and src then list[1] = src end
    if GetResourceState('exti_police') == 'started' then
        pcall(function()
            local label = C.calls[v.kind] or C.calls.fleeca
            if late and v.kind == 'fleeca' then label = C.calls.fleecaQuiet end
            exports.exti_police:AddCall({ kind = 'alarm', label = label, coords = { x = v.center.x, y = v.center.y, z = v.center.z },
                text = ('%s · %s'):format(v.label, late and 'إنذار الخزنة' or 'إنذار البنك'), number = 'إنذار البنك', suspect = list[1] })
        end)
    end
    if s.mode and not s.mode.police and #list > 0 then H.npcRespond(list, v.center, 'bank') end
    for x in pairs(s.crew) do TriggerClientEvent('exti_heists:client:vaultAlarm', x, id) end
    H.log(list[1], 'vault_alarm', ('%s%s'):format(v.label, late and ' (late)' or ''))
end

local function reset(id)
    if C.vaults[id].guards then H.guardEnd('vault:' .. id) end
    st[id] = blank(); publish()
    TriggerClientEvent('exti_heists:client:vaultReset', -1, id)
end
function H.resetVaults() for id in pairs(C.vaults) do H.clearCooldown(cdKey(id)); reset(id) end end

-- the first step: the mode, the cooldown, the bank lock
local function begin(id, src)
    local v, s = C.vaults[id], st[id]
    if s.phase ~= 'idle' then return true end
    local left = H.cooldownLeft(cdKey(id))
    if left > 0 then return false, ('الخزنة فارغة: تعود بعد %s'):format(H.mmss(left)) end
    if H.bankBusy(id) then return false, 'بنك آخر يُسرق الآن في المدينة. انتظر' end
    if H.isHot(src) and v.tier >= 4 then return false, 'أنت مطلوب الآن: انتظر حتى تبرد' end
    local ok, need = H.canTier(src, v.tier, true)
    if not ok then return false, ('تحتاج سمعة %d لهذا البنك'):format(need) end
    local mode, need2 = H.modeFor(v.tier)
    if not mode then return false, ('تحتاج %d شرطة في الخدمة'):format(need2 or 0) end
    -- the big banks: the setup fee (clean money) and the preps, all checked before anything is taken
    for _, pk in ipairs({ v.prep, v.prep2 }) do
        if pk and not H.hasPrep(src, pk) then return false, ('ينقصك التحضير: %s'):format(C.preps[pk] and C.preps[pk].label or pk) end
    end
    local p = H.player(src)
    if (v.cost or 0) > 0 and (not p or (p.PlayerData.money.bank or 0) < v.cost) then return false, ('تحتاج %d$ في حسابك في البنك (تكاليف التحضير)'):format(v.cost) end
    if (v.cost or 0) > 0 then p.Functions.RemoveMoney('bank', v.cost, 'heist-setup') end
    for _, pk in ipairs({ v.prep, v.prep2 }) do if pk then H.takePrep(src, pk) end end
    s.phase, s.mode, s.leader, s.at = 'on', mode, src, H.now()
    s.downed = {}
    if v.special then
        local a = math.random(#v.lockers); local b = a
        while b == a and #v.lockers > 1 do b = math.random(#v.lockers) end
        s.special = { [a] = true, [b] = true }
    end
    if v.guards then
        local site = H.guardSite('vault:' .. id, v.guards)
        site.onAlert = function(by) alarm(id, by) end
    end
    H.setCooldown(cdKey(id), v.cooldownMinutes * 60)
    publish()
    H.log(src, 'vault_start', ('%s · %s%s'):format(v.label, H.modeText(mode), hotBranch() == id and ' · HOT' or ''))
    -- the bank closes itself 25 minutes after it started, whatever happened
    local mark = s
    SetTimeout(25 * 60 * 1000, function()
        if st[id] ~= mark then return end
        for x in pairs(mark.looted) do if GetPlayerName(x) and not (mark.repDone and mark.repDone[x]) then H.repFor(x, v.tier, mark.mode) end end
        reset(id)
    end)
    return true
end

---------------------------------------------------------------------------
-- the steps
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:vaultStepBegin', function(src, id, k)
    local v, s = C.vaults[id], st[id]
    k = math.tointeger(k)
    local step = v and k and v.steps[k]
    if not step or H.isCopOnDuty(src) or not H.near(src, stepAt(id, k), 2.2) then return false end
    if s.busy and H.now() - (s.busyAt or 0) > (C.games.maxSeconds or 240) then s.busy = nil end
    if s.phase == 'done' or s.busy then return false, s.busy and 'أحدٌ يعمل هنا' or nil end
    -- the order: every step before this one done (an optional one may be skipped)
    if k <= s.step then return false, 'تم هذا' end
    for j = s.step + 1, k - 1 do if not v.steps[j].optional then return false, 'ليس بعد' end end
    if s.fuseAt then return false, 'الفتيل يعمل!' end
    local count = step.count or 1
    if step.item and (exports.ox_inventory:Search(src, 'count', step.item) or 0) < count then
        local need = ({ usb_green = 'تحتاج فلاشة خضراء', usb_blue = 'تحتاج فلاشة زرقاء', usb_red = 'تحتاج فلاشة حمراء', usb_gold = 'تحتاج فلاشة ذهبية', c4 = ('تحتاج %d C4'):format(count) })[step.item]
        return false, need or 'ينقصك شيء'
    end
    local ok, why = begin(id, src); if not ok then return false, why end
    -- (the USB / the C4 is gone the moment it goes in)
    if step.item then exports.ox_inventory:RemoveItem(src, step.item, count); H.log(src, 'item_used', ('%dx %s · %s'):format(count, step.item, v.label)) end
    s.crew[src] = true; s.busy, s.busyAt = src, H.now()
    H.setHeat(src, v.tier)
    H.touch(src, stepAt(id, k))
    if step.alarm == 'start' then alarm(id, src) end
    local skill = ({ hack = 'hacking', keypad = 'hacking', wirecut = 'breaching', c4 = 'breaching', drill = 'breaching', glasscut = 'breaching', lockpick = 'lockpick', safedial = 'breaching' })[step.game] or 'breaching'
    local lv = H.skillLevel(H.rec(src), skill)
    local params = {}
    for kk, vv in pairs(step.params or {}) do params[kk] = vv end
    params.time = 1.0 + (lv - 1) * C.skills.timeBonus; params.level = lv
    -- the blueprints (a crew member carries them): the keypad's first digit is known
    if step.game == 'keypad' and H.hasPrep(src, 'blueprints') then params.hint = true end
    return true, H.gameBegin(src, step.game, { vault = id, step = k, skill = skill }), step.game, params
end)

lib.callback.register('exti_heists:server:vaultStepEnd', function(src, token, game, passed)
    local ctx = H.gameEnd(src, tostring(game), token, passed == true)
    local id = ctx and ctx.vault
    local v, s = id and C.vaults[id], id and st[id]
    if not v then
        -- (a refused result: whatever bank he was on is free again)
        for _, x in pairs(st) do if x.busy == src then x.busy = nil end end
        return false
    end
    if s.busy ~= src then return false end
    s.busy = nil
    local k, step = ctx.step, v.steps[ctx.step]
    if not passed then
        if step.alarm == 'fail' or step.alarm == 'quiet' then alarm(id, src) end
        return false, 'failed'
    end
    if not H.near(src, stepAt(id, k), 3.0) then return false end
    s.step = math.max(s.step, k)
    H.addSkill(src, ctx.skill)
    if step.quiet then s.cut = true end
    if step.alarm == 'quiet' then
        -- the vault lock: a late alarm if the panel was cut first, else now
        if s.cut then
            local mark = s
            SetTimeout(v.quietSeconds * 1000, function() if st[id] == mark then alarm(id, src, true) end end)
        else
            alarm(id, src)
        end
    end
    -- the boxes open up after the last step; a door opens after its own
    local last = k == #v.steps
    local function opened(mark)
        if step.opens then mark.doors[step.opens] = true end
        if last then mark.phase = 'open'; for x in pairs(mark.crew) do TriggerClientEvent('exti_heists:client:vaultOpen', x, id) end end
        publish()
    end
    local wait = step.timelock or step.blast
    if wait then
        if step.blast then s.fuseAt = H.now() + step.blast else s.readyAt = H.now() + step.timelock end
        publish()
        local mark = s
        SetTimeout(wait * 1000, function()
            if st[id] ~= mark then return end
            mark.readyAt, mark.fuseAt = nil, nil
            if step.blast then
                local p = stepAt(id, k)
                local who = GetPlayerName(src) and src or nil
                if not who then for x in pairs(mark.crew) do if GetPlayerName(x) then who = x break end end end
                if who then TriggerClientEvent('exti_heists:client:blast', who, { x = p.x, y = p.y, z = p.z }) end
            end
            opened(mark)
        end)
    else
        opened(s)
    end
    H.log(src, 'vault_step', ('%s · %s'):format(v.label, step.id))
    return true, step.timelock, step.blast
end)

---------------------------------------------------------------------------
-- the deposit boxes (drill)
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:vaultBoxBegin', function(src, id, i)
    local v, s = C.vaults[id], st[id]
    i = math.tointeger(i)
    local pos = v and i and v.lockers[i] and boxAt(id, i)
    if not pos or s.phase ~= 'open' or s.lockers[i] or H.isCopOnDuty(src) or not H.near(src, pos, 1.8) then return false end
    if s.boxBusy and s.boxBusy[i] then return false, 'أحدٌ يعمل عليها' end
    if (exports.ox_inventory:Search(src, 'count', 'drill') or 0) < 1 then return false, 'تحتاج مثقابًا' end
    if (exports.ox_inventory:Search(src, 'count', 'drill_bit') or 0) < 1 then return false, 'تحتاج رأس مثقاب' end
    s.boxBusy = s.boxBusy or {}; s.boxBusy[i] = src
    s.crew[src] = true
    H.setHeat(src, v.tier)
    local lv = H.skillLevel(H.rec(src), 'breaching')
    return true, H.gameBegin(src, 'drill', { vault = id, box = i }), { time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:vaultBoxEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'drill', token, passed == true)
    if not ctx then
        for _, s in pairs(st) do if s.boxBusy then for i, w in pairs(s.boxBusy) do if w == src then s.boxBusy[i] = nil end end end end
        return false
    end
    local id, i = ctx.vault, ctx.box
    local v, s = C.vaults[id], st[id]
    if s.boxBusy then s.boxBusy[i] = nil end
    if s.phase ~= 'open' or s.lockers[i] then return false end
    if not passed then
        exports.ox_inventory:RemoveItem(src, 'drill_bit', 1)
        return false, 'bit'
    end
    if not H.near(src, boxAt(id, i), 2.4) then return false end
    s.lockers[i] = true; publish()
    H.touch(src, boxAt(id, i))
    local L = v.loot
    local pay = H.payOf(L.money, s.mode)
    if hotBranch() == id then pay = math.floor(pay * C.hotBranch.mult) end
    local md = L.item == 'marked_bills' and { trace = H.now() + 600, bank = v.label } or nil
    H.giveLoot(src, L.item, pay, md)
    local usb = L.usb and math.random() < L.usb.chance * (s.mode.usb or 1)
    if usb then exports.ox_inventory:AddItem(src, L.usb.item, 1) end
    local extra
    for _, e in ipairs(L.extra or {}) do
        if math.random() < e.chance then extra = e.item; H.giveLoot(src, e.item, math.random(e.amount[1], e.amount[2])) end
    end
    -- Pacific: this week's special sits in two of the boxes
    if v.special and s.special and s.special[i] and H.pacificSpecial then
        local sp = H.pacificSpecial()
        H.giveLoot(src, sp.item, math.random(sp.amount[1], sp.amount[2]))
        extra = sp.item
    end
    H.addSkill(src, 'breaching')
    s.looted[src] = true
    if H.contract then H.contract(src, v.kind) end
    H.log(src, 'vault_box', ('%s · box %d · $%d%s%s'):format(v.label, i, pay, usb and (' + ' .. L.usb.item) or '', extra and (' + ' .. extra) or ''))
    -- every box open: done (Rep comes as each looter leaves the bank)
    local n = 0
    for _ in pairs(s.lockers) do n = n + 1 end
    if n >= #v.lockers then
        s.phase = 'done'; publish()
        if v.kind == 'pacific' and H.title then
            local first = GetResourceKvpInt('first:pacific') ~= 1
            if first then SetResourceKvpInt('first:pacific', 1) end
            for x in pairs(s.looted) do
                if GetPlayerName(x) then
                    if first then H.title(x, 'first_pacific', 'أول من سرق باسيفيك ستاندرد') end
                    if not next(s.downed or {}) then H.title(x, 'pacific_clean', 'باسيفيك بلا إصابات') end
                end
            end
        end
    end
    return true, { money = pay, item = L.item, usb = usb and L.usb.item or nil, extra = extra }
end)

-- the Rep: once for each looter, when he leaves the bank
CreateThread(function()
    while true do
        Wait(3000)
        for id, s in pairs(st) do
            if s.phase ~= 'idle' and next(s.looted) then
                local v = C.vaults[id]
                for x in pairs(s.looted) do
                    s.repDone = s.repDone or {}
                    if not s.repDone[x] and GetPlayerName(x) and not H.near(x, v.center, v.radius + 25.0) then
                        s.repDone[x] = true
                        H.repFor(x, v.tier, s.mode)
                    end
                end
            end
        end
    end
end)

-- a robber of a running bank went down (for "nobody downed")
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bag, _, value)
    if value == nil or value == 1 then return end
    local src = GetPlayerFromStateBagName(bag)
    if not src or src == 0 then return end
    for _, s in pairs(st) do if s.phase ~= 'idle' and s.crew[src] then s.downed = s.downed or {}; s.downed[src] = true end end
end)

-- Pacific's laser grid: a beam touched
RegisterNetEvent('exti_heists:server:vaultLaser', function(id)
    local src = source
    local v, s = C.vaults[id], st[id]
    if not v or not v.laserArea or not s or s.phase ~= 'on' or H.isCopOnDuty(src) then return end
    local a, b = v.laserArea.a, v.laserArea.b
    if not H.near(src, (a + b) / 2, #(b - a) / 2 + 12.0) then return end
    s.crew[src] = true
    H.log(src, 'vault_laser', v.label)
    alarm(id, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, s in pairs(st) do
        if s.busy == src then s.busy = nil end
        if s.boxBusy then for i, w in pairs(s.boxBusy) do if w == src then s.boxBusy[i] = nil end end end
    end
end)

-- the Crew app's board: one line for all the Fleecas
H.registerHeist({ id = 'fleeca', label = 'بنك فليكا', tier = 4, where = '6 فروع', status = function()
    if H.bankBusy() then return 'busy', 0, 'بنك آخر يُسرق الآن' end
    local hot = hotBranch()
    local ready, soonest = 0, nil
    for id, v in pairs(C.vaults) do
        if v.kind == 'fleeca' then
            local left = H.cooldownLeft(cdKey(id))
            if left <= 0 then ready = ready + 1 elseif not soonest or left < soonest then soonest = left end
        end
    end
    if ready == 0 then return 'cooldown', soonest or 0 end
    return 'ready', 0, ('%d فروع جاهزة · فلاشة خضراء + مثقاب%s'):format(ready, hot and ' · المصرّف يعرف الفرع الساخن' or '')
end })

for _, bid in ipairs({ 'paleto', 'pacific' }) do
    local v = C.vaults[bid]
    if v then
        H.registerHeist({ id = bid, label = v.label, tier = v.tier, where = bid == 'pacific' and 'فلاشة حمراء + C4 ×2 + تحضيران + 25,000$' or 'فلاشة زرقاء + C4 + تحضير + 10,000$', status = function()
            local s = st[bid]
            if s.phase ~= 'idle' then return 'busy', 0, 'يُسرق الآن' end
            if H.bankBusy(bid) then return 'busy', 0, 'بنك آخر يُسرق الآن' end
            local left = H.cooldownLeft(cdKey(bid))
            if left > 0 then return 'cooldown', left end
            return 'ready', 0, 'بالشرطة فقط · اكتب للمصرّف "تحضير بنك"'
        end })
    end
end

-- admins (F1): the banks ready again
exports('ResetVaults', function() H.resetVaults() end)
