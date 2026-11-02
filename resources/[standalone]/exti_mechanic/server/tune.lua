-- =====================================================================
-- EX_Tii Mechanic (server): TUNING (part C, step 1) — performance and looks.
--
--  * the customer sits in his OWN car on a tuning bay and opens the menu (only while a mechanic is
--    on duty). He picks the changes (seen on his car while he picks), confirms and pays: the money
--    goes straight to the workshop account. The car goes back to how it was: nothing is real until
--    a mechanic installs it.
--  * the order lands on the tablet (الطلبات). A mechanic takes it, carries the parts (from the parts
--    shop) and installs each change at the car (the service menu, with the mini-games). Every
--    change is checked here, the part is used up, the car gets the change and it is saved on the
--    car (player_vehicles.mods), so it stays after parking.
--  * a mechanic who took the order (or the manager) can cancel it: what is not installed yet is paid
--    back to the customer from the workshop account. The customer can cancel at the bay as long as
--    nothing was installed.
-- =====================================================================

local T = Config.tuning
local S = Config.service
local JOB = Config.job
local getPlayer, onDuty, isBoss, nameOf, notify, pedOf = MEC.getPlayer, MEC.onDuty, MEC.isBoss, MEC.nameOf, MEC.notify, MEC.pedOf

local PERF, BODY = {}, {}
for _, p in ipairs(T.perf) do PERF[p.key] = p end
for _, b in ipairs(T.body) do BODY[b.mod] = b end

---------------------------------------------------------------------------
-- tables and the prices
---------------------------------------------------------------------------
local PRICES, PRICE_LABEL, PRICE_ORDER = {}, {}, {}
for i, p in ipairs(T.prices) do PRICES[p[1]] = p[3] PRICE_LABEL[p[1]] = p[2] PRICE_ORDER[i] = p[1] end

local OPEN = {}      -- [plate] = the open order
local ready = false

local function decode(s)
    local ok, v = pcall(json.decode, s or '')
    return ok and type(v) == 'table' and v or nil
end

local function trim(p)
    p = type(p) == 'string' and p:gsub('^%s+', ''):gsub('%s+$', ''):upper() or nil
    return p ~= '' and p or nil
end

-- which plates have an open order (everyone's game: the mechanic's "[E]" line says so)
local function publishPlates()
    local list = {}
    for plate in pairs(OPEN) do list[plate] = true end
    GlobalState.exti_mechanic_tune_plates = list
end

local function rowToOrder(r)
    return {
        id = r.id, plate = r.plate, model = r.model, cid = r.citizenid, name = r.name, lines = decode(r.lines) or {},
        total = tonumber(r.total) or 0, status = r.status, mcid = r.mechanic_cid, mname = r.mechanic_name,
        created = tonumber(r.created), finished = tonumber(r.finished), refunded = tonumber(r.refunded) or 0,
    }
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_tune_prices` (
        `key` VARCHAR(30) NOT NULL PRIMARY KEY,
        `price` INT NOT NULL,
        `updated_by` VARCHAR(50) NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_tune_orders` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `plate` VARCHAR(12) NOT NULL,
        `model` VARCHAR(40) NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NULL,
        `lines` LONGTEXT NOT NULL,
        `total` INT NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'open',
        `mechanic_cid` VARCHAR(50) NULL,
        `mechanic_name` VARCHAR(80) NULL,
        `created` INT NOT NULL,
        `finished` INT NULL,
        `refunded` INT NOT NULL DEFAULT 0,
        INDEX `status` (`status`),
        INDEX `plate` (`plate`)
    ) DEFAULT CHARSET=utf8mb4]])
    -- the prices: the database wins; a new key from config.lua is added with its starting price
    local rows = MySQL.query.await('SELECT `key`, `price` FROM `exti_mechanic_tune_prices`') or {}
    local have = {}
    for _, r in ipairs(rows) do
        if PRICE_LABEL[r.key] then PRICES[r.key] = tonumber(r.price) or PRICES[r.key] end
        have[r.key] = true
    end
    for _, key in ipairs(PRICE_ORDER) do
        if not have[key] then MySQL.insert.await('INSERT INTO `exti_mechanic_tune_prices` (`key`, `price`) VALUES (?, ?)', { key, PRICES[key] }) end
    end
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `exti_mechanic_tune_orders` WHERE `status` = 'open'") or {}) do
        OPEN[r.plate] = rowToOrder(r)
    end
    publishPlates()
    ready = true
