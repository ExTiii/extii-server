-- =====================================================================
-- EX_Tii heists (game side): NPC security, "حراسة الحي" (no-police mode).
-- The server says when, where, how many and who they want. One robber's game (the "owner") drives the
-- units: they drive in with lights, stop short of the door, get out, take cover behind their cars and
-- fight. Run in a car and they chase you. Out of their sight for 60 s and they lose you.
-- Every hunted robber sees the units as red dots on the map and a bar at the top: how long until they
-- come, or how long until they lose you.
-- =====================================================================
local C = Config
local N = C.npc
local REL = `EXTI_NPCSEC`
AddRelationshipGroup('EXTI_NPCSEC')
SetRelationshipBetweenGroups(3, REL, `PLAYER`)   -- neutral: they only fight who the task names
SetRelationshipBetweenGroups(3, `PLAYER`, REL)
SetRelationshipBetweenGroups(0, REL, REL)

local hunt = nil      -- what I see: { id, phase = 'coming'|'on', arriveAt, lastSeen, lostSent, downSent }
local own = nil       -- what my game drives: { id, units = { {veh, peds = {}} }, targets = {src}, pos }
local blips = {}

---------------------------------------------------------------------------
-- the bar at the top (html/hhud.js)
---------------------------------------------------------------------------
local function bar(state) SendNUIMessage({ action = 'hud', state = state }) end
function HC.hunted() return hunt ~= nil end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function pedOfServerId(s)
    local pl = GetPlayerFromServerId(s)
    if pl == -1 then return nil end
    local ped = GetPlayerPed(pl)
    return ped ~= 0 and ped or nil
end

