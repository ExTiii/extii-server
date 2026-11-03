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

local function setupPed(ped, weapon, opts)
    opts = opts or {}
    SetPedRelationshipGroupHash(ped, REL)
    SetPedArmour(ped, opts.armour or 50)
    SetPedAccuracy(ped, opts.accuracy or (own and own.chase and C.hostages.chaseAccuracy) or N.accuracy)
    SetPedCombatAbility(ped, opts.swat and 2 or 1)
    SetPedCombatMovement(ped, opts.swat and 2 or 1)   -- defensive: hold the line (the SWAT team pushes in)
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
local function spawnUnits(id, pos, cars, weapons, opts)
    opts = opts or {}
    local vehModel, pedModel = joaat(opts.car or N.car), joaat(opts.ped or N.ped)
    if not pcall(lib.requestModel, vehModel, 10000) or not pcall(lib.requestModel, pedModel, 10000) then return end
    if not own or own.id ~= id then return end   -- (it ended while the models loaded)
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
            local unit = { veh = veh, peds = {}, stage = 'drive', swat = opts.swat }
            for seat = -1, 0 do
                local ped = CreatePedInsideVehicle(veh, 4, pedModel, seat, true, false)
                if ped ~= 0 then setupPed(ped, weapons[(seat + 2)] or weapons[1], opts); unit.peds[#unit.peds + 1] = ped; netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(ped) end
            end
            -- stop short of the door, a little to the side of it
            local a = math.rad(math.random(0, 359))
            local r0 = opts.swat and (8.0 + i * 3.0) or (12.0 + i * 4.0)
            unit.park = vec3(pos.x + math.cos(a) * r0, pos.y + math.sin(a) * r0, pos.z)
            local drv = unit.peds[1]
            if drv then TaskVehicleDriveToCoordLongrange(drv, veh, unit.park.x, unit.park.y, unit.park.z, opts.swat and 38.0 or 32.0, 786468, 8.0) end
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

local function holdUnits(u, alive, tgt, dist)
    -- they hold their fire: guns on him; if he drives off (a hostage with him), they follow his car close,
    -- sirens on, and never shoot. A head start: they stay where they are.
    for _, ped in ipairs(alive) do
        SetBlockingOfNonTemporaryEvents(ped, true)
        if not own.attackSent and HasEntityBeenDamagedByAnyPed(ped) then
            for _, s in ipairs(own.targets) do
                local tp = pedOfServerId(s)
                if tp and HasEntityBeenDamagedByEntity(ped, tp, true) then
                    own.attackSent = true
                    TriggerServerEvent('exti_heists:server:npcAttacked', own.id, s)
                    break
                end
            end
            ClearEntityLastDamageEntity(ped)
        end
    end
    local tgtCar = tgt and GetVehiclePedIsIn(tgt, false) or 0
    local canDrive = DoesEntityExist(u.veh) and IsVehicleDriveable(u.veh, false)
    if own.holdWhy ~= 'headstart' and tgtCar ~= 0 and dist and dist > 30.0 and canDrive and not u.block then
        if u.holding ~= 'follow' then
            u.holding, u.aimed, u.followCar = 'follow', {}, nil
            for i, ped in ipairs(alive) do
                if not IsPedInVehicle(ped, u.veh, false) then ClearPedTasks(ped); TaskEnterVehicle(ped, u.veh, 10000, i == 1 and -1 or (i - 2), 2.0, 1, 0) end
            end
        end
        local drv = GetPedInVehicleSeat(u.veh, -1)
        if drv ~= 0 and u.followCar ~= tgtCar then
            u.followCar = tgtCar
            SetVehicleSiren(u.veh, true)
            TaskVehicleFollow(drv, u.veh, tgtCar, 32.0, 786468, 18)
        end
        return
    end
    if u.holding ~= 'aim' then u.holding, u.aimed, u.followCar = 'aim', {}, nil end
    for _, ped in ipairs(alive) do
        if IsPedInVehicle(ped, u.veh, false) then
            -- (they followed him here: out, guns up)
            if dist and dist < 45.0 and tgtCar == 0 and (u.leaving or 0) < GetGameTimer() then TaskLeaveVehicle(ped, u.veh, 256) end
        elseif tgt and u.aimed[ped] ~= tgt then
            u.aimed[ped] = tgt
            ClearPedTasks(ped)
            TaskAimGunAtEntity(ped, tgt, -1, false)
        end
    end
    if dist and dist < 45.0 and tgtCar == 0 then u.leaving = GetGameTimer() + 4000 end
end

local function adopt()
    -- units that were too far from this game when it took them over: picked up once they're around
    if not own.pending or #own.pending == 0 then return end
    local left = {}
    for _, n in ipairs(own.pending) do
        local ent = NetworkDoesNetworkIdExist(n) and NetworkGetEntityFromNetworkId(n) or 0
        if ent ~= 0 and DoesEntityExist(ent) then
            NetworkRequestControlOfEntity(ent)
            if IsEntityAVehicle(ent) then
                local u = { veh = ent, peds = {}, stage = 'fight', since = GetGameTimer(), park = own.pos }
                for seat = -1, GetVehicleMaxNumberOfPassengers(ent) - 1 do
                    local p = GetPedInVehicleSeat(ent, seat)
                    if p ~= 0 and Entity(p).state.exti_npcsec == own.id then u.peds[#u.peds + 1] = p end
                end
                own.units[#own.units + 1] = u
            elseif IsEntityAPed(ent) then
                local known = false
                for _, u in ipairs(own.units) do for _, p in ipairs(u.peds) do if p == ent then known = true end end end
                if not known then
                    local veh = GetVehiclePedIsIn(ent, true)
                    local into
                    for _, u in ipairs(own.units) do if u.veh == veh then into = u break end end
                    if into then into.peds[#into.peds + 1] = ent
                    else own.units[#own.units + 1] = { veh = veh, peds = { ent }, stage = 'fight', since = GetGameTimer(), park = own.pos } end
                end
            end
        else
            left[#left + 1] = n
        end
    end
    own.pending = left
end

local function think()
    adopt()
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
                holdUnits(u, alive, tgt, dist)
            elseif u.holding then
                -- the hold is over: back to work (in their cars after a car: the chase; else out and fight)
                local inCar = DoesEntityExist(u.veh) and IsPedInVehicle(alive[1], u.veh, false)
                local tgtCar = tgt and GetVehiclePedIsIn(tgt, false) or 0
                u.holding = false; u.target = nil; u.chasing = nil; u.shooting = nil; u.aimed = nil; u.followCar = nil
                for _, ped in ipairs(alive) do SetBlockingOfNonTemporaryEvents(ped, false) end
                if inCar and tgtCar ~= 0 and not u.block then
                    u.stage, u.chaseAt = 'chase', nil
                else
                    u.stage = 'fight'
                    for _, ped in ipairs(alive) do if IsPedInVehicle(ped, u.veh, false) then TaskLeaveVehicle(ped, u.veh, 256) end end
                end
            elseif tgt and u.block then
                -- a roadblock: they wait by their cars and open up when he comes close
                if dist < 90.0 and u.target ~= tgt then
                    u.target = tgt
                    for _, ped in ipairs(alive) do ClearPedTasks(ped); TaskCombatPed(ped, tgt, 0, 16) end
                end
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
                        u.target, u.recheck = tgt, GetGameTimer() + 8000
                        for _, ped in ipairs(alive) do ClearPedTasks(ped); TaskCombatPed(ped, tgt, 0, 16) end
                    elseif GetGameTimer() > (u.recheck or 0) then
                        -- (a unit that dropped its order, e.g. after it moved to another player's game: fight again)
                        u.recheck = GetGameTimer() + 8000
                        for _, ped in ipairs(alive) do
                            if not IsPedInCombat(ped, tgt) and not IsPedInAnyVehicle(ped, false) then TaskCombatPed(ped, tgt, 0, 16) end
                        end
                    end
                elseif u.stage == 'chase' then
                    u.chaseAt = u.chaseAt or GetGameTimer()
                    local drivable = DoesEntityExist(veh) and IsVehicleDriveable(veh, false)
                    local inside = 0
                    for _, ped in ipairs(alive) do if drivable and IsPedInVehicle(ped, veh, false) then inside = inside + 1 end end
                    if not drivable or (inside == 0 and GetGameTimer() - u.chaseAt > 12000) then
                        -- their car is wrecked, or they never got back in: on foot, after him
                        u.stage = 'fight'; u.target = nil; u.chasing = nil; u.shooting = nil; u.chaseAt = nil
                        for _, ped in ipairs(alive) do if DoesEntityExist(veh) and IsPedInVehicle(ped, veh, false) then TaskLeaveVehicle(ped, veh, 256) end end
                        goto nextUnit
                    end
                    local drv = GetPedInVehicleSeat(veh, -1)
                    if drv ~= 0 and u.chasing ~= tgt then u.chasing = tgt; TaskVehicleChase(drv, tgt); SetTaskVehicleChaseBehaviorFlag(drv, 1, true) end
                    for _, ped in ipairs(alive) do
                        if ped ~= drv and IsPedInVehicle(ped, veh, false) and u.shooting ~= tgt then TaskDriveBy(ped, tgt, 0, 0.0, 0.0, 0.0, 60.0, 30, false, `FIRING_PATTERN_BURST_FIRE_DRIVEBY`) end
                    end
                    u.shooting = tgt
                    if tgtCar == 0 and dist < 30.0 then
                        u.stage = 'fight'; u.target = nil; u.chasing = nil; u.shooting = nil; u.chaseAt = nil
                        for _, ped in ipairs(alive) do TaskLeaveVehicle(ped, veh, 256) end
                    end
                end
            end
        end
        ::nextUnit::
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
    own = { id = id, units = {}, targets = targets, pos = vec3(pos.x, pos.y, pos.z), pending = {} }
    for _, n in ipairs(netIds) do
        if not (NetworkDoesNetworkIdExist(n) and NetworkGetEntityFromNetworkId(n) ~= 0) then own.pending[#own.pending + 1] = n end
    end
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

-- I went inside a house: a crewmate outside drives the units now (I'm still hunted)
RegisterNetEvent('exti_heists:client:npcRelease', function(id)
    if own and own.id == id then own = nil end
end)

-- the server: hold your fire for this long (hostages, a deal, pulled back)
RegisterNetEvent('exti_heists:client:npcHold', function(id, seconds, why)
    if not own or own.id ~= id then return end
    if (seconds or 0) <= 0 then own.holdUntil, own.holdWhy = 0, nil
    else
        own.holdUntil, own.holdWhy = GetGameTimer() + seconds * 1000, why
        -- (old hits from before the hold don't count as "he shot at us")
        for _, u in ipairs(own.units) do for _, ped in ipairs(u.peds) do if DoesEntityExist(ped) then ClearEntityLastDamageEntity(ped) end end end
    end
    own.pullBack = false
    for _, u in ipairs(own.units) do if u.holding then u.holding = 'redo' end end
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
    if why == 'clear' or (seconds or 0) <= 0 then hunt.holdUntil, hunt.holdWhy = 0, nil; hunt.lastSeen = GetGameTimer(); return end
    hunt.holdUntil, hunt.holdWhy = GetGameTimer() + seconds * 1000, why
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
                -- (while they hold their fire and wait, there's nothing to lose)
                if (hunt.holdUntil or 0) > GetGameTimer() then hunt.lastSeen = GetGameTimer() end
                local from = hunt.lastSeen or ((GetGameTimer() - hunt.onAt > 90000) and (hunt.onAt + 90000) or GetGameTimer())
                local hidden = (GetGameTimer() - from) / 1000
                local left = math.max(0, (hunt.lost or N.lostSeconds) - hidden)
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
        if own and (#own.units > 0 or (own.pending and #own.pending > 0)) then pcall(think) end
        Wait(1000)
    end
end)

---------------------------------------------------------------------------
-- after a deal: the chase (sharper aim, roadblocks ahead of his car); the SWAT team; how long to hide
---------------------------------------------------------------------------
local RB = C.hostages.roadblocks
RegisterNetEvent('exti_heists:client:npcChase', function(id)
    if not own or own.id ~= id then return end
    own.chase = true
    own.rbCount, own.rbNext = own.rbCount or 0, GetGameTimer() + RB.every * 500
    for _, u in ipairs(own.units) do
        for _, ped in ipairs(u.peds) do if DoesEntityExist(ped) then SetPedAccuracy(ped, C.hostages.chaseAccuracy) end end
        u.target, u.chasing, u.shooting = nil, nil, nil
    end
end)

RegisterNetEvent('exti_heists:client:npcSwat', function(id, sw)
    if not own or own.id ~= id or own.swatSent then return end
    own.swatSent = true
    -- (they come to where the robbers are now)
    local at = own.pos
    for _, s in ipairs(own.targets) do local p = pedOfServerId(s); if p then at = GetEntityCoords(p) break end end
    CreateThread(function()
        spawnUnits(id, at, sw.cars, sw.weapons, { car = sw.car, ped = sw.ped, armour = sw.armour, accuracy = sw.accuracy, swat = true })
    end)
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
end)

RegisterNetEvent('exti_heists:client:npcMode', function(id, m)
    if not hunt or hunt.id ~= id then return end
    hunt.lost = m and m.lost or nil
    if m and m.chase then hunt.lastSeen = GetGameTimer(); hunt.lostSent = nil end
end)

-- a roadblock about 260 m ahead of a fleeing car: two cars across the road, two men at each
local function roadblock(tgt)
    local car = GetVehiclePedIsIn(tgt, false)
    if car == 0 or GetEntitySpeed(car) < 8.0 then return false end
    local p, f = GetEntityCoords(car), GetEntityForwardVector(car)
    local ahead = p + f * RB.ahead
    local ok, node, heading = GetClosestVehicleNodeWithHeading(ahead.x, ahead.y, ahead.z, 1, 3.0, 0)
    if not ok then return false end
    local to = node - p
    if #to < RB.ahead * 0.6 or (to.x * f.x + to.y * f.y) <= 0 then return false end
    local vehModel, pedModel = joaat(N.car), joaat(N.ped)
    if not pcall(lib.requestModel, vehModel, 5000) or not pcall(lib.requestModel, pedModel, 5000) then return false end
    if not own or not own.chase then return false end
    local hr = math.rad(heading)
    local side = vec3(math.cos(hr), math.sin(hr), 0.0)          -- across the road
    local netIds = {}
    for k = -1, 1, 2 do
        local c = node + side * (2.6 * k)
        local veh = CreateVehicle(vehModel, c.x, c.y, c.z + 0.4, heading + 90.0, true, false)
        if veh ~= 0 then
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleOnGroundProperly(veh)
            SetVehicleSiren(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            Entity(veh).state:set('exti_npcsec', own.id, true)
            local unit = { veh = veh, peds = {}, stage = 'fight', block = true, since = GetGameTimer(), park = c }
            for j = 1, 2 do
                local behind = c - vec3(math.cos(math.rad(heading + 90.0)), math.sin(math.rad(heading + 90.0)), 0.0) * 1.8 + side * (j == 1 and -0.9 or 0.9)
                local ped = CreatePed(4, pedModel, behind.x, behind.y, behind.z, heading, true, false)
                if ped ~= 0 then
                    setupPed(ped, RB.weapons[j] or RB.weapons[1], { accuracy = C.hostages.chaseAccuracy })
                    unit.peds[#unit.peds + 1] = ped
                    netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(ped)
                end
            end
            own.units[#own.units + 1] = unit
            netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(veh)
        end
    end
    SetModelAsNoLongerNeeded(vehModel); SetModelAsNoLongerNeeded(pedModel)
    if #netIds == 0 then return false end
    TriggerServerEvent('exti_heists:server:npcSpawned', own.id, netIds)
    return true
end
CreateThread(function()
    while true do
        Wait(2000)
        if own and own.chase and (own.rbCount or 0) < RB.max and GetGameTimer() > (own.rbNext or 0) then
            for _, s in ipairs(own.targets) do
                local p = pedOfServerId(s)
                local made = false
                if p and not IsPedDeadOrDying(p, true) and own then local okr, res = pcall(roadblock, p); made = okr and res == true end
                if made then
                    own.rbCount = (own.rbCount or 0) + 1
                    own.rbNext = GetGameTimer() + RB.every * 1000
                    break
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- the drop-off spot: picked here (a road 400-800 m away), shown on the map of every hunted robber
---------------------------------------------------------------------------
lib.callback.register('exti_heists:client:dropSpot', function(origin, minD, maxD)
    local o = vec3(origin.x, origin.y, origin.z)
    for _ = 1, 40 do
        local a = math.rad(math.random(0, 359))
        local d = math.random(math.floor(minD), math.floor(maxD))
        local ok, node = GetClosestVehicleNode(o.x + math.cos(a) * d, o.y + math.sin(a) * d, o.z, 1, 3.0, 0)
        if ok then
            local dd = #(node - o)
            if dd >= minD * 0.85 and dd <= maxD * 1.2 and not TestVerticalProbeAgainstAllWater(node.x, node.y, node.z + 2.0, 0) then
                local s1 = GetStreetNameAtCoord(node.x, node.y, node.z)
                return { x = node.x, y = node.y, z = node.z, street = GetStreetNameFromHashKey(s1) }
            end
        end
    end
    return nil
end)

local dropBlips = {}
local function clearDrop()
    for _, b in ipairs(dropBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    dropBlips = {}
end
RegisterNetEvent('exti_heists:client:dropSpotShow', function(id, spot)
    clearDrop()
    local b = AddBlipForCoord(spot.x, spot.y, spot.z)
    SetBlipSprite(b, 280); SetBlipColour(b, 1); SetBlipScale(b, 1.0)
    SetBlipRoute(b, true); SetBlipRouteColour(b, 1)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('نقطة ترك الرهائن'); EndTextCommandSetBlipName(b)
    local r = AddBlipForRadius(spot.x, spot.y, spot.z, C.hostages.dropRadius)
    SetBlipColour(r, 1); SetBlipAlpha(r, 120)
    dropBlips = { b, r }
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)
RegisterNetEvent('exti_heists:client:dropSpotClear', function() clearDrop() end)
AddEventHandler('exti_heists:client:npcEnd', function() clearDrop() end)

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
