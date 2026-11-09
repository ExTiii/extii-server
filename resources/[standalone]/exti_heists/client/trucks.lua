-- =====================================================================
-- EX_Tii heists (game side): the armored truck and the convoy. The game that owns the driver drives it
-- leg by leg (and the escorts stick to it); any robber close by tells the server when it really stopped;
-- then the guards get out and fight. At the back: the C4, the fuse bar, the blast, the bags.
-- =====================================================================
local C = Config
local REL = joaat(C.guards.rel)
local jobs = {}
local fuseEnds = {}
local function setJobs(v)
    jobs = v or {}
    for id, j in pairs(jobs) do if j.fuseLeft and j.fuseLeft > 0 then fuseEnds[id] = GetGameTimer() + j.fuseLeft * 1000 else fuseEnds[id] = nil end end
end
setJobs(GlobalState['exti_heists:trucks'])
AddStateBagChangeHandler('exti_heists:trucks', 'global', function(_, _, v) setJobs(v) end)

local function ent(n) return (n and NetworkDoesNetworkIdExist(n)) and NetworkGetEntityFromNetworkId(n) or 0 end
local function rearOf(veh) return GetOffsetFromEntityInWorldCoords(veh, 0.0, -4.2, 0.0) end

-- the server asks this game to make the truck (and its escorts) at the start of its route
local function ground(x, y, z) local ok, g = GetGroundZFor_3dCoord(x, y, z + 3.0, false); return ok and g or z end
local function makeCar(model, x, y, z, h, crew, guardModel)
    local vm, gm = joaat(model), joaat(guardModel)
    if not pcall(lib.requestModel, vm, 10000) or not pcall(lib.requestModel, gm, 10000) then return nil end
    local veh = CreateVehicle(vm, x, y, ground(x, y, z) + 0.4, h, true, false)
    if veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleEngineOn(veh, true, true, false)
    local peds = {}
    for _, c in ipairs(crew) do
        local ped = CreatePedInsideVehicle(veh, 4, gm, c.seat, true, false)
        if ped ~= 0 then
            SetEntityAsMissionEntity(ped, true, true)
            GiveWeaponToPed(ped, joaat(c.weapon), 300, false, true)
            SetPedArmour(ped, 80); SetPedAccuracy(ped, C.guards.accuracy)
            SetPedRelationshipGroupHash(ped, REL)
            SetPedCombatAttributes(ped, 46, true); SetPedCombatAttributes(ped, 0, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedKeepTask(ped, true)
            peds[#peds + 1] = NetworkGetNetworkIdFromEntity(ped)
        end
    end
    return veh, peds
end
RegisterNetEvent('exti_heists:client:truckSpawn', function(id, s, model, crew, escorts, guardModel)
    CreateThread(function()
        local veh, peds = makeCar(model, s.x, s.y, s.z, s.w or 0.0, crew, guardModel)
        if not veh then return end
        local out = {}
        for k, e in ipairs(escorts or {}) do
            local back = GetOffsetFromEntityInWorldCoords(veh, 0.0, -9.0 * k, 0.0)
            local ev, ep = makeCar(e.model, back.x, back.y, back.z, s.w or 0.0, e.crew, guardModel)
            if ev then out[#out + 1] = { veh = NetworkGetNetworkIdFromEntity(ev), peds = ep } end
        end
        Wait(600)   -- (until the server knows them)
        TriggerServerEvent('exti_heists:server:truckSpawned', tonumber(id), NetworkGetNetworkIdFromEntity(veh), peds, out)
    end)
end)

local driving = {}   -- [id] = leg I tasked
local stillSince = {}
local fought = {}    -- [ped] = time of the last target pick
local sentAt = {}    -- [id] = when this game last said 'stopped'

local function isCopPed(ped)
    local pl = NetworkGetPlayerIndexFromPed(ped)
    if pl == -1 then return false end
    local st = Player(GetPlayerServerId(pl)).state
    return st and st.exti_cop == true
end
local function nearestRobber(pos, dist)
    local best, bd
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= 0 and not IsPedDeadOrDying(ped, true) and not isCopPed(ped) then
            local d = #(GetEntityCoords(ped) - pos)
            if d < dist and (not bd or d < bd) then best, bd = ped, d end
        end
    end
    return best
end

local function fight(ped, veh)
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or not NetworkHasControlOfEntity(ped) then return end
    SetPedRelationshipGroupHash(ped, REL)
    SetPedAccuracy(ped, C.guards.accuracy)
    SetPedCombatAttributes(ped, 46, true); SetPedCombatAttributes(ped, 0, true)
    if GetGameTimer() < (fought[ped] or 0) then return end
    fought[ped] = GetGameTimer() + 4000
    if veh ~= 0 and IsPedInVehicle(ped, veh, false) then TaskLeaveVehicle(ped, veh, 256); return end
    local t = nearestRobber(GetEntityCoords(ped), 120.0)
    if t then TaskCombatPed(ped, t, 0, 16) end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local me = GetEntityCoords(cache.ped)
        for id, j in pairs(jobs) do
            local veh = ent(j.veh)
            if veh ~= 0 and DoesEntityExist(veh) then
                local vp = GetEntityCoords(veh)
                local near = #(me - vp)
                if near < 250.0 then sleep = 500 end
                if j.phase == 'drive' then
                    -- the driver (if mine): the next leg
                    local drv = GetPedInVehicleSeat(veh, -1)
                    if drv ~= 0 and NetworkHasControlOfEntity(drv) and not IsPedDeadOrDying(drv, true) then
                        local p = j.route[j.leg]
                        if p then
                            if driving[id] ~= j.leg or not GetIsTaskActive(drv, 169) and #(GetEntityVelocity(veh)) < 0.5 then
                                driving[id] = j.leg
                                SetDriverAbility(drv, 1.0); SetDriverAggressiveness(drv, 0.0)
                                TaskVehicleDriveToCoordLongrange(drv, veh, p.x, p.y, p.z, j.speed or 15.0, 786603, 20.0)
                            end
                            if #(vp - vec3(p.x, p.y, p.z)) < 25.0 then TriggerServerEvent('exti_heists:server:truckLeg', tonumber(id), j.leg) end
                        end
                    end
                    -- the escorts (if mine): stay behind the truck
                    for _, e in ipairs(j.escorts or {}) do
                        local ev = ent(e.veh)
                        local ed = ev ~= 0 and GetPedInVehicleSeat(ev, -1) or 0
                        if ed ~= 0 and NetworkHasControlOfEntity(ed) and not GetIsTaskActive(ed, 151) then
                            TaskVehicleEscort(ed, ev, veh, -1, (j.speed or 15.0) + 4.0, 786603, 8.0, 0, 20.0)
                        end
                    end
                    -- stopped for real? (a robber close by says so)
                    if near < 70.0 and not LocalPlayer.state.exti_cop then
                        local stopped = #(GetEntityVelocity(veh)) < 1.0
                        local d = GetPedInVehicleSeat(veh, -1)
                        local why
                        if d == 0 or IsPedDeadOrDying(d, true) then why = 'driver'
                        elseif GetVehicleEngineHealth(veh) < 250.0 then why = 'engine'
                        elseif stopped then
                            stillSince[id] = stillSince[id] or GetGameTimer()
                            if GetGameTimer() - stillSince[id] > 4000 then why = 'blocked' end
                        else stillSince[id] = nil end
                        if why and GetGameTimer() > (sentAt[id] or 0) then sentAt[id] = GetGameTimer() + 3000; TriggerServerEvent('exti_heists:server:truckStopped', tonumber(id), why) end
                    end
                else
                    -- the fight: every guard this game owns
                    for _, n in ipairs(j.peds or {}) do fight(ent(n), veh) end
                    for _, e in ipairs(j.escorts or {}) do
                        local ev = ent(e.veh)
                        for _, n in ipairs(e.peds or {}) do fight(ent(n), ev) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- the back of the truck: C4, the fuse bar, the bags
---------------------------------------------------------------------------
local busy = false
local function plant(id)
    busy = true; HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:truckC4Begin', false, tonumber(id))
    if not ok then busy = false; if token then HC.notify(token, 'error') end return end
    HC.anim(cache.ped, 'anim@heists@ornate_bank@thermal_charge', 'thermal_charge', 1)
    local passed = HC.play('c4', params, 'الباب الخلفي')
    ClearPedTasks(cache.ped)
    local done, fuse = lib.callback.await('exti_heists:server:truckC4End', false, token, passed)
    if done then HC.notify(('الفتيل يعمل: %d ثانية. ابتعد!'):format(fuse), 'warning', 6000)
    elseif fuse == 'fault' then HC.notify('عطل في الدائرة: ضاع الـ C4', 'error') end
    busy = false
end
local function grab(id, left)
    busy = true; HC.prompt(nil)
    local ok, secs = lib.callback.await('exti_heists:server:truckBagBegin', false, tonumber(id))
    if not ok then busy = false return end
    local done = lib.progressCircle({ duration = secs * 1000, label = 'تسحب الحقيبة...', position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 } })
    if done then
        local got, res = lib.callback.await('exti_heists:server:truckBagEnd', false)
        if got and res then HC.notify(('حقيبة: $%d%s · بقي %d'):format(res.money, res.usb and ' + فلاشة' or '', res.left), 'success', 5000) end
    end
    busy = false
end

CreateThread(function()
    local barShown = false
    while true do
        local sleep = 700
        local text, action, bar
        if next(jobs) then
            local me = GetEntityCoords(cache.ped)
            for id, j in pairs(jobs) do
                local veh = ent(j.veh)
                if veh ~= 0 and DoesEntityExist(veh) then
                    local r = rearOf(veh)
                    local d = #(me - r)
                    if fuseEnds[id] and fuseEnds[id] > GetGameTimer() and d < 60.0 then
                        bar = { kind = 'fuse', seconds = math.ceil((fuseEnds[id] - GetGameTimer()) / 1000) }
                    end
                    if d < 2.2 and not busy and HC.canAct() and not LocalPlayer.state.exti_cop then
                        sleep = 0
                        if j.phase == 'stopped' then text, action = '[E] ضع C4 على الباب الخلفي', function() plant(id) end
                        elseif j.phase == 'open' and (j.bags or 0) > 0 then text, action = ('[E] خذ حقيبة (%d)'):format(j.bags), function() grab(id) end end
                    end
                end
            end
        end
        HC.prompt(text, 'truck')
        if action and (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) and HC.lineIs(text) then CreateThread(action); Wait(400) end
        if bar and not (HC.hunted and HC.hunted()) then SendNUIMessage({ action = 'hud', state = bar }); barShown = true
        elseif barShown and not (HC.hunted and HC.hunted()) then SendNUIMessage({ action = 'hud', state = nil }); barShown = false end
        Wait(sleep)
    end
end)

-- the blast (the game that owns the truck makes it, so there is one blast for everyone)
RegisterNetEvent('exti_heists:client:truckBlow', function(vehNet, r)
    local veh = ent(vehNet)
    if veh == 0 or not NetworkHasControlOfEntity(veh) then return end
    AddExplosion(r.x, r.y, r.z + 0.6, 2, 0.35, true, false, 1.0)
    SetVehicleDoorBroken(veh, 2, false); SetVehicleDoorBroken(veh, 3, false)
    SetVehicleDoorOpen(veh, 5, false, true)
end)

-- officers: the truck's GPS dot (for the first few minutes)
local gpsBlip
RegisterNetEvent('exti_heists:client:truckGps', function(p, left)
    if gpsBlip and DoesBlipExist(gpsBlip) then RemoveBlip(gpsBlip) end
    gpsBlip = AddBlipForCoord(p.x + 0.0, p.y + 0.0, 0.0)
    SetBlipSprite(gpsBlip, 67); SetBlipColour(gpsBlip, 1); SetBlipScale(gpsBlip, 1.0); SetBlipFlashes(gpsBlip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(('GPS الشاحنة المصفّحة (%d ث)'):format(left)); EndTextCommandSetBlipName(gpsBlip)
    local b = gpsBlip
    SetTimeout(6000, function() if b and DoesBlipExist(b) then RemoveBlip(b) end end)
end)
