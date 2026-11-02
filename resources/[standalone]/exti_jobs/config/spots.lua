-- =====================================================================
-- EX_Tii jobs: places moved in game by an admin (/jobspots), on top of config/shared.lua.
-- Saved by the server in data/spots.json and sent to every game in GlobalState['exti_jobs:spots'].
-- The same table works in the game and on the server:
--   overrides[job] = {
--       supervisor = { x, y, z, h },      -- where the supervisor stands (and which way he looks)
--       vehicle    = { x, y, z, h },      -- where the work vehicle appears (and is brought back)
--       steps = { [stepId] = { spots = { { x, y, z }, ... }, spot = { x, y, z }, ped = { x, y, z, h } } },
--   }
-- =====================================================================
local M = {}

local function num(v) return type(v) == 'number' and v == v and v > -20000 and v < 20000 end

function M.v3(t)
    if type(t) == 'table' and num(t[1]) and num(t[2]) and num(t[3]) then return vec3(t[1], t[2], t[3]) end
end

function M.v4(t)
    if type(t) == 'table' and num(t[1]) and num(t[2]) and num(t[3]) then return vec4(t[1], t[2], t[3], num(t[4]) and t[4] or 0.0) end
end

-- where the work vehicle is brought back when no spot was set: the supervisor
function M.fill(config)
    for _, job in pairs(config.jobs) do
        if job.chain then
            local s = job.hq.supervisor.coords
            job.hq.returnPoint = job.hq.spawns and job.hq.spawns[1] and job.hq.spawns[1].xyz or vec3(s.x, s.y, s.z)
        end
    end
end

function M.step(job, id)
    for i, step in ipairs(job.chain or {}) do
        if step.id == id then return step, i end
    end
end

-- the defaults are kept the first time, so an override that is taken away goes back to them
local defaults = {}
local function keepDefaults(name, job)
    if defaults[name] then return end
    local d = { supervisor = job.hq.supervisor.coords, spawns = job.hq.spawns, steps = {} }
    for _, step in ipairs(job.chain or {}) do
        d.steps[step.id] = { spots = step.spots, spot = step.spot, ped = step.ped }
    end
    defaults[name] = d
end

-- put the moved places into the config (call again whenever they change)
function M.apply(config, overrides)
    overrides = type(overrides) == 'table' and overrides or {}
    for name, job in pairs(config.jobs) do
        if job.chain then
            keepDefaults(name, job)
            local d, o = defaults[name], overrides[name] or {}
            job.hq.supervisor.coords = M.v4(o.supervisor) or d.supervisor
            local veh = M.v4(o.vehicle)
            job.hq.spawns = veh and { veh } or d.spawns
            local steps = type(o.steps) == 'table' and o.steps or {}
            for _, step in ipairs(job.chain) do
                local ds, ov = d.steps[step.id], steps[step.id] or {}
                if step.kind == 'collect' then
                    local list = {}
                    if type(ov.spots) == 'table' then
                        for _, p in ipairs(ov.spots) do list[#list + 1] = M.v3(p) end
                    end
                    step.spots = #list > 0 and list or ds.spots
                else
                    step.spot = M.v3(ov.spot) or ds.spot
                end
                step.ped = M.v4(ov.ped) or ds.ped
            end
        end
    end
    M.fill(config)
end

return M
