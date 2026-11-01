-- =====================================================================
-- EX_Tii Police (server): the shared helpers (who is an officer on duty, how close people are),
-- starting every session off duty, and cleaning up when someone leaves the job or the city.
-- server/shift.lua = clock in, cloakroom, locker, /policespots
-- server/armory.lua = the armory    server/fleet.lua = the garages    server/forms.lua = the forms
-- =====================================================================

local JOB = Config.job

local vehicles = {}   -- [source] = entity of their police vehicle
local shifts = {}     -- [source] = { start, cid, citizenid, station }
local busy = {}

local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function isCop(player)
    return player and player.PlayerData.job and player.PlayerData.job.name == JOB
end

local function onDuty(player)
    return isCop(player) and player.PlayerData.job.onduty == true
end

local function isBoss(player)
    return isCop(player) and player.PlayerData.job.isboss == true
end

local function grade(player)
    return player and player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
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
    if not ped or not coords then return false end
    return #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= dist
end

local function notify(src, kind, text)
    TriggerClientEvent('ox_lib:notify', src, { type = kind, description = text })
end

local function stationOf(name)
    return type(name) == 'string' and Config.stations[name] or nil
end

-- next to this E spot
local function nearSpot(src, coords, extra)
    return coords and near(src, coords, Config.reachPoint + (extra or 1.5)) or false
end

local function copsOnDuty()
    local ok, _, list = pcall(function() return exports.qbx_core:GetDutyCountJob(JOB) end)
    return ok and type(list) == 'table' and list or {}
end

local function gradeName(level)
    local ok, job = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    local g = ok and job and job.grades and job.grades[level]
    return g and g.name or tostring(level)
end

-- shared with the other server files
POL = POL or {}
POL.getPlayer, POL.isCop, POL.onDuty, POL.isBoss, POL.grade, POL.nameOf = getPlayer, isCop, onDuty, isBoss, grade, nameOf
POL.pedOf, POL.near, POL.nearSpot, POL.notify, POL.stationOf = pedOf, near, nearSpot, notify, stationOf
POL.copsOnDuty, POL.gradeName = copsOnDuty, gradeName
POL.vehicles, POL.shifts, POL.busy = vehicles, shifts, busy

-- our stashes are only opened by this script (after its own checks): a group nobody has stops
-- anyone opening them straight from ox_inventory
POL.NOONE = { exti_police_noone = 0 }

-- the department log (the leader reads it in Management on the tablet). amount + money: 'in' money
-- that came into the police account, 'out' money that left it (for the cash flow)
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_logs` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `at` INT NOT NULL,
        `citizenid` VARCHAR(50) NULL,
        `name` VARCHAR(80) NULL,
        `action` VARCHAR(40) NOT NULL,
        `content` VARCHAR(255) NULL,
        `amount` INT NULL,
        `money` VARCHAR(4) NULL,
        INDEX `at` (`at`)
    )]])
end)

function POL.log(src, action, content, amount, money)
    local player = src and getPlayer(src)
    MySQL.insert('INSERT INTO `exti_police_logs` (`at`, `citizenid`, `name`, `action`, `content`, `amount`, `money`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        os.time(), player and player.PlayerData.citizenid or nil, player and nameOf(player) or nil,
        tostring(action):sub(1, 40), content and tostring(content):sub(1, 255) or nil, amount and math.floor(amount) or nil, money,
    })
end

-- wait (up to 2 minutes) for ox_inventory, then run fn; again every time ox_inventory restarts
function POL.withInventory(fn, what)
    local function run()
        for _ = 1, 60 do
            if GetResourceState('ox_inventory') == 'started' and pcall(fn) then return end
            Wait(2000)
        end
        print(('^1[exti_police] could not set up %s (is ox_inventory started?)^0'):format(what))
    end
    CreateThread(run)
    AddEventHandler('onServerResourceStart', function(resource)
        if resource == 'ox_inventory' then CreateThread(function() Wait(2000) run() end) end
    end)
end

---------------------------------------------------------------------------
-- every session starts off duty (officers clock in at a station)
---------------------------------------------------------------------------
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if Config.offDutyOnLogin and isCop(player) and player.PlayerData.job.onduty then
        exports.qbx_core:SetJobDuty(player.PlayerData.source, false)
    end
end)

-- no longer an officer (fired, quit, left): the shift is logged, the vehicle goes back
local function cleanUp(src)
    if POL.endShift then POL.endShift(src) end
    shifts[src] = nil
    if POL.releaseVehicle then POL.releaseVehicle(src) end
end
POL.cleanUp = cleanUp

AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if not job or job.name ~= JOB then
        if shifts[src] or vehicles[src] then cleanUp(src) end
        -- not in the police any more (not just another main job): out of the tablet chats
        local p = getPlayer(src)
        if p and POL.leftPolice and not (p.PlayerData.jobs and p.PlayerData.jobs[JOB]) then
            CreateThread(function() pcall(POL.leftPolice, p.PlayerData.citizenid) end)
        end
        return
    end
    -- the police job was set again (a new rank, hired, /setjob): qbx puts it on duty by itself on
    -- this server, without the duty event. On duty only counts after clocking in at a station,
    -- so if there is no shift running, back off duty (a moment later, after qbx is done)
    if job.onduty and not shifts[src] then
        SetTimeout(500, function()
            local p = getPlayer(src)
            if p and onDuty(p) and not shifts[src] then exports.qbx_core:SetJobDuty(src, false) end
        end)
    end
    -- a new rank can put you off duty without the duty event: look again in a moment, and only end
    -- the shift if you really are off duty
    if not job.onduty and (shifts[src] or vehicles[src]) then
        SetTimeout(1500, function()
            local p = getPlayer(src)
            if p and isCop(p) and not p.PlayerData.job.onduty then cleanUp(src) end
        end)
    end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    cleanUp(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    cleanUp(src)
    busy[src] = nil
end)

-- a police vehicle disappeared (/dv, blown up and cleaned up...): it is back in the garage
AddEventHandler('entityRemoved', function(entity)
    for src, veh in pairs(vehicles) do
        if veh == entity then vehicles[src] = nil end
    end
    if POL.fleetGone then POL.fleetGone(entity) end
end)

-- this script stops (restart): the team's vehicles out in the city go back to the garage (their
-- fuel and damage are kept)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if POL.parkAll then pcall(POL.parkAll) end
end)
