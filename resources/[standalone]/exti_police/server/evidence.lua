-- =====================================================================
-- EX_Tii Police (server): evidence. A crime leaves marks: partial prints (no gloves), blood, shell
-- casings. Officers on duty see the marks near them, bag them, and hand the bags in at the lab (the
-- seized items room). Ten minutes later the lab answers: on the case they picked (a note on the
-- tablet) and on their phone. Who a mark belongs to never leaves the server until the lab says so.
-- Marked bills (exti_heists) send a trace circle to the cops' map while they are "hot".
--
-- Other scripts:  exports.exti_police:DropEvidence('print'|'blood'|'casing', coords, { src = n } | { serial, owner })
-- =====================================================================

local E = Config.evidence
local getPlayer, onDuty, nameOf, notify = POL.getPlayer, POL.onDuty, POL.nameOf, POL.notify

local marks = {}       -- [id] = { id, kind, x, y, z, at, cid, name, detail }
local order = {}       -- ids, oldest first
local nextId = 0

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_evidence` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `kind` VARCHAR(10) NOT NULL,
        `cid` VARCHAR(64) NULL,
        `name` VARCHAR(80) NULL,
        `detail` VARCHAR(200) NULL,
        `place` VARCHAR(80) NULL,
        `dropped` INT NOT NULL,
        `bagged_by` VARCHAR(64) NOT NULL,
        `bagged_name` VARCHAR(80) NOT NULL,
        `bagged` INT NOT NULL,
        `case_id` INT NULL,
        `lab_by` VARCHAR(64) NULL,
        `ready_at` INT NULL,
        `result` VARCHAR(300) NULL,
        INDEX `ready` (`ready_at`)
    ) DEFAULT CHARSET=utf8mb4]])
end)

local function cidOf(player) return player and player.PlayerData.citizenid end

---------------------------------------------------------------------------
-- the marks on the ground
---------------------------------------------------------------------------
local syncQueued = false
local function sync()
    if syncQueued then return end
    syncQueued = true
    SetTimeout(800, function()
        syncQueued = false
        local list = {}
        for _, id in ipairs(order) do
            local m = marks[id]
            if m then list[#list + 1] = { id = m.id, k = m.kind, x = m.x, y = m.y, z = m.z } end
        end
        for _, src in ipairs(POL.copsOnDuty()) do TriggerClientEvent('exti_police:client:evidence', src, list) end
    end)
end
POL.evidenceSync = sync

local function remove(id)
    marks[id] = nil
    for i, v in ipairs(order) do if v == id then table.remove(order, i) break end end
end

-- kind: print | blood | casing.  who: { src = n } (a person) or { serial = '...', owner = 'name' | nil, label = 'gun' }
local function drop(kind, coords, who)
    if not E.labels[kind] or type(coords) ~= 'table' and type(coords) ~= 'vector3' then return nil end
    if not tonumber(coords.x) then return nil end
    who = type(who) == 'table' and who or {}
    local m = { kind = kind, x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0, at = os.time() }
    if who.src then
        local p = getPlayer(tonumber(who.src))
        if not p then return nil end
        m.cid, m.name = p.PlayerData.citizenid, nameOf(p)
    end
    if kind == 'casing' then
        m.detail = json.encode({ serial = who.serial, owner = who.owner, label = who.label })
    end
    -- the same person, the same kind, within 1.5 m in the last 2 minutes: one mark is enough
    for _, id in ipairs(order) do
        local o = marks[id]
        if o and o.kind == kind and o.cid == m.cid and o.detail == m.detail and os.time() - o.at < 120
            and #(vec3(o.x, o.y, o.z) - vec3(m.x, m.y, m.z)) < 1.5 then return o.id end
    end
    nextId = nextId + 1
    m.id = nextId
    marks[m.id] = m
    order[#order + 1] = m.id
    while #order > E.maxMarks do marks[table.remove(order, 1)] = nil end
    sync()
    return m.id
end
exports('DropEvidence', drop)

-- old marks wash away
CreateThread(function()
    while true do
        Wait(60000)
        local t, gone = os.time(), false
        for i = #order, 1, -1 do
            local m = marks[order[i]]
            if not m or t - m.at > E.lifeMinutes * 60 then marks[order[i]] = nil; table.remove(order, i); gone = true end
        end
        if gone then sync() end
    end
end)

-- an officer comes on duty: he gets the marks
RegisterNetEvent('exti_police:server:evidenceHello', function()
    local src = source
    if onDuty(getPlayer(src)) then
        local list = {}
        for _, id in ipairs(order) do local m = marks[id]; if m then list[#list + 1] = { id = m.id, k = m.kind, x = m.x, y = m.y, z = m.z } end end
        TriggerClientEvent('exti_police:client:evidence', src, list)
    end
end)

---------------------------------------------------------------------------
-- bagging a mark
---------------------------------------------------------------------------
local function zoneOf(m)
    local ok, z = pcall(function() return GetNameOfZone and GetNameOfZone(m.x, m.y, m.z) end)
    return ok and z or nil
end

lib.callback.register('exti_police:server:evidencePick', function(source, id, place)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local m = marks[math.tointeger(id) or -1]
    if not m then return false, 'gone' end
    if not POL.near(source, m, E.pickDistance + 1.0) then return false, 'too_far' end
    if (exports.ox_inventory:Search(source, 'count', E.bagItem) or 0) < 1 then return false, 'no_bag' end
    if not exports.ox_inventory:CanCarryItem(source, E.item, 1) then return false, 'full' end
    if not exports.ox_inventory:RemoveItem(source, E.bagItem, 1) then return false, 'no_bag' end
    remove(m.id); sync()
    place = type(place) == 'string' and place:gsub('[%c<>]', ''):sub(1, 60) or zoneOf(m) or ''
    local dbId = MySQL.insert.await('INSERT INTO `exti_police_evidence` (`kind`, `cid`, `name`, `detail`, `place`, `dropped`, `bagged_by`, `bagged_name`, `bagged`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { m.kind, m.cid, m.name, m.detail, place, m.at, cidOf(player), nameOf(player), os.time() })
    local label = E.labels[m.kind]
    exports.ox_inventory:AddItem(source, E.item, 1, {
        eid = dbId, kind = m.kind,
        label = ('كيس أدلة: %s'):format(label),
        description = ('%s · %s · %s\nرقم الدليل: %d'):format(label, place ~= '' and place or 'مكان غير معروف', os.date('%H:%M', m.at), dbId or 0),
    })
    POL.log(source, 'evidence_bagged', ('#%s %s (%s)'):format(tostring(dbId), m.kind, place))
    return true, label
end)

---------------------------------------------------------------------------
-- the lab (the seized items room of any station)
---------------------------------------------------------------------------
local function atLab(src)
    for _, st in pairs(Config.stations) do
        if (st.lab and POL.nearSpot(src, st.lab, 2.0)) or (st.evidence and POL.nearSpot(src, st.evidence, 2.0)) then return true end
    end
    return false
end

-- what the officer can hand in, and the open cases to put the answer on
lib.callback.register('exti_police:server:labInfo', function(source)
    local player = getPlayer(source)
    if not onDuty(player) or not atLab(source) then return false end
    local bags = {}
    for _, slot in pairs(exports.ox_inventory:Search(source, 'slots', E.item) or {}) do
        local md = slot.metadata or {}
        if md.eid then bags[#bags + 1] = { slot = slot.slot, eid = md.eid, label = md.label or E.item, description = md.description } end
    end
    local cases = MySQL.query.await('SELECT `id`, `title` FROM `exti_police_cases` WHERE `status` = \'open\' ORDER BY `updated` DESC LIMIT 25') or {}
    local mine = MySQL.query.await('SELECT `id`, `kind`, `place`, `ready_at`, `result`, `case_id` FROM `exti_police_evidence` WHERE `lab_by` = ? ORDER BY `id` DESC LIMIT 15', { cidOf(player) }) or {}
    local results = {}
    for _, r in ipairs(mine) do
        results[#results + 1] = { id = r.id, label = E.labels[r.kind] or r.kind, place = r.place, case = r.case_id,
            left = r.result and 0 or math.max(0, (r.ready_at or 0) - os.time()), result = r.result }
    end
    return { bags = bags, cases = cases, results = results, minutes = E.labMinutes }
end)

lib.callback.register('exti_police:server:labSubmit', function(source, slotNo, caseId)
    local player = getPlayer(source)
    if not onDuty(player) or not atLab(source) then return false, 'too_far' end
    slotNo = math.tointeger(slotNo)
    local slot = slotNo and exports.ox_inventory:GetSlot(source, slotNo)
    if not slot or slot.name ~= E.item or not slot.metadata or not slot.metadata.eid then return false, 'gone' end
    local eid = math.tointeger(slot.metadata.eid)
    local row = eid and MySQL.single.await('SELECT `id`, `lab_by` FROM `exti_police_evidence` WHERE `id` = ?', { eid })
    if not row then return false, 'gone' end
    caseId = math.tointeger(caseId)
    if caseId and not MySQL.scalar.await('SELECT `id` FROM `exti_police_cases` WHERE `id` = ?', { caseId }) then caseId = nil end
    if row.lab_by then return false, 'gone' end
    if not exports.ox_inventory:RemoveItem(source, E.item, 1, nil, slotNo) then return false, 'gone' end
    MySQL.update.await('UPDATE `exti_police_evidence` SET `lab_by` = ?, `ready_at` = ?, `case_id` = ? WHERE `id` = ?',
        { cidOf(player), os.time() + E.labMinutes * 60, caseId, eid })
    POL.log(source, 'evidence_lab', ('#%d -> case %s'):format(eid, tostring(caseId)))
    return true, E.labMinutes
end)

-- the answer
local function resultOf(r)
    if r.kind == 'print' then
        return r.name and ('البصمة تطابق: %s (%s)'):format(r.name, r.cid) or 'البصمة لا تطابق أحدًا في السجلات', r.name ~= nil
    elseif r.kind == 'blood' then
        return r.name and ('الدم يطابق: %s (%s)'):format(r.name, r.cid) or 'عينة الدم لا تطابق أحدًا', r.name ~= nil
    elseif r.kind == 'casing' then
        local ok, d = pcall(json.decode, r.detail or '')
        d = ok and type(d) == 'table' and d or {}
        local gun = d.label and (' (%s)'):format(d.label) or ''
        if d.serial and d.owner then return ('الظرف من سلاح%s رقمه %s، مسجّل باسم %s'):format(gun, d.serial, d.owner), true end
        if d.serial then return ('الظرف من سلاح%s رقمه %s، غير مسجّل باسم أحد'):format(gun, d.serial), false end
        return ('الظرف من سلاح%s بلا رقم تسلسلي (صنع محلي)'):format(gun), false
    end
    return 'لا نتيجة', false
end

-- the named person is police (on the job, online or not): no bonus
local function isCopCid(cid)
    if not cid then return false end
    local row = MySQL.single.await('SELECT `job` FROM `players` WHERE `citizenid` = ?', { cid })
    local ok, job = pcall(json.decode, row and row.job or '')
    return ok and type(job) == 'table' and job.name == Config.job
end
local bonusDay = {}   -- [cid] = { day, n }
local function bonusLeft(cid)
    local day = os.date('%Y-%m-%d')
    local b = bonusDay[cid]
    if not b or b.day ~= day then b = { day = day, n = 0 }; bonusDay[cid] = b end
    if b.n >= (E.bonus.daily or 5) then return false end
    b.n = b.n + 1
    return true
end

local function srcOfCid(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    return ok and p and p.PlayerData.source or nil
end

CreateThread(function()
    Wait(5000)
    while true do
        local rows = MySQL.query.await('SELECT * FROM `exti_police_evidence` WHERE `result` IS NULL AND `ready_at` IS NOT NULL AND `ready_at` <= ? LIMIT 20', { os.time() }) or {}
        for _, r in ipairs(rows) do
            local text, named = resultOf(r)
            local full = ('نتيجة المختبر · دليل #%d (%s، %s): %s'):format(r.id, E.labels[r.kind] or r.kind, r.place or '', text)
            MySQL.update.await('UPDATE `exti_police_evidence` SET `result` = ? WHERE `id` = ?', { text, r.id })
            if r.case_id then
                MySQL.insert.await('INSERT INTO `exti_police_case_items` (`case_id`, `kind`, `text`, `url`, `officer`, `officer_cid`, `created`) VALUES (?, ?, ?, NULL, ?, ?, ?)',
                    { r.case_id, 'note', full:sub(1, 500), 'مختبر الأدلة', r.lab_by or 'lab', os.time() })
                MySQL.update.await('UPDATE `exti_police_cases` SET `updated` = ? WHERE `id` = ?', { os.time(), r.case_id })
            end
            local officer = r.lab_by and srcOfCid(r.lab_by)
            if officer then
                notify(officer, 'success', full)
                if named and E.bonus.named > 0 and r.case_id and r.cid ~= r.lab_by and r.cid ~= r.bagged_by and not isCopCid(r.cid) and bonusLeft(r.lab_by) then
                    local p = getPlayer(officer)
                    if p then p.Functions.AddMoney('bank', E.bonus.named, 'police-evidence-bonus') end
                end
            end
            POL.log(nil, 'evidence_result', full)
        end
        Wait(30000)
    end
end)

---------------------------------------------------------------------------
-- blood: a player who got hurt bleeds where he stands
---------------------------------------------------------------------------
local lastBlood = {}
RegisterNetEvent('exti_police:server:blood', function(c)
    local src = source
    local t = os.time()
    if (lastBlood[src] or 0) + E.blood.everySeconds > t then return end
    if type(c) ~= 'table' or not tonumber(c.x) then return end
    if not POL.near(src, c, 6.0) then return end
    if GetPlayerRoutingBucket(src) ~= 0 then return end
    lastBlood[src] = t
    drop('blood', vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0), { src = src })
end)

---------------------------------------------------------------------------
-- casings: a gun fired (exti_weapons tells us; we look at the gun in his hand)
---------------------------------------------------------------------------
local lastCasing = {}
function POL.casing(src, coords)
    local t = os.time()
    if (lastCasing[src] or 0) + E.casing.everySeconds > t then return end
    if onDuty(getPlayer(src)) then return end
    lastCasing[src] = t
    local ok, w = pcall(function() return exports.ox_inventory:GetCurrentWeapon(src) end)
    w = ok and type(w) == 'table' and w or nil
    local md = w and w.metadata or {}
    local item = w and exports.ox_inventory:Items(w.name)
    drop('casing', coords, { serial = type(md.serial) == 'string' and md.serial or nil, owner = type(md.registered) == 'string' and md.registered or nil,
        label = item and item.label or nil })
end
exports('Casing', function(src, coords) POL.casing(src, coords) end)

AddEventHandler('playerDropped', function() lastBlood[source] = nil; lastCasing[source] = nil end)

---------------------------------------------------------------------------
-- marked bills: while hot, whoever carries them shows on the cops' map (a circle, not a dot)
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(E.trace.everySeconds * 1000)
        local cops = POL.copsOnDuty()
        if #cops > 0 then
            local t = os.time()
            for _, s in ipairs(GetPlayers()) do
                local src = tonumber(s)
                local hot = false
                local ok, slots = pcall(function() return exports.ox_inventory:Search(src, 'slots', 'marked_bills') end)
                for _, slot in pairs(ok and slots or {}) do
                    if type(slot.metadata) == 'table' and tonumber(slot.metadata.trace) and slot.metadata.trace > t then hot = true break end
                end
                if hot and GetPlayerRoutingBucket(src) == 0 then
                    local ped = GetPlayerPed(src)
                    local c = ped ~= 0 and GetEntityCoords(ped)
                    if c then
                        local a = math.random() * math.pi * 2
                        local d = math.random() * E.trace.offset
                        local x, y = c.x + math.cos(a) * d, c.y + math.sin(a) * d
                        for _, cop in ipairs(cops) do
                            TriggerClientEvent('exti_police:client:trace', cop, { x = x, y = y, radius = E.trace.radius, seconds = E.trace.everySeconds + 5 })
                        end
                    end
                end
            end
        end
    end
end)
