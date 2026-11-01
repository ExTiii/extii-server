-- EX_Tii hospitals (server): everything is checked here (which hospital, how close you are,
-- waiting times). The panel only asks.

local checkups = {}     -- [source] = { hospital, startedAt } while a check-up is running
local lastCheckup = {}  -- [citizenid] = os.time() of the last report
local lastCall = {}     -- [source] = os.time() of the last "call a medic"
local lastShow = {}     -- [source] = os.time() of the last time they showed their report to someone

local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

---@return table? hospital
local function hospitalNear(src, name)
    local hospital = type(name) == 'string' and Config.hospitals[name]
    if not hospital then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - hospital.reception) > Config.reach then return end
    return hospital
end

local function emsOnDuty()
    local ok, count, list = pcall(function() return exports.qbx_core:GetDutyCountType('ems') end)
    if not ok then return 0, {} end
    return count or 0, list or {}
end

local function freeBeds(name)
    local ok, free, total = pcall(function() return exports.qbx_ambulancejob:GetFreeBeds(name) end)
    if not ok then return nil, nil end
    return free, total
end

-- 0..100 (health 100 = down, 200 = full)
local function healthPercent(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 100 end
    local health = GetEntityHealth(ped)
    return math.max(0, math.min(100, math.floor(health - 100 + 0.5)))
end

local function minutesLeft(last, cooldownMinutes)
    if not last then return 0 end
    local left = cooldownMinutes * 60 - (os.time() - last)
    return left > 0 and math.ceil(left / 60) or 0
end

--- what the reception panel shows
lib.callback.register('exti_hospital:server:info', function(source, name)
    local hospital = hospitalNear(source, name)
    local player = getPlayer(source)
    if not hospital or not player then return false end
    local ems = emsOnDuty()
    local free, total = freeBeds(name)
    local cid = player.PlayerData.citizenid
    return {
        hospital = name,
        label = hospital.label,
        health = healthPercent(source),
        ems = ems,
        beds = free,
        bedsTotal = total,
        checkupWait = minutesLeft(lastCheckup[cid], Config.checkupCooldown),
        callWait = minutesLeft(lastCall[source], Config.callCooldown),
        treatTime = Config.treatTime,
        checkupTime = Config.checkupTime,
        callCooldown = Config.callCooldown,
    }
end)

local function isDown(src)
    local state = Player(src).state['qbx_medical:deathState']
    return state ~= nil and state ~= 1
end

--- free treatment: a bed, then the doctor heals you (qbx_ambulancejob does the bed part)
lib.callback.register('exti_hospital:server:treat', function(source, name)
    if not hospitalNear(source, name) then return false, 'too_far' end
    if isDown(source) then return false, 'failed' end -- down or dead: that is the respawn ($), not the free treatment
    if healthPercent(source) >= 100 then return false, 'healthy' end
    local free = freeBeds(name)
    if free == 0 then return false, 'no_beds' end
    local ok, result = pcall(function() return exports.qbx_ambulancejob:CheckIn(source, source, name) end)
    if not ok then
        print(('^1[exti_hospital] check-in failed: %s^0'):format(tostring(result)))
        return false, 'failed'
    end
    if result == true then return true end
    return false, 'failed'
end)

--- check-up: start (the doctor examines you for a few seconds), then finish (you get the report)
lib.callback.register('exti_hospital:server:startCheckup', function(source, name)
    if not hospitalNear(source, name) then return false, 'too_far' end
    local player = getPlayer(source)
    if not player then return false, 'failed' end
    local wait = minutesLeft(lastCheckup[player.PlayerData.citizenid], Config.checkupCooldown)
    if wait > 0 then return false, 'wait', wait end
    checkups[source] = { hospital = name, startedAt = os.time() }
    return true
end)

local function resultOf(health)
    if health >= 95 then return 'سليم', 'ok', 'لا يحتاج إلى علاج' end
    if health >= 60 then return 'إصابات خفيفة', 'warn', 'يكفي الشاش الطبي أو المسكنات' end
    return 'يحتاج إلى علاج', 'bad', 'ننصح بالعلاج في المستشفى'
end

lib.callback.register('exti_hospital:server:finishCheckup', function(source)
    local run = checkups[source]
    checkups[source] = nil
    if not run then return false, 'failed' end
    -- the check-up must really have taken its time, and you must still be at the counter
    if os.time() - run.startedAt < Config.checkupTime - 1 then return false, 'failed' end
    local hospital = hospitalNear(source, run.hospital)
    if not hospital then return false, 'too_far' end
    local player = getPlayer(source)
    if not player then return false, 'failed' end

    local info = player.PlayerData.charinfo or {}
    local meta = player.PlayerData.metadata or {}
    local health = healthPercent(source)
    local result, level, advice = resultOf(health)
    local name = ('%s %s'):format(info.firstname or '', info.lastname or '')
    local report = {
        patient = name,
        birthdate = info.birthdate,
        gender = info.gender == 1 and 'أنثى' or 'ذكر',
        blood = meta.bloodtype,
        hospital = hospital.label,
        doctor = Config.doctors[math.random(#Config.doctors)],
        date = os.date('%Y/%m/%d'),
        time = os.date('%H:%M'),
        health = health,
        result = result,
        level = level,
        advice = advice,
        number = ('%d-%04d'):format(os.time() % 100000, math.random(0, 9999)),
    }
    -- what the inventory shows when you hover the report
    report.description = ('المريض: %s\nالنتيجة: %s (%d%%)\n%s، %s'):format(name, result, health, hospital.label, report.date)

    local okCarry, canCarry = pcall(function() return exports.ox_inventory:CanCarryItem(source, 'medreport', 1, report) end)
    if okCarry and canCarry == false then return false, 'cant_carry' end
    local added = exports.ox_inventory:AddItem(source, 'medreport', 1, report)
    if not added then return false, 'cant_carry' end
    lastCheckup[player.PlayerData.citizenid] = os.time()
    return true, nil, report
end)

--- call a medic: every medic on duty gets the call and a map mark at the reception
lib.callback.register('exti_hospital:server:callMedic', function(source, name)
    local hospital = hospitalNear(source, name)
    if not hospital then return false, 'too_far' end
    local wait = minutesLeft(lastCall[source], Config.callCooldown)
    if wait > 0 then return false, 'wait', wait end
    local count, list = emsOnDuty()
    if count == 0 then return false, 'no_ems' end
    lastCall[source] = os.time()
    local player = getPlayer(source)
    local who = player and player.PlayerData.charinfo and player.PlayerData.charinfo.lastname or ''
    local text = ('مريض ينتظر في استقبال %s (%s)'):format(hospital.label, who)
    for i = 1, #list do
        TriggerClientEvent('hospital:client:ambulanceAlert', list[i], hospital.reception, text)
    end
    -- the call also goes on the medics' tablet (exti_ems)
    if GetResourceState('exti_ems') == 'started' then
        pcall(function() exports.exti_ems:AddCall({ kind = 'reception', coords = hospital.reception, patient = source, text = text }) end)
    end
    return true, nil, count
end)

--- show your medical report to the closest person next to you
RegisterNetEvent('exti_hospital:server:showReport', function(target, report)
    local src = source
    if type(target) ~= 'number' or type(report) ~= 'table' then return end
    if target == src or not getPlayer(target) then return end
    if lastShow[src] and os.time() - lastShow[src] < 10 then return end -- no spamming someone's screen
    lastShow[src] = os.time()
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target) then return end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > 4.0 then return end
    -- only a report the player really has (same number) can be shown
    local found = false
    local ok, slots = pcall(function() return exports.ox_inventory:Search(src, 'slots', 'medreport') end)
    if ok and type(slots) == 'table' then
        for _, slot in pairs(slots) do
            if slot.metadata and slot.metadata.number == report.number then report = slot.metadata found = true break end
        end
    end
    if not found then return end
    TriggerClientEvent('exti_hospital:client:showReport', target, report, true)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'أظهرت تقريرك الطبي' })
end)

AddEventHandler('playerDropped', function()
    checkups[source] = nil
    lastCall[source] = nil
    lastShow[source] = nil
end)
