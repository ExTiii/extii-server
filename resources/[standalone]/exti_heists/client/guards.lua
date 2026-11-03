-- =====================================================================
-- EX_Tii heists (game side): guards. This game makes them when the server asks (snapped to the ground),
-- and drives every guard it owns: rounds and standing posts while calm; eyes and ears; the alarm; then
-- the fight (half hold cover, half push round the side). Ownership of a ped moves to whoever is closest,
-- so the brain carries on whoever leaves.
-- =====================================================================
local C = Config
local GD = C.guards
local REL = joaat(GD.rel)
AddRelationshipGroup(GD.rel)
SetRelationshipBetweenGroups(3, REL, `PLAYER`)
SetRelationshipBetweenGroups(3, `PLAYER`, REL)
SetRelationshipBetweenGroups(0, REL, REL)

local sites = GlobalState['exti_heists:guards'] or {}
AddStateBagChangeHandler('exti_heists:guards', 'global', function(_, _, v) sites = v or {} end)

-- the ground under a spot, but only close to where the config says (a deck over the sea must not
-- become the sea floor)
local function ground(x, y, z)
    for _, dz in ipairs({ 1.5, 4.0 }) do
        local ok, g = GetGroundZFor_3dCoord(x, y, z + dz, false)
        if ok and math.abs(g - z) < 4.5 then return g end
    end
    return z
end

