-- =====================================================================
-- EX_Tii Mechanic (server): the PARTS SHOP (tablet → متجر القطع), like the video: pick parts, pay
-- with the workshop account, the box is on its way (a timer), and it arrives at the delivery spot
-- near the workshop. A mechanic on duty picks it up there and it goes onto the parts shelf.
-- =====================================================================

local P = Config.parts
local JOB = Config.job
local getPlayer, onDuty, nameOf, notify, grade = MEC.getPlayer, MEC.onDuty, MEC.nameOf, MEC.notify, MEC.grade

local CATALOG = {}
for _, c in ipairs(P.catalog) do CATALOG[c.item] = c end

local ready = false
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_part_orders` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `items` LONGTEXT NOT NULL,
        `total` INT NOT NULL,
        `citizenid` VARCHAR(50) NULL,
        `name` VARCHAR(80) NULL,
        `created` INT NOT NULL,
        `eta` INT NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'shipping',
        `collected_by` VARCHAR(80) NULL,
        `collected` INT NULL,
        INDEX `status` (`status`)
    ) DEFAULT CHARSET=utf8mb4]])
    ready = true
end)

local function labelOf(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and type(item) == 'table' and item.label or name
end

local function balance()
    local ok, money = pcall(function() return exports['Renewed-Banking']:getAccountMoney(JOB) end)
    return ok and tonumber(money) or nil
end

local function decode(s)
    local ok, v = pcall(json.decode, s or '')
    return ok and type(v) == 'table' and v or {}
end

local function ordersView()
    local since = os.time() - (P.keepDays or 14) * 86400
    local rows = MySQL.query.await('SELECT * FROM `exti_mechanic_part_orders` WHERE `created` > ? ORDER BY `id` DESC LIMIT 30', { since }) or {}
    local out = {}
    for i, r in ipairs(rows) do
        local items = {}
        for _, it in ipairs(decode(r.items)) do items[#items + 1] = { item = it.item, label = labelOf(it.item), count = it.count } end
        out[i] = { id = r.id, items = items, total = r.total, name = r.name, created = r.created, eta = r.eta,
            status = r.status, collectedBy = r.collected_by, collected = r.collected }
    end
    return out
end

-- the ready orders, for everyone's game (the box at the delivery spot)
local function publishReady()
    local n = MySQL.scalar.await("SELECT COUNT(*) FROM `exti_mechanic_part_orders` WHERE `status` = 'ready'") or 0
    GlobalState.exti_mechanic_parts_ready = tonumber(n) or 0
end

--- the tablet: the catalog, the account, the orders
function MEC.partsView(src)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    local list = {}
    for _, c in ipairs(P.catalog) do
        list[#list + 1] = { item = c.item, label = labelOf(c.item), price = c.price, category = c.category }
    end
    return { list = list, balance = balance(), canOrder = grade(player) >= (P.orderGrade or 1), eta = P.etaMinutes,
        max = P.maxPerOrder, orders = ordersView(), now = os.time() }
end

--- order: cart = { [item] = count }
function MEC.partsOrder(src, cart)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    if not ready then return false, 'wait' end
    if grade(player) < (P.orderGrade or 1) then return false, 'rank_low' end
    if type(cart) ~= 'table' then return false, 'failed' end
    local items, total, count = {}, 0, 0
    for name, n in pairs(cart) do
        local c = CATALOG[name]
        n = math.tointeger(tonumber(n))
        if c and n and n > 0 then
            n = math.min(n, P.maxPerOrder or 40)
            items[#items + 1] = { item = name, count = n }
            total = total + c.price * n
            count = count + n
        end
    end
    if #items == 0 then return false, 'empty' end
    if count > (P.maxPerOrder or 40) then return false, 'too_many' end
    local okPay, paid = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(JOB, total) end)
    if not okPay or not paid then return false, 'no_money' end
    local names = {}
    for _, it in ipairs(items) do names[#names + 1] = ('%d× %s'):format(it.count, labelOf(it.item)) end
    pcall(function()
        exports['Renewed-Banking']:handleTransaction(JOB, 'متجر القطع', total, table.concat(names, '، '):sub(1, 200), nameOf(player), 'Parts Supplier', 'withdraw')
    end)
    local now = os.time()
    MySQL.insert.await('INSERT INTO `exti_mechanic_part_orders` (`items`, `total`, `citizenid`, `name`, `created`, `eta`, `status`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { json.encode(items), total, player.PlayerData.citizenid, nameOf(player), now, now + (P.etaMinutes or 5) * 60, 'shipping' })
    MEC.log(src, 'parts_ordered', table.concat(names, '، '):sub(1, 240), total, 'out')
    lib.logger(src, 'mechanic', ('ordered parts for $%d: %s'):format(total, table.concat(names, ', ')))
    return MEC.partsView(src)
end

-- every 15 s: the boxes that have arrived
CreateThread(function()
    while not ready do Wait(500) end
    publishReady()
    while true do
        Wait(15000)
        local rows = MySQL.query.await("SELECT `id` FROM `exti_mechanic_part_orders` WHERE `status` = 'shipping' AND `eta` <= ?", { os.time() }) or {}
        if #rows > 0 then
            for _, r in ipairs(rows) do
                MySQL.update.await("UPDATE `exti_mechanic_part_orders` SET `status` = 'ready' WHERE `id` = ? AND `status` = 'shipping'", { r.id })
            end
            publishReady()
            for _, id in ipairs(MEC.copsOnDuty()) do
                notify(tonumber(id) or id, 'success', 'وصلت طلبية القطع إلى نقطة الاستلام بجانب الورشة')
            end
        end
    end
end)

-- picking the boxes up at the delivery spot: everything goes onto the parts shelf
local collecting = false
lib.callback.register('exti_mechanic:server:collectParts', function(source, station)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local st = MEC.stationOf(station)
    if not st or not st.delivery or not MEC.nearSpot(source, st.delivery, 2.5) then return false, 'too_far' end
    if collecting then return false, 'wait' end
    collecting = true
    local rows = MySQL.query.await("SELECT * FROM `exti_mechanic_part_orders` WHERE `status` = 'ready' ORDER BY `id`") or {}
    if #rows == 0 then collecting = false return false, 'no_order' end
    local moved, left = 0, 0
    for _, r in ipairs(rows) do
        -- mark first: nobody picks the same box twice
        local changed = MySQL.update.await("UPDATE `exti_mechanic_part_orders` SET `status` = 'collected', `collected_by` = ?, `collected` = ? WHERE `id` = ? AND `status` = 'ready'",
            { nameOf(player), os.time(), r.id })
        if changed and changed > 0 then
            local missing = {}
            for _, it in ipairs(decode(r.items)) do
                -- EX_Tii: an item that doesn't exist (any more) is dropped, it never blocks the box ("the shelf is full")
                if not exports.ox_inventory:Items(it.item) then
                    lib.print.warn(('[mechanic] parts order %d: unknown item %s dropped'):format(r.id, tostring(it.item)))
                else
                    local ok, added = pcall(function() return exports.ox_inventory:AddItem(MEC.SHELF_ID, it.item, it.count) end)
                    if ok and added then moved = moved + it.count else missing[#missing + 1] = it left = left + it.count end
                end
            end
            if #missing > 0 then
                -- the shelf is full: what did not fit stays at the delivery spot
                MySQL.update.await("UPDATE `exti_mechanic_part_orders` SET `status` = 'ready', `items` = ?, `collected_by` = NULL, `collected` = NULL WHERE `id` = ?",
                    { json.encode(missing), r.id })
            end
        end
    end
    collecting = false
    publishReady()
    MEC.log(source, 'parts_collected', ('%d قطعة'):format(moved))
    return { moved = moved, left = left }
end)
