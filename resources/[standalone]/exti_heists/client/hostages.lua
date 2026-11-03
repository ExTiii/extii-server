-- =====================================================================
-- EX_Tii heists (game side): hostages. Aim a gun at a person and he puts his hands up; walk up with
-- zip ties and [G] tie him. Next to a tied hostage: [E] walk him with you / leave him here,
-- [H] let him go. Officers: [E] free him. The robber's game (or whoever walks him) drives him: kneeling
-- with his hands tied, or walking behind you; it also watches him get hurt.
-- =====================================================================
local C = Config
local HG = C.hostages

local covered = {}      -- [ped] = GetGameTimer() of the last "hands up"
local state = {}        -- [netId] = { by, escort } (GlobalState)
local driving = {}      -- [netId] = { mode = 'kneel'|'follow', hp }

local function decode(v)
    local out = {}
    for k, h in pairs(type(v) == 'table' and v or {}) do local n = tonumber(k); if n then out[n] = h end end
    return out
end
state = decode(GlobalState['exti_heists:hostages'])
AddStateBagChangeHandler('exti_heists:hostages', 'global', function(_, _, v) state = decode(v) end)

local function entOf(net)
    if not NetworkDoesNetworkIdExist(net) then return nil end
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
    if Entity(ped).state.exti_npcsec then return false end
    return true
end

---------------------------------------------------------------------------
-- hands up when a gun points at him
---------------------------------------------------------------------------
local function handsUp(ped)
    if (covered[ped] or 0) + 7000 > GetGameTimer() or isHostage(ped) then return end
    covered[ped] = GetGameTimer()
    CreateThread(function()
        -- (another game may own him: tasks only stick once he is ours)
        NetworkRequestControlOfEntity(ped)
        local t = GetGameTimer() + 600
        while DoesEntityExist(ped) and not NetworkHasControlOfEntity(ped) and GetGameTimer() < t do Wait(30); NetworkRequestControlOfEntity(ped) end
        if not DoesEntityExist(ped) or not NetworkHasControlOfEntity(ped) then return end
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        ClearPedTasks(ped)
        TaskHandsUp(ped, 9000, cache.ped, -1, true)
        if math.random() < 0.5 then PlayPain(ped, 6, 0) end
    end)
end

CreateThread(function()
    while true do
        local sleep = 300
        if IsPlayerFreeAiming(cache.playerId) and IsPedArmed(cache.ped, 4) then
            local ok, ent = GetEntityPlayerIsFreeAimingAt(cache.playerId)
            if ok and canCover(ent) and #(GetEntityCoords(ent) - GetEntityCoords(cache.ped)) < HG.aimDistance then handsUp(ent) end
            sleep = 100
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- keeping him tied (only the game that owns him does this)
---------------------------------------------------------------------------
local KNEEL = { 'random@arrests@busted', 'idle_a' }
local TIED = { 'mp_arresting', 'idle' }

local function pedOfServerId(s)
    local pl = GetPlayerFromServerId(s)
    if pl == -1 then return nil end
    local p = GetPlayerPed(pl)
    return p ~= 0 and p or nil
end

local function playLoop(ped, a, flag)
    if IsEntityPlayingAnim(ped, a[1], a[2], 3) then return end
    if not pcall(lib.requestAnimDict, a[1], 2000) then return end
    TaskPlayAnim(ped, a[1], a[2], 4.0, 4.0, -1, flag, 0.0, false, false, false)
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
                    end
                    local escort = h.escort and pedOfServerId(h.escort)
                    if escort then
                        -- walking behind whoever leads him, hands tied
                        local dist = #(GetEntityCoords(ped) - GetEntityCoords(escort))
                        if d.mode ~= 'follow' or (dist > 3.0 and not GetIsTaskActive(ped, 35)) then
                            d.mode = 'follow'
                            ClearPedTasks(ped)
                            TaskFollowToOffsetOfEntity(ped, escort, 0.0, -1.1, 0.0, 1.6, -1, 1.2, true)
                        end
                        playLoop(ped, TIED, 49)
                    else
                        if d.mode ~= 'kneel' then d.mode = 'kneel'; ClearPedTasksImmediately(ped) end
                        playLoop(ped, KNEEL, 1)
                    end
                    -- hurt? find who did it, the server checks his health itself
                    local hp = GetEntityHealth(ped)
                    if hp < d.hp - 5 then
                        local who
                        for _, pl in ipairs(GetActivePlayers()) do
                            local pp = GetPlayerPed(pl)
                            if pp ~= 0 and HasEntityBeenDamagedByEntity(ped, pp, true) then who = GetPlayerServerId(pl) break end
                        end
                        ClearEntityLastDamageEntity(ped)
                        TriggerServerEvent('exti_heists:server:hostageHurt', net, who)
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
    if not NetworkHasControlOfEntity(ped) then return end
    ClearPedTasksImmediately(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    if from then TaskSmartFleeCoord(ped, from.x, from.y, from.z, 120.0, 30000, false, false)
    else TaskWanderStandard(ped, 10.0, 10) end
    SetTimeout(15000, function() if DoesEntityExist(ped) then SetPedAsNoLongerNeeded(ped) end end)
end)

---------------------------------------------------------------------------
-- the prompts
---------------------------------------------------------------------------
local function nearestPed(maxDist, test)
    local me = GetEntityCoords(cache.ped)
    local best, bd
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped and test(ped) then
            local d = #(GetEntityCoords(ped) - me)
            if d < maxDist and (not bd or d < bd) then best, bd = ped, d end
        end
    end
    return best
end

local busy = false
local function tie(ped)
    busy = true
    HC.prompt(nil)
    TaskTurnPedToFaceEntity(cache.ped, ped, 800); Wait(800)
    local ok = lib.progressCircle({ duration = HG.tieSeconds * 1000, label = 'تقيّده...', position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 } })
    if ok and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
        NetworkRequestControlOfEntity(ped)
        local t = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(ped) and GetGameTimer() < t do Wait(50) end
        SetEntityAsMissionEntity(ped, true, true)
        local net = NetworkGetNetworkIdFromEntity(ped)
        SetNetworkIdCanMigrate(net, true)
        local done, info = lib.callback.await('exti_heists:server:hostageTie', false, net)
        if done then
            HC.notify(('قيّدته · معك %d رهائن'):format(info), 'success')
            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        else
            -- (not ours after all: let the game have him back)
            SetBlockingOfNonTemporaryEvents(ped, false)
            SetPedAsNoLongerNeeded(ped)
            HC.notify(type(info) == 'string' and info or 'لا تستطيع تقييده', 'error')
        end
    end
    busy = false
