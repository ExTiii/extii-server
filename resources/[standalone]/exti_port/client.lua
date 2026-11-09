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

local function pickModel()
    if model then return model end
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
    pieces, built = {}, false
end

local function parse()
    corners, openings, segs = {}, {}, {}
    for _, m in ipairs(marks) do
        local p = vec3(m.x, m.y, m.z)
        if m.kind == 'corner' then corners[#corners + 1] = p
        elseif m.kind == 'gate' then openings[#openings + 1] = { pos = p, half = Config.gateWidth / 2 }
        elseif m.kind == 'door' then openings[#openings + 1] = { pos = p, half = Config.doorWidth / 2 } end
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

-- how far a point is from the nearest gap (gate or door)
local function nearOpening(p, extra)
    for _, o in ipairs(openings) do
        if #(p.xy - o.pos.xy) < o.half + (extra or 0.0) then return true end
    end
    return false
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
    local made = 0
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
            if not nearOpening(c, step / 2) then
                local z = c.z
                local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.5, false)
                if ok and math.abs(gz - c.z) < 2.0 then z = gz end
                local x = c.x - ax * dims.cx - bx * dims.cy
                local y = c.y - ay * dims.cx - by * dims.cy
                local obj = CreateObjectNoOffset(model, x, y, z - dims.mn.z, false, false, false)
                if gen ~= mine then if obj and obj ~= 0 then DeleteEntity(obj) end return end
                if obj and obj ~= 0 then
                    SetEntityHeading(obj, h)
                    FreezeEntityPosition(obj, true)
                    SetEntityInvincible(obj, true)
                    pieces[#pieces + 1] = obj
                end
                made = made + 1
                if made % 40 == 0 then Wait(0) end   -- (a few at a time: no hitch)
            end
        end
    end
    SetModelAsNoLongerNeeded(model)
end

local function refresh(value)
    marks = type(value) == 'table' and value or {}
    parse()
    if built then build() end   -- (already near it: rebuilt at once with the new marks)
end
AddStateBagChangeHandler('extiPort', 'global', function(_, _, value) refresh(value) end)
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

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() end
end)
