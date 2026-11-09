-- =====================================================================
-- EX_Tii (Moe): the port terminal fence. Built on each player's game from the marks (GlobalState.extiPort):
-- the corners in order make a closed fence; the gate and the doors are gaps in it. Only near the port.
-- Nobody climbs or jumps over it: next to the fence the jump/climb key does nothing.
-- =====================================================================
local marks = {}
local corners, openings = {}, {}
local pieces = {}            -- (old name, kept for /portdebug) the fence objects that exist right now
local slots = {}             -- EX_Tii: every fence piece of the whole port (where it goes); only the ones near you exist
local built = false
local center, reach = nil, 0
local segs = {}              -- { a, b, len, dir } for the climb check
local model, dims = nil, nil
local gen = 0                -- each build has a number: an older one still running stops by itself
local doors = {}             -- the door gates: { obj, c, dir, h, d (dims), open, until }

local function pickModel()
    if model then return model end
    -- the fence an admin picked in game (/portpick, then /port fence <number>) wins over the list
    local chosen = tonumber(GlobalState.extiPortModel)
    if chosen and IsModelInCdimage(chosen) and IsModelValid(chosen) then
        model = chosen
        print(('[exti_port] fence model (picked in game): %d'):format(chosen))
        return model
    end
    for _, name in ipairs(Config.fenceModels) do
        local h = joaat(name)
        if IsModelInCdimage(h) and IsModelValid(h) then
            model = h
            print(('[exti_port] fence model: %s'):format(name))
            return model
        end
    end
    print('^1[exti_port] none of the fence models exist in this game^0')
end

