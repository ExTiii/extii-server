-- =====================================================================
-- EX_Tii heists: NPC police "حراسة الحي" (no-police mode). When an alarm goes off and there are not
-- enough real cops, armed units come after a timer, hold the entrance from behind their cars and fight
-- the robbers. Out of their sight for 60 s and they lose you. Downed by them: the loot of this robbery is
-- gone (the hospital does the rest as usual). A real cop within 100 m: they stand down.
-- Hostages (hostages.lua) change everything:
--   * one hostage is enough: they hold their fire and wait (a standoff), they follow you if you drive
--     off with him, and the negotiator texts you. No deal in 15 min: they storm in.
--   * the deals (negotiate.lua): drop him at a spot they text you / let him go right here / more time
--     (once) / give up. A clean drop: a head start, then a hard chase (cars, roadblocks) for 15 min;
--     out of their sight 2 min and you're gone.
--   * hurt a hostage (or let the time run out): the SWAT team comes in hard.
--   * no mask: they saw your face. A warrant in the police tablet.
-- The server decides who, when, how many and where; the robber's game drives the units.
-- =====================================================================
local C = Config
local N = C.npc
local HG = C.hostages

local active = {}     -- [id] = { id, targets = { [src] = true }, pos, kind, phase, units = {netIds}, owner, ... }
local nextId = 0
local byPlayer = {}   -- [src] = id

