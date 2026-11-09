-- =====================================================================
-- EX_Tii (Moe): the port entrance checkpoint (on the road under the "West Docks · Pier 400" signs).
-- A guard booth in the middle of the road, a boom barrier across each direction, stop signs.
-- Closed: police on duty raise/lower it from the booth ([E]). With no police on duty it stays up.
-- Built on each player's game when near (a few objects); the barriers move the same for everyone.
-- =====================================================================
local CP = Config.checkpoint
local objs, arms = {}, {}       -- everything made; the barrier arms { obj, hinge, h, dims, angle }
local made = false
local spot = nil                -- { x, y, z, h } (h = facing into the port)

local function firstModel(list, override)
    local all = {}
    if tonumber(override) then all[#all + 1] = tonumber(override) end
    for _, n in ipairs(list) do all[#all + 1] = joaat(n) end
    for _, h in ipairs(all) do
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
end

local function dimsOf(m)
    local mn, mx = GetModelDimensions(m)
    return { mn = mn, mx = mx, len = mx.x - mn.x, cy = (mn.y + mx.y) / 2 }
end

-- a point to the right (+) / forward (+) of the spot, on the road
local function at(right, fwd)
    local r = math.rad(spot.h)
    local fx, fy = -math.sin(r), math.cos(r)      -- facing into the port
    local rx, ry = fy, -fx                        -- its right hand
    return vec3(spot.x + rx * right + fx * fwd, spot.y + ry * right + fy * fwd, spot.z)
end

local function ground(p)
    local ok, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
    return (ok and math.abs(z - p.z) < 3.0) and z or p.z
end

local function place(m, p, heading)
    local d = dimsOf(m)
    local z = ground(p)
    local o = CreateObjectNoOffset(m, p.x, p.y, z - d.mn.z, false, false, false)
    if o ~= 0 then
        SetEntityHeading(o, heading)
        FreezeEntityPosition(o, true)
        SetEntityInvincible(o, true)
        objs[#objs + 1] = o
    end
    return o, d, z
end

-- a barrier arm: its hinge end stays put, it lifts (angle 0 = across the road, CP.armUp = raised)
local function poseArm(a)
    local d = a.d
    -- turn it, then move it so its hinge end sits on the hinge point (works whatever the model's centre is)
    SetEntityRotation(a.obj, 0.0, a.sign * a.angle, a.h, 2, true)
    local now = GetOffsetFromEntityInWorldCoords(a.obj, d.mn.x, d.cy, d.mn.z)
    local cur = GetEntityCoords(a.obj)
    SetEntityCoordsNoOffset(a.obj, cur.x + (a.hinge.x - now.x), cur.y + (a.hinge.y - now.y), cur.z + (a.hinge.z - now.z), false, false, false)
end

local function addArm(m, hingeP, towards)
    local d = dimsOf(m)
    local z = ground(hingeP)
    local h = math.deg(math.atan(towards.y - hingeP.y, towards.x - hingeP.x))   -- the arm points this way
    local o = CreateObjectNoOffset(m, hingeP.x, hingeP.y, z, false, false, false)
    if o == 0 then return end
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    objs[#objs + 1] = o
    local a = { obj = o, d = d, h = h, hinge = vec3(hingeP.x, hingeP.y, z + CP.armHeight), angle = 0.0, sign = 1 }
    -- which way is "up" for this model: try a lift and look where the far end went
    a.angle = 30.0; poseArm(a)
    local tip = GetOffsetFromEntityInWorldCoords(o, d.mx.x, d.cy, d.mn.z)
    if tip.z < a.hinge.z then a.sign = -1 end
    a.angle = 0.0; poseArm(a)
    arms[#arms + 1] = a
end

local function clearGate()
    for _, o in ipairs(objs) do if DoesEntityExist(o) then DeleteEntity(o) end end
    objs, arms, made = {}, {}, false
end

local function makeGate()
    clearGate()
    if not spot then return end
    made = true
    local W = CP.halfWidth
    -- the booth, in the middle of the road
    local booth = firstModel(CP.boothModels, GlobalState.extiPortBoothModel)
    local boothHalf = 1.5
    if booth then
        local _, bd = place(booth, at(0.0, 0.0), spot.h)
        boothHalf = math.max(1.0, math.min(3.0, (bd.mx.x - bd.mn.x) / 2))
    else
        print('^3[exti_port] no booth model found^0')
    end
    -- the barriers: for each direction one arm from the road edge and one from the booth, meeting in the lane
    local arm = firstModel(CP.armModels, GlobalState.extiPortArmModel)
    if arm then
        for _, side in ipairs({ 1, -1 }) do                   -- right = into the port, left = out
            local edge, mid = at(side * W, side * 1.5), at(side * boothHalf, side * 1.5)
            addArm(arm, edge, mid)
            addArm(arm, mid, edge)
        end
    else
        print('^3[exti_port] no barrier arm model found^0')
    end
    -- stop signs at the road edges, facing the cars coming in / going out
    local sign = firstModel(CP.signModels)
    if sign then
        place(sign, at(W + 0.8, -3.0), spot.h + 180.0)
        place(sign, at(-W - 0.8, 3.0), spot.h)
    end
end

local function readSpot()
    local c = GlobalState.extiPortCheckpoint
    spot = type(c) == 'table' and c.x and { x = c.x, y = c.y, z = c.z, h = c.h } or nil
    if made then makeGate() end
end
AddStateBagChangeHandler('extiPortCheckpoint', 'global', function() SetTimeout(0, readSpot) end)
AddStateBagChangeHandler('extiPortBoothModel', 'global', function() SetTimeout(0, function() if made then makeGate() end end) end)
AddStateBagChangeHandler('extiPortArmModel', 'global', function() SetTimeout(0, function() if made then makeGate() end end) end)
CreateThread(function() Wait(800); readSpot() end)

local function isOpen()
    return (tonumber(GlobalState.extiPortCops) or 0) < 1 or GlobalState.extiPortBarrierOpen == true
end

-- made when near, removed when far; the arms move towards open / closed
CreateThread(function()
    local last = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local dt = math.min(0.1, (now - last) / 1000.0)
        last = now
        local wait = 1000
        if spot then
            local d = #(GetEntityCoords(cache.ped).xy - vector2(spot.x, spot.y))
            if d < CP.distance and not made then makeGate()
            elseif d > CP.distance + 30.0 and made then clearGate() end
            if made then
                wait = 250
                local target = isOpen() and CP.armUp or 0.0
                for _, a in ipairs(arms) do
                    if math.abs(a.angle - target) > 0.1 then
                        local step = CP.armSpeed * dt
                        a.angle = a.angle < target and math.min(target, a.angle + step) or math.max(target, a.angle - step)
                        poseArm(a)
                        wait = 0
                    end
                end
            end
        end
        Wait(wait)
    end
end)

-- police at the booth: [E] raise / lower the barriers
local function onDutyCop()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local job = ok and data and data.job
    return job and job.name == CP.policeJob and job.onduty == true
end
CreateThread(function()
    local shown = false
    while true do
        local sleep = 1000
        if made and spot and onDutyCop() and not cache.vehicle then
            local d = #(GetEntityCoords(cache.ped) - vec3(spot.x, spot.y, spot.z))
            if d < 30.0 then sleep = 250 end
            if d < CP.reach then
                sleep = 0
                local text = GlobalState.extiPortBarrierOpen and '[E] أنزل حاجز الميناء' or '[E] ارفع حاجز الميناء'
                lib.showTextUI(text); shown = true
                if IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName()) then
                    TriggerServerEvent('exti_port:server:barrier')
                    lib.hideTextUI(); shown = false
                    Wait(800)
                end
            elseif shown then lib.hideTextUI(); shown = false end
        elseif shown then lib.hideTextUI(); shown = false end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clearGate() end end)
