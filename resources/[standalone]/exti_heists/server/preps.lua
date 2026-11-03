-- =====================================================================
-- EX_Tii heists: prep missions. The big jobs need something first: a cartel guard's keycard, the
-- convoy's blueprints, a catering uniform (the yacht, M4). The fence (or the Broker) gives you a car
-- parked somewhere in the city with it inside, sometimes with two men by it. Lockpick the door
-- (its alarm calls the police), take the item from the glovebox. The item is good for one job, 24 hours.
-- =====================================================================
local C = Config
local P = C.preps

local active = {}    -- [cid] = { kind, spot, veh (netId), guards = {netIds}, until, taken }
local lastPrep = {}  -- [cid] = os.time()

local function entOf(n)
    local e = NetworkGetEntityFromNetworkId(math.tointeger(n) or 0)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end

local function publish()
    local o = {}
    for c, x in pairs(active) do if not x.taken and x.untilT > H.now() and x.veh then o[c] = { veh = x.veh, kind = x.kind } end end
    GlobalState['exti_heists:preps'] = o
end

local function clean(a)
    if not a then return end
    for _, n in ipairs(a.guards or {}) do local e = entOf(n); if e then DeleteEntity(e) end end
    local v = entOf(a.veh); if v then DeleteEntity(v) end
end

