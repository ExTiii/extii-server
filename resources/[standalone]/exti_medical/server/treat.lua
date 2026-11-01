-- =====================================================================
-- EX_Tii medical (server): treatment step by step (like the video).
-- The medic opens the patient in treatment mode, the server builds the treatment plan from what
-- was found (wounds in the checked body parts + the measured vitals), and every step is checked
-- here: the medic is on duty and next to the patient, has the item, and took long enough.
-- When the plan is done the patient is stable: a downed player gets up, a hurt one is healed,
-- the treated wounds go (fractures stay for the hospital).
-- =====================================================================

Med = Med or {}

local C = Config.treat
local E -- Med.exam (set once exam.lua has run)
local pending = {}   -- [medic] = the step that is running { token, action, target, wid, choice, at, min, item }
local watch = {}     -- [target] = { s, until } infusions running (the plan changes when a bag ends)
local doneAt = {}    -- [patient cid] = os.time() the plan was finished (no double finish)

local ZONE_OF = {}
for zone, z in pairs(Config.zones) do
    for _, part in ipairs(z.parts) do ZONE_OF[part] = zone end
end

local NEEDS_DRESSING = { gunshot = true, pellets = true, shrapnel = true, stab = true, laceration = true, bite = true, abrasion = true, burn = true }
local EXTRACT = { gunshot = true, pellets = true, shrapnel = true, probes = true }

local function api()
    E = E or Med.exam
    return E
end

-- ---------------------------------------------------------------------
-- items
-- ---------------------------------------------------------------------
local function itemCount(src, key)
    local it = C.items[key]
    if not it then return 0 end
    local ok, n = pcall(function() return exports.ox_inventory:Search(src, 'count', it.item) end)
    return ok and tonumber(n) or 0
end

local function takeItem(src, key)
    local it = C.items[key]
    if not it then return false end
    if it.tool then return itemCount(src, key) > 0 end
    local ok, removed = pcall(function() return exports.ox_inventory:RemoveItem(src, it.item, 1) end)
    return ok and removed and true or false
end

local function woundById(list, id)
    id = tonumber(id)
    for i = 1, #list do
        if list[i].id == id then return list[i] end
    end
end

-- what can stop this bleeding properly (a strong bleed needs more than gauze)
local function dressingsFor(w)
    if (w.b or 0) >= 2 then return { 'pressure', 'quickclot' } end
    return { 'gauze', 'pressure', 'quickclot' }
end

-- an open wound needs a dressing: everything that bleeds, and burns / cuts / scrapes / bites,
-- and a bullet hole once the bullet is out
local function needsDressing(w)
    if (w.b or 0) > 0 then return true end
    if w.dr then return false end
    if w.k == 'gunshot' or w.k == 'pellets' or w.k == 'shrapnel' then return (w.x or 0) > 0 end
    return NEEDS_DRESSING[w.k] == true
end

-- ---------------------------------------------------------------------
-- the treatment plan
-- ---------------------------------------------------------------------
local function runningInfusion(meta, now)
    for _, inf in ipairs(meta and meta.inf or {}) do
        if now < inf.s + inf.d then return inf end
    end
end

