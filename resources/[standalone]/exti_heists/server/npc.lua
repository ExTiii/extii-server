-- =====================================================================
-- EX_Tii heists: NPC security (no-police mode). When an alarm goes off and there are not enough real
-- cops, armed "حراسة الحي" units come after a timer, hold the entrance from behind their cars and
-- fight the robbers (lowered aim, no helicopters). Break their line of sight for 60 s and they lose you.
-- Downed by them: you wake at the hospital as usual and the loot from this robbery is gone.
-- The server decides who, when, how many and where; the robber's game drives the units.
-- A real cop within 100 m: the units stand down and leave it to him.
-- =====================================================================
local C = Config
local N = C.npc

local active = {}     -- [id] = { id, targets = { [src] = true }, pos, kind, startsAt, phase, units = {netIds}, owner }
local nextId = 0
local byPlayer = {}   -- [src] = id

local function targetsList(r) local t = {} for s in pairs(r.targets) do t[#t + 1] = s end return t end

-- the robber whose game drives the units is out of it: another robber's game takes them over
local function handOver(r, leaving)
    if r.owner ~= leaving or not next(r.targets) then return end
    local nxt = next(r.targets)
    r.owner = nxt
    TriggerClientEvent('exti_heists:client:npcTakeOver', nxt, r.id, r.units or {}, targetsList(r), { x = r.pos.x, y = r.pos.y, z = r.pos.z })
end
local function tellTargets(r)
    if r.phase == 'on scene' and r.owner then TriggerClientEvent('exti_heists:client:npcTargets', r.owner, r.id, targetsList(r)) end
end

local function endResponse(id, why)
    local r = active[id]; if not r then return end
    active[id] = nil
    for s in pairs(r.targets) do
        if byPlayer[s] == id then byPlayer[s] = nil end
        TriggerClientEvent('exti_heists:client:npcEnd', s, id, why)
    end
    H.log(r.owner, 'npc_end', ('%s · %s'):format(r.kind, why))
end
H.npcEnd = endResponse

-- start a response at pos for these players (already in no-police mode)
function H.npcRespond(players, pos, kind)
    local spec = N.kinds[kind] or N.kinds.store
    -- one response per robber: a second alarm only adds people to it
    for _, s in ipairs(players) do
        local id = byPlayer[s]
        if id and active[id] then
            for _, o in ipairs(players) do active[id].targets[o] = true; byPlayer[o] = id end
            tellTargets(active[id])
            return id
        end
    end
    nextId = nextId + 1
    local id = nextId
    local r = { id = id, targets = {}, pos = vec3(pos.x, pos.y, pos.z), kind = kind, phase = 'coming', owner = players[1],
        startsAt = H.now() + spec.delay, cars = math.random(spec.cars[1], spec.cars[2]) }
    for _, s in ipairs(players) do r.targets[s] = true; byPlayer[s] = id end
    active[id] = r
    for _, s in ipairs(players) do TriggerClientEvent('exti_heists:client:npcIncoming', s, id, spec.delay) end
    H.log(players[1], 'npc_start', ('%s · %d cars in %ds'):format(kind, r.cars, spec.delay))
    SetTimeout(spec.delay * 1000, function()
        if active[id] ~= r then return end
        -- still somebody around? (they all ran before the units came: nothing comes)
        local owner
        for s in pairs(r.targets) do
            local here = H.coords(s)
            if here and #(here - r.pos) < N.giveUpDistance then owner = s break end
        end
        if not owner then return endResponse(id, 'gone before') end
        r.owner, r.phase = owner, 'on scene'
        r.spawnedAt = H.now()
        TriggerClientEvent('exti_heists:client:npcSpawn', owner, id, { x = r.pos.x, y = r.pos.y, z = r.pos.z }, r.cars, targetsList(r), spec.weapons)
        for s in pairs(r.targets) do if s ~= owner then TriggerClientEvent('exti_heists:client:npcHunted', s, id) end end
    end)
    return id
end

-- the owner's game says the units are out (their network ids, so others see them and the server can check)
RegisterNetEvent('exti_heists:server:npcSpawned', function(id, netIds)
    local src = source
    local r = active[id]
    if not r or r.owner ~= src or type(netIds) ~= 'table' then return end
    r.units = {}
    for _, n in ipairs(netIds) do if math.type(n) == 'integer' then r.units[#r.units + 1] = n end end
    SetTimeout(8000, function()
        if active[id] ~= r then return end
        local alive = 0
        for _, n in ipairs(r.units) do if DoesEntityExist(NetworkGetEntityFromNetworkId(n)) then alive = alive + 1 end end
        if alive == 0 then H.log(src, 'flag_npc_missing', ('%s: units never appeared'):format(r.kind)) end
    end)
end)

-- the owner's game: lost them (out of sight for 60 s) / downed / left the area
RegisterNetEvent('exti_heists:server:npcLost', function(id)
    local src = source
    local r = active[id]
    if not r or not r.targets[src] then return end
    r.targets[src] = nil; byPlayer[src] = nil
    H.notify(src, 'أضعتهم: توقفت حراسة الحي عن البحث', 'success', 6000)
    H.log(src, 'npc_lost', r.kind)
    TriggerClientEvent('exti_heists:client:npcEnd', src, id, r.owner == src and next(r.targets) and 'handover' or 'lost')
    if not next(r.targets) then return endResponse(id, 'everyone lost them') end
    handOver(r, src); tellTargets(r)
end)

-- downed while they were on you: the loot of this robbery is gone (the hospital does the rest as usual)
local function downed(src)
    local id = byPlayer[src]; local r = id and active[id]
    if not r or r.phase ~= 'on scene' then return end
    local rec = H.rec(src)
    local gone = {}
    if rec then
        for item, n in pairs(rec.loot or {}) do
            local have = exports.ox_inventory:Search(src, 'count', item) or 0
            local take = math.min(have, n)
            if take > 0 then exports.ox_inventory:RemoveItem(src, item, take); gone[#gone + 1] = ('%dx %s'):format(take, item) end
        end
        rec.loot = {}
    end
    H.notify(src, 'أسقطتك حراسة الحي: ضاعت الغنيمة', 'error', 9000)
    H.log(src, 'npc_downed', table.concat(gone, ', '))
    r.targets[src] = nil; byPlayer[src] = nil
    TriggerClientEvent('exti_heists:client:npcEnd', src, id, r.owner == src and next(r.targets) and 'handover' or 'downed')
    if not next(r.targets) then return endResponse(id, 'all downed') end
    handOver(r, src); tellTargets(r)
end
RegisterNetEvent('exti_heists:server:npcDowned', function(id)
    local src = source
    -- trust the medical state (qbx_medical: 1 = alive), not just the message
    local ds = Player(src).state['qbx_medical:deathState']
    if (ds ~= nil and ds ~= 1) or GetEntityHealth(GetPlayerPed(src)) <= 101 then downed(src) end
end)

-- a real cop arrives: the NPCs stand down / everyone left / the time ran out
CreateThread(function()
    while true do
        Wait(3000)
        local t = H.now()
        for id, r in pairs(active) do
            if r.phase == 'on scene' then
                local cop
                for _, s in ipairs(GetPlayers()) do
                    local src = tonumber(s)
                    if src and H.isCopOnDuty(src) then
                        local cp = H.coords(src)
                        for tgt in pairs(r.targets) do
                            local tp = H.coords(tgt)
                            if cp and tp and #(cp - tp) < N.copStandDown then cop = src break end
                        end
                    end
                    if cop then break end
                end
                if cop then
                    for tgt in pairs(r.targets) do TriggerClientEvent('exti_heists:client:npcEnd', tgt, id, 'police') end
                    active[id] = nil
                    for tgt in pairs(r.targets) do if byPlayer[tgt] == id then byPlayer[tgt] = nil end end
                    H.log(cop, 'npc_stand_down', r.kind)
                elseif t - (r.spawnedAt or t) > N.maxMinutes * 60 then
                    endResponse(id, 'time')
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = byPlayer[src]; local r = id and active[id]
    if not r then return end
    r.targets[src] = nil; byPlayer[src] = nil
    if not next(r.targets) then return endResponse(id, 'left') end
    handOver(r, src); tellTargets(r)
end)

exports('NpcActive', function(src) return byPlayer[src] ~= nil end)
