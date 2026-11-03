-- =====================================================================
-- EX_Tii heists (game side): NPC hostages. Aim a gun at a person: hands up. Aim at him again: flat on
-- his stomach (he stays there until you pick "قف" on the wheel). Everything else is on the Z wheel
-- (client/radial.lua). The robber's game (or whoever walks him) drives a tied hostage: kneeling, flat
-- on the floor, walking behind you, sitting in a car. It also watches him get hurt. Every game draws the
-- sack on a blindfolded hostage's head (NPC or player).
-- =====================================================================
local C = Config
local HG = C.hostages

local covered = {}      -- [ped] = { at = GetGameTimer() of hands up, prone = true|nil, by = me }
local state = {}        -- [netId] = { by, escort, blind, prone, veh, seat } (GlobalState)
local driving = {}      -- [netId] = { mode, hp }

local function decode(v)
    local out = {}
    for k, h in pairs(type(v) == 'table' and v or {}) do local n = tonumber(k); if n then out[n] = h end end
    return out
end
state = decode(GlobalState['exti_heists:hostages'])
AddStateBagChangeHandler('exti_heists:hostages', 'global', function(_, _, v) state = decode(v) end)

local function entOf(net)
    if not net or not NetworkDoesNetworkIdExist(net) then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end
local function isHostage(ped)
    if not NetworkGetEntityIsNetworked(ped) then return nil end
    local net = NetworkGetNetworkIdFromEntity(ped)
    return state[net] and net or nil
end

