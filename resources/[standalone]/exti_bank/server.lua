-- EX_Tii Bank (server)
-- Every money action is checked and done here. The tablet / ATM / phone only ask.
--  * whole numbers only, between Config.minAmount and the limit
--  * one action at a time per player (no double spending), short cooldown
--  * a transfer takes the money from one player and gives it to the other in the same step;
--    if giving fails, the sender gets it back
--  * every bank-money change on the server (shops, impound, jobs, paychecks...) is written into
--    the player's history with a clear description, so nobody wonders where money went

local RB = 'Renewed-Banking'
local sessions = {}   -- [src] = { kind = 'bank' | 'atm', area = string }
local busy = {}       -- [src] = true while an action runs
local lastAction = {} -- [src] = GetGameTimer() of the last action
local pending = {}    -- [src] = description for the very next bank-money change of this player
local historyFor      -- (defined below)
local billsFor        -- (defined below)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function charName(player)
    local info = player and player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(info.firstname or '', info.lastname or ''):match('^%s*(.-)%s*$')
    return name ~= '' and name or 'مواطن'
end

local function balances(player)
    local m = player.PlayerData.money or {}
    return math.floor(tonumber(m.cash) or 0), math.floor(tonumber(m.bank) or 0)
end

local function accountNumber(citizenid)
    return ('EX-%s'):format(tostring(citizenid or ''):upper())
end

local function audit(text, ...)
    lib.print.info(('[bank] ' .. text):format(...))
end

local function suspicious(src, text, ...)
    lib.print.warn(('[bank] SUSPICIOUS %s (%s): ' .. text):format(GetPlayerName(src) or '?', src, ...))
end

--- a whole number in range, or nil
local function readAmount(value, max)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n % 1 ~= 0 then return nil end
    n = math.tointeger(n)
    if not n or n < Config.minAmount or n > max then return nil end
    return n
end

local function cleanNote(value)
    if type(value) ~= 'string' or not utf8.len(value) then return '' end
    value = value:gsub('[%c<>~^\\]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    local len = utf8.len(value)
    if len and len > Config.noteLength then
        value = value:sub(1, utf8.offset(value, Config.noteLength + 1) - 1)
    end
    return value
end

local function rbReady()
    return GetResourceState(RB) == 'started'
end

---------------------------------------------------------------------------
-- history: every bank-money change gets a line
---------------------------------------------------------------------------
local function describe(reason, action)
    reason = type(reason) == 'string' and reason or ''
    local exact = Config.reasons[reason]
    if exact then return exact, '' end
    local key, extra = reason:match('^([^|]+)|(.+)$') -- "fuel|Grove Street" = title + where
    if key and Config.reasons[key] then return Config.reasons[key], extra end
    local shopType = reason:match('^shop%-(.+)$')
    if shopType then return 'مشتريات · ' .. (Config.shopLabels[shopType] or 'متجر'), '' end
    local bought = reason:match('^Purchased (.+)$')
    if bought then return 'شراء عقار', bought end
    local rent = reason:match('^Rent for (.+)$')
    if rent then return 'إيجار عقار', rent end
    local note = (reason ~= '' and reason ~= 'unknown') and reason or ''
    return action == 'add' and 'إضافة إلى الحساب' or 'خصم من الحساب', note
end

local function log(cid, title, amount, note, issuer, receiver, kind, transId)
    if not rbReady() then return nil end
    local ok, result = pcall(function()
        return exports[RB]:logPlayerTransaction(cid, title, amount, note or '', issuer or '', receiver or '', kind, transId)
    end)
    if not ok then lib.print.error(('[bank] history not saved for %s: %s'):format(cid, result)) end
    return ok and result or nil
end

-- an open tablet / ATM always shows the real balances (paychecks, incoming transfers...)
local pushQueued = {}
local function pushBalances(src)
    if not sessions[src] or pushQueued[src] then return end
    pushQueued[src] = true
    SetTimeout(200, function()
        pushQueued[src] = nil
        if not sessions[src] then return end
        local player = getPlayer(src)
        if not player then return end
        local cash, bank = balances(player)
        TriggerClientEvent('exti_bank:client:balance', src, {
            cash = cash, bank = bank, history = historyFor(player.PlayerData.citizenid),
            bills = billsFor(player.PlayerData.citizenid),
        })
    end)
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, action, reason)
    local ctx = pending[src]
    pending[src] = nil
    if moneyType == 'cash' or moneyType == 'bank' then pushBalances(src) end
    if moneyType ~= 'bank' or (action ~= 'add' and action ~= 'remove') then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    local player = getPlayer(src)
    if not player then return end

    local title, note, issuer, receiver, transId
    if ctx then
        title, note, issuer, receiver, transId = ctx.title, ctx.note, ctx.issuer, ctx.receiver, ctx.transId
    else
        title, note = describe(reason, action)
        local me, place = charName(player), Config.bankName
        issuer, receiver = action == 'add' and place or me, action == 'add' and me or place
    end
    local saved = log(player.PlayerData.citizenid, title, amount, note, issuer, receiver,
        action == 'add' and 'deposit' or 'withdraw', transId)
    if ctx and ctx.onSaved then ctx.onSaved(saved) end
