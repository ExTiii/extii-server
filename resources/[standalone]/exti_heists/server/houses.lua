-- =====================================================================
-- EX_Tii heists: house burglary (Tiers 1-3)
--   1. The fence gives a lead (an address and its size) by text or face to face. Night only (22:00-05:00).
--   2. Lockpick the front door (quiet) or break a window (loud: the alarm goes off right away).
--   3. Inside (a private copy of the world per break-in): search drawers and closets, crack the wall safe,
--      carry the big item (a TV / a painting) out to your car at walking speed. A noise meter fills when
--      you run, jump or fail: full = the owner wakes up and calls (police, or the NPC security).
--   4. Sell what you took to the fence. Dirty money goes to the Money Wash gang.
-- =====================================================================
local C = Config
local HS = C.house

local leads = {}          -- [id] = lead (see newLead)
local leadOf = {}         -- [cid] = id of the lead this character holds
local nextId = 0
local inside = {}         -- [src] = lead id

local function doorKey(i) return ('house:door:%d'):format(i) end
local function playerKey(cid) return ('house:player:%s'):format(cid) end

local function isNight()
    local t = GlobalState.currentTime
    local h = type(t) == 'table' and tonumber(t.hour) or tonumber(os.date('%H'))
    if HS.nightFrom > HS.nightTo then return h >= HS.nightFrom or h < HS.nightTo end
    return h >= HS.nightFrom and h < HS.nightTo
end
H.isNight = isNight

-- a gang HQ in this house? (the luxury houses can be gang HQs: never send burglars there)
local function gangHome(pos)
    local s = GlobalState['exti_gangs:spots']
    for _, set in pairs(type(s) == 'table' and s.hq or {}) do
        for _, p in pairs(set) do
            if type(p) == 'table' and p.x and #(vec3(p.x, p.y, p.z) - pos) < 60.0 then return true end
        end
    end
    return false
end

local function publish()
    local open = {}
    for id, l in pairs(leads) do
        if l.phase == 'open' then open[id] = { x = l.pos.x, y = l.pos.y, z = l.pos.z, size = l.size } end
    end
    GlobalState['exti_heists:houses'] = open
end

local function view(l)
    local sz = HS.sizes[l.size]
    return { id = l.id, door = l.door, label = sz.label, area = l.area, pos = { x = l.pos.x, y = l.pos.y, z = l.pos.z }, size = l.size,
             phase = l.phase, expires = l.expires - H.now() }
end

