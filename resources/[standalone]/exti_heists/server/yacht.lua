-- =====================================================================
-- EX_Tii heists: the yacht (Tier 9, police only). Text the Broker "يخت": a red USB, two C4, the catering
-- uniform (the prep: in it the crew on deck takes you for staff a while longer) and $35,000 from your bank.
-- Armed men on the decks, a boat of reinforcements. The bridge lock (the laptop), the captain's safe
-- (two C4, the wiring game, the blast), then empty it.
-- =====================================================================
local C = Config
local Y = C.yacht
local KEY = 'yacht'
local SITE = 'yacht'

local st = { phase = 'idle', step = 0, crew = {}, looted = {} }
local function publish() GlobalState['exti_heists:yacht'] = { phase = st.phase, step = st.step, fuseLeft = st.fuseAt and math.max(0, st.fuseAt - H.now()) or nil, emptied = st.emptied } end
CreateThread(function() Wait(1500); publish() end)
local function reset() H.guardEnd(SITE); st = { phase = 'idle', step = 0, crew = {}, looted = {} }; publish() end
function H.resetYacht() H.clearCooldown(KEY); reset() end

local function stepAt(k) return (H.spotFix and H.spotFix('yacht', k)) or Y.steps[k].at end
H.yachtStepAt = stepAt

function H.startYacht(src)
    if st.phase ~= 'idle' then return false, 'اليخت مشغول الآن' end
    local left = H.cooldownLeft(KEY)
    if left > 0 then return false, ('اليخت في البحر بعيدًا. يعود بعد %d ساعة'):format(math.ceil(left / 3600)) end
    if H.isCopOnDuty(src) or H.isHot(src) then return false, 'ليس الآن' end
    local ok, need = H.canTier(src, Y.tier, true)
    if not ok then return false, ('تحتاج سمعة %d'):format(need) end
    local mode, need2 = H.modeFor(Y.tier)
    if not mode then return false, ('أحتاج %d شرطة في الخدمة: لا يُسرق اليخت بلا شرطة'):format(need2 or 0) end
    if (exports.ox_inventory:Search(src, 'count', Y.needs.usb) or 0) < 1 then return false, 'تحتاج فلاشة حمراء' end
    if (exports.ox_inventory:Search(src, 'count', 'c4') or 0) < Y.needs.c4 then return false, ('تحتاج %d C4'):format(Y.needs.c4) end
    if not H.hasPrep(src, Y.needs.prep) then return false, 'تحتاج زي شركة التموين (تحضير: اكتب للمصرّف "تحضير يخت")' end
    local p = H.player(src)
    if not p or (p.PlayerData.money.bank or 0) < Y.cost then return false, ('أحتاج %d$ من حسابك في البنك'):format(Y.cost) end
    p.Functions.RemoveMoney('bank', Y.cost, 'heist-setup')
    H.takePrep(src, Y.needs.prep)
    st = { phase = 'on', step = 0, crew = { [src] = true }, looted = {}, mode = mode, by = src, at = H.now() }
    H.setCooldown(KEY, Y.cooldownMinutes * 60)
    H.setHeat(src, Y.tier)
    local site = H.guardSite(SITE, Y)
    H.guardBlind(SITE)   -- (the uniform: the deck crew is slow to notice)
    site.onAlert = function(by)
        if GetResourceState('exti_police') == 'started' then
            pcall(function()
                exports.exti_police:AddCall({ kind = 'alarm', label = C.calls.yacht, coords = { x = Y.center.x, y = Y.center.y, z = Y.center.z },
                    text = 'إطلاق نار على يخت قبالة الساحل', number = 'خفر السواحل', suspect = by })
            end)
        end
    end
    publish()
    H.log(src, 'yacht_start', H.modeText(mode))
    local mark = st
    SetTimeout(35 * 60 * 1000, function() if st == mark then reset() end end)
    return true, Y.center
end

