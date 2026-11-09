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
local used = {}                 -- the models picked (for /portgate)

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
    return { mn = mn, mx = mx, len = mx.x - mn.x, cx = (mn.x + mx.x) / 2, cy = (mn.y + mx.y) / 2 }
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

local function spawn(m, x, y, z)
    local o = CreateObjectNoOffset(m, x, y, z, false, false, false)
    if o == 0 then o = CreateObjectNoOffset(m, x, y, z, false, false, true) end   -- a door-type model
    return o
end

local function place(m, p, heading)
    local d = dimsOf(m)
    local z = ground(p)
    local o = spawn(m, p.x, p.y, z - d.mn.z)
    if o ~= 0 then
        SetEntityHeading(o, heading)
        FreezeEntityPosition(o, true)
        SetEntityInvincible(o, true)
        objs[#objs + 1] = o
    end
    return o, d, z
end

-- a swing gate (the prison's gate model): hinged at the road edge. Closed = across its lane to the booth,
-- open = swung 90 degrees into the port, lying along the side wall. Works whether the model is long along X or Y.
local function poseGate(g)
    local yaw = g.closedDir + g.delta * g.t                 -- the way the gate points from its hinge now
    SetEntityHeading(g.obj, g.ax == 'x' and yaw or (yaw - 90.0))   -- (a model's +Y is its heading)
    local d = g.d
    local hx, hy = (g.ax == 'x') and d.mn.x or d.cx, (g.ax == 'x') and d.cy or d.mn.y
    local now = GetOffsetFromEntityInWorldCoords(g.obj, hx, hy, d.mn.z)
    local cur = GetEntityCoords(g.obj)
    SetEntityCoordsNoOffset(g.obj, cur.x + (g.hinge.x - now.x), cur.y + (g.hinge.y - now.y), cur.z + (g.hinge.z - now.z), false, false, false)
end

local function angleOf(v) return math.deg(math.atan(v.y, v.x)) end

local function addSwing(m, side, W)
    local d = dimsOf(m)
    local ax = (d.mx.x - d.mn.x) >= (d.mx.y - d.mn.y) and 'x' or 'y'
    local hingeP = at(side * W, side * CP.gateForward)
    local z = ground(hingeP)
    local rr = math.rad(spot.h)
    local right = vec3(math.cos(rr), math.sin(rr), 0.0)    -- the right hand when facing into the port
    local fwd = vec3(-math.sin(rr), math.cos(rr), 0.0)     -- into the port
    local closedDir = angleOf(right * -side)               -- from the road edge towards the booth
    local delta = angleOf(fwd) - closedDir                 -- swing into the port: the short way round (90 degrees)
    delta = (delta + 180.0) % 360.0 - 180.0
    local o = spawn(m, hingeP.x, hingeP.y, z - d.mn.z)
    if o == 0 then print('^3[exti_port] the gate could not be made^0') return end
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    objs[#objs + 1] = o
    local g = { obj = o, d = d, ax = ax, hinge = vec3(hingeP.x, hingeP.y, z), closedDir = closedDir, delta = delta, t = 0.0 }
    poseGate(g)
    arms[#arms + 1] = g
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
    used = { booth = booth }
    local boothHalf = 1.5
    if booth then
        local _, bd = place(booth, at(0.0, 0.0), spot.h)
        boothHalf = math.max(1.0, math.min(3.0, (bd.mx.x - bd.mn.x) / 2))
    else
        print('^3[exti_port] no booth model found^0')
    end
    -- the gates: one swing gate across each lane, hinged at the road edge (right = into the port, left = out)
    local gate = firstModel(CP.gateModels, GlobalState.extiPortArmModel)
    used.arm = gate
    if gate then
        addSwing(gate, 1, W)
        addSwing(gate, -1, W)
    else
        print('^3[exti_port] no gate model found^0')
    end
    -- stop signs at the road edges, facing the cars coming in / going out
    local sign = firstModel(CP.signModels)
    if sign then
        place(sign, at(W + 0.8, -3.0), spot.h)            -- faces the cars coming in (right side)
        place(sign, at(-W - 0.8, 3.0), spot.h + 180.0)    -- faces the cars going out (left side)
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
                local target = isOpen() and 1.0 or 0.0
                for _, g in ipairs(arms) do
                    if math.abs(g.t - target) > 0.001 then
                        local step = dt / CP.gateSwingTime
                        g.t = g.t < target and math.min(target, g.t + step) or math.max(target, g.t - step)
                        poseGate(g)
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

-- /portgate (admin look): which booth / barrier models exist in this game, and what was built
RegisterCommand('portgate', function()
    local function list(title, names)
        for _, n in ipairs(names) do
            local hsh = joaat(n)
            local ok = IsModelInCdimage(hsh) and IsModelValid(hsh)
            local size = ''
            if ok then
                RequestModel(hsh)
                local t = GetGameTimer() + 2000
                while not HasModelLoaded(hsh) and GetGameTimer() < t do Wait(10) end
                local mn, mx = GetModelDimensions(hsh)
                size = (' size %.2f x %.2f x %.2f'):format(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
            end
            print(('[exti_port] %s %s %s%s'):format(title, n, ok and 'YES' or 'no', size))
        end
    end
    list('booth', CP.boothModels)
    list('gate', CP.gateModels)
    print(('[exti_port] spot %s made %s booth %s gate %s gates %d cops %s open %s'):format(spot and 'yes' or 'no', tostring(made),
        tostring(used.booth), tostring(used.arm), #arms, tostring(GlobalState.extiPortCops), tostring(isOpen())))
    for i, a in ipairs(arms) do
        local c = GetEntityCoords(a.obj)
        print(('[exti_port] gate %d axis %s open %.2f at %.1f %.1f %.1f'):format(i, a.ax, a.t, c.x, c.y, c.z))
    end
    lib.notify({ description = 'افتح F8 وصوّر الأسطر التي تبدأ بـ [exti_port]', type = 'inform' })
end, false)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clearGate() end end)
