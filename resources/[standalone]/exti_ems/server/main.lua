-- =====================================================================
-- EX_Tii EMS (server): everything is checked here — who is a medic on duty, how close people
-- are, who is down, the pay per patient (with a waiting time so friends can't farm it),
-- the calls list, the boss tools, vehicles and the stretcher / wheelchair.
-- =====================================================================

local JOB = Config.job
local DOWN_STATE = 'qbx_medical:deathState' -- 1 alive, 2 down (last stand), 3 dead

local calls, nextCallId = {}, 0
local equipment = {}  -- [netId] = { kind, owner, pusher, patient, vehicle }
local lastPaid = {}   -- [patient citizenid] = os.time() of the last paid care
local lastCounted = {} -- [patient citizenid] = os.time() the care was last counted in the stats
local vehicles = {}   -- [source] = entity of their EMS vehicle
local shifts = {}     -- [source] = { start, revives, treats, earned }
local busy = {}

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function isMedic(player)
    return player and player.PlayerData.job and player.PlayerData.job.name == JOB
end

local function onDuty(player)
    return isMedic(player) and player.PlayerData.job.onduty == true
end

local function nameOf(player)
    local c = player and player.PlayerData.charinfo or {}
    return ('%s %s'):format(c.firstname or '', c.lastname or '')
end

local function pedOf(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and ped or nil
end

local function near(src, coords, dist)
    local ped = pedOf(src)
    if not ped then return false end
    return #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= dist
end

local function playersClose(a, b, dist)
    if type(a) ~= 'number' or type(b) ~= 'number' then return false end
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    local pa, pb = pedOf(a), pedOf(b)
    if not pa or not pb then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= dist
end

local function deathState(src)
    return Player(src).state[DOWN_STATE] or 1
end

local function healthPercent(src)
    local ped = pedOf(src)
    if not ped then return 100 end
    return math.max(0, math.min(100, math.floor(GetEntityHealth(ped) - 100 + 0.5)))
end

local function hasItem(src, name)
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', name) end)
    return ok and (count or 0) > 0
end

local function notify(src, kind, text)
    TriggerClientEvent('ox_lib:notify', src, { type = kind, description = text })
end

local function medicsOnDuty()
    local ok, _, list = pcall(function() return exports.qbx_core:GetDutyCountType('ems') end)
    return ok and list or {}
end

-- shared with server/shift.lua (clock in, cloakroom, lockers) and server/fleet.lua (garages)
EMS = EMS or {}
EMS.getPlayer, EMS.isMedic, EMS.onDuty, EMS.nameOf = getPlayer, isMedic, onDuty, nameOf
EMS.pedOf, EMS.near, EMS.notify = pedOf, near, notify
EMS.shifts, EMS.vehicles, EMS.equipment, EMS.busy = shifts, vehicles, equipment, busy

local function gradeLabel(grade)
    local ok, job = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    local g = ok and job and job.grades and job.grades[grade]
    return g and g.name or tostring(grade)
end

local function stats(player)
    local s = player.PlayerData.metadata and player.PlayerData.metadata.emsstats
    if type(s) ~= 'table' then s = {} end
    local out = {}
    for k, v in pairs(s) do out[k] = v end -- keep the rest (minutes worked, this week...)
    out.revives, out.treats, out.earned = s.revives or 0, s.treats or 0, s.earned or 0
    return out
end
EMS.stats, EMS.gradeLabel = stats, gradeLabel

---------------------------------------------------------------------------
-- calls (people down, the hospital reception, phone 911)
---------------------------------------------------------------------------
local function tellMedics(event, ...)
    local list = medicsOnDuty()
    for i = 1, #list do TriggerClientEvent(event, list[i], ...) end
end

---@param data { kind: string, coords: vector3, patient?: number, text?: string, number?: string }
local function addCall(data)
    if type(data) ~= 'table' or not data.coords or not Config.callLabels[data.kind] then return end
    -- one open call per person and kind
    if data.patient then
        for _, c in pairs(calls) do
            if c.patient == data.patient and c.kind == data.kind then
                c.coords, c.time = vec3(data.coords.x, data.coords.y, data.coords.z), os.time()
                if type(data.text) == 'string' then c.text = data.text:sub(1, 160) end
                tellMedics('exti_ems:client:callsChanged')
                return c.id
            end
        end
    end
    nextCallId += 1
    local player = data.patient and getPlayer(data.patient)
    calls[nextCallId] = {
        id = nextCallId,
        kind = data.kind,
        label = Config.callLabels[data.kind],
        coords = vec3(data.coords.x, data.coords.y, data.coords.z),
        patient = data.patient,
        patientName = player and nameOf(player) or nil,
        text = type(data.text) == 'string' and data.text:sub(1, 160) or nil,
        number = data.number,
        time = os.time(),
    }
    tellMedics('exti_ems:client:callsChanged', true)
    return nextCallId
end
exports('AddCall', addCall)

local function closeCallsOf(patient, kind)
    local changed = false
    for id, c in pairs(calls) do
        if c.patient == patient and (not kind or c.kind == kind) then
            calls[id] = nil
            changed = true
        end
    end
    if changed then tellMedics('exti_ems:client:callsChanged') end
end

-- someone goes down: a call; back on their feet: the call goes away
AddStateBagChangeHandler(DOWN_STATE, nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    if value == 2 or value == 3 then
        SetTimeout(500, function()
            local ped = pedOf(src)
            local state = Player(src).state[DOWN_STATE]
            if ped and (state == 2 or state == 3) then addCall({ kind = 'down', coords = GetEntityCoords(ped), patient = src }) end
        end)
    elseif value == 1 then
        closeCallsOf(src, 'down')
    end
end)

-- old calls go away
CreateThread(function()
    while true do
        Wait(60000)
        local now, changed = os.time(), false
        for id, c in pairs(calls) do
            if now - c.time > Config.callExpire * 60 then calls[id] = nil changed = true end
        end
        if changed then tellMedics('exti_ems:client:callsChanged') end
    end
end)

local function callsView(src)
    local list = {}
    for _, c in pairs(calls) do
        -- a downed patient's spot is read again (they may have been moved)
        local coords = c.coords
        if c.kind == 'down' and c.patient then
            local ped = pedOf(c.patient)
            if ped then coords = GetEntityCoords(ped) end
        end
        list[#list + 1] = {
            id = c.id, kind = c.kind, label = c.label, text = c.text, number = c.number,
            patientName = c.patientName, x = coords.x, y = coords.y, z = coords.z,
            ago = os.time() - c.time,
            takenBy = c.takenByName, mine = c.takenBy == src,
            -- helping only while the medic who has the call is still on duty (else you may take it over)
            helping = (c.helpers and c.helpers[src] and c.takenBy and c.takenBy ~= src and onDuty(getPlayer(c.takenBy))) and true or false,
        }
    end
    table.sort(list, function(a, b) return a.ago < b.ago end)
    return list
end

lib.callback.register('exti_ems:server:takeCall', function(source, id)
    local player = getPlayer(source)
    if not onDuty(player) then return false end
    local c = calls[id]
    if not c then return false, 'gone' end
    -- EX_Tii: if a colleague (still on duty) already has this call, "ساعد" only gives you the route;
    -- the call stays his (before, pressing it took the call away from him)
    local first = c.takenBy and c.takenBy ~= source and getPlayer(c.takenBy)
    local helping = first and onDuty(first) and true or false
    if helping then
        c.helpers = c.helpers or {}
        c.helpers[source] = true
    else
        c.takenBy, c.takenByName = source, nameOf(player)
        if c.patient and getPlayer(c.patient) then
            notify(c.patient, 'inform', ('المسعف %s في الطريق إليك'):format(nameOf(player)))
        end
    end
    tellMedics('exti_ems:client:callsChanged')
    return true, { x = c.coords.x, y = c.coords.y, z = c.coords.z, label = c.label, helping = helping }
end)

lib.callback.register('exti_ems:server:closeCall', function(source, id)
    local player = getPlayer(source)
    if not onDuty(player) then return false end
    local c = calls[id]
    if not c then return true end
    if c.takenBy and c.takenBy ~= source and not player.PlayerData.job.isboss then return false, 'not_yours' end
    calls[id] = nil
    tellMedics('exti_ems:client:callsChanged')
    return true
end)

---------------------------------------------------------------------------
-- clocking in / out: server/shift.lua (the terminal at the reception computer)
---------------------------------------------------------------------------
-- medics always start a session off duty (they clock in at the hospital)
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if isMedic(player) and player.PlayerData.job.onduty then
        exports.qbx_core:SetJobDuty(player.PlayerData.source, false)
    end
end)

-- no longer a medic (fired, quit): off duty, no vehicle, no stretcher
local function cleanUp(src)
    if EMS.endShift then EMS.endShift(src) end
    shifts[src] = nil
    if EMS.releaseVehicle then EMS.releaseVehicle(src) end
    for netId, e in pairs(equipment) do
        if e.owner == src or e.pusher == src then
            if e.owner == src then
                if e.patient then TriggerClientEvent('exti_ems:client:dismount', e.patient) end
                local ent = NetworkGetEntityFromNetworkId(netId)
                if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
                equipment[netId] = nil
            else
                e.pusher = nil
            end
        end
    end
end

AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if not job or job.name ~= JOB then cleanUp(src) return end
    -- a new rank puts you off duty without the duty event (the tablet puts you back on right
    -- after): look again in a moment, and only end the shift if you really are off duty
    if not job.onduty and (shifts[src] or vehicles[src]) then
        SetTimeout(1500, function()
            local p = getPlayer(src)
            if p and isMedic(p) and not p.PlayerData.job.onduty then
                if EMS.endShift then EMS.endShift(src) end
                shifts[src] = nil
                if EMS.releaseVehicle then EMS.releaseVehicle(src) end
            end
        end)
    end
end)