lib.callback.register('exti_heists:server:yachtStepBegin', function(src, k)
    k = math.tointeger(k)
    local step = k and Y.steps[k]
    if st.busy and H.now() - (st.busyAt or 0) > (C.games.maxSeconds or 240) then st.busy = nil end
    if st.fuseAt then return false, 'الفتيل يعمل!' end
    if not step or st.phase ~= 'on' or st.busy or k ~= st.step + 1 or H.isCopOnDuty(src) or not H.near(src, stepAt(k), 2.4) then return false end
    local n = step.count or 1
    if step.item and (exports.ox_inventory:Search(src, 'count', step.item) or 0) < n then return false, ('تحتاج %d %s'):format(n, step.item) end
    if step.item then exports.ox_inventory:RemoveItem(src, step.item, n) end
    st.busy, st.busyAt = src, H.now(); st.crew[src] = true
    H.touch(src, stepAt(k))
    local skill = step.game == 'hack' and 'hacking' or 'breaching'
    local lv = H.skillLevel(H.rec(src), skill)
    local params = { time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
    for kk, vv in pairs(step.params or {}) do params[kk] = vv end
    return true, H.gameBegin(src, step.game, { yacht = k, skill = skill }), step.game, params
end)

lib.callback.register('exti_heists:server:yachtStepEnd', function(src, token, game, passed)
    local ctx = H.gameEnd(src, tostring(game), token, passed == true)
    if st.busy == src then st.busy = nil end
    if not ctx or not ctx.yacht or st.phase ~= 'on' then return false end
    local k = ctx.yacht
    if not passed then H.guardRaise(SITE, src, 'failed'); return false, 'failed' end
    if not H.near(src, stepAt(k), 3.0) then return false end
    H.addSkill(src, ctx.skill)
    local step = Y.steps[k]
    if step.blast then
        st.fuseAt = H.now() + step.blast; publish()
        local mark = st
        SetTimeout(step.blast * 1000, function()
            if st ~= mark then return end
            mark.fuseAt = nil; mark.step = k; publish()
            local p = stepAt(k)
            local who = GetPlayerName(src) and src or nil
            if not who then for x in pairs(mark.crew) do if GetPlayerName(x) then who = x break end end end
            if who then TriggerClientEvent('exti_heists:client:blast', who, { x = p.x, y = p.y, z = p.z }) end
            H.guardRaise(SITE, src, 'blast')
        end)
        return true, step.blast
    end
    st.step = k; publish()
    return true
end)

-- the safe is open: empty it (one person, 10 s)
lib.callback.register('exti_heists:server:yachtLoot', function(src)
    if st.phase ~= 'on' or st.step < #Y.steps or st.emptied or H.isCopOnDuty(src) then return false end
    local at = stepAt(#Y.steps)
    if not H.near(src, at, 2.4) then return false end
    st.emptied = true; publish()
    local pay = H.payOf(Y.loot.money, st.mode)
    H.giveLoot(src, 'black_money', pay)
    local bars = math.random(Y.loot.bars[1], Y.loot.bars[2])
    H.giveLoot(src, 'vault_goldbar', bars)
    local usb = Y.loot.usb and math.random() < Y.loot.usb.chance
    if usb then exports.ox_inventory:AddItem(src, Y.loot.usb.item, 1) end
    for x in pairs(st.crew) do if GetPlayerName(x) then H.repFor(x, Y.tier, st.mode) end end
    if H.title then for x in pairs(st.crew) do H.title(x, 'yacht', 'قرصان اليخت') end end
    H.log(src, 'yacht_loot', ('$%d + %d bars%s'):format(pay, bars, usb and ' + gold USB' or ''))
    local mark = st
    SetTimeout(5 * 60 * 1000, function() if st == mark then reset() end end)
    return true, { money = pay, bars = bars, usb = usb }
end)

H.registerHeist({ id = 'yacht', label = Y.label, tier = Y.tier, where = 'فلاشة حمراء + C4 ×2 + زي التموين + 35,000$', status = function()
    if st.phase ~= 'idle' then return 'busy', 0, 'يُسرق الآن' end
    local left = H.cooldownLeft(KEY)
    if left > 0 then return 'cooldown', left end
    return 'ready', 0, 'اكتب للوسيط "يخت"'
end })
