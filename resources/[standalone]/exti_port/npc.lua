-- =====================================================================
-- EX_Tii (Moe): no NPCs in the port. Inside the fence, and on the road from the entrance checkpoint to the
-- front gate: no people walking around and no NPC cars (driving or parked). Players, their cars and
-- anything a script made (job peds, shop clerks, police cars) are never touched.
-- Done on the server: NPCs are stopped as the game makes them, and any that are already there are removed.
-- =====================================================================
local CORRIDOR = 14.0      -- metres either side of the road from the checkpoint to the gate
local BEHIND = 6.0         -- metres the clear zone starts before the checkpoint (the booth and its stop sign)

local poly, corridor = {}, nil   -- the fence corners { x, y }; the road { ax, ay, bx, by }
local minX, minY, maxX, maxY

local function rebuild()
    local d = PORT and PORT.data() or {}
    poly, corridor = {}, nil
    minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local gate
    for _, m in ipairs(d.marks or {}) do
        if m.kind == 'corner' then poly[#poly + 1] = { x = m.x, y = m.y } end
        if m.kind == 'gate' then gate = m end
    end
    if #poly < 3 then poly = {} end
    for _, p in ipairs(poly) do
        minX, minY, maxX, maxY = math.min(minX, p.x), math.min(minY, p.y), math.max(maxX, p.x), math.max(maxY, p.y)
    end
    local c = d.checkpoint
    if c and gate then
        -- from a little before the checkpoint to the gate
        local dx, dy = gate.x - c.x, gate.y - c.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1.0 then
            dx, dy = dx / len, dy / len
            corridor = { ax = c.x - dx * BEHIND, ay = c.y - dy * BEHIND, bx = gate.x, by = gate.y }
            for _, p in ipairs({ { corridor.ax, corridor.ay }, { corridor.bx, corridor.by } }) do
                minX, minY = math.min(minX, p[1] - CORRIDOR), math.min(minY, p[2] - CORRIDOR)
                maxX, maxY = math.max(maxX, p[1] + CORRIDOR), math.max(maxY, p[2] + CORRIDOR)
            end
        end
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

local function inPort(coords)
    if not minX or minX == math.huge then return false end
    local x, y = coords.x, coords.y
    if x < minX or x > maxX or y < minY or y > maxY then return false end
    return inCorridor(x, y) or (#poly > 0 and inPoly(x, y))
end

-- 1 random permanent, 2 parked, 3 patrol, 4 scenario, 5 ambient = made by the game (6/7 = scripts and players)
local function isAmbient(entity)
    local t = GetEntityPopulationType(entity)
    return t >= 1 and t <= 5
end

local function hasPlayer(veh)
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

-- the game making an NPC or an NPC car in the port: not made at all
AddEventHandler('entityCreating', function(entity)
    if not DoesEntityExist(entity) or not isAmbient(entity) then return end
    local kind = GetEntityType(entity)
    if kind ~= 1 and kind ~= 2 then return end          -- people and cars only (no props)
    if kind == 1 and IsPedAPlayer(entity) then return end
    if inPort(GetEntityCoords(entity)) then CancelEvent() end
end)

-- any already there (made before this started, or that walked / drove in): removed
local removed = 0
local function sweep()
    for _, ped in ipairs(GetAllPeds()) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and isAmbient(ped) and inPort(GetEntityCoords(ped)) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 or not hasPlayer(veh) then DeleteEntity(ped) removed = removed + 1 end
        end
    end
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and isAmbient(veh) then
            local st = Entity(veh).state
            if hasPlayer(veh) then
                if not st.extiPlayerUsed then st:set('extiPlayerUsed', true, false) end   -- (a player took it: it stays)
            elseif not st.extiPlayerUsed and inPort(GetEntityCoords(veh)) then
                DeleteEntity(veh)
                removed = removed + 1
            end
        end
    end
end

CreateThread(function()
    Wait(2000)
    rebuild()
    local last, told, warned = 0, 0, false
    while true do
        -- (the fence or the checkpoint may have been changed with /port)
        if GetGameTimer() - last > 30000 then rebuild(); last = GetGameTimer() end
        local ok, err = pcall(sweep)
        if not ok and not warned then warned = true print('^1[exti_port] npc sweep: ' .. tostring(err) .. '^0') end
        if removed > 0 and GetGameTimer() - told > 60000 then
            print(('[exti_port] removed %d NPCs / NPC cars from the port'):format(removed))
            removed, told = 0, GetGameTimer()
        end
        Wait(2000)
    end
end)
AddStateBagChangeHandler('extiPortCheckpoint', 'global', function() SetTimeout(0, rebuild) end)
AddStateBagChangeHandler('extiPort', 'global', function() SetTimeout(0, rebuild) end)