AddEventHandler('QBCore:Server:SetDuty', function(src, duty)
    -- off duty (the terminal, an admin, the boss...): the vehicle goes back to the garage
    if not duty and EMS.releaseVehicle then EMS.releaseVehicle(src) end
end)

---------------------------------------------------------------------------
-- reviving and treating (paid per patient)
---------------------------------------------------------------------------
local function careCheck(src, target)
    if type(target) ~= 'number' or target == src then return nil, 'failed' end
    local player, patient = getPlayer(src), getPlayer(target)
    if not onDuty(player) then return nil, 'off_duty' end
    if not patient then return nil, 'failed' end
    if not playersClose(src, target, Config.reach + 1.0) then return nil, 'too_far' end
    return player, patient
end

lib.callback.register('exti_ems:server:patient', function(source, target)
    local player, patient = careCheck(source, target)
    if not player then return false end
    local state = deathState(target)
    local health = healthPercent(target)
    return {
        name = nameOf(patient),
        health = state == 1 and health or 0,
        state = state ~= 1 and 'down' or (health < 100 and 'hurt' or 'ok'),
        hasRevive = hasItem(source, Config.items.revive),
        hasTreat = hasItem(source, Config.items.treat),
    }
end)

local function pay(src, player, kind, patient)
    local cid = patient.PlayerData.citizenid
    local last = lastPaid[cid]
    if last and os.time() - last < Config.payCooldown * 60 then return 0 end
    lastPaid[cid] = os.time()
    local amount = Config.pay[kind] or 0
    if amount <= 0 then return 0 end
    player.Functions.AddMoney('bank', amount, 'ems-' .. kind)
    local s = stats(player)
    s.earned = s.earned + amount
    player.Functions.SetMetaData('emsstats', s)
    local shift = shifts[src]
    if shift then shift.earned = shift.earned + amount end
    -- the player level (exti_level): XP for the patient (the pay cooldown above already stops farming)
    if GetResourceState('exti_level') == 'started' then
        pcall(function() exports.exti_level:AddXP(src, kind == 'revive' and 30 or 15, kind == 'revive' and 'إنعاش مريض' or 'علاج مصاب') end)
    end
    return amount
