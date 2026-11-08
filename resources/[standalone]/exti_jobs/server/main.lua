-- =====================================================================
-- EX_Tii jobs (server)
-- Everything that gives money is decided here, never in the game:
--   * the job center: take a job / leave it
--   * the HQs: start a shift (vehicle + deposit), end it (deposit back + return bonus)
--   * rounds: the server picks the stops, checks you really are there, then pays
--   * levels: every task done raises your level in that job (+10% pay per level)
-- =====================================================================
local config = require 'config.shared'
local stops = require 'config.stops'
local spots = require 'config.spots'

-- EX_Tii: places moved in game with /jobspots (data/spots.json), shared with every game
local SPOTS_FILE = 'data/spots.json'
local spotOverrides = {}
do
    local raw = LoadResourceFile(GetCurrentResourceName(), SPOTS_FILE)
    local ok, data = pcall(json.decode, raw or '')
    spotOverrides = ok and type(data) == 'table' and data or {}
    -- a hand-edited file: only tables per job are kept
    for k, v in pairs(spotOverrides) do
        if type(k) ~= 'string' or type(v) ~= 'table' or not (config.jobs[k] and config.jobs[k].chain) then spotOverrides[k] = nil end
    end
end
spots.apply(config, spotOverrides)
GlobalState['exti_jobs:spots'] = spotOverrides

local shifts = {}      -- [source] = shift
local busy = {}        -- [source] = true while a request is running
local lastUsed = {}    -- [vehicle] = os.time() the car last had a driver (abandoned cars for the tow job)
local towTaken = {}    -- [tow spot index] = source that has it as a mission

local JOB_CENTERS = { vec3(-232.44, -915.57, 32.30) }

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function notify(src, text, kind, duration)
    exports.qbx_core:Notify(src, text, kind or 'inform', duration)
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped), ped
end

local function near(src, coords, dist)
    local here = pedCoords(src)
    return here and #(here - coords) <= dist
end

local function nearJobCenter(src)
    for i = 1, #JOB_CENTERS do
        if near(src, JOB_CENTERS[i], 12.0) then return true end
    end
    return false
end

local function flat(a, b)
    return #(vec2(a.x, a.y) - vec2(b.x, b.y))
end

local function round(n) return math.floor(n + 0.5) end

local function jobName(player)
    return player and player.PlayerData.job and player.PlayerData.job.name or 'unemployed'
end

local function hasLicence(player)
    local lic = player.PlayerData.metadata and player.PlayerData.metadata.licences
    return lic and lic[config.licence] == true
end

---------------------------------------------------------------------------
-- levels (kept on the character: metadata.jobskill = { tow = 12, garbage = 40, ... })
---------------------------------------------------------------------------
local function tasksDone(player, job)
    local skill = player.PlayerData.metadata and player.PlayerData.metadata.jobskill
    return type(skill) == 'table' and tonumber(skill[job]) or 0
end

local function levelInfo(job, tasks)
    local steps = config.jobs[job].levelSteps
    local level = 1
    for i = #steps, 1, -1 do
        if tasks >= steps[i] then level = i break end
    end
    return {
        level = level,
        max = #steps,
        name = config.levelNames[level],
        tasks = tasks,
        from = steps[level],
        nextAt = steps[level + 1],
        bonus = config.levelBonus[level] or 0.0,
        nextBonus = config.levelBonus[level + 1],
    }
end

local function addTask(player, job)
    local skill = player.PlayerData.metadata.jobskill
    skill = type(skill) == 'table' and skill or {}
    local before = levelInfo(job, tonumber(skill[job]) or 0)
    skill[job] = (tonumber(skill[job]) or 0) + 1
    player.Functions.SetMetaData('jobskill', skill)
    local after = levelInfo(job, skill[job])
    if after.level > before.level then
        notify(player.PlayerData.source,
            ('ترقية! وصلت إلى الرتبة %d (%s) في وظيفة %s، وأجرك الآن أعلى بنسبة %d%%'):format(
                after.level, after.name, config.jobs[job].label, round(after.bonus * 100)), 'success', 9000)
    end
end

-- pay a task: level bonus included, into the bank, counted in the shift
local function payTask(src, shift, base, reason, counts, items)
    local player = getPlayer(src)
    if not player then return 0 end
    local info = levelInfo(shift.job, tasksDone(player, shift.job))
    local amount = round(base * (1.0 + info.bonus))
    player.Functions.AddMoney('bank', amount, reason)
    -- the player level (exti_level): XP for the work itself. The level jobs give a fixed XP per piece sold
    -- (job.xpPerItem: Moe's ladder, see config); the starter jobs a share of the base pay (job.xpRate)
    local job = config.jobs[shift.job]
    local xp
    if job.xpPerItem and items then xp = round(items * job.xpPerItem)
    else xp = round(base * (job.xpRate or 0.094)) end
    if xp > 0 and GetResourceState('exti_level') == 'started' then
        pcall(function() exports.exti_level:AddXP(src, xp, job.xpText or job.label) end)
    end
    shift.earned = shift.earned + amount
    -- (level jobs: only a real run counts toward the rank: a sale of at least half a load)
    if counts ~= false then
        shift.tasks = shift.tasks + 1
        addTask(player, shift.job)
    end
    notify(src, ('+%s$ في حسابك البنكي'):format(amount), 'success', 3500)
    return amount
end

---------------------------------------------------------------------------
-- the delivery job is new: make sure the city knows it (also written in qbx_core/shared/jobs.lua)
---------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)
    if not exports.qbx_core:GetJob('delivery') then
        exports.qbx_core:CreateJob('delivery', {
            label = 'التوصيل',
            defaultDuty = true,
            offDutyPay = false,
            grades = { [0] = { name = 'عامل توصيل', payment = 50 } },
        })
    end
end)