-- start a prep for this robber (kind = an item name in Config.preps)
function H.startPrep(src, kind)
    local def = P[kind]; local cid = H.cid(src)
    if not def or not cid then return false, 'off' end
    if H.isCopOnDuty(src) then return false, 'cop' end
    local a = active[cid]
    if a and a.untilT > H.now() and not a.taken then return false, ('عندك تحضير لم تنهه: %s'):format(P[a.kind].label) end
    local wait = (lastPrep[cid] or 0) + P.cooldownMinutes * 60 - H.now()
    if wait > 0 then return false, ('لا شيء الآن. بعد %d دقيقة'):format(math.ceil(wait / 60)) end
    -- a free spot (not someone else's right now)
    local free = {}
    for i, sp in ipairs(P.spots) do
        local used = false
        for _, o in pairs(active) do if o.spot == i and o.untilT > H.now() and not o.taken then used = true end end
        if not used then free[#free + 1] = i end
    end
    if #free == 0 then return false, 'كل سياراتي مشغولة. بعد قليل' end
    local i = free[math.random(#free)]
    local sp = P.spots[i]
    clean(a)
    -- (the car and the men are made by his game when he comes near: on the ground, wherever it is)
    active[cid] = { kind = kind, spot = i, guards = {}, untilT = H.now() + P.minutes * 60, src = src }
    lastPrep[cid] = H.now()
    H.log(src, 'prep_start', ('%s at spot %d'):format(kind, i))
    return true, { label = def.label, pos = vec3(sp.x, sp.y, sp.z), minutes = P.minutes }
end


-- the car's door: a lockpick game (the car alarm calls the police)
lib.callback.register('exti_heists:server:prepBegin', function(src)
    local cid = H.cid(src); local a = cid and active[cid]
    local veh = a and entOf(a.veh)
    if not veh or a.taken or a.untilT < H.now() or H.isCopOnDuty(src) then return false end
    if #(GetEntityCoords(veh) - H.coords(src)) > 3.5 then return false end
    if (exports.ox_inventory:Search(src, 'count', 'lockpick') or 0) < 1 then return false, 'تحتاج مفتاح فتح (lockpick)' end
    H.setHeat(src, 2)
    H.touch(src, GetEntityCoords(veh))
    if not a.alarmed then
        a.alarmed = true
        -- the guards wake up and the car alarm goes
        TriggerClientEvent('exti_heists:client:prepAlarm', -1, a.veh, a.guards, src)
        local mode = H.modeFor(2)
        if mode and mode.police and GetResourceState('exti_police') == 'started' then
            local c = GetEntityCoords(veh)
            pcall(function() exports.exti_police:AddCall({ kind = 'alarm', label = C.calls.prep, coords = { x = c.x, y = c.y, z = c.z }, text = 'إنذار سيارة', number = 'إنذار سيارة', suspect = src, vehicle = veh }) end)
        end
    end
    local lv = H.skillLevel(H.rec(src), 'lockpick')
    return true, H.gameBegin(src, 'lockpick', { prep = cid }), { pins = P.lockpickPins, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:prepEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'lockpick', token, passed == true)
    local cid = ctx and ctx.prep
    local a = cid and active[cid]
    if not a or cid ~= H.cid(src) or a.taken then return false end
    if not passed then
        local lv = H.skillLevel(H.rec(src), 'lockpick')
        if math.random() < math.max(0.1, 0.45 - (lv - 1) * 0.08) then exports.ox_inventory:RemoveItem(src, 'lockpick', 1); return false, 'broke' end
        return false, 'failed'
    end
    local veh = entOf(a.veh)
    if not veh or #(GetEntityCoords(veh) - H.coords(src)) > 4.0 then return false end
    a.taken = true; publish()
    SetVehicleDoorsLocked(veh, 1)
    local def = P[a.kind]
    exports.ox_inventory:AddItem(src, a.kind, 1, { label = def.label, description = 'لعملية واحدة', expires = H.now() + P.itemHours * 3600, owner = cid })
    H.addSkill(src, 'lockpick')
    H.log(src, 'prep_done', a.kind)
    -- the car and the men go away after a while
    SetTimeout(120000, function() if active[cid] == a then clean(a); active[cid] = nil end end)
    return true, def.label
end)

-- a prep item still good (and use it up): kind = the item name
function H.takePrep(src, kind)
    for _, slot in pairs(exports.ox_inventory:Search(src, 'slots', kind) or {}) do
        local md = slot.metadata or {}
        if not md.expires or md.expires > H.now() then
            if exports.ox_inventory:RemoveItem(src, kind, 1, nil, slot.slot) then return true end
        end
    end
    return false
end
function H.hasPrep(src, kind)
    for _, slot in pairs(exports.ox_inventory:Search(src, 'slots', kind) or {}) do
        local md = slot.metadata or {}
        if not md.expires or md.expires > H.now() then return true end
    end
    return false
end

-- his game made the car (and the men): we keep their ids
RegisterNetEvent('exti_heists:server:prepSpawned', function(vehNet, guardNets)
    local src = source
    local cid = H.cid(src); local a = cid and active[cid]
    if not a or a.veh or not a.asked then return end
    local veh = entOf(vehNet)
    local sp = P.spots[a.spot]
    if not veh or GetEntityType(veh) ~= 2 or #(GetEntityCoords(veh) - vec3(sp.x, sp.y, sp.z)) > 30.0 then return end
    a.veh = vehNet
    pcall(SetEntityOrphanMode, veh, 2)
    SetVehicleDoorsLocked(veh, 2)
    Entity(veh).state:set('exti_prep', cid, true)
    for _, n in ipairs(type(guardNets) == 'table' and guardNets or {}) do
        local e = entOf(n)
        if e and GetEntityType(e) == 1 and not IsPedAPlayer(e) and #a.guards < 4 then a.guards[#a.guards + 1] = n; Entity(e).state:set('exti_prepguard', cid, true) end
    end
    publish()
end)
CreateThread(function()
    while true do
        Wait(2000)
        for cid, a in pairs(active) do
            -- (the car is gone: his game left with it, or it was towed): make it again next time he's near
            if a.veh and not a.taken and not entOf(a.veh) then
                for _, n in ipairs(a.guards) do local e = entOf(n); if e then DeleteEntity(e) end end
                a.veh, a.guards, a.asked = nil, {}, nil
                publish()
            end
            if not a.veh and not a.taken and GetPlayerName(a.src) and (not a.asked or H.now() - a.asked > 20) then
                local sp = P.spots[a.spot]
                if H.near(a.src, vec3(sp.x, sp.y, sp.z), 160.0) then
                    a.asked = H.now()
                    local def = P[a.kind]
                    TriggerClientEvent('exti_heists:client:prepSpawn', a.src, { x = sp.x, y = sp.y, z = sp.z, w = sp.w }, def.model, def.guards or 0, def.guardModel, def.weapon)
                end
            end
        end
    end
end)

-- back in the city (a crash, a relog): his prep follows him
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local cid = H.cid(src)
    if cid and active[cid] then active[cid].src = src end
end)

-- time's up: the car leaves
CreateThread(function()
    while true do
        Wait(30000)
        local changed = false
        for cid, a in pairs(active) do
            if not a.taken and a.untilT < H.now() then
                clean(a); active[cid] = nil; changed = true
                if GetPlayerName(a.src) then H.notify(a.src, 'انتهى الوقت: ذهبت السيارة', 'error') end
            end
        end
        if changed then publish() end
    end
end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then for _, a in pairs(active) do clean(a) end end end)
CreateThread(function() Wait(1000); GlobalState['exti_heists:preps'] = {} end)