end

local function count(src, player, what)
    local s = stats(player)
    s[what] = (s[what] or 0) + 1
    player.Functions.SetMetaData('emsstats', s)
    local shift = shifts[src]
    if shift then shift[what] = (shift[what] or 0) + 1 end
end

-- reviving / healing is done by the treatment now (exti_medical, step by step like the video):
-- when the medic finishes a patient's treatment plan, exti_medical calls CareDone to pay and count
-- returns what was paid
local function careDone(src, target, kind, health)
    local player, patient = getPlayer(src), getPlayer(target)
    if not onDuty(player) or not patient then return 0 end
    kind = kind == 'revive' and 'revive' or 'treat'
    local paid = 0
    local cid = patient.PlayerData.citizenid
    local counted = lastCounted[cid]
    pcall(function()
        -- the same patient only counts again after the waiting time (like the pay)
        if not counted or os.time() - counted >= Config.payCooldown * 60 then
            lastCounted[cid] = os.time()
            count(src, player, kind == 'revive' and 'revives' or 'treats')
        end
        if kind == 'revive' or (tonumber(health) or 100) < Config.treatBelow then paid = pay(src, player, kind, patient) end
        if kind == 'revive' then closeCallsOf(target) end
    end)
    lib.logger(src, 'ems', ('%s %s (%s) with the treatment, paid $%d'):format(kind == 'revive' and 'revived' or 'treated', nameOf(patient), patient.PlayerData.citizenid, paid))
    return paid