end)

--- move bank money with a description for the history line it makes
local function bankMove(target, action, amount, reason, ctx)
    local src = type(target) == 'table' and target.PlayerData.source or target
    pending[src] = ctx
    local player = type(target) == 'table' and target or getPlayer(src)
    local ok = player and (action == 'add' and player.Functions.AddMoney('bank', amount, reason)
        or action == 'remove' and player.Functions.RemoveMoney('bank', amount, reason))
    pending[src] = nil
    return ok and true or false
end

function historyFor(cid)
    if not rbReady() then return {} end
    local ok, list = pcall(function() return exports[RB]:getPlayerTransactions(cid, Config.historyLimit) end)
    local out = {}
    if ok and type(list) == 'table' then
        for i = 1, #list do
            local t = list[i]
            out[#out + 1] = {
                id = t.trans_id, title = t.title, amount = tonumber(t.amount) or 0,
                dir = t.trans_type == 'deposit' and 'in' or 'out',
                note = t.message, from = t.issuer, to = t.receiver, time = t.time,
            }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- the actions
---------------------------------------------------------------------------
local function begin(src)
    if busy[src] then return false, 'busy' end
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < Config.cooldown * 1000 then return false, 'cooldown' end
    busy[src], lastAction[src] = true, now
    return true
end

local function finish(src) busy[src] = nil end

local function snapshot(src)
    local player = getPlayer(src)
    if not player then return nil end
    local cash, bank = balances(player)
    return { cash = cash, bank = bank, history = historyFor(player.PlayerData.citizenid), bills = billsFor(player.PlayerData.citizenid) }
end

local function deposit(src, amount, where)
    local player = getPlayer(src)
    if not player then return false, 'failed' end
    local cash = balances(player)
    if cash < amount then return false, 'no_cash' end
    if not player.Functions.RemoveMoney('cash', amount, 'bank-deposit') then return false, 'no_cash' end
    if not bankMove(player, 'add', amount, 'bank-deposit',
        { title = 'إيداع نقدي', note = where, issuer = charName(player), receiver = Config.bankName }) then
        player.Functions.AddMoney('cash', amount, 'bank-deposit-refund')
        return false, 'failed'
    end
    audit('%s (%s) deposited $%d (%s)', GetPlayerName(src), player.PlayerData.citizenid, amount, where)
    return true
end

local function canHoldCash(src, amount)
    if GetResourceState('ox_inventory') ~= 'started' then return true end
    local ok, can = pcall(function() return exports.ox_inventory:CanCarryItem(src, 'money', amount) end)
    return not ok or can ~= false
end

