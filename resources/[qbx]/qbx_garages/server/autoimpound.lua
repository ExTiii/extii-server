-- EX_Tii: the impound staff take away vehicles that were left alone (a vehicle nobody is in and
-- that has not moved):
--   * a player's car, owner in the city:   after ownedMinutes (30), once nobody is right next to it
--   * a player's car, owner logged out:    ownedOffline (10) minutes after he left (a window for thieves)
--   * a stolen player car the thief dumped: the same, and the owner pays only dumpedFee ($250)
--   * anything else (NPC cars someone drove, wrecks): after looseMinutes (15), nobody within 100 m
-- It goes to the impound (any impound lot, $500). Tow truck drivers (exti_jobs) can tow sooner.

local settings = Config.autoImpound or {}
local enabled = settings.enabled ~= false
local idleSeconds = math.floor((tonumber(settings.looseMinutes or settings.minutes) or 15) * 60)
local ownedSeconds = math.floor((tonumber(settings.ownedMinutes) or 30) * 60)
local offlineSeconds = math.floor((tonumber(settings.offlineMinutes) or 10) * 60)
local nobodyWithin = tonumber(settings.nobodyWithin) or 100.0
local ownedNobodyWithin = tonumber(settings.ownedNobodyWithin) or 35.0
local dumpedFee = tonumber(settings.dumpedFee) or 250
local checkEvery = math.max(10, math.floor(tonumber(settings.checkEvery) or 30))
local keepStates = settings.keepStates or { 'exti_job', 'exti_broken', 'exti_keep' }

local MOVED = 2.5 -- meters: a vehicle that moved this much since the last check counts as used
local tracked = {} -- [vehicle] = { since = os.time(), pos = vector3, owner = citizenid | false }
local leftAt = {}  -- [citizenid] = os.time() he logged out (this server session)

