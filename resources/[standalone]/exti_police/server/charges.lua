-- =====================================================================
-- EX_Tii Police (server): charges. The list of offences (fine + jail minutes each, the chief edits it
-- on the tablet), and the charge sheet an officer writes to the person next to him on the street:
-- the fine becomes a bill in his bank (exti_bank), paid at the teller or the ATM into the police
-- account. Every sheet is kept (the person's record on the tablet, round 2 step 4).
-- =====================================================================

local JOB = Config.job
local C = Config.charges
local getPlayer, onDuty, isBoss, nameOf, notify, pedOf = POL.getPlayer, POL.onDuty, POL.isBoss, POL.nameOf, POL.notify, POL.pedOf

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function int(x)
    local n = tonumber(x)
    if not n or n ~= n or n == math.huge or n % 1 ~= 0 then return nil end
    return math.tointeger(n)
end

local function cleanText(value, max)
    if type(value) ~= 'string' or not utf8.len(value) then return nil end
    value = value:gsub('[%c<>~^\\]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if value == '' then return nil end
    local len = utf8.len(value)
    if len and len > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

local busy = {}
local function slow(src, key, ms)
    local now = GetGameTimer()
    busy[src] = busy[src] or {}
    if busy[src][key] and now - busy[src][key] < ms then return true end
    busy[src][key] = now
    return false
end
AddEventHandler('playerDropped', function() busy[source] = nil end)

-- the tablet apps call these (exti_police:server:tab_<name>, like server/tablet.lua)
local function cb(name, fn)
    lib.callback.register('exti_police:server:tab_' .. name, function(source, ...)
        if slow(source, 'cb:' .. name, 200) then return false, 'wait' end
        return fn(source, ...)
    end)
end

---------------------------------------------------------------------------
-- the tables
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_offences` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `label` VARCHAR(80) NOT NULL,
        `category` VARCHAR(40) NOT NULL,
        `fine` INT NOT NULL DEFAULT 0,
        `jail` INT NOT NULL DEFAULT 0,
        `sort` INT NOT NULL DEFAULT 0,
        `active` TINYINT NOT NULL DEFAULT 1,
        `updated_by` VARCHAR(50) NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_charges` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `officer` VARCHAR(80) NOT NULL,
        `kind` VARCHAR(10) NOT NULL DEFAULT 'fine',
        `offences` LONGTEXT NOT NULL,
        `fine` INT NOT NULL DEFAULT 0,
        `jail` INT NOT NULL DEFAULT 0,
        `note` VARCHAR(255) NULL,
        `bill_id` INT NULL,
        `created` INT NOT NULL,
        INDEX `cid_created` (`citizenid`, `created`)
    ) DEFAULT CHARSET=utf8mb4]])

    -- the very first time only: the starting list from config.lua
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM `exti_police_offences`') or 0
    if n == 0 and GetResourceKvpInt('offences_seeded') ~= 1 then
        for i, d in ipairs(C.defaults or {}) do
            MySQL.insert.await('INSERT INTO `exti_police_offences` (`label`, `category`, `fine`, `jail`, `sort`) VALUES (?, ?, ?, ?, ?)',
                { d[1], d[2], math.floor(d[3] or 0), math.floor(d[4] or 0), i })
        end
        SetResourceKvpInt('offences_seeded', 1)
    end
end)

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------
local function offences()
    local rows = MySQL.query.await('SELECT `id`, `label`, `category`, `fine`, `jail` FROM `exti_police_offences` WHERE `active` = 1 ORDER BY `sort`, `id`') or {}
    for i = 1, #rows do
        rows[i].fine = tonumber(rows[i].fine) or 0
        rows[i].jail = tonumber(rows[i].jail) or 0
    end
    return rows
end

local function check(src)
    local player = getPlayer(src)
    if not onDuty(player) then return nil, 'off_duty' end
    return player
end

local function bossCheck(src)
    local player, err = check(src)
    if not player then return nil, err end
    if not isBoss(player) then return nil, 'not_boss' end
    return player
end

cb('offences', function(source)
    local player, err = check(source)
    if not player then return false, err end
    return { list = offences(), isBoss = isBoss(player), maxFine = C.maxFine, maxJail = C.maxJail }
end)