local function withdraw(src, amount, where)
    local player = getPlayer(src)
    if not player then return false, 'failed' end
    local _, bank = balances(player)
    if bank < amount then return false, 'no_bank' end
    -- the cash goes into the bag; with no free slot it would be lost
    if not canHoldCash(src, amount) then return false, 'no_room' end
    if not bankMove(player, 'remove', amount, 'bank-withdraw',
        { title = 'سحب نقدي', note = where, issuer = Config.bankName, receiver = charName(player) }) then
        return false, 'no_bank'
    end
    if not player.Functions.AddMoney('cash', amount, 'bank-withdraw') then
        bankMove(player, 'add', amount, 'bank-withdraw-refund',
            { title = 'استرداد سحب', note = where, issuer = Config.bankName, receiver = charName(player) })
        return false, 'failed'
    end
    audit('%s (%s) withdrew $%d (%s)', GetPlayerName(src), player.PlayerData.citizenid, amount, where)
    return true
end

--- player -> player (online only). via = 'bank' | 'phone'
---@return boolean ok, string? errorCode, table? info
local function transfer(src, targetSrc, amount, note, via)
    local player = getPlayer(src)
    if not player then return false, 'failed' end
    targetSrc = tonumber(targetSrc)
    local target = targetSrc and getPlayer(targetSrc)
    if not target then return false, 'not_found' end
    if target.PlayerData.citizenid == player.PlayerData.citizenid then return false, 'self' end
    local _, bank = balances(player)
    if bank < amount then return false, 'no_bank' end

    local fromName, toName = charName(player), charName(target)
    local title = via == 'phone' and 'تحويل عبر الهاتف' or 'تحويل بنكي'
    local transId
    if not bankMove(player, 'remove', amount, 'bank-transfer-out', {
        title = ('%s إلى %s'):format(title, toName), note = note, issuer = fromName, receiver = toName,
        onSaved = function(saved) transId = saved and saved.trans_id or nil end,
    }) then
        return false, 'no_bank'
    end
    if not bankMove(target, 'add', amount, 'bank-transfer-in', {
        title = ('%s من %s'):format(title, fromName), note = note, issuer = fromName, receiver = toName, transId = transId,
    }) then
        bankMove(player, 'add', amount, 'bank-transfer-refund',
            { title = 'استرداد تحويل', note = toName, issuer = Config.bankName, receiver = fromName })
        return false, 'failed'
    end
    audit('%s (%s) sent $%d to %s (%s) via %s', GetPlayerName(src), player.PlayerData.citizenid, amount,
        GetPlayerName(targetSrc), target.PlayerData.citizenid, via)
    return true, nil, { name = toName, targetSrc = targetSrc, fromName = fromName }
end

