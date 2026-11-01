-- =====================================================================
-- EX_Tii EMS (server): starting the shift like the video — the clock in / out terminal at the
-- reception computer (hours logged), the cloakroom (uniforms saved in the database; the leader
-- adds, edits and deletes them), the team storage, the personal locker, and moving the spots in
-- game (/emsspots).
-- =====================================================================

local JOB = Config.job
local RES = GetCurrentResourceName()
local SPOT_FILE = 'data/spots.json'

local getPlayer, isMedic, onDuty, nameOf = EMS.getPlayer, EMS.isMedic, EMS.onDuty, EMS.nameOf
local near, notify, shifts = EMS.near, EMS.notify, EMS.shifts

local function hospitalOf(name)
    return type(name) == 'string' and Config.hospitals[name] or nil
end

local function isBoss(player)
    return isMedic(player) and player.PlayerData.job.isboss == true
end

local function grade(player)
    return player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
end

local function nearSpot(src, coords, extra)
    return coords and near(src, coords, Config.reachPoint + (extra or 1.5)) or false
end

-- men's or women's clothes: what the player's character is
local FEMALE = GetHashKey('mp_f_freemode_01')
local function pedGender(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityModel(ped) == FEMALE and 'female' or 'male'
end

-- our stashes are only opened by this script (after its own checks): a group nobody has stops
-- anyone opening them straight from ox_inventory
EMS.NOONE = { exti_ems_noone = 0 }

---------------------------------------------------------------------------
-- spots moved in game (data/spots.json)
---------------------------------------------------------------------------
local savedSpots = {}
do
    local raw = LoadResourceFile(RES, SPOT_FILE)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then savedSpots = data end
end
EMS.applySpots(savedSpots)
GlobalState.exti_ems_spots = savedSpots

---------------------------------------------------------------------------
-- database
---------------------------------------------------------------------------
local dbReady = false
local outfits = { male = {}, female = {} } -- [gender] = list { id, label, grades = {..}, clothes = { components, props } }

local function decode(s)
    local ok, v = pcall(json.decode, s or '')
    return ok and v or nil
end

local function sortOutfits()
    for _, list in pairs(outfits) do
        table.sort(list, function(a, b)
            if a.sort ~= b.sort then return a.sort < b.sort end
            return a.id < b.id
        end)
    end
end

local function toClothes(def)
    local c = { components = {}, props = {} }
    for i, v in ipairs(def.components or {}) do c.components[i] = { component_id = v[1], drawable = v[2], texture = v[3] } end
    for i, v in ipairs(def.props or {}) do c.props[i] = { prop_id = v[1], drawable = v[2], texture = v[3] } end
    return c
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_ems_shifts` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `hospital` VARCHAR(32) NULL,
        `started` INT NOT NULL,
        `ended` INT NOT NULL,
        `minutes` INT NOT NULL,
        INDEX `cid_ended` (`citizenid`, `ended`)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_ems_outfits` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `gender` VARCHAR(8) NOT NULL,
        `label` VARCHAR(40) NOT NULL,
        `grades` VARCHAR(100) NOT NULL,
        `clothes` LONGTEXT NOT NULL,
        `sort` INT NOT NULL DEFAULT 0,
        `updated_by` VARCHAR(50) NULL
    )]])

    -- EX_Tii: one-time flags, so the default uniforms are added only once (before, a leader who
    -- deleted every uniform got the defaults back after each restart)
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_ems_flags` (
        `name` VARCHAR(40) NOT NULL PRIMARY KEY,
        `value` INT NOT NULL DEFAULT 0
    ) DEFAULT CHARSET=utf8mb4]])
    local seeded = MySQL.scalar.await('SELECT `value` FROM `exti_ems_flags` WHERE `name` = ?', { 'outfits_seeded' })

    local rows = MySQL.query.await('SELECT * FROM `exti_ems_outfits`') or {}
    if not seeded then
        if #rows == 0 then
            -- the first time: the uniforms from config.lua (the one from the video first)
            for gender, list in pairs(Config.defaultOutfits or {}) do
                for i, def in ipairs(list) do
                    MySQL.insert.await('INSERT INTO `exti_ems_outfits` (`gender`, `label`, `grades`, `clothes`, `sort`) VALUES (?, ?, ?, ?, ?)',
                        { gender, def.label, json.encode(def.grades or {}), json.encode(toClothes(def)), i })
                end
            end
            rows = MySQL.query.await('SELECT * FROM `exti_ems_outfits`') or {}
        end
        MySQL.query.await('INSERT INTO `exti_ems_flags` (`name`, `value`) VALUES (?, 1) ON DUPLICATE KEY UPDATE `value` = 1', { 'outfits_seeded' })
    end
    for _, r in ipairs(rows) do
        local list = outfits[r.gender]
        local clothes = decode(r.clothes)
        if list and clothes then
            list[#list + 1] = { id = r.id, label = r.label, grades = decode(r.grades) or {}, clothes = clothes, sort = r.sort or 0 }
        end
    end
    sortOutfits()
    dbReady = true
end)

---------------------------------------------------------------------------
-- the team storage and the personal locker (ox_inventory stashes)
---------------------------------------------------------------------------
local function registerStashes()
    for name, h in pairs(Config.hospitals) do
        if h.storage then
            exports.ox_inventory:RegisterStash('exti_ems_storage_' .. name, ('%s — %s'):format(Config.storage.label, h.label),
                Config.storage.slots, Config.storage.weight, nil, EMS.NOONE, h.storage)
        end
    end
end

-- one locker per person (its own stash name, so it can never mix with someone else's)
local function lockerOf(cid)
    local id = 'exti_ems_locker_' .. cid
    exports.ox_inventory:RegisterStash(id, Config.locker.label, Config.locker.slots, Config.locker.weight, nil, EMS.NOONE)
    return id
end

local function registerAll()
    for _ = 1, 60 do
        if GetResourceState('ox_inventory') == 'started' and pcall(registerStashes) then return end
        Wait(2000)
    end
    print('^1[exti_ems] could not register the EMS storage (is ox_inventory started?)^0')
end
CreateThread(registerAll)

-- ox_inventory restarted: it forgot our stashes
AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'ox_inventory' then CreateThread(function() Wait(2000) registerAll() end) end
end)

lib.callback.register('exti_ems:server:openStash', function(source, hospital, kind)
    local player = getPlayer(source)
    local h = hospitalOf(hospital)
    if not isMedic(player) or not h then return false, 'failed' end
    if kind == 'storage' then
        if not onDuty(player) then return false, 'off_duty' end
        if not nearSpot(source, h.storage) then return false, 'too_far' end
        if grade(player) < Config.storage.grade then return false, 'storage_rank' end
        return exports.ox_inventory:forceOpenInventory(source, 'stash', 'exti_ems_storage_' .. hospital) and true or false, 'failed'
    elseif kind == 'locker' then
        if not nearSpot(source, h.locker) then return false, 'too_far' end
        local ok, id = pcall(lockerOf, player.PlayerData.citizenid)
        if not ok then return false, 'failed' end
        return exports.ox_inventory:forceOpenInventory(source, 'stash', id) and true or false, 'failed'
    end
    return false, 'failed'
end)

---------------------------------------------------------------------------
-- clocking in / out: drag your card onto the sensor at the reception computer
---------------------------------------------------------------------------
local function startOfWeek(now)
    local t = os.date('*t', now)
    local back = (t.wday + 5) % 7 -- days since Monday
    return os.time({ year = t.year, month = t.month, day = t.day - back, hour = 0, min = 0, sec = 0 })
end

local function minutesThisWeek(cid)
    local ok, total = pcall(function()
        return MySQL.scalar.await('SELECT COALESCE(SUM(`minutes`), 0) FROM `exti_ems_shifts` WHERE `citizenid` = ? AND `ended` >= ?', { cid, startOfWeek(os.time()) })
    end)
    return ok and tonumber(total) or 0
end
EMS.minutesThisWeek = minutesThisWeek

-- the shift ends (clocked out, left the job, left the city): log the minutes
function EMS.endShift(src)
    local shift = shifts[src]
    if not shift or not shift.cid then return end
    local now = os.time()
    local minutes = math.floor((now - shift.start) / 60)
    shift.cid = nil -- only once
    if minutes >= 1 then
        MySQL.insert('INSERT INTO `exti_ems_shifts` (`citizenid`, `hospital`, `started`, `ended`, `minutes`) VALUES (?, ?, ?, ?, ?)',
            { shift.citizenid, shift.hospital, shift.start, now, minutes })
    end
    return minutes
end

local lastSwipe = {}

lib.callback.register('exti_ems:server:dutyInfo', function(source, hospital)
    local player = getPlayer(source)
    local h = hospitalOf(hospital)
    if not isMedic(player) or not h or not nearSpot(source, h.duty) then return false end
    return {
        name = nameOf(player),
        rank = player.PlayerData.job.grade.name,
        station = h.label,
        onDuty = player.PlayerData.job.onduty == true,
    }
end)

lib.callback.register('exti_ems:server:swipe', function(source, hospital)
    local player = getPlayer(source)
    local h = hospitalOf(hospital)
    if not isMedic(player) then return { ok = false, text = 'هذه البطاقة ليست لطاقم الإسعاف.' } end
    if not h or not nearSpot(source, h.duty) then return { ok = false, text = 'اقترب من الجهاز أكثر.' } end
    local now = GetGameTimer()
    if lastSwipe[source] and now - lastSwipe[source] < 3000 then return { ok = false, text = 'انتظر لحظة ثم اسحب البطاقة مرة أخرى.' } end
    lastSwipe[source] = now

    local cid = player.PlayerData.citizenid
    if player.PlayerData.job.onduty then
        local minutes = EMS.endShift(source) or 0
        shifts[source] = nil
        exports.qbx_core:SetJobDuty(source, false)
        lib.logger(source, 'ems', ('clocked out at %s after %d minutes'):format(hospital, minutes))
        return { ok = true, on = false, minutes = minutes, name = nameOf(player) }
    end
    EMS.endShift(source) -- an old shift that never ended (a rank change...) is logged first
    local week = minutesThisWeek(cid)
    exports.qbx_core:SetJobDuty(source, true)
    shifts[source] = { start = os.time(), cid = cid, citizenid = cid, hospital = hospital, revives = 0, treats = 0, earned = 0 }
    lib.logger(source, 'ems', ('clocked in at %s'):format(hospital))
    return { ok = true, on = true, week = week, name = nameOf(player) }
end)

-- after a restart of this script, medics still on duty keep their shift (counted from now)
CreateThread(function()
    Wait(1000)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local player = getPlayer(src)
        if onDuty(player) and not shifts[src] then
            shifts[src] = { start = os.time(), cid = player.PlayerData.citizenid, citizenid = player.PlayerData.citizenid, revives = 0, treats = 0, earned = 0 }
        end
    end
end)

-- clocked in some other way (an admin, /duty): still log the time
AddEventHandler('QBCore:Server:SetDuty', function(src, duty)
    if duty then
        local player = getPlayer(src)
        if isMedic(player) and not shifts[src] then
            shifts[src] = { start = os.time(), cid = player.PlayerData.citizenid, citizenid = player.PlayerData.citizenid, revives = 0, treats = 0, earned = 0 }
        end
    elseif shifts[src] then
        EMS.endShift(src)
        shifts[src] = nil
    end
end)

AddEventHandler('playerDropped', function()
    lastSwipe[source] = nil
end)

---------------------------------------------------------------------------
-- the cloakroom
---------------------------------------------------------------------------
local function gradeList()
    local list = {}
    local ok, job = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    if ok and job and job.grades then
        for g = 0, 20 do
            local d = job.grades[g]
            if not d then break end
            list[#list + 1] = { level = g, name = d.name }
        end
    end
    return list
end

local function allowed(outfit, level)
    for _, g in ipairs(outfit.grades or {}) do
        if g == level then return true end
    end
    return false
end

local function outfitView(gender, player)
    local list, level = {}, grade(player)
    for _, o in ipairs(outfits[gender] or {}) do
        list[#list + 1] = { id = o.id, label = o.label, grades = o.grades, allowed = allowed(o, level) }
    end
    return list
end

local function genderOf(g) return g == 'female' and 'female' or 'male' end

local function cloakCheck(src, hospital, needBoss)
    local player = getPlayer(src)
    local h = hospitalOf(hospital)
    if not isMedic(player) then return nil, 'failed' end
    if not h or not nearSpot(src, h.cloakroom) then return nil, 'too_far' end
    if needBoss and not isBoss(player) then return nil, 'not_boss' end
    if not dbReady then return nil, 'failed' end
    return player, h
end

lib.callback.register('exti_ems:server:cloakroom', function(source, hospital, gender)
    local player, h = cloakCheck(source, hospital)
    if not player then return false, h end
    local own = pedGender(source)
    -- the leader can also look after the other side's uniforms (names, ranks, delete)
    gender = isBoss(player) and genderOf(gender or own) or own
    return {
        boss = isBoss(player), grade = grade(player), gender = gender, own = gender == own, station = h.label,
        grades = gradeList(), outfits = outfitView(gender, player),
    }
end)

lib.callback.register('exti_ems:server:outfitClothes', function(source, hospital, gender, id)
    local player = cloakCheck(source, hospital)
    if not player then return false end
    if genderOf(gender) ~= pedGender(source) then return false end -- men's clothes on a woman break
    for _, o in ipairs(outfits[genderOf(gender)] or {}) do
        if o.id == id then
            if not allowed(o, grade(player)) and not isBoss(player) then return false end
            return o.clothes
        end
    end
    return false
end)

-- what the leader picked in the clothes editor (only the clothes: never the face or hair)
local COMPONENTS = { [1] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }
local PROPS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }

local function cleanClothes(c)
    if type(c) ~= 'table' or type(c.components) ~= 'table' then return end
    local out = { components = {}, props = {} }
    local seen = {}
    for _, v in ipairs(c.components) do
        local id, d, t = math.tointeger(v.component_id), math.tointeger(v.drawable), math.tointeger(v.texture)
        if id and COMPONENTS[id] and not seen[id] and d and t and d >= -1 and d <= 2000 and t >= 0 and t <= 255 then
            seen[id] = true
            out.components[#out.components + 1] = { component_id = id, drawable = d, texture = t }
        end
    end
    seen = {}
    for _, v in ipairs(type(c.props) == 'table' and c.props or {}) do
        local id, d, t = math.tointeger(v.prop_id), math.tointeger(v.drawable), math.tointeger(v.texture)
        if id and PROPS[id] and not seen[id] and d and t and d >= -1 and d <= 2000 and t >= -1 and t <= 255 then
            seen[id] = true
            out.props[#out.props + 1] = { prop_id = id, drawable = d, texture = math.max(t, 0) }
        end
    end
    if #out.components == 0 then return end
    return out
end

local function cleanGrades(list)
    if type(list) ~= 'table' then return end
    local valid = {}
    for _, g in ipairs(gradeList()) do valid[g.level] = true end
    local out, seen = {}, {}
    for _, g in ipairs(list) do
        g = math.tointeger(g)
        if g and valid[g] and not seen[g] then seen[g] = true out[#out + 1] = g end
    end
    table.sort(out)
    if #out == 0 then return end
    return out
end

lib.callback.register('exti_ems:server:outfitSave', function(source, hospital, data)
    local player = cloakCheck(source, hospital, true)
    if not player then return { ok = false, text = 'هذا لقائد الإسعاف فقط، وقرب غرفة الملابس.' } end
    if type(data) ~= 'table' then return { ok = false } end
    local gender = genderOf(data.gender)
    local label = type(data.label) == 'string' and data.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local chars = utf8.len(label)
    if not chars or chars < 2 or chars > 24 then return { ok = false, text = 'اكتب اسمًا قصيرًا للزي.' } end
    local grades = cleanGrades(data.grades)
    if not grades then return { ok = false, text = 'اختر رتبة واحدة على الأقل.' } end
    local clothes = data.clothes ~= nil and cleanClothes(data.clothes) or nil
    if clothes and gender ~= pedGender(source) then return { ok = false, text = 'ملابس هذا الزي تُختار بشخصية من نفس الجنس.' } end
    local list = outfits[gender]
    local cid = player.PlayerData.citizenid

    if data.mode == 'new' then
        if not clothes then return { ok = false, text = 'اختر الملابس في المحرر أولًا.' } end
        if #list >= (Config.maxOutfits or 12) then return { ok = false, text = 'وصلت للحد الأقصى من الأزياء، احذف واحدًا أولًا.' } end
        local sort = (#list > 0 and list[#list].sort or 0) + 1
        local id = MySQL.insert.await('INSERT INTO `exti_ems_outfits` (`gender`, `label`, `grades`, `clothes`, `sort`, `updated_by`) VALUES (?, ?, ?, ?, ?, ?)',
            { gender, label, json.encode(grades), json.encode(clothes), sort, cid })
        if not id then return { ok = false } end
        list[#list + 1] = { id = id, label = label, grades = grades, clothes = clothes, sort = sort }
    else
        local o
        for _, x in ipairs(list) do if x.id == data.id then o = x break end end
        if not o then return { ok = false, text = 'هذا الزي لم يعد موجودًا.' } end
        o.label, o.grades = label, grades
        if clothes then o.clothes = clothes end
        MySQL.update.await('UPDATE `exti_ems_outfits` SET `label` = ?, `grades` = ?, `clothes` = ?, `updated_by` = ? WHERE `id` = ?',
            { label, json.encode(grades), json.encode(o.clothes), cid, o.id })
    end
    sortOutfits()
    lib.logger(source, 'ems', ('%s outfit "%s" (%s)'):format(data.mode == 'new' and 'added' or 'edited', label, gender))
    return { ok = true, outfits = outfitView(gender, player) }
end)

lib.callback.register('exti_ems:server:outfitDelete', function(source, hospital, gender, id)
    local player = cloakCheck(source, hospital, true)
    if not player then return false end
    gender = genderOf(gender)
    local list = outfits[gender]
    for i, o in ipairs(list) do
        if o.id == id then
            table.remove(list, i)
            MySQL.update.await('DELETE FROM `exti_ems_outfits` WHERE `id` = ?', { id })
            lib.logger(source, 'ems', ('deleted outfit "%s" (%s)'):format(o.label, gender))
            break
        end
    end
    return { outfits = outfitView(gender, player) }
end)

---------------------------------------------------------------------------
-- admins: /emsspots — move the hospital spots in game
---------------------------------------------------------------------------
lib.addCommand('emsspots', {
    help = 'EMS: move the hospital spots (clock in, cloakroom, storage, locker, garages) to where you stand (admin)',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('exti_ems:client:spots', source)
end)

local function save()
    SaveResourceFile(RES, SPOT_FILE, json.encode(savedSpots, { indent = true }), -1)
    EMS.applySpots(savedSpots)
    GlobalState.exti_ems_spots = savedSpots
    pcall(registerStashes)
end

lib.callback.register('exti_ems:server:setSpot', function(source, hospital, kind, remove)
    if not IsPlayerAceAllowed(source, 'command.emsspots') then return false end
    if not hospitalOf(hospital) or not EMS.SPOT_KINDS[kind] then return false end
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end
    savedSpots[hospital] = type(savedSpots[hospital]) == 'table' and savedSpots[hospital] or {}
    if remove then
        if not EMS.SPOT_OPTIONAL[kind] then return false end
        savedSpots[hospital][kind] = false
    else
        local c = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        local heading = GetEntityHeading(veh ~= 0 and veh or ped)
        local spot = { x = math.floor(c.x * 100 + 0.5) / 100, y = math.floor(c.y * 100 + 0.5) / 100, z = math.floor(c.z * 100 + 0.5) / 100 }
        if EMS.SPOT_KINDS[kind] == 'spawn' then
            spot.w = math.floor(heading * 10 + 0.5) / 10
            if veh ~= 0 then spot.z = spot.z - 0.5 end -- from the car seat down to the road
        end
        savedSpots[hospital][kind] = spot
    end
    save()
    lib.logger(source, 'ems', ('%s spot %s/%s'):format(remove and 'removed' or 'moved', hospital, kind))
    return true
end)

lib.callback.register('exti_ems:server:resetSpot', function(source, hospital, kind)
    if not IsPlayerAceAllowed(source, 'command.emsspots') then return false end
    if not hospitalOf(hospital) or not EMS.SPOT_KINDS[kind] then return false end
    if type(savedSpots[hospital]) == 'table' then savedSpots[hospital][kind] = nil end
    save()
    return true
end)
