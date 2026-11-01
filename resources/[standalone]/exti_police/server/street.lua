-- =====================================================================
-- EX_Tii Police (server): the street. An officer on duty, next to a person (Z wheel → الشرطة):
-- cuff / uncuff (needs the handcuffs item), escort, put in a vehicle / take out, search the bag,
-- seize the guns and ammo (they go to the station's seized items room).
-- The person's side (the cuffed animation, the escort attach, getting in the car) is done by
-- that person's game: the server only decides and tells both sides.
-- =====================================================================

local S = Config.street
local getPlayer, onDuty, pedOf, notify = POL.getPlayer, POL.onDuty, POL.pedOf, POL.notify

local cuffed = {}      -- [src] = true
local escorting = {}   -- [copSrc] = targetSrc
local escortedBy = {}  -- [targetSrc] = copSrc
local busy = {}        -- [src] = true while cuffing / uncuffing runs

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function state(src) return Player(src) and Player(src).state end

local function coordsOf(src)
    local ped = pedOf(src)
    return ped and GetEntityCoords(ped) or nil
end

local function distance(a, b)
    local ca, cb = coordsOf(a), coordsOf(b)
    if not ca or not cb then return math.huge end
    return #(ca - cb)
end

local function inVehicle(src)
    local ped = pedOf(src)
    local veh = ped and GetVehiclePedIsIn(ped, false) or 0
    return veh ~= 0 and veh or nil
end

local function isDown(src)
    local st = state(src)
    local ds = st and st['qbx_medical:deathState']
    return ds ~= nil and ds ~= 1
end

-- the state bags the person's game and ox_inventory watch
local function setBags(src, on)
    local st = state(src)
    if not st then return end
    st:set('cuffed', on and true or false, true)
    -- ox_inventory: no bag, no hotkeys, no weapon in hand while cuffed
    st:set('canUseWeapons', not on, true)
    st:set('invBusy', on and true or false, true)
    st:set('invHotkeys', not on, true)
end

local function setCuffed(src, on)
    cuffed[src] = on or nil
    setBags(src, on)
    local player = getPlayer(src)
    if player then player.Functions.SetMetaData('ishandcuffed', on and true or false) end
end

local function stopEscort(copSrc, quiet)
    local target = escorting[copSrc]
    if not target then return end
    escorting[copSrc], escortedBy[target] = nil, nil
    local cs, ts = state(copSrc), state(target)
    if cs then cs:set('escorting', false, true) end
    if ts then ts:set('escortedBy', false, true) end
    if not quiet then
        notify(target, 'inform', 'تركك الشرطي')
    end
end

local function startEscort(copSrc, target)
    escorting[copSrc], escortedBy[target] = target, copSrc
    local cs, ts = state(copSrc), state(target)
    if cs then cs:set('escorting', target, true) end
    if ts then ts:set('escortedBy', copSrc, true) end
    notify(target, 'inform', 'الشرطي يصطحبك')
end

-- the officer and the person: both here, the officer on duty, the person close enough
local function pair(copSrc, targetId)
    local cop = getPlayer(copSrc)
    if not onDuty(cop) then return nil, nil, 'off_duty' end
    local tid = math.tointeger(tonumber(targetId))
    if not tid or tid == copSrc then return nil, nil, 'nobody' end
    local target = getPlayer(tid)
    if not target or not pedOf(tid) then return nil, nil, 'nobody' end
    local reach = escorting[copSrc] == tid and S.vehicleReach + 1.0 or S.reach + 0.8
    if distance(copSrc, tid) > reach then return nil, nil, 'too_far' end
    if inVehicle(copSrc) then return nil, nil, 'in_vehicle' end
    return cop, target, nil
end

---------------------------------------------------------------------------
-- cuff / uncuff
---------------------------------------------------------------------------
local function hasCuffs(src)
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', S.cuffItem) end)
    return ok and (tonumber(count) or 0) > 0
end

local function cuff(copSrc, tid)
    if busy[copSrc] or busy[tid] then return false, 'busy' end
    if inVehicle(copSrc) or inVehicle(tid) then return false, 'in_vehicle' end
    local turningOn = not cuffed[tid]
    if turningOn and isDown(tid) then return false, 'down' end
    if turningOn and not hasCuffs(copSrc) then return false, 'no_cuffs' end

    busy[copSrc], busy[tid] = true, true
    TriggerClientEvent('exti_police:client:cuffAnim', copSrc, 'cop', turningOn, tid)
    TriggerClientEvent('exti_police:client:cuffAnim', tid, 'crook', turningOn, copSrc)
    SetTimeout(math.floor(S.cuffSeconds * 1000), function()
        busy[copSrc], busy[tid] = nil, nil
        -- the person ran off while the officer was busy: nothing happens
        if not pedOf(tid) or distance(copSrc, tid) > S.reach + 2.0 then
            notify(copSrc, 'error', 'ابتعد عنك')
            TriggerClientEvent('exti_police:client:cuffAnim', copSrc, 'cop', nil)
            TriggerClientEvent('exti_police:client:cuffAnim', tid, 'crook', nil)
            return
        end
        if turningOn then
            setCuffed(tid, true)
            notify(tid, 'inform', 'تم تقييدك')
            notify(copSrc, 'success', 'تم تقييده')
        else
            if escortedBy[tid] then stopEscort(escortedBy[tid], true) end
            setCuffed(tid, false)
            notify(tid, 'inform', 'فُكّ قيدك')
            notify(copSrc, 'success', 'فككت قيده')
        end
        lib.logger(copSrc, 'police', ('%s player %d'):format(turningOn and 'cuffed' or 'uncuffed', tid))
    end)
    return true, nil, { on = turningOn, seconds = S.cuffSeconds }
end

---------------------------------------------------------------------------
-- escort
---------------------------------------------------------------------------
local function escort(copSrc, tid)
    if escorting[copSrc] == tid then
        stopEscort(copSrc)
        return true, nil, { on = false }
    end
    if escorting[copSrc] then return false, 'escorting' end
    if not cuffed[tid] then return false, 'not_cuffed' end
    if escortedBy[tid] and escortedBy[tid] ~= copSrc then return false, 'taken' end
    if inVehicle(copSrc) or inVehicle(tid) then return false, 'in_vehicle' end
    if busy[tid] then return false, 'busy' end
    if isDown(tid) then return false, 'down' end
    startEscort(copSrc, tid)
    return true, nil, { on = true }
end

---------------------------------------------------------------------------
-- in / out of a vehicle
---------------------------------------------------------------------------
local function vehicleIn(copSrc, tid, netId)
    if not cuffed[tid] then return false, 'not_cuffed' end
    if inVehicle(tid) then return false, 'in_vehicle' end
    if isDown(tid) then return false, 'down' end
    local veh = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, 'no_vehicle' end
    local vc = GetEntityCoords(veh)
    local cc = coordsOf(copSrc)
    if not cc or #(cc - vc) > S.vehicleReach + 1.0 then return false, 'no_vehicle' end
    if escortedBy[tid] then stopEscort(escortedBy[tid], true) end
    TriggerClientEvent('exti_police:client:enterVehicle', tid, netId)
    notify(tid, 'inform', 'وضعك الشرطي في المركبة')
    return true
end

local function vehicleOut(copSrc, tid)
    local veh = inVehicle(tid)
    if not veh then return false, 'not_in_vehicle' end
    local cc = coordsOf(copSrc)
    if not cc or #(cc - GetEntityCoords(veh)) > S.vehicleReach + 1.0 then return false, 'too_far' end
    TriggerClientEvent('exti_police:client:leaveVehicle', tid)
    notify(tid, 'inform', 'أخرجك الشرطي من المركبة')
    return true
end

---------------------------------------------------------------------------
-- search the bag (ox_inventory opens it for the police job) / seize the guns
---------------------------------------------------------------------------
local function search(copSrc, tid)
    local ok, opened = pcall(function() return exports.ox_inventory:forceOpenInventory(copSrc, 'player', tid) end)
    if not ok or not opened then return false, 'failed' end
    notify(tid, 'inform', 'الشرطي يفتّش حقيبتك')
    lib.logger(copSrc, 'police', ('searched player %d'):format(tid))
    return true
end

local function isWeaponOrAmmo(name)
    return name:sub(1, 7) == 'WEAPON_' or name:sub(1, 5) == 'ammo-'
end

local function seize(copSrc, tid)
    if not cuffed[tid] then return false, 'not_cuffed' end
    if busy[tid] then return false, 'busy' end
    local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(tid) end)
    if not ok or type(items) ~= 'table' then return false, 'failed' end
    -- our own list first: the bag's table changes while items move
    local list = {}
    for _, it in pairs(items) do
        if it and type(it.name) == 'string' and isWeaponOrAmmo(it.name) and (it.count or 0) > 0 then
            list[#list + 1] = { name = it.name, count = it.count, slot = it.slot, metadata = it.metadata }
        end
    end
    if #list == 0 then return false, 'nothing' end
    busy[tid] = true
    local moved, names = 0, {}
    for _, it in ipairs(list) do
        local ok1, removed = pcall(function()
            return exports.ox_inventory:RemoveItem(tid, it.name, it.count, nil, it.slot)
        end)
        if ok1 and removed then
            local ok2, added = pcall(function()
                return exports.ox_inventory:AddItem(S.seized.id, it.name, it.count, it.metadata)
            end)
            if ok2 and added then
                moved = moved + 1
                names[#names + 1] = ('%dx %s'):format(it.count, it.name)
            else
                -- the room is full: back into the bag
                pcall(function() exports.ox_inventory:AddItem(tid, it.name, it.count, it.metadata) end)
            end
        end
    end
    busy[tid] = nil
    if moved == 0 then return false, 'nothing' end
    local target = getPlayer(tid)
    POL.log(copSrc, 'seize', ('%s: %s'):format(POL.nameOf(target), table.concat(names, ', ')))
    lib.logger(copSrc, 'police', ('seized from player %d: %s'):format(tid, table.concat(names, ', ')))
    notify(tid, 'inform', 'صادر الشرطي أسلحتك')
    return true, nil, { count = moved }
end

---------------------------------------------------------------------------
-- the one callback the officer's game calls
---------------------------------------------------------------------------
lib.callback.register('exti_police:server:street', function(source, action, targetId, extra)
    local _, _, err = pair(source, targetId)
    if err then return false, err end
    local tid = math.tointeger(tonumber(targetId))
    if action == 'cuff' then return cuff(source, tid) end
    if action == 'escort' then return escort(source, tid) end
    if action == 'vehicleIn' then return vehicleIn(source, tid, math.tointeger(tonumber(extra))) end
    if action == 'vehicleOut' then return vehicleOut(source, tid) end
    if action == 'search' then return search(source, tid) end
    if action == 'seize' then return seize(source, tid) end
    return false, 'failed'
end)

-- the escorted person's game lost the officer (he vanished): let go
RegisterNetEvent('exti_police:server:lostEscort', function()
    local src = source
    local cop = escortedBy[src]
    if not cop then return end
    if pedOf(cop) and distance(cop, src) < 5.0 then return end -- he is right there: no letting go
    stopEscort(cop, true)
end)

-- the escorted person goes down: let go (a body is not dragged)
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    if value == 1 then return end
    local src = GetPlayerFromStateBagName(bagName)
    if src and src ~= 0 and escortedBy[src] then stopEscort(escortedBy[src], true) end
end)

-- the officer got into a vehicle / died while escorting: let go
RegisterNetEvent('exti_police:server:dropEscort', function()
    local src = source
    if escorting[src] then stopEscort(src) end
end)

---------------------------------------------------------------------------
-- the seized items room (the evidence spot of a station)
---------------------------------------------------------------------------
POL.withInventory(function()
    exports.ox_inventory:RegisterStash(S.seized.id, S.seized.label, S.seized.slots, S.seized.weight, nil, POL.NOONE)
end, 'the seized items room')

---------------------------------------------------------------------------
-- no stealing with the badge:
--  * anything an officer takes out of a citizen's bag (a search) goes to the seized items room, never
--    into his own pockets, a car, a stash or the ground; it is written in the log
--  * an officer cannot drop his own item ON a citizen's item (a swap would hand him the citizen's)
--  * only the chief takes things out of the seized items room (logged); every officer can put in
---------------------------------------------------------------------------
local function itemText(slot, count)
    return ('%dx %s'):format(count or (slot and slot.count) or 1, slot and (slot.label or slot.name) or '?')