---------------------------------------------------------------------------
-- bills: money a player owes (a police fine...). A bill stays in his bank until he pays it,
-- at the teller tablet or the ATM. The money goes to the job account that wrote it (society).
---------------------------------------------------------------------------
local billsReady = false
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_bank_bills` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(20) NOT NULL DEFAULT 'bill',
        `title` VARCHAR(120) NOT NULL,
        `note` VARCHAR(255) NULL,
        `amount` INT NOT NULL,
        `issuer` VARCHAR(80) NULL,
        `society` VARCHAR(40) NULL,
        `ref` VARCHAR(60) NULL,
        `created` INT NOT NULL,
        `paid` INT NULL,
        `paid_from` VARCHAR(10) NULL,
        INDEX `cid_paid` (`citizenid`, `paid`)
    ) DEFAULT CHARSET=utf8mb4]])
    billsReady = true
end)

local function cleanText(value, max)
    if type(value) ~= 'string' or not utf8.len(value) then return nil end
    value = value:gsub('[%c<>~^\\]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if value == '' then return nil end
    local len = utf8.len(value)
    if len and len > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

local function billRow(r)
    return {
        id = r.id, kind = r.kind, title = r.title, note = r.note, amount = tonumber(r.amount) or 0,
        issuer = r.issuer, society = r.society, created = r.created, paid = r.paid,
    }
end

--- the bills of a citizen (unpaid, newest first; all = paid ones too, the newest 50)
function billsFor(cid, all)
    if not billsReady or not cid then return {} end
    local rows = all
        and MySQL.query.await('SELECT * FROM `exti_bank_bills` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 50', { cid })
        or MySQL.query.await('SELECT * FROM `exti_bank_bills` WHERE `citizenid` = ? AND `paid` IS NULL ORDER BY `id` DESC', { cid })
    local out = {}
    for i = 1, #(rows or {}) do out[i] = billRow(rows[i]) end
    return out
end

local function unpaidTotals(cid)
    if not billsReady or not cid then return 0, 0 end
    local r = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(`amount`), 0) AS total FROM `exti_bank_bills` WHERE `citizenid` = ? AND `paid` IS NULL', { cid })
    return tonumber(r and r.n) or 0, tonumber(r and r.total) or 0
end

local function srcOf(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    return ok and p and p.PlayerData.source or nil
end

--- another script writes a bill: AddBill(citizenid, { amount, title, note, issuer, society, kind, ref }) -> id
local function addBill(cid, data)
    if not billsReady or type(cid) ~= 'string' or type(data) ~= 'table' then return nil, 'failed' end
    local amount = readAmount(data.amount, Config.maxAmount)
    local title = cleanText(data.title, 120)
    if not amount or not title then return nil, 'amount' end
    local id = MySQL.insert.await('INSERT INTO `exti_bank_bills` (`citizenid`, `kind`, `title`, `note`, `amount`, `issuer`, `society`, `ref`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        cid, cleanText(data.kind, 20) or 'bill', title, cleanText(data.note, 255), amount,
        cleanText(data.issuer, 80), cleanText(data.society, 40), cleanText(data.ref, 60), os.time(),
    })
    if not id then return nil, 'failed' end
    audit('bill #%d for %s: %s $%d (%s)', id, cid, title, amount, data.society or '-')
    local src = srcOf(cid)
    if src then
        TriggerClientEvent('exti_bank:client:bill', src, { id = id, title = title, amount = amount, issuer = cleanText(data.issuer, 80) })
        pushBalances(src)
    end
    return id
end

--- the player pays one of his bills from his bank account or his cash
---@return boolean ok, string? errorCode, table? bill
local function payBill(src, id, account)
    if not billsReady then return false, 'failed' end
    local player = getPlayer(src)
    if not player then return false, 'failed' end
    id = math.tointeger(tonumber(id))
    if not id then return false, 'failed' end
    if account ~= 'bank' and account ~= 'cash' then return false, 'failed' end
    local cid = player.PlayerData.citizenid
    local r = MySQL.single.await('SELECT * FROM `exti_bank_bills` WHERE `id` = ? AND `citizenid` = ? AND `paid` IS NULL', { id, cid })
    if not r then return false, 'no_bill' end
    local bill = billRow(r)
    local cash, bank = balances(player)
    if account == 'bank' and bank < bill.amount then return false, 'no_bank' end
    if account == 'cash' and cash < bill.amount then return false, 'no_cash' end

    -- mark it paid first: two screens cannot pay the same bill twice
    local changed = MySQL.update.await('UPDATE `exti_bank_bills` SET `paid` = ?, `paid_from` = ? WHERE `id` = ? AND `paid` IS NULL', { os.time(), account, id })
    if not changed or changed < 1 then return false, 'no_bill' end

    local me = charName(player)
    local societyLabel = Config.societies[bill.society or ''] or bill.society or Config.bankName
    local taken
    if account == 'bank' then
        taken = bankMove(player, 'remove', bill.amount, 'paid-bills',
            { title = 'دفع فاتورة · ' .. bill.title, note = bill.issuer or '', issuer = me, receiver = societyLabel })
    else
        taken = player.Functions.RemoveMoney('cash', bill.amount, 'paid-bills')
    end
    if not taken then
        MySQL.update.await('UPDATE `exti_bank_bills` SET `paid` = NULL, `paid_from` = NULL WHERE `id` = ?', { id })
        return false, account == 'bank' and 'no_bank' or 'no_cash'
    end
    if bill.society and rbReady() then
        pcall(function()
            exports[RB]:addAccountMoney(bill.society, bill.amount)
            exports[RB]:handleTransaction(bill.society, 'فاتورة مدفوعة', bill.amount, bill.title, me, societyLabel, 'deposit')
        end)
    end
    audit('%s (%s) paid bill #%d %s $%d from %s', GetPlayerName(src) or src, cid, id, bill.title, bill.amount, account)
    bill.paid, bill.paidFrom = os.time(), account
    TriggerEvent('exti_bank:server:billPaid', cid, bill, src)
    return true, nil, bill
end

-- a reminder when you come into the city with unpaid bills
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    local cid = player.PlayerData.citizenid
    SetTimeout(20000, function()
        if not getPlayer(src) then return end
        local n, total = unpaidTotals(cid)
        if n > 0 then
            TriggerClientEvent('exti_bank:client:billsReminder', src, { count = n, total = total })
        end
    end)
end)

-- the script that wrote a bill takes it back (unpaid ones only)
local function cancelBill(id)
    id = math.tointeger(tonumber(id))
    if not billsReady or not id then return false end
    local r = MySQL.single.await('SELECT `citizenid` FROM `exti_bank_bills` WHERE `id` = ? AND `paid` IS NULL', { id })
    if not r then return false end
    MySQL.query.await('DELETE FROM `exti_bank_bills` WHERE `id` = ? AND `paid` IS NULL', { id })
    local src = srcOf(r.citizenid)
    if src then pushBalances(src) end
    return true
end

exports('AddBill', addBill)
exports('CancelBill', cancelBill)
exports('PayBill', payBill)
exports('GetBills', function(cid, all) return billsFor(cid, all == true) end)
exports('UnpaidBills', function(cid) local n, total = unpaidTotals(cid) return n, total end)

---------------------------------------------------------------------------
-- the tablet and the ATM
---------------------------------------------------------------------------
local function nearTeller(src)
    if GetResourceState('exti_shops') ~= 'started' then return nil end
    local ok, area = pcall(function() return exports.exti_shops:NearStore(src, 'bank', Config.tellerDistance) end)
    return ok and area or nil
end

lib.callback.register('exti_bank:server:open', function(source, kind)
    if kind ~= 'bank' and kind ~= 'atm' then return false end
    local player = getPlayer(source)
    if not player then return false end
    if not rbReady() then return false, 'offline' end
    local area
    if kind == 'bank' then
        area = nearTeller(source)
        if not area then return false, 'too_far' end
    end
    sessions[source] = {
        kind = kind,
        area = type(area) == 'string' and area or nil,
        at = GetEntityCoords(GetPlayerPed(source)), -- where it was opened (the ATM)
        opened = os.time(),
    }
    local cash, bank = balances(player)
    return {
        kind = kind,
        bankName = Config.bankName,
        branch = sessions[source].area,
        name = charName(player),
        account = accountNumber(player.PlayerData.citizenid),
        cash = cash,
        bank = bank,
        history = historyFor(player.PlayerData.citizenid),
        bills = billsFor(player.PlayerData.citizenid),
        limits = { min = Config.minAmount, max = kind == 'atm' and Config.atmMax or Config.maxAmount, note = Config.noteLength },
    }
end)

lib.callback.register('exti_bank:server:close', function(source)
    sessions[source] = nil
    return true
end)

lib.callback.register('exti_bank:server:lookup', function(source, targetId)
    local s = sessions[source]
    if not s or s.kind ~= 'bank' then return false end
    targetId = tonumber(targetId)
    if not targetId or targetId % 1 ~= 0 then return false end
    local target = getPlayer(targetId)
    if not target then return false end
    local player = getPlayer(source)
    if player and target.PlayerData.citizenid == player.PlayerData.citizenid then return { self = true } end
    return { name = charName(target), account = accountNumber(target.PlayerData.citizenid) }
end)

lib.callback.register('exti_bank:server:action', function(source, action, data)
    local src = source
    local s = sessions[src]
    if not s or type(data) ~= 'table' then return { ok = false, code = 'closed' } end
    if os.time() - (s.opened or 0) > Config.sessionMinutes * 60 then
        sessions[src] = nil
        return { ok = false, code = 'closed' }
    end
    if s.kind == 'bank' and not nearTeller(src) then
        sessions[src] = nil
        return { ok = false, code = 'too_far' }
    end
    if s.kind == 'atm' and s.at and #(GetEntityCoords(GetPlayerPed(src)) - s.at) > Config.atmDistance then
        sessions[src] = nil
        return { ok = false, code = 'too_far_atm' }
    end
    if action == 'transfer' and s.kind ~= 'bank' then
        suspicious(src, 'transfer from an ATM')
        return { ok = false, code = 'failed' }
    end
    if action == 'paybill' then
        local started, why = begin(src)
        if not started then return { ok = false, code = why } end
        local ok, result, code, bill = pcall(payBill, src, data.id, data.account)
        finish(src)
        if not ok then
            lib.print.error(('[bank] paybill failed for %s: %s'):format(src, result))
            return { ok = false, code = 'failed' }
        end
        if not result then return { ok = false, code = code or 'failed' } end
        local snap = snapshot(src) or {}
        snap.ok, snap.amount, snap.bill = true, bill.amount, bill
        return snap
    end
    if action ~= 'deposit' and action ~= 'withdraw' and action ~= 'transfer' then return { ok = false, code = 'failed' } end

    local amount = readAmount(data.amount, s.kind == 'atm' and Config.atmMax or Config.maxAmount)
    if not amount then
        if tonumber(data.amount) and tonumber(data.amount) < 0 then suspicious(src, 'negative amount %s', tostring(data.amount)) end
        return { ok = false, code = 'amount' }
    end

    local started, why = begin(src)
    if not started then return { ok = false, code = why } end

    local where = s.kind == 'atm' and 'صراف آلي' or ('فرع ' .. (s.area or Config.bankName))
    local ok, result, code, info = pcall(function()
        if action == 'deposit' then return deposit(src, amount, where) end
        if action == 'withdraw' then return withdraw(src, amount, where) end
        -- the account shown when the receiver was checked must still be the one on that ID
        if type(data.account) == 'string' then
            local target = getPlayer(tonumber(data.target) or -1)
            if not target or accountNumber(target.PlayerData.citizenid) ~= data.account then
                return false, 'not_found'
            end
        end
        return transfer(src, data.target, amount, cleanNote(data.note), 'bank')
    end)
    finish(src)

    if not ok then
        lib.print.error(('[bank] %s failed for %s: %s'):format(action, src, result))
        return { ok = false, code = 'failed' }
    end
    if not result then return { ok = false, code = code or 'failed' } end

    if action == 'transfer' and info then
        TriggerClientEvent('exti_bank:client:received', info.targetSrc, { amount = amount, name = info.fromName, note = cleanNote(data.note) })
    end
    local snap = snapshot(src) or {}
    snap.ok, snap.amount, snap.name = true, amount, info and info.name or nil
    return snap
end)

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src], busy[src], lastAction[src], pending[src], pushQueued[src] = nil, nil, nil, nil, nil
end)

---------------------------------------------------------------------------
-- for other scripts (the phone bank app)
---------------------------------------------------------------------------
--- Transfer(src, targetSrc, amount, note, via) -> ok, errorCode, { name }
exports('Transfer', function(src, targetSrc, amount, note, via)
    if not rbReady() then return false, 'failed' end -- no history without the bank records
    amount = readAmount(amount, Config.maxAmount)
    if not amount then return false, 'amount' end
    local started, why = begin(src)
    if not started then return false, why end
    local ok, result, code, info = pcall(transfer, src, targetSrc, amount, cleanNote(note), via or 'phone')
    finish(src)
    if not ok then
        lib.print.error(('[bank] transfer failed for %s: %s'):format(src, result))
        return false, 'failed'
    end
    return result, code, info
end)

exports('GetHistory', function(citizenid) return historyFor(citizenid) end)
