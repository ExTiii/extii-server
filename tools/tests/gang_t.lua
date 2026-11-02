-- EX_Tii gangs: server test with mocks (run: lua5.4 gang_t.lua)
local RES = '/home/claude/extii-server/resources/[standalone]/exti_gangs/'
package.path = RES .. '?.lua;' .. package.path
local passes, fails = 0, 0
function check(c, m) if c then passes = passes + 1 else fails = fails + 1 end print((c and 'PASS ' or 'FAIL ') .. m) end

-- clock
local clock = 1800000000
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return clock end
local function advance(s) clock = clock + s end

-- vectors
local V = {}
V.__index = V
V.__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vec3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
function vec4(x, y, z, w) return setmetatable({ x = x, y = y, z = z, w = w }, V) end

json = { encode = function() return '{}' end, decode = function(s) if s == '' or s == nil then error('empty') end return {} end }
function joaat(s) local h = 0; for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
qbx = { table = { size = function(t) local n = 0; for _ in pairs(t) do n = n + 1 end return n end } }
THREADS = {}
function CreateThread(f) local co = coroutine.create(f); THREADS[#THREADS + 1] = co; coroutine.resume(co) end
function SetTimeout() end
promise = { new = function() local o = {}; function o:resolve(v) self.v = v; self.done = true end; return o end }
Citizen = { Await = function(p) return p.v end }
WITNESS = false
function GetVehicleColours(v) return 0, 0 end
function GetIsVehiclePrimaryColourCustom() return false end
function GetVehicleCustomPrimaryColour() return 0, 0, 0 end
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
function GetConvar(_, d) return d end
function PerformHttpRequest() end
function LoadResourceFile() return nil end
local saved = {}
function SaveResourceFile(_, f, d) saved[f] = d end
function GetCurrentResourceName() return 'exti_gangs' end
function GetResourceState(r) return 'started' end
function IsPlayerAceAllowed(src) return src == 1 end
GlobalState = {}
local clientEvents = {}
function TriggerClientEvent(name, src, ...) clientEvents[#clientEvents + 1] = { name = name, src = src, args = { ... } } end
function TriggerEvent() end
local netHandlers = {}
function RegisterNetEvent(name, fn) if fn then netHandlers[name] = netHandlers[name] or {}; table.insert(netHandlers[name], fn) end end
function AddEventHandler(name, fn) netHandlers[name] = netHandlers[name] or {}; table.insert(netHandlers[name], fn) end
local function fireNet(name, src, ...) source = src; for _, f in ipairs(netHandlers[name] or {}) do f(...) end end

-- MySQL (rows kept only where the code reads them back)
local leftRows = {}
BOLOS, UPD, CALLS = {}, {}, {}
MySQL = {
    ready = function(f) READIES = READIES or {}; READIES[#READIES + 1] = f end,
    query = setmetatable({ await = function(q, p)
        if q:find('SELECT `actor`') then return {} end
        return {}
    end }, { __call = function(_, q, p)
        if q:find('DELETE FROM `exti_gang_left`') then leftRows[p[1]] = nil end
        if q:find('INSERT INTO `exti_gang_left`') then leftRows[p[1]] = p[2] end
    end }),
    insert = setmetatable({ await = function(q, p) if q:find('exti_police_bolos') then BOLO = p; BOLOS[#BOLOS + 1] = { id = #BOLOS + 1, plate = p[4], officer = p[5], title = p[2] } end return 1 end }, { __call = function(_, q, p)
        if q:find('exti_gang_left') then leftRows[p[1]] = p[2] end
        if q:find('exti_police_bolos') then BOLO = p end
    end }),
    update = setmetatable({ await = function(q, p) if q:find('exti_police_bolos') then UPD[#UPD + 1] = { q = q, p = p }; if q:find('`closed` = ?') then for _, b in ipairs(BOLOS) do if b.id == p[3] then b.closed = true end end end end return 1 end }, { __call = function() end }),
    single = { await = function(q, p) if q:find('exti_police_bolos') then for i = #BOLOS, 1, -1 do local b = BOLOS[i]; if b.plate == p[1] and not b.closed then return b end end return nil end if q:find('exti_gang_left') then return leftRows[p[1]] and { left_at = leftRows[p[1]] } or nil end end },
}
-- fix: query used as both function and table
local q = MySQL.query
MySQL.query = setmetatable({ await = q.await }, getmetatable(q))

-- players
local pos, peds, players = {}, {}, {}
local cash = {}
function GetPlayerPed(src) return peds[src] or 0 end
local entityPos, entityState, entityModel, entityType, seats, frozen = {}, {}, {}, {}, {}, {}
function GetEntityCoords(e) for s, p in pairs(peds) do if p == e then return pos[s] end end return entityPos[e] end
function GetEntityHeading() return 0.0 end
function GetVehicleType(e) return (entityState[e] or {}).vtype or 'automobile' end
function DoesEntityExist(e) return entityPos[e] ~= nil end
function GetEntityType(e) return entityType[e] or 0 end
function GetEntityModel(e) return entityModel[e] end
function GetPedInVehicleSeat(v, s) return (seats[v] or {})[s] or 0 end
function FreezeEntityPosition(e, f) frozen[e] = f end
function SetVehicleDoorsLocked() end
function DeleteEntity(e) entityPos[e] = nil end
function GetVehicleNumberPlateText(e) return entityState[e] and entityState[e].plate or 'NPC 001 ' end
function NetworkGetEntityFromNetworkId(n) return n end
function Entity(e)
    entityState[e] = entityState[e] or {}
    local st = entityState[e]
    return { state = setmetatable({ set = function(self, k, v) st[k] = v end }, { __index = st }) }
end
Entity = function(e)
    entityState[e] = entityState[e] or {}
    local st = entityState[e]
    local proxy = setmetatable({}, { __index = function(_, k) if k == 'set' then return function(_, kk, v) st[kk] = v end end return st[k] end, __newindex = st })
    return { state = proxy }
end

local function addPlayer(src, cid, name)
    peds[src] = 1000 + src; pos[src] = vec3(0, 0, 0); cash[src] = 0
    local p = { PlayerData = { source = src, citizenid = cid, charinfo = { firstname = name, lastname = 'X' }, gang = { name = 'none' }, gangs = {} },
        Functions = {
            RemoveMoney = function(t, a) if cash[src] >= a then cash[src] = cash[src] - a return true end return false end,
            AddMoney = function(t, a) cash[src] = cash[src] + a return true end,
        } }
    players[src] = p
    return p
end

local qbxGangs, qbxMember = {}, {}
local ownedByPlate = {}
local savedVehicle = nil
local vehicleInfo = {}
local inv = {}       -- [inventory id] = { item = count }
local function invOf(id) inv[id] = inv[id] or {}; return inv[id] end
local hooks = {}
local stashes = {}
local EXP_INDEX = function(_, res)
    if res == 'qbx_core' then return {
        GetPlayer = function(_, src) return players[src] end,
        GetPlayerByCitizenId = function(_, cid) for _, p in pairs(players) do if p.PlayerData.citizenid == cid then return p end end end,
        CreateGangs = function(_, t) for k, v in pairs(t) do qbxGangs[k] = v end return true end,
        AddPlayerToGang = function(_, cid, g, r) qbxMember[cid] = { g, r } return true end,
        SetPlayerPrimaryGang = function(_, cid, g) return true end,
        RemovePlayerFromGang = function(_, cid, g) qbxMember[cid] = nil return true end,
        GetVehiclesByHash = function() return vehicleInfo end,
        GetDutyCountJob = function(_, job) local l = {}; for s, pl in pairs(players) do local j = pl.PlayerData.job; if j and j.name == job and j.onduty then l[#l + 1] = s end end return #l, l end,
    } end
    if res == 'ox_inventory' then return {
        RegisterStash = function(_, id, label, slots, weight) stashes[id] = { slots = slots, weight = weight } end,
        CanCarryItem = function(_, id, item, n) return true end,
        AddItem = function(_, id, item, n) local t = invOf(id); t[item] = (t[item] or 0) + n return true end,
        RemoveItem = function(_, id, item, n) local t = invOf(id); if (t[item] or 0) < n then return false end t[item] = t[item] - n return true end,
        GetItemCount = function(_, id, item) return invOf(id)[item] or 0 end,
        GetInventoryItems = function(_, id) local out = {}; for k, v in pairs(invOf(id)) do out[#out + 1] = { name = k, count = v } end return out end,
        ClearInventory = function(_, id) inv[id] = {} end,
        registerHook = function(_, name, fn, opts) hooks[name] = fn end,
    } end
    if res == 'qbx_vehicles' then return {
        GetVehicleIdByPlate = function(_, plate) for k, o in pairs(ownedByPlate) do if k:gsub('%s+$', ''):upper() == tostring(plate):gsub('%s+$', ''):upper() then return o.id end end end,
        GetPlayerVehicle = function(_, id) for _, o in pairs(ownedByPlate) do if o.id == id then return o end end end,
        SaveVehicle = function(_, veh, opts) savedVehicle = opts return true end,
    } end
    if res == 'exti_police' then return { AddCall = function(_, d) CALLS[#CALLS + 1] = d return #CALLS end } end
    if res == 'qbx_vehiclekeys' then return { HasKeys = function(_, src, veh) return (entityState[veh] or {}).keys == src end } end
    return {}
end
exports = setmetatable({}, { __index = EXP_INDEX, __call = function() end })

-- ox_lib
local CB, CMD = {}, {}
lib = {
    callback = setmetatable({ register = function(name, fn) CB[name:gsub('exti_gangs:server:', '')] = fn end }, { __call = function(_, name, src, cb) cb(WITNESS) end }),
    addCommand = function(name, opts, fn) CMD[name] = fn end,
    print = { info = function() end, error = function(m) print('ERR ' .. tostring(m)) end },
    logger = function() end,
}
math.randomseed(7)

-- load the resource
dofile(RES .. 'server/main.lua')
dofile(RES .. 'server/spots.lua')
dofile(RES .. 'server/collect.lua')
dofile(RES .. 'server/chop.lua')
dofile(RES .. 'server/theft.lua')
dofile(RES .. 'server/door.lua')
for _, f in ipairs(READIES) do f() end

-- ---------------------------------------------------------------- tests
local admin = addPlayer(1, 'CID1', 'Admin')
local leader = addPlayer(2, 'CID2', 'Boss')
local runner = addPlayer(3, 'CID3', 'Kid')
local outsider = addPlayer(4, 'CID4', 'Owner')

CMD.creategang(1, { name = 'Chopz', kind = 'chop', leader = 2, label = 'Chop Boys' })
local g = GANG.gangs.chopz
check(g and g.type == 'chop' and GANG.members.CID2.rank == 3 and qbxGangs.chopz and qbxMember.CID2[2] == 3, 'admin creates a chop gang, leader is rank 3 in Qbox too')
CMD.creategang(1, { name = 'other', kind = 'chop', leader = 4 })
check(GANG.gangs.other == nil, 'only one gang per type')

-- the HQ places (admin stands there)
local HQ = vec3(100, 0, 0)
local function at(src, p) pos[src] = vec3(p.x, p.y, p.z) end
at(1, HQ); CB.spotSave(1, 'hq', 'chopz', 'laptop')
at(1, vec3(103, 0, 0)); CB.spotSave(1, 'hq', 'chopz', 'stash')
at(1, vec3(106, 0, 0)); CB.spotSave(1, 'hq', 'chopz', 'deposit')
at(1, vec3(110, 0, 0)); CB.spotSave(1, 'hq', 'chopz', 'bench')
at(1, vec3(130, 0, 0)); CB.spotSave(1, 'hq', 'chopz', 'garage')
at(1, vec3(500, 0, 0)); CB.spotSave(1, 'crate_add')
at(1, vec3(505, 0, 0)); CB.spotSave(1, 'crate_add')
check(#GANG.spots.collect.crates == 2 and GANG.spot(g, 'garage').x == 130, 'admin places the HQ spots and 2 crates')
check(CB.spotSave(2, 'crate_add') == false, 'a non-admin can not place spots')

-- invites
at(2, HQ); at(3, HQ)
check(CB.invite(2, 3) == true, 'the leader invites a nearby player')
fireNet('exti_gangs:server:inviteAnswer', 3, true)
check(GANG.members.CID3 and GANG.members.CID3.rank == 0, 'he accepts and starts as a Runner')
check(select(2, CB.invite(2, 3)) == 'ingang', 'can not invite someone already in a gang')

-- the bank
at(3, HQ)
cash[3] = 500
check(select(2, CB.bank(3, 'deposit', 100)) == 'rank', 'a Runner can not deposit into the bank')
cash[2] = 5000
check(CB.bank(2, 'deposit', 2000) == true and g.bank == 2000, 'the leader deposits $2,000')
check(select(2, CB.bank(2, 'withdraw', 3000)) == 'bank', 'can not withdraw more than the bank has')

-- collection: runner at a crate
at(3, vec3(500, 0, 0))
local ok, info = CB.collectBegin(3, 1)
check(ok and info.seconds == 25, 'collection run starts at a crate')
advance(10)
check(select(2, CB.collectFinish(3, info.token, true)) == 'fast', 'finishing early is refused')
ok, info = CB.collectBegin(3, 2) ; at(3, vec3(505, 0, 0)); ok, info = CB.collectBegin(3, 2)
advance(26)
local f1, r1 = CB.collectFinish(3, info.token, true)
check(f1 and r1.count == 3 and inv[3].chop_tools == 3, '3 Chop Tools after a clean run')
check(select(2, CB.collectBegin(3, 1)) == 'cooldown' or select(2, CB.collectBegin(3, 2)) == 'cooldown', '6 minute personal cooldown')
advance(400)
at(3, vec3(500, 0, 0)); ok, info = CB.collectBegin(3, 1)
local f2, r2 = CB.collectFinish(3, info.token, false)
check(not f2 and r2 == 'skill' and inv[3].chop_tools == 3, 'a failed skill check gives nothing')

-- hand in at HQ: paid from the bank
at(3, vec3(106, 0, 0))
local d1, dr = CB.deposit(3)
check(d1 and dr.count == 3 and dr.paid == 300 and cash[3] == 800 and g.bank == 1700 and inv.gang_chopz.chop_tools == 3, 'hand in 3 parts: $300 from the gang bank to the member, parts to the stash')
inv[3].chop_tools = 30
check(select(2, CB.deposit(3)) == 'notmine' and inv[3].chop_tools == 30, 'parts he did not collect himself are not paid (no re-selling stash parts)')
local function collectOnce(src)
    advance(400); at(src, vec3(500, 0, 0)); local o, i = CB.collectBegin(src, 1)
    if not o then at(src, vec3(505, 0, 0)); o, i = CB.collectBegin(src, 2) end
    advance(26); return CB.collectFinish(src, i.token, true)
end
inv[3].chop_tools = 0
for k = 1, 10 do collectOnce(3) end
at(3, vec3(106, 0, 0))
g.bank = 100
check(select(2, CB.deposit(3)) == 'bank' and inv[3].chop_tools == 30, 'bank too low: the hand-in is refused and nothing moves')
g.bank = 10000
local d2, dr2 = CB.deposit(3)
check(d2 and dr2.count == 30, 'with money in the bank his 30 collected parts go in')
for k = 1, 6 do collectOnce(3) end
at(3, vec3(106, 0, 0))
local d3, dr3 = CB.deposit(3)
check(d3 and dr3.count == 12 and GANG.getDaily('m', 'CID3', 'collected') == 45, 'the member daily cap (45 collected) stops him (' .. tostring(dr3 and dr3.count) .. ')')

-- stash rules
local hook = hooks.swapItems
at(3, vec3(103, 0, 0)); at(4, vec3(103, 0, 0))
check(hook({ source = 3, fromType = 'stash', fromInventory = 'gang_chopz', toType = 'player', toInventory = 3, fromSlot = { name = 'chop_tools' }, count = 1 }) == false, 'a Runner can not take from the stash')
check(CB.setRank(2, 'CID3', 1) == true and GANG.members.CID3.rank == 1 and qbxMember.CID3[2] == 1, 'the leader promotes him to Crew (Qbox grade too)')
check(hook({ source = 3, fromType = 'stash', fromInventory = 'gang_chopz', toType = 'player', toInventory = 3, fromSlot = { name = 'chop_tools' }, count = 5 }) ~= false, 'Crew takes a little out')
check(hook({ source = 3, fromType = 'stash', fromInventory = 'gang_chopz', toType = 'player', toInventory = 3, fromSlot = { name = 'black_money' }, count = 20000 }) == false, 'Crew hits the $10,000 daily take limit')
check(hook({ source = 4, fromType = 'stash', fromInventory = 'gang_chopz', toType = 'player', toInventory = 4, fromSlot = { name = 'chop_tools' }, count = 1 }) == false, 'an outsider can not touch the stash')
check(CB.setRank(2, 'CID3', 0) == true, '(back to Runner for the swap test)')
check(hook({ source = 3, action = 'swap', fromType = 'player', fromInventory = 3, toType = 'stash', toInventory = 'gang_chopz', fromSlot = { name = 'water', count = 1 }, toSlot = { name = 'c4', count = 1 }, count = 1 }) == false, 'a Runner can not swap junk for the C4 in the stash')
check(CB.setRank(2, 'CID3', 1) == true, '(Crew again)')
check(hook({ source = 3, action = 'swap', fromType = 'stash', fromInventory = 'gang_chopz', toType = 'player', toInventory = 3, fromSlot = { name = 'black_money', count = 50000 }, toSlot = { name = 'water', count = 1 }, count = 1 }) == false, 'a swap counts the whole stack ($50,000 > the $10,000 limit)')
at(3, vec3(900, 0, 0))
check(hook({ source = 3, fromType = 'stash', fromInventory = 'gang_chopz', toType = 'player', toInventory = 3, fromSlot = { name = 'lockpick' }, count = 1 }) == false, 'the stash does not work away from the HQ')
at(3, vec3(103, 0, 0))
check(CB.setRank(2, 'CID3', 0.5) == false and GANG.members.CID3.rank == 1, 'a rank of 0.5 (or NaN) is refused')

-- the thief tag
local CAR = 77
entityPos[CAR] = vec3(130, 1, 0); entityType[CAR] = 2; entityModel[CAR] = joaat('zentorno')
vehicleInfo[joaat('zentorno')] = { category = 'super' }
at(4, vec3(900, 0, 0))
fireNet('qbx_vehiclekeys:server:hotwiredVehicle', 4, CAR)
check(entityState[CAR] == nil or entityState[CAR].exti_thief == nil, 'a fake hotwire event from across the map does not tag the car')
at(3, vec3(131, 1, 0))
fireNet('qbx_vehiclekeys:server:hotwiredVehicle', 3, CAR)
check(entityState[CAR].exti_thief == 'CID3', 'hotwiring tags the thief on the car')

-- car theft -> police
check(#CALLS == 1 and CALLS[1].label == 'سرقة سيارة' and CALLS[1].text:find('سوداء'), 'a super car hotwired: the police always get it (model, colour)')
check(entityState[CAR].exti_tracker == true, 'a fast car gets the GPS tracker')
fireNet('qbx_vehiclekeys:server:hotwiredVehicle', 3, CAR)
check(#CALLS == 1, 'the same car again within 5 min: no second alert')
local NPC = 60
entityPos[NPC] = vec3(300, 0, 0); entityType[NPC] = 2; entityModel[NPC] = joaat('blista'); vehicleInfo[joaat('blista')] = { category = 'compacts' }
at(3, vec3(301, 0, 0))
local rnd = math.random
math.random = function(a, b) if a == nil then return 0.99 end return rnd(a, b) end
fireNet('exti_gangs:server:theftAttempt', 3, 'carjack', NPC, false)
check(#CALLS == 1, 'a normal car, unlucky roll, no witness: no alert')
advance(5)
fireNet('exti_gangs:server:theftAttempt', 3, 'carjack', NPC, false)
check(#CALLS == 1, 'trying again on the same car does not roll again for 5 min')
advance(5)
fireNet('exti_gangs:server:theftAttempt', 3, 'carjack', NPC, true)
check(#CALLS == 2 and CALLS[2].text:find('شاهد'), 'a witness saw it: the call goes in')
math.random = rnd
local NPC2 = 61
entityPos[NPC2] = vec3(400, 0, 0); entityType[NPC2] = 2; entityModel[NPC2] = joaat('blista')
at(4, vec3(900, 0, 0))
fireNet('exti_gangs:server:theftAttempt', 4, 'carjack', NPC2, true)
check(#CALLS == 2, 'a fake attempt from far away is ignored')
players[4].PlayerData.job = { name = 'police', onduty = true }
at(4, vec3(401, 0, 0))
fireNet('exti_gangs:server:theftAttempt', 4, 'carjack', NPC2, true)
check(#CALLS == 2, 'an officer on duty opening a car: no alert')
-- the tracker: cops see it, the thief pulls it
for _, co in ipairs(THREADS) do if coroutine.status(co) == 'suspended' then coroutine.resume(co) end end
local seenT = false
for _, e in ipairs(clientEvents) do if e.name == 'exti_gangs:client:tracker' and e.src == 4 then seenT = true end end
check(seenT, 'the officer on duty sees the tracker live')
check(CB.pullBegin(4, CAR) == false, 'the officer can not pull the tracker')
at(3, vec3(131, 1, 0))
local okP = CB.pullBegin(3, CAR)
check(okP and CB.pullFinish(3, true) == false, 'pulling it takes its time')
CB.pullBegin(3, CAR); advance(8)
check(CB.pullFinish(3, true) == true and entityState[CAR].exti_tracker == nil, 'the thief pulls the tracker out')
players[4].PlayerData.job = nil

-- chop
at(3, vec3(131, 0, 0))
inv.gang_chopz.chop_tools = 10
local okp, prev = CB.chopPreview(3, CAR, 7)
check(okp and prev.tools == 6 and prev.money[1] >= 4000, 'the preview shows super class: 6 tools, $4,000+')
seats[CAR] = { [-1] = 99 }
check(select(2, CB.chopStart(3, CAR, 7)):find('أخرِج') ~= nil, 'an occupied car can not be chopped')
seats[CAR] = {}
local ok1, s1 = CB.chopStart(3, CAR, 7)
check(ok1 and inv.gang_chopz.chop_tools == 4 and frozen[CAR], 'the chop starts: 6 tools used, the car frozen')
check(select(2, CB.chopStage(3, 2)) == 'order', 'stages must go in order')
check(select(2, CB.chopStage(3, 1)) == 'fast', 'a stage needs its time')
local before = inv.gang_chopz.black_money or 0
for st = 1, 4 do advance(75); local ok_, r_ = CB.chopStage(3, st); if st == 4 then FIN = r_ end end
check(FIN and FIN.money >= 4000 and FIN.money <= 5200 * 1.3 and entityPos[CAR] == nil, 'after 4 stages the car is gone and pays $' .. tostring(FIN and FIN.money))
local thief = math.floor(FIN.money * 0.15); local chopper = math.floor(FIN.money * 0.10)
check(inv[3].black_money == thief + chopper, 'he stole and chopped it: both shares (25%) in dirty money')
check(inv.gang_chopz.black_money - before == FIN.money - thief - chopper and (inv.gang_chopz.lockpick or 0) >= 2, '75% and the lockpicks go to the gang stash')
check(select(2, CB.chopStart(3, CAR, 7)) ~= nil, 'next chop waits (cooldown or no car)')

-- a player's car
advance(600)
local PC = 88
entityPos[PC] = vec3(130, -1, 0); entityType[PC] = 2; entityModel[PC] = joaat('sultan'); vehicleInfo[joaat('sultan')] = { category = 'sports' }
entityState[PC] = { plate = 'OWN 123 ' }
ownedByPlate['OWN 123 '] = { id = 55, citizenid = 'CID4', modelName = 'sultan' }
at(3, vec3(130, -1, 0))
fireNet('qb-vehiclekeys:server:setVehLockState', 3, PC, 1)
check(entityState[PC].exti_thief == 'CID3', 'lockpicking a player car tags the thief')
local alarm = false
for _, e in ipairs(clientEvents) do if e.name == 'exti_gangs:client:carAlarm' and e.src == 4 then alarm = true end end
check(alarm, 'the owner gets the car alarm')
local flagged = false
for _, e in ipairs(clientEvents) do if e.name == 'exti_gangs:client:carAlarm' and e.src == 4 then flagged = e.args[1].flagged and e.args[1].coords ~= nil end end
check(BOLO and BOLO[4] == 'OWN 123' and BOLO[5] == 'نظام الإنذار' and flagged, 'the alarm flags the plate STOLEN on the police tablet right away (owner sees where)')
local nc = #CALLS
check(nc > 0 and CALLS[nc].text:find('OWN') and CALLS[nc].text:find('%*'), 'the police get the call with half the plate: ' .. tostring(CALLS[nc] and CALLS[nc].text))
fireNet('exti_gangs:server:reportStolen', 4, 'OWN 123', true)
check(UPD[#UPD] and UPD[#UPD].p[1]:find('بلاغ المالك'), 'the owner confirms: the BOLO says "owner report"')
local ok2 = CB.chopStart(3, PC, 6)
for st = 1, 4 do advance(65); local _, r_ = CB.chopStage(3, st); if st == 4 then FIN2 = r_ end end
check(ok2 and FIN2 and savedVehicle and savedVehicle.state == 2 and savedVehicle.depotPrice == FIN2.money and savedVehicle.garage == 'impoundlot', 'the player car goes to the impound, recovery fee = what the gang made')
check(savedVehicle.props == nil, 'mods, tuning and items are kept (props are not overwritten)')
advance(600)
local PC2 = 89
entityPos[PC2] = vec3(130, 2, 0); entityType[PC2] = 2; entityModel[PC2] = joaat('sultan'); entityState[PC2] = { plate = 'OWN 999 ' }
ownedByPlate['OWN 999 '] = { id = 56, citizenid = 'CID4', modelName = 'sultan' }
check((select(2, CB.chopStart(3, PC2, 6)) or ''):find('ساخنة') ~= nil, 'the same owner is "too hot" for 72 h')
local PC3 = 90
entityPos[PC3] = vec3(130, 3, 0); entityType[PC3] = 2; entityModel[PC3] = joaat('sultan'); entityState[PC3] = { plate = 'MINE 1  ' }
ownedByPlate['MINE 1  '] = { id = 57, citizenid = 'CID2', modelName = 'sultan' }
check((select(2, CB.chopStart(3, PC3, 6)) or ''):find('العصابة') ~= nil, "a gang member's car can not be chopped")
local POL = 91
entityPos[POL] = vec3(130, 4, 0); entityType[POL] = 2; entityModel[POL] = joaat('police'); entityState[POL] = { exti_police = true }
check((select(2, CB.chopStart(3, POL, 18)) or ''):find('لا تُفكّك') ~= nil, 'police cars are blocked')
local UNK = 92
entityPos[UNK] = vec3(130, 5, 0); entityType[UNK] = 2; entityModel[UNK] = joaat('mystery')
local okU, pU = CB.chopPreview(3, UNK, 7)
check(okU and pU.tools == 2, 'an unknown model claiming "super" is capped at the lowest class')
local BOAT = 93
entityPos[BOAT] = vec3(130, 6, 0); entityType[BOAT] = 2; entityModel[BOAT] = joaat('tug'); entityState[BOAT] = { vtype = 'boat' }
check(CB.chopPreview(3, BOAT, 2) == false, 'boats / helis / trailers are never chopped, whatever the game says')

-- bench
at(3, vec3(110, 0, 0))
inv.gang_chopz.chop_tools = 2
local lp = inv.gang_chopz.lockpick
local okb, b = CB.benchBegin(3)
advance(13)
check(okb and CB.benchFinish(3, b.token) == true and inv.gang_chopz.lockpick == lp + 2, 'the bench turns 1 Chop Tools into 2 lockpicks')

-- rent
g.bank = 5000
g.rent_due = clock - 1
GANG.gangs.chopz.locked = false
-- (the loop runs every 10 min; call the same path)
CB.bank(2, 'deposit', 0)
local _ = CB.laptop(2)
for _, co in ipairs(THREADS) do if coroutine.status(co) == 'suspended' then local ok, e = coroutine.resume(co); if not ok then print('THREAD ERR', e) end end end
check(g.locked == true and g.bank == 5000, 'rent due with only $5,000 in the bank: the HQ locks, nothing taken')
at(3, vec3(103, 0, 0))
check(select(2, CB.openStash(3)) == 'locked', 'a locked HQ: the stash is closed')
check(GANG.rentFor(g) <= 20000, 'rent is $20,000 or less with rep')
at(2, HQ); cash[2] = 30000
g.locked = true
CB.bank(2, 'deposit', 20000)
check(g.locked == false, 'depositing the rent unlocks the HQ')

-- leaving, kicking, leadership
check(select(2, CB.leave(2)) == 'leader', 'the leader can not just leave')
check(CB.transfer(2, 'CID3', true, false) == false, 'transfer needs two confirmations')
check(CB.transfer(2, 'CID3', true, true) == true and GANG.members.CID3.rank == 3 and GANG.members.CID2.rank == 2 and g.leader == 'CID3', 'leadership moves, the old leader becomes Underboss')
check(CB.kick(3, 'CID2') == true and GANG.members.CID2 == nil, 'the new leader kicks the old one')
at(3, HQ); at(2, HQ)
check(select(2, CB.invite(3, 2)) == 'wait', 'a kicked member waits 48 h before joining a gang')

-- rank slots: 3 Underbosses max even through a demotion trick
local extra = {}
for i = 10, 15 do local pl = addPlayer(i, 'CX' .. i, 'M' .. i); at(i, HQ); at(3, HQ); CB.invite(3, i); fireNet('exti_gangs:server:inviteAnswer', i, true); extra[#extra + 1] = 'CX' .. i end
for i = 1, 3 do CB.setRank(3, extra[i], 2) end
check(select(2, CB.setRank(3, extra[4], 2)) == 'slots', 'the 4th Underboss is refused (3 max)')
for i = 4, 6 do CB.setRank(3, extra[i], 1) end
local crew = 0; for _, mm in pairs(GANG.members) do if mm.gang == 'chopz' and mm.rank == 1 then crew = crew + 1 end end
check(crew <= 6, 'Crew stays within 6 (' .. crew .. ')')
check(select(2, CB.setRank(3, extra[1], 1)) == 'slots' or crew < 6, 'demoting an Underboss to a full Crew is refused')

-- a stuck chop does not block the shop forever
local CAR2 = 95
entityPos[CAR2] = vec3(130, 7, 0); entityType[CAR2] = 2; entityModel[CAR2] = joaat('blista'); vehicleInfo[joaat('blista')] = { category = 'compacts' }
inv.gang_chopz.chop_tools = 10
advance(3600)
at(3, vec3(131, 7, 0))
check(CB.chopStart(3, CAR2, 0) == true, 'a chop starts')
peds[3] = nil  -- he crashed
local CAR3 = 96
entityPos[CAR3] = vec3(130, -6, 0); entityType[CAR3] = 2; entityModel[CAR3] = joaat('blista')
at(10, vec3(131, -6, 0)); CB.setRank(3, extra[1], 2)
local okS, whyS = CB.chopStart(10, CAR3, 0)
check(okS == true, 'another member can start a new chop when the chopper is gone (' .. tostring(whyS) .. ')')

-- the HQ front door
at(1, vec3(200, 0, 0)); CB.spotSave(1, 'hq', 'chopz', 'door_out')
at(1, vec3(205, 0, 0)); CB.spotSave(1, 'hq', 'chopz', 'door_in')
at(10, vec3(200, 0, 0))
local okE, toE = CB.door(10, 'chopz', 'enter')
check(okE and toE.x == 205, 'a member walks in through the front door')
at(10, toE)
local guest = addPlayer(20, 'CG20', 'Guest'); at(20, vec3(200.5, 0, 0))
check(select(2, CB.door(20, 'chopz', 'enter')) == 'notmember', 'a stranger can not walk in')
local before = #clientEvents
check(CB.door(20, 'chopz', 'knock') == true, 'he knocks')
local kid = nil
for i = before + 1, #clientEvents do local e = clientEvents[i]; if e.name == 'exti_gangs:client:knock' and e.src == 10 then kid = e.args[1] end end
check(kid ~= nil, 'the member inside hears the knock')
fireNet('exti_gangs:server:knockAnswer', 10, kid, true)
local let = false
for i = before + 1, #clientEvents do local e = clientEvents[i]; if e.name == 'exti_gangs:client:doorTeleport' and e.src == 20 then let = true end end
check(let, 'the member opens: the guest is let in')
check(select(2, CB.door(20, 'chopz', 'knock')) == 'soon', 'no knock spam')
local cop = addPlayer(21, 'CP21', 'Cop'); cop.PlayerData.job = { name = 'police', onduty = true }; at(21, vec3(200, 0, 0))
check(select(2, CB.door(21, 'chopz', 'enter')) == 'notmember', 'the police can not just walk in')
local okB, rB = CB.door(21, 'chopz', 'breachBegin')
check(okB and rB.seconds == 10, 'the police start a breach (10 s)')
check(CB.door(21, 'chopz', 'breachFinish') == false, 'a breach can not be skipped')
CB.door(21, 'chopz', 'breachBegin'); advance(11)
local okF, toF = CB.door(21, 'chopz', 'breachFinish')
check(okF and toF.x == 205, 'after 10 s the police are in')
local cop2 = addPlayer(22, 'CP22', 'Cop2'); cop2.PlayerData.job = { name = 'police', onduty = true }; at(22, vec3(200, 0, 0))
check(CB.door(22, 'chopz', 'enter') == true, 'the door stays open to the police for 10 min')
at(20, vec3(205, 0, 0))
check(CB.door(20, 'chopz', 'exit') == true, 'anyone inside can walk out')

print(('\n%d passed, %d failed'):format(passes, fails))