local function unitPeds()
    local out = {}
    if not hunt then return out end
    for _, ped in ipairs(GetGamePool('CPed')) do
        local st = Entity(ped).state.exti_npcsec
        if st == hunt.id and not IsPedDeadOrDying(ped, true) then out[#out + 1] = ped end
    end
    return out
end

local function clearBlips()
    for ent, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end blips[ent] = nil end
end

local function spawnPoint(pos, i)
    -- a road node 160-260 m away, in a different direction for each car, out of the robber's sight if we can
    for _ = 1, 12 do
        local a = math.rad(math.random(0, 359) + i * 97)
        local d = math.random(math.floor(N.spawnDistance[1]), math.floor(N.spawnDistance[2]))
        local try = vec3(pos.x + math.cos(a) * d, pos.y + math.sin(a) * d, pos.z)
        local ok, node, heading = GetClosestVehicleNodeWithHeading(try.x, try.y, try.z, 1, 3.0, 0)
        if ok and #(node - pos) > N.spawnDistance[1] * 0.7 then return node, heading end
    end
    return vec3(pos.x + 150.0, pos.y, pos.z), 0.0
end

local function setupPed(ped, weapon)
    SetPedRelationshipGroupHash(ped, REL)
    SetPedArmour(ped, 50)
    SetPedAccuracy(ped, N.accuracy)
    SetPedCombatAbility(ped, 1)
    SetPedCombatMovement(ped, 1)          -- defensive: hold the line, don't rush in
    SetPedCombatRange(ped, 1)
    SetPedCombatAttributes(ped, 0, true)  -- use cover
    SetPedCombatAttributes(ped, 1, true)  -- use vehicles
    SetPedCombatAttributes(ped, 5, true)  -- fight armed peds when not armed
    SetPedCombatAttributes(ped, 46, true) -- always fight
    SetPedCanSwitchWeapon(ped, false)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedSuffersCriticalHits(ped, true)
    SetCanAttackFriendly(ped, false, false)
    SetPedKeepTask(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    GiveWeaponToPed(ped, joaat(weapon or 'WEAPON_PISTOL'), 250, false, true)
    Entity(ped).state:set('exti_npcsec', own.id, true)
end

---------------------------------------------------------------------------
-- spawning (the owner's game)
---------------------------------------------------------------------------
local function spawnUnits(id, pos, cars, weapons)
    local vehModel, pedModel = joaat(N.car), joaat(N.ped)
    if not pcall(lib.requestModel, vehModel, 10000) or not pcall(lib.requestModel, pedModel, 10000) then return end
    local netIds = {}
    for i = 1, cars do
        local p, h = spawnPoint(pos, i)
        local veh = CreateVehicle(vehModel, p.x, p.y, p.z + 0.5, h, true, false)
        if veh ~= 0 then
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleOnGroundProperly(veh)
            SetVehicleSiren(veh, true)
            SetVehicleHasMutedSirens(veh, false)
            SetVehicleDoorsLocked(veh, 1)
            SetVehicleEngineOn(veh, true, true, false)
            Entity(veh).state:set('exti_npcsec', id, true)
            local unit = { veh = veh, peds = {}, stage = 'drive' }
            for seat = -1, 0 do
                local ped = CreatePedInsideVehicle(veh, 4, pedModel, seat, true, false)
                if ped ~= 0 then setupPed(ped, weapons[(seat + 2)] or weapons[1]); unit.peds[#unit.peds + 1] = ped; netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(ped) end
            end
            -- stop short of the door, a little to the side of it
            local a = math.rad(math.random(0, 359))
            unit.park = vec3(pos.x + math.cos(a) * (12.0 + i * 4.0), pos.y + math.sin(a) * (12.0 + i * 4.0), pos.z)
            local drv = unit.peds[1]
            if drv then TaskVehicleDriveToCoordLongrange(drv, veh, unit.park.x, unit.park.y, unit.park.z, 32.0, 786468, 8.0) end
            unit.since = GetGameTimer()
            own.units[#own.units + 1] = unit
            netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(veh)
        end
    end
    SetModelAsNoLongerNeeded(vehModel); SetModelAsNoLongerNeeded(pedModel)
    TriggerServerEvent('exti_heists:server:npcSpawned', id, netIds)
end

---------------------------------------------------------------------------
-- the units' brain (the owner's game, every second)
---------------------------------------------------------------------------
local function nearestTarget(from)
    local best, bd
    for _, s in ipairs(own.targets) do
        local tp = pedOfServerId(s)
        if tp and not IsPedDeadOrDying(tp, true) then
            local d = #(GetEntityCoords(tp) - from)
            if not bd or d < bd then best, bd = tp, d end
        end
    end
    return best, bd
end

local function holdUnits(u, alive, tgt)
    -- (they aim, they don't shoot, they don't chase; pulled back = they sit in their cars)
    if u.holding then return end
    u.holding = true
    for i, ped in ipairs(alive) do
        ClearPedTasks(ped)
        if own.pullBack and DoesEntityExist(u.veh) and IsVehicleDriveable(u.veh, false) then
            TaskEnterVehicle(ped, u.veh, 10000, i == 1 and -1 or 0, 1.2, 1, 0)
        elseif tgt then
            TaskAimGunAtEntity(ped, tgt, -1, false)
        end
    end
end

local function think()
    local holding = (own.holdUntil or 0) > GetGameTimer()
    for _, u in ipairs(own.units) do
        for _, e in ipairs(u.peds) do if DoesEntityExist(e) and not NetworkHasControlOfEntity(e) then NetworkRequestControlOfEntity(e) end end
        if u.veh and DoesEntityExist(u.veh) and not NetworkHasControlOfEntity(u.veh) then NetworkRequestControlOfEntity(u.veh) end
        local veh = u.veh
        local alive = {}
        for _, ped in ipairs(u.peds) do if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then alive[#alive + 1] = ped end end
        if #alive > 0 then
            local here = GetEntityCoords(alive[1])
            local tgt, dist = nearestTarget(here)
            if holding and u.stage ~= 'drive' then
                holdUnits(u, alive, tgt)
            elseif u.holding then
                -- the hold is over: back to work
                u.holding = false; u.target = nil; u.chasing = nil; u.shooting = nil
                if u.stage == 'chase' then u.stage = 'fight' end
                for _, ped in ipairs(alive) do if IsPedInVehicle(ped, u.veh, false) then TaskLeaveVehicle(ped, u.veh, 256) end end
            elseif tgt then
                local tgtCar = GetVehiclePedIsIn(tgt, false)
                if u.stage == 'drive' then
                    -- arrived (or stuck for 45 s): out and into cover
                    if (DoesEntityExist(veh) and #(GetEntityCoords(veh) - u.park) < 14.0) or GetGameTimer() - u.since > 45000 or (dist and dist < 30.0) then
                        u.stage = 'fight'
                        if DoesEntityExist(veh) then SetVehicleSiren(veh, true); TaskVehicleTempAction(alive[1], veh, 27, 1500) end
                        for _, ped in ipairs(alive) do TaskLeaveVehicle(ped, veh, 256); u.target = nil end
                    end
                elseif u.stage == 'fight' then
                    if tgtCar ~= 0 and dist > 35.0 and DoesEntityExist(veh) and IsVehicleDriveable(veh, false) then
                        -- he drives off: back in the car and after him
                        u.stage = 'chase'
                        for seat, ped in ipairs(alive) do TaskEnterVehicle(ped, veh, 8000, seat - 2, 2.0, 1, 0) end
                    elseif u.target ~= tgt then
                        u.target = tgt
                        for _, ped in ipairs(alive) do ClearPedTasks(ped); TaskCombatPed(ped, tgt, 0, 16) end
                    end
                elseif u.stage == 'chase' then
                    local drv = GetPedInVehicleSeat(veh, -1)
                    if drv ~= 0 and u.chasing ~= tgt then u.chasing = tgt; TaskVehicleChase(drv, tgt); SetTaskVehicleChaseBehaviorFlag(drv, 1, true) end
                    for _, ped in ipairs(alive) do
                        if ped ~= drv and IsPedInVehicle(ped, veh, false) and u.shooting ~= tgt then TaskDriveBy(ped, tgt, 0, 0.0, 0.0, 0.0, 60.0, 30, false, `FIRING_PATTERN_BURST_FIRE_DRIVEBY`) end
                    end
                    u.shooting = tgt
                    if tgtCar == 0 and dist < 30.0 then
                        u.stage = 'fight'; u.target = nil; u.chasing = nil; u.shooting = nil
                        for _, ped in ipairs(alive) do TaskLeaveVehicle(ped, veh, 256) end
                    end
                end
            end
        end
    end
end

local function cleanUp(drive)
    if not own then return end
    local units = own.units
    own = nil
    for _, u in ipairs(units) do
        local veh = u.veh
        local peds = u.peds
        if drive and DoesEntityExist(veh) and IsVehicleDriveable(veh, false) then
            -- they get back in and drive off, then go away
            for seat, ped in ipairs(peds) do if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then ClearPedTasks(ped); TaskEnterVehicle(ped, veh, 10000, seat - 2, 1.5, 1, 0) end end
            SetTimeout(10000, function()
                local drv = GetPedInVehicleSeat(veh, -1)
                if drv ~= 0 then SetVehicleSiren(veh, false); TaskVehicleDriveWander(drv, veh, 20.0, 786603) end
            end)
            SetTimeout(30000, function()
                for _, ped in ipairs(peds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
                if DoesEntityExist(veh) then DeleteEntity(veh) end
            end)
        else
            for _, ped in ipairs(peds) do if DoesEntityExist(ped) then SetEntityAsNoLongerNeeded(ped) end end
            if DoesEntityExist(veh) then SetEntityAsNoLongerNeeded(veh) end
        end
    end
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
RegisterNetEvent('exti_heists:client:npcIncoming', function(id, delay)
    hunt = { id = id, phase = 'coming', arriveAt = GetGameTimer() + delay * 1000 }
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
    bar({ kind = 'coming', seconds = delay })
end)

RegisterNetEvent('exti_heists:client:npcSpawn', function(id, pos, cars, targets, weapons)
    if not hunt or hunt.id ~= id then hunt = { id = id } end
    hunt.phase, hunt.lastSeen, hunt.onAt = 'on', nil, GetGameTimer()
    own = { id = id, units = {}, targets = targets, pos = vec3(pos.x, pos.y, pos.z) }
    CreateThread(function() spawnUnits(id, own.pos, cars, weapons or { 'WEAPON_PISTOL' }) end)
end)

RegisterNetEvent('exti_heists:client:npcHunted', function(id)
    if not hunt or hunt.id ~= id then hunt = { id = id } end
    hunt.phase, hunt.lastSeen, hunt.onAt = 'on', nil, GetGameTimer()
end)

RegisterNetEvent('exti_heists:client:npcTargets', function(id, targets)
    if own and own.id == id then own.targets = targets; for _, u in ipairs(own.units) do u.target = nil; u.chasing = nil; u.shooting = nil end end
end)

RegisterNetEvent('exti_heists:client:npcTakeOver', function(id, netIds, targets, pos)
    own = { id = id, units = {}, targets = targets, pos = vec3(pos.x, pos.y, pos.z) }
    local byVeh = {}
    for _, n in ipairs(netIds) do
        local ent = NetworkGetEntityFromNetworkId(n)
        if ent ~= 0 and DoesEntityExist(ent) then
            NetworkRequestControlOfEntity(ent)
            if IsEntityAVehicle(ent) then byVeh[ent] = byVeh[ent] or { veh = ent, peds = {}, stage = 'fight', since = GetGameTimer(), park = own.pos } end
        end
    end
    for _, n in ipairs(netIds) do
        local ent = NetworkGetEntityFromNetworkId(n)
        if ent ~= 0 and IsEntityAPed(ent) then
            local veh = GetVehiclePedIsIn(ent, true)
            local u = byVeh[veh]
            if not u then u = { veh = veh, peds = {}, stage = 'fight', since = GetGameTimer(), park = own.pos }; byVeh[veh] = u end
            u.peds[#u.peds + 1] = ent
        end
    end
    for _, u in pairs(byVeh) do own.units[#own.units + 1] = u end
end)

-- the server: hold your fire for this long (hostages, a deal, pulled back)
RegisterNetEvent('exti_heists:client:npcHold', function(id, seconds, why)
    if not own or own.id ~= id then return end
    local untilT = GetGameTimer() + math.max(0, seconds) * 1000
    if why == 'pullback' then own.pullUntil = untilT end
    own.holdUntil = math.max(own.holdUntil or 0, untilT)
    own.pullBack = (own.pullUntil or 0) > GetGameTimer()
    for _, u in ipairs(own.units) do u.holding = false end
end)
RegisterNetEvent('exti_heists:client:npcPullBack', function(id)
    if own and own.id == id then own.pullBack = true; for _, u in ipairs(own.units) do u.holding = false end end
end)
-- a hostage was hurt: no hold, sharper, pushing in
RegisterNetEvent('exti_heists:client:npcRage', function(id)
    if not own or own.id ~= id then return end
    own.holdUntil, own.pullBack, own.pullUntil, own.rage = 0, false, 0, true
    for _, u in ipairs(own.units) do
        u.holding = false; u.target = nil
        for _, ped in ipairs(u.peds) do
            if DoesEntityExist(ped) then SetPedAccuracy(ped, C.hostages.rageAccuracy); SetPedCombatMovement(ped, 2); SetPedCombatAbility(ped, 2) end
        end
    end
end)
-- every hunted robber: the bar says they hold their fire
RegisterNetEvent('exti_heists:client:npcHoldBar', function(id, seconds, why)
    if not hunt or hunt.id ~= id then return end
    if why == 'rage' then hunt.rageUntil = GetGameTimer() + 6000; hunt.holdUntil = 0; return end
    hunt.holdUntil, hunt.holdWhy = GetGameTimer() + math.max(0, seconds) * 1000, why
end)

RegisterNetEvent('exti_heists:client:npcEnd', function(id, why)
    if hunt and hunt.id == id then hunt = nil; bar(nil); clearBlips() end
    if why == 'handover' then
        if own and own.id == id then own = nil end   -- (someone else's game drives them now)
        return
    end
    if own and own.id == id then cleanUp(true) end
    if why == 'police' then HC.notify('وصلت الشرطة: انسحبت حراسة الحي', 'warning', 7000)
    elseif why == 'time' then HC.notify('توقفت حراسة الحي عن البحث', 'inform')
    elseif why == 'surrender' then HC.notify('استسلمت: أخذت حراسة الحي الغنيمة وتركتك', 'warning', 8000) end
end)

---------------------------------------------------------------------------
-- the loops: being seen, being lost, being downed; the owner's brain
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        if hunt then
            sleep = 500
            if hunt.phase == 'coming' then
                bar({ kind = 'coming', seconds = math.max(0, math.ceil((hunt.arriveAt - GetGameTimer()) / 1000)) })
            elseif hunt.phase == 'on' then
                local me = cache.ped
                local myPos = GetEntityCoords(me)
                local seen = false
                local peds = unitPeds()
                local alive = {}
                for _, ped in ipairs(peds) do
                    alive[ped] = true
                    if not blips[ped] then
                        local b = AddBlipForEntity(ped); SetBlipSprite(b, 1); SetBlipColour(b, 1); SetBlipScale(b, 0.7)
                        SetBlipAsShortRange(b, false); ShowHeadingIndicatorOnBlip(b, true); blips[ped] = b
                    end
                    if not seen and #(GetEntityCoords(ped) - myPos) < 140.0 and HasEntityClearLosToEntity(ped, me, 17) then seen = true end
                end
                for ent, b in pairs(blips) do if not alive[ent] then if DoesBlipExist(b) then RemoveBlip(b) end blips[ent] = nil end end
                -- (while they are still driving in, nobody has seen you yet: the clock starts when they first see you,
                -- or 90 s after they are out if they never do)
                if seen then hunt.lastSeen = GetGameTimer() end
                -- (inside a house nobody can see you, but they wait at the door: the clock doesn't run in there)
                if HC.insideHouse and HC.insideHouse() then hunt.lastSeen = GetGameTimer() end
                local from = hunt.lastSeen or ((GetGameTimer() - hunt.onAt > 90000) and (hunt.onAt + 90000) or GetGameTimer())
                local hidden = (GetGameTimer() - from) / 1000
                local left = math.max(0, N.lostSeconds - hidden)
                if (hunt.rageUntil or 0) > GetGameTimer() then
                    bar({ kind = 'rage', seconds = 0 })
                elseif (hunt.holdUntil or 0) > GetGameTimer() then
                    bar({ kind = 'hold', seconds = math.ceil((hunt.holdUntil - GetGameTimer()) / 1000), why = hunt.holdWhy })
                else
                    bar({ kind = seen and 'seen' or 'hiding', seconds = math.ceil(left), units = #peds })
                end
                if left <= 0 and not hunt.lostSent then hunt.lostSent = true; TriggerServerEvent('exti_heists:server:npcLost', hunt.id) end
                -- (sent again every 2 s until the server agrees: the death state may reach it a moment later)
                if HC.isDown() and GetGameTimer() > (hunt.downNext or 0) then hunt.downNext = GetGameTimer() + 2000; TriggerServerEvent('exti_heists:server:npcDowned', hunt.id) end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if own and #own.units > 0 then pcall(think) end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    if own then
        for _, u in ipairs(own.units) do
            for _, ped in ipairs(u.peds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
            if DoesEntityExist(u.veh) then DeleteEntity(u.veh) end
        end
    end
end)
