-- =====================================================================
-- EX_Tii (Moe): no NPCs in the port, on each player's game too (the server does the same in npc.lua):
--  * the road from the checkpoint to the gate is switched off for NPC traffic (they don't drive in at all)
--  * while you are inside the port, the game makes no new NPCs or NPC cars around you
--  * NPCs / NPC cars your game is running that are inside are removed at once
-- Players, their cars and anything a script made are never touched.
-- =====================================================================
local CORRIDOR = 14.0
local BEHIND = 6.0

local poly, corridor, box = {}, nil, nil
local roadsOff = nil   -- the corridor we switched off: { ax, ay, az, bx, by, bz }

local function rebuild()
    local marks = GlobalState.extiPort
    local c = GlobalState.extiPortCheckpoint
    poly, corridor, box = {}, nil, nil
    local gate
    for _, m in ipairs(type(marks) == 'table' and marks or {}) do
        if m.kind == 'corner' then poly[#poly + 1] = { x = m.x, y = m.y } end
        if m.kind == 'gate' then gate = m end
    end
    if #poly < 3 then poly = {} end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(poly) do
        minX, minY, maxX, maxY = math.min(minX, p.x), math.min(minY, p.y), math.max(maxX, p.x), math.max(maxY, p.y)
    end
    if type(c) == 'table' and c.x and gate then
        local dx, dy = gate.x - c.x, gate.y - c.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1.0 then
            dx, dy = dx / len, dy / len
            corridor = { ax = c.x - dx * BEHIND, ay = c.y - dy * BEHIND, az = c.z, bx = gate.x, by = gate.y, bz = gate.z }
            for _, p in ipairs({ { corridor.ax, corridor.ay }, { corridor.bx, corridor.by } }) do
                minX, minY = math.min(minX, p[1] - CORRIDOR), math.min(minY, p[2] - CORRIDOR)
                maxX, maxY = math.max(maxX, p[1] + CORRIDOR), math.max(maxY, p[2] + CORRIDOR)
            end
        end
    end
    if minX ~= math.huge then box = { minX = minX, minY = minY, maxX = maxX, maxY = maxY } end

    -- NPC traffic: the road from the checkpoint to the gate is off (put back first if it moved)
    if roadsOff then
        local r = roadsOff
        SetRoadsBackToOriginalInAngledArea(r.ax, r.ay, r.az - 20.0, r.bx, r.by, r.bz + 20.0, CORRIDOR * 2.0, 0)
        roadsOff = nil
    end
    if corridor then
        local r = corridor
        SetRoadsInAngledArea(r.ax, r.ay, r.az - 20.0, r.bx, r.by, r.bz + 20.0, CORRIDOR * 2.0, false, false, false)
        roadsOff = r
    end
end

local function inPoly(x, y)
    local inside, j = false, #poly
    for i = 1, #poly do
        local a, b = poly[i], poly[j]
        if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) then inside = not inside end
        j = i
    end
    return inside
end

local function inCorridor(x, y)
    if not corridor then return false end
    local ax, ay, bx, by = corridor.ax, corridor.ay, corridor.bx, corridor.by
    local vx, vy = bx - ax, by - ay
    local t = ((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy)
    if t < 0.0 or t > 1.0 then return false end
    local px, py = ax + vx * t - x, ay + vy * t - y
    return px * px + py * py <= CORRIDOR * CORRIDOR
end

local function inPort(p)
    if not box or p.x < box.minX or p.x > box.maxX or p.y < box.minY or p.y > box.maxY then return false end
    return inCorridor(p.x, p.y) or (#poly > 0 and inPoly(p.x, p.y))
end

local function isAmbient(e)
    local t = GetEntityPopulationType(e)
    return t >= 1 and t <= 5
end

local function hasPlayer(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

local function remove(e)
    if NetworkGetEntityIsNetworked(e) and NetworkGetEntityOwner(e) ~= PlayerId() then return end   -- (its owner's game removes it)
    SetEntityAsMissionEntity(e, true, true)
    DeleteEntity(e)
end

AddStateBagChangeHandler('extiPort', 'global', function() SetTimeout(0, rebuild) end)
AddStateBagChangeHandler('extiPortCheckpoint', 'global', function() SetTimeout(0, rebuild) end)

CreateThread(function()
    Wait(1500)
    rebuild()
    while true do
        local sleep = 2000
        local me = GetEntityCoords(cache.ped)
        if box and me.x > box.minX - 300.0 and me.x < box.maxX + 300.0 and me.y > box.minY - 300.0 and me.y < box.maxY + 300.0 then
            sleep = 1000
            for _, ped in ipairs(GetGamePool('CPed')) do
                if ped ~= cache.ped and not IsPedAPlayer(ped) and isAmbient(ped) and inPort(GetEntityCoords(ped)) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh == 0 or not hasPlayer(veh) then remove(ped) end
                end
            end
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if isAmbient(veh) and not hasPlayer(veh) and not Entity(veh).state.extiPlayerUsed and inPort(GetEntityCoords(veh)) then
                    remove(veh)
                end
            end
        end
        Wait(sleep)
    end
end)

-- inside the port: no new NPCs or NPC cars around you
CreateThread(function()
    while true do
        if box and inPort(GetEntityCoords(cache.ped)) then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not roadsOff then return end
    local r = roadsOff
    SetRoadsBackToOriginalInAngledArea(r.ax, r.ay, r.az - 20.0, r.bx, r.by, r.bz + 20.0, CORRIDOR * 2.0, 0)
end)