---@return table plan
local function buildPlan(target, s)
    local now = os.time()
    local list = Med.list(target)
    local b = Med.body(target)
    local meta = Med.meta(target) or {}
    local zonesDone = 0
    for _, z in ipairs(Config.zoneOrder) do
        if s.checked[z] then zonesDone = zonesDone + 1 end
    end
    local v = s.vitals
    local vitalsDone = (v.hr and 1 or 0) + (v.bp and 1 or 0) + (v.spo2 and 1 or 0)
    local diag = {
        zones = { done = zonesDone, of = #Config.zoneOrder },
        vitals = { done = vitalsDone, of = 3 },
    }
    diag.complete = zonesDone >= #Config.zoneOrder and vitalsDone >= 3

    local tasks, later, hidden = {}, {}, 0
    local bleedingLeft, zones = false, {}
    for _, z in ipairs(Config.zoneOrder) do
        zones[z] = { checked = s.checked[z] == true, level = 0, todo = 0, wounds = {} }
    end

    for _, w in ipairs(list) do
        local zone = ZONE_OF[w.p] or 'chest'
        local seen = s.checked[zone]
        local part = Config.parts[w.p] or ''
        local actions = {}
        if EXTRACT[w.k] and (w.r or 0) > 0 then
            actions[#actions + 1] = {
                kind = 'extract', wid = w.id, items = { 'forceps' }, game = 'bullet',
                label = w.k == 'probes' and 'انزع سهمي الصاعق' or 'أخرج الرصاصة',
            }
        end
        if needsDressing(w) then
            local bleeding = (w.b or 0) > 0
            actions[#actions + 1] = {
                kind = 'dress', wid = w.id, items = bleeding and dressingsFor(w) or { 'gauze' }, game = 'wrap',
                label = bleeding and ((w.b or 0) >= 2 and 'أوقف النزيف بضماد ضاغط' or 'لفّ الجرح بالشاش') or (w.k == 'burn' and 'غطِّ الحرق بالشاش' or 'نظّف الجرح ولفّه بالشاش'),
                blocked = (w.r or 0) > 0 and EXTRACT[w.k] and 'extract_first' or nil,
            }
            if bleeding and Config.limbs[w.p] and Med.isBleeding(w, now) then
                actions[#actions + 1] = { kind = 'tourniquet', wid = w.id, items = { 'tourniquet' }, game = 'quick', label = 'عاصبة (مؤقتة)', optional = true }
            end
        end
        if Med.isBleeding(w, now) then bleedingLeft = true end
        local isLater = w.k == 'fracture' or w.k == 'sprain'
        if seen then
            local t = Med.T.wound(w)
            local zz = zones[zone]
            zz.level = math.max(zz.level, t.level)
            zz.wounds[#zz.wounds + 1] = { id = w.id, kind = w.k, text = t.text, tags = t.tags, level = t.level, actions = actions, later = isLater or nil }
            for _, a in ipairs(actions) do
                if not a.optional then
                    zz.todo = zz.todo + 1
                    local title
                    if a.kind == 'extract' then
                        title = w.k == 'probes' and ('انزع سهمي الصاعق من ' .. part) or ('أخرج ' .. ((w.r or 0) > 1 and 'الرصاصات' or 'الرصاصة') .. ' من ' .. part)
                    else
                        title = a.label .. ' — ' .. part
                    end
                    tasks[#tasks + 1] = {
                        id = a.kind .. ':' .. w.id, kind = a.kind, wid = w.id, zone = zone, title = title,
                        sub = t.text, items = a.items, game = a.game, blocked = a.blocked,
                    }
                end
            end
            if isLater then
                later[#later + 1] = { title = (w.k == 'sprain' and 'التواء في ' or 'كسر في ') .. part, sub = 'يحتاج أشعة وجبس في المستشفى' }
            end
        elseif #actions > 0 then
            hidden = hidden + 1
        end
    end
    if b.conc then later[#later + 1] = { title = 'اشتباه ارتجاج', sub = 'راقبه — يحتاج فحصًا في المستشفى' } end

    -- the whole body
    local running = runningInfusion(meta, now)
    local infusion
    if running then
        infusion = { kind = running.k, left = math.max(0, running.s + running.d - now), total = running.d }
    end
    -- a patient on the ground always gets a line in the vein (stabilise him); more bags while he lost a lot
    local downNoLine = b.death ~= 1 and #(meta.inf or {}) == 0
    if v.bp and (b.class >= 2 or running or downNoLine) then
        tasks[#tasks + 1] = {
            id = 'infuse', kind = 'infuse', game = 'quick',
            title = b.class >= 3 and 'ابدأ نقل الدم' or 'ابدأ محلولًا ملحيًا أو نقل دم',
            sub = running and ('الكيس شغّال — باقي %d ث'):format(infusion.left)
                or (b.class >= 2 and 'فقد دمًا كثيرًا — الضغط منخفض' or 'المريض على الأرض — ركّب له محلولًا لتثبيت حالته'),
            items = b.class >= 3 and { 'blood' } or { 'saline', 'blood' },
            running = running and true or nil,
        }
    end
    if v.spo2 and b.spo2 and b.spo2 < 94 and not meta.ox and b.death ~= 3 then
        tasks[#tasks + 1] = { id = 'oxygen', kind = 'oxygen', game = 'breaths', title = 'أعطه أكسجين بكيس التنفس', sub = ('الأكسجين %d%% — منخفض'):format(b.spo2), items = { 'bvm' } }
    end
    if s.said and not s.said.none and b.consciousness ~= 'none' and b.pain >= 4 then
        tasks[#tasks + 1] = {
            id = 'med', kind = 'med', game = 'quick', optional = true,
            title = 'أعطه مسكّنًا مناسبًا', sub = ('الألم %d من 10'):format(b.pain),
            items = b.pain >= 6 and { 'morphine' } or { 'ibuprofen', 'morphine' },
        }
    end
    local needsFluid = false
    for _, t in ipairs(tasks) do
        if t.kind == 'infuse' and not t.running and #(meta.inf or {}) == 0 then needsFluid = true end
    end
    if b.death == 3 then
        local blocked
        if not diag.complete then blocked = 'diag_first'
        elseif bleedingLeft then blocked = 'bleeding_first'
        elseif needsFluid then blocked = 'infuse_first' end
        tasks[#tasks + 1] = {
            id = 'cpr', kind = 'cpr', game = 'cpr', title = 'ابدأ الإنعاش القلبي (CPR)',
            sub = ('لا يوجد نبض — الدورة %d من %d (جهاز الصدمات يختصر)'):format(meta.cpr or 0, C.cprCycles),
            items = {}, blocked = blocked, cycles = meta.cpr or 0, of = C.cprCycles,
        }
    end

    local required = 0
    for _, t in ipairs(tasks) do
        if not t.optional then required = required + 1 end
    end
    return {
        diag = diag, tasks = tasks, later = later, hidden = hidden, zones = zones, infusion = infusion,
        complete = diag.complete and required == 0 and hidden == 0,
        death = b.death,
    }
end
Med.buildPlan = buildPlan

-- ---------------------------------------------------------------------
-- what the treatment screen shows
-- ---------------------------------------------------------------------
function Med.treatView(src, s, target, patient)
    local plan = buildPlan(target, s)
    local v = s.vitals
    local items = {}
    for _, key in ipairs(C.order) do
        local it = C.items[key]
        items[#items + 1] = { key = key, item = it.item, label = it.label, tool = it.tool or nil, count = itemCount(src, key) }
    end
    local name = patient.name or ''
    return {
        target = target,
        patient = { name = name ~= '' and name or ('مريض #%d'):format(math.abs(target)), female = patient.female == true, fake = patient.fake and true or nil },
        mini = {
            hr = v.hr and v.hr.v or nil,
            spo2 = v.spo2 and v.spo2.v or nil,
            bp = v.bp and (v.bp.sys > 0 and ('%d/%d'):format(v.bp.sys, v.bp.dia) or '—') or nil,
        },
        plan = plan,
        items = items,
        times = Config.time,
        quick = C.quickTime,
        turns = C.wrapTurns,
        pending = pending[src] and pending[src].action or nil,
        stable = s.stable and os.time() - s.stable < 60 or nil,
    }
end

function Med.treatPush(medic, s, target, patient)
    TriggerClientEvent('exti_medical:client:treatUpdate', medic, target, Med.treatView(medic, s, target, patient))
end

-- ---------------------------------------------------------------------
-- finishing: the patient is stable
-- ---------------------------------------------------------------------
local function rawDeath(target)
    if target < 0 then return Med.deathOf(target) end
    local st = Player(target).state['qbx_medical:deathState']
    return (st == 2 or st == 3) and st or 1
end

local function healthOf(target)
    if target < 0 then
        local f = Med.fakeOf(target)
        return f and f.hp or 100
    end
    local ped = GetPlayerPed(target)
    if ped == 0 then return 100 end
    return math.max(0, math.min(100, math.floor(GetEntityHealth(ped) - 100 + 0.5)))
end

local function finish(src, target, s, patient, medic)
    local key = patient.cid
    if doneAt[key] and os.time() - doneAt[key] < 20 then return false end
    doneAt[key] = os.time()
    local wasDown = rawDeath(target) ~= 1
    local health = healthOf(target)
    if patient.fake then
        local f = patient.fake
        f.death, f.hp = 1, 100
        Med.keepForHospital(target)
        if GetPlayerPing(f.creator) > 0 then
            TriggerClientEvent('exti_medical:client:fakeStable', f.creator, f.id)
        end
        if f.netId then
            local ent = Med.fakeEntity(f)
            if ent ~= 0 then Entity(ent).state:set('exti_fake', { id = f.id, death = 1 }, true) end
        end
    else
        if wasDown then
            pcall(function() exports.qbx_medical:Revive(target) end)
        elseif health < 100 then
            pcall(function() exports.qbx_medical:Heal(target) end)
        end
        Med.keepForHospital(target)
        TriggerClientEvent('ox_lib:notify', target, { type = 'success', description = ('حالتك مستقرة الآن — عالجك المسعف %s'):format(api().nameOf(medic)) })
    end
    local paid = 0
    if not patient.fake and GetResourceState('exti_ems') == 'started' then
        local ok, res = pcall(function() return exports.exti_ems:CareDone(src, target, wasDown and 'revive' or 'treat', health) end)
        if ok and tonumber(res) then paid = tonumber(res) end
    end
    s.checked, s.results, s.vitals, s.said = {}, {}, {}, nil
    s.stable = os.time()
    return true, paid
end

-- ---------------------------------------------------------------------
-- callbacks
-- ---------------------------------------------------------------------
local NOTICE = {
    extract = 'المسعف يخرج الرصاصة — لا تتحرك',
    dress = 'المسعف يضمّد جرحك',
    tourniquet = 'المسعف يربط عاصبة على جرحك',
    infuse = 'المسعف يركّب لك محلولًا في الوريد',
    oxygen = 'المسعف يعطيك أكسجين',
    med = 'المسعف يعطيك مسكّنًا',
    cpr = 'المسعف يجري لك إنعاشًا قلبيًا',
    defib = 'المسعف يستخدم جهاز الصدمات',
}

-- the treatment mode opens (asks an awake player first, like the exam)
lib.callback.register('exti_medical:server:treatOpen', function(src, target)
    local e = api()
    local ok, s, patient, medic = e.openFor(src, target)
    if not ok then return false, s end
    target = tonumber(target)
    s.treat[src] = true
    s.stable = nil
    pending[src] = nil
    e.notifyPatient(target, ('المسعف %s بدأ علاجك — لا تتحرك'):format(e.nameOf(medic)))
    return true, Med.treatView(src, s, target, patient)
end)

lib.callback.register('exti_medical:server:treatClose', function(src, target)
    local e = api()
    pending[src] = nil
    local patient = e.patientOf(target)
    local s = patient and e.sessionOf(patient, false)
    if s then
        s.treat[src] = nil
        s.viewers[src] = nil
    end
    return true
end)

lib.callback.register('exti_medical:server:treatView', function(src, target)
    local e = api()
    local patient, err = e.check(src, target)
    if not patient then return false, err end
    local s = e.sessionOf(patient, false)
    if not s or not s.treat[src] then return false, 'not_open' end
    return true, Med.treatView(src, s, tonumber(target), patient)
end)

local function findAction(plan, action, wid)
    if action == 'extract' or action == 'dress' or action == 'tourniquet' then
        for _, z in pairs(plan.zones) do
            for _, w in ipairs(z.wounds) do
                if w.id == wid then
                    for _, a in ipairs(w.actions) do
                        if a.kind == action then return a end
                    end
                end
            end
        end
        return nil
    end
    for _, t in ipairs(plan.tasks) do
        if t.kind == action then return t end
    end
    if action == 'defib' then
        for _, t in ipairs(plan.tasks) do
            if t.kind == 'cpr' then return { kind = 'defib', items = { 'defib' }, game = 'defib', blocked = t.blocked, cpr = t } end
        end
    end
end

lib.callback.register('exti_medical:server:treatStart', function(src, target, action, wid, choice)
    local e = api()
    local patient, err = e.check(src, target)
    if not patient then return false, err end
    target = tonumber(target)
    local s = e.sessionOf(patient, false)
    if not s or not s.treat[src] then return false, 'not_open' end
    if e.busy[src] or pending[src] then return false, 'busy' end
    if type(action) ~= 'string' or not NOTICE[action] then return false, 'failed' end
    wid = tonumber(wid)
    local plan = buildPlan(target, s)
    local a = findAction(plan, action, wid)
    if not a then return false, 'not_needed' end
    if a.blocked then return false, a.blocked end
    if a.running then return false, 'running' end

    local meta = Med.meta(target) or {}
    local key
    if action == 'cpr' then
        key = nil
    elseif action == 'defib' then
        if (meta.cpr or 0) < 1 then return false, 'cpr_first' end
        key = 'defib'
    else
        local allowed = {}
        for _, k in ipairs(a.items or {}) do allowed[k] = true end
        key = (type(choice) == 'string' and allowed[choice]) and choice or (a.items and a.items[1])
        if not key or not allowed[key] then return false, 'failed' end
    end
    if key and itemCount(src, key) < 1 then return false, 'no_item' end

    local token = math.random(100000, 999999)
    pending[src] = {
        token = token, action = action, target = target, wid = wid, choice = key,
        at = GetGameTimer(), min = (action == 'dress' and C.dressMin and C.dressMin[key]) or C.minTime[action] or 2,
    }
    e.notifyPatient(target, NOTICE[action])
    local params = {}
    if action == 'extract' then
        local list = Med.list(target)
        local w = woundById(list, wid)
        params.power = w and w.pw or 2
        params.left = w and w.r or 1
        params.probes = w and w.k == 'probes' or nil
    elseif action == 'dress' then
        params.turns = C.wrapTurns[key] or 3
        params.item = key
        local w = woundById(Med.list(target), wid)
        params.part = w and Config.parts[w.p] or ''
        params.limb = w and Config.limbs[w.p] and true or false
    elseif action == 'cpr' then
        params.cycle = (meta.cpr or 0) + 1
        params.of = C.cprCycles
        params.defib = itemCount(src, 'defib') > 0
    elseif action == 'oxygen' then
        params.breaths = 3
    elseif action == 'tourniquet' or action == 'infuse' or action == 'med' then
        params.seconds = C.quickTime[action] or 3
        params.item = key
    end
    return true, { token = token, game = a.game or (action == 'defib' and 'defib') or 'quick', params = params }
end)

lib.callback.register('exti_medical:server:treatCancel', function(src)
    pending[src] = nil
    return true
end)

lib.callback.register('exti_medical:server:treatFinish', function(src, target, token, result)
    local e = api()
    local p = pending[src]
    target = tonumber(target)
    if not p or p.target ~= target or p.token ~= tonumber(token) then return false, 'failed' end
    pending[src] = nil
    local patient, medic = e.check(src, target)
    if not patient then return false, medic end
    local s = e.sessionOf(patient, false)
    if not s or not s.treat[src] then return false, 'not_open' end
    if GetGameTimer() - p.at < p.min * 1000 then return false, 'failed' end
    result = type(result) == 'table' and result or {}
    local now = os.time()
    local list = Med.list(target)
    local w = p.wid and woundById(list, p.wid) or nil

    -- the step failed (touched the walls, missed the rhythm...): nothing is used up
    if result.ok ~= true then
        if p.action == 'extract' and w and (w.b or 0) > 0 and (w.b or 0) < 3 and (tonumber(result.touches) or 0) >= 3 then
            w.b = w.b + 1 -- pulling it out roughly made it bleed more
            Med.touch(target)
        end
        e.push(s, target, patient, src)
        return true, Med.treatView(src, s, target, patient), { failed = true }
    end

    -- still needed? (another medic may have done it meanwhile)
    local a = findAction(buildPlan(target, s), p.action, p.wid)
    if not a or a.blocked then
        return true, Med.treatView(src, s, target, patient), { notNeeded = true }
    end
    if p.choice and not takeItem(src, p.choice) then return false, 'no_item' end

    local meta = Med.meta(target, true) or {}
    if p.action == 'extract' and w then
        w.r = math.max(0, (w.r or 0) - 1)
        w.x = (w.x or 0) + 1
    elseif p.action == 'dress' and w then
        if (w.b or 0) > 0 then w.b0 = math.max(w.b0 or 0, w.b) end
        w.b = 0
        w.dr = true
        w.stop = w.stop or now
    elseif p.action == 'tourniquet' and w then
        w.tq = now
    elseif p.action == 'infuse' then
        meta.inf = meta.inf or {}
        meta.inf[#meta.inf + 1] = { k = p.choice, s = now, d = C.infusion[p.choice] or 45 }
        watch[target] = { at = now + (C.infusion[p.choice] or 45), medic = src }
    elseif p.action == 'oxygen' then
        meta.ox = true
    elseif p.action == 'med' then
        local pk = C.painkiller[p.choice] or { drop = 3, minutes = 30 }
        meta.pain = { d = pk.drop, u = now + pk.minutes * 60 }
    elseif p.action == 'cpr' then
        meta.cpr = (meta.cpr or 0) + 1
        if meta.cpr >= C.cprCycles then meta.rosc = true end
    elseif p.action == 'defib' then
        if (meta.cpr or 0) >= 1 then meta.rosc = true end
    end
    Med.touch(target)
    s.last = now

    local extra = {}
    if p.action == 'cpr' or p.action == 'defib' then extra.pulse = meta.rosc == true end
    local plan = buildPlan(target, s)
    if plan.complete then
        local ok, paid = finish(src, target, s, patient, medic)
        if ok then
            extra.stable = true
            extra.paid = paid
        end
    end
    local v = Med.treatView(src, s, target, patient)
    e.push(s, target, patient, src)
    return true, v, extra
end)

-- the plan is all done but the patient is still down / hurt (e.g. only fractures left): finish now
lib.callback.register('exti_medical:server:treatComplete', function(src, target)
    local e = api()
    local patient, medic = e.check(src, target)
    if not patient then return false, medic end
    target = tonumber(target)
    local s = e.sessionOf(patient, false)
    if not s or not s.treat[src] then return false, 'not_open' end
    local plan = buildPlan(target, s)
    if not plan.complete then return false, 'not_done' end
    -- only when there was something to do here (down, hurt, or a wound treated now): no farming
    local treated = false
    for _, w in ipairs(Med.list(target)) do
        if w.dr or (w.x or 0) > 0 or w.tq then treated = true end
    end
    if rawDeath(target) == 1 and healthOf(target) >= 100 and not treated then return false, 'healthy' end
    local ok, paid = finish(src, target, s, patient, medic)
    if not ok then return false, 'failed' end
    e.push(s, target, patient, src)
    return true, Med.treatView(src, s, target, patient), { stable = true, paid = paid }
end)

-- a bag ended: the plan changes (update the screens, maybe the patient is stable now)
CreateThread(function()
    while true do
        Wait(2000)
        local now = os.time()
        for target, wch in pairs(watch) do
            if now >= wch.at then
                watch[target] = nil
                local e = api()
                local patient = e and e.patientOf(target)
                local s = patient and e.sessionOf(patient, false)
                if s then
                    -- the last thing was the bag: the patient is stable now (if that medic is still there)
                    local medic = wch.medic
                    if s.treat[medic] and buildPlan(target, s).complete then
                        local okNear, medicPlayer = pcall(function() local pt, m = e.check(medic, target) return pt and m end)
                        if okNear and medicPlayer then finish(medic, target, s, patient, medicPlayer) end
                    end
                    e.push(s, target, patient)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