-- who left the city when (a car's 10 minutes start then)
local function noteLeft(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    local cid = ok and p and p.PlayerData and p.PlayerData.citizenid
    if cid then leftAt[cid] = os.time() end
end
AddEventHandler('playerDropped', function() noteLeft(source) end)
RegisterNetEvent('qbx_core:server:onPlayerUnload', function() noteLeft(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) noteLeft(tonumber(src) or source) end)

local function anyoneInside(vehicle)
    for seat = -1, 8 do
        if GetPedInVehicleSeat(vehicle, seat) ~= 0 then return true end
    end
    return false
end

local function keptByAnotherScript(vehicle)
    local state = Entity(vehicle).state
    for i = 1, #keepStates do
        if state[keepStates[i]] then return true end
    end
    return false
end

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

--- A vehicle nobody is in, nobody owns and no script looks after (used to clear a garage spot)
---@return boolean
function IsLooseVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    if anyoneInside(vehicle) or keptByAnotherScript(vehicle) then return false end
    if GetEntityAttachedTo(vehicle) ~= 0 then return false end
    return ownedVehicleId(vehicle) == nil
end

--- where an owned vehicle of this kind is kept when it is impounded
local function depotFor(modelName)
    local info = VEHICLES[modelName]
    if info and (info.category == 'helicopters' or info.category == 'planes') then return 'airdepot' end
    if info and info.category == 'boats' then return 'seadepot' end
    return 'impoundlot'
end

local function playersByBucket()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped and ped ~= 0 then
            list[#list + 1] = { coords = GetEntityCoords(ped), bucket = GetPlayerRoutingBucket(id) }
        end
    end
    return list
end

local function playerNear(coords, bucket, players, within)
    within = within or nobodyWithin
    for i = 1, #players do
        local p = players[i]
        if p.bucket == bucket and #(p.coords - coords) < within then return true end
    end
    return false
end

---@return boolean done
local function impound(vehicle, why)
    local vehicleId = ownedVehicleId(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if not vehicleId then
        DeleteEntity(vehicle)
        return true
    end

    local ok, owned = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    owned = ok and owned or nil
    if not owned then
        DeleteEntity(vehicle)
        return true
    end

    -- keep the car's condition (fuel and damage) as it was left
    local props = type(owned.props) == 'table' and owned.props or nil
    if props then
        local fuel = Entity(vehicle).state.fuel
        if type(fuel) == 'number' then props.fuelLevel = math.floor(fuel + 0.5) end
        props.bodyHealth = GetVehicleBodyHealth(vehicle)
        props.engineHealth = GetVehicleEngineHealth(vehicle)
    end

    local fee = Config.calculateImpoundFee(vehicleId, owned.modelName) or 500
    if why == 'dumped' then fee = math.min(fee, dumpedFee) end
    local depot = depotFor(owned.modelName)
    local saved = exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.IMPOUNDED,
        depotPrice = fee,
        garage = depot,
        props = props,
    })
    if not saved then return false end
    exports.qbx_core:DeleteVehicle(vehicle)

    local owner = owned.citizenid and exports.qbx_core:GetPlayerByCitizenId(owned.citizenid)
    if owner then
        local msg = why == 'dumped'
            and ('وُجدت سيارتك المسروقة (%s) متروكة ونُقلت إلى ساحة الحجز. استلمها من أي ساحة حجز مقابل %s$ فقط'):format(plate:match('^%s*(.-)%s*$'), fee)
            or ('نقل موظفو الحجز مركبتك (%s) إلى ساحة الحجز لأنها تُركت أكثر من %d دقيقة. استلمها من أي ساحة حجز مقابل %s$'):format(
                plate:match('^%s*(.-)%s*$'), math.floor(ownedSeconds / 60), fee)
        exports.qbx_core:Notify(owner.PlayerData.source, msg, 'inform', 12000)
    end
    lib.print.info(('[auto impound] %s (id %s) -> %s%s'):format(plate, vehicleId, depot, why and (' · ' .. why) or ''))
    return true
end

--- EX_Tii: a player's own car left on a garage car spot while its owner is not in the city goes
--- to the impound, so the spot is free again (the owner pays the impound fee to get it back).
---@return boolean impounded
function ImpoundIfOwnerAway(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    if anyoneInside(vehicle) or keptByAnotherScript(vehicle) or GetEntityAttachedTo(vehicle) ~= 0 then return false end
    local vehicleId = ownedVehicleId(vehicle)
    if not vehicleId then return false end
    local ok, owned = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    if not ok or not owned or not owned.citizenid then return false end
    if exports.qbx_core:GetPlayerByCitizenId(owned.citizenid) then return false end -- the owner is in the city
    local done, result = pcall(impound, vehicle)
    if not done then lib.print.error('[spot impound] ' .. tostring(result)) end
    return done and result == true
end

local function check(forceSeconds)
    local now = os.time()
    local limit = forceSeconds or idleSeconds
    local players = playersByBucket()
    local seen = {}
    for _, vehicle in ipairs(GetAllVehicles()) do
        seen[vehicle] = true
        local skip = GetVehicleType(vehicle) == 'train'
            or GetEntityRoutingBucket(vehicle) ~= 0
            or GetEntityAttachedTo(vehicle) ~= 0
            or keptByAnotherScript(vehicle)
        if skip then
            tracked[vehicle] = nil
        else
            local coords = GetEntityCoords(vehicle)
            local t = tracked[vehicle]
            if not t or anyoneInside(vehicle) or #(coords - t.pos) > MOVED then
                tracked[vehicle] = { since = now, pos = coords, owner = t and t.owner }
            else
                -- whose is it (looked up once per vehicle)
                if t.owner == nil then
                    local vid = ownedVehicleId(vehicle)
                    local ok, owned = false, nil
                    if vid then ok, owned = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vid) end) end
                    t.owner = (ok and owned and owned.citizenid) or false
                end
                local idle, need, near, why = now - t.since, limit, nobodyWithin, nil
                if t.owner and not forceSeconds then
                    near = ownedNobodyWithin
                    local thief = Entity(vehicle).state.exti_thief
                    if thief and thief ~= t.owner then why = 'dumped' end
                    local online = exports.qbx_core:GetPlayerByCitizenId(t.owner) ~= nil
                    if online then
                        need = ownedSeconds
                    else
                        -- (10 minutes from when he left, or from when it was left if that was later)
                        idle = now - math.max(t.since, leftAt[t.owner] or 0)
                        need = offlineSeconds
                    end
                end
                if idle >= need and not playerNear(coords, 0, players, near) then
                    local ok, done = pcall(impound, vehicle, why)
                    if not ok then lib.print.error('[auto impound] ' .. tostring(done)) end
                    if ok and done then tracked[vehicle] = nil end
                end
            end
        end
    end
    for vehicle in pairs(tracked) do
        if not seen[vehicle] then tracked[vehicle] = nil end
    end
end

if enabled then
    CreateThread(function()
        Wait(5000)
        while true do
            local ok, err = pcall(check)
            if not ok then lib.print.error('[auto impound] ' .. tostring(err)) end
            Wait(checkEvery * 1000)
        end
    end)
end

-- admins, for testing: /autoimpound 0 -> takes every vehicle left alone for 0 minutes now
-- (only vehicles nobody is near, as always). /autoimpound alone runs a normal check.
lib.addCommand('autoimpound', {
    help = 'حجز المركبات المتروكة الآن (للإدارة)',
    params = { { name = 'minutes', type = 'number', help = 'كم دقيقة تُركت المركبة على الأقل', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    local minutes = tonumber(args.minutes)
    local ok, err = pcall(check, minutes and math.max(0, math.floor(minutes * 60)) or nil)
    if not ok then lib.print.error('[auto impound] ' .. tostring(err)) end
    exports.qbx_core:Notify(source, ok and 'تم فحص المركبات المتروكة' or 'حدث خطأ أثناء الفحص', ok and 'success' or 'error')
end)
