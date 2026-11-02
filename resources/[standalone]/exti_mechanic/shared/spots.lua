-- =====================================================================
-- Spots moved in game with /mechspots (saved in data/spots.json) win over config.lua.
-- The server sends them to everyone in GlobalState.exti_mechanic_spots.
-- =====================================================================

MEC = MEC or {}

-- the spots an admin can move. point = an E spot; spawn = where a vehicle appears (with heading)
MEC.SPOT_KINDS = {
    duty = 'point', cloakroom = 'point', locker = 'point', armory = 'point', forms = 'point', inbox = 'point',
    evidence = 'point', delivery = 'point', garage = 'point', garageSpawn = 'spawn', cars = 'point', carsSpawn = 'spawn',
}
-- these can also be removed from a station
MEC.SPOT_OPTIONAL = { cloakroom = true, locker = true, armory = true, forms = true, inbox = true, evidence = true, delivery = true }
-- the simple E spots (not the garages)
MEC.POINTS = { 'duty', 'cloakroom', 'locker', 'armory', 'forms', 'inbox', 'evidence', 'delivery' }

local DEFAULTS = {}
for name, s in pairs(Config.stations) do
    local d = {}
    for _, kind in ipairs(MEC.POINTS) do d[kind] = s[kind] end
    d.garage = s.garage and { coords = s.garage.coords, spawn = s.garage.spawn }
    d.cars = s.cars and { coords = s.cars.coords, spawn = s.cars.spawn }
    DEFAULTS[name] = d
end

local function num(v) return tonumber(v) end
local function point(t)
    if type(t) ~= 'table' or not num(t.x) or not num(t.y) or not num(t.z) then return end
    return vec3(num(t.x), num(t.y), num(t.z))
end
local function spawn(t)
    if type(t) ~= 'table' or not num(t.x) or not num(t.y) or not num(t.z) then return end
    return vec4(num(t.x), num(t.y), num(t.z), num(t.w) or 0.0)
end

-- put the saved spots over the config ones (always starting again from config.lua, so a spot
-- removed from the file goes back to its config place)
function MEC.applySpots(saved)
    saved = type(saved) == 'table' and saved or {}
    for name, st in pairs(Config.stations) do
        local d = DEFAULTS[name]
        for _, kind in ipairs(MEC.POINTS) do st[kind] = d[kind] end
        st.garage = d.garage and { coords = d.garage.coords, spawn = d.garage.spawn } or nil
        st.cars = d.cars and { coords = d.cars.coords, spawn = d.cars.spawn } or nil
        local s = type(saved[name]) == 'table' and saved[name] or nil
        if s then
            for _, kind in ipairs(MEC.POINTS) do
                if s[kind] == false and MEC.SPOT_OPTIONAL[kind] then
                    st[kind] = nil
                else
                    st[kind] = point(s[kind]) or st[kind]
                end
            end
            for _, kind in ipairs({ 'garage', 'cars' }) do
                local c, sp = point(s[kind]), spawn(s[kind .. 'Spawn'])
                if c or sp then
                    st[kind] = st[kind] or {}
                    st[kind].coords = c or st[kind].coords or (sp and sp.xyz)
                    st[kind].spawn = sp or st[kind].spawn or vec4(st[kind].coords.x, st[kind].coords.y, st[kind].coords.z, 0.0)
                end
            end
        end
    end
end