end

local function toSeized(copSrc, fromSrc, slot, count)
    count = math.max(1, math.floor(tonumber(count) or slot.count or 1))
    local okR, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(fromSrc, slot.name, count, nil, slot.slot)
    end)
    if not okR or not removed then return notify(copSrc, 'error', 'تعذّر نقل الغرض، حاول مرة أخرى') end
    local okA, added = pcall(function()
        return exports.ox_inventory:AddItem(S.seized.id, slot.name, count, slot.metadata)
    end)
    if not okA or not added then
        -- the room is full: back into the citizen's bag
        pcall(function() exports.ox_inventory:AddItem(fromSrc, slot.name, count, slot.metadata) end)
        return notify(copSrc, 'error', 'غرفة المصادرات ممتلئة')
    end
    local target = getPlayer(fromSrc)
    local what = itemText(slot, count)
    POL.log(copSrc, 'seize', ('%s: %s'):format(target and POL.nameOf(target) or fromSrc, what))
    lib.logger(copSrc, 'police', ('searched player %d: %s went to the seized room'):format(fromSrc, what))
    notify(copSrc, 'inform', ('أُرسل إلى غرفة المصادرات: %s'):format(what))
    notify(fromSrc, 'inform', ('صادرت الشرطة منك: %s'):format(what))