-- the chief adds (id = nil) or edits one
cb('offenceSave', function(source, id, label, category, fine, jail)
    local player, err = bossCheck(source)
    if not player then return false, err end
    label = cleanText(label, 80)
    category = cleanText(category, 40)
    fine, jail = int(fine), int(jail)
    if not label or utf8.len(label) < 2 then return false, 'label' end
    if not category then return false, 'category' end
    if not fine or fine < 0 or fine > C.maxFine then return false, 'fine' end
    if not jail or jail < 0 or jail > C.maxJail then return false, 'jail' end
    id = int(id)
    if id then
        local changed = MySQL.update.await('UPDATE `exti_police_offences` SET `label` = ?, `category` = ?, `fine` = ?, `jail` = ?, `updated_by` = ? WHERE `id` = ? AND `active` = 1',
            { label, category, fine, jail, player.PlayerData.citizenid, id })
        if not changed or changed < 1 then return false, 'failed' end
        POL.log(source, 'offence_changed', ('%s · $%d · %d دقيقة'):format(label, fine, jail))
    else
        local sort = (MySQL.scalar.await('SELECT COALESCE(MAX(`sort`), 0) FROM `exti_police_offences`') or 0) + 1
        id = MySQL.insert.await('INSERT INTO `exti_police_offences` (`label`, `category`, `fine`, `jail`, `sort`, `updated_by`) VALUES (?, ?, ?, ?, ?, ?)',
            { label, category, fine, jail, sort, player.PlayerData.citizenid })
        if not id then return false, 'failed' end
        POL.log(source, 'offence_added', ('%s · $%d · %d دقيقة'):format(label, fine, jail))
    end
    return { list = offences(), id = id }
end)

cb('offenceDelete', function(source, id)
    local player, err = bossCheck(source)
    if not player then return false, err end
    id = int(id)
    if not id then return false, 'failed' end
    local row = MySQL.single.await('SELECT `label` FROM `exti_police_offences` WHERE `id` = ? AND `active` = 1', { id })
    if not row then return false, 'failed' end
    MySQL.update.await('UPDATE `exti_police_offences` SET `active` = 0, `updated_by` = ? WHERE `id` = ?', { player.PlayerData.citizenid, id })
    POL.log(source, 'offence_removed', row.label)
    return { list = offences() }
end)

---------------------------------------------------------------------------
-- the charge sheet on the street
---------------------------------------------------------------------------
local S = Config.street

local function nearTarget(copSrc, targetId)
    local cop = getPlayer(copSrc)
    if not onDuty(cop) then return nil, nil, 'off_duty' end
    local tid = int(targetId)
    if not tid or tid == copSrc then return nil, nil, 'nobody' end
    local target = getPlayer(tid)
    local cped, tped = pedOf(copSrc), pedOf(tid)
    if not target or not cped or not tped then return nil, nil, 'nobody' end
    if #(GetEntityCoords(cped) - GetEntityCoords(tped)) > S.reach + 2.5 then return nil, nil, 'too_far' end
    return cop, target, nil, tid
end

local function previousCount(cid)
    return MySQL.scalar.await('SELECT COUNT(*) FROM `exti_police_charges` WHERE `citizenid` = ?', { cid }) or 0
end

lib.callback.register('exti_police:server:chargeOpen', function(source, targetId)
    local cop, target, err, tid = nearTarget(source, targetId)
    if err then return false, err end
    return {
        target = { id = tid, name = nameOf(target), cid = target.PlayerData.citizenid, previous = previousCount(target.PlayerData.citizenid),
                   cuffed = POL.isCuffed and POL.isCuffed(tid) or false },
        officer = nameOf(cop),
        offences = offences(),
        maxPicks = C.maxPicks,
        noteLength = C.noteLength,
        bank = GetResourceState('exti_bank') == 'started',
        atPrison = POL.atPrisonIntake and POL.atPrisonIntake(source) or false, -- the سجن buttons work here only
    }
end)

