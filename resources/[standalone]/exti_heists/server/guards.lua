-- =====================================================================
-- EX_Tii heists: guards (the cartel ranch now; the big banks and the yacht in M4). Server-run sites:
--   * a job starts a site; when a robber comes within 220 m, his game makes the guards (on the ground,
--     armed) and tells us their network ids; we tag them so every game knows whose they are
--   * calm: they stand or walk their rounds. Every game drives the guards it owns (ownership moves to
--     whoever is closest), so the brain is never lost when one player leaves
--   * they see (a cone, line of sight, faster if you're armed, masked, running) and hear (shots, running
--     close by). One of them raises the alarm: the whole site knows, and the reinforcements come in waves
--   * the job ends: the server deletes them all
-- =====================================================================
local C = Config
local GD = C.guards

local sites = {}   -- [id] = { id, def, active, spawning, owner, units = {netIds}, alert, blind, at }

local function publish()
    local out = {}
    for id, s in pairs(sites) do if s.active then out[id] = { alert = s.alert, blind = s.blind, c = { x = s.def.center.x, y = s.def.center.y, z = s.def.center.z } } end end
    GlobalState['exti_heists:guards'] = out
end

local function entOf(n)
    local e = NetworkGetEntityFromNetworkId(math.tointeger(n) or 0)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end

-- the guards' list for the client: positions, weapons, patrol points (no functions)
local function lite(def)
    local g = {}
    for i, x in ipairs(def.guards) do
        g[i] = { x = x.pos.x, y = x.pos.y, z = x.pos.z, w = x.pos.w, weapon = x.weapon, patrol = x.patrol }
    end
    return { guards = g, models = def.models or { def.model }, center = def.center }
end

function H.guardSite(id, def)
    local s = sites[id]
    if s and s.active then return s end
    sites[id] = { id = id, def = def, active = true, units = {}, alert = false, blind = false, at = H.now(), waves = {} }
    publish()
    return sites[id]
end

function H.guardEnd(id)
    local s = sites[id]; if not s then return end
    s.active = false
    local units = s.units
    sites[id] = nil
    publish()
    SetTimeout(2000, function() for _, n in ipairs(units) do local e = entOf(n); if e then DeleteEntity(e) end end end)
end

function H.guardBlind(id) local s = sites[id]; if s then s.blind = true; publish() end end
function H.guardAlerted(id) local s = sites[id]; return s and s.alert or false end
function H.guardAlive(id)
    local s = sites[id]; if not s then return 0 end
    local n = 0
    for _, u in ipairs(s.units) do local e = entOf(u); if e and GetEntityHealth(e) > 0 then n = n + 1 end end
    return n
end

local function nearestRobber(pos, dist)
    local best, bd
    for _, p in ipairs(GetPlayers()) do
        local src = tonumber(p)
        if src and not H.isCopOnDuty(src) and GetPlayerRoutingBucket(src) == 0 then
            local c = H.coords(src)
            if c then local d = #(c - pos); if d < dist and (not bd or d < bd) then best, bd = src, d end end
        end
    end
    return best
end

-- the alarm: the whole site, then the waves
local function raise(id, by, why)
    local s = sites[id]; if not s or s.alert then return end
    s.alert = true; publish()
    H.log(by, 'guards_alert', ('%s · %s'):format(id, why or ''))
    if s.onAlert then pcall(s.onAlert, by, why) end
    for k, w in ipairs(s.def.waves or {}) do
        SetTimeout(w.delay * 1000, function()
            if sites[id] ~= s or not s.active then return end
            local who = nearestRobber(s.def.center, 300.0)
            if who then s.waveAsked = s.waveAsked or {}; s.waveAsked[who] = true end
            if who then TriggerClientEvent('exti_heists:client:guardWave', who, id, k, { x = w.from.x, y = w.from.y, z = w.from.z, w = w.from.w }, w.count, w.weapon, s.def.models or { s.def.model }) end
        end)
    end
end
H.guardRaise = raise

RegisterNetEvent('exti_heists:server:guardAlert', function(id, why)
    local src = source
    local s = sites[id]
    if not s or not s.active or s.alert then return end
    -- (only a game that owns one of the guards can say they saw something, and it must be close to him)
    local here = H.coords(src)
    local ok = false
    for _, n in ipairs(s.units) do
        local e = entOf(n)
        if e and NetworkGetEntityOwner(e) == src and here and #(GetEntityCoords(e) - here) < 150.0 then ok = true break end
    end
    if not ok then return end
    raise(id, src, tostring(why or ''):sub(1, 20))
end)

-- a game made guards: their ids (checked on the server, then tagged for everyone)
RegisterNetEvent('exti_heists:server:guardSpawned', function(id, netIds)
    local src = source
    local s = sites[id]
    if not s or not s.active or type(netIds) ~= 'table' then return end
    local wave = s.waveAsked and s.waveAsked[src]
    if s.spawning ~= src and not wave then
        -- (a late or stray report: what that game made goes away)
        for _, it in ipairs(netIds) do
            local e = type(it) == 'table' and entOf(it.n)
            if e and GetEntityType(e) == 1 and not IsPedAPlayer(e) and NetworkGetEntityOwner(e) == src and not Entity(e).state.exti_guard then DeleteEntity(e) end
        end
        return
    end
    if wave then s.waveAsked[src] = nil end
    local before = #s.units
    for _, it in ipairs(netIds) do
        local n = type(it) == 'table' and it.n
        if math.type(n) == 'integer' and #s.units < 24 then
            local e = entOf(n)
            if e and GetEntityType(e) == 1 and not IsPedAPlayer(e) and #(GetEntityCoords(e) - s.def.center) < 400.0 then
                s.units[#s.units + 1] = n
                Entity(e).state:set('exti_guard', id, true)
                -- his rounds (from the site's list, never from the game)
                local g = math.tointeger(it.i) and s.def.guards[it.i]
                if g and g.patrol then Entity(e).state:set('exti_guard_post', { patrol = g.patrol }, true) end
                pcall(SetEntityOrphanMode, e, 2)   -- (they stay when the game that made them leaves)
            end
        end
    end
    -- nothing came through: the next try (at most 3)
    if not wave and #s.units > before then s.spawning = nil end
    if not wave and #s.units == before then s.tries = (s.tries or 0) + 1; s.spawning = nil end
end)

-- spawn when a robber is near; clean up after a job that ended
CreateThread(function()
    while true do
        Wait(2000)
        for id, s in pairs(sites) do
            if s.active and #s.units == 0 and (s.tries or 0) < 3 and (not s.spawning or H.now() - (s.spawnAsked or 0) > 45) then
                local who = nearestRobber(s.def.center, 150.0)
                if who then
                    s.spawning, s.spawnAsked = who, H.now()
                    TriggerClientEvent('exti_heists:client:guardSpawn', who, id, lite(s.def))
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, s in pairs(sites) do for _, n in ipairs(s.units) do local e = entOf(n); if e then DeleteEntity(e) end end end
end)
CreateThread(function() Wait(1200); GlobalState['exti_heists:guards'] = {} end)
