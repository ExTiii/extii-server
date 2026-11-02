-- =====================================================================
-- EX_Tii gangs: the shared collection point, handing parts in at HQ (paid from the gang bank),
-- the fence, and the gang stash rules (who may take what out).
-- =====================================================================
local ox = exports.ox_inventory
local pending = {}   -- [source] = { crate, token, at }
local busy = {}      -- [source] = true while a hand-in runs

-- parts a member collected himself and wasn't paid for yet (only these are paid on hand-in, so parts
-- taken out of the stash can't be handed in again for pay)
local owed = {}
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_owed` (
        `citizenid` VARCHAR(60) NOT NULL PRIMARY KEY,
        `count` INT NOT NULL DEFAULT 0
    )]])
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `exti_gang_owed`') or {}) do owed[row.citizenid] = row.count end
end)
local function setOwed(cid, n)
    owed[cid] = math.max(0, n)
    MySQL.query('INSERT INTO `exti_gang_owed` (`citizenid`, `count`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `count` = VALUES(`count`)', { cid, owed[cid] })
end

local function partOf(g) return C.types[g.type].part end
local allParts = {}
for _, t in pairs(C.types) do allParts[t.part] = true end

---------------------------------------------------------------------------
-- collection: E at a crate -> 25 s + 2 skill checks -> 3 parts of your gang's type
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:collectBegin', function(source, crate)
    local g, m = GANG.memberOf(source)
    if not g then return false, 'nogang' end
    if not C.types[g.type].ready then return false, 'soon' end
    local c = math.type(crate) == 'integer' and GANG.spots.collect.crates[crate]
    if not c or not GANG.near(source, c, 2.6) then return false, 'far' end
    local cid = m.citizenid
    local wait = math.max(GANG.cooldownLeft('collect:' .. cid), GANG.cooldownLeft('collectfail:' .. cid))
    if wait > 0 then return false, 'cooldown', wait end
    local cw = GANG.cooldownLeft('crate:' .. crate)
    if cw > 0 then return false, 'crate', cw end
    if GANG.getDaily('m', cid, 'collected') + C.collect.give > C.collect.memberDaily then return false, 'daily' end
    if not ox:CanCarryItem(source, partOf(g), C.collect.give) then return false, 'full' end
    local token = math.random(100000, 999999)
    pending[source] = { crate = crate, token = token, at = os.time() }
    GANG.setCooldown('crate:' .. crate, 30) -- hold the crate while this run is going
    return true, { token = token, seconds = C.collect.seconds, checks = C.collect.checks }
end)

lib.callback.register('exti_gangs:server:collectFinish', function(source, token, passed)
    local p = pending[source]
    pending[source] = nil
    local g, m = GANG.memberOf(source)
    if not p or not g or p.token ~= token then return false, 'failed' end
    local c = GANG.spots.collect.crates[p.crate]
    if not c or not GANG.near(source, c, 3.5) then return false, 'far' end
    if passed ~= true then
        GANG.setCooldown('collectfail:' .. m.citizenid, C.collect.failWait)
        GANG.setCooldown('crate:' .. p.crate, C.collect.crateCooldown)
        return false, 'skill'
    end
    if os.time() - p.at < C.collect.seconds - 2 then return false, 'fast' end
    local item = partOf(g)
    if not ox:CanCarryItem(source, item, C.collect.give) or not ox:AddItem(source, item, C.collect.give) then return false, 'full' end
    GANG.setCooldown('collect:' .. m.citizenid, C.collect.personalCooldown)
    GANG.setCooldown('crate:' .. p.crate, C.collect.crateCooldown)
    GANG.addDaily('m', m.citizenid, 'collected', C.collect.give)
    setOwed(m.citizenid, (owed[m.citizenid] or 0) + C.collect.give)
    return true, { item = item, count = C.collect.give }
end)

RegisterNetEvent('exti_gangs:server:collectCancel', function() pending[source] = nil end)

---------------------------------------------------------------------------
-- handing parts in at HQ: paid on deposit (so parts can be robbed on the way back)
---------------------------------------------------------------------------
local function deposit(source)
    local g, m, p = GANG.memberOf(source)
    if not g then return false, 'nogang' end
    if not GANG.near(source, GANG.spot(g, 'deposit') or GANG.spot(g, 'stash'), 3.0) then return false, 'far' end
    if g.locked then return false, 'locked' end
    if not g.settings.deposits then return false, 'closed' end
    local item = partOf(g)
    local have = ox:GetItemCount(source, item) or 0
    if have < 1 then return false, 'none' end
    local _, L = GANG.level(g)
    local roomGang = L.partsDaily - GANG.getDaily('g', g.name, 'parts')
    local roomMe = C.collect.memberDaily - GANG.getDaily('m', m.citizenid, 'parts')
    local mine = owed[m.citizenid] or 0
    local n = math.min(have, roomGang, roomMe, mine)
    if n < 1 then
        if mine < 1 then return false, 'notmine' end
        return false, roomGang < 1 and 'gangcap' or 'mecap'
    end
    local paid = m.rank == 3 and 0 or n * g.settings.partPay
    if g.bank < paid then
        GANG.toGang(g, ('بنك العصابة لا يكفي لدفع أجر القطع ($%d مطلوب). أودِعوا مالًا في البنك'):format(paid), 'error', 3)
        return false, 'bank', paid
    end
    local stash = GANG.stashId(g)
    if not ox:CanCarryItem(stash, item, n) then return false, 'stashfull' end
    if not ox:RemoveItem(source, item, n) then return false, 'none' end
    if not ox:AddItem(stash, item, n) then
        ox:AddItem(source, item, n)
        return false, 'stashfull'
    end
    if paid > 0 then
        g.bank = g.bank - paid; GANG.saveGang(g)
        p.Functions.AddMoney('cash', paid, 'gang-part-pay')
    end
    setOwed(m.citizenid, mine - n)
    GANG.addDaily('g', g.name, 'parts', n)
    GANG.addDaily('m', m.citizenid, 'parts', n)
    GANG.addDaily('m', m.citizenid, 'paid', paid)
    GANG.addRep(g, C.rep.gain.part * n, 'parts')
    GANG.log(g, GANG.charName(p), 'parts_in', ('%d × %s · أجر $%d'):format(n, item, paid))
    return true, { count = n, paid = paid, left = have - n }
end

lib.callback.register('exti_gangs:server:deposit', function(source)
    if busy[source] then return false, 'failed' end
    busy[source] = true
    local ok, a, b, c = pcall(deposit, source)
    busy[source] = nil
    if not ok then lib.print.error('deposit: ' .. tostring(a)) return false, 'failed' end
    return a, b, c
end)
AddEventHandler('playerDropped', function() busy[source] = nil; pending[source] = nil end)

---------------------------------------------------------------------------
-- the fence: buys stolen parts of any gang for dirty money
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:fence', function(source)
    local f = GANG.spots.fence
    if not f or not GANG.near(source, f, 3.0) then return false, 'far' end
    local p = GANG.player(source)
    local total, sold, took = 0, 0, {}
    for item in pairs(allParts) do
        local n = ox:GetItemCount(source, item) or 0
        if n > 0 and ox:RemoveItem(source, item, n) then sold = sold + n; took[item] = n end
    end
    if sold < 1 then return false, 'none' end
    total = sold * C.fence.price
    if not ox:AddItem(source, 'black_money', total) then
        for item, n in pairs(took) do ox:AddItem(source, item, n) end -- nothing lost
        return false, 'full'
    end
    GANG.log('-', GANG.charName(p), 'fence', ('%d قطعة · $%d'):format(sold, total))
    return true, { count = sold, money = total }
end)

---------------------------------------------------------------------------
-- the gang stash: any member opens it at HQ; Runners can't take out, Crew has a daily value limit
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:openStash', function(source)
    local g = GANG.memberOf(source)
    if not g then return false, 'nogang' end
    if not GANG.near(source, GANG.spot(g, 'stash'), 3.0) then return false, 'far' end
    if g.locked then return false, 'locked' end
    return GANG.stashId(g)
end)

local function gangOfStash(id)
    local name = type(id) == 'string' and id:match('^gang_(.+)$')
    return name and GANG.gangs[name]
end

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
    ox:registerHook('swapItems', function(payload)
        local fromStash = payload.fromType == 'stash' and gangOfStash(payload.fromInventory)
        local toStash = payload.toType == 'stash' and gangOfStash(payload.toInventory)
        if not fromStash and not toStash then return end
        local g = fromStash or toStash
        local src = payload.source
        local mg, m, p = GANG.memberOf(src)
        if not mg or mg.name ~= g.name then return false end
        if g.locked then GANG.notify(src, 'المقر مقفل: لم يُدفع الإيجار', 'error') return false end
        -- the stash only works at the HQ (a modified game can't open it from across the map)
        if not GANG.near(src, GANG.spot(g, 'stash'), 4.0) then return false end
        -- what leaves the stash in this move: a normal move takes from the stash; a swap also brings
        -- the stash item of the other slot out (and always whole stacks)
        local takes = {}
        if fromStash and not toStash then
            local count = payload.action == 'swap' and (payload.fromSlot and payload.fromSlot.count) or payload.count
            takes[#takes + 1] = { item = payload.fromSlot and payload.fromSlot.name, count = tonumber(count) or 0 }
        elseif toStash and not fromStash and payload.action == 'swap' and payload.toSlot and payload.toSlot.name then
            takes[#takes + 1] = { item = payload.toSlot.name, count = tonumber(payload.toSlot.count) or 0 }
        end
        if #takes == 0 then return end
        if m.rank == 0 then GANG.notify(src, 'العدّاء لا يأخذ من المخزن', 'error') return false end
        if m.rank == 1 then
            local value = 0
            for _, t in ipairs(takes) do value = value + (C.itemValue[t.item] or 100) * math.max(1, t.count) end
            local used = GANG.getDaily('m', m.citizenid, 'take')
            if used + value > C.crewDailyTake then
                GANG.notify(src, ('حدّك اليومي للأخذ من المخزن $%d (استعملت $%d)'):format(C.crewDailyTake, used), 'error')
                return false
            end
            GANG.addDaily('m', m.citizenid, 'take', value)
        end
        for _, t in ipairs(takes) do GANG.log(g, GANG.charName(p), 'stash_take', ('%d × %s'):format(t.count, tostring(t.item))) end
    end, { inventoryFilter = { '^gang_' } })
end)