local function targetsList(r) local t = {} for s in pairs(r.targets) do t[#t + 1] = s end return t end
local function each(r, fn) for s in pairs(r.targets) do fn(s) end end

-- what every hunted robber's game must know (how long to hide, the bar)
local function tellMode(r)
    local lost = r.chase and HG.chaseLostSeconds or N.lostSeconds
    each(r, function(s) TriggerClientEvent('exti_heists:client:npcMode', s, r.id, { lost = lost, chase = r.chase ~= nil }) end)
end

-- the robber whose game drives the units is out of it: another robber's game takes them over
local function handOver(r, leaving)
    if r.owner ~= leaving or not next(r.targets) then return end
    local nxt
    for s in pairs(r.targets) do if s ~= leaving and GetPlayerRoutingBucket(s) == 0 then nxt = s break end end
    nxt = nxt or next(r.targets)
    r.owner = nxt
    TriggerClientEvent('exti_heists:client:npcTakeOver', nxt, r.id, r.units or {}, targetsList(r), { x = r.pos.x, y = r.pos.y, z = r.pos.z })
    -- (whatever the units were doing goes with them: a hold, the chase, the rage)
    if r.rage then TriggerClientEvent('exti_heists:client:npcRage', nxt, r.id) end
    if r.chase then TriggerClientEvent('exti_heists:client:npcChase', nxt, r.id) end
    if (r.holdUntil or 0) > H.now() then TriggerClientEvent('exti_heists:client:npcHold', nxt, r.id, r.holdUntil - H.now(), r.holdWhy) end
end
local function tellTargets(r)
    if r.phase == 'on scene' and r.owner then TriggerClientEvent('exti_heists:client:npcTargets', r.owner, r.id, targetsList(r)) end
end

-- the server removes the units itself 40 s after the end (the owner's game may be gone, and they are
-- kept entities nobody else cleans up): time for them to drive off first
local function sweep(r)
    local units = r.units or {}
    SetTimeout(40000, function()
        for _, n in ipairs(units) do
            local ent = NetworkGetEntityFromNetworkId(n)
            if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
        end
    end)
end

local function endResponse(id, why)
    local r = active[id]; if not r then return end
    active[id] = nil
    sweep(r)
    for s in pairs(r.targets) do
        if byPlayer[s] == id then byPlayer[s] = nil end
        TriggerClientEvent('exti_heists:client:npcEnd', s, id, why)
    end
    H.log(r.owner, 'npc_end', ('%s · %s'):format(r.kind, why))
end
H.npcEnd = endResponse

---------------------------------------------------------------------------
-- hold your fire (the standoff, a deal, a head start) / fire at will
---------------------------------------------------------------------------
function H.npcHold(r, seconds, why)
    if not r then return end
    r.holdUntil, r.holdWhy = H.now() + seconds, why
    if r.owner then TriggerClientEvent('exti_heists:client:npcHold', r.owner, r.id, seconds, why) end
    each(r, function(s) TriggerClientEvent('exti_heists:client:npcHoldBar', s, r.id, seconds, why) end)
end
local function unhold(r)
    r.holdUntil, r.holdWhy = 0, nil
    if r.owner then TriggerClientEvent('exti_heists:client:npcHold', r.owner, r.id, 0, 'clear') end
    each(r, function(s) TriggerClientEvent('exti_heists:client:npcHoldBar', s, r.id, 0, 'clear') end)
end

local function negotiator(r, msg) if H.negotiatorText then each(r, function(s) H.negotiatorText(s, msg) end) end end

-- the warrant: they saw his face (no mask)
local function faceSeen(r)
    for s in pairs(r.targets) do
        local ped = GetPlayerPed(s)
        local ok, mask = pcall(GetPedDrawableVariation, ped, 1)
        if ped ~= 0 and ok and mask == 0 and not (r.warned or {})[s] then
            r.warned = r.warned or {}; r.warned[s] = true
            local cid, name = H.cid(s), H.name(s)
            if cid then
                MySQL.single('SELECT `id` FROM `exti_police_warrants` WHERE `citizenid` = ? AND `closed` IS NULL', { cid }, function(open)
                    if open then return end
                    MySQL.insert('INSERT INTO `exti_police_warrants` (`citizenid`, `name`, `reason`, `officer`, `created`) VALUES (?, ?, ?, ?, ?)',
                        { cid, name, ('سطو مسلح (%s) · رأت حراسة الحي وجهه'):format(r.kind), 'حراسة الحي', os.time() })
                end)
                H.notify(s, 'رأوا وجهك: أنت مطلوب للشرطة', 'error', 7000)
                H.log(s, 'npc_face_seen', r.kind)
            end
        end
    end
end

---------------------------------------------------------------------------
-- the standoff, the storm, the head start, the chase
---------------------------------------------------------------------------
local function storm(r, why)
    if r.rage then return end
    r.rage, r.standoff, r.deal, r.chasePending, r.rageAt = true, nil, nil, nil, H.now()
    unhold(r)
    if r.owner then
        TriggerClientEvent('exti_heists:client:npcRage', r.owner, r.id)
        TriggerClientEvent('exti_heists:client:npcSwat', r.owner, r.id, HG.swat)
    end
    each(r, function(s) TriggerClientEvent('exti_heists:client:npcHoldBar', s, r.id, 0, 'rage') end)
    negotiator(r, (why == 'hurt' and 'آذيت أحدهم. انتهى الكلام. فريق التدخل قادم.')
        or (why == 'attacked' and 'أطلقت النار على رجالنا. انتهى الكلام.')
        or (why == 'broken' and 'خرقت الاتفاق. لا كلام بعد الآن.')
        or (why == 'talk' and 'انتهى الكلام معك. فريق التدخل يقتحم الآن.')
        or 'انتهى الوقت. فريق التدخل يقتحم الآن.')
    H.log(r.owner, 'npc_storm', ('%s · %s'):format(r.kind, why))
end

local function standoff(r)
    if r.standoff or r.rage or r.chase or r.chasePending or r.phase ~= 'on scene' or not r.arrived then return end
    r.standoffEnd = r.standoffEnd or (H.now() + HG.standoffMinutes * 60)
    if r.standoffEnd <= H.now() then return storm(r, 'time') end
    r.standoff = { untilT = r.standoffEnd }
    H.npcHold(r, r.standoffEnd - H.now(), 'hostages')
    H.log(r.owner, 'npc_standoff', r.kind)
    if H.negotiateStart then SetTimeout(C.negotiator.textAfter * 1000, function() if active[r.id] == r and r.standoff then H.negotiateStart(r) end end) end
end

local function chase(r, quiet)
    if active[r.id] ~= r or r.rage then return end
    r.chasePending = nil
    r.chase = { endT = H.now() + HG.chaseMinutes * 60 }
    unhold(r)
    if r.owner then TriggerClientEvent('exti_heists:client:npcChase', r.owner, r.id) end
    tellMode(r)
    if not quiet then negotiator(r, 'انتهت المهلة. نحن قادمون خلفك.') end
    H.log(r.owner, 'npc_chase', r.kind)
end

local function headStart(r, seconds)
    r.standoff, r.deal, r.chasePending = nil, nil, true
    H.npcHold(r, seconds, 'headstart')
    each(r, function(s) TriggerClientEvent('exti_heists:client:dropSpotClear', s, r.id) end)
    SetTimeout(seconds * 1000, function() if active[r.id] == r and r.chasePending then chase(r) end end)
end

-- every hostage of these robbers, wherever they are
local function heldBy(r)
    local n = 0
    for s in pairs(r.targets) do n = n + #(H.hostagesOf and H.hostagesOf(s) or {}) end
    return n
end

-- from hostages.lua: a hostage was taken / let go
function H.npcOnHostage(src)
    local r = H.npcOf(src)
    if r then standoff(r) end
end
function H.npcOnRelease(by, at, why)
    local r = H.npcOf(by)
    -- no deal yet: letting one go is good faith (the negotiator remembers it)
    if r and not r.deal and why == 'released' and r.standoff and not r.rage then
        if H.negotiateGoodwill then H.negotiateGoodwill(r, by, heldBy(r)) end
        return
    end
    if not r or not r.deal or r.deal.kind ~= 'drop' then return end
    if why == 'released' then
        local sp = r.deal.spot
        if #(vec2(at.x, at.y) - vec2(sp.x, sp.y)) > HG.dropRadius and not r.deal.broken then
            -- not where we said: the deal is off (they still won't shoot while he holds the others)
            r.deal.broken = true
            each(r, function(x) TriggerClientEvent('exti_heists:client:dropSpotClear', x, r.id) end)
            negotiator(r, 'هذا ليس المكان الذي اتفقنا عليه. الاتفاق انتهى.')
            H.log(by, 'npc_deal_broken', r.kind)
        end
    end
    if heldBy(r) > 0 then return end
    local broken = r.deal.broken
    if why == 'released' and not broken then
        -- everyone's out at the spot: the head start
        local secs = math.max(HG.dropHeadStart, r.bonusHead or 0)   -- (a head start he talked them into)
        negotiator(r, ('رأيناهم في المكان. اتفاق شريف. معك %d ثانية.'):format(secs))
        H.log(by, 'npc_deal_done', r.kind)
        headStart(r, secs)
    else
        -- let go at the wrong place, or the last one got away some other way: no hostage, no deal
        r.deal = nil; r.standoff = nil
        each(r, function(x) TriggerClientEvent('exti_heists:client:dropSpotClear', x, r.id) end)
        -- (EX_Tii) the deal is off: no more holding back, the SWAT team comes in hard
        if not broken then negotiator(r, 'لم يعد معك أحد. الاتفاق انتهى.') end
        storm(r, 'broken')
    end
end

-- (hostages.lua) a drop deal is on: letting him go anywhere but inside the red circle is refused, not a broken deal
function H.npcDropGuard(by, at)
    local r = H.npcOf(by)
    local d = r and r.deal
    if not d or d.kind ~= 'drop' or d.broken or r.rage or not at then return true end
    if #(vec2(at.x, at.y) - vec2(d.spot.x, d.spot.y)) <= HG.dropRadius then return true end
    return false, 'الاتفاق: أطلقه داخل الدائرة الحمراء (النقطة على خريطتك)'
end

-- the negotiator's deals (negotiate.lua): 'drop' | 'release' | 'time' | 'surrender'
function H.npcDeal(src, kind)
    local r = H.npcOf(src)
    if not r or r.phase ~= 'on scene' then return false, 'none' end
    if r.rage then return false, 'rage' end
    if kind == 'surrender' then return H.npcSurrender(src) end
    if not r.standoff then return false, r.chase and 'chase' or 'nohostage' end
    if kind == 'time' then
        if r.moreUsed then return false, 'once' end
        r.moreUsed = true
        local add = HG.moreTimeMinutes * 60
        r.standoff.untilT = r.standoff.untilT + add
        r.standoffEnd = r.standoff.untilT
        if r.deal then r.deal.deadline = r.deal.deadline + add end
        H.npcHold(r, r.standoff.untilT - H.now(), r.deal and 'deal' or 'hostages')
        return true, math.ceil((r.standoff.untilT - H.now()) / 60)
    elseif kind == 'release' then
        if heldBy(r) == 0 then return false, 'nohostage' end
        r.deal = nil
        each(r, function(x) TriggerClientEvent('exti_heists:client:dropSpotClear', x, r.id) end)
        for s in pairs(r.targets) do H.releaseAll(s, 'deal') end
        H.log(src, 'npc_deal_release', r.kind)
        local secs = math.max(HG.releaseHeadStart, r.bonusHead or 0)   -- (a head start he talked them into)
        headStart(r, secs)
        return true, secs
    elseif kind == 'drop' then
        if r.deal and r.deal.broken then return false, 'broken' end
        if r.deal then return true, r.deal.spot, true end
        if heldBy(r) == 0 then return false, 'nohostage' end
        local here = H.coords(src); if not here then return false end
        local ok, spot = pcall(function()
            return lib.callback.await('exti_heists:client:dropSpot', src, { x = here.x, y = here.y, z = here.z }, HG.dropDistance[1], HG.dropDistance[2])
        end)
        if not ok or type(spot) ~= 'table' or not tonumber(spot.x) then return false, 'nospot' end
        if active[r.id] ~= r or not r.standoff or r.rage or r.chasePending or r.chase then return false, 'none' end
        if r.deal then if r.deal.broken then return false, 'broken' end return true, r.deal.spot, true end
        local p = vec3(spot.x + 0.0, spot.y + 0.0, spot.z + 0.0)
        local d = #(p - here)
        if d < HG.dropDistance[1] * 0.75 or d > HG.dropDistance[2] * 1.4 then return false, 'nospot' end
        r.deal = { kind = 'drop', spot = { x = p.x, y = p.y, z = p.z, street = tostring(spot.street or ''):sub(1, 60) }, deadline = H.now() + HG.dropMinutes * 60 }
        r.standoff.untilT = math.max(r.standoff.untilT, r.deal.deadline)
        H.npcHold(r, r.deal.deadline - H.now(), 'deal')
        each(r, function(s) TriggerClientEvent('exti_heists:client:dropSpotShow', s, r.id, r.deal.spot) end)
        H.log(src, 'npc_deal_drop', ('%s · %.0f m'):format(r.kind, d))
        return true, r.deal.spot
    end
    return false
end

-- they are really there (out of their cars, or the timeout): now they see the hostages and the talking starts
local function arrive(r)
    if r.arrived or active[r.id] ~= r then return end
    r.arrived = true
    each(r, function(s) TriggerClientEvent('exti_heists:client:npcArrived', s, r.id) end)
    if heldBy(r) > 0 then standoff(r)
    elseif H.negotiateStart then SetTimeout(C.negotiator.textAfter * 1000, function() if active[r.id] == r and not r.standoff and not r.rage then H.negotiateStart(r) end end) end
end
RegisterNetEvent('exti_heists:server:npcArrived', function(id)
    local r = active[id]
    if r and r.owner == source then arrive(r) end
end)

---------------------------------------------------------------------------
-- start a response at pos for these players (already in no-police mode)
---------------------------------------------------------------------------
function H.npcRespond(players, pos, kind)
    local spec = N.kinds[kind] or N.kinds.store
    -- one response per robber: a second alarm only adds people to it
    for _, s in ipairs(players) do
        local id = byPlayer[s]
        if id and active[id] then
            local r = active[id]
            for _, o in ipairs(players) do r.targets[o] = true; byPlayer[o] = id end
            tellTargets(r)
            if r.phase == 'on scene' then
                for _, o in ipairs(players) do
                    if o ~= r.owner then TriggerClientEvent('exti_heists:client:npcHunted', o, id) end
                    if r.arrived then TriggerClientEvent('exti_heists:client:npcArrived', o, id) end
                end
                tellMode(r)
            end
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
    r.retry = function()
        if active[id] ~= r then return end
        -- still somebody around? (they all ran before the units came: nothing comes)
        -- (a robber still inside a house is in his own copy of the world: the units wait outside for him)
        local owner, waiting
        for s in pairs(r.targets) do
            local here = H.coords(s)
            if GetPlayerRoutingBucket(s) ~= 0 then waiting = true
            elseif here and #(here - r.pos) < N.giveUpDistance then owner = s break end
        end
        if not owner and waiting and (r.waited or 0) < N.maxMinutes * 30 then
            r.waited = (r.waited or 0) + 1
            SetTimeout(2000, function() if active[id] == r then r.retry() end end)
            return
        end
        if not owner then return endResponse(id, 'gone before') end
        r.owner, r.phase = owner, 'on scene'
        r.spawnedAt = H.now()
        TriggerClientEvent('exti_heists:client:npcSpawn', owner, id, { x = r.pos.x, y = r.pos.y, z = r.pos.z }, r.cars, targetsList(r), spec.weapons)
        for s in pairs(r.targets) do if s ~= owner then TriggerClientEvent('exti_heists:client:npcHunted', s, id) end end
        tellMode(r)
        if r.rage then
            SetTimeout(1500, function()
                if active[id] == r and r.owner then
                    TriggerClientEvent('exti_heists:client:npcRage', r.owner, id)
                    TriggerClientEvent('exti_heists:client:npcSwat', r.owner, id, HG.swat)
                end
            end)
        end
        -- they see his face (a warrant without a mask); the hostages and the talking wait until they are there
        SetTimeout(20000, function() if active[id] == r then faceSeen(r) end end)
        SetTimeout(N.arriveTimeout * 1000, function() arrive(r) end)
    end
    SetTimeout(spec.delay * 1000, function() r.retry() end)
    return id
end

-- the owner's game says units are out (the first ones, the SWAT team, a roadblock): their network ids
RegisterNetEvent('exti_heists:server:npcSpawned', function(id, netIds)
    local src = source
    local r = active[id]
    if not r or r.owner ~= src or type(netIds) ~= 'table' then return end
    r.units = r.units or {}
    local have, fresh = {}, {}
    for _, n in ipairs(r.units) do have[n] = true end
    for _, n in ipairs(netIds) do
        if math.type(n) == 'integer' and not have[n] and #r.units < 60 then r.units[#r.units + 1] = n; have[n] = true; fresh[#fresh + 1] = n end
    end
    -- tag them on the server (a tag set by the game right after creating them may not reach the others)
    SetTimeout(1500, function()
        for _, n in ipairs(fresh) do
            local ent = NetworkGetEntityFromNetworkId(n)
            if ent ~= 0 and DoesEntityExist(ent) then
                Entity(ent).state:set('exti_npcsec', id, true)
                pcall(SetEntityOrphanMode, ent, 2)   -- (they stay when the game that made them leaves, runs off or goes inside; we delete them ourselves)
            end
        end
    end)
    SetTimeout(8000, function()
        if active[id] ~= r then return end
        local alive = 0
        for _, n in ipairs(r.units) do if DoesEntityExist(NetworkGetEntityFromNetworkId(n)) then alive = alive + 1 end end
        if alive == 0 then H.log(src, 'flag_npc_missing', ('%s: units never appeared'):format(r.kind)) end
    end)
end)

-- the owner's game: a robber shot one of them while they held their fire -> the storm
RegisterNetEvent('exti_heists:server:npcAttacked', function(id, by)
    local src = source
    local r = active[id]
    by = math.tointeger(by)
    if not r or r.owner ~= src or not by or not r.targets[by] then return end
    if not (r.standoff or r.chasePending) or r.rage then return end
    storm(r, 'attacked')
end)

-- the owner's game: lost them (out of sight long enough)
RegisterNetEvent('exti_heists:server:npcLost', function(id)
    local src = source
    local r = active[id]
    if not r or not r.targets[src] then return end
    if GetPlayerRoutingBucket(src) ~= 0 then return end   -- (hiding inside a house doesn't lose them)
    if r.standoff or r.deal or r.chasePending then return end   -- (while they wait for you, you can't "lose" them)
    r.targets[src] = nil; byPlayer[src] = nil
    H.notify(src, 'أضعتهم: توقفت حراسة الحي عن البحث', 'success', 6000)
    H.log(src, 'npc_lost', r.kind)
    TriggerClientEvent('exti_heists:client:npcEnd', src, id, r.owner == src and next(r.targets) and 'handover' or 'lost')
    if not next(r.targets) then return endResponse(id, 'everyone lost them') end
    handOver(r, src); tellTargets(r)
end)

-- the loot of this robbery is gone
local function takeLoot(src)
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
    return gone
end

-- downed while they were on you
local function downed(src)
    local id = byPlayer[src]; local r = id and active[id]
    if not r or r.phase ~= 'on scene' then return end
    local gone = takeLoot(src)
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

-- the clock: a real cop arrives / the standoff / the deal / the chase / everyone left
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
                    sweep(r)
                    for tgt in pairs(r.targets) do if byPlayer[tgt] == id then byPlayer[tgt] = nil end end
                    H.log(cop, 'npc_stand_down', r.kind)
                elseif r.standoff then
                    if r.deal and not r.deal.broken and t > r.deal.deadline then
                        storm(r, 'deal time')
                    elseif t > r.standoff.untilT then
                        storm(r, 'time')
                    elseif not r.warned2 and r.standoff.untilT - t <= 120 and not r.deal then
                        r.warned2 = true   -- (two minutes left: the negotiator calls)
                        if H.negotiateWarn then H.negotiateWarn(r) end
                    elseif heldBy(r) == 0 and not r.deal then
                        -- no hostage any more and no deal: nothing holds them back
                        r.standoff = nil; unhold(r); r.spawnedAt = t
                        negotiator(r, 'لا رهائن معك الآن. لا شيء يمنعنا.')
                    end
                elseif r.chase then
                    if t > r.chase.endT then endResponse(id, 'time') end
                elseif r.rage then
                    if t - (r.rageAt or t) > N.maxMinutes * 60 then endResponse(id, 'time') end
                elseif not r.chasePending and t - (r.spawnedAt or t) > N.maxMinutes * 60 then
                    endResponse(id, 'time')
                end
                -- the robber whose game drives them went inside a house: a crewmate still outside drives them
                local rr = active[id]
                if rr and rr.owner and GetPlayerRoutingBucket(rr.owner) ~= 0 then
                    local outside
                    for s in pairs(rr.targets) do if s ~= rr.owner and GetPlayerRoutingBucket(s) == 0 then outside = s break end end
                    if outside then
                        local old = rr.owner
                        TriggerClientEvent('exti_heists:client:npcRelease', old, id)
                        handOver(rr, old)
                    end
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

-- the resource stops: every unit goes (they are kept even when their game leaves, so the server deletes them)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(active) do
        for _, n in ipairs(r.units or {}) do
            local ent = NetworkGetEntityFromNetworkId(n)
            if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
        end
    end
end)

---------------------------------------------------------------------------
-- for hostages.lua / negotiate.lua
---------------------------------------------------------------------------
function H.npcOf(src) local id = byPlayer[src]; return id and active[id] or nil end
function H.npcTargets(r) return targetsList(r) end
function H.npcStandoffLeft(r) return r.standoff and math.max(0, r.standoff.untilT - H.now()) or 0 end

-- the negotiator ends the talk (negotiate.lua): the SWAT team
function H.npcStorm(r, why) if r then storm(r, why) end end

-- the negotiator gives more time (negotiate.lua decides how much, from the mood)
function H.npcMoreTime(r, minutes)
    if not r or not r.standoff or r.rage then return false end
    local add = math.floor(minutes * 60)
    r.standoff.untilT = r.standoff.untilT + add
    r.standoffEnd = r.standoff.untilT
    if r.deal then r.deal.deadline = r.deal.deadline + add end
    H.npcHold(r, r.standoff.untilT - H.now(), r.deal and 'deal' or 'hostages')
    return math.ceil((r.standoff.untilT - H.now()) / 60)
end
function H.npcHeld(r) return r and heldBy(r) or 0 end
function H.npcHeadStart(r, secs) if r and active[r.id] == r and not r.rage then headStart(r, secs) end end

-- a hostage was hurt: no more talking, the SWAT team
function H.npcRage(src)
    local r = H.npcOf(src); if not r then return end
    storm(r, 'hurt')
end

-- he gives himself up: his hostages go, the loot of this robbery is gone, he goes to prison
function H.npcSurrender(src)
    local id = byPlayer[src]; local r = id and active[id]
    if not r then return false end
    H.releaseAll(src, 'surrender')
    local gone = takeLoot(src)
    H.log(src, 'npc_surrender', table.concat(gone, ', '))
    r.targets[src] = nil; byPlayer[src] = nil
    TriggerClientEvent('exti_heists:client:npcEnd', src, id, r.owner == src and next(r.targets) and 'handover' or 'surrender')
    if not next(r.targets) then endResponse(id, 'surrender') else handOver(r, src); tellTargets(r) end
    if GetResourceState('exti_police') == 'started' then
        SetTimeout(4000, function()
            if GetPlayerName(src) then pcall(function() exports.exti_police:Jail(src, HG.surrenderJail, 'حراسة الحي') end) end
        end)
    end
    return true
end
