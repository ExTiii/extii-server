-- =====================================================================
-- EX_Tii Police (server): the prison (Bolingbroke).
-- The officer brings the cuffed person to the gate and hands him over (the charge sheet's سجن buttons
-- work only there). The time runs while the prisoner is in the city, the yard jobs take minutes off,
-- his bag is locked up until he walks out, and leaving the prison grounds is an escape (the police
-- are told). The tablet's Prison app lists the inmates and lets an officer release one early.
-- =====================================================================

local JOB = Config.job
local P = Config.prison
local getPlayer, onDuty, nameOf, notify, pedOf = POL.getPlayer, POL.onDuty, POL.nameOf, POL.notify, POL.pedOf
local RES = GetCurrentResourceName()
local SPOT_FILE = 'data/prison.json'

---------------------------------------------------------------------------
-- the spots: config.lua + what admins moved with /prisonspot (data/prison.json), shared in GlobalState
---------------------------------------------------------------------------
local saved = {}
do
    local raw = LoadResourceFile(RES, SPOT_FILE)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then saved = data end
end

local function num(v) return tonumber(v) end
local function point(t) if type(t) == 'table' and num(t.x) and num(t.y) and num(t.z) then return vec3(num(t.x), num(t.y), num(t.z)) end end
local function spawnOf(t) if type(t) == 'table' and num(t.x) and num(t.y) and num(t.z) then return vec4(num(t.x), num(t.y), num(t.z), num(t.w) or 0.0) end end

local prison = {} -- the effective one
local function build()
    prison = {
        intake = point(saved.intake) or P.intake,
        intakeRadius = P.intakeRadius,
        spawn = spawnOf(saved.spawn) or P.spawn,
        release = spawnOf(saved.release) or P.release,
        center = P.center, radius = P.radius,
        works = {},
    }
    for i, w in ipairs(P.works) do
        local spots = {}
        for j, s in ipairs(w.spots) do spots[j] = s end
        local extra = type(saved.works) == 'table' and saved.works[w.id] or nil
        if type(extra) == 'table' then
            for j, s in pairs(extra) do
                local idx = math.tointeger(tonumber(j))
                local c = point(s)
                if idx and c and idx >= 1 and idx <= #spots + 1 then spots[idx] = c end
            end
        end
        prison.works[i] = { id = w.id, label = w.label, minutes = w.minutes, seconds = w.seconds, scenario = w.scenario, spots = spots }
    end
    GlobalState.exti_police_prison = prison
end
build()

local function savePrison()
    SaveResourceFile(RES, SPOT_FILE, json.encode(saved, { indent = true }), -1)
    build()
end

