-- =====================================================================
-- EX_Tii Police (server): the records on the tablet.
--   Citizens  (المواطنون): search by name / ID / phone; the record: licences, job, vehicles, charges,
--             prison, warrants, the officers' notes, cases and reports he appears in
--   Vehicles  (المركبات): search by plate / model: the owner, where it is, open BOLOs on it
--   Reports   (التقارير): incident / arrest reports with the citizens involved
--   Warrants  (أوامر القبض): open / closed, by citizen
--   BOLOs     (التعاميم): be-on-the-lookout for a vehicle or a person
--   Cases     (القضايا): open / closed, the officers on it, notes and photos from the gallery
-- Every callback is 'exti_police:server:tab_<name>' (on duty only).
-- =====================================================================

local JOB = Config.job
local getPlayer, onDuty, isBoss, nameOf = POL.getPlayer, POL.onDuty, POL.isBoss, POL.nameOf

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function int(x)
    local n = tonumber(x)
    if not n or n ~= n or n == math.huge or n % 1 ~= 0 then return nil end
    return math.tointeger(n)
end

local function cleanText(value, max, lines)
    if type(value) ~= 'string' or not utf8.len(value) then return nil end
    value = value:gsub('[\0-\8\11\12\14-\31<>~^\\]', ' ')
    if not lines then value = value:gsub('[\r\n]', ' ') end
    value = value:gsub('[ \t]+', ' '):match('^%s*(.-)%s*$') or ''
    if value == '' then return nil end
    local len = utf8.len(value)
    if len and len > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

local function like(q) return '%' .. (q or ''):gsub('[%%_]', '') .. '%' end

local busy = {}
local function slow(src, key, ms)
    local now = GetGameTimer()
    busy[src] = busy[src] or {}
    if busy[src][key] and now - busy[src][key] < ms then return true end
    busy[src][key] = now
    return false
end
AddEventHandler('playerDropped', function() busy[source] = nil end)

local function cb(name, fn)
    lib.callback.register('exti_police:server:tab_' .. name, function(source, ...)
        if slow(source, 'cb:' .. name, 200) then return false, 'wait' end
        local player = getPlayer(source)
        if not onDuty(player) then return false, 'off_duty' end
        return fn(source, player, ...)
    end)
end

local function decode(s)
    if type(s) == 'table' then return s end
    local ok, v = pcall(json.decode, s or '')
    return ok and type(v) == 'table' and v or {}
end

local function cidOf(p) return p.PlayerData.citizenid end

-- the people in a record: "[{cid,name},...]" kept as JSON
local function people(raw)
    local list = decode(raw)
    local out = {}
    for _, p in ipairs(list) do
        if type(p) == 'table' and type(p.cid) == 'string' then out[#out + 1] = { cid = p.cid, name = tostring(p.name or p.cid) } end
    end
    return out
end

local vehicleLabels
local function vehicleLabel(model)
    if not vehicleLabels then
        local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
        vehicleLabels = ok and type(list) == 'table' and list or {}
    end
    local v = vehicleLabels[model]
    return v and (v.name or v.label) or model
end

local STATE_LABEL = { [0] = 'في الشارع', [1] = 'في المرآب', [2] = 'في الحجز' }

---------------------------------------------------------------------------
-- the tables
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_notes` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `text` VARCHAR(500) NOT NULL,
        `officer` VARCHAR(80) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `created` INT NOT NULL,
        INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_reports` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(120) NOT NULL,
        `text` TEXT NOT NULL,
        `people` LONGTEXT NULL,
        `officer` VARCHAR(80) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `created` INT NOT NULL,
        `updated` INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_warrants` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `reason` VARCHAR(255) NOT NULL,
        `officer` VARCHAR(80) NOT NULL,
        `created` INT NOT NULL,
        `closed` INT NULL,
        `closed_by` VARCHAR(80) NULL,
        INDEX `cid_closed` (`citizenid`, `closed`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_bolos` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `kind` VARCHAR(10) NOT NULL,
        `title` VARCHAR(120) NOT NULL,
        `text` VARCHAR(500) NULL,
        `plate` VARCHAR(12) NULL,
        `officer` VARCHAR(80) NOT NULL,
        `created` INT NOT NULL,
        `closed` INT NULL,
        `closed_by` VARCHAR(80) NULL,
        INDEX `plate` (`plate`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_cases` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(120) NOT NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'open',
        `text` TEXT NULL,
        `people` LONGTEXT NULL,
        `officers` LONGTEXT NULL,
        `officer` VARCHAR(80) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `created` INT NOT NULL,
        `updated` INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_case_items` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `case_id` INT NOT NULL,
        `kind` VARCHAR(10) NOT NULL,
        `text` VARCHAR(500) NULL,
        `url` VARCHAR(300) NULL,
        `officer` VARCHAR(80) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `created` INT NOT NULL,
        INDEX `case_id` (`case_id`)
    ) DEFAULT CHARSET=utf8mb4]])