-- a person we may point a gun at and tie up: a real local, not a player, not a script's own NPC
local function canCover(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not IsEntityAPed(ped) or IsPedAPlayer(ped) then return false end
    if IsPedDeadOrDying(ped, true) or not IsPedHuman(ped) or IsPedInAnyVehicle(ped, true) then return false end
    if not NetworkGetEntityIsNetworked(ped) or IsEntityAMissionEntity(ped) and not isHostage(ped) then return false end
    if Entity(ped).state.exti_npcsec or Entity(ped).state.exti_guard then return false end
    return true
end

local function control(ped, ms)
    NetworkRequestControlOfEntity(ped)
    local t = GetGameTimer() + (ms or 600)
    while DoesEntityExist(ped) and not NetworkHasControlOfEntity(ped) and GetGameTimer() < t do Wait(30); NetworkRequestControlOfEntity(ped) end
    return DoesEntityExist(ped) and NetworkHasControlOfEntity(ped)
end

local function playLoop(ped, a, flag)
    if IsEntityPlayingAnim(ped, a[1], a[2], 3) then return end
    if not pcall(lib.requestAnimDict, a[1], 2000) then return end
    TaskPlayAnim(ped, a[1], a[2], 4.0, 4.0, -1, flag, 0.0, false, false, false)
end
local KNEEL = { 'random@arrests@busted', 'idle_a' }
local TIED = { 'mp_arresting', 'idle' }
local PRONE = { 'amb@world_human_sunbathe@male@front@base', 'base' }
local HANDS = { 'missminuteman_1ig_2', 'handsup_base' }
HC.ANIM_PRONE = PRONE

---------------------------------------------------------------------------
-- aim at him: hands up. Aim at him again: down on his stomach.
---------------------------------------------------------------------------
local function handsUp(ped)
    local c = covered[ped]
    if c and c.at + 7000 > GetGameTimer() then return end
    covered[ped] = { at = GetGameTimer(), prone = c and c.prone }
    CreateThread(function()
        -- (another game may own him: tasks only stick once he is ours)
        if not control(ped) then return end
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        if covered[ped] and covered[ped].prone then return end
        ClearPedTasks(ped)
        TaskHandsUp(ped, 9000, cache.ped, -1, true)
        if math.random() < 0.5 then PlayPain(ped, 6, 0) end
    end)
end

local function goProne(ped)
    local c = covered[ped] or { at = GetGameTimer() }
    c.prone, c.at, c.proneAt = true, GetGameTimer(), GetGameTimer()
    covered[ped] = c
    CreateThread(function()
        if not control(ped) then return end
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        ClearPedTasks(ped)
        if pcall(lib.requestAnimDict, PRONE[1], 2000) then TaskPlayAnim(ped, PRONE[1], PRONE[2], 3.0, 3.0, -1, 1, 0.0, false, false, false) end
        if math.random() < 0.6 then PlayPain(ped, 6, 0) end
    end)
end
-- (from the wheel: an untied one gets up, hands up again)
function HC.coverUp(ped)
    local c = covered[ped]; if not c then return end
    c.prone, c.at = nil, 0
    handsUp(ped)
end
function HC.coverProne(ped) goProne(ped) end
function HC.covered(ped)
    local c = covered[ped]
    if not c then return nil end
    if c.prone then return (GetGameTimer() - (c.proneAt or c.at) < 180000) and 'prone' or nil end
    return (c.at + 9000 > GetGameTimer()) and 'up' or nil
end

local aimed = nil   -- what I aimed at last tick
CreateThread(function()
    while true do
        local sleep = 300
        local now = nil
        if IsPlayerFreeAiming(cache.playerId) and IsPedArmed(cache.ped, 4) and not LocalPlayer.state.exti_tied then
            sleep = 100
            local ok, ent = GetEntityPlayerIsFreeAimingAt(cache.playerId)
            if ok and ent ~= 0 and #(GetEntityCoords(ent) - GetEntityCoords(cache.ped)) < HG.aimDistance then
                now = ent
                local net = IsEntityAPed(ent) and not IsPedAPlayer(ent) and isHostage(ent)
                if net then
                    -- a tied hostage: aimed at again, he goes flat (if he isn't already, walking or in a car)
                    local h = state[net]
                    if aimed ~= ent and h and not h.prone and not h.escort and not h.veh and h.by == cache.serverId then
                        CreateThread(function() lib.callback.await('exti_heists:server:hostageAct', false, 'prone', 'npc', net, 'aim') end)
                    end
                elseif canCover(ent) then
                    local c = covered[ent]
                    if aimed ~= ent and c and not c.prone and GetGameTimer() - c.at > 1200 and c.at + 9000 > GetGameTimer() then
                        goProne(ent)
                    else
                        handsUp(ent)
                    end
                elseif IsEntityAPed(ent) and IsPedAPlayer(ent) and HC.aimAtPlayer then
                    HC.aimAtPlayer(ent, aimed ~= ent)
                end
            end
        end
        aimed = now
        Wait(sleep)
    end
end)

-- an untied one on the floor stays there while I'm close (and goes back to his day when I'm gone)
CreateThread(function()
    while true do
        Wait(1000)
        local me = GetEntityCoords(cache.ped)
        for ped, c in pairs(covered) do
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or isHostage(ped) then covered[ped] = nil
            elseif c.prone then
                local far = #(GetEntityCoords(ped) - me) > 40.0
                if far or GetGameTimer() - (c.proneAt or c.at) > 180000 then
                    covered[ped] = nil
                    if NetworkHasControlOfEntity(ped) then
                        ClearPedTasks(ped); SetBlockingOfNonTemporaryEvents(ped, false)
                        TaskSmartFleeCoord(ped, me.x, me.y, me.z, 100.0, 20000, false, false)
                        SetPedAsNoLongerNeeded(ped)
                    end
                elseif NetworkHasControlOfEntity(ped) then
                    playLoop(ped, PRONE, 1)
                end
            elseif c.at + 12000 < GetGameTimer() then
                covered[ped] = nil
            end
        end
    end
end)

---------------------------------------------------------------------------
-- keeping him tied (only the game that drives him does this)
---------------------------------------------------------------------------
local function pedOfServerId(s)
    if not s then return nil end
    local pl = GetPlayerFromServerId(s)
    if pl == -1 then return nil end
    local p = GetPlayerPed(pl)
    return p ~= 0 and p or nil
end

CreateThread(function()
    while true do
        local me = cache.serverId
        local myPos = GetEntityCoords(cache.ped)
        for net, h in pairs(state) do
            local ped = entOf(net)
            if ped then
                local mine = h.escort == me or (h.by == me and not h.escort)
                if mine and not NetworkHasControlOfEntity(ped) and #(GetEntityCoords(ped) - myPos) < 80.0 then NetworkRequestControlOfEntity(ped) end
                if NetworkHasControlOfEntity(ped) then
                    local d = driving[net]
                    if not d then
                        d = { hp = GetEntityHealth(ped) }
                        driving[net] = d
                        SetEntityAsMissionEntity(ped, true, true)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        SetPedFleeAttributes(ped, 0, false)
                        SetPedCanRagdoll(ped, true)
                        SetPedKeepTask(ped, true)
                        SetPedConfigFlag(ped, 32, false)   -- (no flying through the windscreen)
                    end
                    local veh = h.veh and entOf(h.veh)
                    local escort = h.escort and pedOfServerId(h.escort)
                    if veh then
                        -- sitting in the car he was put in
                        if GetVehiclePedIsIn(ped, false) ~= veh then
                            d.mode = 'car'
                            ClearPedTasksImmediately(ped)
                            TaskWarpPedIntoVehicle(ped, veh, h.seat or 1)
                        end
                        SetPedCanBeDraggedOut(ped, false)
                    elseif IsPedInAnyVehicle(ped, false) then
                        -- taken out
                        local v = GetVehiclePedIsIn(ped, false)
                        TaskLeaveVehicle(ped, v, 0)
                        d.mode = 'out'
                    elseif escort then
                        -- walking behind whoever leads him, hands tied
                        local dist = #(GetEntityCoords(ped) - GetEntityCoords(escort))
                        if d.mode ~= 'follow' or (dist > 3.0 and not GetIsTaskActive(ped, 35)) then
                            d.mode = 'follow'
                            ClearPedTasks(ped)
                            TaskFollowToOffsetOfEntity(ped, escort, 0.0, -1.1, 0.0, 1.6, -1, 1.2, true)
                        end
                        playLoop(ped, TIED, 49)
                    elseif h.prone then
                        if d.mode ~= 'prone' then d.mode = 'prone'; ClearPedTasksImmediately(ped) end
                        playLoop(ped, PRONE, 1)
                    else
                        if d.mode ~= 'kneel' then d.mode = 'kneel'; ClearPedTasksImmediately(ped) end
                        playLoop(ped, KNEEL, 1)
                    end
                    -- hurt by a weapon or a fist (not a bump in the car)? the server checks his health itself
                    local hp = GetEntityHealth(ped)
                    if hp < d.hp - 5 and (HasPedBeenDamagedByWeapon(ped, 0, 2) or hp <= 0) then
                        local who
                        for _, pl in ipairs(GetActivePlayers()) do
                            local pp = GetPlayerPed(pl)
                            if pp ~= 0 and HasEntityBeenDamagedByEntity(ped, pp, true) then who = GetPlayerServerId(pl) break end
                        end
                        ClearEntityLastDamageEntity(ped); ClearPedLastWeaponDamage(ped)
                        TriggerServerEvent('exti_heists:server:hostageHurt', net, who)
                    elseif hp < d.hp then
                        ClearEntityLastDamageEntity(ped)
                    end
                    d.hp = hp
                else
                    driving[net] = nil
                end
            end
        end
        for net in pairs(driving) do if not state[net] then driving[net] = nil end end
        Wait(next(state) and 500 or 1500)
    end
end)

-- he is free: up and away (the game that owns him)
RegisterNetEvent('exti_heists:client:hostageFree', function(net, from)
    driving[net] = nil
    local ped = entOf(net)
    if not ped then return end
    covered[ped] = nil
    if not NetworkHasControlOfEntity(ped) then return end
    ClearPedTasksImmediately(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0) end
    SetTimeout(1200, function()
        if not DoesEntityExist(ped) then return end
        if from then TaskSmartFleeCoord(ped, from.x, from.y, from.z, 120.0, 30000, false, false)
        else TaskWanderStandard(ped, 10.0, 10) end
    end)
    SetTimeout(15000, function() if DoesEntityExist(ped) then SetPedAsNoLongerNeeded(ped) end end)
end)

---------------------------------------------------------------------------
-- the sack over the head (every game draws its own, NPCs and players)
---------------------------------------------------------------------------
local sacks = {}   -- [ped] = object
local function sackOn(ped)
    if sacks[ped] and DoesEntityExist(sacks[ped]) then return end
    local m = joaat(HG.blindProp)
    if not pcall(lib.requestModel, m, 3000) then return end
    local o = CreateObject(m, 0.0, 0.0, 0.0, false, false, false)
    SetEntityCollision(o, false, false)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, 12844), 0.2, 0.04, 0.0, 0.0, 270.0, 60.0, true, true, false, true, 1, true)
    sacks[ped] = o
    SetModelAsNoLongerNeeded(m)
