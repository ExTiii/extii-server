-- =====================================================================
-- EX_Tii (Moe): the port terminal fence. Built on each player's game from the marks (GlobalState.extiPort):
-- the corners in order make a closed fence; the gate and the doors are gaps in it. Only near the port.
-- Nobody climbs or jumps over it: next to the fence the jump/climb key does nothing.
-- =====================================================================
local marks = {}
local corners, openings = {}, {}
local pieces = {}            -- the objects we made
local built = false
local center, reach = nil, 0
local segs = {}              -- { a, b, len, dir } for the climb check
local model, dims = nil, nil
local gen = 0                -- each build has a number: an older one still running stops by itself
local doors = {}             -- the door gates: { obj, c, dir, h, d (dims), open, until }
local doorModel, doorDims = nil, nil

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

local function clear()
    gen = gen + 1
    for _, obj in ipairs(pieces) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    for _, d in ipairs(doors) do if d.obj and DoesEntityExist(d.obj) then DeleteEntity(d.obj) end end
    pieces, doors, built = {}, {}, false
end

-- the door: a fence gate model (the one an admin picked with /port doormodel, else the first that exists)
local function pickDoor()
    if doorModel ~= nil then return doorModel end
    local list = {}
    local chosen = tonumber(GlobalState.extiPortDoorModel)
    if chosen then list[#list + 1] = chosen end
    for _, name in ipairs(Config.doorModels) do list[#list + 1] = joaat(name) end
    for _, h in ipairs(list) do
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            local mn, mx = GetModelDimensions(h)
            local len = mx.x - mn.x
            if len > 0.8 and len < 3.5 then
                doorModel = h
                doorDims = { mn = mn, mx = mx, len = len, cx = (mn.x + mx.x) / 2, cy = (mn.y + mx.y) / 2 }
                print(('[exti_port] door model: %d (%.1f m wide)'):format(h, len))
                return doorModel
            end
        end
    end
    doorModel = false
    print('^3[exti_port] no door model found: the doors are open gaps^0')
    return false
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

-- a door's pose: closed = along the fence; open = swung 90 degrees on its hinge (one end)
local function placeDoor(d)
    local dd = d.d
    local h = d.h + (d.open and 90.0 or 0.0)
    local hx, hy = math.cos(math.rad(d.h)), math.sin(math.rad(d.h))
    local hinge = d.c - vec3(hx, hy, 0.0) * (dd.len / 2)
    local ax, ay = math.cos(math.rad(h)), math.sin(math.rad(h))
    local bx, by = -ay, ax
    local cx, cy = hinge.x + ax * dd.len / 2, hinge.y + ay * dd.len / 2
    SetEntityCoordsNoOffset(d.obj, cx - ax * dd.cx - bx * dd.cy, cy - ay * dd.cx - by * dd.cy, d.c.z - dd.mn.z, false, false, false)
    SetEntityHeading(d.obj, h)
end

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
    local made, nextYield = 0, 40
    -- the doors: the gap is as wide as the gate that fills it; each sits on the fence line
    if pickDoor() then
        for _, o in ipairs(openings) do if o.door then o.half = math.max(Config.doorWidth / 2, doorDims.len / 2 + 0.05) end end
    end
    for _, s in ipairs(segs) do
        local count = math.max(1, math.ceil(s.len / dims.len))
        local step = s.len / count
        local h = math.deg(math.atan(s.dir.y, s.dir.x))
        local ax, ay = s.dir.x, s.dir.y           -- the piece's own X (along the fence)
        local bx, by = -s.dir.y, s.dir.x          -- its Y
        for k = 1, count do
            if not built or gen ~= mine then return end
            local f = (k - 0.5) * step / s.len
            local c = s.a + (s.b - s.a) * f
            local op = openingAt(c, step / 2)
            local rows = math.max(1, math.min(4, math.floor(tonumber(GlobalState.extiPortHeight) or 1)))
            -- a door leaves the rows above it (a doorway in the wall); the gate leaves nothing
            local fromRow = (op and op.door) and 1 or 0
            if not op or (op.door and rows > 1) then
                local z = c.z
                local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.5, false)
                if ok and math.abs(gz - c.z) < 2.0 then z = gz end
                local x = c.x - ax * dims.cx - bx * dims.cy
                local y = c.y - ay * dims.cx - by * dims.cy
                -- EX_Tii (Moe): rows stacked on top of each other (/port height 2 or 3) make it a tall wall
                local tall = dims.mx.z - dims.mn.z
                for r = fromRow, rows - 1 do
                    local obj = CreateObjectNoOffset(model, x, y, z - dims.mn.z + r * tall * 0.97, false, false, false)
                    if gen ~= mine then if obj and obj ~= 0 then DeleteEntity(obj) end return end
                    if obj and obj ~= 0 then
                        SetEntityHeading(obj, h)
                        FreezeEntityPosition(obj, true)
                        SetEntityInvincible(obj, true)
                        pieces[#pieces + 1] = obj
                    end
                end
                made = made + rows
                if made >= nextYield then nextYield = made + 40; Wait(0) end   -- (a few at a time: no hitch)
            end
        end
    end
    SetModelAsNoLongerNeeded(model)
    -- the door gates themselves
    if doorModel then
        RequestModel(doorModel)
        local t2 = GetGameTimer() + 5000
        while not HasModelLoaded(doorModel) and GetGameTimer() < t2 do Wait(10) end
        for _, o in ipairs(openings) do
            if o.door and HasModelLoaded(doorModel) and gen == mine then
                local q, sg = onLine(o.pos)
                if q and sg then
                    local z = q.z
                    local ok, gz = GetGroundZFor_3dCoord(q.x, q.y, q.z + 1.5, false)
                    if ok and math.abs(gz - q.z) < 2.0 then z = gz end
                    local obj = CreateObjectNoOffset(doorModel, q.x, q.y, z, false, false, false)
                    if obj and obj ~= 0 then
                        FreezeEntityPosition(obj, true)
                        SetEntityInvincible(obj, true)
                        local d = { obj = obj, c = vec3(q.x, q.y, z), h = math.deg(math.atan(sg.dir.y, sg.dir.x)), d = doorDims, open = false }
                        placeDoor(d)
                        doors[#doors + 1] = d
                    end
                end
            end
        end
        SetModelAsNoLongerNeeded(doorModel)
    end
end

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
    SetTimeout(0, function() model, dims = nil, nil; if built then build() end end)
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

-- the doors: walk up, [E] opens it (it swings on its hinge), it closes again by itself after a few seconds.
-- Each player opens his own (the fence is built on every game), so nobody locks anyone out.
CreateThread(function()
    local shown = false
    while true do
        local sleep = 500
        if built and #doors > 0 then
            local p = GetEntityCoords(cache.ped)
            local near
            for _, d in ipairs(doors) do
                local dist = #(p.xy - d.c.xy)
                if dist < 25.0 then sleep = 100 end
                if dist < 1.8 and not cache.vehicle then near = d end
                -- open long enough: closes (not on top of someone standing in the doorway)
                if d.open and GetGameTimer() > d.untilAt and dist > 1.4 then d.open = false; placeDoor(d) end
            end
            if near and not near.open then
                sleep = 0
                if not shown then lib.showTextUI('[E] افتح الباب'); shown = true end
                if IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName()) then
                    near.open, near.untilAt = true, GetGameTimer() + Config.doorOpenSeconds * 1000
                    placeDoor(near)
                    PlaySoundFromCoord(-1, 'DOOR_OPEN', near.c.x, near.c.y, near.c.z, 'MP_PROPERTIES_ELEVATOR_DOORS', false, 0, false)
                    lib.hideTextUI(); shown = false
                end
            elseif shown then
                lib.hideTextUI(); shown = false
            end
        elseif shown then
            lib.hideTextUI(); shown = false
        end
        Wait(sleep)
    end
end)

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