end)

local function saveLines(o)
    MySQL.update.await('UPDATE `exti_mechanic_tune_orders` SET `lines` = ?, `mechanic_cid` = ?, `mechanic_name` = ? WHERE `id` = ?',
        { json.encode(o.lines), o.mcid, o.mname, o.id })
end

local function priceOf(key)
    return math.max(0, math.floor(tonumber(PRICES[key]) or 0))
end

-- a performance level price: the level's own key, or the highest level that has one
local function levelPrice(key, level)
    for l = level, 1, -1 do
        if PRICES[('%s_%d'):format(key, l)] then return priceOf(('%s_%d'):format(key, l)) end
    end
    return 0
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function itemCount(src, name)
    local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, name) end)
    return ok and tonumber(n) or 0
end

local function itemLabel(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and type(item) == 'table' and item.label or name
end

local function vehicleOf(netId)
    netId = math.tointeger(tonumber(netId))
    if not netId then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function plateOf(veh) return trim(GetVehicleNumberPlateText(veh)) end

local function balance()
    local ok, money = pcall(function() return exports['Renewed-Banking']:getAccountMoney(JOB) end)
    return ok and tonumber(money) or nil
end

local function int(v, lo, hi)
    v = math.tointeger(tonumber(v))
    if not v or v < lo or v > hi then return nil end
    return v
end

local function rgb(c)
    if type(c) ~= 'table' then return nil end
    local r, g, b = int(c[1], 0, 255), int(c[2], 0, 255), int(c[3], 0, 255)
    if not r or not g or not b then return nil end
    return { r, g, b }
end

local function cleanName(s)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c<>"\'&]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    if utf8.len(s) and utf8.len(s) > 40 then s = s:sub(1, utf8.offset(s, 41) - 1) end
    return s
end

-- the customer's own car: { citizenid, mods } from player_vehicles
local function ownedRow(plate)
    return MySQL.single.await('SELECT `citizenid`, `mods` FROM `player_vehicles` WHERE `plate` = ? OR TRIM(`plate`) = ? LIMIT 1', { plate, plate })
end

-- the car on a bay of a workshop (flat distance: the car sits above the circle)
local function onBay(veh)
    local c = GetEntityCoords(veh)
    for name, st in pairs(Config.stations) do
        for kind in pairs(MEC.BAYS) do
            local b = st[kind]
            if b and #(vec2(c.x, c.y) - vec2(b.x, b.y)) <= (T.bayReach or 3.5) + 1.5 and math.abs(c.z - b.z) < 4.0 then return name end
        end
    end
end

-- the mechanic installs inside the workshop
local function inWorkshop(src)
    local ped = pedOf(src)
    if not ped then return false end
    local p = GetEntityCoords(ped)
    for _, st in pairs(Config.stations) do
        local c = st.duty or (st.garage and st.garage.coords)
        if c and #(p - vec3(c.x, c.y, c.z)) <= (T.area or 70.0) then return true end
    end
    return false
end

local function mechanicsOnDuty()
    return #MEC.copsOnDuty()
end

local function playerByCid(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    return ok and p or nil
end

---------------------------------------------------------------------------
-- turning the customer's picks into the order's lines (all prices and parts are worked out here)
--   changes = { engine = 2, turbo = true, paint1 = { t, c = {r,g,b} }, pearl = 5, wheelColor = 0,
--     wheels = { t, i, bike }, body = { ["0"] = { i, n } }, tint = 1, neon = { on, c }, xenon = { on, c }, plate = 2 }
--   cur = what the car has now (from the customer's game; the saved car wins for performance)
---------------------------------------------------------------------------
local PAINT_TYPES = { [0] = 'عادي', [1] = 'معدني', [2] = 'لؤلؤي', [3] = 'مطفي', [4] = 'معدن', [5] = 'كروم' }
local TINTS = { [0] = 'بدون', [1] = 'أسود كامل', [2] = 'دخاني غامق', [3] = 'دخاني فاتح', [4] = 'الأصلي', [5] = 'ليموزين', [6] = 'أخضر' }

local function buildLines(changes, cur, stored)
    if type(changes) ~= 'table' then return nil, 'failed' end
    cur = type(cur) == 'table' and cur or {}
    stored = type(stored) == 'table' and stored or {}
    local I = T.items
    local lines = {}
    local function add(l) lines[#lines + 1] = l end

    -- performance
    for _, p in ipairs(T.perf) do
        local v = changes[p.key]
        if v ~= nil then
            v = int(v, -1, 9)
            if not v then return nil, 'failed' end
            local now = math.tointeger(tonumber(stored[p.prop])) or int(cur[p.key], -1, 9) or -1
            if v ~= now then
                if v > now then
                    add({ k = p.key, label = ('%s: المستوى %d'):format(p.label, v + 1), price = levelPrice(p.key, v + 1),
                        item = p.item, count = v - now, recipe = p.recipe, props = { [p.prop] = v } })
                else
                    add({ k = p.key, label = ('%s: إرجاع إلى %s'):format(p.label, v < 0 and 'الأصلي' or ('المستوى %d'):format(v + 1)),
                        price = priceOf('remove'), count = 0, recipe = p.recipe, props = { [p.prop] = v } })
                end
            end
        end
    end
    if changes.turbo ~= nil then
        local on = changes.turbo == true
        local now = stored.modTurbo
        if now == nil then now = cur.turbo == true end
        if on ~= (now == true) then
            if on then
                add({ k = 'turbo', label = 'تيربو', price = priceOf('turbo'), item = T.turbo.item, count = 1, recipe = T.turbo.recipe, props = { modTurbo = true } })
            else
                add({ k = 'turbo', label = 'إزالة التيربو', price = priceOf('remove'), count = 0, recipe = T.turbo.recipe, props = { modTurbo = false } })
            end
        end
    end

    -- paint (the pearl rides with the main paint in the game, so it is carried along)
    local pearl = changes.pearl ~= nil and int(changes.pearl, 0, 160) or int(cur.pearl, 0, 160) or 0
    for slot = 1, 2 do
        local v = changes['paint' .. slot]
        if v ~= nil then
            if type(v) ~= 'table' then return nil, 'failed' end
            local t, c = int(v.t, 0, 5), rgb(v.c)
            if not t or not c then return nil, 'failed' end
            local props = slot == 1 and { color1 = c, paintType1 = t, pearlescentColor = pearl } or { color2 = c, paintType2 = t }
            add({ k = 'paint' .. slot, label = ('%s (%s)'):format(slot == 1 and 'الصبغ الأساسي' or 'الصبغ الثانوي', PAINT_TYPES[t]),
                price = priceOf('paint' .. slot), item = I.paint, count = 1, recipe = 't_paint', props = props, color = c })
        end
    end
    if changes.pearl ~= nil then
        if not int(changes.pearl, 0, 160) then return nil, 'failed' end
        add({ k = 'pearl', label = 'اللمعة (البيرل)', price = priceOf('pearl'), item = I.paint, count = 1, recipe = 't_paint',
            props = { pearlescentColor = int(changes.pearl, 0, 160) } })
    end
    if changes.wheelColor ~= nil then
        local v = int(changes.wheelColor, 0, 160)
        if not v then return nil, 'failed' end
        add({ k = 'wheelColor', label = 'لون الجنوط', price = priceOf('wheelColor'), item = I.paint, count = 1, recipe = 't_paint', props = { wheelColor = v } })
    end

    -- wheels
    if changes.wheels ~= nil then
        local v = changes.wheels
        if type(v) ~= 'table' then return nil, 'failed' end
        local t, i = int(v.t, 0, 12), int(v.i, -1, 600)
        if not t or not i then return nil, 'failed' end
        local props = { wheels = t, modFrontWheels = i }
        if v.bike == true then props.modBackWheels = i end
        add({ k = 'wheels', label = ('جنوط: %s'):format(cleanName(v.n) or (i < 0 and 'الأصلية' or ('رقم %d'):format(i + 1))),
            price = priceOf('wheels'), item = I.wheels, count = 1, recipe = 'wheel', times = 4, props = props })
    end

    -- body parts
    if changes.body ~= nil then
        if type(changes.body) ~= 'table' then return nil, 'failed' end
        for modKey, v in pairs(changes.body) do
            local mod = int(modKey, 0, 60)
            local b = mod and BODY[mod]
            if not b or type(v) ~= 'table' then return nil, 'failed' end
            local i = int(v.i, -1, 400)
            if not i then return nil, 'failed' end
            add({ k = 'body' .. mod, label = ('%s: %s'):format(b.label, cleanName(v.n) or (i < 0 and 'الأصلي' or ('رقم %d'):format(i + 1))),
                price = priceOf(b.price or 'body'), item = b.item or I.body, count = 1, recipe = b.price == 'horn' and 't_small' or b.price == 'livery' and 't_paint' or 't_body',
                props = { [b.prop] = i } })
        end
    end

    -- the rest
    if changes.tint ~= nil then
        local v = int(changes.tint, 0, 6)
        if not v then return nil, 'failed' end
        add({ k = 'tint', label = ('تظليل: %s'):format(TINTS[v]), price = priceOf('tint'), item = I.tint, count = 1, recipe = 't_tint', props = { windowTint = v } })
    end
    if changes.neon ~= nil then
        local v = changes.neon
        if type(v) ~= 'table' then return nil, 'failed' end
        local on, c = v.on == true, rgb(v.c) or { 255, 255, 255 }
        local was = cur.neon == true
        if on ~= was then
            add({ k = 'neon', label = on and 'تركيب النيون' or 'إزالة النيون', price = priceOf('neon'), item = on and I.neon or nil, count = on and 1 or 0,
                recipe = 't_neon', props = { neonEnabled = { on, on, on, on }, neonColor = c }, color = c })
        elseif on then
            add({ k = 'neon', label = 'لون النيون', price = priceOf('neonColor'), count = 0, recipe = 't_small', props = { neonColor = c }, color = c })
        end
    end
    if changes.xenon ~= nil then
        local v = changes.xenon
        if type(v) ~= 'table' then return nil, 'failed' end
        local on, c = v.on == true, int(v.c, -1, 12) or -1
        local was = cur.xenon == true
        if on ~= was then
            add({ k = 'xenon', label = on and 'تركيب الزينون' or 'إزالة الزينون', price = priceOf('xenon'), item = on and I.xenon or nil, count = on and 1 or 0,
                recipe = 't_xenon', props = { modXenon = on, xenonColor = c } })
        elseif on then
            add({ k = 'xenon', label = 'لون الزينون', price = priceOf('xenonColor'), count = 0, recipe = 't_small', props = { xenonColor = c } })
        end
    end
    if changes.plate ~= nil then
        local v = int(changes.plate, 0, 5)
        if not v then return nil, 'failed' end
        add({ k = 'plate', label = 'شكل اللوحة', price = priceOf('plate'), item = I.plate, count = 1, recipe = 't_small', props = { plateIndex = v } })
    end

    if #lines == 0 then return nil, 'empty' end
    if #lines > (T.maxLines or 30) then return nil, 'too_many' end
    return lines
end
MEC.tuneBuildLines = buildLines -- (for the tests)

local function totalOf(lines)
    local t = 0
    for _, l in ipairs(lines) do t = t + (l.price or 0) end
    return t
end

local function pendingTotal(o)
    local t = 0
    for _, l in ipairs(o.lines) do if not l.done then t = t + (l.price or 0) end end
    return t
end

local function anyDone(o)
    for _, l in ipairs(o.lines) do if l.done then return true end end
    return false
end

local function shortOrder(o)
    local lines = {}
    for i, l in ipairs(o.lines) do lines[i] = { label = l.label, price = l.price, done = l.done == true } end
    return { id = o.id, plate = o.plate, total = o.total, lines = lines, mname = o.mname, started = anyDone(o) }
end

---------------------------------------------------------------------------
-- money: the customer pays the workshop; a cancel pays back what is not installed
---------------------------------------------------------------------------
local function charge(player, amount, why)
    local src = player.PlayerData.source
    local money = player.PlayerData.money or {}
    local kind = (tonumber(money.bank) or 0) >= amount and 'bank' or (tonumber(money.cash) or 0) >= amount and 'cash' or nil
    if not kind then return false end
    local ok, done = pcall(function() return exports.qbx_core:RemoveMoney(src, kind, amount, why) end)
    if not ok or not done then return false end
    return kind
end

local function refundCustomer(cid, amount, why)
    if amount <= 0 then return true end
    local ok, done = pcall(function() return exports.qbx_core:AddMoney(cid, 'bank', amount, why) end)
    return ok and done ~= false
end

local function shopIn(amount, plate, who)
    local ok, done = pcall(function() return exports['Renewed-Banking']:addAccountMoney(JOB, amount) end)
    if not ok or not done then return false end
    pcall(function()
        exports['Renewed-Banking']:handleTransaction(JOB, 'تعديل سيارة', amount, ('طلب تعديل للسيارة %s'):format(plate), who, 'ورشة بيني', 'deposit')
    end)
    return true
end

local function shopOut(amount, plate, who)
    if amount <= 0 then return true end
    local ok, done = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(JOB, amount) end)
    if not ok or not done then return false end
    pcall(function()
        exports['Renewed-Banking']:handleTransaction(JOB, 'إرجاع مبلغ تعديل', amount, ('إلغاء طلب التعديل %s'):format(plate), 'ورشة بيني', who, 'withdraw')
    end)
    return true
end

---------------------------------------------------------------------------
-- the customer at the bay
---------------------------------------------------------------------------
local function customerAt(src, netId)
    if not ready then return nil, 'wait' end
    local player = getPlayer(src)
    if not player then return nil, 'failed' end
    local veh = vehicleOf(netId)
    local ped = pedOf(src)
    if not veh or not ped or GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'driver' end
    local plate = plateOf(veh)
    if not plate then return nil, 'failed' end
    if not onBay(veh) then return nil, 'not_bay' end
    local row = ownedRow(plate)
    if not row or row.citizenid ~= player.PlayerData.citizenid then return nil, 'not_owner' end
    return player, veh, plate, row
end

lib.callback.register('exti_mechanic:server:tuneOpen', function(source, netId)
    local player, veh, plate, row = customerAt(source, netId)
    if not player then return false, veh end
    local o = OPEN[plate]
    if o then return { open = shortOrder(o) } end
    if T.needMechanic ~= false and mechanicsOnDuty() < 1 then return false, 'no_mechanic' end
    local stored = decode(row.mods) or {}
    local cur = {}
    for _, p in ipairs(T.perf) do cur[p.key] = math.tointeger(tonumber(stored[p.prop])) end
    local money = player.PlayerData.money or {}
    return { plate = plate, prices = PRICES, bank = tonumber(money.bank) or 0, cash = tonumber(money.cash) or 0, stored = cur }
end)

lib.callback.register('exti_mechanic:server:tuneOrder', function(source, netId, changes, cur, model)
    local player, veh, plate, row = customerAt(source, netId)
    if not player then return false, veh end
    if OPEN[plate] then return false, 'has_order' end
    if T.needMechanic ~= false and mechanicsOnDuty() < 1 then return false, 'no_mechanic' end
    local lines, err = buildLines(changes, cur, decode(row.mods))
    if not lines then return false, err end
    local total = totalOf(lines)
    local kind = total == 0 and 'free' or charge(player, total, ('tuning %s'):format(plate))
    if not kind then return false, 'no_money' end
    if total > 0 and not shopIn(total, plate, nameOf(player)) then
        -- the workshop account could not take it: give it back
        pcall(function() exports.qbx_core:AddMoney(source, kind, total, 'tuning refund') end)
        return false, 'failed'
    end
    local now = os.time()
    model = type(model) == 'string' and model:sub(1, 40) or nil
    local id = MySQL.insert.await('INSERT INTO `exti_mechanic_tune_orders` (`plate`, `model`, `citizenid`, `name`, `lines`, `total`, `status`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { plate, model, player.PlayerData.citizenid, nameOf(player), json.encode(lines), total, 'open', now })
    if not id then
        if total > 0 and shopOut(total, plate, nameOf(player)) then refundCustomer(player.PlayerData.citizenid, total, 'tuning refund') end
        return false, 'failed'
    end
    OPEN[plate] = { id = id, plate = plate, model = model, cid = player.PlayerData.citizenid, name = nameOf(player), lines = lines,
        total = total, status = 'open', created = now, refunded = 0 }
    publishPlates()
    MEC.log(source, 'tune_ordered', ('#%d · %s · %d تعديل'):format(id, plate, #lines), total, 'in')
    lib.logger(source, 'mechanic', ('tuning order #%d for %s: $%d, %d changes'):format(id, plate, total, #lines))
    for _, m in ipairs(MEC.copsOnDuty()) do
        notify(tonumber(m) or m, 'inform', ('طلب تعديل جديد #%d · %s (%s) · %d تعديل. افتح الطلبات في التابلت'):format(id, model or '', plate, #lines))
    end
    return { id = id, total = total, paid = kind, lines = #lines }
end)

-- the customer cancels at the bay (only while nothing is installed)
lib.callback.register('exti_mechanic:server:tuneCustomerCancel', function(source, netId)
    local player, veh, plate = customerAt(source, netId)
    if not player then return false, veh end
    local o = OPEN[plate]
    if not o then return false, 'gone' end
    if anyDone(o) then return false, 'started' end
    if not shopOut(o.total, plate, nameOf(player)) then return false, 'shop_money' end
    refundCustomer(o.cid, o.total, ('tuning #%d cancelled'):format(o.id))
    MySQL.update.await("UPDATE `exti_mechanic_tune_orders` SET `status` = 'cancelled', `finished` = ?, `refunded` = ? WHERE `id` = ?", { os.time(), o.total, o.id })
    OPEN[plate] = nil
    publishPlates()
    MEC.log(source, 'tune_cancelled', ('#%d · %s · الزبون'):format(o.id, plate), o.total, 'out')
    return { refunded = o.total }
end)

---------------------------------------------------------------------------
-- the tablet (الطلبات)
---------------------------------------------------------------------------
local function orderView(o, src)
    local lines, need = {}, {}
    for i, l in ipairs(o.lines) do
        lines[i] = { label = l.label, price = l.price, item = l.item, itemLabel = l.item and itemLabel(l.item) or nil, count = l.count or 0,
            done = l.done == true, by = l.by, color = l.color }
        if l.item and not l.done and (l.count or 0) > 0 then need[l.item] = (need[l.item] or 0) + l.count end
    end
    local needList = {}
    for item, n in pairs(need) do needList[#needList + 1] = { item = item, label = itemLabel(item), count = n, have = src and itemCount(src, item) or 0 } end
    table.sort(needList, function(a, b) return a.label < b.label end)
    return { id = o.id, plate = o.plate, model = o.model, name = o.name, total = o.total, status = o.status, mcid = o.mcid, mname = o.mname,
        created = o.created, finished = o.finished, refunded = o.refunded, lines = lines, need = needList, left = pendingTotal(o) }
end

function MEC.tuneOrders(src)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    local open = {}
    for _, o in pairs(OPEN) do open[#open + 1] = orderView(o, src) end
    table.sort(open, function(a, b) return a.id < b.id end)
    local since = os.time() - (T.keepDays or 14) * 86400
    local done = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `exti_mechanic_tune_orders` WHERE `status` <> 'open' AND `created` > ? ORDER BY `id` DESC LIMIT 40", { since }) or {}) do
        done[#done + 1] = orderView(rowToOrder(r))
    end
    return { open = open, done = done, isBoss = isBoss(player), me = player.PlayerData.citizenid, now = os.time() }
end

local function findOpen(id)
    id = math.tointeger(tonumber(id))
    if not id then return nil end
    for _, o in pairs(OPEN) do if o.id == id then return o end end
end

function MEC.tuneClaim(src, id)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    local o = findOpen(id)
    if not o then return false, 'gone' end
    if o.mcid and o.mcid ~= player.PlayerData.citizenid and not isBoss(player) then return false, 'claimed' end
    o.mcid, o.mname = player.PlayerData.citizenid, nameOf(player)
    saveLines(o)
    MEC.log(src, 'tune_claimed', ('#%d · %s'):format(o.id, o.plate))
    return MEC.tuneOrders(src)
end

function MEC.tuneCancel(src, id)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    local o = findOpen(id)
    if not o then return false, 'gone' end
    if not isBoss(player) and o.mcid ~= player.PlayerData.citizenid then return false, 'not_yours' end
    local back = pendingTotal(o)
    if not shopOut(back, o.plate, o.name or '') then return false, 'no_money' end
    refundCustomer(o.cid, back, ('tuning #%d cancelled'):format(o.id))
    local status = anyDone(o) and 'done' or 'cancelled'
    MySQL.update.await('UPDATE `exti_mechanic_tune_orders` SET `status` = ?, `finished` = ?, `refunded` = ?, `lines` = ? WHERE `id` = ?',
        { status, os.time(), back, json.encode(o.lines), o.id })
    OPEN[o.plate] = nil
    publishPlates()
    MEC.log(src, 'tune_cancelled', ('#%d · %s'):format(o.id, o.plate), back, 'out')
    local c = playerByCid(o.cid)
    if c then notify(c.PlayerData.source, 'inform', ('أُلغي طلب التعديل لسيارتك %s، ورجع لك $%s في البنك'):format(o.plate, back)) end
    return MEC.tuneOrders(src)
end

function MEC.tunePrices(src)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    local list = {}
    for i, key in ipairs(PRICE_ORDER) do list[i] = { key = key, label = PRICE_LABEL[key], price = PRICES[key] } end
    return { list = list, isBoss = isBoss(player), max = T.maxPrice or 250000 }
end

function MEC.tunePriceSave(src, key, price)
    local player = getPlayer(src)
    if not onDuty(player) then return false, 'off_duty' end
    if not isBoss(player) then return false, 'not_boss' end
    if type(key) ~= 'string' or not PRICE_LABEL[key] then return false, 'failed' end
    price = int(price, 0, T.maxPrice or 250000)
    if not price then return false, 'bad_price' end
    PRICES[key] = price
    MySQL.prepare.await('INSERT INTO `exti_mechanic_tune_prices` (`key`, `price`, `updated_by`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `price` = VALUES(`price`), `updated_by` = VALUES(`updated_by`)',
        { key, price, player.PlayerData.citizenid })
    MEC.log(src, 'tune_price', ('%s · $%d'):format(PRICE_LABEL[key], price))
    return MEC.tunePrices(src)
end

-- the badge on the tablet: open orders nobody took yet
function MEC.openTunes()
    local n = 0
    for _, o in pairs(OPEN) do if not o.mcid then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- installing at the car (the service menu shows the order's changes)
---------------------------------------------------------------------------
function MEC.tuneFor(src, plate)
    local o = plate and OPEN[plate]
    if not o then return nil end
    local player = getPlayer(src)
    local lines = {}
    for i, l in ipairs(o.lines) do
        lines[i] = { i = i, label = l.label, item = l.item, itemLabel = l.item and itemLabel(l.item) or nil, count = l.count or 0,
            have = l.item and itemCount(src, l.item) or 0, done = l.done == true }
    end
    return { id = o.id, lines = lines, mname = o.mname, mine = player and o.mcid == player.PlayerData.citizenid or false, free = o.mcid == nil,
        boss = isBoss(player) == true }
end

local pending = {} -- [src] = { id, idx, veh, plate, started, steps }

function MEC.tuneCancelWork(src) pending[src] = nil end
AddEventHandler('playerDropped', function() pending[source] = nil end)

local function mechanicAt(src, netId)
    local player = getPlayer(src)
    if not onDuty(player) then return nil, nil, 'off_duty' end
    local veh = vehicleOf(netId)
    if not veh then return nil, nil, 'no_car' end
    local ped = pedOf(src)
    if not ped or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > (S.reach or 4.0) + 3.0 then return nil, nil, 'too_far' end
    if not inWorkshop(src) then return nil, nil, 'not_workshop' end
    return player, veh
end

lib.callback.register('exti_mechanic:server:tuneStart', function(source, netId, orderId, idx)
    local player, veh, err = mechanicAt(source, netId)
    if not player then return false, err end
    local plate = plateOf(veh)
    local o = plate and OPEN[plate]
    if not o or o.id ~= math.tointeger(tonumber(orderId)) then return false, 'gone' end
    local l = o.lines[math.tointeger(tonumber(idx)) or 0]
    if not l or l.done then return false, 'gone' end
    local cid = player.PlayerData.citizenid
    if o.mcid and o.mcid ~= cid and not isBoss(player) then return false, 'claimed' end
    if (l.count or 0) > 0 and itemCount(source, l.item) < l.count then return false, 'no_part' end
    if not o.mcid then
        o.mcid, o.mname = cid, nameOf(player)
        saveLines(o)
    end
    local recipe = S.recipes[l.recipe] and l.recipe or 't_small'
    local times = l.times or 1
    pending[source] = { id = o.id, idx = math.tointeger(tonumber(idx)), veh = veh, plate = plate, started = os.time(), steps = #S.recipes[recipe] * times }
    return { recipe = recipe, times = times, steps = S.recipes[recipe], label = l.label }
end)

-- put the change on the car: the car's owner game sets it (ox_lib), and it is saved on the car
local function applyToCar(veh, plate, props)
    Entity(veh).state:set('ox_lib:setVehicleProperties', props, true)
    local row = MySQL.single.await('SELECT `id`, `mods` FROM `player_vehicles` WHERE `plate` = ? OR TRIM(`plate`) = ? LIMIT 1', { plate, plate })
    if not row then return end
    local mods = decode(row.mods) or {}
    for k, v in pairs(props) do mods[k] = v end
    MySQL.update.await('UPDATE `player_vehicles` SET `mods` = ? WHERE `id` = ?', { json.encode(mods), row.id })
end

lib.callback.register('exti_mechanic:server:tuneDone', function(source, success)
    local p = pending[source]
    pending[source] = nil
    if not p then return false, 'failed' end
    if success ~= true then return false, 'cancelled' end
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if not DoesEntityExist(p.veh) then return false, 'no_car' end
    local ped = pedOf(source)
    if not ped or #(GetEntityCoords(ped) - GetEntityCoords(p.veh)) > (S.reach or 4.0) + 3.0 then return false, 'too_far' end
    if os.time() - p.started < math.max(3, p.steps) then return false, 'too_fast' end
    local o = OPEN[p.plate]
    if not o or o.id ~= p.id then return false, 'gone' end
    local l = o.lines[p.idx]
    if not l or l.done then return false, 'gone' end
    if (l.count or 0) > 0 then
        local okR, removed = pcall(function() return exports.ox_inventory:RemoveItem(source, l.item, l.count) end)
        if not okR or not removed then return false, 'no_part' end
    end
    l.done, l.by, l.at = true, nameOf(player), os.time()
    applyToCar(p.veh, p.plate, l.props or {})
    saveLines(o)
    MEC.log(source, 'tune_installed', ('#%d · %s · %s'):format(o.id, o.plate, l.label))
    lib.logger(source, 'mechanic', ('installed "%s" on %s (order #%d)'):format(l.label, o.plate, o.id))
    local left = 0
    for _, x in ipairs(o.lines) do if not x.done then left = left + 1 end end
    if left == 0 then
        o.status = 'done'
        MySQL.update.await("UPDATE `exti_mechanic_tune_orders` SET `status` = 'done', `finished` = ?, `lines` = ? WHERE `id` = ?", { os.time(), json.encode(o.lines), o.id })
        OPEN[o.plate] = nil
        publishPlates()
        local names = {}
        for _, x in ipairs(o.lines) do names[#names + 1] = x.label end
        MySQL.insert('INSERT INTO `exti_mechanic_service` (`plate`, `at`, `citizenid`, `name`, `what`, `km`) VALUES (?, ?, ?, ?, ?, ?)',
            { o.plate, os.time(), player.PlayerData.citizenid, nameOf(player), ('تعديل: %s'):format(table.concat(names, '، ')):sub(1, 120), nil })
        MEC.log(source, 'tune_done', ('#%d · %s'):format(o.id, o.plate))
        local c = playerByCid(o.cid)
        if c then notify(c.PlayerData.source, 'success', ('انتهى تعديل سيارتك %s! تعال استلمها من الورشة'):format(o.plate)) end
    end
    return { label = l.label, left = left, id = o.id }
end)