-- /prisonspot intake | spawn | release | work <electric|clean|gym> <n> | reset
lib.addCommand('prisonspot', {
    help = 'نقل نقاط السجن إلى مكانك (للإدارة)',
    params = {
        { name = 'what', type = 'string', help = 'intake / spawn / release / work / reset' },
        { name = 'work', type = 'string', help = 'electric / clean / gym', optional = true },
        { name = 'n', type = 'number', help = 'رقم النقطة', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local ped = pedOf(source)
    if not ped then return end
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local here = { x = c.x, y = c.y, z = c.z, w = h }
    if args.what == 'reset' then
        saved = {}
        savePrison()
        return notify(source, 'success', 'رجعت نقاط السجن إلى config.lua')
    elseif args.what == 'intake' or args.what == 'spawn' or args.what == 'release' then
        saved[args.what] = here
    elseif args.what == 'work' then
        local w
        for _, x in ipairs(P.works) do if x.id == args.work then w = x end end
        if not w then return notify(source, 'error', 'الأعمال: electric / clean / gym') end
        local n = math.tointeger(tonumber(args.n)) or 1
        local count = #prison.works[1].spots
        for _, x in ipairs(prison.works) do if x.id == w.id then count = #x.spots end end
        if n < 1 or n > count + 1 then return notify(source, 'error', ('الرقم من 1 إلى %d'):format(count + 1)) end
        saved.works = type(saved.works) == 'table' and saved.works or {}
        saved.works[w.id] = saved.works[w.id] or {}
        saved.works[w.id][tostring(n)] = { x = c.x, y = c.y, z = c.z }
    else
        return notify(source, 'error', '/prisonspot intake | spawn | release | work <electric|clean|gym> <n> | reset')
    end
    savePrison()
    lib.print.info(('[prisonspot] %s %s %s by %s'):format(args.what, args.work or '', args.n or '', GetPlayerName(source) or source))
    notify(source, 'success', 'حُفظت النقطة في مكانك')
end)

---------------------------------------------------------------------------
-- the table and the inmates
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_prison` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `name` VARCHAR(80) NOT NULL,
        `minutes` INT NOT NULL,
        `remaining` INT NOT NULL,
        `officer` VARCHAR(80) NOT NULL,
        `charge_id` INT NULL,
        `started` INT NOT NULL,
        `escaped` TINYINT NOT NULL DEFAULT 0,
        `updated` INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
end)

local inmates = {}   -- [src] = { cid, name, remaining (seconds), minutes, escaped, lastTick, lastWork, away }

-- his prison locker (an ox_inventory stash nobody opens from the street). Registered again every time
-- it is touched: after a server restart ox_inventory knows nothing about it
local function locker(cid)
    local id = 'exti_prison_' .. cid
    pcall(function() exports.ox_inventory:RegisterStash(id, 'أغراض السجين', 60, 1000000, nil, POL.NOONE) end)
    return id
end
local lockerId = locker

local function state(src) return Player(src) and Player(src).state end

local function tellClient(src, inmate)
    TriggerClientEvent('exti_police:client:jailed', src, {
        remaining = inmate.remaining, minutes = inmate.minutes, escaped = inmate.escaped == true,
    })
end

local function save(src, inmate)
    MySQL.update('UPDATE `exti_police_prison` SET `remaining` = ?, `escaped` = ?, `updated` = ? WHERE `citizenid` = ?',
        { math.max(0, math.floor(inmate.remaining)), inmate.escaped and 1 or 0, os.time(), inmate.cid })
end

-- everything in his bag goes to his prison locker (and comes back when he walks out)
local function lockItems(src, cid)
    local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
    if not ok or type(items) ~= 'table' then return end
    local list = {}
    for _, it in pairs(items) do
        if it and type(it.name) == 'string' and (it.count or 0) > 0 then
            list[#list + 1] = { name = it.name, count = it.count, slot = it.slot, metadata = it.metadata }
        end
    end
    if #list == 0 then return end
    for _, it in ipairs(list) do
        local ok1, removed = pcall(function() return exports.ox_inventory:RemoveItem(src, it.name, it.count, nil, it.slot) end)
        if ok1 and removed then
            local ok2, added = pcall(function() return exports.ox_inventory:AddItem(lockerId(cid), it.name, it.count, it.metadata) end)
            if not (ok2 and added) then pcall(function() exports.ox_inventory:AddItem(src, it.name, it.count, it.metadata) end) end
        end
    end
end

local function returnItems(src, cid)
    local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(lockerId(cid)) end)
    if not ok or type(items) ~= 'table' then return end
    local list = {}
    for _, it in pairs(items) do
        if it and type(it.name) == 'string' and (it.count or 0) > 0 then
            list[#list + 1] = { name = it.name, count = it.count, slot = it.slot, metadata = it.metadata }
        end
    end
    local left = 0
    for _, it in ipairs(list) do
        local ok1, removed = pcall(function() return exports.ox_inventory:RemoveItem(lockerId(cid), it.name, it.count, nil, it.slot) end)
        if ok1 and removed then
            local ok2, added = pcall(function() return exports.ox_inventory:AddItem(src, it.name, it.count, it.metadata) end)
            if not (ok2 and added) then
                left = left + 1
                pcall(function() exports.ox_inventory:AddItem(lockerId(cid), it.name, it.count, it.metadata) end)
            end
        end
    end
    if left > 0 then notify(src, 'warning', 'بعض أغراضك لم تتسع في حقيبتك، اسأل الشرطة عنها') end
end

local function setJailBags(src, on)
    local st = state(src)
    if st then
        st:set('injail', on and true or false, true)
        st:set('canUseWeapons', not on, true) -- nothing handed to him inside works as a weapon
    end
    local player = getPlayer(src)
    if player then player.Functions.SetMetaData('injail', on and (inmates[src] and math.ceil(inmates[src].remaining / 60) or 1) or 0) end
end

local function copsTold(text)
    for _, src in ipairs(POL.copsOnDuty()) do
        local id = tonumber(src)
        if id then notify(id, 'warning', text) end
    end
end

---------------------------------------------------------------------------
-- in and out
---------------------------------------------------------------------------
--- jail(src, minutes, officerName, chargeId) -> ok
local function jail(src, minutes, officerName, chargeId)
    local player = getPlayer(src)
    minutes = tonumber(minutes)
    if not player or not minutes or minutes < 1 then return false end
    minutes = math.max(1, math.min(P.maxMinutes, math.floor(minutes)))
    local cid = player.PlayerData.citizenid
    local name = nameOf(player)
    -- jailed while already inside: the times add up
    local before = inmates[src]
    local remaining = (before and math.max(0, before.remaining) or 0) + minutes * 60
    local inmate = { cid = cid, name = name, remaining = remaining, minutes = math.ceil(remaining / 60), escaped = false, lastTick = os.time(), lastWork = 0 }
    inmates[src] = inmate
    MySQL.query.await('INSERT INTO `exti_police_prison` (`citizenid`, `name`, `minutes`, `remaining`, `officer`, `charge_id`, `started`, `escaped`, `updated`) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `minutes` = VALUES(`minutes`), `remaining` = VALUES(`remaining`), `officer` = VALUES(`officer`), `charge_id` = VALUES(`charge_id`), `started` = VALUES(`started`), `escaped` = 0, `updated` = VALUES(`updated`)',
        { cid, name, inmate.minutes, remaining, officerName or 'الشرطة', chargeId, os.time(), os.time() })
    lockItems(src, cid) -- again when he is jailed a second time: whatever he picked up goes too
    -- cuffs off, escort over, and an officer goes off duty
    if POL.isCuffed and POL.isCuffed(src) then POL.uncuff(src) end
    if onDuty(player) then pcall(function() exports.qbx_core:SetJobDuty(src, false) end) end
    setJailBags(src, true)
    tellClient(src, inmate)
    POL.log(nil, 'jailed', ('%s: %d دقيقة (%s)'):format(name, inmate.minutes, officerName or ''))
    lib.print.info(('[prison] %s (%s) jailed %d min by %s'):format(name, cid, inmate.minutes, officerName or '?'))
    return true
end

local pendingReturn = {} -- [src] = cid: released while down; the bag comes back after the respawn (the hospital wipes it)

local function isDown(src)
    local st = state(src)
    local ds = st and st['qbx_medical:deathState']
    return ds ~= nil and ds ~= 1
end

local function release(src, why)
    local inmate = inmates[src]
    if not inmate then return false end
    inmates[src] = nil
    MySQL.query.await('DELETE FROM `exti_police_prison` WHERE `citizenid` = ?', { inmate.cid })
    setJailBags(src, false)
    if isDown(src) then pendingReturn[src] = inmate.cid else returnItems(src, inmate.cid) end
    TriggerClientEvent('exti_police:client:released', src, why or 'time')
    POL.log(nil, 'released', ('%s (%s)'):format(inmate.name, why == 'admin' and 'إطلاق سراح من الإدارة' or 'انتهت المدة'))
    return true
end

-- an offline inmate who comes back: his time goes on
local function restore(src, player)
    local cid = player.PlayerData.citizenid
    local row = MySQL.single.await('SELECT * FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
    if not row then
        if (tonumber(player.PlayerData.metadata and player.PlayerData.metadata.injail) or 0) > 0 then player.Functions.SetMetaData('injail', 0) end
        returnItems(src, cid) -- released while he was away (the tablet), or things that did not fit last time
        return
    end
    if (tonumber(row.remaining) or 0) <= 0 then
        MySQL.query.await('DELETE FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
        player.Functions.SetMetaData('injail', 0)
        returnItems(src, cid)
        return
    end
    inmates[src] = { cid = cid, name = row.name, remaining = tonumber(row.remaining), minutes = tonumber(row.minutes), escaped = false, lastTick = os.time(), lastWork = 0 }
    setJailBags(src, true)
    SetTimeout(3000, function() if inmates[src] then tellClient(src, inmates[src]) end end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    SetTimeout(2000, function()
        local p = getPlayer(src)
        if p then restore(src, p) end
    end)
end)

-- the script starts again with players in the city: the inmates among them go on
AddEventHandler('onResourceStart', function(resource)
    if resource ~= RES then return end
    SetTimeout(2000, function()
        for _, s in ipairs(GetPlayers()) do
            local id = tonumber(s)
            local p = id and getPlayer(id)
            if p then restore(id, p) end
        end
    end)
end)

local function gone(src)
    local inmate = inmates[src]
    if not inmate then return end
    save(src, inmate)
    inmates[src] = nil
end
AddEventHandler('playerDropped', function()
    local src = source
    gone(src)
    pendingReturn[src] = nil
end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    gone(src)
    pendingReturn[src] = nil
    setJailBags(src, false)
end)

-- back from the hospital: back into the cells (or, released while down, the bag comes back now)
AddEventHandler('qbx_medical:server:playerRespawned', function(src)
    local inmate = inmates[src]
    if inmate then SetTimeout(2500, function() if inmates[src] then tellClient(src, inmates[src]) end end) end
    local cid = pendingReturn[src]
    if cid then
        pendingReturn[src] = nil
        SetTimeout(3000, function() if getPlayer(src) then returnItems(src, cid) end end)
    end
end)

local function distanceFromCenter(src)
    local ped = pedOf(src)
    if not ped then return 0 end
    return #(GetEntityCoords(ped) - prison.center)
end

-- prison is prison: nobody gets out before the time is up (walking out, an admin "bring", a teleport,
-- a car...). Outside the grounds = straight back to the cells. Only the time or /unjail (admin) frees.
local function sendBack(src, inmate)
    local ped = pedOf(src)
    if not ped then return end
    local sp = prison.spawn
    SetEntityCoords(ped, sp.x, sp.y, sp.z, false, false, false, false)
    SetEntityHeading(ped, sp.w or 0.0)
    inmate.escaped = false
    tellClient(src, inmate) -- the game puts him in the cell too, in the uniform
    local now = os.time()
    if not inmate.lastPulled or now - inmate.lastPulled > 60 then
        POL.log(nil, 'escaped', ('%s (أُعيد إلى الزنزانة)'):format(inmate.name))
        lib.print.warn(('[prison] %s (%s) was outside the prison: sent back to the cells'):format(inmate.name, inmate.cid))
    end
    inmate.lastPulled = now
end

-- the clock: once a second for everyone inside (it never stops). Every second the server also looks
-- where everyone is: outside the grounds = back in the cell.
CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        local done, outside = {}, {}
        for src, inmate in pairs(inmates) do
            inmate.escaped = false
            inmate.remaining = inmate.remaining - (now - inmate.lastTick)
            inmate.lastTick = now
            if inmate.remaining <= 0 then
                done[#done + 1] = src
            else
                if now % 30 == 0 then save(src, inmate) end
                if pedOf(src) and not isDown(src) and distanceFromCenter(src) > prison.radius then outside[#outside + 1] = src end
            end
        end
        for _, src in ipairs(outside) do if inmates[src] then sendBack(src, inmates[src]) end end
        for _, src in ipairs(done) do if inmates[src] then release(src, 'time') end end
    end
end)

-- /unjail <id or citizenid>: the only way out before the time is up (admins)
lib.addCommand('unjail', {
    help = 'Prison: let an inmate out now (admin only)',
    params = { { name = 'target', type = 'string', help = 'the player id (online) or the citizen id' } },
    restricted = 'group.admin',
}, function(source, args)
    local t = tostring(args.target or '')
    local id = math.tointeger(tonumber(t))
    if id and inmates[id] then
        local name = inmates[id].name
        release(id, 'admin')
        lib.print.info(('[prison] %s used /unjail on %s'):format(source == 0 and 'console' or (GetPlayerName(source) or source), name))
        if source > 0 then notify(source, 'success', ('أُطلق سراح %s'):format(name)) else print(('released %s'):format(name)) end
        return
    end
    local cid = t:upper()
    for src, inmate in pairs(inmates) do
        if inmate.cid == cid then
            release(src, 'admin')
            if source > 0 then notify(source, 'success', ('أُطلق سراح %s'):format(inmate.name)) else print(('released %s'):format(inmate.name)) end
            return
        end
    end
    local row = MySQL.single.await('SELECT `name` FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
    if row then
        -- offline: he walks out with his things the next time he comes into the city
        MySQL.query.await('DELETE FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
        POL.log(nil, 'released', ('%s (إطلاق سراح من الإدارة)'):format(row.name))
        if source > 0 then notify(source, 'success', ('أُطلق سراح %s (غير متصل)'):format(row.name)) else print(('released %s (offline)'):format(row.name)) end
        return
    end
    if source > 0 then notify(source, 'error', 'هذا الشخص ليس في السجن') else print('not in prison') end
end)

---------------------------------------------------------------------------
-- from the prisoner's game
---------------------------------------------------------------------------
-- a yard job done: minutes off
lib.callback.register('exti_police:server:prisonWork', function(source, workId, spotIndex)
    local inmate = inmates[source]
    if not inmate then return false, 'not_inmate' end
    local w
    for _, x in ipairs(prison.works) do if x.id == workId then w = x end end
    local spot = w and w.spots[math.tointeger(tonumber(spotIndex)) or 0]
    if not spot then return false, 'failed' end
    local ped = pedOf(source)
    if not ped or #(GetEntityCoords(ped) - spot) > 4.0 then return false, 'too_far' end
    local now = os.time()
    if now - inmate.lastWork < math.max(P.workCooldown, w.seconds - 2) then return false, 'wait' end
    inmate.lastWork = now
    inmate.remaining = math.max(0, inmate.remaining - w.minutes * 60)
    if inmate.escaped then inmate.escaped = false end
    save(source, inmate)
    if inmate.remaining <= 0 then
        release(source, 'time')
        return { remaining = 0, released = true }
    end
    return { remaining = inmate.remaining }
end)

-- the prisoner's game says he is outside the grounds (faster than the server's own look)
RegisterNetEvent('exti_police:server:prisonAway', function(outside)
    local src = source
    local inmate = inmates[src]
    if not inmate then return end
    if outside and distanceFromCenter(src) > prison.radius and not isDown(src) then sendBack(src, inmate) end
end)

lib.callback.register('exti_police:server:prisonStatus', function(source)
    local inmate = inmates[source]
    if not inmate then return false end
    return { remaining = inmate.remaining, minutes = inmate.minutes, escaped = inmate.escaped == true }
end)

---------------------------------------------------------------------------
-- the tablet's Prison app
---------------------------------------------------------------------------
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
        return fn(source, ...)
    end)
end

local function inmatesView()
    local rows = MySQL.query.await('SELECT * FROM `exti_police_prison` ORDER BY `started` DESC') or {}
    local online = {}
    for src, inmate in pairs(inmates) do online[inmate.cid] = { src = src, inmate = inmate } end
    local out = {}
    for _, r in ipairs(rows) do
        local o = online[r.citizenid]
        out[#out + 1] = {
            cid = r.citizenid, name = r.name, minutes = tonumber(r.minutes) or 0, officer = r.officer, started = r.started,
            remaining = o and math.max(0, math.floor(o.inmate.remaining)) or (tonumber(r.remaining) or 0),
            escaped = o and o.inmate.escaped or tonumber(r.escaped) == 1,
            online = o ~= nil,
        }
    end
    return out
end

cb('prisonList', function(source)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    return { inmates = inmatesView() }
end)

cb('prisonRelease', function(source, cid)
    -- only an admin (/unjail) lets someone out early now
    do return false, 'admin_only' end
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if type(cid) ~= 'string' then return false, 'failed' end
    local target
    for src, inmate in pairs(inmates) do if inmate.cid == cid then target = src end end
    if target then
        release(target, 'officer')
    else
        local row = MySQL.single.await('SELECT `name` FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
        if not row then return false, 'failed' end
        MySQL.query.await('DELETE FROM `exti_police_prison` WHERE `citizenid` = ?', { cid })
        -- offline: he gets his things when he comes back (restore sees no row and empties the locker)
        POL.log(source, 'released', ('%s (إطلاق سراح من الشرطة)'):format(row.name))
    end
    lib.print.info(('[prison] %s released %s'):format(nameOf(player), cid))
    return { inmates = inmatesView() }
end)

-- an officer opens an inmate's locker (things that did not fit on release, or to check them)
cb('prisonLocker', function(source, cid)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    if type(cid) ~= 'string' or cid == '' then return false, 'failed' end
    local ok, opened = pcall(function() return exports.ox_inventory:forceOpenInventory(source, 'stash', locker(cid)) end)
    if not ok or not opened then return false, 'failed' end
    return true
end)

---------------------------------------------------------------------------
-- for the charge sheet and the others
---------------------------------------------------------------------------
POL.jail = jail
POL.isInmate = function(src) return inmates[src] ~= nil end
POL.atPrisonIntake = function(src)
    local ped = pedOf(src)
    return ped ~= nil and #(GetEntityCoords(ped) - prison.intake) <= prison.intakeRadius + 1.5
end
exports('IsJailed', function(src) return inmates[src] ~= nil end)
exports('Jail', function(src, minutes, officerName) return jail(src, minutes, officerName) end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RES then return end
    for src, inmate in pairs(inmates) do save(src, inmate) end
end)