end

CreateThread(function()
    while true do
        local sleep = 400
        local text
        if not busy and HC.canAct() then
            local cop = LocalPlayer.state.isLoggedIn ~= false and QBX and QBX.PlayerData and QBX.PlayerData.job and QBX.PlayerData.job.name == C.cops.job and QBX.PlayerData.job.onduty
            -- a tied hostage next to me
            local hp = next(state) and nearestPed(1.8, function(p) return isHostage(p) ~= nil end)
            if hp then
                sleep = 0
                local net = isHostage(hp)
                local h = state[net]
                if cop then
                    text = '[E] فك رباطه'
                    if IsControlJustPressed(0, 38) then
                        busy = true; HC.prompt(nil)
                        if lib.progressCircle({ duration = 3000, label = 'تفك الرباط...', position = 'bottom', canCancel = true, disable = { move = true, combat = true },
                            anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 } }) then
                            local ok, bonus = lib.callback.await('exti_heists:server:hostageFreeCop', false, net)
                            if ok then HC.notify(('حرّرت رهينة · مكافأة $%d'):format(bonus), 'success') end
                        end
                        busy = false
                    end
                else
                    text = (h.escort == cache.serverId and '[E] اتركه هنا' or '[E] خذه معك') .. '   [H] أطلق سراحه'
                    if IsControlJustPressed(0, 38) then
                        lib.callback.await('exti_heists:server:hostageEscort', false, net)
                        Wait(300)
                    elseif IsControlJustPressed(0, 74) then
                        if lib.callback.await('exti_heists:server:hostageRelease', false, net) then HC.notify('أطلقت سراحه', 'inform') end
                        Wait(300)
                    end
                end
            elseif not cop and IsPedArmed(cache.ped, 4) then
                -- a person with his hands up in front of me
                local t = GetGameTimer()
                local target = nearestPed(HG.tieDistance, function(p) return (covered[p] or 0) + 9000 > t and canCover(p) and not isHostage(p) end)
                if target then
                    sleep = 0
                    if HC.count('zip_ties') > 0 then
                        text = '[G] قيّده (أربطة بلاستيكية)'
                        if IsControlJustPressed(0, 47) then CreateThread(function() tie(target) end) end
                    else
                        text = 'تحتاج أربطة بلاستيكية لتقييده'
                    end
                end
            end
        end
        HC.prompt(text, 'hostage')
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for net in pairs(driving) do
        local ped = entOf(net)
        if ped and NetworkHasControlOfEntity(ped) then ClearPedTasksImmediately(ped); SetPedAsNoLongerNeeded(ped) end
    end
end)