end

POL.withInventory(function()
    exports.ox_inventory:registerHook('swapItems', function(p)
        local src = tonumber(p.source)
        if not src then return true end
        if p.fromInventory == p.toInventory then return true end -- tidying one bag
        local player = getPlayer(src)
        if not player or not POL.isCop(player) then return true end

        -- out of another player's bag (a search): to the seized room instead
        local fromId = p.fromType == 'player' and tonumber(p.fromInventory) or nil
        if fromId and fromId ~= src and type(p.fromSlot) == 'table' and p.fromSlot.name then
            local slot = { name = p.fromSlot.name, slot = p.fromSlot.slot, count = p.fromSlot.count, metadata = p.fromSlot.metadata, label = p.fromSlot.label }
            local count = tonumber(p.count) or slot.count
            SetTimeout(0, function() toSeized(src, fromId, slot, count) end)
            return false
        end

        -- my item dropped onto a citizen's item: that swap would give me his
        local toId = p.toType == 'player' and tonumber(p.toInventory) or nil
        if toId and toId ~= src and p.action == 'swap' then
            notify(src, 'error', 'ضع الغرض في خانة فارغة')
            return false
        end

        -- the seized items room: everyone puts in, only the chief takes out
        if p.fromInventory == S.seized.id then
            if not POL.isBoss(player) then
                notify(src, 'error', 'فقط قائد الشرطة يأخذ من غرفة المصادرات')
                return false
            end
            local what = type(p.fromSlot) == 'table' and itemText(p.fromSlot, tonumber(p.count)) or '?'
            POL.log(src, 'seized_taken', what)
            lib.logger(src, 'police', ('took %s from the seized room'):format(what))
            return true
        end
        if p.toInventory == S.seized.id and p.action == 'swap' and not POL.isBoss(player) then
            -- a swap would take the room's item out
            notify(src, 'error', 'ضع الغرض في خانة فارغة')
            return false
        end
        return true
    end, {})
end, 'the search and seized room rules')

