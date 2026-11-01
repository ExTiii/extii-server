-- EX_Tii GPS: one thin gold route line.
--
-- GTA's route line has a fixed width. So GTA finds the way (hidden), we read the points along that
-- way and draw them ourselves as a thin line (a "custom route" with our own width and colour).
-- If the way can't be read, GTA's own line is shown on the destination icon instead.
--
-- Other resources (client side):
--   exports.exti_gps:Route(key, coords, { blip = blipHandle })  -- a route to a script's own map icon
--   exports.exti_gps:ClearRoute(key)
--   exports.exti_gps:GoTo(x, y, z, label)                        -- "take me there": a yellow pin + the line
-- The newest route is the one drawn. When it ends, the one before it comes back.

local routes = {}       -- every route that wants a line, newest last
local active = nil      -- the route the line is drawn for
local gen = 0           -- goes up on every change: an older search is thrown away
local dirty = false     -- the worker must look again
local line = nil        -- { points, truncated, width, along, seg, cut, cutAlong } the thin line on the map
local trimTo = nil      -- the watcher asks the worker to cut the line behind you: { line, seg, point, at }
local mode = nil        -- 'thin' | 'gta'
local gtaBlip = nil     -- the icon that has GTA's own line on it

local hiddenWorks = true -- false once we know the hidden search doesn't work in this game
local hiddenFails = 0
local warned, warnedError = false, false

-- GTA: "where is the point N metres along this route?" (newer name first, then the older ones)
local getPos = GetPosAlongGpsTypeRoute or GetGpsWaypointRouteEnd
if type(getPos) ~= 'function' then
    getPos = function(fromPlayer, distance, slot)
        local found, pos = Citizen.InvokeNative(0xF3162836C28F9DA5, Citizen.PointerValueVector(), fromPlayer, distance, slot,
            Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger())
        return found == 1 or found == true, pos
    end
end

---------------------------------------------------------------------------
-- settings (GlobalState from the server, set with /gpsline)
---------------------------------------------------------------------------
local function settings()
    local s = GlobalState['exti_gps']
    local on, width = Config.enabled, Config.width
    if type(s) == 'table' then
        if s.on ~= nil then on = s.on ~= false end
        width = tonumber(s.width) or width
    end
    width = math.max(Config.minWidth, math.min(Config.maxWidth, math.floor(width)))
    return on, width
end

