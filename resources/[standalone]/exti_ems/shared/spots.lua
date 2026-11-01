-- =====================================================================
-- Spots moved in game with /emsspots (saved in data/spots.json) win over config.lua.
-- The server sends them to everyone in GlobalState.exti_ems_spots.
-- =====================================================================

EMS = EMS or {}

-- the spots an admin can move. point = an E spot; spawn = where a vehicle appears (with heading)
EMS.SPOT_KINDS = {
    duty = 'point', cloakroom = 'point', storage = 'point', locker = 'point',
    garage = 'point', garageSpawn = 'spawn', heli = 'point', heliSpawn = 'spawn',
}
-- these can also be removed from a hospital
EMS.SPOT_OPTIONAL = { cloakroom = true, storage = true, locker = true }

local DEFAULTS = {}
for name, h in pairs(Config.hospitals) do
    DEFAULTS[name] = {
        duty = h.duty, cloakroom = h.cloakroom, storage = h.storage, locker = h.locker,
        garage = h.garage and { coords = h.garage.coords, spawn = h.garage.spawn },
        heli = h.heli and { coords = h.heli.coords, spawn = h.heli.spawn },
    }
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
function EMS.applySpots(saved)
    saved = type(saved) == 'table' and saved or {}
    for name, h in pairs(Config.hospitals) do
        local d = DEFAULTS[name]
        h.duty, h.cloakroom, h.storage, h.locker = d.duty, d.cloakroom, d.storage, d.locker
        h.garage = d.garage and { coords = d.garage.coords, spawn = d.garage.spawn } or nil
        h.heli = d.heli and { coords = d.heli.coords, spawn = d.heli.spawn } or nil
        local s = type(saved[name]) == 'table' and saved[name] or nil
        if s then
            for _, kind in ipairs({ 'duty', 'cloakroom', 'storage', 'locker' }) do
                if s[kind] == false and EMS.SPOT_OPTIONAL[kind] then
                    h[kind] = nil
                else
                    h[kind] = point(s[kind]) or h[kind]
                end
            end
            for _, kind in ipairs({ 'garage', 'heli' }) do
                local c, sp = point(s[kind]), spawn(s[kind .. 'Spawn'])
                if c or sp then
                    h[kind] = h[kind] or {}
                    h[kind].coords = c or h[kind].coords or (sp and sp.xyz)
                    h[kind].spawn = sp or h[kind].spawn or vec4(h[kind].coords.x, h[kind].coords.y, h[kind].coords.z, 0.0)
                end
            end
        end
    end
end