end
exports('CareDone', function(src, target, kind, health)
    -- only exti_medical may report a finished treatment
    if GetInvokingResource() ~= 'exti_medical' then return 0 end
    return careDone(src, target, kind, health)
end)

-- the old quick revive / heal (one item, a progress bar) is replaced by the treatment
lib.callback.register('exti_ems:server:revive', function() return false, 'use_treatment' end)
lib.callback.register('exti_ems:server:treat', function() return false, 'use_treatment' end)

---------------------------------------------------------------------------
-- the tablet
---------------------------------------------------------------------------
local function teamView(src, player)
    local isBoss = player.PlayerData.job.isboss
    local list = {}
    local ok, members = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    if not ok or type(members) ~= 'table' then members = {} end
    for i = 1, #members do
        local m = members[i]
        local online = exports.qbx_core:GetPlayerByCitizenId(m.citizenid)
        local duty = online and online.PlayerData.job.name == JOB and online.PlayerData.job.onduty
        if isBoss or duty then
            local name
            if online then
                name = nameOf(online)
            else
                local okOff, off = pcall(function() return exports.qbx_core:GetOfflinePlayer(m.citizenid) end)
                name = okOff and off and nameOf(off) or m.citizenid
            end
            list[#list + 1] = {
                citizenid = m.citizenid, name = name, grade = m.grade, gradeLabel = gradeLabel(m.grade),
                online = online ~= nil, onDuty = duty == true, me = online and online.PlayerData.source == src,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.onDuty ~= b.onDuty then return a.onDuty end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    return list
end

lib.callback.register('exti_ems:server:tablet', function(source)
    local player = getPlayer(source)
    if not isMedic(player) then return false end
    local job = player.PlayerData.job
    local ok, jobData = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    local ranks = {}
    if ok and jobData then
        for grade = 0, 20 do
            local g = jobData.grades[grade]
            if not g then break end
            ranks[#ranks + 1] = { grade = grade, name = g.name, payment = g.payment, boss = g.isboss == true }
        end
    end
    return {
        me = {
            name = nameOf(player), grade = job.grade.level, gradeLabel = job.grade.name,
            onDuty = job.onduty == true, isBoss = job.isboss == true,
            stats = stats(player), shift = shifts[source],
        },
        pay = Config.pay,
        payCooldown = Config.payCooldown,
        treatBelow = Config.treatBelow,
        ranks = ranks,
        calls = job.onduty and callsView(source) or {},
        team = teamView(source, player),
        applications = job.isboss and EMS_applicationsView and EMS_applicationsView() or nil, -- (defined further down)
        now = os.time(),
    }
end)

-- boss: change rank / fire (not yourself, not someone of your rank or higher)
local function bossCheck(src, cid)
    local player = getPlayer(src)
    if not isMedic(player) or not player.PlayerData.job.isboss then return nil, 'not_boss' end
    if type(cid) ~= 'string' or cid == player.PlayerData.citizenid then return nil, 'failed' end
    local ok, members = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    if not ok then return nil, 'failed' end
    for i = 1, #members do
        if members[i].citizenid == cid then
            if members[i].grade >= player.PlayerData.job.grade.level then return nil, 'rank' end
            return player, members[i]
        end
    end
    return nil, 'failed'
end

lib.callback.register('exti_ems:server:setGrade', function(source, cid, grade)
    local player, member = bossCheck(source, cid)
    if not player then return false, member end
    grade = math.tointeger(grade)
    if not grade or grade < 0 or grade >= player.PlayerData.job.grade.level then return false, 'rank' end
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    local wasOn = online and online.PlayerData.job.name == JOB and online.PlayerData.job.onduty
    local ok = exports.qbx_core:AddPlayerToJob(cid, JOB, grade)
    if not ok then return false, 'failed' end
    -- a new rank must not clock them out (qbx_core resets duty when the job is set again)
    if wasOn then exports.qbx_core:SetJobDuty(online.PlayerData.source, true) end
    if online then
        notify(online.PlayerData.source, 'inform', ('رتبتك في الإسعاف الآن: %s'):format(gradeLabel(grade)))
    end
    lib.logger(source, 'ems', ('set %s to grade %d'):format(cid, grade))
    return true
end)

lib.callback.register('exti_ems:server:fire', function(source, cid)
    local player, member = bossCheck(source, cid)
    if not player then return false, member end
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online and online.PlayerData.job.name == JOB then
        online.Functions.SetJob('unemployed', 0)
        notify(online.PlayerData.source, 'error', 'أُنهيت خدمتك في الإسعاف')
    else
        exports.qbx_core:RemovePlayerFromJob(cid, JOB)
    end
    lib.logger(source, 'ems', ('fired %s'):format(cid))
    return true
end)

-- leave EMS yourself (from the tablet)
lib.callback.register('exti_ems:server:quit', function(source)
    local player = getPlayer(source)
    if not isMedic(player) then return false end
    player.Functions.SetJob('unemployed', 0)
    return true
end)

---------------------------------------------------------------------------
-- joining EMS (like police and mechanic): a citizen fills the job application at the hospital
-- reception (exti_hospital), the EMS chief reads it on the tablet and hires or rejects
---------------------------------------------------------------------------
local APP = Config.applications or {}
-- the jobs someone may leave to become a medic (team jobs like police or mechanic can't)
local FREE_JOBS = APP.freeJobs or { unemployed = true, tow = true, garbage = true, delivery = true, taxi = true, bus = true, trucker = true, reporter = true, vineyard = true }

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_ems_applications` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NULL,
        `phone` VARCHAR(20) NULL,
        `answers` LONGTEXT NULL,
        `created` INT NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'open',
        `handled_by` VARCHAR(80) NULL,
        `handled` INT NULL,
        INDEX `status` (`status`),
        INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]])
end)

local function clean(s, max)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('[%c<>]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if utf8.len(s) and utf8.len(s) > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

local function jobOfCid(cid)
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online then return online.PlayerData.job and online.PlayerData.job.name, online end
    local ok, off = pcall(function() return exports.qbx_core:GetOfflinePlayer(cid) end)
    return ok and off and off.PlayerData.job and off.PlayerData.job.name or nil, nil
end

-- a citizen applies (from the hospital reception)
lib.callback.register('exti_ems:server:apply', function(source, data)
    local player = getPlayer(source)
    if not player or type(data) ~= 'table' then return false, 'failed' end
    if isMedic(player) then return false, 'already' end
    local cid = player.PlayerData.citizenid
    local open = MySQL.scalar.await("SELECT COUNT(*) FROM `exti_ems_applications` WHERE `citizenid` = ? AND `status` = 'open'", { cid })
    if (tonumber(open) or 0) > 0 then return false, 'pending' end
    local lastNo = MySQL.scalar.await("SELECT MAX(`handled`) FROM `exti_ems_applications` WHERE `citizenid` = ? AND `status` = 'rejected'", { cid })
    if lastNo and os.time() - tonumber(lastNo) < (APP.retryHours or 24) * 3600 then return false, 'wait' end
    local answers = { experience = clean(data.experience, 300), why = clean(data.why, 400), hours = clean(data.hours, 80) }
    if utf8.len(answers.why) and utf8.len(answers.why) < 10 then return false, 'short' end
    MySQL.insert.await('INSERT INTO `exti_ems_applications` (`citizenid`, `name`, `phone`, `answers`, `created`) VALUES (?, ?, ?, ?, ?)',
        { cid, nameOf(player), clean(data.phone or (player.PlayerData.charinfo and player.PlayerData.charinfo.phone) or '', 20), json.encode(answers), os.time() })
    -- the chiefs on duty hear about it
    for _, id in ipairs(GetPlayers()) do
        local p = getPlayer(tonumber(id))
        if isMedic(p) and p.PlayerData.job.isboss then notify(tonumber(id), 'inform', ('طلب توظيف جديد في الإسعاف من %s. افتح التابلت ← الإدارة'):format(nameOf(player))) end
    end
    lib.logger(source, 'ems', 'applied to EMS')
    return true
end)

local function applicationsView()
    local rows = MySQL.query.await("SELECT * FROM `exti_ems_applications` WHERE `status` = 'open' ORDER BY `id` LIMIT 30") or {}
    local out = {}
    for i, r in ipairs(rows) do
        local ok, a = pcall(json.decode, r.answers or '')
        local job, online = jobOfCid(r.citizenid)
        out[i] = { id = r.id, citizenid = r.citizenid, name = r.name, phone = r.phone, created = r.created, answers = ok and a or {},
            online = online ~= nil, free = job == nil or FREE_JOBS[job] == true, job = job }
    end
    return out
end
EMS_applicationsView = applicationsView

local function chief(src)
    local player = getPlayer(src)
    if not isMedic(player) or not player.PlayerData.job.isboss then return nil end
    return player
end

lib.callback.register('exti_ems:server:appHire', function(source, id)
    local player = chief(source)
    if not player then return false, 'not_boss' end
    local row = MySQL.single.await("SELECT * FROM `exti_ems_applications` WHERE `id` = ? AND `status` = 'open'", { math.tointeger(tonumber(id)) or 0 })
    if not row then return false, 'gone' end
    local job, online = jobOfCid(row.citizenid)
    if job == JOB then return false, 'already' end
    if job and not FREE_JOBS[job] then return false, 'busy_job' end
    local okAdd, added = pcall(function() return exports.qbx_core:AddPlayerToJob(row.citizenid, JOB, 0) end)
    if not okAdd or added == false then return false, 'failed' end
    pcall(function() exports.qbx_core:SetPlayerPrimaryJob(row.citizenid, JOB) end)
    MySQL.update.await("UPDATE `exti_ems_applications` SET `status` = 'hired', `handled_by` = ?, `handled` = ? WHERE `id` = ?", { nameOf(player), os.time(), row.id })
    if online then notify(online.PlayerData.source, 'success', 'قُبل طلبك! أصبحت مسعفًا. اذهب إلى المستشفى وابدأ الدوام من جهاز تسجيل الدخول') end
    lib.logger(source, 'ems', ('hired %s from application #%d'):format(row.citizenid, row.id))
    return applicationsView()
end)

lib.callback.register('exti_ems:server:appReject', function(source, id)
    local player = chief(source)
    if not player then return false, 'not_boss' end
    local row = MySQL.single.await("SELECT * FROM `exti_ems_applications` WHERE `id` = ? AND `status` = 'open'", { math.tointeger(tonumber(id)) or 0 })
    if not row then return false, 'gone' end
    MySQL.update.await("UPDATE `exti_ems_applications` SET `status` = 'rejected', `handled_by` = ?, `handled` = ? WHERE `id` = ?", { nameOf(player), os.time(), row.id })
    local online = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
    if online then notify(online.PlayerData.source, 'inform', 'لم يُقبل طلبك في الإسعاف هذه المرة. تقدر تقدّم مرة أخرى بعد يوم') end
    return applicationsView()
end)

---------------------------------------------------------------------------
-- vehicles: server/fleet.lua (the garages, every vehicle with its own trunk)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- stretcher and wheelchair
---------------------------------------------------------------------------
local function equipmentOf(netId)
    return type(netId) == 'number' and equipment[netId] or nil
end

lib.callback.register('exti_ems:server:registerEquipment', function(source, netId, kind)
    local player = getPlayer(source)
    local def = Config.equipment[kind]
    if not onDuty(player) or type(def) ~= 'table' or not def.model or type(netId) ~= 'number' then return false end
    if equipment[netId] then return false end
    -- the server may hear about the new object a moment after the player made it
    local ent = 0
    for _ = 1, 25 do
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent ~= 0 and DoesEntityExist(ent) then break end
        Wait(100)
    end
    if ent == 0 or not DoesEntityExist(ent) then return false end
    -- only a stretcher / wheelchair this medic just made, next to them
    if GetEntityModel(ent) ~= GetHashKey(def.model) or NetworkGetEntityOwner(ent) ~= source then return false end
    if not near(source, GetEntityCoords(ent), 6.0) then return false end
    -- one stretcher / wheelchair per medic: the old one goes away (unless someone is on it)
    for id, e in pairs(equipment) do
        if e.owner == source and id ~= netId and not e.patient then
            local old = NetworkGetEntityFromNetworkId(id)
            if old ~= 0 and DoesEntityExist(old) then DeleteEntity(old) end
            equipment[id] = nil
        end
    end
    equipment[netId] = { kind = kind, owner = source, pusher = source }
    return true
end)

lib.callback.register('exti_ems:server:equipmentState', function(source, netId)
    local e = equipmentOf(netId)
    if not e then return false end
    return { kind = e.kind, pusher = e.pusher, patient = e.patient, vehicle = e.vehicle, mine = e.pusher == source }
end)

local function entityNear(src, netId, dist)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then return false end
    local ped = pedOf(src)
    return ped and #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= dist
end

lib.callback.register('exti_ems:server:equipment', function(source, netId, action, arg)
    local e = equipmentOf(netId)
    -- letting go always works (also when off duty or when it is gone)
    if action == 'release' then
        if e and e.pusher == source then e.pusher = nil end
        return true
    end
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if not e then return false, 'gone' end
    if not entityNear(source, netId, 4.5) then return false, 'too_far' end

    if action == 'push' then
        if e.pusher and e.pusher ~= source and getPlayer(e.pusher) then return false, 'taken' end
        if e.vehicle then return false, 'loaded' end
        e.pusher = source
        return true
    elseif action == 'putPatient' then
        local target = arg
        if e.patient then return false, 'full' end
        if type(target) ~= 'number' or target == source or not getPlayer(target) then return false, 'no_patient' end
        if not playersClose(source, target, Config.reach + 1.5) then return false, 'too_far' end
        if GetVehiclePedIsIn(pedOf(target), false) ~= 0 then return false, 'in_vehicle' end
        if e.kind == 'wheelchair' and deathState(target) ~= 1 then return false, 'down_wheelchair' end
        for _, other in pairs(equipment) do
            if other.patient == target then return false, 'already' end
        end
        e.patient = target
        TriggerClientEvent('exti_ems:client:mount', target, netId, e.kind)
        return true
    elseif action == 'removePatient' then
        if not e.patient then return true end
        if e.vehicle then return false, 'loaded' end
        TriggerClientEvent('exti_ems:client:dismount', e.patient)
        e.patient = nil
        return true
    elseif action == 'seatPatient' then
        -- wheelchair -> a car seat
        local vehNet = arg
        if not e.patient or type(vehNet) ~= 'number' then return false, 'no_patient' end
        local veh = NetworkGetEntityFromNetworkId(vehNet)
        if veh == 0 or not DoesEntityExist(veh) or not entityNear(source, vehNet, 6.0) then return false, 'too_far' end
        TriggerClientEvent('exti_ems:client:dismount', e.patient, vehNet)
        e.patient = nil
        return true
    elseif action == 'load' then
        local vehNet = arg
        if e.kind ~= 'stretcher' or e.vehicle then return false, 'failed' end
        local veh = type(vehNet) == 'number' and NetworkGetEntityFromNetworkId(vehNet) or 0
        if veh == 0 or not DoesEntityExist(veh) or not entityNear(source, vehNet, 6.5) then return false, 'too_far' end
        local isAmbulance = false
        for _, model in ipairs(Config.equipment.ambulances or {}) do
            if GetEntityModel(veh) == model then isAmbulance = true break end
        end
        if not isAmbulance then return false, 'failed' end
        for _, other in pairs(equipment) do
            if other.vehicle == vehNet then return false, 'full' end
        end
        e.vehicle, e.pusher = vehNet, nil
        return true
    elseif action == 'unload' then
        if not e.vehicle then return false, 'failed' end
        e.vehicle, e.pusher = nil, source
        return true
    elseif action == 'store' then
        if e.patient then return false, 'has_patient' end
        if e.vehicle then return false, 'loaded' end
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
        equipment[netId] = nil
        return true
    end
    return false, 'failed'
end)

-- the patient asks to get off the wheelchair themselves (alive patients only)
RegisterNetEvent('exti_ems:server:leaveEquipment', function()
    local src = source
    if deathState(src) ~= 1 then return end -- someone who is down waits for the medic
    for _, e in pairs(equipment) do
        if e.patient == src and not e.vehicle then
            e.patient = nil
            TriggerClientEvent('exti_ems:client:dismount', src)
            return
        end
    end
end)

-- the patient's game says they are no longer on it (bed, respawn, it vanished): just forget it
RegisterNetEvent('exti_ems:server:leftEquipment', function()
    local src = source
    for _, e in pairs(equipment) do
        if e.patient == src then e.patient = nil end
    end
end)

-- off the stretcher without moving them (they are being put in a hospital bed / respawned / leaving)
local function freePatient(src)
    for _, e in pairs(equipment) do
        if e.patient == src then
            e.patient = nil
            TriggerClientEvent('exti_ems:client:dismount', src, nil, true)
        end
    end
end

AddEventHandler('qbx_medical:server:playerRespawned', function(src) freePatient(src) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    freePatient(src)
    closeCallsOf(src)
    cleanUp(src)
end)

-- a stretcher / wheelchair or an ambulance disappeared (deleted, /dv, the owner left...)
AddEventHandler('entityRemoved', function(entity)
    local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
    if not ok or not netId then return end
    local e = equipment[netId]
    if e then
        if e.patient then TriggerClientEvent('exti_ems:client:dismount', e.patient, nil, true) end
        equipment[netId] = nil
        return
    end
    for _, other in pairs(equipment) do
        if other.vehicle == netId then other.vehicle, other.pusher = nil, nil end -- it stays where the car was
    end
    for src, veh in pairs(vehicles) do
        if veh == entity then vehicles[src] = nil end
    end
    if EMS.fleetGone then EMS.fleetGone(entity) end
end)

-- is this player lying on a stretcher / sitting in a wheelchair? (the client asks after a restart)
lib.callback.register('exti_ems:server:myEquipment', function(source)
    for netId, e in pairs(equipment) do
        if e.patient == source then return netId, e.kind end
    end
end)

---------------------------------------------------------------------------
-- leaving
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    closeCallsOf(src)
    for id, c in pairs(calls) do
        if c.takenBy == src then c.takenBy, c.takenByName, c.helpers = nil, nil, nil end
        if c.helpers then c.helpers[src] = nil end
    end
    for _, e in pairs(equipment) do
        if e.patient == src then e.patient = nil end
    end
    cleanUp(src)
    busy[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for netId, e in pairs(equipment) do
        if e.patient then TriggerClientEvent('exti_ems:client:dismount', e.patient) end
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    for _, veh in pairs(vehicles) do
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end)

-- admins: /emstune to adjust where the stretcher / wheelchair / patient sit (saved for this session)
lib.addCommand('emstune', {
    help = 'EMS: adjust stretcher / wheelchair positions (admin)',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('exti_ems:client:tune', source)
end)
