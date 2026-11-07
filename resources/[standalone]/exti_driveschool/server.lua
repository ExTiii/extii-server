-- =====================================================================
-- EX_Tii Driving School (server): the licences in the record, the money, the theory marking, the
-- practical test result, the school vehicles. The game only drives; the server decides.
-- =====================================================================

local RES = GetCurrentResourceName()
local SPOT_FILE = 'data/spots.json'
local ROUTE_FILE = 'data/routes.json'
local L = Config.licences

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function notify(src, kind, text)
    TriggerClientEvent('ox_lib:notify', src, { type = kind, description = text })
end

local function nameOf(p)
    local i = p.PlayerData.charinfo or {}
    return ('%s %s'):format(i.firstname or '', i.lastname or ''):match('^%s*(.-)%s*$')
end

local function v4(v) return { x = v.x, y = v.y, z = v.z, w = v.w or 0.0 } end

---------------------------------------------------------------------------
-- the schools and the routes (config + what admins moved / recorded)
---------------------------------------------------------------------------
local schools = {}      -- [id] = { id, label, ped, coords, blip, offers, spawns = { [licence] = {x,y,z,w} } }
local schoolOrder = {}
for _, s in ipairs(Config.schools) do
    local spawns = {}
    for k, v in pairs(s.spawns) do spawns[k] = v4(v) end
    schools[s.id] = { id = s.id, label = s.label, ped = s.ped, coords = v4(s.coords), blip = s.blip, offers = s.offers, spawns = spawns }
    schoolOrder[#schoolOrder + 1] = s.id
end
do
    local ok, saved = pcall(json.decode, LoadResourceFile(RES, SPOT_FILE) or '')
    if ok and type(saved) == 'table' then
        for id, s in pairs(saved) do
            if schools[id] then
                if type(s.coords) == 'table' and tonumber(s.coords.x) then schools[id].coords = v4(s.coords) end
                for k, v in pairs(type(s.spawns) == 'table' and s.spawns or {}) do
                    if L[k] and type(v) == 'table' and tonumber(v.x) then schools[id].spawns[k] = v4(v) end
                end
            end
        end
    end
end

local routes = {}       -- [licence] = { {x,y,z}... } recorded by admins (wins over config)
do
    local ok, saved = pcall(json.decode, LoadResourceFile(RES, ROUTE_FILE) or '')
    if ok and type(saved) == 'table' then
        for k, list in pairs(saved) do
            if L[k] and type(list) == 'table' and #list > 0 then
                routes[k] = {}
                for i, p in ipairs(list) do routes[k][i] = { x = p.x, y = p.y, z = p.z } end
            end
        end
    end
end

local function publish()
    local lic = {}
    for k, v in pairs(L) do
        local route = routes[k]
        if not route then
            route = {}
            for i, p in ipairs(v.test.route) do route[i] = { x = p.x, y = p.y, z = p.z } end
        end
        lic[k] = { label = v.label, short = v.short, price = v.price, requires = v.requires, order = v.order, theory = v.theory,
                   test = { speedLimit = v.test.speedLimit, speedGrace = v.test.speedGrace, speedInstant = v.test.speedInstant, maxFaults = v.test.maxFaults,
                            maxDamage = v.test.maxDamage, checkpointRadius = v.test.checkpointRadius, timeLimitMinutes = v.test.timeLimitMinutes,
                            snapToRoad = v.test.snapToRoad == true, landing = v.test.landing == true, route = route } }
    end
    GlobalState.exti_driveschool = { schools = schools, order = schoolOrder, licences = lic }
end
publish()

local function saveSpots()
    local out = {}
    for id, s in pairs(schools) do out[id] = { coords = s.coords, spawns = s.spawns } end
    SaveResourceFile(RES, SPOT_FILE, json.encode(out, { indent = true }), -1)
end

lib.addCommand('driveschoolspot', {
    help = 'نقل مدرّب مدرسة القيادة أو مكان مركبتها إلى مكانك (للإدارة)',
    params = {
        { name = 'school', type = 'string', help = 'city / marina / heli' },
        { name = 'what', type = 'string', help = 'ped أو اسم الرخصة: car / truck / boat / heli، أو reset' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local s = schools[args.school]
    if not s then return notify(source, 'error', 'المدارس: ' .. table.concat(schoolOrder, ' / ')) end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    -- in a vehicle: the vehicle's place (the boat spot is on the water)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then c, h = GetEntityCoords(veh), GetEntityHeading(veh) end
    if args.what == 'ped' then
        s.coords = { x = c.x, y = c.y, z = c.z, w = h }
    elseif args.what == 'reset' then
        for _, cfg in ipairs(Config.schools) do
            if cfg.id == s.id then
                s.coords = v4(cfg.coords)
                s.spawns = {}
                for k, v in pairs(cfg.spawns) do s.spawns[k] = v4(v) end
            end
        end
    elseif L[args.what] then
        s.spawns[args.what] = { x = c.x, y = c.y, z = c.z, w = h }
    else
        return notify(source, 'error', '/driveschoolspot <school> ped | car | truck | boat | heli | reset')
    end
    saveSpots()
    publish()
    notify(source, 'success', 'حُفظ المكان')
end)

lib.addCommand('dsroute', {
    help = 'تسجيل مسار الاختبار العملي: add يضيف نقطة عند مكانك، undo يحذف الأخيرة، clear يعيد مسار الإعدادات، show يعرض (للإدارة)',
    params = {
        { name = 'licence', type = 'string', help = 'car / truck / boat / heli' },
        { name = 'what', type = 'string', help = 'add / undo / clear / show' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local k = args.licence
    if not L[k] then return notify(source, 'error', 'الرخص: car / truck / boat / heli') end
    local ped = GetPlayerPed(source)
    if args.what == 'add' then
        local veh = GetVehiclePedIsIn(ped, false)
        local c = GetEntityCoords(veh ~= 0 and veh or ped)
        routes[k] = routes[k] or {}
        routes[k][#routes[k] + 1] = { x = c.x, y = c.y, z = c.z }
        notify(source, 'success', ('نقطة %d حُفظت لمسار %s'):format(#routes[k], L[k].short))
    elseif args.what == 'undo' then
        if routes[k] and #routes[k] > 0 then routes[k][#routes[k]] = nil end
        if routes[k] and #routes[k] == 0 then routes[k] = nil end
        notify(source, 'inform', routes[k] and ('باقي %d نقاط'):format(#routes[k]) or 'عاد مسار الإعدادات')
    elseif args.what == 'clear' then
        routes[k] = nil
        notify(source, 'inform', 'عاد مسار الإعدادات')
    elseif args.what == 'show' then
        notify(source, 'inform', ('مسار %s: %d نقاط (%s)'):format(L[k].short, #(routes[k] or L[k].test.route), routes[k] and 'مسجّل' or 'من الإعدادات'))
        return
    else
        return notify(source, 'error', '/dsroute <licence> add | undo | clear | show')
    end
    SaveResourceFile(RES, ROUTE_FILE, json.encode(routes, { indent = true }), -1)
    publish()
end)

local function nearSchool(src, schoolId)
    local s = schools[schoolId]
    local ped = GetPlayerPed(src)
    return s ~= nil and ped ~= 0 and #(GetEntityCoords(ped) - vec3(s.coords.x, s.coords.y, s.coords.z)) < 6.0
end

local function schoolOffers(s, k)
    for _, o in ipairs(s.offers) do if o == k then return true end end
    return false
end

---------------------------------------------------------------------------
-- the licences in the record
-- metadata.licences[metaKey] = true/false ; metadata.driveschool[k] = { passed, at, suspended }
---------------------------------------------------------------------------
local function licences(p)
    local l = p.PlayerData.metadata.licences
    if type(l) ~= 'table' then l = { id = true, driver = false, weapon = false } end
    return l
end

local function school(p)
    local ds = p.PlayerData.metadata.driveschool
    if type(ds) ~= 'table' then ds = {} end
    -- the first version kept only the car: { passed = true/false }
    if ds.passed ~= nil and ds.car == nil then
        ds = { car = { passed = ds.passed == true, at = ds.at, suspended = ds.suspended } }
    end
    return ds
end

local function has(p, k) return licences(p)[L[k].metaKey] == true end

local function setLicence(p, k, on)
    local l = licences(p)
    l[L[k].metaKey] = on and true or false
    p.Functions.SetMetaData('licences', l)
end

-- every licence has its line in the record; returns the table (saved when something was missing)
local function markNew(p)
    local ds = school(p)
    local changed = ds ~= p.PlayerData.metadata.driveschool
    for k in pairs(L) do
        if type(ds[k]) ~= 'table' then ds[k] = { passed = false } changed = true end
    end
    if changed then p.Functions.SetMetaData('driveschool', ds) end
    return ds
end

-- nobody starts with one (qbx_core's default says yes for the car; this takes it back from every
-- character once, at the first start after the school arrived)
MySQL.ready(function()
    if GetResourceKvpInt('licences_wiped') ~= 1 then
        local rows = MySQL.query.await('SELECT `citizenid`, `metadata` FROM `players`') or {}
        local n = 0
        for _, r in ipairs(rows) do
            local ok, meta = pcall(json.decode, r.metadata or '')
            if ok and type(meta) == 'table' then
                meta.licences = type(meta.licences) == 'table' and meta.licences or {}
                if meta.licences.driver ~= false then
                    meta.licences.driver = false
                    meta.driveschool = type(meta.driveschool) == 'table' and meta.driveschool or {}
                    MySQL.update.await('UPDATE `players` SET `metadata` = ? WHERE `citizenid` = ?', { json.encode(meta), r.citizenid })
                    n = n + 1
                end
            end
        end
        for _, s in ipairs(GetPlayers()) do
            local p = getPlayer(tonumber(s))
            if p then setLicence(p, 'car', false) markNew(p) end
        end
        SetResourceKvpInt('licences_wiped', 1)
        lib.print.info(('[driveschool] driving licences taken back from %d characters: the school is open'):format(n))
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local meta = player.PlayerData.metadata or {}
    if type(meta.driveschool) ~= 'table' then
        -- a brand new character: no licence until the school
        for k in pairs(L) do setLicence(player, k, false) end
    end
    markNew(player)
end)

---------------------------------------------------------------------------
-- the test
---------------------------------------------------------------------------
local tests = {}      -- [src] = { licence, school, stage = 'theory'|'drive', questions, started, netId, veh }
local lastFail = {}   -- [src] = { [licence] = os.time() }

local function waitLeft(src, k)
    local t = lastFail[src] and lastFail[src][k]
    return t and math.max(0, t + Config.retryMinutes * 60 - os.time()) or 0
end
local function failed(src, k)
    lastFail[src] = lastFail[src] or {}
    lastFail[src][k] = os.time()
end

-- the questions go out with their answers shuffled; the right position is kept here
local function pickQuestions(k)
    local all = Config.questions[k] or {}
    local pool = {}
    for i = 1, #all do pool[i] = i end
    for i = #pool, 2, -1 do local j = math.random(i) pool[i], pool[j] = pool[j], pool[i] end
    local out = {}
    for i = 1, math.min(L[k].theory.count, #pool) do
        local q = all[pool[i]]
        local order = { 1, 2, 3, 4 }
        for j = #order, 2, -1 do local m = math.random(j) order[j], order[m] = order[m], order[j] end
        local answers, right = {}, 1
        for pos, from in ipairs(order) do
            answers[pos] = q[2][from]
            if from == q[3] then right = pos end
        end
        out[i] = { id = pool[i], text = q[1], answers = answers, right = right }
    end
    return out
end

local function forPage(questions)
    local out = {}
    for i, q in ipairs(questions) do out[i] = { id = q.id, text = q.text, answers = q.answers } end
    return out
end

-- where the player stands with one licence (for the screen)
local function status(p, src, k)
    local ds = school(p)
    local me = type(ds[k]) == 'table' and ds[k] or {}
    local t = L[k].test
    local st = { key = k, label = L[k].label, short = L[k].short, price = L[k].price, order = L[k].order,
                 requires = L[k].requires and L[L[k].requires].short or nil, theory = L[k].theory,
                 test = { limit = t.speedLimit, faults = t.maxFaults, minutes = t.timeLimitMinutes, landing = t.landing == true },
                 has = has(p, k), suspended = me.suspended == true, wait = waitLeft(src, k), locked = false }
    if L[k].requires and not has(p, L[k].requires) then st.locked = true end
    return st
end

lib.callback.register('exti_driveschool:server:open', function(source, schoolId)
    local p = getPlayer(source)
    if not p or not nearSchool(source, schoolId) then return false, 'too_far' end
    local s = schools[schoolId]
    local list = {}
    for _, k in ipairs(s.offers) do list[#list + 1] = status(p, source, k) end
    table.sort(list, function(a, b) return a.order < b.order end)
    return { school = s.label, name = nameOf(p), cash = math.floor(p.PlayerData.money.cash or 0), bank = math.floor(p.PlayerData.money.bank or 0),
             licences = list, busy = tests[source] ~= nil }
end)

-- pay and get the questions
lib.callback.register('exti_driveschool:server:start', function(source, schoolId, k, account)
    local p = getPlayer(source)
    if not p or not nearSchool(source, schoolId) then return false, 'too_far' end
    local s = schools[schoolId]
    if not L[k] or not schoolOffers(s, k) then return false, 'failed' end
    if tests[source] then return false, 'busy' end
    if has(p, k) then return false, 'has' end
    local ds = school(p)
    if type(ds[k]) == 'table' and ds[k].suspended then return false, 'suspended' end
    if L[k].requires and not has(p, L[k].requires) then return false, 'locked' end
    if waitLeft(source, k) > 0 then return false, 'wait' end
    account = account == 'bank' and 'bank' or 'cash'
    if L[k].price > 0 and not p.Functions.RemoveMoney(account, L[k].price, 'driveschool ' .. k) then return false, 'no_money' end
    tests[source] = { licence = k, school = schoolId, stage = 'theory', questions = pickQuestions(k), started = os.time(), account = account }
    lib.print.info(('[driveschool] %s (%s) started the %s test ($%d from %s)'):format(nameOf(p), p.PlayerData.citizenid, k, L[k].price, account))
    return { questions = forPage(tests[source].questions), seconds = L[k].theory.seconds, licence = k }
end)

-- the theory answers: the chosen position per question
lib.callback.register('exti_driveschool:server:theory', function(source, answers)
    local t = tests[source]
    local p = getPlayer(source)
    if not t or t.stage ~= 'theory' or not p then return false, 'failed' end
    local k = t.licence
    if os.time() - t.started > L[k].theory.seconds + 15 then
        tests[source] = nil
        failed(source, k)
        return false, 'timeout'
    end
    local right = 0
    for i, q in ipairs(t.questions) do
        local a = type(answers) == 'table' and tonumber(answers[i]) or nil
        if a and q.right == a then right = right + 1 end
    end
    if right < L[k].theory.pass then
        tests[source] = nil
        failed(source, k)
        lib.print.info(('[driveschool] %s failed the %s theory: %d/%d'):format(nameOf(p), k, right, #t.questions))
        return { passed = false, right = right, total = #t.questions, need = L[k].theory.pass }
    end
    t.stage = 'drive'
    t.started = os.time()
    return { passed = true, right = right, total = #t.questions, need = L[k].theory.pass }
end)

-- the school vehicle (the game asks once the theory is passed)
lib.callback.register('exti_driveschool:server:car', function(source)
    local t = tests[source]
    if not t or t.stage ~= 'drive' then return false, 'failed' end
    if t.netId then return t.netId, t.licence end
    local k = t.licence
    local spot = schools[t.school].spawns[k]
    local ped = GetPlayerPed(source)
    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = L[k].test.vehicle.model, spawnSource = vec4(spot.x, spot.y, spot.z, spot.w), warp = ped ~= 0 and ped or nil })
    if not ok or not netId then
        lib.print.error(('[driveschool] %s vehicle failed: %s'):format(k, tostring(netId)))
        -- no vehicle = no test: the money back, and he can start again (no wait, he did nothing wrong)
        tests[source] = nil
        local p = getPlayer(source)
        if p and L[k].price > 0 then pcall(function() p.Functions.AddMoney(t.account or 'cash', L[k].price, 'driveschool refund') end) end
        return false, 'nocar'
    end
    Entity(veh).state:set('exti_job', 'driveschool', true) -- (never chopped by the Chop Shop)
    pcall(function() SetVehicleNumberPlateText(veh, L[k].test.vehicle.plate or 'SCHOOL') end)
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(source, veh, true) end)
    pcall(function() exports.qbx_vehiclekeys:SetLockState(veh, 'unlock') end)
    t.netId, t.veh = netId, veh
    return netId, k
end)

local function removeVehicle(t)
    if t and t.veh and DoesEntityExist(t.veh) then DeleteEntity(t.veh) end
end

-- the game reports the practical result (it checked the route, the speed and the damage; the
-- server checks that the test is real and the time)
lib.callback.register('exti_driveschool:server:drive', function(source, passed, why, stats)
    local t = tests[source]
    local p = getPlayer(source)
    if not t or t.stage ~= 'drive' or not p then return false, 'failed' end
    local k = t.licence
    tests[source] = nil
    local tooLong = os.time() - t.started > L[k].test.timeLimitMinutes * 60 + 30
    removeVehicle(t)
    if passed and not tooLong then
        setLicence(p, k, true)
        local ds = markNew(p)
        ds[k] = { passed = true, at = os.time() }
        p.Functions.SetMetaData('driveschool', ds)
        pcall(function() exports.qbx_idcard:CreateMetaLicense(source, L[k].item) end)
        lib.print.info(('[driveschool] %s (%s) PASSED %s'):format(nameOf(p), p.PlayerData.citizenid, k))
        return { passed = true, licence = k }
    end
    failed(source, k)
    lib.print.info(('[driveschool] %s failed the %s drive: %s'):format(nameOf(p), k, tooLong and 'time' or tostring(why)))
    return { passed = false, why = tooLong and 'time' or why, licence = k }
end)

-- admins: give a licence without the test (the same as passing it: the record, the card, logged)
--   /givelicence [player id] [car / truck / boat / heli]
lib.addCommand('givelicence', {
    help = 'إعطاء رخصة بدون اختبار (للإدارة): car / truck / boat / heli',
    params = {
        { name = 'id', type = 'playerId', help = 'رقم اللاعب' },
        { name = 'licence', type = 'string', help = 'car / truck / boat / heli', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local k = args.licence or 'car'
    if not L[k] then return notify(source, 'error', 'الرخص: car / truck / boat / heli') end
    local p = getPlayer(args.id)
    if not p then return notify(source, 'error', 'اللاعب غير موجود') end
    setLicence(p, k, true)
    local ds = markNew(p)
    ds[k] = { passed = true, at = os.time() }
    p.Functions.SetMetaData('driveschool', ds)
    pcall(function() exports.qbx_idcard:CreateMetaLicense(args.id, L[k].item) end)
    notify(args.id, 'success', ('حصلت على %s'):format(L[k].label))
    if source ~= args.id then notify(source, 'success', ('أُعطيت %s لـ %s'):format(L[k].label, nameOf(p))) end
    lib.logger(source, 'driveschool', ('admin gave %s the %s licence'):format(p.PlayerData.citizenid, k))
    lib.print.info(('[driveschool] admin %s gave %s (%s) the %s licence'):format(source, nameOf(p), p.PlayerData.citizenid, k))
end)

-- gave up / left
RegisterNetEvent('exti_driveschool:server:cancel', function()
    local src = source
    local t = tests[src]
    if not t then return end
    tests[src] = nil
    removeVehicle(t)
    failed(src, t.licence)
end)

AddEventHandler('playerDropped', function()
    local src = source
    removeVehicle(tests[src])
    tests[src], lastFail[src] = nil, nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for _, t in pairs(tests) do removeVehicle(t) end
end)

---------------------------------------------------------------------------
-- for the police (exti_police): suspend / restore, and a look
---------------------------------------------------------------------------
local function normKey(k)
    if k == nil then return 'car' end   -- the first version had only the car
    return L[k] and k or nil
end

--- SetLicence(src, licence, on) -> ok, why  (old form SetLicence(src, on) = the car)
--- on = true only works for a licence passed at the school (why = 'not_passed')
--- seconds (optional): how long the police take it (it comes back by itself after that)
exports('SetLicence', function(src, k, on, seconds)
    if type(k) == 'boolean' then on, k, seconds = k, 'car', on end
    k = normKey(k)
    local p = getPlayer(src)
    if not p or not k then return false end
    local ds = markNew(p)
    -- give back only what was earned at the school (and taken by the police): never a free licence
    if on and not (type(ds[k]) == 'table' and ds[k].passed == true) then return false, 'not_passed' end
    setLicence(p, k, on)
    ds[k].suspended = (not on) and ds[k].passed == true or nil
    ds[k].suspendedUntil = (not on) and tonumber(seconds) and (os.time() + math.floor(seconds)) or nil
    p.Functions.SetMetaData('driveschool', ds)
    if on then
        notify(src, 'success', ('أعادت لك الشرطة %s'):format(L[k].label))
    elseif ds[k].suspendedUntil then
        local h = math.floor(seconds / 3600 + 0.5)
        notify(src, 'error', ('سحبت منك الشرطة %s لمدة %s، وتعود إليك تلقائيًا بعدها'):format(L[k].label, h == 1 and 'ساعة واحدة' or (h == 24 and '24 ساعة' or (h .. ' ساعات'))))
    else
        notify(src, 'error', ('سحبت منك الشرطة %s'):format(L[k].label))
    end
    return true
end)

--- SetLicenceOffline(citizenid, licence, on) -> ok, why (the player may be away)
exports('SetLicenceOffline', function(cid, k, on, seconds)
    if type(k) == 'boolean' then on, k, seconds = k, 'car', on end
    k = normKey(k)
    if not k then return false end
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online then return exports[RES]:SetLicence(online.PlayerData.source, k, on, seconds) end
    local r = MySQL.single.await('SELECT `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not r then return false end
    local ok, meta = pcall(json.decode, r.metadata or '')
    if not ok or type(meta) ~= 'table' then return false end
    local ds = type(meta.driveschool) == 'table' and meta.driveschool or {}
    if ds.passed ~= nil and ds.car == nil then ds = { car = { passed = ds.passed == true, at = ds.at, suspended = ds.suspended } } end
    ds[k] = type(ds[k]) == 'table' and ds[k] or { passed = false }
    -- give back only what was earned at the school (and taken by the police): never a free licence
    if on and ds[k].passed ~= true then return false, 'not_passed' end
    meta.licences = type(meta.licences) == 'table' and meta.licences or {}
    meta.licences[L[k].metaKey] = on and true or false
    ds[k].suspended = (not on) and ds[k].passed == true or nil
    ds[k].suspendedUntil = (not on) and tonumber(seconds) and (os.time() + math.floor(seconds)) or nil
    meta.driveschool = ds
    MySQL.update.await('UPDATE `players` SET `metadata` = ? WHERE `citizenid` = ?', { json.encode(meta), cid })
    return true
end)

--- HasLicence(src, licence) -> bool
exports('HasLicence', function(src, k)
    k = normKey(k)
    local p = getPlayer(src)
    return p ~= nil and k ~= nil and has(p, k)
end)

--- Licences() -> { key = { label, short, metaKey, item, order } } for other scripts (the police tablet)
exports('Licences', function()
    local out = {}
    for k, v in pairs(L) do out[k] = { label = v.label, short = v.short, metaKey = v.metaKey, item = v.item, order = v.order } end
    return out
end)

-- EX_Tii (Moe): a licence the police took for a time comes back by itself (checked every minute for
-- everyone in the city; someone who was away gets it back a minute after coming in)
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for _, sid in ipairs(GetPlayers()) do
            local src = tonumber(sid)
            local p = getPlayer(src)
            local ds = p and p.PlayerData.metadata and p.PlayerData.metadata.driveschool
            if type(ds) == 'table' then
                for k, v in pairs(ds) do
                    if L[k] and type(v) == 'table' and v.suspended and tonumber(v.suspendedUntil) and v.suspendedUntil <= now then
                        local ok = exports[RES]:SetLicence(src, k, true)
                        if ok then lib.logger(src, 'driveschool', ('licence %s back after the police suspension'):format(k)) end
                    end
                end
            end
        end
    end
end)

-- EX_Tii admin panel (F1): give a licence like passing the test, or take it away (exti_admin checks the rights)
exports('AdminGive', function(src, k, on)
    k = normKey(k)
    local p = getPlayer(src)
    if not p or not k then error('bad licence') end
    local ds = markNew(p)
    if on then
        setLicence(p, k, true)
        ds[k] = { passed = true, at = os.time() }
        p.Functions.SetMetaData('driveschool', ds)
        pcall(function() exports.qbx_idcard:CreateMetaLicense(src, L[k].item) end)
        notify(src, 'success', ('حصلت على %s'):format(L[k].label))
    else
        setLicence(p, k, false)
        ds[k] = { passed = false }
        p.Functions.SetMetaData('driveschool', ds)
        notify(src, 'error', ('سحبت الإدارة %s'):format(L[k].label))
    end
    return true
end)