-- ids = the ticked offences; mode = 'fine' (the bill only), 'jail' (prison + the bill),
-- 'jailonly' (prison, the bill was written earlier). Jail only at the prison gate, person cuffed.
lib.callback.register('exti_police:server:chargeIssue', function(source, targetId, ids, note, mode)
    if slow(source, 'charge', 1500) then return false, 'wait' end
    local cop, target, err, tid = nearTarget(source, targetId)
    if err then return false, err end
    if mode ~= 'fine' and mode ~= 'jail' and mode ~= 'jailonly' then return false, 'failed' end
    local wantJail = mode ~= 'fine'
    if wantJail then
        if not POL.jail then return false, 'soon' end
        if not POL.atPrisonIntake(source) then return false, 'not_at_prison' end
        if not (POL.isCuffed and POL.isCuffed(tid)) then return false, 'not_cuffed' end
    end
    if type(ids) ~= 'table' then return false, 'pick' end

    local wanted, order = {}, {}
    for _, v in ipairs(ids) do
        local id = int(v)
        if id and not wanted[id] then
            wanted[id] = true
            order[#order + 1] = id
        end
    end
    if #order == 0 then return false, 'pick' end
    if #order > C.maxPicks then return false, 'too_many' end

    local picked, fine, jail, labels = {}, 0, 0, {}
    for _, o in ipairs(offences()) do
        if wanted[o.id] then
            picked[#picked + 1] = { id = o.id, label = o.label, fine = o.fine, jail = o.jail }
            fine, jail = fine + o.fine, jail + o.jail
            labels[#labels + 1] = o.label
        end
    end
    if #picked ~= #order then return false, 'pick' end -- one of them is not in the list any more
    -- EX_Tii (Moe): away from the prison gate an officer may only write offences that carry no jail time.
    -- An offence with jail time is written at the gate, with the person cuffed (so nobody "fines away" a jail charge)
    if not wantJail then
        for _, o in ipairs(picked) do
            if (tonumber(o.jail) or 0) > 0 then return false, 'jail_here' end
        end
    end
    local withBill = mode == 'fine' or mode == 'jail'
    if withBill and fine < 1 and not wantJail then return false, 'no_fine' end
    if withBill and fine < 1 then withBill = false end -- jail with free offences: no bill
    if wantJail and jail < 1 then return false, 'no_jail' end
    if withBill and GetResourceState('exti_bank') ~= 'started' then return false, 'no_bank' end

    note = cleanText(note, C.noteLength)
    local officer, person = nameOf(cop), nameOf(target)
    local cid = target.PlayerData.citizenid
    local chargeId = MySQL.insert.await('INSERT INTO `exti_police_charges` (`citizenid`, `name`, `officer_cid`, `officer`, `kind`, `offences`, `fine`, `jail`, `note`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, person, cop.PlayerData.citizenid, officer, wantJail and 'jail' or 'fine', json.encode(picked), withBill and fine or 0, wantJail and jail or 0, note, os.time() })
    if not chargeId then return false, 'failed' end

    local billId
    if withBill then
        local title = 'غرامة: ' .. table.concat(labels, '، ')
        if utf8.len(title) > 118 then title = title:sub(1, utf8.offset(title, 116) - 1) .. '…' end
        local okBill, id = pcall(function()
            return exports.exti_bank:AddBill(cid, {
                amount = fine, title = title, note = note, issuer = officer, society = JOB, kind = 'fine', ref = 'charge:' .. chargeId,
            })
        end)
        if not okBill or not id then
            MySQL.query.await('DELETE FROM `exti_police_charges` WHERE `id` = ?', { chargeId })
            return false, 'failed'
        end
        billId = id
        MySQL.update.await('UPDATE `exti_police_charges` SET `bill_id` = ? WHERE `id` = ?', { billId, chargeId })
        POL.log(source, 'fine_issued', ('%s: %s'):format(person, table.concat(labels, '، ')), fine) -- money comes when he pays
        lib.logger(source, 'police', ('fined player %d (%s) $%d: %s'):format(tid, cid, fine, table.concat(labels, ', ')))
    end
    if wantJail then
        if not POL.jail(tid, jail, officer, chargeId, source) then
            if billId then pcall(function() exports.exti_bank:CancelBill(billId) end) end
            MySQL.query.await('DELETE FROM `exti_police_charges` WHERE `id` = ?', { chargeId })
            return false, 'failed'
        end
        lib.logger(source, 'police', ('jailed player %d (%s) %d min: %s'):format(tid, cid, jail, table.concat(labels, ', ')))
        notify(tid, 'warning', withBill
            and ('حكم عليك الشرطي %s بالسجن %d دقيقة وغرامة $%d'):format(officer, jail, fine)
            or ('حكم عليك الشرطي %s بالسجن %d دقيقة'):format(officer, jail))
    else
        notify(tid, 'warning', ('حرّر لك الشرطي %s مخالفة بقيمة $%d — ادفعها من البنك أو الصراف'):format(officer, fine))
    end
    -- the player level (exti_level): XP for the arrest / ticket, once per suspect per 30 minutes
    if GetResourceState('exti_level') == 'started' then
        pcall(function() exports.exti_level:AddXP(source, wantJail and 40 or 12, wantJail and 'سجن مشتبه' or 'تحرير مخالفة', 'police:' .. cid) end)
    end
    return { id = chargeId, fine = withBill and fine or 0, jail = wantJail and jail or 0, count = #picked, jailed = wantJail }
end)

-- a paid fine shows in the department log
AddEventHandler('exti_bank:server:billPaid', function(cid, bill)
    if type(bill) ~= 'table' or bill.society ~= JOB then return end
    local who = MySQL.scalar.await('SELECT `name` FROM `exti_police_charges` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 1', { cid }) or cid
    POL.log(nil, 'fine_paid', ('%s: %s'):format(who, bill.title or ''), bill.amount, 'in')
end)

-- for the other parts (the records app)
POL.chargesOf = function(cid, limit)
    local rows = MySQL.query.await('SELECT * FROM `exti_police_charges` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?', { cid, limit or 50 }) or {}
    for i = 1, #rows do
        local ok, list = pcall(json.decode, rows[i].offences or '[]')
        rows[i].offences = ok and type(list) == 'table' and list or {}
    end
    return rows
end