end)

---------------------------------------------------------------------------
-- citizens
---------------------------------------------------------------------------
local function citizenRow(r)
    local info = decode(r.charinfo)
    local job = decode(r.job)
    return {
        cid = r.citizenid,
        name = ('%s %s'):format(info.firstname or '', info.lastname or ''):match('^%s*(.-)%s*$'),
        phone = info.phone and tostring(info.phone) or nil,
        dob = info.birthdate,
        gender = tonumber(info.gender) == 1 and 'أنثى' or 'ذكر',
        nationality = info.nationality,
        job = job.label or job.name, jobGrade = job.grade and job.grade.name or nil,
    }
end

-- a few people by name / ID / phone (the charinfo JSON holds the name and the phone). "first last"
-- is two words: every word must be somewhere in the record
local function findCitizens(q, limit)
    q = cleanText(q, 40)
    q = q and q:gsub('[%%_]', ''):match('^%s*(.-)%s*$') or nil
    if not q or q == '' then return {} end
    local words, params = {}, { q }
    for w in q:gmatch('%S+') do
        words[#words + 1] = '`charinfo` LIKE ?'
        params[#params + 1] = like(w)
        if #words >= 4 then break end
    end
    params[#params + 1] = limit or 25
    local rows = MySQL.query.await('SELECT `citizenid`, `charinfo`, `job` FROM `players` WHERE `citizenid` = ? OR (' .. table.concat(words, ' AND ') .. ') ORDER BY `citizenid` LIMIT ?', params) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = citizenRow(r) end
    return out
end

-- "name, name, ID" typed in a form -> [{cid,name}]
local function resolvePeople(text)
    local out, seen = {}, {}
    for token in tostring(text or ''):gsub('،', ','):gmatch('[^,\n]+') do
        local t = token:match('^%s*(.-)%s*$')
        if t ~= '' then
            local found = findCitizens(t, 1)[1]
            if found and not seen[found.cid] then
                seen[found.cid] = true
                out[#out + 1] = { cid = found.cid, name = found.name }
            end
        end
        if #out >= 10 then break end
    end
    return out
end

cb('citizenSearch', function(source, player, q)
    return { list = findCitizens(q, 25) }
end)

cb('citizenGet', function(source, player, cid)
    if type(cid) ~= 'string' then return false, 'failed' end
    local r = MySQL.single.await('SELECT `citizenid`, `charinfo`, `job`, `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not r then return false, 'not_found' end
    local c = citizenRow(r)
    local meta = decode(r.metadata)
    local lic = type(meta.licences) == 'table' and meta.licences or {}
    c.licences = { driver = lic.driver == true, weapon = lic.weapon == true, business = lic.business == true }
    -- the driving school's licences (car / truck / boat / heli), in order, for the suspend buttons
    c.driving = {}
    if GetResourceState('exti_driveschool') == 'started' then
        local okL, types = pcall(function() return exports.exti_driveschool:Licences() end)
        local ds = type(meta.driveschool) == 'table' and meta.driveschool or {}
        for k, v in pairs(okL and type(types) == 'table' and types or {}) do
            local me = type(ds[k]) == 'table' and ds[k] or {}
            c.driving[#c.driving + 1] = { key = k, label = v.label, short = v.short, order = v.order or 9, has = lic[v.metaKey] == true, suspended = me.suspended == true, passed = me.passed == true }
        end
        table.sort(c.driving, function(a, b) return a.order < b.order end)
    end
    c.online = exports.qbx_core:GetPlayerByCitizenId(cid) ~= nil
    -- vehicles
    local vehicles = {}
    for _, v in ipairs(MySQL.query.await('SELECT `plate`, `vehicle`, `state`, `garage` FROM `player_vehicles` WHERE `citizenid` = ? ORDER BY `id`', { cid }) or {}) do
        vehicles[#vehicles + 1] = { plate = v.plate, model = v.vehicle, label = vehicleLabel(v.vehicle), state = STATE_LABEL[tonumber(v.state)] or '—', garage = v.garage }
    end
    -- the record
    local charges = POL.chargesOf and POL.chargesOf(cid, 30) or {}
    local list = {}
    for _, ch in ipairs(charges) do
        local labels = {}
        for _, o in ipairs(ch.offences or {}) do labels[#labels + 1] = o.label end
        list[#list + 1] = { id = ch.id, kind = ch.kind, fine = tonumber(ch.fine) or 0, jail = tonumber(ch.jail) or 0, officer = ch.officer, created = ch.created, note = ch.note, offences = table.concat(labels, '، ') }
    end
    local prison = MySQL.single.await('SELECT `minutes`, `remaining`, `officer`, `started`, `escaped` FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
    local warrants = MySQL.query.await('SELECT * FROM `exti_police_warrants` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 20', { cid }) or {}
    local notes = MySQL.query.await('SELECT * FROM `exti_police_notes` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 50', { cid }) or {}
    local reports = MySQL.query.await('SELECT `id`, `title`, `officer`, `created` FROM `exti_police_reports` WHERE `people` LIKE ? ORDER BY `id` DESC LIMIT 20', { like(cid) }) or {}
    local cases = MySQL.query.await('SELECT `id`, `title`, `status`, `officer`, `created` FROM `exti_police_cases` WHERE `people` LIKE ? ORDER BY `id` DESC LIMIT 20', { like(cid) }) or {}
    local bills
    if GetResourceState('exti_bank') == 'started' then
        local ok, n, total = pcall(function() return exports.exti_bank:UnpaidBills(cid) end)
        if ok then bills = { count = n or 0, total = total or 0 } end
    end
    return { citizen = c, vehicles = vehicles, charges = list, prison = prison, warrants = warrants, notes = notes, reports = reports, cases = cases, bills = bills, me = cidOf(player), isBoss = isBoss(player) }
end)

cb('citizenNote', function(source, player, cid, text)
    text = cleanText(text, 500, true)
    if type(cid) ~= 'string' or not text then return false, 'text' end
    MySQL.insert.await('INSERT INTO `exti_police_notes` (`citizenid`, `text`, `officer`, `officer_cid`, `created`) VALUES (?, ?, ?, ?, ?)',
        { cid, text, nameOf(player), cidOf(player), os.time() })
    return { notes = MySQL.query.await('SELECT * FROM `exti_police_notes` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 50', { cid }) or {} }
end)

cb('citizenNoteDelete', function(source, player, id)
    id = int(id)
    local row = id and MySQL.single.await('SELECT * FROM `exti_police_notes` WHERE `id` = ?', { id })
    if not row then return false, 'failed' end
    if row.officer_cid ~= cidOf(player) and not isBoss(player) then return false, 'not_yours' end
    MySQL.query.await('DELETE FROM `exti_police_notes` WHERE `id` = ?', { id })
    return { notes = MySQL.query.await('SELECT * FROM `exti_police_notes` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 50', { row.citizenid }) or {} }
end)

-- a driving-school licence (car / truck / boat / heli): suspended / given back (exti_driveschool keeps it)
cb('licenceSet', function(source, player, cid, kind, on)
    if type(cid) ~= 'string' then return false, 'failed' end
    if type(kind) == 'boolean' then on, kind = kind, 'car' end
    if type(kind) ~= 'string' then return false, 'failed' end
    if GetResourceState('exti_driveschool') ~= 'started' then return false, 'failed' end
    local okL, types = pcall(function() return exports.exti_driveschool:Licences() end)
    local info = okL and type(types) == 'table' and types[kind] or nil
    if not info then return false, 'failed' end
    local ok, done = pcall(function() return exports.exti_driveschool:SetLicenceOffline(cid, kind, on == true) end)
    if not ok or not done then return false, 'failed' end
    local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
    local who = row and decode(row.charinfo) or {}
    POL.log(source, on and 'licence_restored' or 'licence_suspended', ('%s %s · %s'):format(who.firstname or '', who.lastname or cid, info.short or kind))
    return { key = kind, has = on == true }
end)

---------------------------------------------------------------------------
-- vehicles
---------------------------------------------------------------------------
cb('vehicleSearch', function(source, player, q)
    q = cleanText(q, 20)
    if not q then return { list = {} } end
    local rows = MySQL.query.await('SELECT v.`plate`, v.`vehicle`, v.`state`, v.`garage`, v.`citizenid`, p.`charinfo` FROM `player_vehicles` v LEFT JOIN `players` p ON p.`citizenid` = v.`citizenid` WHERE v.`plate` LIKE ? OR v.`vehicle` LIKE ? ORDER BY v.`plate` LIMIT 25', { like(q:upper()), like(q:lower()) }) or {}
    local out = {}
    for _, v in ipairs(rows) do
        local info = decode(v.charinfo)
        local plate = tostring(v.plate or ''):match('^%s*(.-)%s*$')
        local bolo = MySQL.single.await('SELECT `id`, `title` FROM `exti_police_bolos` WHERE `plate` = ? AND `closed` IS NULL ORDER BY `id` DESC LIMIT 1', { plate })
        out[#out + 1] = {
            plate = plate, model = v.vehicle, label = vehicleLabel(v.vehicle),
            state = STATE_LABEL[tonumber(v.state)] or '—', garage = v.garage,
            ownerCid = v.citizenid, owner = ('%s %s'):format(info.firstname or '', info.lastname or ''):match('^%s*(.-)%s*$'),
            bolo = bolo and bolo.title or nil,
        }
    end
    return { list = out }
end)

---------------------------------------------------------------------------
-- reports
---------------------------------------------------------------------------
local function reportView(r)
    return { id = r.id, title = r.title, text = r.text, people = people(r.people), officer = r.officer, officerCid = r.officer_cid, created = r.created, updated = r.updated }
end

local function reportList(q)
    q = cleanText(q, 40)
    local rows = q
        and MySQL.query.await('SELECT `id`, `title`, `officer`, `created`, `people` FROM `exti_police_reports` WHERE `title` LIKE ? OR `people` LIKE ? OR `officer` LIKE ? ORDER BY `id` DESC LIMIT 60', { like(q), like(q), like(q) })
        or MySQL.query.await('SELECT `id`, `title`, `officer`, `created`, `people` FROM `exti_police_reports` ORDER BY `id` DESC LIMIT 60')
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = { id = r.id, title = r.title, officer = r.officer, created = r.created, people = people(r.people) } end
    return out
end

cb('reports', function(source, player, q) return { list = reportList(q) } end)

cb('reportGet', function(source, player, id)
    id = int(id)
    local r = id and MySQL.single.await('SELECT * FROM `exti_police_reports` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    return reportView(r)
end)

cb('reportSave', function(source, player, id, title, text, peopleText)
    title = cleanText(title, 120)
    text = cleanText(text, 4000, true)
    if not title or utf8.len(title) < 2 then return false, 'title' end
    if not text then return false, 'text' end
    local list = json.encode(resolvePeople(peopleText))
    id = int(id)
    if id then
        local r = MySQL.single.await('SELECT `officer_cid` FROM `exti_police_reports` WHERE `id` = ?', { id })
        if not r then return false, 'not_found' end
        if r.officer_cid ~= cidOf(player) and not isBoss(player) then return false, 'not_yours' end
        MySQL.update.await('UPDATE `exti_police_reports` SET `title` = ?, `text` = ?, `people` = ?, `updated` = ? WHERE `id` = ?', { title, text, list, os.time(), id })
    else
        id = MySQL.insert.await('INSERT INTO `exti_police_reports` (`title`, `text`, `people`, `officer`, `officer_cid`, `created`, `updated`) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { title, text, list, nameOf(player), cidOf(player), os.time(), os.time() })
        POL.log(source, 'report_added', title)
    end
    local r = MySQL.single.await('SELECT * FROM `exti_police_reports` WHERE `id` = ?', { id })
    return { item = reportView(r), list = reportList() }
end)

cb('reportDelete', function(source, player, id)
    id = int(id)
    local r = id and MySQL.single.await('SELECT `officer_cid`, `title` FROM `exti_police_reports` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    if r.officer_cid ~= cidOf(player) and not isBoss(player) then return false, 'not_yours' end
    MySQL.query.await('DELETE FROM `exti_police_reports` WHERE `id` = ?', { id })
    POL.log(source, 'report_removed', r.title)
    return { list = reportList() }
end)

---------------------------------------------------------------------------
-- warrants
---------------------------------------------------------------------------
local function warrantList(all)
    local rows = all
        and MySQL.query.await('SELECT * FROM `exti_police_warrants` ORDER BY `id` DESC LIMIT 100')
        or MySQL.query.await('SELECT * FROM `exti_police_warrants` WHERE `closed` IS NULL ORDER BY `id` DESC LIMIT 100')
    return rows or {}
end

cb('warrants', function(source, player, all) return { list = warrantList(all == true) } end)

cb('warrantAdd', function(source, player, who, reason)
    reason = cleanText(reason, 255)
    if not reason then return false, 'text' end
    local target = findCitizens(who, 1)[1]
    if not target then return false, 'not_found' end
    local open = MySQL.single.await('SELECT `id` FROM `exti_police_warrants` WHERE `citizenid` = ? AND `closed` IS NULL', { target.cid })
    if open then return false, 'exists' end
    MySQL.insert.await('INSERT INTO `exti_police_warrants` (`citizenid`, `name`, `reason`, `officer`, `created`) VALUES (?, ?, ?, ?, ?)',
        { target.cid, target.name, reason, nameOf(player), os.time() })
    POL.log(source, 'warrant_added', ('%s: %s'):format(target.name, reason))
    return { list = warrantList(false) }
end)

cb('warrantClose', function(source, player, id)
    id = int(id)
    local r = id and MySQL.single.await('SELECT `name`, `closed` FROM `exti_police_warrants` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    if r.closed then return false, 'failed' end
    MySQL.update.await('UPDATE `exti_police_warrants` SET `closed` = ?, `closed_by` = ? WHERE `id` = ?', { os.time(), nameOf(player), id })
    POL.log(source, 'warrant_closed', r.name)
    return { list = warrantList(false) }
end)

POL.openWarrant = function(cid)
    return MySQL.single.await('SELECT `id`, `reason` FROM `exti_police_warrants` WHERE `citizenid` = ? AND `closed` IS NULL', { cid })
end

---------------------------------------------------------------------------
-- BOLOs
---------------------------------------------------------------------------
local function boloList(all)
    local rows = all
        and MySQL.query.await('SELECT * FROM `exti_police_bolos` ORDER BY `id` DESC LIMIT 100')
        or MySQL.query.await('SELECT * FROM `exti_police_bolos` WHERE `closed` IS NULL ORDER BY `id` DESC LIMIT 100')
    return rows or {}
end

cb('bolos', function(source, player, all) return { list = boloList(all == true) } end)

cb('boloAdd', function(source, player, kind, title, text, plate)
    kind = kind == 'person' and 'person' or 'vehicle'
    title = cleanText(title, 120)
    text = cleanText(text, 500, true)
    plate = cleanText(plate, 12)
    if not title or utf8.len(title) < 2 then return false, 'title' end
    if plate then plate = plate:upper() end
    MySQL.insert.await('INSERT INTO `exti_police_bolos` (`kind`, `title`, `text`, `plate`, `officer`, `created`) VALUES (?, ?, ?, ?, ?, ?)',
        { kind, title, text, kind == 'vehicle' and plate or nil, nameOf(player), os.time() })
    POL.log(source, 'bolo_added', title)
    -- everyone on duty hears about it
    for _, src in ipairs(POL.copsOnDuty()) do
        if src ~= source then TriggerClientEvent('ox_lib:notify', src, { type = 'inform', title = 'تعميم جديد', description = title }) end
    end
    return { list = boloList(false) }
end)

cb('boloClose', function(source, player, id)
    id = int(id)
    local r = id and MySQL.single.await('SELECT `title`, `closed` FROM `exti_police_bolos` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    if r.closed then return false, 'failed' end
    MySQL.update.await('UPDATE `exti_police_bolos` SET `closed` = ?, `closed_by` = ? WHERE `id` = ?', { os.time(), nameOf(player), id })
    POL.log(source, 'bolo_closed', r.title)
    return { list = boloList(false) }
end)

---------------------------------------------------------------------------
-- cases
---------------------------------------------------------------------------
local function caseItems(id)
    return MySQL.query.await('SELECT * FROM `exti_police_case_items` WHERE `case_id` = ? ORDER BY `id`', { id }) or {}
end

local function caseView(r)
    return {
        id = r.id, title = r.title, status = r.status, text = r.text, people = people(r.people), officers = people(r.officers),
        officer = r.officer, officerCid = r.officer_cid, created = r.created, updated = r.updated, items = caseItems(r.id),
    }
end

local function caseList(q, all)
    q = cleanText(q, 40)
    local where = all and '1 = 1' or '`status` = \'open\''
    local rows = q
        and MySQL.query.await('SELECT `id`, `title`, `status`, `officer`, `created`, `updated`, `people` FROM `exti_police_cases` WHERE (' .. where .. ') AND (`title` LIKE ? OR `people` LIKE ? OR `officers` LIKE ?) ORDER BY `updated` DESC LIMIT 60', { like(q), like(q), like(q) })
        or MySQL.query.await('SELECT `id`, `title`, `status`, `officer`, `created`, `updated`, `people` FROM `exti_police_cases` WHERE ' .. where .. ' ORDER BY `updated` DESC LIMIT 60')
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = { id = r.id, title = r.title, status = r.status, officer = r.officer, created = r.created, updated = r.updated, people = people(r.people) } end
    return out
end

-- officers typed by name -> the team members that match
local function resolveOfficers(text)
    local ok, members = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    members = ok and type(members) == 'table' and members or {}
    local out, seen = {}, {}
    for token in tostring(text or ''):gsub('،', ','):gmatch('[^,\n]+') do
        local t = token:match('^%s*(.-)%s*$'):lower()
        if t ~= '' then
            for _, m in ipairs(members) do
                local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { m.citizenid })
                local info = row and decode(row.charinfo) or {}
                local name = ('%s %s'):format(info.firstname or '', info.lastname or ''):match('^%s*(.-)%s*$')
                if not seen[m.citizenid] and (m.citizenid == t or name:lower():find(t, 1, true)) then
                    seen[m.citizenid] = true
                    out[#out + 1] = { cid = m.citizenid, name = name }
                    break
                end
            end
        end
        if #out >= 10 then break end
    end
    return out
end

cb('cases', function(source, player, q, all) return { list = caseList(q, all == true) } end)

cb('caseGet', function(source, player, id)
    id = int(id)
    local r = id and MySQL.single.await('SELECT * FROM `exti_police_cases` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    return caseView(r)
end)

cb('caseSave', function(source, player, id, title, text, peopleText, officersText, status)
    title = cleanText(title, 120)
    text = cleanText(text, 4000, true)
    if not title or utf8.len(title) < 2 then return false, 'title' end
    status = status == 'closed' and 'closed' or 'open'
    local pl, ol = json.encode(resolvePeople(peopleText)), json.encode(resolveOfficers(officersText))
    id = int(id)
    if id then
        local r = MySQL.single.await('SELECT `id` FROM `exti_police_cases` WHERE `id` = ?', { id })
        if not r then return false, 'not_found' end
        MySQL.update.await('UPDATE `exti_police_cases` SET `title` = ?, `text` = ?, `people` = ?, `officers` = ?, `status` = ?, `updated` = ? WHERE `id` = ?', { title, text, pl, ol, status, os.time(), id })
    else
        id = MySQL.insert.await('INSERT INTO `exti_police_cases` (`title`, `status`, `text`, `people`, `officers`, `officer`, `officer_cid`, `created`, `updated`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { title, status, text, pl, ol, nameOf(player), cidOf(player), os.time(), os.time() })
        POL.log(source, 'case_added', title)
    end
    local r = MySQL.single.await('SELECT * FROM `exti_police_cases` WHERE `id` = ?', { id })
    return { item = caseView(r), list = caseList(nil, false) }
end)

cb('caseItem', function(source, player, id, kind, text, url)
    id = int(id)
    local r = id and MySQL.single.await('SELECT `id` FROM `exti_police_cases` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    if kind == 'photo' then
        if type(url) ~= 'string' or not url:match('^https://[%w%-%./_%%?=&]+$') or #url > 300 then return false, 'bad_url' end
        text = cleanText(text, 200)
    else
        kind = 'note'
        text = cleanText(text, 500, true)
        url = nil
        if not text then return false, 'text' end
    end
    MySQL.insert.await('INSERT INTO `exti_police_case_items` (`case_id`, `kind`, `text`, `url`, `officer`, `officer_cid`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { id, kind, text, url, nameOf(player), cidOf(player), os.time() })
    MySQL.update.await('UPDATE `exti_police_cases` SET `updated` = ? WHERE `id` = ?', { os.time(), id })
    return { items = caseItems(id) }
end)

cb('caseItemDelete', function(source, player, itemId)
    itemId = int(itemId)
    local r = itemId and MySQL.single.await('SELECT * FROM `exti_police_case_items` WHERE `id` = ?', { itemId })
    if not r then return false, 'not_found' end
    if r.officer_cid ~= cidOf(player) and not isBoss(player) then return false, 'not_yours' end
    MySQL.query.await('DELETE FROM `exti_police_case_items` WHERE `id` = ?', { itemId })
    return { items = caseItems(r.case_id) }
end)

cb('caseDelete', function(source, player, id)
    id = int(id)
    local r = id and MySQL.single.await('SELECT `officer_cid`, `title` FROM `exti_police_cases` WHERE `id` = ?', { id })
    if not r then return false, 'not_found' end
    if r.officer_cid ~= cidOf(player) and not isBoss(player) then return false, 'not_yours' end
    MySQL.query.await('DELETE FROM `exti_police_case_items` WHERE `case_id` = ?', { id })
    MySQL.query.await('DELETE FROM `exti_police_cases` WHERE `id` = ?', { id })
    POL.log(source, 'case_removed', r.title)
    return { list = caseList(nil, false) }
end)