---------------------------------------------------------------------------
-- small maths (flat = on the map, height ignored)
---------------------------------------------------------------------------
local function flat(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function segDist(p, a, b)
    local abx, aby = b.x - a.x, b.y - a.y
    local len2 = abx * abx + aby * aby
    local t = 0.0
    if len2 > 0.0 then
        t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
    end
    local cx, cy = a.x + abx * t - p.x, a.y + aby * t - p.y
    return math.sqrt(cx * cx + cy * cy)
end

local function distToLine(points, p)
    if #points == 1 then return flat(points[1], p) end
    local best = math.huge
    for i = 1, #points - 1 do
        local d = segDist(p, points[i], points[i + 1])
        if d < best then best = d end
    end
    return best
end

-- the closest spot to p on the bit from a to b: distance, how far along (0-1), and the spot
local function project(p, a, b)
    local abx, aby = b.x - a.x, b.y - a.y
    local len2 = abx * abx + aby * aby
    local t = 0.0
    if len2 > 0.0 then
        t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
    end
    local x, y = a.x + abx * t, a.y + aby * t
    local z = (a.z or 0.0) + ((b.z or 0.0) - (a.z or 0.0)) * t
    local dx, dy = x - p.x, y - p.y
    return math.sqrt(dx * dx + dy * dy), t, vector3(x, y, z)
end

-- keep only the points that shape the line (straight bits need two points, bends need more)
local function simplify(points, tolerance)
    local n = #points
    if n <= 2 then return points end
    local keep = { [1] = true, [n] = true }
    local stack = { { 1, n } }
    while #stack > 0 do
        local part = table.remove(stack)
        local a, b = part[1], part[2]
        local far, at = 0.0, nil
        for i = a + 1, b - 1 do
            local d = segDist(points[i], points[a], points[b])
            if d > far then far, at = d, i end
        end
        if at and far > tolerance then
            keep[at] = true
            stack[#stack + 1] = { a, at }
            stack[#stack + 1] = { at, b }
        end
    end
    local out = {}
    for i = 1, n do
        if keep[i] then out[#out + 1] = points[i] end
    end
    return out
end

-- up to 6 m off the real road (never cuts a corner you'd notice); a trip that still needs too many
-- points is drawn in parts: the next part comes when you get close to the end of this one
local function shape(points)
    local out = points
    for _, tolerance in ipairs({ 2.0, 4.0, 6.0 }) do
        out = simplify(points, tolerance)
        if #out <= Config.maxPoints then break end
    end
    local truncated = false
    if #out > Config.maxPoints then
        local cut = {}
        for i = 1, Config.maxPoints do cut[i] = out[i] end
        out, truncated = cut, true
    end
    return out, truncated
end

---------------------------------------------------------------------------
-- reading GTA's way
---------------------------------------------------------------------------
-- slot: 1 = the route to a map icon, 2 = the hidden multi-point route
local function readWay(slot, myGen)
    local points, last, same = {}, nil, 0
    local d, calls = 0.0, 0
    local capped = true -- stays true only when the way is longer than Config.maxLength
    while d <= Config.maxLength do
        local ok, p = getPos(true, d, slot)
        if not ok or not p then capped = false break end
        if last and flat(p, last) < 0.5 then
            same = same + 1
            if same >= 2 then capped = false break end -- the end of the way
        else
            same = 0
            points[#points + 1] = vector3(p.x, p.y, p.z)
            last = p
        end
        d = d + Config.sampleStep
        calls = calls + 1
        if calls % 100 == 0 then
            Wait(0)
            if gen ~= myGen then return nil end
        end
    end
    if #points < 2 then return nil end
    return points, capped
end

local function waitForWay(slot, myGen)
    local stop = GetGameTimer() + Config.findTimeout
    repeat
        Wait(50)
        if gen ~= myGen then return nil end
        if getPos(true, 0.0, slot) then
            Wait(150) -- let GTA finish the way before reading it
            if gen ~= myGen then return nil end
            return readWay(slot, myGen)
        end
    until GetGameTimer() > stop
    return nil
end

-- 1st way: our own route, drawn in a see-through colour while GTA finds the way
-- (GTA drops a multi route that isn't drawn, so it is drawn, just invisible)
local function hiddenWay(dest, myGen)
    ClearGpsCustomRoute()
    ClearGpsMultiRoute()
    ReplaceHudColourWithRgba(Config.hiddenSlot, Config.colour[1], Config.colour[2], Config.colour[3], 0)
    StartGpsMultiRoute(Config.hiddenSlot, true, true)
    AddPointToGpsMultiRoute(dest.x, dest.y, dest.z)
    SetGpsMultiRouteRender(true)
    local points, capped = waitForWay(2, myGen)
    ClearGpsMultiRoute()
    return points, capped
end

-- 2nd way: GTA's line on the icon for a moment, read it, take it off again
local function iconWay(route, myGen)
    local blip = route.blip
    if not blip or not DoesBlipExist(blip) then return nil end
    ClearGpsCustomRoute()
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, route.routeColour)
    local points, capped = waitForWay(1, myGen)
    if DoesBlipExist(blip) then SetBlipRoute(blip, false) end
    -- another script's icon route can sit in the same GTA slot: only keep a way that ends at our place
    if points and not capped and flat(points[#points], route.dest) > Config.wrongWay then return nil end
    return points, capped
end

local function findWay(route, myGen)
    local points, capped
    if hiddenWorks then
        points, capped = hiddenWay(route.dest, myGen)
        if gen ~= myGen then return nil end
        if points then hiddenFails = 0 else hiddenFails = hiddenFails + 1 end
    end
    if not points then
        points, capped = iconWay(route, myGen)
        if gen ~= myGen then return nil end
        -- the icon way works but the hidden one never did: stop trying the hidden one
        if points and hiddenWorks and hiddenFails >= 2 then hiddenWorks = false end
    end
    return points, capped
end

---------------------------------------------------------------------------
-- drawing (only the worker thread below calls these)
---------------------------------------------------------------------------
local function stopLine()
    ClearGpsCustomRoute()
    ClearGpsMultiRoute()
    if gtaBlip and DoesBlipExist(gtaBlip) then SetBlipRoute(gtaBlip, false) end
    gtaBlip, line, mode, trimTo = nil, nil, nil, nil
end

local function gtaLine(route, failed)
    if route.blip and DoesBlipExist(route.blip) then
        SetBlipRoute(route.blip, true)
        SetBlipRouteColour(route.blip, route.routeColour)
        gtaBlip = route.blip
    end
    mode = 'gta'
    route.failedAt = failed and GetEntityCoords(cache.ped) or nil
    if failed and not warned then
        warned = true
        print('[exti_gps] the thin line could not be drawn for this route, GTA\'s own line is used')
    end
end

local function drawLine(route, raw, width, capped)
    local gap = flat(raw[#raw], route.dest)
    if not capped and gap > 3.0 and gap <= Config.lastBit then
        raw[#raw + 1] = route.dest -- the last bit from the road to the place
    end
    local points, truncated = shape(raw)
    truncated = truncated or capped == true

    ReplaceHudColourWithRgba(Config.hudSlot, Config.colour[1], Config.colour[2], Config.colour[3], 255)
    ClearGpsMultiRoute()
    ClearGpsCustomRoute()
    StartGpsCustomRoute(Config.hudSlot, true, true)
    for i = 1, #points do
        local p = points[i]
        AddPointToGpsCustomRoute(p.x, p.y, p.z)
    end
    SetGpsCustomRouteRender(true, width, width)

    -- how far along the line each point is (metres), to know how much of it is behind you
    local along = { 0.0 }
    for i = 2, #points do along[i] = along[i - 1] + flat(points[i - 1], points[i]) end
    line = { points = points, truncated = truncated, width = width, along = along, seg = 1, cut = nil, cutAlong = 0.0 }
    trimTo = nil
    mode = 'thin'
    route.failedAt = nil
    route.off = 0
    route.builtAt = GetGameTimer()
    -- GTA's way starts at the nearest road: you may start far from the line (a yard, a field)
    route.closest = distToLine(points, GetEntityCoords(cache.ped))
end

-- GTA draws a custom line from you to its first point. So the line is drawn again from where you are
-- on it: the part you already passed goes away (else a straight line goes back to where it started).
local function trimLine(t)
    if t.line ~= line or mode ~= 'thin' then return end
    local pts = line.points
    ClearGpsCustomRoute()
    StartGpsCustomRoute(Config.hudSlot, true, true)
    AddPointToGpsCustomRoute(t.point.x, t.point.y, t.point.z)
    for i = t.seg + 1, #pts do
        local p = pts[i]
        AddPointToGpsCustomRoute(p.x, p.y, p.z)
    end
    SetGpsCustomRouteRender(true, line.width, line.width)
    line.seg, line.cut, line.cutAlong = t.seg, t.point, t.at
end

-- the part of the line still in front of you: (first bit starts where it was last cut)
local function bitStart(i)
    if i == line.seg and line.cut then return line.cut, line.cutAlong end
    return line.points[i], line.along[i]
end

-- how far you are from the part of the line still in front of you
local function distAhead(me)
    local pts = line.points
    local best = math.huge
    for i = line.seg, #pts - 1 do
        local a = bitStart(i)
        local d = segDist(me, a, pts[i + 1])
        if d < best then best = d end
    end
    if best == math.huge then best = flat(me, pts[#pts]) end
    return best
end

-- where you are on the line: distance to it, which bit, the spot, and how far along the line that is
local function progress(me)
    local pts = line.points
    local best, bestSeg, bestPoint, bestAt = math.huge, nil, nil, nil
    local _, fromAt = bitStart(line.seg)
    for i = line.seg, #pts - 1 do
        local a, aAt = bitStart(i)
        if aAt - fromAt > Config.trimWindow then break end
        local d, t, p = project(me, a, pts[i + 1])
        if d < best then
            best, bestSeg, bestPoint = d, i, p
            bestAt = aAt + t * flat(a, pts[i + 1])
        end
    end
    return best, bestSeg, bestPoint, bestAt
end

local function apply(myGen)
    stopLine()
    local route = routes[#routes]
    active = route
    if not route then return end

    local on, width = settings()
    if not on then return gtaLine(route, false) end

    local points, capped = findWay(route, myGen)
    if gen ~= myGen then return end -- something changed while searching: the worker starts again
    if not points then return gtaLine(route, true) end
    drawLine(route, points, width, capped)
end

local function markDirty()
    gen = gen + 1
    dirty = true
end

-- the worker: the only place that touches GTA's route natives
CreateThread(function()
    while true do
        if dirty then
            dirty = false
            local ok, err = pcall(apply, gen)
            if not ok then
                if not warnedError then
                    warnedError = true
                    print(('[exti_gps] %s (GTA\'s own line is used)'):format(err))
                end
                pcall(stopLine)
                local route = routes[#routes]
                if route then pcall(gtaLine, route, false) end
            end
        elseif trimTo then
            local t = trimTo
            trimTo = nil
            local ok, err = pcall(trimLine, t)
            if not ok and not warnedError then
                warnedError = true
                print(('[exti_gps] %s'):format(err))
            end
        end
        Wait(100)
    end
end)

AddStateBagChangeHandler('exti_gps', 'global', function()
    markDirty()
end)

---------------------------------------------------------------------------
-- the list of routes
---------------------------------------------------------------------------
local function findRoute(key)
    for i = 1, #routes do
        if routes[i].key == key then return i, routes[i] end
    end
end

local function removeRoute(route)
    for i = #routes, 1, -1 do
        if routes[i] == route then
            table.remove(routes, i)
            break
        end
    end
    if route.own and route.blip and DoesBlipExist(route.blip) then RemoveBlip(route.blip) end
    if route == active then markDirty() end
end

-- the newest route is drawn, but a job's next stop never takes the line away from a
-- "take me there" you asked for: it waits underneath and comes back when you arrive
local function addRoute(route)
    local i, old = findRoute(route.key)
    if i then
        table.remove(routes, i)
        if old.own and old.blip and old.blip ~= route.blip and DoesBlipExist(old.blip) then RemoveBlip(old.blip) end
    end
    local at = #routes + 1
    if not route.own then
        for j = 1, #routes do
            if routes[j].own then at = j break end
        end
    end
    table.insert(routes, at, route)
    if routes[#routes] == route or routes[#routes] ~= active or old == active then markDirty() end
end

-- every second: arrived? your own marker? off the line? icon gone?
CreateThread(function()
    while true do
        Wait(1000)
        local ped = cache.ped
        local me = GetEntityCoords(ped)
        local now = GetGameTimer()

        for i = #routes, 1, -1 do
            local route = routes[i]
            if route then
                if route.blip and not DoesBlipExist(route.blip) then
                    removeRoute(route) -- the icon was removed without telling us
                elseif route.arrive and flat(me, route.dest) < route.arrive then
                    removeRoute(route) -- arrived
                elseif route.own and now > route.markerFrom and IsWaypointActive() then
                    removeRoute(route) -- you put your own marker on the map: that's where you want to go now
                end
            end
        end

        local route = active
        if route and route == routes[#routes] and not dirty then
            if mode == 'thin' and line then
                local settled = now - (route.builtAt or 0) > Config.recomputeCooldown
                local flying = IsPedInFlyingVehicle(ped) or IsPedInAnyBoat(ped)
                local limit = IsPedInAnyVehicle(ped, false) and Config.offRoute or Config.offRouteOnFoot
                local far = distAhead(me) -- only the part still in front of you counts
                if settled and not flying and flat(me, route.dest) > Config.nearEnd then
                    route.closest = math.min(route.closest or far, far)
                    -- off the line = you were on it (or closer to it) and went away from it
                    if far > limit and far > route.closest + limit then
                        route.off = (route.off or 0) + 1
                        if route.off >= 2 then markDirty() end -- a wrong turn: find the new way
                    else
                        route.off = 0
                        local last = line.points[#line.points]
                        if line.truncated and flat(me, last) < 250.0 then markDirty() end -- draw the next part
                    end
                elseif not settled then
                    route.closest = math.min(route.closest or far, far)
                end
                -- on the line and moved on along it: cut away the part behind you
                if not dirty and (route.off or 0) == 0 then
                    local d, seg, point, at = progress(me)
                    if seg and d <= limit and at >= line.cutAlong + Config.trimStep then
                        trimTo = { line = line, seg = seg, point = point, at = at }
                    end
                end
            elseif mode == 'gta' and route.failedAt and flat(me, route.failedAt) > 250.0 then
                markDirty() -- try the thin line again from here
            end
        end
    end
end)

---------------------------------------------------------------------------
-- exports
---------------------------------------------------------------------------
local function toVec(c)
    local t = type(c)
    if t == 'vector3' or t == 'vector4' then return vector3(c.x, c.y, c.z) end
    if t == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y then return vector3(x, y, z or 0.0) end
    end
    return nil
end

local function groundZ(x, y)
    local ok, z = pcall(GetHeightmapBottomZForPosition, x, y)
    if ok and type(z) == 'number' and z > -100.0 and z < 2000.0 then return z + 1.0 end
    return 30.0
end

-- a route to a script's own map icon (job pick-ups and drop-offs). Cleared with ClearRoute(key).
exports('Route', function(key, coords, opts)
    local dest = toVec(coords)
    if type(key) ~= 'string' or not dest then return false end
    opts = type(opts) == 'table' and opts or {}
    addRoute({
        key = key,
        dest = dest,
        blip = opts.blip,
        routeColour = tonumber(opts.routeColour) or Config.gtaColour,
        resource = GetInvokingResource(),
    })
    return true
end)

exports('ClearRoute', function(key)
    local _, route = findRoute(key)
    if route then removeRoute(route) end
end)

-- "take me there": a yellow pin named after the place + the thin line. Ends when you arrive,
-- or when you put your own marker on the map. GoTo(x, y, z, label) or GoTo(coords, label).
exports('GoTo', function(x, y, z, label)
    local tx = type(x)
    if tx == 'vector2' then
        label = y
        x, y, z = x.x, x.y, nil
    elseif tx == 'vector3' or tx == 'vector4' or tx == 'table' then
        local c = toVec(x)
        if not c then return false end
        label = y
        x, y, z = c.x, c.y, (tx ~= 'table' or x.z or x[3]) and c.z or nil
    end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    z = tonumber(z) or groundZ(x, y)

    if not settings() then
        SetNewWaypoint(x, y) -- the thin line is off: GTA's own map marker, like before
        return true
    end

    -- one "take me there" at a time, and it replaces your own marker (like GTA's marker did)
    for i = #routes, 1, -1 do
        if routes[i].own then removeRoute(routes[i]) end
    end
    if IsWaypointActive() then SetWaypointOff() end

    local name = (type(label) == 'string' and label ~= '') and label or Config.pin.name
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, Config.pin.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, Config.pin.colour)
    SetBlipScale(blip, Config.pin.scale)
    SetBlipAsShortRange(blip, false)
    SetBlipPriority(blip, 12)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)

    addRoute({
        key = 'exti_gps:goto',
        dest = vector3(x, y, z),
        blip = blip,
        own = true,
        arrive = Config.arrive,
        markerFrom = GetGameTimer() + 1500,
        routeColour = Config.pin.colour,
    })
    return true
end)

---------------------------------------------------------------------------
-- clean up
---------------------------------------------------------------------------
AddEventHandler('onClientResourceStop', function(resource)
    if resource == cache.resource then
        ClearGpsCustomRoute()
        ClearGpsMultiRoute()
        -- a job icon that had GTA's line keeps it (exti_jobs puts GTA's line back on its icons by itself)
        local keep
        for i = 1, #routes do
            local route = routes[i]
            if route.own then
                keep = route
                if route.blip and DoesBlipExist(route.blip) then RemoveBlip(route.blip) end
            end
        end
        -- your "take me there" becomes GTA's map marker, so you still know where you were going
        if keep then SetNewWaypoint(keep.dest.x, keep.dest.y) end
        return
    end
    -- a resource that asked for a route stopped: its route goes too
    for i = #routes, 1, -1 do
        if routes[i].resource == resource then removeRoute(routes[i]) end
    end
end)