lib.callback.register('exti_police:server:openSeized', function(source, station)
    local player = getPlayer(source)
    local st = POL.stationOf(station)
    if not onDuty(player) then return false, 'off_duty' end
    if not st or not st.evidence or not POL.nearSpot(source, st.evidence) then return false, 'too_far' end
    local ok, opened = pcall(function() return exports.ox_inventory:forceOpenInventory(source, 'stash', S.seized.id) end)
    if not ok or not opened then return false, 'failed' end
    return true
end)

---------------------------------------------------------------------------
-- joining, leaving, dying
---------------------------------------------------------------------------
-- still cuffed from last time (no escaping by leaving the city)
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    if player.PlayerData.metadata and player.PlayerData.metadata.ishandcuffed then
        SetTimeout(1500, function()
            if getPlayer(src) then setCuffed(src, true) end
        end)
    end
end)

local function gone(src)
    if escorting[src] then stopEscort(src) end
    if escortedBy[src] then stopEscort(escortedBy[src], true) end
    cuffed[src], busy[src] = nil, nil
end

AddEventHandler('playerDropped', function() gone(source) end)
-- character switch: the bags go back to normal for the next character (the cuffs themselves stay
-- in the old character's metadata and come back when he logs in again)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    gone(src)
    setBags(src, false)
end)

-- woke up at the hospital: the cuffs are off
AddEventHandler('qbx_medical:server:playerRespawned', function(src)
    if escortedBy[src] then stopEscort(escortedBy[src], true) end
    if cuffed[src] then setCuffed(src, false) end
end)

-- off duty / out of the police: whoever he was escorting is let go
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if escorting[src] and not (job and job.name == Config.job and job.onduty) then stopEscort(src) end
end)

-- this script stops: everyone is let go (cuffs stay: they are in the metadata and come back on restart)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for cop in pairs(escorting) do stopEscort(cop, true) end
    for src in pairs(cuffed) do setBags(src, false) end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetTimeout(2000, function()
        for _, src in ipairs(GetPlayers()) do
            local id = tonumber(src)
            local player = id and getPlayer(id)
            if player and player.PlayerData.metadata and player.PlayerData.metadata.ishandcuffed then setCuffed(id, true) end
        end
    end)
end)

POL.isCuffed = function(src) return cuffed[src] == true end
-- the prison takes the cuffs off at the gate
POL.uncuff = function(src)
    if escortedBy[src] then stopEscort(escortedBy[src], true) end
    if escorting[src] then stopEscort(src, true) end
    busy[src] = nil
    if cuffed[src] then setCuffed(src, false) end
end
exports('IsCuffed', function(src) return cuffed[src] == true end)