---------------------------------------------------------------------------
-- leads (the fence hands them out: fence.lua)
---------------------------------------------------------------------------
function H.houseLead(src)
    local cid = H.cid(src)
    local old = leadOf[cid] and leads[leadOf[cid]]
    if old and old.phase ~= 'done' then return false, 'عندك بيت لم تنتهِ منه بعد' end
    local left = H.cooldownLeft(playerKey(cid))
    if left > 0 then return false, ('اهدأ قليلًا. كلّمني بعد %d دقيقة'):format(math.ceil(left / 60)) end
    local lv = H.repLevel(src)
    -- the biggest house his Rep allows, sometimes a smaller one
    local pool = {}
    for i, d in ipairs(HS.doors) do
        local sz = HS.sizes[d.size]
        local busy = false
        for _, l in pairs(leads) do if l.door == i and l.phase ~= 'done' then busy = true end end
        if sz and sz.tier <= lv and not busy and H.cooldownLeft(doorKey(i)) == 0 and not gangHome(d.pos) then
            local w = sz.tier == math.min(lv, 3) and 3 or 1
            for _ = 1, w do pool[#pool + 1] = i end
        end
    end
    if #pool == 0 then return false, 'لا بيوت فاضية الليلة. جرّب لاحقًا' end
    local i = pool[math.random(#pool)]
    local d = HS.doors[i]
    nextId = nextId + 1
    local l = { id = nextId, door = i, size = d.size, area = d.area, pos = d.pos, cid = cid, holder = src, phase = 'lead',
                expires = H.now() + C.fence.leadMinutes * 60, members = {}, searched = {}, noise = 0, bucket = 2000 + nextId }
    leads[l.id] = l
    leadOf[cid] = l.id
    TriggerClientEvent('exti_heists:client:houseLead', src, view(l))
    H.log(src, 'house_lead', ('%s · %s #%d'):format(d.size, d.area, i))
    return { label = HS.sizes[d.size].label, area = d.area, pos = d.pos, size = d.size }
end

local function leadFor(src, id)
    local l = leads[math.tointeger(id) or -1]
    return l
end

---------------------------------------------------------------------------
-- the alarm: the police card always; no-police mode sends the NPC security (they wait outside)
---------------------------------------------------------------------------
local function alarm(l, why, loud)
    if l.alarm then return end
    l.alarm = true
    local list = {}
    for s in pairs(l.members) do list[#list + 1] = s end
    if #list == 0 and l.holder then list[1] = l.holder end
    if GetResourceState('exti_police') == 'started' then
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = loud and C.calls.houseLoud or C.calls.house, coords = { x = l.pos.x, y = l.pos.y, z = l.pos.z },
                text = ('%s · %s · %s'):format(HS.sizes[l.size].label, l.area, why), number = 'صاحب البيت', suspect = list[1] })
        end)
    end
    if l.mode and not l.mode.police and #list > 0 then H.npcRespond(list, l.pos, 'house') end
    for s in pairs(l.members) do TriggerClientEvent('exti_heists:client:houseAlarm', s, l.id, why) end
    H.log(list[1], 'house_alarm', ('%s · %s'):format(l.area, why))
end

---------------------------------------------------------------------------
-- breaking in
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:houseBreakBegin', function(src, id, how)
    local l = leadFor(src, id)
    if not l or l.phase ~= 'lead' or l.holder ~= src then return false end
    if not H.near(src, l.pos, 3.0) or H.isCopOnDuty(src) then return false end
    if H.now() > l.expires then return false, 'انتهت مهلة هذا البيت' end
    if not isNight() and not l.admin then return false, 'البيت فيه ناس الآن. انتظر الليل (10 مساءً - 5 صباحًا)' end
    local sz = HS.sizes[l.size]
    local mode = H.modeFor(sz.tier); if not mode then return false end
    l.mode = mode
    if how == 'window' then
        l.phase = 'open'; l.loud = true; l.openedAt = H.now(); publish()
        H.setHeat(src)
        H.log(src, 'house_window', ('%s · %s'):format(l.area, H.modeText(mode)))
        SetTimeout(4000, function() alarm(l, 'كُسرت نافذة', true) end)
        return true, 'open'
    end
    if (exports.ox_inventory:Search(src, 'count', 'lockpick') or 0) < 1 then return false, 'تحتاج مفتاح فتح (lockpick) أو اكسر النافذة' end
    local lv = H.skillLevel(H.rec(src), 'lockpick')
    return true, H.gameBegin(src, 'lockpick', { lead = l.id }), { pins = 5, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:houseBreakEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'lockpick', token, passed == true)
    local l = ctx and leads[ctx.lead]
    if not l or l.phase ~= 'lead' or l.holder ~= src then return false end
    if not passed then
        local lv = H.skillLevel(H.rec(src), 'lockpick')
        if math.random() < math.max(0.1, 0.45 - (lv - 1) * 0.08) then exports.ox_inventory:RemoveItem(src, 'lockpick', 1); return false, 'broke' end
        return false, 'failed'
    end
    if not H.near(src, l.pos, 3.5) then return false end
    l.phase = 'open'; l.openedAt = H.now(); publish()
    H.setHeat(src)
    H.addSkill(src, 'lockpick')
    H.log(src, 'house_open', ('%s · %s'):format(l.area, H.modeText(l.mode)))
    return true
end)

---------------------------------------------------------------------------
-- in and out (anyone at the open door may come in: the crew)
---------------------------------------------------------------------------
local function setInside(src, l)
    inside[src] = l.id
    l.members[src] = true
    SetPlayerRoutingBucket(src, l.bucket)
    local cid = H.cid(src)
    if cid then SetResourceKvp('housedoor:' .. cid, json.encode({ x = l.pos.x, y = l.pos.y, z = l.pos.z })) end
