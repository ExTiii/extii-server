-- =====================================================================
-- EX_Tii medical (server): the exam on the EMS tablet.
-- Every step is timed and checked here (medic on duty, next to the patient). The results are
-- shared: a second medic who opens the same patient sees what was already found.
-- =====================================================================

Med = Med or {}

local sessions = {}   -- [patient citizenid] = session
local busy = {}       -- [medic source] = true while a step is running
local lastNotice = {} -- [patient source] = os.time()
local refused = {}    -- ['medic:patientcid'] = os.time() the patient said no (no asking again right away)
local ASK_AGAIN = 45  -- seconds

local function nameOf(player)
    local c = player and player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(c.firstname or '', c.lastname or '')
    return (name:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function initials(name)
    local a, b = name:match('^(%S+)%s*(%S*)')
    local function first(s)
        if not s or s == '' then return '' end
        return s:match('^[%z\1-\127\194-\244][\128-\191]*') or ''
    end
    return first(a) .. first(b)
end

local function ageOf(birthdate)
    local y = tonumber(tostring(birthdate or ''):match('(%d%d%d%d)'))
    if not y then return nil end
    local age = tonumber(os.date('%Y')) - y
    return (age > 0 and age < 120) and age or nil
end

local function onDutyMedic(src)
    local p = Med.getPlayer(src)
    if not p or p.PlayerData.job.name ~= Config.job or not p.PlayerData.job.onduty then return nil end
    return p
end

--- the patient behind a target: a player (positive id) or a test patient NPC (negative id)
local function patientOf(target)
    target = tonumber(target)
    if not target or target == 0 then return nil end
    if target < 0 then
        local f = Med.fakeOf(target)
        if not f then return nil end
        return { cid = f.cid, fake = f, name = f.name, female = f.female, age = f.age, blood = f.blood }
    end
    local p = Med.getPlayer(target)
    if not p then return nil end
    local info = p.PlayerData.charinfo or {}
    return { cid = p.PlayerData.citizenid, player = p, name = nameOf(p), female = info.gender == 1,
        age = ageOf(info.birthdate), blood = (p.PlayerData.metadata or {}).bloodtype }
end

--- where the patient's body is (ped / NPC entity) and in which world (routing bucket)
local function bodyOf(target, patient)
    if patient.fake then
        local ent = Med.fakeEntity and Med.fakeEntity(patient.fake) or 0
        if ent == 0 then return 0 end
        return ent, GetEntityRoutingBucket(ent)
    end
    local ped = GetPlayerPed(target)
    return ped, GetPlayerRoutingBucket(target)
end

---@return table? patient, table|string medicOrError
local function check(src, target)
    target = tonumber(target)
    if not target or target == src then return nil, 'no_patient' end
    local medic = onDutyMedic(src)
    if not medic then return nil, 'off_duty' end
    if Med.deathOf(src) ~= 1 then return nil, 'failed' end
    local patient = patientOf(target)
    if not patient then return nil, 'no_patient' end
    local a = GetPlayerPed(src)
    local b, bucket = bodyOf(target, patient)
    if a == 0 or b == 0 or GetPlayerRoutingBucket(src) ~= bucket
        or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.examReach then
        return nil, 'too_far'
    end
    return patient, medic
end

local function notifyPatient(target, text)
    if type(target) ~= 'number' or target <= 0 then return end -- a test patient has no screen
    local now = os.time()
    if lastNotice[target] and now - lastNotice[target] < 3 then return end
    lastNotice[target] = now
    TriggerClientEvent('exti_medical:client:examined', target, text)
end

local function newSession()
    -- viewers = medics with this patient open (tablet or treatment); treat = the ones in treatment mode
    return { checked = {}, results = {}, vitals = {}, said = nil, consent = {}, viewers = {}, treat = {}, started = os.time(), last = os.time() }
end

local function sessionOf(patient, create)
    local cid = patient.cid
    local s = sessions[cid]
    if s and os.time() - s.last > Config.examKeep * 60 then s = nil end
    if not s and create then
        s = newSession()
        sessions[cid] = s
    end
    return s
end

-- ---------------------------------------------------------------------
-- what the tablet shows
-- ---------------------------------------------------------------------
local MEASURES = { 'hr', 'bp', 'spo2', 'temp', 'listen', 'pupils' }

local function view(s, target, patient)
    local name = patient.name or ''
    local female = patient.female == true
    local death = Med.deathOf(target)
    local b = Med.body(target)
    local chips = {}
    if patient.fake then chips[#chips + 1] = { 'مريض تجريبي', 'warn' } end
    if death ~= 1 then chips[#chips + 1] = { 'على الأرض', 'bad' } end
    if b.consciousness == 'none' then chips[#chips + 1] = { 'لا يستجيب', 'bad' }
    elseif b.consciousness == 'confused' then chips[#chips + 1] = { female and 'واعية لكن مشوّشة' or 'واعٍ لكن مشوّش', 'warn' }
    else chips[#chips + 1] = { female and 'واعية' or 'واعٍ', 'ok' } end

    local zones, checked = {}, 0
    for _, z in ipairs(Config.zoneOrder) do
        if s.checked[z] then
            checked = checked + 1
            zones[z] = s.results[z]
        end
    end
    local measured = 0
    for _, m in ipairs(MEASURES) do
        if m == 'listen' then
            if s.vitals.heart or s.vitals.lungL or s.vitals.lungR then measured = measured + 1 end
        elseif s.vitals[m] then
            measured = measured + 1
        end
    end
    return {
        target = target,
        patient = {
            name = name ~= '' and name or ('مريض #%d'):format(math.abs(target)),
            initials = initials(name ~= '' and name or '؟'),
            gender = female and 'أنثى' or 'ذكر',
            female = female,
            age = patient.age,
            blood = patient.blood,
        },
        death = death,
        chips = chips,
        zones = zones,
        vitals = s.vitals,
        said = s.said,
        counts = { zones = checked, zonesOf = #Config.zoneOrder, measures = measured, measuresOf = #MEASURES },
        started = s.started,
        now = os.time(),
        times = Config.time,
    }
end

local function push(s, target, patient, except)
    local v
    for medic in pairs(s.viewers) do
        if medic ~= except then
            if GetPlayerPing(medic) > 0 then
                if s.treat[medic] then
                    if Med.treatPush then Med.treatPush(medic, s, target, patient) end
                else
                    v = v or view(s, target, patient)
                    TriggerClientEvent('exti_medical:client:examUpdate', medic, target, v)
                end
            else
                s.viewers[medic] = nil
                s.treat[medic] = nil
            end
        end
    end
end

-- what the acting medic gets back: the tablet view, or the treatment view in treatment mode
local function viewFor(src, s, target, patient)
    if s.treat[src] and Med.treatView then return Med.treatView(src, s, target, patient) end
    return view(s, target, patient)
end

-- ---------------------------------------------------------------------
-- asking an awake patient first
-- ---------------------------------------------------------------------
local function askConsent(target, medicName)
    local p = promise.new()
    local done = false
    lib.callback('exti_medical:client:consent', target, function(ok)
        if done then return end
        done = true
        p:resolve(ok == true)
    end, medicName)
    SetTimeout(Config.consentTimeout * 1000, function()
        if done then return end
        done = true
        p:resolve(false)
        TriggerClientEvent('exti_medical:client:consentClosed', target)
    end)
    return Citizen.Await(p)
end

--- open a patient for a medic (asks an awake player first); returns true, session, patient, medic
local function openFor(src, target)
    local patient, medic = check(src, target)
    if not patient then return false, medic end
    target = tonumber(target)
    local s = sessionOf(patient, true)
    if not patient.fake and Med.deathOf(target) == 1 and not s.consent[src] then -- a test patient always says yes
        if busy[src] then return false, 'busy' end
        local key = ('%d:%s'):format(src, patient.cid)
        if refused[key] and os.time() - refused[key] < ASK_AGAIN then return false, 'ask_later' end
        busy[src] = true
        local ok = target > 0 and askConsent(target, nameOf(medic))
        busy[src] = nil
        if not ok then
            refused[key] = os.time()
            return false, 'declined'
        end
        refused[key] = nil
        s.consent[src] = true
        patient, medic = check(src, target)
        if not patient then return false, medic end
    end
    s.viewers[src] = true
    s.last = os.time()
    return true, s, patient, medic
end

lib.callback.register('exti_medical:server:open', function(src, target)
    local ok, s, patient, medic = openFor(src, target)
    if not ok then return false, s end
    target = tonumber(target)
    s.treat[src] = nil
    notifyPatient(target, ('المسعف %s يفحصك الآن — لا تتحرك'):format(nameOf(medic)))
    return true, view(s, target, patient)
end)

lib.callback.register('exti_medical:server:close', function(src, target)
    local patient = patientOf(target)
    local s = patient and sessionOf(patient, false)
    if s then
        s.viewers[src] = nil
        s.treat[src] = nil
    end
    return true
end)

--- one timed step: wait, check again, then do it
local function step(src, target, seconds, notice, fn)
    local patient, medic = check(src, target)
    if not patient then return false, medic end
    target = tonumber(target)
    local s = sessionOf(patient, false)
    if not s or not s.viewers[src] then return false, 'not_open' end
    if busy[src] then return false, 'busy' end
    busy[src] = true
    notifyPatient(target, notice)
    Wait(math.floor(seconds * 1000))
    busy[src] = nil
    patient, medic = check(src, target)
    if not patient then return false, medic end
    local ok, err = pcall(fn, s, target)
    if not ok then
        print(('^1[exti_medical] exam step failed: %s^0'):format(tostring(err)))
        return false, 'failed'
    end
    s.last = os.time()
    local v = viewFor(src, s, target, patient)
    push(s, target, patient, src)
    return true, v
end

local function round1(v) return math.floor(v * 10 + 0.5) / 10 end

lib.callback.register('exti_medical:server:zone', function(src, target, zone)
    local z = type(zone) == 'string' and Config.zones[zone]
    if not z then return false, 'failed' end
    return step(src, target, Config.time.zone, ('المسعف يفحص %s'):format(z.label), function(s, t)
        local inZone = {}
        for _, p in ipairs(z.parts) do inZone[p] = true end
        local items, level = {}, 0
        for _, w in ipairs(Med.list(t)) do
            if inZone[w.p] then
                local item = Med.T.wound(w)
                items[#items + 1] = item
                level = math.max(level, item.level)
            end
        end
        table.sort(items, function(a, b) return a.level > b.level end)
        s.checked[zone] = true
        s.results[zone] = { label = z.label, level = level, items = items }
    end)
end)

local TOOLS = {
    pulse = { time = 'pulse', notice = 'المسعف يجسّ نبضك' },
    spo2 = { time = 'spo2', notice = 'المسعف يضع مقياس الأكسجين على إصبعك' },
    temp = { time = 'temp', notice = 'المسعف يقيس حرارتك' },
    pupils = { time = 'pupils', notice = 'المسعف يفحص عينيك بالضوء' },
    heart = { time = 'listen', notice = 'المسعف يسمع قلبك' },
    L = { time = 'listen', notice = 'المسعف يسمع رئتك اليسرى' },
    R = { time = 'listen', notice = 'المسعف يسمع رئتك اليمنى' },
}

lib.callback.register('exti_medical:server:measure', function(src, target, tool)
    local t = type(tool) == 'string' and TOOLS[tool]
    if not t then return false, 'failed' end
    return step(src, target, Config.time[t.time], t.notice, function(s, pt)
        local b = Med.body(pt)
        local now = os.time()
        if tool == 'pulse' then
            local v = b.hr > 0 and math.max(30, b.hr + math.random(-2, 2)) or 0
            local label, cls = Med.T.hr(v, b.sys)
            s.vitals.hr = { v = v, label = label, cls = cls, at = now }
        elseif tool == 'spo2' then
            local v = b.spo2 and math.min(100, b.spo2 + math.random(-1, 1)) or nil
            local label, cls = Med.T.spo2(v)
            s.vitals.spo2 = { v = v, label = label, cls = cls, at = now }
        elseif tool == 'temp' then
            local v = round1(b.temp + math.random(-1, 1) / 10)
            local label, cls = Med.T.temp(v)
            s.vitals.temp = { v = v, label = label, cls = cls, at = now }
        elseif tool == 'pupils' then
            local p = Med.T.pupils[b.pupils]
            s.vitals.pupils = { text = p[1], cls = p[2], at = now }
        elseif tool == 'heart' then
            local text, cls = Med.T.heart(b)
            s.vitals.heart = { text = text, cls = cls, at = now }
        else
            local text, cls = Med.T.lung(b, tool)
            s.vitals['lung' .. tool] = { text = text, cls = cls, at = now }
            local v = b.resp > 0 and math.max(4, b.resp + math.random(-1, 1)) or 0
            local label, rcls = Med.T.resp(v)
            s.vitals.resp = { v = v, label = label, cls = rcls, at = now }
        end
    end)
end)

lib.callback.register('exti_medical:server:ask', function(src, target)
    return step(src, target, Config.time.ask, 'المسعف يسألك: وين يوجعك؟', function(s, t)
        local b = Med.body(t)
        s.said = Med.T.say(t, b) or { quote = 'المريض لا يستجيب', none = true }
    end)
end)

-- ---------------------------------------------------------------------
-- the blood pressure cuff (a short game on the tablet)
-- ---------------------------------------------------------------------
lib.callback.register('exti_medical:server:bpStart', function(src, target)
    local patient, medic = check(src, target)
    if not patient then return false, medic end
    target = tonumber(target)
    local s = sessionOf(patient, false)
    if not s or not s.viewers[src] then return false, 'not_open' end
    if busy[src] then return false, 'busy' end
    local b = Med.body(target)
    local token = math.random(100000, 999999)
    notifyPatient(target, 'المسعف يقيس ضغطك — لا تتحرك')
    if b.death == 3 then
        s.bp = { token = token, medic = src, at = GetGameTimer(), none = true }
        return true, { token = token, none = true }
    end
    local sys = b.sys + math.random(-2, 2)
    local dia = math.min(sys - 15, b.dia + math.random(-2, 2))
    s.bp = { token = token, medic = src, at = GetGameTimer(), sys = sys, dia = dia }
    return true, { token = token, sys = sys, dia = dia, hr = math.max(40, b.hr) }
end)

lib.callback.register('exti_medical:server:bpFinish', function(src, target, token, sys, dia)
    local patient, medic = check(src, target)
    if not patient then return false, medic end
    target = tonumber(target)
    local s = sessionOf(patient, false)
    if not s or not s.bp or s.bp.medic ~= src or s.bp.token ~= tonumber(token) then return false, 'failed' end
    if GetGameTimer() - s.bp.at < Config.time.bpMin * 1000 then return false, 'failed' end
    local truth = s.bp
    s.bp = nil
    local b = Med.body(target)
    if b.death == 3 or truth.none then
        s.vitals.bp = { sys = 0, dia = 0, label = 'لا يمكن قياسه', cls = 'bad', at = os.time() }
    else
        sys, dia = tonumber(sys), tonumber(dia)
        if not sys or not dia then return false, 'failed' end
        -- the reading comes from the medic's timing: a bit off is normal, far off is not possible
        sys = math.max(truth.sys - 30, math.min(truth.sys + 30, sys))
        dia = math.max(truth.dia - 30, math.min(truth.dia + 30, dia))
        sys = math.floor(math.max(40, math.min(260, sys)) + 0.5)
        dia = math.floor(math.max(20, math.min(sys - 5, dia)) + 0.5)
        local label, cls = Med.T.bp(sys)
        s.vitals.bp = { sys = sys, dia = dia, label = label, cls = cls, at = os.time() }
    end
    s.last = os.time()
    local v = viewFor(src, s, target, patient)
    push(s, target, patient, src)
    return true, v
end)

-- new injuries / healed: a healed patient starts a fresh exam
AddEventHandler('exti_medical:server:woundsChanged', function(src)
    local patient = patientOf(src)
    if not patient then return end
    if #Med.list(src) == 0 then
        local s = sessions[patient.cid]
        if s then
            s.checked, s.results, s.vitals, s.said = {}, {}, {}, nil
            push(s, src, patient)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastNotice[src] = nil
    for _, s in pairs(sessions) do
        s.viewers[src] = nil
        s.treat[src] = nil
    end
end)

-- old sessions go away
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for cid, s in pairs(sessions) do
            if now - s.last > Config.examKeep * 60 then sessions[cid] = nil end
        end
        for key, at in pairs(refused) do
            if now - at > ASK_AGAIN then refused[key] = nil end
        end
    end
end)

-- ---------------------------------------------------------------------
-- admin: test injuries (so you can try the exam without hurting anyone)
-- ---------------------------------------------------------------------
local TESTS = {
    mix = {
        { k = 'gunshot', p = 'LLEG', r = 1, b = 2, s = 2, pw = 1, w = 'مسدس' },
        { k = 'fracture', p = 'RLEG', s = 3, b = 0, w = 'سقوط' },
        { k = 'laceration', p = 'RARM', cm = 6, b = 1, s = 2, w = 'سكين' },
    },
    gun = { { k = 'gunshot', p = 'UPPER_BODY', r = 1, b = 2, s = 3, pw = 2, lung = 'L', w = 'بندقية' } },
    knife = { { k = 'stab', p = 'LOWER_BODY', b = 2, s = 3, w = 'سكين' }, { k = 'laceration', p = 'LARM', cm = 8, b = 1, s = 2, w = 'سكين' } },
    fall = { { k = 'fracture', p = 'LFOOT', s = 3, b = 0, w = 'سقوط' }, { k = 'bruise', p = 'LLEG', s = 2, b = 0, w = 'سقوط' } },
    car = { { k = 'bruise', p = 'UPPER_BODY', s = 2, b = 0, w = 'دهس سيارة' }, { k = 'fracture', p = 'RLEG', s = 3, b = 0, w = 'دهس سيارة' }, { k = 'abrasion', p = 'LARM', s = 1, b = 0, w = 'دهس سيارة' } },
    fire = { { k = 'burn', p = 'LARM', deg = 2, s = 2, b = 0, w = 'نار' }, { k = 'burn', p = 'RLEG', deg = 3, s = 3, b = 0, w = 'نار' } },
    head = { { k = 'bruise', p = 'HEAD', s = 2, b = 0, conc = true, w = 'مضرب' } },
    chest = { { k = 'gunshot', p = 'UPPER_BODY', r = 0, b = 3, s = 3, pw = 3, lung = 'R', w = 'قناصة' } },
    smoke = { { k = 'smoke', p = 'UPPER_BODY', s = 2, b = 0, w = 'دخان' } },
}
Med.TESTS = TESTS -- the test patients (server/fake.lua) use the same sets

-- shared with server/treat.lua
Med.exam = {
    check = check, patientOf = patientOf, sessionOf = sessionOf, openFor = openFor, push = push, view = view,
    busy = busy, notifyPatient = notifyPatient, nameOf = nameOf,
}

--- a test patient was removed: forget its exam, and close it on the medics' tablets
function Med.dropExam(cid, target)
    local s = cid and sessions[cid]
    if not s then return end
    sessions[cid] = nil
    for medic in pairs(s.viewers) do
        if GetPlayerPing(medic) > 0 then TriggerClientEvent('exti_medical:client:examGone', medic, target) end
    end
end

local function targetOf(source, args)
    local id = tonumber(args.id) or source
    if not Med.getPlayer(id) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'اللاعب غير موجود' })
        return nil
    end
    return id
end

lib.addCommand('woundtest', {
    help = 'إصابات تجريبية لتجربة الفحص الطبي (مثال: /woundtest mix 5)',
    restricted = 'group.admin',
    params = {
        { name = 'type', type = 'string', help = 'mix / gun / knife / fall / car / fire / head / chest / smoke', optional = true },
        { name = 'id', type = 'playerId', help = 'رقم اللاعب (فارغ = أنت)', optional = true },
    },
}, function(source, args)
    local id = targetOf(source, args)
    if not id then return end
    local set = TESTS[args.type or 'mix'] or TESTS.mix
    for _, w in ipairs(set) do
        local copy = {}
        for k, v in pairs(w) do copy[k] = v end
        Med.add(id, copy)
    end
    TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = ('أُضيفت إصابات تجريبية (%s) للاعب %d'):format(args.type or 'mix', id) })
end)

lib.addCommand('wounds', {
    help = 'اعرض إصابات لاعب (في F8)',
    restricted = 'group.admin',
    params = { { name = 'id', type = 'playerId', help = 'رقم اللاعب (فارغ = أنت)', optional = true } },
}, function(source, args)
    local id = targetOf(source, args)
    if not id then return end
    local list = Med.list(id)
    local lines = { ('-- إصابات اللاعب %d: %d --'):format(id, #list) }
    for _, w in ipairs(list) do
        local t = Med.T.wound(w)
        lines[#lines + 1] = ('%s: %s'):format(t.part, t.text)
    end
    TriggerClientEvent('exti_medical:client:print', source, table.concat(lines, '\n'))
    TriggerClientEvent('ox_lib:notify', source, { type = 'inform', description = ('%d إصابة — التفاصيل في F8'):format(#list) })
end)

lib.addCommand('woundsclear', {
    help = 'امسح كل إصابات لاعب',
    restricted = 'group.admin',
    params = { { name = 'id', type = 'playerId', help = 'رقم اللاعب (فارغ = أنت)', optional = true } },
}, function(source, args)
    local id = targetOf(source, args)
    if not id then return end
    Med.clear(id)
    TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = ('مُسحت إصابات اللاعب %d'):format(id) })
end)