---------------------------------------------------------------------------
-- choosing stops (never too far: each stop is close to the one before)
---------------------------------------------------------------------------
local function pickChain(pool, from, count, firstMin, firstMax, legMax, legMin)
    local used, list = {}, {}
    local function pick(pos, minD, maxD)
        local fits, all = {}, {}
        for i = 1, #pool do
            if not used[i] then
                local d = flat(pool[i].coords, pos)
                all[#all + 1] = { i = i, d = d }
                if d >= minD and d <= maxD then fits[#fits + 1] = { i = i, d = d } end
            end
        end
        if #fits == 0 then
            table.sort(all, function(a, b) return a.d < b.d end)
            fits = { all[1] }
        else
            table.sort(fits, function(a, b) return a.d < b.d end)
        end
        if not fits[1] then return nil end
        local choice = fits[math.random(1, math.min(#fits, 3))]
        used[choice.i] = true
        return choice
    end

    local first = pick(from, firstMin, firstMax)
    if not first then return list end
    list[1] = { i = first.i, leg = first.d }
    local pos = pool[first.i].coords
    while #list < count do
        local nextOne = pick(pos, legMin or 60.0, legMax)
        if not nextOne then break end
        list[#list + 1] = { i = nextOne.i, leg = nextOne.d }
        pos = pool[nextOne.i].coords
    end
    return list
end

local function garbageRoute(from)
    local job = config.jobs.garbage
    local pool = {}
    for i = 1, #stops.garbage do pool[i] = { coords = stops.garbage[i].stand } end
    local chain = pickChain(pool, from, job.perRound, 250.0, 1200.0, 600.0, 150.0)
    local route = {}
    for n = 1, #chain do
        local s = stops.garbage[chain[n].i]
        route[n] = { coords = s.stand, dumpster = s.dumpster, label = s.label, bags = math.random(job.bags[1], job.bags[2]) }
    end
    return route
end

local function deliveryRoute(from)
    local job = config.jobs.delivery
    local chain = pickChain(stops.delivery, from, job.perRound, 200.0, 1600.0, 900.0)
    local route = {}
    for n = 1, #chain do
        local s = stops.delivery[chain[n].i]
        route[n] = { coords = s.coords, label = s.label, leg = chain[n].leg }
    end
    return route
end

-- the next broken-down car for a tow driver: 300 m - 1.5 km from where they are, not taken by someone else
local function nextTowSpot(src, from)
    local fits, all = {}, {}
    local last = shifts[src] and shifts[src].lastTow
    for i = 1, #stops.tow do
        if not towTaken[i] and i ~= last then
            local d = flat(stops.tow[i].coords, from)
            all[#all + 1] = { i = i, d = d }
            if d >= 300.0 and d <= 950.0 then fits[#fits + 1] = i end -- close by: a short drive there and back
        end
    end
    if #fits > 0 then return fits[math.random(1, #fits)] end
    table.sort(all, function(a, b) return a.d < b.d end)
    return all[1] and all[1].i
end

local function nearestDrop(coords)
    local best, bestDist
    for _, drop in ipairs(config.jobs.tow.drops) do
        local d = #(coords - drop.coords)
        if not bestDist or d < bestDist then best, bestDist = drop, d end
    end
    return best, bestDist
end

---------------------------------------------------------------------------
-- shifts
---------------------------------------------------------------------------
local function vehicleOf(shift)
    local veh = shift and shift.vehicle
    if veh and DoesEntityExist(veh) then return veh end
end

local function freeTow(src)
    for i, owner in pairs(towTaken) do
        if owner == src then towTaken[i] = nil end
    end
end

-- EX_Tii: the broken car of a mission carries the driver's citizen id, so a reused network id
-- can never make another vehicle count as (or be deleted as) the mission car
local function missionCarOf(shift)
    local mission = shift and shift.mission
    if not mission or not mission.netId then return nil end
    local car = NetworkGetEntityFromNetworkId(mission.netId)
    if car ~= 0 and DoesEntityExist(car) and Entity(car).state.exti_broken == shift.cid then return car end
    return nil
end

-- people in any seat, or hidden in the trunk (attached to the car)
local function anyoneIn(car)
    for seat = -1, 8 do
        if GetPedInVehicleSeat(car, seat) ~= 0 then return true end
    end
    local peds = GetAllPeds()
    for i = 1, #peds do
        if IsPedAPlayer(peds[i]) and GetEntityAttachedTo(peds[i]) == car then return true end
    end
    return false
end

local function deleteTowCar(shift)
    local car = missionCarOf(shift)
    if car then DeleteEntity(car) end
    -- an abandoned player car still on the flatbed: let it go where it is (the truck goes away)
    local load = shift.load
    if load and load.kind == 'abandoned' then
        local loaded = NetworkGetEntityFromNetworkId(load.netId)
        if loaded ~= 0 and DoesEntityExist(loaded) then
            FreezeEntityPosition(loaded, false)
        end
    end
end

-- the round as the game needs to see it
local function roundView(shift)
    local r = shift.round
    if not r then return nil end
    local view = { n = r.n, stage = r.stage, index = r.index, total = r.total }
    if r.stage == 'chain' then
        view.sold = shift.sold or 0
        return view
    end
    if shift.job == 'tow' then
        view.mission = shift.mission and { coords = shift.mission.coords, model = shift.mission.model, netId = shift.mission.netId } or nil
    else
        view.stops = r.stops
        view.bagsDone = r.bagsDone
    end
    return view
end

local function newTowMission(src, shift, from)
    freeTow(src)
    local index = nextTowSpot(src, from)
    if not index then shift.mission = nil return end
    towTaken[index] = src
    local spot = stops.tow[index]
    shift.lastTow = index
    local models = config.jobs.tow.brokenModels
    shift.mission = {
        index = index, coords = spot.coords.xyz, heading = spot.coords.w,
        model = spot.model or models[math.random(1, #models)], startedAt = os.time(),
    }
end

local function newRound(src, shift, from)
    shift.roundCount = (shift.roundCount or 0) + 1
    local job = shift.job
    if config.jobs[job] and config.jobs[job].chain then
        shift.round = { n = shift.roundCount, stage = 'chain', index = 1, total = config.jobs[job].perRound }
        return
    end
    if job == 'garbage' then
        local route = garbageRoute(from)
        shift.round = { n = shift.roundCount, stage = 'stops', stops = route, index = 1, total = #route, bagsDone = 0, lastAt = os.time(), lastPos = from }
    elseif job == 'delivery' then
        shift.round = { n = shift.roundCount, stage = 'load', stops = {}, index = 1, total = config.jobs.delivery.perRound, lastAt = os.time(), lastPos = from }
    elseif job == 'tow' then
        shift.round = { n = shift.roundCount, stage = 'stops', index = 1, total = config.jobs.tow.perRound, lastAt = os.time() }
        newTowMission(src, shift, from)
    end
end

local lastBonus = {} -- [citizenid] = os.time() of the last return bonus of a level job
local function returnBonus(shift, veh)
    local b = config.returnBonus
    local amount = math.min(b.base + b.perRound * shift.rounds, b.max)
    if shift.rounds == 0 then return 0 end -- EX_Tii: only after a whole round (no end-and-restart farming)
    -- EX_Tii level jobs: only after a real shift (at least one round's time), and once an hour
    local job = config.jobs[shift.job]
    if job and job.chain then
        if os.time() - shift.startedAt < (job.roundMinutes or 15) * 60 then return 0 end
        if lastBonus[shift.cid] and os.time() - lastBonus[shift.cid] < 3600 then return 0 end
    end
    local condition = 1.0
    if veh then
        local body = GetVehicleBodyHealth(veh)
        local engine = GetVehicleEngineHealth(veh)
        condition = math.max(0.0, math.min(1.0, ((body + engine) / 2.0) / 1000.0))
    end
    if condition < 0.5 then return 0 end
    return round(amount * condition)
end

-- end a shift without the HQ (job changed, left the city, resource restart). refund = give the deposit back
local function dropShift(src, refund)
    local shift = shifts[src]
    if not shift then return end
    shifts[src] = nil
    freeTow(src)
    local okCar, errCar = pcall(deleteTowCar, shift) -- never stop the refund / clean-up below
    if not okCar then lib.print.error('deleteTowCar: ' .. tostring(errCar)) end
    local veh = vehicleOf(shift)
    if veh then DeleteEntity(veh) end
    if refund and shift.deposit > 0 then
        local player = getPlayer(src)
        if player then
            player.Functions.AddMoney('bank', shift.deposit, 'job-deposit-refund')
            -- the character may already have been saved (logout), so save the refund now
            pcall(function() player.Functions.Save() end)
        elseif shift.cid then
            pcall(function() exports.qbx_core:AddMoney(shift.cid, 'bank', shift.deposit, 'job-deposit-refund') end)
        end
    end
    TriggerClientEvent('exti_jobs:client:shiftEnded', src)
end

-- the work vehicle is back at the HQ (level jobs: also where it was picked up, on the road by the HQ)
local function vehicleAtHq(shift, job, veh)
    if not veh then return false end
    local pos = GetEntityCoords(veh)
    if #(pos - job.hq.returnPoint) <= job.hq.returnRadius then return true end
    return shift and shift.home ~= nil and #(pos - shift.home) <= 30.0 or false
end

-- something left in the trunk / glovebox of a work vehicle (it would go with the vehicle)
local function cargoIn(veh)
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    for _, kind in ipairs({ 'trunk', 'glove' }) do
        local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(kind .. plate) end)
        if ok and type(items) == 'table' and next(items) then return true end
    end
    return false
end

local function findSpawn(job)
    for _, spot in ipairs(job.hq.spawns) do
        local free = true
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - spot.xyz) < 4.0 then free = false break end
        end
        if free then return spot end
    end
end

---------------------------------------------------------------------------
-- the player level (exti_level)
---------------------------------------------------------------------------
local function levelOf(src)
    if GetResourceState('exti_level') ~= 'started' then return { level = 1, cur = 0, need = 1, pct = 0 } end
    local ok, info = pcall(function() return exports.exti_level:Info(src) end)
    return ok and type(info) == 'table' and info or { level = 1, cur = 0, need = 1, pct = 0 }
end

-- what each level unlocks (exti_level shows it on level up): { { level, label } }
exports('Unlocks', function()
    local list = {}
    for name, job in pairs(config.jobs) do
        if (job.minLevel or 1) > 1 then list[#list + 1] = { level = job.minLevel, label = job.label } end
    end
    for _, u in ipairs(config.upcoming or {}) do
        list[#list + 1] = { level = u.minLevel, label = u.soon and (u.label .. ' (قريبًا)') or u.label }
    end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end)

---------------------------------------------------------------------------
-- the job center tablet
---------------------------------------------------------------------------
local function jobView(player, name)
    local job = config.jobs[name]
    local info = levelInfo(name, tasksDone(player, name))
    return {
        name = name,
        label = job.label,
        company = job.company,
        icon = job.icon,
        short = job.short,
        steps = job.steps,
        extra = job.extra,
        payText = job.payText,
        hourText = job.hourText,
        deposit = job.noVehicle and 0 or config.deposit,
        bonusMax = config.returnBonus.max,
        vehicle = job.vehicle and { model = job.vehicle.model, label = job.vehicle.label } or nil,
        noVehicle = job.noVehicle == true,
        hq = { label = job.hq.label, place = job.hq.place },
        perRound = job.perRound,
        taskWord = job.taskWord,
        level = info,
        levelNames = config.levelNames,
        levelBonus = config.levelBonus,
        minLevel = job.minLevel or 1,
        roundMinutes = job.roundMinutes,
    }
end

-- EX_Tii: team jobs (EMS): joined here, run by their own script
local function teamView(name)
    local job = config.teamJobs[name]
    local ranks = {}
    local ok, data = pcall(function() return exports.qbx_core:GetJob(name) end)
    if ok and data and data.grades then
        for grade = 0, 20 do
            local g = data.grades[grade]
            if not g then break end
            ranks[#ranks + 1] = { name = g.name, payment = g.payment }
        end
    end
    return {
        name = name, team = true,
        label = job.label, company = job.company, icon = job.icon, short = job.short,
        steps = job.steps, extra = job.extra, payText = job.payText,
        vehicle = { model = job.vehicle.model, label = job.vehicle.label },
        hq = { label = job.hq.label, place = job.hq.place },
        ranks = ranks,
    }
end

lib.callback.register('exti_jobs:server:center', function(source)
    local player = getPlayer(source)
    if not player then return nil end
    local current = jobName(player)
    local jobs = {}
    for _, name in ipairs(config.order) do jobs[#jobs + 1] = jobView(player, name) end
    for _, name in ipairs(config.teamOrder or {}) do
        if config.teamJobs[name] then jobs[#jobs + 1] = teamView(name) end
    end
    -- the jobs that need a level (the ones not built yet show as "قريبًا")
    for _, u in ipairs(config.upcoming or {}) do
        jobs[#jobs + 1] = { name = u.name, label = u.label, company = u.company, icon = u.icon, short = u.short, hourText = u.hourText,
            minLevel = u.minLevel, supplies = u.supplies, soon = u.soon == true }
    end
    local jobData = player.PlayerData.job or {}
    return {
        jobs = jobs,
        me = levelOf(source),
        current = current,
        currentLabel = config.jobs[current] and config.jobs[current].label
            or config.teamJobs and config.teamJobs[current] and config.teamJobs[current].label
            or (jobData.label or 'بلا وظيفة'),
        canSwitch = config.freeJobs[current] == true,
        onShift = shifts[source] ~= nil,
        hasLicence = hasLicence(player),
        licences = player.PlayerData.metadata.licences or {},
        cash = player.PlayerData.money.cash or 0,
        name = ('%s %s'):format(player.PlayerData.charinfo.firstname or '', player.PlayerData.charinfo.lastname or ''),
    }
end)

lib.callback.register('exti_jobs:server:apply', function(source, name)
    local player = getPlayer(source)
    -- team jobs only while they are listed in the job centre (EMS is hired by its chief now)
    local listed = false
    for _, t in ipairs(config.teamOrder or {}) do if t == name then listed = true end end
    local team = listed and type(name) == 'string' and config.teamJobs and config.teamJobs[name]
    if not player or type(name) ~= 'string' or not (config.jobs[name] or team) then return false, 'failed' end
    if not nearJobCenter(source) then return false, 'far' end
    local current = jobName(player)
    if current == name then return false, 'same' end
    if not config.freeJobs[current] then return false, 'locked' end
    if shifts[source] then return false, 'shift' end
    if not team and not config.jobs[name].noVehicle and not hasLicence(player) then return false, 'licence' end -- EX_Tii: team jobs (and jobs without a vehicle) don't need a driver's licence
    if not team and (config.jobs[name].minLevel or 1) > levelOf(source).level then return false, 'level' end
    player.Functions.SetJob(name, 0)
    lib.logger(source, 'jobs', ('took the job %s (was %s)'):format(name, current))
    return true
end)

lib.callback.register('exti_jobs:server:resign', function(source)
    local player = getPlayer(source)
    if not player or not nearJobCenter(source) then return false, 'far' end
    local current = jobName(player)
    if not config.jobs[current] and not (config.teamJobs and config.teamJobs[current]) then return false, 'failed' end
    if shifts[source] then return false, 'shift' end
    player.Functions.SetJob('unemployed', 0)
    return true
end)

---------------------------------------------------------------------------
-- the HQ panel
---------------------------------------------------------------------------
lib.callback.register('exti_jobs:server:hq', function(source, name)
    local player = getPlayer(source)
    if not player or type(name) ~= 'string' or not config.jobs[name] then return nil end
    local job = config.jobs[name]
    local shift = shifts[source]
    local view = jobView(player, name)
    view.isMine = jobName(player) == name
    view.hasLicence = hasLicence(player)
    view.supervisor = job.hq.supervisor.name
    view.money = { cash = player.PlayerData.money.cash or 0, bank = player.PlayerData.money.bank or 0 }
    if shift and shift.job == name then
        local veh = vehicleOf(shift)
        view.shift = {
            rounds = shift.rounds,
            tasks = shift.tasks,
            earned = shift.earned,
            minutes = math.floor((os.time() - shift.startedAt) / 60),
            round = roundView(shift),
            hasVehicle = veh ~= nil,
            vehicleHere = vehicleAtHq(shift, job, veh),
            bonus = returnBonus(shift, veh),
            deposit = shift.deposit,
        }
    end
    return view
end)

-- EX_Tii: a road spot the game found next to the supervisor (level jobs without a set vehicle spot)
local function roadSpawn(job, spot)
    if type(spot) ~= 'vector4' and type(spot) ~= 'table' then return nil end
    local x, y, z, h = tonumber(spot.x), tonumber(spot.y), tonumber(spot.z), tonumber(spot.w) or 0.0
    for _, v in pairs({ x or false, y or false, z or false, h or false }) do
        if not v or v ~= v or math.abs(v) > 20000 then return nil end
    end
    local here = vec3(x, y, z)
    if not (#(here - job.hq.supervisor.coords.xyz) <= 150.0) then return nil end
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - here) < 4.0 then return nil end
    end
    return vec4(x, y, z, h)
end

lib.callback.register('exti_jobs:server:startShift', function(source, name, road)
    local player = getPlayer(source)
    if not player or busy[source] or type(name) ~= 'string' then return false, 'failed' end
    local job = config.jobs[name]
    if not job or jobName(player) ~= name then return false, 'notmine' end
    if shifts[source] then return false, 'already' end
    if not near(source, job.hq.supervisor.coords.xyz, 8.0) then return false, 'far' end
    -- EX_Tii: jobs without a vehicle (chicken): clocking in is all (the uniform is put on in the game)
    if job.noVehicle then
        local shift = { job = name, cid = player.PlayerData.citizenid, deposit = 0, rounds = 0, tasks = 0, earned = 0, startedAt = os.time() }
        shifts[source] = shift
        newRound(source, shift, job.hq.supervisor.coords.xyz)
        lib.logger(source, 'jobs', ('clocked in: %s'):format(name))
        return true, { round = roundView(shift), job = name }
    end
    if not hasLicence(player) then return false, 'licence' end

    local method = (player.PlayerData.money.cash or 0) >= config.deposit and 'cash'
        or (player.PlayerData.money.bank or 0) >= config.deposit and 'bank' or nil
    if not method then return false, 'money' end

    local spot = findSpawn(job) or (job.chain and roadSpawn(job, road))
    if not spot then return false, 'spot' end

    busy[source] = true
    if not player.Functions.RemoveMoney(method, config.deposit, 'job-vehicle-deposit') then
        busy[source] = nil
        return false, 'money'
    end
    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = job.vehicle.model, spawnSource = spot })
    busy[source] = nil
    if not ok or not netId or not veh or veh == 0 then
        player.Functions.AddMoney(method, config.deposit, 'job-vehicle-deposit-refund')
        return false, 'spawn'
    end

    -- EX_Tii: the player left (or changed job) while the vehicle was being made
    if not GetPlayerName(source) or not getPlayer(source) or jobName(getPlayer(source)) ~= name then
        DeleteEntity(veh)
        pcall(function() exports.qbx_core:AddMoney(player.PlayerData.citizenid, method, config.deposit, 'job-vehicle-deposit-refund') end)
        return false, 'spawn'
    end

    SetVehicleNumberPlateText(veh, ('%s%05d'):format(job.vehicle.plate, math.random(0, 99999)))
    Entity(veh).state:set('fuel', 100.0, true)
    Entity(veh).state:set('exti_job', name, true)
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(source, veh, true) end)
    pcall(function() exports.qbx_vehiclekeys:SetLockState(veh, 'unlock') end)

    local shift = {
        job = name,
        cid = player.PlayerData.citizenid,
        vehicle = veh,
        netId = netId,
        deposit = config.deposit,
        rounds = 0,
        tasks = 0,
        earned = 0,
        startedAt = os.time(),
        home = job.chain and spot.xyz or nil,
        lastAct = job.chain and GetGameTimer() or nil,
    }
    shifts[source] = shift
    newRound(source, shift, job.hq.returnPoint)
    lib.logger(source, 'jobs', ('started a %s shift'):format(name))
    return true, { netId = netId, round = roundView(shift), job = name }
end)

lib.callback.register('exti_jobs:server:endShift', function(source, withoutVehicle)
    local player = getPlayer(source)
    local shift = shifts[source]
    if not player or not shift then return false, 'noshift' end
    local job = config.jobs[shift.job]
    if not near(source, job.hq.supervisor.coords.xyz, 8.0) then return false, 'far' end
    if shift.load then return false, 'loaded' end

    local veh = vehicleOf(shift)
    local here = vehicleAtHq(shift, job, veh)
    if veh and not here and not withoutVehicle then return false, 'vehicle' end
    if veh and job.chain and cargoIn(veh) then return false, 'cargo' end

    local refund, bonus = 0, 0
    if here then
        bonus = returnBonus(shift, veh)
        refund = shift.deposit
    end
    shifts[source] = nil
    freeTow(source)
    deleteTowCar(shift)
    if veh then DeleteEntity(veh) end
    if refund > 0 then player.Functions.AddMoney('bank', refund, 'job-vehicle-deposit-refund') end
    if bonus > 0 then
        if job.chain then lastBonus[shift.cid] = os.time() end
        player.Functions.AddMoney('bank', bonus, 'job-return-bonus')
        shift.earned = shift.earned + bonus
    end
    lib.logger(source, 'jobs', ('ended a %s shift: %d tasks, %d$ earned, refund %d, bonus %d'):format(shift.job, shift.tasks, shift.earned, refund, bonus))
    return true, { refund = refund, bonus = bonus, earned = shift.earned, tasks = shift.tasks, rounds = shift.rounds }
end)

lib.callback.register('exti_jobs:server:isAdmin', function(source)
    return IsPlayerAceAllowed(source, 'command') or exports.qbx_core:HasPermission(source, 'admin')
end)

-- admins only (testing): jump straight to the last stop of the current round, so a round ending can be tried
lib.callback.register('exti_jobs:server:devLastStop', function(source)
    if not (IsPlayerAceAllowed(source, 'command') or exports.qbx_core:HasPermission(source, 'admin')) then return false end
    local shift = shifts[source]
    local r = shift and shift.round
    if not r or r.stage ~= 'stops' then return false end
    r.index = r.total
    r.bagsDone = 0
    r.lastAt = os.time() - 600
    lib.print.info(('devLastStop: %s jumped to stop %d/%d (%s)'):format(source, r.index, r.total, shift.job))
    return true, roundView(shift)
end)

-- the game asks again after a restart of this resource or a reconnect
lib.callback.register('exti_jobs:server:state', function(source)
    local shift = shifts[source]
    if not shift then return nil end
    return { netId = shift.netId, round = roundView(shift), job = shift.job }
end)

---------------------------------------------------------------------------
-- garbage
---------------------------------------------------------------------------
lib.callback.register('exti_jobs:server:garbageBag', function(source, index)
    local shift = shifts[source]
    if not shift or shift.job ~= 'garbage' or busy[source] then return false end
    local r = shift.round
    if not r or r.stage ~= 'stops' or index ~= r.index then return false end
    local stop = r.stops[r.index]
    local truck = vehicleOf(shift)
    if not stop or not truck then return false, 'truck' end
    local here = pedCoords(source)
    if not here then return false end
    local truckPos = GetEntityCoords(truck)
    if #(truckPos - stop.coords) > 40.0 then return false, 'truckfar' end
    if #(here - truckPos) > 9.0 then return false, 'far' end
    if #(here - stop.coords) > 30.0 then return false, 'far' end
    local now = os.time()
    if r.lastBagAt and now - r.lastBagAt < 2 then return false end
    -- EX_Tii: the first bag of a stop needs the time to drive there (like deliveries and tows)
    if r.bagsDone == 0 then
        local prev = r.index > 1 and r.stops[r.index - 1] and r.stops[r.index - 1].coords or r.lastPos
        local leg = prev and #(vec3(prev.x, prev.y, prev.z) - stop.coords) or 0.0
        if now - (r.lastAt or 0) < math.max(8, math.floor(leg / 45.0)) then return false, 'fast' end
    end
    r.lastBagAt = now
    r.bagsDone = r.bagsDone + 1

    local result = { bagsDone = r.bagsDone, bags = stop.bags }
    if r.bagsDone >= stop.bags then
        result.paid = payTask(source, shift, config.jobs.garbage.pay.perBag * stop.bags, 'garbage-stop')
        r.index = r.index + 1
        r.bagsDone = 0
        r.lastAt = now
        if r.index > r.total then
            r.stage = 'return'
            shift.rounds = shift.rounds + 1
        end
    end
    result.round = roundView(shift)
    return true, result
end)

lib.callback.register('exti_jobs:server:garbageUnload', function(source)
    local shift = shifts[source]
    if not shift or shift.job ~= 'garbage' then return false end
    local r = shift.round
    if not r or r.stage ~= 'return' then
        lib.print.warn(('garbageUnload %s: stage=%s'):format(source, r and r.stage))
        return false, 'notyet'
    end
    local hq = config.jobs.garbage.hq
    local truck = vehicleOf(shift)
    if not truck then
        lib.print.warn(('garbageUnload %s: no truck'):format(source))
        return false, 'truck'
    end
    local d = #(GetEntityCoords(truck) - hq.dock)
    if d > hq.dockRadius + 4.0 then
        lib.print.warn(('garbageUnload %s: truck %.1f m from the dock'):format(source, d))
        return false, 'far'
    end
    newRound(source, shift, hq.dock)
    return true, roundView(shift)
end)

---------------------------------------------------------------------------
-- delivery
---------------------------------------------------------------------------
lib.callback.register('exti_jobs:server:deliveryLoad', function(source)
    local shift = shifts[source]
    if not shift or shift.job ~= 'delivery' then return false end
    local r = shift.round
    if not r or r.stage ~= 'load' then
        lib.print.warn(('deliveryLoad %s: stage=%s'):format(source, r and r.stage))
        return false, 'notyet'
    end
    local hq = config.jobs.delivery.hq
    local van = vehicleOf(shift)
    if not van then
        lib.print.warn(('deliveryLoad %s: no van'):format(source))
        return false, 'truck'
    end
    local d = #(GetEntityCoords(van) - hq.dock)
    if d > hq.dockRadius + 4.0 then
        lib.print.warn(('deliveryLoad %s: van %.1f m from the dock'):format(source, d))
        return false, 'far'
    end
    local route = deliveryRoute(hq.dock)
    if #route == 0 then return false, 'failed' end
    r.stage = 'stops'
    r.stops = route
    r.total = #route
    r.index = 1
    r.lastAt = os.time()
    return true, roundView(shift)
end)

lib.callback.register('exti_jobs:server:deliveryDrop', function(source, index)
    local shift = shifts[source]
    if not shift or shift.job ~= 'delivery' then return false, 'noshift' end
    local r = shift.round
    if not r or r.stage ~= 'stops' or index ~= r.index then
        lib.print.warn(('deliveryDrop %s: stage=%s index=%s/%s'):format(source, r and r.stage, tostring(index), r and tostring(r.index)))
        return false, 'stage'
    end
    local stop = r.stops[r.index]
    local van = vehicleOf(shift)
    if not stop then return false, 'stage' end
    if not van then return false, 'truck' end
    local here = pedCoords(source)
    if not here or #(here - stop.coords) > 4.0 then
        lib.print.warn(('deliveryDrop %s: far %.1f m'):format(source, here and #(here - stop.coords) or -1))
        return false, 'far'
    end
    if #(GetEntityCoords(van) - stop.coords) > 120.0 then return false, 'truckfar' end
    local now = os.time()
    -- nobody drives faster than this between two shops (stops teleporting)
    if now - r.lastAt < math.max(8, math.floor((stop.leg or 0) / 45.0)) then return false, 'fast' end

    local pay = config.jobs.delivery.pay
    local base = pay.base + math.min((stop.leg or 0) * pay.perMeter, pay.maxDistance)
    local paid = payTask(source, shift, base, 'delivery-drop')
    r.index = r.index + 1
    r.lastAt = now
    if r.index > r.total then
        shift.rounds = shift.rounds + 1
        newRound(source, shift, stop.coords) -- next round starts with loading at the depot
    end
    return true, { paid = paid, round = roundView(shift) }
end)

---------------------------------------------------------------------------
-- tow
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local now = os.time()
        local seen = {}
        for _, vehicle in ipairs(GetAllVehicles()) do
            seen[vehicle] = true
            local used = not lastUsed[vehicle]
            if not used then
                for seat = -1, 8 do
                    if GetPedInVehicleSeat(vehicle, seat) ~= 0 then used = true break end
                end
            end
            if used then lastUsed[vehicle] = now end
        end
        for vehicle in pairs(lastUsed) do
            if not seen[vehicle] then lastUsed[vehicle] = nil end
        end
        Wait(30000)
    end
end)

local function ownedVehicleId(vehicle)
    local id = Entity(vehicle).state.vehicleid
    if not id then
        local ok, result = pcall(function()
            return exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
        end)
        id = ok and result or nil
    end
    return tonumber(id)
end

lib.callback.register('exti_jobs:server:towSpawn', function(source)
    local shift = shifts[source]
    if not shift or shift.job ~= 'tow' or busy[source] then return nil end
    local mission = shift.mission
    if not mission then return nil end
    if mission.netId then
        if missionCarOf(shift) then return mission.netId end
        mission.netId = nil -- the car is gone (police, admin, someone drove it away): make a new one
    end
    if not near(source, mission.coords, 150.0) then return nil end

    busy[source] = true
    local ok, netId, car = pcall(qbx.spawnVehicle, { model = mission.model, spawnSource = vec4(mission.coords.x, mission.coords.y, mission.coords.z, mission.heading or (math.random(0, 359) + 0.0)) })
    busy[source] = nil
    if not ok or not netId or not car or car == 0 then return nil end
    if shifts[source] ~= shift or shift.mission ~= mission then DeleteEntity(car) return nil end
    SetVehicleDoorsLocked(car, 1)
    SetVehicleNumberPlateText(car, ('BRK%05d'):format(math.random(0, 99999)))
    Entity(car).state:set('exti_broken', shift.cid, true)
    mission.netId = netId
    return netId
end)

lib.callback.register('exti_jobs:server:towCanLoad', function(source, netId)
    local shift = shifts[source]
    if not shift or shift.job ~= 'tow' or math.type(netId) ~= 'integer' then return false, 'failed' end
    if shift.load then return false, 'loaded' end
    local car = NetworkGetEntityFromNetworkId(netId)
    if car == 0 or not DoesEntityExist(car) then return false, 'gone' end
    if GetEntityModel(car) == joaat(config.jobs.tow.vehicle.model) then return false, 'truck' end
    if anyoneIn(car) then return false, 'occupied' end
    if GetEntityAttachedTo(car) ~= 0 then return false, 'occupied' end -- on another flatbed / trailer
    local truck = vehicleOf(shift)
    if not truck then return false, 'notruck' end
    if #(GetEntityCoords(truck) - GetEntityCoords(car)) > 15.0 then return false, 'truckfar' end
    if not near(source, GetEntityCoords(car), 6.0) then return false, 'far' end

    local mission = shift.mission
    if mission and mission.netId == netId then
        if missionCarOf(shift) ~= car then return false, 'gone' end
        shift.load = { netId = netId, kind = 'mission', from = mission.coords }
        return true, 'mission'
    end
    if Entity(car).state.exti_broken or Entity(car).state.exti_job then return false, 'notmission' end

    local vehicleId = ownedVehicleId(car)
    if not vehicleId then return false, 'notmission' end
    local idle = os.time() - (lastUsed[car] or os.time())
    local needed = config.jobs.tow.abandonedMinutes * 60
    if idle < needed then
        return false, 'notabandoned', math.max(1, math.ceil((needed - idle) / 60))
    end
    shift.load = { netId = netId, kind = 'abandoned', vehicleId = vehicleId, from = GetEntityCoords(car) }
    return true, 'abandoned'
end)

lib.callback.register('exti_jobs:server:towCancelLoad', function(source)
    local shift = shifts[source]
    if shift then shift.load = nil end
    return true
end)

local function towDeliver(source, netId)
    local shift = shifts[source]
    if not shift or shift.job ~= 'tow' then return false end
    local load = shift.load
    if not load or load.netId ~= netId then return false end
    local car = NetworkGetEntityFromNetworkId(netId)
    if car == 0 or not DoesEntityExist(car) then
        shift.load = nil
        return false, 'gone'
    end
    local carPos = GetEntityCoords(car)
    local drop, dist = nearestDrop(carPos)
    -- the car lands about 9.5 m behind the truck, so allow for that around the drop circle
    if not drop or dist > config.jobs.tow.dropRadius + 12.0 then return false, 'notdrop' end
    if not near(source, carPos, 40.0) then return false, 'far' end
    if anyoneIn(car) then return false, 'occupied' end

    local job = config.jobs.tow
    if load.kind == 'mission' then
        local mission = shift.mission
        if not mission or mission.netId ~= netId or missionCarOf(shift) ~= car then return false end
        local distance = flat(mission.coords, drop.coords)
        if os.time() - mission.startedAt < math.max(30, math.floor(distance / 40.0)) then return false, 'fast' end
        shift.load = nil
        DeleteEntity(car)
        local paid = payTask(source, shift, job.pay.base + math.min(distance * job.pay.perMeter, job.pay.maxDistance), 'tow-mission')
        local r = shift.round
        r.index = r.index + 1
        if r.index > r.total then
            shift.rounds = shift.rounds + 1
            newRound(source, shift, drop.coords)
        else
            newTowMission(source, shift, drop.coords)
        end
        return true, { paid = paid, round = roundView(shift) }
    end

    -- an abandoned player car -> the impound
    local vehicleId = ownedVehicleId(car)
    if not vehicleId or vehicleId ~= load.vehicleId then return false end
    local plate = GetVehicleNumberPlateText(car)
    -- impounded (state 2) and with the car's real condition, like the automatic impound
    local ok0, owned0 = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    local props = ok0 and owned0 and type(owned0.props) == 'table' and owned0.props or nil
    if props then
        local fuel = Entity(car).state.fuel
        if type(fuel) == 'number' then props.fuelLevel = math.floor(fuel + 0.5) end
        props.bodyHealth = GetVehicleBodyHealth(car)
        props.engineHealth = GetVehicleEngineHealth(car)
    end
    local saved = exports.qbx_vehicles:SaveVehicle(car, { state = 2, depotPrice = job.impoundFee, garage = drop.garage, props = props })
    if not saved then return false, 'impound' end
    shift.load = nil
    DeleteEntity(car)
    local paid = payTask(source, shift, job.abandonedPay, 'tow-impound')
    local ok, owned = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    local owner = ok and owned and owned.citizenid and exports.qbx_core:GetPlayerByCitizenId(owned.citizenid)
    if owner then
        notify(owner.PlayerData.source,
            ('سُحبت مركبتك (%s) إلى ساحة الحجز لأنها تُركت مدة طويلة. ادفع %s$ لاستلامها'):format(plate, job.impoundFee),
            'error', 12000)
    end
    lib.logger(source, 'jobs', ('impounded vehicle %s (id %s)'):format(plate, vehicleId))
    return true, { paid = paid, round = roundView(shift), abandoned = true }
end

-- EX_Tii: one delivery at a time per driver (the impound save waits on the database; without this
-- the same car could be paid many times)
lib.callback.register('exti_jobs:server:towDeliver', function(source, netId)
    if busy[source] then return false end
    busy[source] = true
    local ok, a, b = pcall(towDeliver, source, netId)
    busy[source] = nil
    if not ok then lib.print.error(('towDeliver failed for %s: %s'):format(source, a)) return false end
    return a, b
end)

---------------------------------------------------------------------------
-- EX_Tii level jobs (chicken, raisins, ...): collect -> process -> sell with real items.
-- The game only asks "I did this step here"; everything is checked here: the job, the shift, the
-- spot, the time the work takes, the items and supplies in the pockets, the buyer's limit.
---------------------------------------------------------------------------
local ox = exports.ox_inventory
local sold = {}        -- [citizenid:job] = { os.time() of every batch sold in the last hour }
local spotRest = {}    -- [citizenid:job:step:spot] = os.time() the spot gives again

local weights = {}
local function weightOf(item)
    if weights[item] then return weights[item] end
    local ok, data = pcall(function() return ox:Items(item) end)
    weights[item] = ok and type(data) == 'table' and tonumber(data.weight) or 0
    return weights[item]
end

local function countOf(src, item)
    return tonumber(ox:Search(src, 'count', item)) or 0
end

local function soldLastHour(key)
    if not sold[key] then
        local ok, data = pcall(json.decode, GetResourceKvpString('sold:' .. key) or '')
        sold[key] = ok and type(data) == 'table' and data or {}
    end
    local now, keep = os.time(), {}
    for _, t in ipairs(sold[key]) do
        if type(t) == 'number' and now - t < 3600 then keep[#keep + 1] = t end
    end
    sold[key] = keep
    return keep
end

local function saveSold(key)
    SetResourceKvp('sold:' .. key, json.encode(sold[key] or {}))
end

-- the buyer counts per person: the game licence (alt characters share it), else the character
local function sellerKey(src, shift)
    local lic = GetPlayerIdentifierByType(src, 'license')
    return (lic and lic:gsub('^license:', '') or shift.cid) .. ':' .. shift.job
end

-- every level job is a real job in the city (also written in qbx_core/shared/jobs.lua)
CreateThread(function()
    Wait(1200)
    for name, job in pairs(config.jobs) do
        if job.chain and not exports.qbx_core:GetJob(name) then
            exports.qbx_core:CreateJob(name, {
                label = job.label, defaultDuty = true, offDutyPay = false,
                grades = { [0] = { name = job.label, payment = 50 } },
            })
        end
    end
end)

local function chainAct(source, stepIndex, spotIndex)
    local shift = shifts[source]
    if not shift then return false, 'noshift' end
    local job = config.jobs[shift.job]
    local player = getPlayer(source)
    if not job or not job.chain or not player or jobName(player) ~= shift.job then return false, 'noshift' end
    if math.type(stepIndex) ~= 'integer' then return false, 'failed' end
    local step = job.chain[stepIndex]
    if not step then return false, 'failed' end

    local spot
    if step.kind == 'collect' then
        if math.type(spotIndex) ~= 'integer' then return false, 'failed' end
        spot = step.spots[spotIndex]
    else
        spot = step.ped and step.ped.xyz or step.spot -- a buyer (person) stands there instead of a circle
    end
    if not spot then return false, 'failed' end

    local here, ped = pedCoords(source)
    if not here or flat(here, spot) > 3.0 or math.abs(here.z - spot.z) > 4.0 then return false, 'far' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'far' end

    -- nobody works faster than the animation (the progress bar + the skill check)
    local nowMs = GetGameTimer()
    if shift.lastAct and nowMs - shift.lastAct < math.floor(step.time * 0.85) then return false, 'fast' end

    local cid = shift.cid
    if step.kind == 'collect' then
        local restKey = ('%s:%s:%d:%d'):format(cid, shift.job, stepIndex, spotIndex)
        local now = os.time()
        if spotRest[restKey] and spotRest[restKey] > now then return false, 'rest', spotRest[restKey] - now end
        local have = countOf(source, step.give.item)
        if have >= step.cap then return false, 'cap', step.cap end
        local n = math.min(math.random(step.give.min, step.give.max), step.cap - have)
        if not ox:CanCarryItem(source, step.give.item, n) then return false, 'full' end
        if not ox:AddItem(source, step.give.item, n) then return false, 'full' end
        spotRest[restKey] = now + step.rest
        shift.lastAct = nowMs
        return true, { got = n, item = step.give.item, rest = step.rest }
    end

    if step.kind == 'process' then
        for item, need in pairs(step.take) do
            local have = countOf(source, item)
            if have < need then return false, 'missing', item, need, have end
        end
        -- the batch must fit in the pockets before anything is taken (so nothing can ever be lost)
        local net = 0
        for item, n in pairs(step.give) do net = net + weightOf(item) * n end
        for item, n in pairs(step.take) do net = net - weightOf(item) * n end
        if net > 0 and not ox:CanCarryWeight(source, net) then return false, 'full' end
        local removed = {}
        for item, need in pairs(step.take) do
            if ox:RemoveItem(source, item, need) then
                removed[#removed + 1] = { item, need }
            else
                for _, r in ipairs(removed) do ox:AddItem(source, r[1], r[2]) end
                return false, 'missing', item, need, 0
            end
        end
        local given = {}
        for item, count in pairs(step.give) do
            if ox:AddItem(source, item, count) then
                given[#given + 1] = { item, count }
            else
                -- the pockets are full: everything goes back as it was
                for _, g in ipairs(given) do ox:RemoveItem(source, g[1], g[2]) end
                for _, r in ipairs(removed) do ox:AddItem(source, r[1], r[2]) end
                return false, 'full'
            end
        end
        shift.lastAct = nowMs
        return true, { done = true }
    end

    if step.kind == 'sell' then
        local key = sellerKey(source, shift)
        local list = soldLastHour(key)
        if #list >= step.perHour then
            local wait = math.max(1, math.ceil((3600 - (os.time() - list[1])) / 60))
            return false, 'hourcap', wait
        end
        for item, need in pairs(step.take) do
            local have = countOf(source, item)
            if have < need then return false, 'missing', item, need, have end
        end
        local taken = {}
        for item, need in pairs(step.take) do
            if ox:RemoveItem(source, item, need) then
                taken[#taken + 1] = { item, need }
            else
                for _, t in ipairs(taken) do ox:AddItem(source, t[1], t[2]) end
                return false, 'missing', item, need, 0
            end
        end
        list[#list + 1] = os.time()
        saveSold(key)
        shift.lastAct = nowMs
        local paid = payTask(source, shift, step.price, 'job-' .. shift.job)
        shift.sold = (shift.sold or 0) + 1
        if shift.sold % job.perRound == 0 then shift.rounds = shift.rounds + 1 end
        lib.logger(source, 'jobs', ('sold %s for %d$'):format(shift.job, paid))
        return true, { paid = paid, left = step.perHour - #list, round = roundView(shift) }
    end
    return false, 'failed'
end

lib.callback.register('exti_jobs:server:chainAct', function(source, stepIndex, spotIndex)
    if busy[source] then return false, 'fast' end
    busy[source] = true
    local ok, a, b, c, d, e = pcall(chainAct, source, stepIndex, spotIndex)
    busy[source] = nil
    if not ok then
        lib.print.error(('chainAct failed for %s: %s'):format(source, a))
        return false, 'failed'
    end
    return a, b, c, d, e
end)

-- the buyer's limit (shown in the game before you drive all the way)
lib.callback.register('exti_jobs:server:chainInfo', function(source)
    local shift = shifts[source]
    local job = shift and config.jobs[shift.job]
    if not job or not job.chain then return nil end
    local sellStep
    for _, st in ipairs(job.chain) do if st.kind == 'sell' then sellStep = st end end
    local list = soldLastHour(sellerKey(source, shift))
    return { sold = #list, perHour = sellStep and sellStep.perHour or 0 }
end)

---------------------------------------------------------------------------
-- EX_Tii (Moe's design, chicken): every step does ALL you carry at once with a mini game.
--   batchBegin: you are at the place with the items -> the game starts (the server remembers when)
--   batchFinish: the game is over (at least `seconds` later) -> the score decides how many survive
--   sellall: a progress bar of `seconds`, then everything is sold at once
---------------------------------------------------------------------------
local MAX_BATCH = 200   -- bag + the biggest trunk (180 kg) at 2 kg a piece, with room

-- EX_Tii (Moe): the work car. A station works on your bag AND the trunk of your own car parked next to it
-- (within 15 m, you must have its keys). The trunk inventory is loaded through ox_inventory with the car's net id.
local HELPER_RANGE = 15.0
local function helperTrunk(source, netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    local here = pedCoords(source)
    if not here or #(here - GetEntityCoords(veh)) > HELPER_RANGE then return nil end
    local okK, keys = pcall(function() return exports.qbx_vehiclekeys:HasKeys(source, veh) end)
    if not okK or not keys then return nil end
    local plate = GetVehicleNumberPlateText(veh)
    if not plate or plate == '' then return nil end
    local okI, inv = pcall(function() return ox:GetInventory({ id = 'trunk' .. plate, type = 'trunk', netid = netId }) end)
    if not okI or type(inv) ~= 'table' or not inv.id then return nil end
    return inv.id
end

-- how many of an item in the bag and in the helper trunk
local function countBoth(source, trunk, item)
    local n = tonumber(ox:Search(source, 'count', item)) or 0
    if trunk then n = n + (tonumber(ox:Search(trunk, 'count', item)) or 0) end
    return n
end

-- take `count` of an item from the bag first, then the trunk. Returns the list of what was taken (to undo), or nil
local function takeBoth(source, trunk, item, count)
    local taken = {}
    local function take(from, n)
        if n <= 0 then return true end
        if ox:RemoveItem(from, item, n) then taken[#taken + 1] = { from, n } return true end
        return false
    end
    local inBag = math.min(count, tonumber(ox:Search(source, 'count', item)) or 0)
    if not take(source, inBag) then return nil end
    local left = count - inBag
    if left > 0 then
        if not trunk or not take(trunk, left) then
            for _, t in ipairs(taken) do ox:AddItem(t[1], item, t[2]) end
            return nil
        end
    end
    return taken
end
local function undoTake(item, taken) for _, t in ipairs(taken or {}) do ox:AddItem(t[1], item, t[2]) end end

-- give `count` of an item: the trunk first (so the bag stays free to work), the rest to the bag. Returns list or nil
local function giveBoth(source, trunk, item, count)
    local given = {}
    local function give(to, n)
        if n <= 0 then return true end
        if ox:AddItem(to, item, n) then given[#given + 1] = { to, n } return true end
        return false
    end
    local toTrunk = 0
    if trunk then
        local w = weightOf(item)
        local okW, can = pcall(function() return ox:CanCarryWeight(trunk, w * count) end)
        if okW and can then toTrunk = count
        else
            -- as many as fit
            local okI, inv = pcall(function() return ox:GetInventory(trunk) end)
            if okI and type(inv) == 'table' and inv.maxWeight and inv.weight and w > 0 then
                toTrunk = math.max(0, math.min(count, math.floor((inv.maxWeight - inv.weight) / w)))
            end
        end
        if toTrunk > 0 and not give(trunk, toTrunk) then toTrunk = 0 end
    end
    local toBag = count - toTrunk
    if toBag > 0 and not give(source, toBag) then
        for _, g in ipairs(given) do ox:RemoveItem(g[1], item, g[2]) end
        return nil
    end
    return given
end
local function undoGive(item, given) for _, g in ipairs(given or {}) do ox:RemoveItem(g[1], item, g[2]) end end

local function batchStep(source, stepIndex)
    local shift = shifts[source]
    if not shift then return nil, 'noshift' end
    local job = config.jobs[shift.job]
    local player = getPlayer(source)
    if not job or not job.chain or not player or jobName(player) ~= shift.job then return nil, 'noshift' end
    if math.type(stepIndex) ~= 'integer' then return nil, 'failed' end
    local step = job.chain[stepIndex]
    if not step or (step.kind ~= 'batch' and step.kind ~= 'sellall') then return nil, 'failed' end
    local here, ped = pedCoords(source)
    local at = step.ped and step.ped.xyz or step.spot -- a buyer (person) stands there instead of a circle
    if not here or flat(here, at) > 3.0 or math.abs(here.z - at.z) > 4.0 then return nil, 'far' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return nil, 'far' end
    return shift, step, job
end

lib.callback.register('exti_jobs:server:batchBegin', function(source, stepIndex, helperNetId)
    if busy[source] then return false, 'fast' end
    local shift, step = batchStep(source, stepIndex)
    if not shift then return false, step end
    local trunk = helperTrunk(source, helperNetId)
    local have = countBoth(source, trunk, step.take)
    for item in pairs(step.takeAlso or {}) do have = have + countBoth(source, trunk, item) end   -- (metals: every kind of bar)
    if have < 1 then return false, 'missing', step.take end
    shift.pending = { step = stepIndex, count = math.min(have, MAX_BATCH), at = GetGameTimer(), token = math.random(100000, 999999), trunk = trunk }
    return true, { token = shift.pending.token, count = shift.pending.count, seconds = step.seconds, trunk = trunk ~= nil }
end)

local function batchFinish(source, token, score)
    local shift, step, job = batchStep(source, shifts[source] and shifts[source].pending and shifts[source].pending.step)
    if not shift then return false, step end
    local pending = shift.pending
    shift.pending = nil
    if not pending or pending.token ~= token then return false, 'failed' end
    -- the game (or the progress bar) really took its time
    if GetGameTimer() - pending.at < step.seconds * 1000 - 1500 then return false, 'fast' end
    if step.kind == 'sellall' and step.takeAlso then
        -- several goods, each its own price (metals: copper, iron, gold)
        local total, money, list = 0, 0, { { step.take, step.price } }
        for item, price in pairs(step.takeAlso) do list[#list + 1] = { item, price } end
        local left = pending.count
        local trunk = pending.trunk
        local takenAll = {}
        for _, it in ipairs(list) do
            local n = math.min(left, countBoth(source, trunk, it[1]))
            if n > 0 then
                local taken = takeBoth(source, trunk, it[1], n)
                if not taken then
                    for _, t in ipairs(takenAll) do undoTake(t[1], t[2]) end   -- nothing is lost
                    return false, 'missing', it[1]
                end
                takenAll[#takenAll + 1] = { it[1], taken }
                total, money, left = total + n, money + n * it[2], left - n
            end
        end
        if total < 1 then return false, 'missing', step.take end
        local run = total >= math.ceil((job.perRound or 2) / 2)
        local paid = payTask(source, shift, money, 'job-' .. shift.job, run, total)
        if run then shift.rounds = shift.rounds + 1 end
        lib.logger(source, 'jobs', ('sold %d bars for %d$'):format(total, paid))
        return true, { sold = total, paid = paid, run = run }
    end

    local trunk = pending.trunk
    local count = math.min(pending.count, countBoth(source, trunk, step.take))
    if count < 1 then return false, 'missing', step.take end

    if step.kind == 'sellall' then
        if not takeBoth(source, trunk, step.take, count) then return false, 'missing', step.take end
        local run = count >= math.ceil((job.perRound or 2) / 2)
        local paid = payTask(source, shift, count * step.price, 'job-' .. shift.job, run, count)
        if run then shift.rounds = shift.rounds + 1 end
        lib.logger(source, 'jobs', ('sold %d %s for %d$'):format(count, step.take, paid))
        return true, { sold = count, paid = paid, run = run }
    end

    score = tonumber(score) or 0
    if score ~= score then score = 0 end
    score = math.max(0.0, math.min(1.0, score))
    local got = math.floor(count * score + 0.5)
    -- what comes out: one item, or a mix (metals: mostly copper and iron, sometimes gold)
    local out = { [step.give] = got }
    if step.giveMix and got > 0 then
        out = {}
        local sum = 0
        for _, m in ipairs(step.giveMix) do sum = sum + m[2] end
        for _ = 1, got do
            local r, acc = math.random() * sum, 0
            for _, m in ipairs(step.giveMix) do
                acc = acc + m[2]
                if r <= acc then out[m[1]] = (out[m[1]] or 0) + 1; break end
            end
        end
    end
    -- (the pieces all weigh the same, so what comes out fits where what went in was; the trunk is filled first)
    local taken = takeBoth(source, trunk, step.take, count)
    if not taken then return false, 'missing', step.take end
    local added = {}
    for item, n in pairs(out) do
        if n > 0 then
            local given = giveBoth(source, trunk, item, n)
            if not given then
                for _, a in ipairs(added) do undoGive(a[1], a[2]) end
                undoTake(step.take, taken) -- nothing is lost
                return false, 'full'
            end
            added[#added + 1] = { item, given }
        end
    end
    local mix
    if step.giveMix then mix = {}; for item, n in pairs(out) do if n > 0 then mix[#mix + 1] = { item = item, n = n } end end end
    return true, { got = got, lost = count - got, mix = mix }
end

lib.callback.register('exti_jobs:server:batchFinish', function(source, token, score)
    if busy[source] then return false, 'fast' end
    busy[source] = true
    local ok, a, b, c = pcall(batchFinish, source, token, score)
    busy[source] = nil
    if not ok then
        lib.print.error(('batchFinish failed for %s: %s'):format(source, a))
        return false, 'failed'
    end
    return a, b, c
end)

-- the goods of these jobs can't be kept in a stash or dropped on the ground (only carried, in your car, or given):
-- the weight of your bag plus your car's trunk is what limits a batch
CreateThread(function()
    Wait(2000)
    local goods = {}
    for _, job in pairs(config.jobs) do
        for _, item in ipairs(job.noStore or {}) do goods[item] = true end
    end
    if not next(goods) then return end
    local ok, err = pcall(function()
        ox:registerHook('swapItems', function(payload)
            -- EX_Tii (Moe): your car is your work partner: the trunk and the glove box are allowed; stashes, the
            -- ground and containers are not (only carried, in a car, or given to a person)
            local to = payload.toType
            if payload.fromType == 'player' and to ~= 'player' and to ~= 'trunk' and to ~= 'glovebox' then
                notify(payload.source, 'لا يمكن تخزين هذه البضاعة إلا في سيارتك (الصندوق أو الدرج)', 'error', 5000)
                return false
            end
            return true
        end, { itemFilter = goods })
    end)
    if not ok then lib.print.error('swapItems hook: ' .. tostring(err)) end
end)

---------------------------------------------------------------------------
-- admins: /jobspots moves the places of the level jobs (saved in data/spots.json)
---------------------------------------------------------------------------
local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'command') or exports.qbx_core:HasPermission(src, 'admin')
end

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

lib.callback.register('exti_jobs:server:spotSave', function(source, name, what, stepId, action)
    if not isAdmin(source) then return false, 'admin' end
    local job = type(name) == 'string' and config.jobs[name]
    if not job or not job.chain then return false, 'failed' end
    local here, ped = pedCoords(source)
    if not here then return false, 'failed' end
    local h = round2(GetEntityHeading(ped))
    local p3 = { round2(here.x), round2(here.y), round2(here.z) }
    local p4 = { p3[1], p3[2], p3[3], h }

    if what ~= 'supervisor' and what ~= 'vehicle' and what ~= 'reset' and what ~= 'step' then return false, 'failed' end
    local o = type(spotOverrides[name]) == 'table' and spotOverrides[name] or {}
    spotOverrides[name] = o
    if what == 'supervisor' then
        o.supervisor = p4
    elseif what == 'vehicle' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local vp = GetEntityCoords(veh)
            o.vehicle = { round2(vp.x), round2(vp.y), round2(vp.z), round2(GetEntityHeading(veh)) }
        else
            o.vehicle = p4
        end
    elseif what == 'reset' then
        spotOverrides[name] = nil
    elseif what == 'step' then
        local step = type(stepId) == 'string' and spots.step(job, stepId)
        if not step then return false, 'failed' end
        o.steps = type(o.steps) == 'table' and o.steps or {}
        local so = type(o.steps[stepId]) == 'table' and o.steps[stepId] or {}
        o.steps[stepId] = so
        if step.kind == 'collect' then
            -- start from the spots in use (the defaults the first time)
            if type(so.spots) ~= 'table' then
                so.spots = {}
                for _, v in ipairs(step.spots) do so.spots[#so.spots + 1] = { round2(v.x), round2(v.y), round2(v.z) } end
            end
            if action == 'add' then
                if #so.spots >= 40 then return false, 'many' end
                so.spots[#so.spots + 1] = p3
            elseif action == 'remove' then
                local best, bestD
                for i, v in ipairs(so.spots) do
                    local sv = spots.v3(v)
                    local d = sv and #(sv - here) or 1e9
                    if not bestD or d < bestD then best, bestD = i, d end
                end
                if not best or bestD > 6.0 then return false, 'nospot' end
                if #so.spots <= 1 then return false, 'last' end
                table.remove(so.spots, best)
            elseif action == 'clear' then
                so.spots = { p3 }
            else
                return false, 'failed'
            end
        elseif action == 'ped' then
            so.ped = p4
        elseif action == 'noped' then
            so.ped = nil
        elseif action == 'move' then
            so.spot = p3
        else
            return false, 'failed'
        end
    else
        return false, 'failed'
    end

    SaveResourceFile(GetCurrentResourceName(), SPOTS_FILE, json.encode(spotOverrides, { indent = true }), -1)
    spots.apply(config, spotOverrides)
    GlobalState['exti_jobs:spots'] = spotOverrides
    lib.logger(source, 'jobs', ('moved %s %s %s %s'):format(name, what, tostring(stepId), tostring(action)))
    return true
end)

---------------------------------------------------------------------------
-- clean up
---------------------------------------------------------------------------
-- the job changed (left it, admin, another script): the shift ends, the deposit comes back
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    local shift = shifts[src]
    if shift and (not job or job.name ~= shift.job) then dropShift(src, true) end
end)

-- left the city or went back to the character screen: the vehicle goes; the deposit only comes back
-- when the vehicle was parked at the HQ
local function leftCity(src)
    local shift = shifts[src]
    if not shift then return end
    local veh = vehicleOf(shift)
    local job = config.jobs[shift.job]
    local atHq = vehicleAtHq(shift, job, veh)
    dropShift(src, atHq)
end

AddEventHandler('playerDropped', function()
    local src = source
    leftCity(src)
    busy[src] = nil
end)

-- (both only come from the server itself, never from a player)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) leftCity(src) end)
AddEventHandler('qbx_core:server:playerLoggedOut', function(src) if src then leftCity(src) end end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- nobody loses money because of a restart: every deposit comes back
    for src in pairs(shifts) do dropShift(src, true) end
end)