end
local function setOutside(src, l)
    inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    local cid = H.cid(src)
    if cid then DeleteResourceKvp('housedoor:' .. cid) end
    if l then TriggerClientEvent('exti_heists:client:houseOut', src, { x = l.pos.x, y = l.pos.y, z = l.pos.z }) end
end

local function finish(l, why)
    if l.phase == 'done' then return end
    l.phase = 'done'; publish()
    H.setCooldown(doorKey(l.door), HS.houseCooldownMinutes * 60)
    if l.cid then H.setCooldown(playerKey(l.cid), HS.playerCooldownMinutes * 60) end
    for s in pairs(l.members) do
        if inside[s] == l.id then setOutside(s, l) end
        TriggerClientEvent('exti_heists:client:houseDone', s, l.id)
    end
    if l.holder then TriggerClientEvent('exti_heists:client:houseDone', l.holder, l.id) end
    H.log(l.holder, 'house_done', ('%s · %s'):format(l.area, why or ''))
    SetTimeout(5000, function() if leads[l.id] == l then leads[l.id] = nil; if leadOf[l.cid] == l.id then leadOf[l.cid] = nil end end end)
end

lib.callback.register('exti_heists:server:houseEnter', function(src, id)
    local l = leadFor(src, id)
    if not l or l.phase ~= 'open' then return false end
    if not H.near(src, l.pos, 3.5) or H.isCopOnDuty(src) then return false end
    if inside[src] then return false end
    setInside(src, l)
    H.setHeat(src)
    local it = HS.interiors[HS.sizes[l.size].interior]
    -- the spots are rolled once per break-in: which drawers have something in them
    if not l.spots then
        local sz = HS.sizes[l.size]
        local all = {}
        for k = 1, #it.spots do all[k] = k end
        for k = #all, 2, -1 do local j = math.random(k); all[k], all[j] = all[j], all[k] end
        l.spots = {}
        for k = 1, math.min(#all, math.random(sz.spots[1], sz.spots[2])) do l.spots[all[k]] = true end
        l.startedAt = H.now()
        -- inside too long: the owner comes home
        SetTimeout(HS.maxMinutes * 60 * 1000, function() if leads[l.id] == l and l.phase == 'open' then alarm(l, 'رجع صاحب البيت') end end)
    end
    local list = {}
    for k in pairs(l.spots) do list[#list + 1] = k end
    return true, {
        id = l.id, size = l.size, interior = HS.sizes[l.size].interior, spots = list, searched = l.searched,
        safeDone = l.safeDone == true, pickupTaken = l.pickupTaken == true, alarm = l.alarm == true, noise = l.noise,
        dog = HS.sizes[l.size].dog == true, loud = l.loud == true,
    }
end)

lib.callback.register('exti_heists:server:houseLeave', function(src, id)
    local l = leadFor(src, id)
    if not l or inside[src] ~= l.id then return false end
    local it = HS.interiors[HS.sizes[l.size].interior]
    if not H.near(src, vec3(it.exit.x, it.exit.y, it.exit.z), 4.0) then return false end
    setOutside(src, l)
    -- the Rep comes when you get out with something
    if l.looted and l.looted[src] and not (l.repDone and l.repDone[src]) then
        l.repDone = l.repDone or {}; l.repDone[src] = true
        H.repFor(src, HS.sizes[l.size].tier, l.mode)
    end
    -- everyone out: the house is done
    local still = false
    for s in pairs(l.members) do if inside[s] == l.id then still = true end end
    if not still then SetTimeout(60000, function() if leads[l.id] == l then
        local back = false
        for s in pairs(l.members) do if inside[s] == l.id then back = true end end
        if not back then finish(l, 'everyone out') end
    end end) end
    return true
end)

---------------------------------------------------------------------------
-- searching, the safe, the big item
---------------------------------------------------------------------------
local searching = {}   -- [src] = { id, spot, at, secs }
local function rollLoot(l)
    local tier = HS.sizes[l.size].tier
    local total, pool = 0, {}
    for _, e in ipairs(HS.loot) do if not e.minTier or tier >= e.minTier then total = total + e.weight; pool[#pool + 1] = e end end
    local r = math.random() * total
    for _, e in ipairs(pool) do
        r = r - e.weight
        if r <= 0 then return e.item, math.random(e.amount[1], e.amount[2]) end
    end
end

lib.callback.register('exti_heists:server:houseSearchBegin', function(src, id, spot)
    local l = leadFor(src, id)
    spot = math.tointeger(spot)
    if not l or inside[src] ~= l.id or not spot or l.searched[spot] then return false end
    local it = HS.interiors[HS.sizes[l.size].interior]
    local p = it.spots[spot]
    if not p or not H.near(src, p, 2.2) then return false end
    local secs = math.random(HS.searchSeconds[1], HS.searchSeconds[2])
    searching[src] = { id = l.id, spot = spot, at = GetGameTimer(), secs = secs }
    return true, secs
end)

lib.callback.register('exti_heists:server:houseSearchEnd', function(src)
    local s = searching[src]; searching[src] = nil
    local l = s and leads[s.id]
    if not l or inside[src] ~= l.id or l.searched[s.spot] then return false end
    if GetGameTimer() - s.at < (s.secs - 1) * 1000 then return false end
    local it = HS.interiors[HS.sizes[l.size].interior]
    if not H.near(src, it.spots[s.spot], 2.6) then return false end
    l.searched[s.spot] = true
    for m in pairs(l.members) do if m ~= src then TriggerClientEvent('exti_heists:client:houseSearched', m, l.id, s.spot) end end
    if not l.spots[s.spot] then return true, {} end
    local found = {}
    local sz = HS.sizes[l.size]
    for _ = 1, math.random(sz.rolls[1], sz.rolls[2]) do
        local item, n = rollLoot(l)
        if item then
            if item == 'black_money' then n = math.floor(n * (l.mode and l.mode.pay or 1)) end
            H.giveLoot(src, item, n); found[#found + 1] = { item = item, n = n }
        end
    end
    if #found > 0 then l.looted = l.looted or {}; l.looted[src] = true end
    return true, found
end)

lib.callback.register('exti_heists:server:houseSafeBegin', function(src, id)
    local l = leadFor(src, id)
    if not l or inside[src] ~= l.id or l.safeDone then return false end
    local it = HS.interiors[HS.sizes[l.size].interior]
    if not it.safe or not HS.sizes[l.size].safe or not H.near(src, it.safe, 2.4) then return false end
    local lv = H.skillLevel(H.rec(src), 'breaching')
    return true, H.gameBegin(src, 'safedial', { lead = l.id }), { numbers = l.size == 'mansion' and 4 or 3, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:houseSafeEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'safedial', token, passed == true)
    local l = ctx and leads[ctx.lead]
    if not l or inside[src] ~= l.id or l.safeDone then return false end
    if not passed then
        l.noise = math.min(100, l.noise + HS.noise.safeFail)
        return false, 'failed'
    end
    local it = HS.interiors[HS.sizes[l.size].interior]
    if not H.near(src, it.safe, 2.8) then return false end
    l.safeDone = true
    local sz = HS.sizes[l.size]
    local pay = H.payOf(sz.safe, l.mode)
    H.giveLoot(src, 'black_money', pay)
    local extra = math.random() < 0.6 and (math.random() < 0.5 and 'rolex' or 'diamond_ring') or nil
    if extra then H.giveLoot(src, extra, 1) end
    local usb = sz.usb and math.random() < sz.usb * (l.mode.usb or 1)
    if usb then exports.ox_inventory:AddItem(src, 'usb_green', 1) end
    H.addSkill(src, 'breaching')
    l.looted = l.looted or {}; l.looted[src] = true
    for m in pairs(l.members) do if m ~= src then TriggerClientEvent('exti_heists:client:houseSafeDone', m, l.id) end end
    H.log(src, 'house_safe', ('%s · $%d%s%s'):format(l.area, pay, extra and (' + ' .. extra) or '', usb and ' + green USB' or ''))
    return true, { money = pay, extra = extra, usb = usb }
end)

-- the big item: picked up inside, put in a car outside (it is only an item once it's in the car)
local carrying = {}   -- [src] = { item, id }
lib.callback.register('exti_heists:server:housePickup', function(src, id)
    local l = leadFor(src, id)
    if not l or inside[src] ~= l.id or l.pickupTaken or carrying[src] then return false end
    local it = HS.interiors[HS.sizes[l.size].interior]
    if not it.pickup or not H.near(src, it.pickup.pos, 2.4) then return false end
    l.pickupTaken = true
    carrying[src] = { item = HS.sizes[l.size].pickup, id = l.id }
    for m in pairs(l.members) do if m ~= src then TriggerClientEvent('exti_heists:client:housePickedUp', m, l.id) end end
    return true, it.pickup.model, carrying[src].item
end)

lib.callback.register('exti_heists:server:houseStow', function(src, netId)
    local c = carrying[src]; if not c then return false end
    if inside[src] then return false end
    local veh = NetworkGetEntityFromNetworkId(math.tointeger(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false end
    local here = H.coords(src)
    if not here or #(GetEntityCoords(veh) - here) > 4.5 then return false end
    carrying[src] = nil
    H.giveLoot(src, c.item, 1)
    local l = leads[c.id]
    if l then l.looted = l.looted or {}; l.looted[src] = true end
    H.log(src, 'house_stow', c.item)
    return true, c.item
end)
-- dropped it (or downed): it's gone
RegisterNetEvent('exti_heists:server:houseDropCarry', function() carrying[source] = nil end)

---------------------------------------------------------------------------
-- noise (the game reports the meter; full = the owner wakes)
---------------------------------------------------------------------------
RegisterNetEvent('exti_heists:server:houseNoise', function(id, level)
    local src = source
    local l = leadFor(src, id)
    if not l or inside[src] ~= l.id then return end
    level = tonumber(level) or 0
    l.noise = math.max(l.noise, math.min(100, level))
    if l.noise >= 100 then alarm(l, 'استيقظ صاحب البيت') end
end)

---------------------------------------------------------------------------
-- leads run out, players leave
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(15000)
        local t = H.now()
        for _, l in pairs(leads) do
            if l.phase == 'lead' and t > l.expires then
                l.phase = 'done'; publish()
                if l.holder then TriggerClientEvent('exti_heists:client:houseDone', l.holder, l.id, 'expired') end
                leads[l.id] = nil; if leadOf[l.cid] == l.id then leadOf[l.cid] = nil end
            elseif l.phase == 'open' and l.openedAt and t - l.openedAt > (HS.maxMinutes + 10) * 60 then
                finish(l, 'time')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    searching[src] = nil; carrying[src] = nil
    local id = inside[src]
    inside[src] = nil
    local l = id and leads[id]
    if l then l.members[src] = nil end
    for _, x in pairs(leads) do if x.holder == src and x.phase == 'lead' then x.holder = nil end end
end)

-- back in after a crash inside a house: out at its front door
function H.houseOnLoaded(src)
    local cid = H.cid(src); if not cid then return end
    local raw = GetResourceKvpString('housedoor:' .. cid)
    if not raw then return end
    DeleteResourceKvp('housedoor:' .. cid)
    local ok, p = pcall(json.decode, raw)
    SetPlayerRoutingBucket(src, 0)
    if ok and type(p) == 'table' and p.x then TriggerClientEvent('exti_heists:client:houseOut', src, p) end
    -- a lead he still holds comes back to his game
    local l = leadOf[cid] and leads[leadOf[cid]]
    if l and l.phase ~= 'done' then l.holder = src; TriggerClientEvent('exti_heists:client:houseLead', src, view(l)) end
end

-- admins (F1): a lead right now, any time of day
function H.adminHouseLead(src, size)
    local cid = H.cid(src); if not cid then return false end
    leadOf[cid] = nil
    H.clearCooldown(playerKey(cid))
    for i, d in ipairs(HS.doors) do
        if d.size == size and H.cooldownLeft(doorKey(i)) == 0 then
            nextId = nextId + 1
            local l = { id = nextId, door = i, size = d.size, area = d.area, pos = d.pos, cid = cid, holder = src, phase = 'lead',
                        expires = H.now() + C.fence.leadMinutes * 60, members = {}, searched = {}, noise = 0, bucket = 2000 + nextId, admin = true }
            leads[l.id] = l; leadOf[cid] = l.id
            TriggerClientEvent('exti_heists:client:houseLead', src, view(l))
            return true
        end
    end
    return false
end
H.isNightOrAdmin = function(l) return isNight() or (l and l.admin) end
