-- mini FiveM server for exti_heists hostages + npc + negotiate (virtual time, coroutines)
local R = arg[1]
T = 0                -- virtual ms
local tasks = {}     -- { at, co }
local function sched(co, at) tasks[#tasks + 1] = { at = at, co = co } end
function CreateThread(fn) sched(coroutine.create(fn), T) end
function SetTimeout(ms, fn) sched(coroutine.create(fn), T + ms) end
function Wait(ms) coroutine.yield(ms or 0) end
function run(untilT)
    while true do
        table.sort(tasks, function(a, b) return a.at < b.at end)
        local t = tasks[1]
        if not t or t.at > untilT then T = untilT return end
        table.remove(tasks, 1)
        T = t.at
        local ok, ms = coroutine.resume(t.co)
        if not ok then error(ms .. '\n' .. debug.traceback(t.co)) end
        if coroutine.status(t.co) ~= 'dead' then sched(t.co, T + (ms or 0)) end
    end
end
function vec3(x, y, z) return setmetatable({ x = x, y = y, z = z }, VM) end
VM = { __sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end, __add = function(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end }
function vec4(x, y, z, w) local v = vec3(x, y, z); v.w = w; return v end
function vector3(x, y, z) return vec3(x, y, z) end
json = { encode = function(t) return 'J' .. tostring(t.jail) end, decode = function(s) return { jail = tonumber(s:sub(2)) } end }
-- world
players = {}   -- [src] = { pos, bucket, hp, cid, name, state = {}, items = {} , cop }
npcs = {}      -- [net] = { pos, hp, state = {} }
events = {}    -- client events log
function TriggerClientEvent(name, to, ...) events[#events + 1] = { name = name, to = to, args = { ... } } end
local function bag(t) return setmetatable({}, { __index = function(_, k) if k == 'set' then return function(self, kk, v) t[kk] = v end end return t[k] end, __newindex = t }) end
function Player(src) return { state = bag(players[src].state) } end
function Entity(e) return { state = bag(npcs[e] and npcs[e].state or {}) } end
function GetPlayers() local o = {} for s in pairs(players) do o[#o + 1] = tostring(s) end return o end
function GetPlayerName(s) return players[s] and players[s].name or nil end
function GetPlayerRoutingBucket(s) return players[s] and players[s].bucket or 0 end
function GetEntityRoutingBucket() return 0 end
function GetPlayerPed(s) return players[s] and (1000 + s) or 0 end
local function pedOwner(e) return players[e - 1000] end
function GetEntityHealth(e) if npcs[e] then return npcs[e].hp end local p = pedOwner(e); return p and p.hp or 0 end
function GetEntityCoords(e) if npcs[e] then return npcs[e].pos end local p = pedOwner(e); return p and p.pos end
function NetworkGetEntityFromNetworkId(n) return npcs[n] and n or 0 end
function DoesEntityExist(e) return npcs[e] ~= nil or pedOwner(e) ~= nil end
function GetEntityType(e) if npcs[e] then return npcs[e].veh and 2 or 1 end return 1 end
function IsPedAPlayer(e) return npcs[e] == nil end
function GetVehiclePedIsIn() return 0 end
function GetPedInVehicleSeat() return 0 end
function GetPedSourceOfDamage() return 0 end
function GetPedSourceOfDeath() return 0 end
function GetSelectedPedWeapon() return 1 end
function GetPedDrawableVariation(ped) local p = pedOwner(ped); return p and p.mask or 0 end
function NetworkGetEntityOwner() return 1 end
function SetEntityOrphanMode() end
function DeleteEntity(e) npcs[e] = nil end
function IsPlayerAceAllowed(s) return players[s] and players[s].admin end
function GetResourceState(r) return 'started' end
function GetCurrentResourceName() return 'exti_heists' end
local kvp = {}
function SetResourceKvp(k, v) kvp[k] = v end
function GetResourceKvpString(k) return kvp[k] end
function DeleteResourceKvp(k) kvp[k] = nil end
handlers = {}
function RegisterNetEvent(n, fn) if fn then handlers[n] = handlers[n] or {}; table.insert(handlers[n], fn) end end
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {}; table.insert(handlers[n], fn) end
function fire(n, src, ...) for _, fn in ipairs(handlers[n] or {}) do source = src; fn(...) end end
GlobalState = {}
MySQL = { insert = function(q, p) warrants[#warrants + 1] = p end, single = function(q, p, cb) cb(nil) end, query = function() end, ready = function() end }
warrants = {}
cbs = {}
clientCb = {}
lib = { callback = { register = function(n, fn) cbs[n] = fn end, await = function(n, src, ...) return clientCb[n](src, ...) end }, logger = function() end }
function call(n, src, ...) return cbs[n](src, ...) end
inv = {}
exports = setmetatable({}, { __index = function(_, r)
    return setmetatable({}, { __index = function(_, f)
        if r == 'ox_inventory' then
            if f == 'Search' then return function(_, src, _, item) return (players[src].items[item] or 0) end end
            if f == 'RemoveItem' then return function(_, src, item, n) players[src].items[item] = (players[src].items[item] or 0) - n; return true end end
            if f == 'AddItem' then return function(_, src, item, n) players[src].items[item] = (players[src].items[item] or 0) + n; return true end end
        end
        if r == 'exti_police' then
            if f == 'Jail' then return function(_, src, m) jailed[#jailed + 1] = { src, m } return true end end
            if f == 'IsCuffed' then return function() return false end end
            return function() end
        end
        if r == 'npwd' then if f == 'emitMessage' then return function(_, m) texts[#texts + 1] = m end end; if f == 'onMessage' then return function(_, num, fn) npwdHandler = fn end end end
        return function() end
    end })
end, __call = function() end })
jailed, texts = {}, {}
function cfx(p) local f = assert(io.open(p)); local s = f:read('a'); f:close(); s = s:gsub('`[^`]*`', '0'); assert(load(s, '@' .. p))() end
-- the heist module
Config = {}
cfx(R .. '/config.lua')
H = {}
function H.now() return math.floor(T / 1000) end
function H.coords(s) return players[s] and players[s].pos end
function H.near(s, p, d) local c = H.coords(s); return c and #(c - p) <= d end
function H.notify(s, t) end
function H.log(a, act, d) logs[#logs + 1] = act .. ' ' .. tostring(d) end
logs = {}
function H.cid(s) return players[s] and players[s].cid end
function H.name(s) return players[s] and players[s].name end
local recs = {}
function H.rec(s) local c = H.cid(s); if not c then return nil end recs[c] = recs[c] or { loot = { black_money = 500 } }; return recs[c] end
function H.isCopOnDuty(s) return players[s] and players[s].cop end
function H.setHeat() end
function H.modeFor() return { police = false } end
function H.phoneOf(s) return 'P' .. s end
function H.addXP() end
function H.player() return nil end
os.clock = function() return T / 1000 end
cfx(R .. '/server/npc.lua')
cfx(R .. '/server/hostages.lua')
cfx(R .. '/server/negotiate.lua')
-- helpers
function has(name, to) for _, e in ipairs(events) do if e.name == name and (to == nil or e.to == to) then return e end end end
function lastText(to) for i = #texts, 1, -1 do if texts[i].targetNumber == to then return texts[i].message end end end
function say(src, msg) npwdHandler({ source = src, data = { message = msg } }) end
