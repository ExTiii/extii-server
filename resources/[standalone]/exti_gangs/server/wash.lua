-- =====================================================================
-- EX_Tii gangs: the Money Wash.
--   * the drop box (outside the HQ, anyone): drop dirty money -> an order (the gang's cut is fixed on it),
--     collect the clean cash when it's ready, or cancel what isn't washed yet (the dirty money comes back)
--   * the machine (inside, Crew and up): a batch takes the oldest orders up to $5,000, needs 1 wash supplies
--     per $1,000 from the stash, 3 steps of work checked by the server (order + time)
--   * the gang's cut: 20% to the member who washed it (cash), the rest to the gang bank
--   * marked bills: now and then the police get an anonymous tip with the area
-- =====================================================================
local W = C.wash
local ox = exports.ox_inventory
local sessions = {}   -- [gang] = { src, cid, token, stage, stageAt, parts = { { id, amount } }, total, supplies }
local busyBox = {}    -- [src] = true while a drop box action runs

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_wash` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `gang` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `dirty` INT NOT NULL,
        `left` INT NOT NULL,
        `cut` INT NOT NULL,
        `ready` INT NOT NULL DEFAULT 0,
        `washing` INT NOT NULL DEFAULT 0,
        `closed` TINYINT NOT NULL DEFAULT 0,
        `created` INT NOT NULL,
        INDEX `gang_open` (`gang`, `closed`),
        INDEX `cid_open` (`citizenid`, `closed`)
    ) DEFAULT CHARSET=utf8mb4]])
    -- a batch that was in the machine when the server stopped goes back in the box (nothing is lost)
    MySQL.update.await('UPDATE `exti_gang_wash` SET `left` = `left` + `washing`, `washing` = 0, `closed` = 0 WHERE `washing` > 0')
end)

local function washGang(name)
    local g = type(name) == 'string' and GANG.gangs[name]
    return g and g.type == 'wash' and g or nil
end

local function myOrders(g, cid)
    return MySQL.query.await('SELECT `id`, `dirty`, `left`, `cut`, `ready`, `created` FROM `exti_gang_wash` WHERE `gang` = ? AND `citizenid` = ? AND `closed` = 0 ORDER BY `id`',
        { g.name, cid }) or {}
end

local function queueTotal(g)
    local r = MySQL.single.await('SELECT COALESCE(SUM(`left`), 0) AS `total`, COUNT(*) AS `n` FROM `exti_gang_wash` WHERE `gang` = ? AND `closed` = 0 AND `left` > 0', { g.name })
    return r and tonumber(r.total) or 0, r and tonumber(r.n) or 0
end

local function dailyLeft(g)
    local _, L = GANG.level(g)
    return math.max(0, (L.washDaily or 40000) - GANG.getDaily('g', g.name, 'washed'))
end

---------------------------------------------------------------------------
-- the drop box (anyone)
---------------------------------------------------------------------------
local function atBox(src, g) return GANG.near(src, GANG.spot(g, 'dropbox'), 2.5) end

lib.callback.register('exti_gangs:server:washBox', function(source, name)
    local g = washGang(name)
    if not g or not atBox(source, g) then return false, 'far' end
    local p = GANG.player(source)
    if not p then return false end
    local list = myOrders(g, p.PlayerData.citizenid)
    local ready, waiting = 0, 0
    for _, o in ipairs(list) do ready = ready + o.ready; waiting = waiting + o.left end
    return true, { label = g.label, cut = g.settings.washCut, ready = ready, waiting = waiting, orders = #list, maxOrders = W.openOrders,
                   min = W.dropMin, max = W.dropMax, dirty = (ox:GetItemCount(source, 'black_money') or 0) + (ox:GetItemCount(source, 'marked_bills') or 0), locked = g.locked }
end)

lib.callback.register('exti_gangs:server:washDrop', function(source, name, amount)
    local g = washGang(name)
    if not g or not atBox(source, g) then return false, 'far' end
    if g.locked then return false, 'closed' end
    if busyBox[source] then return false, 'busy' end
    amount = math.tointeger(tonumber(amount))
    if not amount or amount < W.dropMin or amount > W.dropMax then return false, 'amount' end
    local p = GANG.player(source)
    if not p then return false end
    busyBox[source] = true
    local cid = p.PlayerData.citizenid
    local ok, why = (function()
        if #myOrders(g, cid) >= W.openOrders then return false, 'orders' end
        local total = queueTotal(g)
        if total + amount > W.queueMax then return false, 'queue' end
        -- dirty money first, then marked bills from the heists (both wash the same way)
        local dirty, marked = ox:GetItemCount(source, 'black_money') or 0, ox:GetItemCount(source, 'marked_bills') or 0
        if dirty + marked < amount then return false, 'nomoney' end
        local fromDirty = math.min(dirty, amount)
        local fromMarked = amount - fromDirty
        if fromDirty > 0 and not ox:RemoveItem(source, 'black_money', fromDirty) then return false, 'nomoney' end
        if fromMarked > 0 and not ox:RemoveItem(source, 'marked_bills', fromMarked) then
            if fromDirty > 0 then ox:AddItem(source, 'black_money', fromDirty) end
            return false, 'nomoney'
        end
        local cut = g.settings.washCut
        local id = MySQL.insert.await('INSERT INTO `exti_gang_wash` (`gang`, `citizenid`, `name`, `dirty`, `left`, `cut`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { g.name, cid, GANG.charName(p), amount, amount, cut, os.time() })
        if not id then
            if fromDirty > 0 then ox:AddItem(source, 'black_money', fromDirty) end
            if fromMarked > 0 then ox:AddItem(source, 'marked_bills', fromMarked) end
            return false, 'failed'
        end
        GANG.log(g, GANG.charName(p), 'wash_drop', ('$%d · النسبة %d%%'):format(amount, cut))
        GANG.toGang(g, ('طلب غسيل جديد في الصندوق: $%d'):format(amount), 'inform', 1)
        return true, { amount = amount, back = amount - math.floor(amount * cut / 100), cut = cut }
    end)()
    busyBox[source] = nil
    return ok, why
end)

lib.callback.register('exti_gangs:server:washCollect', function(source, name)
    local g = washGang(name)
    if not g or not atBox(source, g) then return false, 'far' end
    if busyBox[source] then return false, 'busy' end
    local p = GANG.player(source)
    if not p then return false end
    busyBox[source] = true
    local cid = p.PlayerData.citizenid
    local total = 0
    for _, o in ipairs(myOrders(g, cid)) do
        if o.ready > 0 then
            -- take it only if nobody else did (a second click / a second box)
            local n = MySQL.update.await('UPDATE `exti_gang_wash` SET `ready` = 0, `closed` = IF(`left` = 0 AND `washing` = 0, 1, 0) WHERE `id` = ? AND `ready` = ?', { o.id, o.ready })
            if n and n > 0 then total = total + o.ready end
        end
    end
    if total > 0 then
        p.Functions.AddMoney('cash', total, 'gang-wash-collect')
        GANG.log(g, GANG.charName(p), 'wash_collect', ('$%d'):format(total))
    end
    busyBox[source] = nil
    if total == 0 then return false, 'notready' end
    return true, total
end)

lib.callback.register('exti_gangs:server:washCancel', function(source, name)
    local g = washGang(name)
    if not g or not atBox(source, g) then return false, 'far' end
    if busyBox[source] then return false, 'busy' end
    local p = GANG.player(source)
    if not p then return false end
    busyBox[source] = true
    local back = 0
    for _, o in ipairs(myOrders(g, p.PlayerData.citizenid)) do
        if o.left > 0 and ox:CanCarryItem(source, 'black_money', o.left) then
            -- (what's in the machine right now was already taken off `left`)
            local n = MySQL.update.await('UPDATE `exti_gang_wash` SET `left` = 0, `closed` = IF(`ready` = 0 AND `washing` = 0, 1, 0) WHERE `id` = ? AND `left` = ?', { o.id, o.left })
            if n and n > 0 then
                if ox:AddItem(source, 'black_money', o.left) then back = back + o.left
                else MySQL.update.await('UPDATE `exti_gang_wash` SET `left` = `left` + ?, `closed` = 0 WHERE `id` = ?', { o.left, o.id }) end
            end
        end
    end
    busyBox[source] = nil
    if back == 0 then return false, 'nothing' end
    GANG.log(g, GANG.charName(p), 'wash_cancel', ('$%d'):format(back))
    return true, back
end)

AddEventHandler('playerDropped', function() busyBox[source] = nil end)

---------------------------------------------------------------------------
-- the machine (Crew and up)
---------------------------------------------------------------------------
local function refund(s)
    for _, part in ipairs(s.parts) do
        MySQL.update.await('UPDATE `exti_gang_wash` SET `left` = `left` + ?, `washing` = GREATEST(`washing` - ?, 0), `closed` = 0 WHERE `id` = ?', { part.amount, part.amount, part.id })
    end
end

local function endSession(name, giveBack)
    local s = sessions[name]
    sessions[name] = nil
    if s and giveBack then refund(s) end
    return s
end

local SESSION_IDLE = 600

lib.callback.register('exti_gangs:server:washBegin', function(source)
    local g, m = GANG.memberOf(source)
    if not g or g.type ~= 'wash' then return false, 'nogang' end
    if m.rank < 1 then return false, 'rank' end
    if g.locked then return false, 'locked' end
    if not GANG.near(source, GANG.spot(g, 'washer'), 2.5) then return false, 'far' end
    local old = sessions[g.name]
    -- an abandoned batch (no step for 10 min, or the washer is gone) frees the machine
    local stale = old and ((old.pending and os.time() - old.stageAt > 30)
        or (not old.pending and (os.time() - old.stageAt > SESSION_IDLE or GetPlayerPed(old.src) == 0)))
    if old and not stale then return false, 'busy' end
    local cd = GANG.cooldownLeft('wash:' .. g.name)
    if cd > 0 then return false, 'cooldown', cd end
    local room = math.min(W.batchMax, dailyLeft(g))
    if room < 1 then return false, 'daily' end
    -- take the machine NOW (before any wait), so two presses at once can't start two batches
    local claim = { src = source, pending = true, stageAt = os.time(), parts = {}, total = 0, token = 0 }
    sessions[g.name] = claim
    if stale then refund(old) end   -- the abandoned batch's money goes back in the box
    local function release(...) if sessions[g.name] == claim then sessions[g.name] = nil end return ... end
    -- the oldest orders first, up to one batch
    local rows = MySQL.query.await('SELECT `id`, `left` FROM `exti_gang_wash` WHERE `gang` = ? AND `closed` = 0 AND `left` > 0 ORDER BY `id` LIMIT 20', { g.name }) or {}
    local parts, total = {}, 0
    for _, r in ipairs(rows) do
        if total >= room then break end
        local take = math.min(r.left, room - total)
        parts[#parts + 1] = { id = r.id, amount = take }
        total = total + take
    end
    if total < 1 then return release(false, 'empty') end
    local supplies = math.ceil(total / W.supplyPer)
    local stash = GANG.stashId(g)
    if (ox:GetItemCount(stash, 'wash_supplies') or 0) < supplies then return release(false, 'supplies', supplies) end
    -- reserve the money (a cancel at the box can't take what's in the machine; a restart gives it back)
    local got = {}
    for _, part in ipairs(parts) do
        local n = MySQL.update.await('UPDATE `exti_gang_wash` SET `left` = `left` - ?, `washing` = `washing` + ? WHERE `id` = ? AND `left` >= ?', { part.amount, part.amount, part.id, part.amount })
        if n and n > 0 then got[#got + 1] = part end
    end
    total = 0
    for _, part in ipairs(got) do total = total + part.amount end
    if total < 1 then return release(false, 'empty') end
    supplies = math.ceil(total / W.supplyPer)
    if sessions[g.name] ~= claim or not ox:RemoveItem(stash, 'wash_supplies', supplies) then
        refund({ parts = got })
        return release(false, sessions[g.name] ~= claim and 'busy' or 'supplies', supplies)
    end
    local token = math.random(100000, 999999)
    sessions[g.name] = { src = source, cid = m.citizenid, token = token, stage = 0, stageAt = os.time(), parts = got, total = total, supplies = supplies }
    claim.pending = false
    GANG.log(g, m.name, 'wash_start', ('$%d · %d مواد'):format(total, supplies))
    return true, { token = token, total = total, supplies = supplies, stacks = math.max(1, math.ceil(total / 1000)), seconds = W.stageSeconds }
end)

local function tip(g)
    local spot = GANG.spot(g, 'washer') or GANG.spot(g, 'dropbox')
    if not spot or GetResourceState('exti_police') ~= 'started' then return end
    local a, r = math.random() * math.pi * 2, W.tipRadius * (0.3 + math.random() * 0.7)
    local c = { x = spot.x + math.cos(a) * r, y = spot.y + math.sin(a) * r, z = spot.z }
    SetTimeout(math.random(W.tipDelay[1], W.tipDelay[2]) * 1000, function()
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = 'بلاغ مجهول', coords = c,
                text = 'أوراق نقدية مُعلَّمة ظهرت في هذه المنطقة: نشاط غسيل أموال قريب', number = 'مجهول' })
        end)
    end)
end

local function finish(g, s)
    -- the machine's wait and the daily total first (before any database wait), so nobody slips in
    GANG.addDaily('g', g.name, 'washed', s.total)
    GANG.setCooldown('wash:' .. g.name, W.cooldown)
    local toCustomers, cutTotal = 0, 0
    local cust = {}
    for _, part in ipairs(s.parts) do
        local o = MySQL.single.await('SELECT `citizenid`, `cut` FROM `exti_gang_wash` WHERE `id` = ?', { part.id })
        local cut = o and o.cut or g.settings.washCut
        local clean = part.amount - math.floor(part.amount * cut / 100)
        MySQL.update.await('UPDATE `exti_gang_wash` SET `ready` = `ready` + ?, `washing` = GREATEST(`washing` - ?, 0), `closed` = 0 WHERE `id` = ?', { clean, part.amount, part.id })
        toCustomers = toCustomers + clean
        cutTotal = cutTotal + (part.amount - clean)
        if o then cust[o.citizenid] = true end
    end
    local washerCut = math.floor(cutTotal * W.washerShare / 100)
    local toBank = cutTotal - washerCut
    local wp = GANG.player(s.src)
    if wp and washerCut > 0 then wp.Functions.AddMoney('cash', washerCut, 'gang-wash-share') else toBank = toBank + washerCut; washerCut = 0 end
    g.bank = g.bank + toBank
    GANG.saveGang(g)
    GANG.addRep(g, C.rep.gain.wash, 'wash')
    local marked = math.random() < W.markedChance
    if marked then tip(g) end
    GANG.log(g, wp and GANG.charName(wp) or '-', 'wash', ('$%d غُسلت · للزبائن $%d · للعصابة $%d · للغاسل $%d%s'):format(
        s.total, toCustomers, toBank, washerCut, marked and ' · أوراق مُعلَّمة' or ''))
    for cid in pairs(cust) do
        local cs = GANG.srcOf(cid)
        if cs then GANG.notify(cs, ('مالك النظيف جاهز في صندوق %s'):format(g.label), 'success', 8000) end
    end
    return { total = s.total, mine = washerCut, bank = toBank }
end

lib.callback.register('exti_gangs:server:washStage', function(source, token, stage)
    local g, m = GANG.memberOf(source)
    local s = g and sessions[g.name]
    if not s or s.src ~= source or s.token ~= token then return false, 'nosession' end
    if math.type(stage) ~= 'integer' or stage ~= s.stage + 1 then return false, 'order' end
    if not GANG.near(source, GANG.spot(g, 'washer'), 4.0) then return false, 'far' end
    local need = W.stageSeconds[stage] or 15
    if os.time() - s.stageAt < need then return false, 'fast' end
    s.stage, s.stageAt = stage, os.time()
    if stage < 3 then return true end
    endSession(g.name)
    return true, finish(g, s)
end)

lib.callback.register('exti_gangs:server:washStop', function(source)
    for name, s in pairs(sessions) do
        if s.src == source then
            endSession(name, true)
            GANG.log(GANG.gangs[name], GANG.charName(GANG.player(source)), 'wash_cancel_batch', ('$%d'):format(s.total))
            return true
        end
    end
    return false
end)

AddEventHandler('playerDropped', function()
    local src = source
    for name, s in pairs(sessions) do if s.src == src then endSession(name, true) end end
end)

---------------------------------------------------------------------------
-- the laptop's Wash tab
---------------------------------------------------------------------------
function GANG.washView(g, m)
    local _, L = GANG.level(g)
    local total, n = queueTotal(g)
    local rows = m.rank >= 1 and MySQL.query.await('SELECT `name`, `left`, `cut`, `created` FROM `exti_gang_wash` WHERE `gang` = ? AND `closed` = 0 AND `left` > 0 ORDER BY `id` LIMIT 30', { g.name }) or {}
    local s = sessions[g.name]
    return {
        queue = rows, queueTotal = total, queueCount = n,
        washed = GANG.getDaily('g', g.name, 'washed'), washCap = L.washDaily or 40000,
        cooldown = GANG.cooldownLeft('wash:' .. g.name), supplies = ox:GetItemCount(GANG.stashId(g), 'wash_supplies') or 0,
        cut = g.settings.washCut, washerShare = W.washerShare, batchMax = W.batchMax, supplyPer = W.supplyPer,
        busy = s and { total = s.total, stage = s.stage } or nil,
    }
end