end
local function sackOff(ped)
    local o = sacks[ped]
    if o and DoesEntityExist(o) then DeleteEntity(o) end
    sacks[ped] = nil
end
CreateThread(function()
    while true do
        local want = {}
        for net, h in pairs(state) do
            if h.blind then local ped = entOf(net); if ped then want[ped] = true end end
        end
        for _, pl in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(pl)
            -- (my own sack: I don't see it, I see black)
            if ped ~= 0 and pl ~= cache.playerId and Player(GetPlayerServerId(pl)).state.exti_blind then want[ped] = true end
        end
        for ped in pairs(want) do sackOn(ped) end
        for ped in pairs(sacks) do if not want[ped] or not DoesEntityExist(ped) then sackOff(ped) end end
        Wait(next(want) and 500 or 1500)
    end
end)

---------------------------------------------------------------------------
-- for the wheel: the hostage next to me (or the one I walk)
---------------------------------------------------------------------------
function HC.npcHostages() return state end
function HC.hostagePed(net) return entOf(net) end
function HC.netOf(ped) return NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or nil end
function HC.canCover(ped) return canCover(ped) end
function HC.takeControl(ped, ms) return control(ped, ms) end
HC.ANIM_HANDS = HANDS

-- a small hint while you stand by someone you can do something with
CreateThread(function()
    while true do
        local sleep = 700
        local text
        if HC.canAct() and HC.radialTarget then
            local t = HC.radialTarget()
            if t then sleep = 250; text = '[Z] الرهينة' end
        end
        HC.prompt(text, 'hostage')
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for ped in pairs(sacks) do sackOff(ped) end
    for net in pairs(driving) do
        local ped = entOf(net)
        if ped and NetworkHasControlOfEntity(ped) then ClearPedTasksImmediately(ped); SetPedAsNoLongerNeeded(ped) end
    end
end)