-- the door: a small fence gate from the game, as close as possible to half a panel wide
-- (an admin can choose another one: /portpick on a gate, then /port doormodel <number>)
local doorModel, doorDims
local function pickDoor(want)
    if doorModel ~= nil then return doorModel end
    local list = {}
    local chosen = tonumber(GlobalState.extiPortDoorModel)
    if chosen then list[#list + 1] = chosen end
    for _, name in ipairs(Config.doorModels) do list[#list + 1] = joaat(name) end
    local best, bestDims, bestScore
    for i, h in ipairs(list) do
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            local mn, mx = GetModelDimensions(h)
            local len = mx.x - mn.x
            -- (some gates are the map's own doors: they measure fine but a script can't make them. Try it.)
            local test = 0
            -- (flat gates only: thin like the fence. A gate with its own frame/cage swings as a whole box)
            local depth = mx.y - mn.y
            if len > 0.6 and len < 3.0 and depth < 0.45 and HasModelLoaded(h) then
                local me = GetEntityCoords(cache.ped)
                test = CreateObjectNoOffset(h, me.x, me.y, me.z - 60.0, false, false, false)
                if test ~= 0 then DeleteEntity(test) else print(('[exti_port] door model %d can not be made by a script, skipped'):format(h)) end
            end
            if test ~= 0 then
                local score = (chosen and i == 1) and -1 or math.abs(len - want)   -- (the admin's pick always wins)
                if not bestScore or score < bestScore then
                    best, bestScore = h, score
                    bestDims = { mn = mn, mx = mx, len = len, cx = (mn.x + mx.x) / 2, cy = (mn.y + mx.y) / 2 }
                end
            end
        end
    end
    doorModel, doorDims = best or false, bestDims
    print(best and ('[exti_port] door model: %d (%.2f m wide)'):format(best, bestDims.len) or '^3[exti_port] no door model: doors are fence panels^0')
    return doorModel
end

local function clear()
    gen = gen + 1
    for _, sl in ipairs(slots) do if sl.obj and DoesEntityExist(sl.obj) then DeleteEntity(sl.obj) end end
    for _, d in ipairs(doors) do for _, o in ipairs(d.objs) do if DoesEntityExist(o) then DeleteEntity(o) end end end
    if model then SetModelAsNoLongerNeeded(model) end
    if doorModel then SetModelAsNoLongerNeeded(doorModel) end
    slots, pieces, doors, built = {}, {}, {}, false
end


local function parse()
    corners, openings, segs = {}, {}, {}
    for _, m in ipairs(marks) do
        local p = vec3(m.x, m.y, m.z)
        if m.kind == 'corner' then corners[#corners + 1] = p
        elseif m.kind == 'gate' then openings[#openings + 1] = { pos = p, half = Config.gateWidth / 2 }
        elseif m.kind == 'door' then openings[#openings + 1] = { pos = p, half = Config.doorWidth / 2, door = true } end
    end
    if #corners < 2 then center = nil return end
    local sx, sy, sz = 0.0, 0.0, 0.0
    for _, c in ipairs(corners) do sx, sy, sz = sx + c.x, sy + c.y, sz + c.z end
    center = vec3(sx / #corners, sy / #corners, sz / #corners)
    reach = 0
    for _, c in ipairs(corners) do reach = math.max(reach, #(c.xy - center.xy)) end
    local n = #corners
    -- closed (the last corner back to the first) once there are 3+ corners and the admin typed /port done;
    -- while marking it stays open, so no line jumps across the terminal
    local last = (n >= 3 and not GlobalState.extiPortEditing) and n or n - 1
    for i = 1, last do
        local a, b = corners[i], corners[i % n + 1]
        local d = b - a
        local len = #(d.xy)
        if len > 0.5 then segs[#segs + 1] = { a = a, b = b, len = len, dir = vec2(d.x / len, d.y / len) } end
    end
end

-- the gap (gate or door) at this point, if any
local function openingAt(p, extra)
    for _, o in ipairs(openings) do
        if #(p.xy - o.pos.xy) < o.half + (extra or 0.0) then return o end
    end
end
local function nearOpening(p, extra) return openingAt(p, extra) ~= nil end

-- the nearest point on the fence line (and its segment) to p
local function onLine(p)
    local best, bd, bs
    for _, sg in ipairs(segs) do
        local rel = p.xy - sg.a.xy
        local t = math.max(0.0, math.min(sg.len, rel.x * sg.dir.x + rel.y * sg.dir.y))
        local q = sg.a + vec3(sg.dir.x, sg.dir.y, 0.0) * t
        local d = #(p.xy - q.xy)
        if not bd or d < bd then best, bd, bs = q, d, sg end
    end
    return best, bs
end

-- a door's pose: closed = along the fence (it IS a fence panel, every row of it); open = swung 90 degrees
-- on its hinge (one end)
local function placeDoor(d)
    local dd = d.d
    local h = d.h + (d.angle or 0.0)   -- (0 = closed, 90 = wide open; it moves between them, see below)
    local hx, hy = math.cos(math.rad(d.h)), math.sin(math.rad(d.h))
    local hinge = d.c - vec3(hx, hy, 0.0) * (dd.len / 2)
    local ax, ay = math.cos(math.rad(h)), math.sin(math.rad(h))
    local bx, by = -ay, ax
    local cx, cy = hinge.x + ax * dd.len / 2, hinge.y + ay * dd.len / 2
    local tall = dd.mx.z - dd.mn.z
    for r, obj in ipairs(d.objs) do
        SetEntityCoordsNoOffset(obj, cx - ax * dd.cx - bx * dd.cy, cy - ay * dd.cx - by * dd.cy, d.c.z - dd.mn.z + (r - 1) * tall * 0.97, false, false, false)
        SetEntityHeading(obj, h)
    end
end

-- EX_Tii (Moe): GTA holds only 1600 breakable objects at once (more = the game crashes: "fragInstGta Pool
-- Full"). The whole port fence is far more than that, so build() only works out where every piece goes;
-- the pieces themselves are made when you come within Config.streamDistance and removed when you leave.
local function build()
    clear()
    if not center or not pickModel() then return end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end
    if not dims then
        local mn, mx = GetModelDimensions(model)
        dims = { mn = mn, mx = mx, len = math.max(0.5, mx.x - mn.x), cx = (mn.x + mx.x) / 2, cy = (mn.y + mx.y) / 2 }
    end
    built = true
    local mine = gen
    local rows = math.max(1, math.min(4, math.floor(tonumber(GlobalState.extiPortHeight) or 1)))
    local tall = dims.mx.z - dims.mn.z
    for _, o in ipairs(openings) do if o.door then o.half, o.used = dims.len / 2 + 0.05, nil end end
    local hasDoor = false
    for _, o in ipairs(openings) do if o.door then hasDoor = true end end
    if hasDoor and pickDoor(dims.len / 2) then
        RequestModel(doorModel)
        local td = GetGameTimer() + 3000
        while not HasModelLoaded(doorModel) and GetGameTimer() < td do Wait(10) end
        if not HasModelLoaded(doorModel) then doorModel = nil end
    end
    if gen ~= mine then return end
    local function slot(m, x, y, ground, off, h)
        slots[#slots + 1] = { m = m, x = x, y = y, ground = ground, off = off, h = h }
    end
    local count0 = 0
    for _, s in ipairs(segs) do
        local count = math.max(1, math.ceil(s.len / dims.len))
        local step = s.len / count
        local h = math.deg(math.atan(s.dir.y, s.dir.x))
        local ax, ay = s.dir.x, s.dir.y           -- the piece's own X (along the fence)
        local bx, by = -s.dir.y, s.dir.x          -- its Y
        for k = 1, count do
            local f = (k - 0.5) * step / s.len
            local c = s.a + (s.b - s.a) * f
            local z = c.z
            -- this panel is a door?
            local door
            for _, o in ipairs(openings) do
                if o.door and not o.used then
                    local rx, ry = o.pos.x - s.a.x, o.pos.y - s.a.y
                    local along = rx * s.dir.x + ry * s.dir.y
                    local off = math.abs(rx * s.dir.y - ry * s.dir.x)
                    if off < 3.0 and math.abs(along - (k - 0.5) * step) <= step / 2 + 0.01 then door = o break end
                end
            end
            local gate = false
            for _, o in ipairs(openings) do
                if not o.door and #(c.xy - o.pos.xy) < o.half + step / 2 then gate = true break end
            end
            if door then
                door.used = true
                -- the panel's place: [ door | the rest of it fence ]; the rows above stay whole
                local sx, sy = c.x - ax * dims.len / 2, c.y - ay * dims.len / 2   -- the start of the gap (the hinge)
                local dd = doorModel and doorDims or dims
                local dm = doorModel or model
                local dc = vec3(sx + ax * dd.len / 2, sy + ay * dd.len / 2, z)
                door.pos, door.half = dc, dd.len / 2 + 0.1   -- (only the door itself lets you through)
                doors[#doors + 1] = { objs = {}, c = dc, h = h, d = dd, m = dm, angle = 0.0 }
                if dims.len - dd.len > 0.1 then
                    local fx, fy = sx + ax * (dd.len + dims.len / 2), sy + ay * (dd.len + dims.len / 2)
                    slot(model, fx - ax * dims.cx - bx * dims.cy, fy - ay * dims.cx - by * dims.cy, z, -dims.mn.z, h)
                end
                for r = 1, rows - 1 do
                    slot(model, c.x - ax * dims.cx - bx * dims.cy, c.y - ay * dims.cx - by * dims.cy, z, -dims.mn.z + r * tall * 0.97, h)
                end
            elseif not gate then
                for r = 0, rows - 1 do
                    slot(model, c.x - ax * dims.cx - bx * dims.cy, c.y - ay * dims.cx - by * dims.cy, z, -dims.mn.z + r * tall * 0.97, h)
                end
            end
            count0 = count0 + 1
            if count0 % 200 == 0 then Wait(0); if gen ~= mine then return end end
        end
    end
end

-- the pieces near you exist, the others don't (a few made per frame: no hitch, never the 1600 limit)
CreateThread(function()
    while true do
        local sleep = 500
        if built and #slots + #doors > 0 then
            local me = GetEntityCoords(cache.ped)
            local R = Config.streamDistance
            local inR, outR = R * R, (R + 25.0) * (R + 25.0)
            local made, live = 0, {}
            for _, sl in ipairs(slots) do
                local dx, dy = sl.x - me.x, sl.y - me.y
                local d2 = dx * dx + dy * dy
                if d2 < inR then
                    if not sl.obj and made < 40 and HasModelLoaded(sl.m) then
                        local gz = sl.ground
                        local ok, z = GetGroundZFor_3dCoord(sl.x, sl.y, sl.ground + 1.5, false)
                        if ok and math.abs(z - sl.ground) < 2.0 then gz = z end
                        local obj = CreateObjectNoOffset(sl.m, sl.x, sl.y, gz + sl.off, false, false, false)
                        if obj ~= 0 then
                            SetEntityHeading(obj, sl.h); FreezeEntityPosition(obj, true); SetEntityInvincible(obj, true)
                            sl.obj = obj
                        end
                        made = made + 1
                    end
                elseif sl.obj and d2 > outR then
                    if DoesEntityExist(sl.obj) then DeleteEntity(sl.obj) end
                    sl.obj = nil
                end
                if sl.obj then live[#live + 1] = sl.obj end
            end
            pieces = live
            for _, d in ipairs(doors) do
                local d2 = (d.c.x - me.x) ^ 2 + (d.c.y - me.y) ^ 2
                if d2 < inR and #d.objs == 0 and HasModelLoaded(d.m) then
                    local obj = CreateObjectNoOffset(d.m, d.c.x, d.c.y, d.c.z, false, false, false)
                    if obj ~= 0 then
                        FreezeEntityPosition(obj, true); SetEntityInvincible(obj, true)
                        d.objs = { obj }
                        placeDoor(d)
                    end
                elseif d2 > outR and #d.objs > 0 then
                    for _, o in ipairs(d.objs) do if DoesEntityExist(o) then DeleteEntity(o) end end
                    d.objs, d.angle = {}, 0.0
                end
            end
            if made >= 40 then sleep = 0 end
        end
        Wait(sleep)
    end
end)

local function refresh(value)
    marks = type(value) == 'table' and value or {}
    parse()
    if built then build() end   -- (already near it: rebuilt at once with the new marks)
end
AddStateBagChangeHandler('extiPort', 'global', function(_, _, value) refresh(value) end)
AddStateBagChangeHandler('extiPortHeight', 'global', function()
    SetTimeout(0, function() if built then build() end end)
end)
AddStateBagChangeHandler('extiPortDoorModel', 'global', function()
    SetTimeout(0, function() doorModel, doorDims = nil, nil; if built then build() end end)
end)
AddStateBagChangeHandler('extiPortModel', 'global', function()
    SetTimeout(0, function() model, dims, doorModel, doorDims = nil, nil, nil, nil; if built then build() end end)
end)
AddStateBagChangeHandler('extiPortEditing', 'global', function() SetTimeout(0, function() refresh(GlobalState.extiPort) end) end)
CreateThread(function() Wait(500); refresh(GlobalState.extiPort) end)

-- built when you come near, removed when you leave
CreateThread(function()
    while true do
        local sleep = 2000
        if center then
            local d = #(GetEntityCoords(cache.ped).xy - center.xy)
            local near = d < reach + Config.buildDistance
            if near and not built then build()
            elseif not near and built then clear() end
        elseif built then clear() end
        Wait(sleep)
    end
end)

-- next to the fence (not at a gap): no jumping or climbing over it
local blockClimb = false
CreateThread(function()
    while true do
        local sleep = 1000
        blockClimb = false
        if built then
            local p = GetEntityCoords(cache.ped)
            if #(p.xy - center.xy) < reach + 30.0 then
                sleep = 200
                for _, s in ipairs(segs) do
                    local rel = p.xy - s.a.xy
                    local t = math.max(0.0, math.min(s.len, rel.x * s.dir.x + rel.y * s.dir.y))
                    local q = s.a.xy + s.dir * t
                    if #(p.xy - q) < Config.noClimb and not nearOpening(vec3(q.x, q.y, p.z), 0.0) then blockClimb = true break end
                end
            end
        end
        Wait(sleep)
    end
end)
CreateThread(function()
    while true do
        if blockClimb then
            DisableControlAction(0, 22, true)   -- jump / climb
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- EX_Tii (Moe): nobody gets over it, whatever the trick (a car roof, a container, an explosion, a ragdoll):
-- crossing the fence line anywhere but the gate or a door puts you (and your car) back where you were.
-- Admins in noclip (no collision, frozen) and teleports (a big jump in one step) are left alone.
local function crossesAt(p1, p2, a, b)
    local rx, ry = p2.x - p1.x, p2.y - p1.y
    local sx, sy = b.x - a.x, b.y - a.y
    local den = rx * sy - ry * sx
    if math.abs(den) < 1e-6 then return nil end
    local qx, qy = a.x - p1.x, a.y - p1.y
    local t = (qx * sy - qy * sx) / den
    local u = (qx * ry - qy * rx) / den
    if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0 then return vec3(p1.x + t * rx, p1.y + t * ry, p1.z) end
end
CreateThread(function()
    local prev, lastWarn = nil, 0
    while true do
        local sleep = 1000
        if built and center and not GlobalState.extiPortEditing then
            local ped = cache.ped
            local ent = cache.vehicle and GetVehiclePedIsIn(ped, false) or ped
            local pos = GetEntityCoords(ent)
            if #(pos.xy - center.xy) < reach + 60.0 then
                sleep = 100
                local exempt = IsEntityPositionFrozen(ent) or GetEntityCollisionDisabled(ent) or IsEntityDead(ped)
                if exempt or not prev or #(pos - prev) > 30.0 then
                    prev = pos
                else
                    local bad = false
                    for _, sg in ipairs(segs) do
                        local hit = crossesAt(prev, pos, sg.a, sg.b)
                        -- (high above it - a helicopter, a plane - is not crossing it)
                        if hit and pos.z < math.max(sg.a.z, sg.b.z) + 8.0 and not nearOpening(hit, 0.3) then bad = true break end
                    end
                    if bad then
                        SetEntityCoordsNoOffset(ent, prev.x, prev.y, prev.z, false, false, false)
                        SetEntityVelocity(ent, 0.0, 0.0, 0.0)
                        if GetGameTimer() - lastWarn > 3000 then
                            lastWarn = GetGameTimer()
                            lib.notify({ description = 'الميناء مسوّر: الدخول من البوابة أو من أبواب البحر فقط', type = 'error' })
                        end
                    else
                        prev = pos
                    end
                end
            else
                prev = nil
            end
        else
            prev = nil
        end
        Wait(sleep)
    end
end)

-- while an admin is marking: numbered markers on every mark (green corners, yellow gate, blue doors)
CreateThread(function()
    while true do
        if GlobalState.extiPortEditing and #marks > 0 then
            local p = GetEntityCoords(cache.ped)
            local n = 0
            for _, m in ipairs(marks) do
                if m.kind == 'corner' then n = n + 1 end
                if #(p - vec3(m.x, m.y, m.z)) < 250.0 then
                    local r, g, b = 32, 201, 151
                    if m.kind == 'gate' then r, g, b = 245, 197, 66 elseif m.kind == 'door' then r, g, b = 80, 160, 255 end
                    DrawMarker(1, m.x, m.y, m.z, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 4.0, r, g, b, 150, false, false, 2, false, nil, nil, false)
                    if m.kind == 'corner' then
                        local on, sx, sy = World3dToScreen2d(m.x, m.y, m.z + 4.5)
                        if on then
                            SetTextScale(0.45, 0.45); SetTextFont(4); SetTextCentre(true); SetTextColour(255, 255, 255, 230); SetTextOutline()
                            BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(tostring(n)); EndTextCommandDisplayText(sx, sy)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- EX_Tii (Moe): the doors work like GTA's open house doors. A person walking into one pushes it: it opens
-- just as far as his body needs (stop halfway = it rests half open against you), from whichever side he comes,
-- and it swings back shut by itself once nobody is in its way (never through someone standing there).
local BODY = 0.5             -- a person's reach on the door (metres): a bit more than his body, so leaning on it pushes it
local function pushDoors(dt)
    -- everyone on foot near a door (me and the players around)
    local feet = {}
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= 0 and not IsPedInAnyVehicle(ped, false) then feet[#feet + 1] = GetEntityCoords(ped) end
    end
    local busy = false
    for _, d in ipairs(doors) do
        local len = d.d.len
        local fx, fy = math.cos(math.rad(d.h)), math.sin(math.rad(d.h))       -- along the closed door, from the hinge
        local nx, ny = -fy, fx                                                -- its side (+90 degrees)
        local hx, hy = d.c.x - fx * len / 2, d.c.y - fy * len / 2             -- the hinge
        local a = d.angle or 0.0
        local sgn = d.sgn or 1
        local need = 0.0
        for _, p in ipairs(feet) do
            if math.abs(p.z - d.c.z) < 3.0 then
                local rx, ry = p.x - hx, p.y - hy
                local r = math.sqrt(rx * rx + ry * ry)
                if r > 0.15 and r < len + BODY then
                    local th = math.deg(math.atan(rx * nx + ry * ny, rx * fx + ry * fy))   -- where he is around the hinge
                    local half = math.deg(math.asin(math.min(1.0, BODY / math.max(r, BODY))))
                    if math.abs(a) < 0.5 and math.abs(th) < half then
                        sgn = th < 0 and 1 or -1   -- closed and touched: it will swing away from him
                    end
                    local t = th * sgn                                        -- his place, measured the way it opens
                    local open = math.abs(a)
                    if t > -half and t < open + half then need = math.max(need, t + half) end
                end
            end
        end
        need = math.min(need, Config.doorMaxAngle)
        local open = math.abs(a)
        if need > open + 0.05 then
            if open < 1.0 then PlaySoundFromCoord(-1, 'Grab_Gate', d.c.x, d.c.y, d.c.z, 'DLC_Biker_Mailbox_Sounds', false, 10, false) end
            open = math.min(need, open + Config.doorPushSpeed * dt)            -- pushed: it moves with you
        elseif open > need + 0.05 then
            open = math.max(need, open - Config.doorReturnSpeed * dt)          -- nobody there: it swings back
        end
        if open < 0.05 then open, sgn = 0.0, 1 end
        local newA = open * sgn
        if math.abs(newA - a) > 0.01 then
            d.angle, d.sgn = newA, sgn
            placeDoor(d)
            busy = true
        else
            d.sgn = sgn
        end
        if open > 0.0 then busy = true end
    end
    return busy
end

CreateThread(function()
    local last = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local dt = math.min(0.1, (now - last) / 1000.0)
        last = now
        local wait = 400
        if built and #doors > 0 then
            local me = GetEntityCoords(cache.ped)
            local near = false
            for _, d in ipairs(doors) do if #(me.xy - d.c.xy) < 30.0 then near = true break end end
            if near then
                local moving = pushDoors(dt)
                -- every frame right next to a door or while one moves; a bit slower otherwise
                local close = false
                for _, d in ipairs(doors) do if #(me.xy - d.c.xy) < 4.0 then close = true break end end
                wait = (moving or close) and 0 or 100
            end
        end
        Wait(wait)
    end
end)

-- /portdebug (F8): what the doors are made of and where they are
RegisterCommand('portdebug', function()
    print(('[exti_port] fence model %s  door model %s  doors %d  pieces %d'):format(tostring(model), tostring(doorModel), #doors, #pieces))
    if doorDims then print(('[exti_port] door size %.2f x %.2f x %.2f'):format(doorDims.len, doorDims.mx.y - doorDims.mn.y, doorDims.mx.z - doorDims.mn.z)) end
    local me = GetEntityCoords(cache.ped)
    for i, d in ipairs(doors) do
        print(('[exti_port] door %d plan: model %s loaded %s  place %.1f %.1f %.1f  (%.0f m from you)  objects %d  angle %.0f'):format(
            i, tostring(d.m), tostring(d.m and HasModelLoaded(d.m)), d.c.x, d.c.y, d.c.z, #(d.c - me), #d.objs, d.angle or 0))
        local o = d.objs[1]
        local ex = o and DoesEntityExist(o)
        local at = ex and GetEntityCoords(o) or vec3(0, 0, 0)
        print(('[exti_port] door %d: exists %s  model %s  at %.1f %.1f %.1f  (%.0f m from you)  visible %s  alpha %s  open %s'):format(
            i, tostring(ex), ex and tostring(GetEntityModel(o)) or '-', at.x, at.y, at.z, #(at - me), ex and tostring(IsEntityVisible(o)) or '-',
            ex and tostring(GetEntityAlpha(o)) or '-', tostring(d.open)))
    end
end, false)

-- /portpick: look at a fence in the world and type it: its model number is shown (and written in F8).
-- Then /port fence <number> makes the port fence out of that one.
local function isOurs(ent)
    for _, o in ipairs(pieces) do if o == ent then return true end end
    return false
end
RegisterCommand('portpick', function()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = cam + dir * 20.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, -1, cache.ped, 0)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    local found
    if hit == 1 and ent and ent ~= 0 and DoesEntityExist(ent) and not isOurs(ent) then
        local m = GetEntityModel(ent)
        if m and m ~= 0 and GetEntityType(ent) ~= 1 and GetEntityType(ent) ~= 2 then found = m end
    end
    if not found then
        -- not hit by the look: the nearest object around you instead
        local here, best, bd = GetEntityCoords(cache.ped), nil, 6.0
        for _, obj in ipairs(GetGamePool('CObject')) do
            if not isOurs(obj) then
                local d = #(GetEntityCoords(obj) - here)
                if d < bd then best, bd = obj, d end
            end
        end
        if best then found = GetEntityModel(best) end
    end
    if not found then
        return lib.notify({ description = 'لم أجد شيئًا: انظر إلى السياج من قريب (أقل من 20 مترًا) وجرّب مرة أخرى', type = 'error' })
    end
    local mn, mx = GetModelDimensions(found)
    print(('[exti_port] picked model %d  (length %.1f m, height %.1f m)  ->  /port fence %d'):format(found, mx.x - mn.x, mx.z - mn.z, found))
    lib.notify({ description = ('رقم هذا السياج: %d (طوله %.1f م، ارتفاعه %.1f م). اكتب: /port fence %d'):format(found, mx.x - mn.x, mx.z - mn.z, found), type = 'success', duration = 15000 })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() end
end)