local function setup(ped, weapon, site, idx)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, REL)
    SetPedArmour(ped, GD.armour)
    SetPedAccuracy(ped, GD.accuracy)
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 1)
    SetPedCombatMovement(ped, (idx % 2 == 0) and 2 or 1)     -- (half push in, half hold)
    SetPedCombatAttributes(ped, 0, true); SetPedCombatAttributes(ped, 5, true); SetPedCombatAttributes(ped, 46, true)
    SetPedSeeingRange(ped, GD.sight); SetPedHearingRange(ped, GD.hearShots)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedKeepTask(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    GiveWeaponToPed(ped, joaat(weapon or 'WEAPON_PISTOL'), 250, false, true)
    Entity(ped).state:set('exti_guard', site, true)
end

RegisterNetEvent('exti_heists:client:guardSpawn', function(site, def)
    CreateThread(function()
        local models = def.models or {}
        for _, m in ipairs(models) do pcall(lib.requestModel, joaat(m), 10000) end
        local ids = {}
        for i, g in ipairs(def.guards or {}) do
            local m = joaat(models[(i - 1) % #models + 1])
            -- (the floor / the deck must be loaded first, or they drop through it)
            RequestCollisionAtCoord(g.x, g.y, g.z)
            local tw = GetGameTimer() + 1500
            while GetGameTimer() < tw do RequestCollisionAtCoord(g.x, g.y, g.z); Wait(100) end
            local z = ground(g.x, g.y, g.z)
            local ped = CreatePed(4, m, g.x, g.y, z, g.w or 0.0, true, false)
            if ped ~= 0 then
                FreezeEntityPosition(ped, true)
                SetTimeout(2500, function() if DoesEntityExist(ped) then FreezeEntityPosition(ped, false) end end)
                setup(ped, g.weapon, site, i)
                ids[#ids + 1] = { n = NetworkGetNetworkIdFromEntity(ped), i = i }
            end
        end
        for _, m in ipairs(models) do SetModelAsNoLongerNeeded(joaat(m)) end
        -- (wait until the server knows them, or it can't find them by their ids)
        Wait(600)
        TriggerServerEvent('exti_heists:server:guardSpawned', site, ids)
    end)
end)

-- reinforcements: they come running from where the server says
RegisterNetEvent('exti_heists:client:guardWave', function(site, k, from, count, weapon, models)
    CreateThread(function()
        for _, m in ipairs(models) do pcall(lib.requestModel, joaat(m), 10000) end
        local ids = {}
        for i = 1, count do
            local x, y = from.x + math.random(-30, 30) / 10, from.y + math.random(-30, 30) / 10
            local ped = CreatePed(4, joaat(models[(i - 1) % #models + 1]), x, y, ground(x, y, from.z), from.w or 0.0, true, false)
            if ped ~= 0 then setup(ped, weapon, site, i + k); ids[#ids + 1] = { n = NetworkGetNetworkIdFromEntity(ped) } end
        end
        Wait(600)
        TriggerServerEvent('exti_heists:server:guardSpawned', site, ids)
        PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    end)
end)

---------------------------------------------------------------------------
-- the brain (every guard this game owns, twice a second)
---------------------------------------------------------------------------
local mind = {}   -- [ped] = { sus, stage, next, wait, target, alertSent }
local function isCopPed(ped)
    local pl = NetworkGetPlayerIndexFromPed(ped)
    if pl == -1 then return false end
    local p = Player(GetPlayerServerId(pl)).state
    return p and p.exti_cop == true
end

local function robbersNear(pos, dist)
    local out = {}
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= 0 and not IsPedDeadOrDying(ped, true) and not isCopPed(ped) then
            local d = #(GetEntityCoords(ped) - pos)
            if d < dist then out[#out + 1] = { ped = ped, d = d, sid = GetPlayerServerId(pl) } end
        end
    end
    return out
end

local function inCone(guard, target)
    local gp, tp = GetEntityCoords(guard), GetEntityCoords(target)
    local fwd = GetEntityForwardVector(guard)
    local to = tp - gp
    local l = #to; if l < 0.5 then return true end
    local cos = (fwd.x * to.x + fwd.y * to.y) / (l * math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y) + 0.0001)
    return cos > math.cos(math.rad(GD.cone))
end

local function patrol(ped, m, post)
    if m.stage == 'walk' then
        local p = post.patrol[m.next]
        if #(GetEntityCoords(ped) - vec3(p.x, p.y, p.z)) < 1.6 then
            m.stage, m.wait = 'pause', GetGameTimer() + math.random(4000, 9000)
            TaskStartScenarioInPlace(ped, math.random() < 0.5 and 'WORLD_HUMAN_GUARD_STAND' or 'WORLD_HUMAN_SMOKING', 0, true)
        elseif not GetIsTaskActive(ped, 35) and not m.walking then
            m.walking = true
            TaskGoStraightToCoord(ped, p.x, p.y, p.z, 1.0, -1, 0.0, 0.5)
        end
    elseif m.stage == 'pause' then
        if GetGameTimer() > m.wait then
            ClearPedTasks(ped)
            m.next = m.next % #post.patrol + 1
            m.stage, m.walking = 'walk', false
        end
    end
end

CreateThread(function()
    while true do
        local sleep = 1500
        if next(sites) then
            sleep = 500
            local seenSites = {}
            for _, ped in ipairs(GetGamePool('CPed')) do
                local site = Entity(ped).state.exti_guard
                local S = site and sites[site]
                if S and NetworkHasControlOfEntity(ped) and not IsPedDeadOrDying(ped, true) then
                    local m = mind[ped]
                    local post = Entity(ped).state.exti_guard_post
                    if not m then
                        m = { sus = 0.0, stage = (post and post.patrol and #post.patrol > 1) and 'walk' or 'post', next = 1 }
                        mind[ped] = m
                        SetPedRelationshipGroupHash(ped, REL)   -- (a new owner must set it again)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        if m.stage == 'post' then TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GUARD_STAND', 0, true) end
                    end
                    if m.stage == 'post' and post and post.patrol and #post.patrol > 1 and not S.alert then m.stage = 'walk'; ClearPedTasks(ped) end
                    local gp = GetEntityCoords(ped)
                    if S.alert then
                        -- the fight: the nearest robber, re-picked every few seconds
                        if m.stage ~= 'fight' then m.stage = 'fight'; ClearPedTasks(ped); SetBlockingOfNonTemporaryEvents(ped, false) end
                        if not m.target or not DoesEntityExist(m.target) or IsPedDeadOrDying(m.target, true) or GetGameTimer() > (m.retarget or 0) then
                            local list = robbersNear(gp, 120.0)
                            table.sort(list, function(a, b) return a.d < b.d end)
                            local t = list[1] and list[1].ped
                            if t and t ~= m.target then m.target = t; TaskCombatPed(ped, t, 0, 16) end
                            m.retarget = GetGameTimer() + 4000
                        end
                    else
                        -- eyes and ears
                        for _, r in ipairs(robbersNear(gp, GD.sight + 30.0)) do
                            if IsPedShooting(r.ped) and r.d < GD.hearShots then
                                if not m.alertSent then m.alertSent = true; TriggerServerEvent('exti_heists:server:guardAlert', site, 'shots') end
                            end
                            local seen = r.d < GD.sight and inCone(ped, r.ped) and HasEntityClearLosToEntity(ped, r.ped, 17)
                            local heard = r.d < GD.hearRun and (IsPedSprinting(r.ped) or IsPedRunning(r.ped))
                            if seen or heard then
                                local k = 1.0
                                if IsPedArmed(r.ped, 6) then k = k * 1.8 end
                                if GetPedDrawableVariation(r.ped, 1) > 0 then k = k * 1.3 end
                                if IsPedSprinting(r.ped) or IsPedRunning(r.ped) then k = k * 1.4 end
                                if GetPedStealthMovement(r.ped) then k = k * 0.45 end
                                if r.d < 6.0 then k = k * 2.0 end
                                if S.blind then k = k * 0.6 end
                                m.sus = m.sus + 0.5 / GD.noticeSeconds * k
                                if m.sus > 0.35 and not m.looking then
                                    -- he turns and looks
                                    m.looking = true; ClearPedTasks(ped); TaskTurnPedToFaceEntity(ped, r.ped, 1500)
                                    if math.random() < 0.5 then PlayPedAmbientSpeechNative(ped, 'GENERIC_WHATEVER', 'SPEECH_PARAMS_FORCE_SHOUTED') end
                                end
                            end
                        end
                        m.sus = math.max(0, m.sus - 0.08)
                        if m.sus >= 1.0 and not m.alertSent then m.alertSent = true; TriggerServerEvent('exti_heists:server:guardAlert', site, 'seen') end
                        if m.looking and m.sus < 0.15 then m.looking = false; m.walking = false; if m.stage == 'post' then TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GUARD_STAND', 0, true) end end
                        if not m.looking and post and post.patrol and #post.patrol > 1 then patrol(ped, m, post) end
                        -- a guard who got hurt or saw his friend go down: the alarm
                        if HasEntityBeenDamagedByAnyPed(ped) and not m.alertSent then m.alertSent = true; TriggerServerEvent('exti_heists:server:guardAlert', site, 'hurt') end
                    end
                    seenSites[site] = true
                end
            end
            for ped in pairs(mind) do if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then mind[ped] = nil end end
        end
        Wait(sleep)
    end
end)

-- officers carry a flag the guards' brains can read (they never fight a cop on duty)
CreateThread(function()
    local last
    while true do
        local j = QBX and QBX.PlayerData and QBX.PlayerData.job
        local cop = j ~= nil and j.name == C.cops.job and j.onduty == true
        if cop ~= last then last = cop; LocalPlayer.state:set('exti_cop', cop, true) end
        Wait(3000)
    end
end)
