-- =====================================================================
-- EX_Tii medical (server): test patients.
-- An admin types /fakepatient [type] [awake|down|dead] and a hurt NPC appears on the ground in
-- front of him, with test injuries. Medics examine it like a real patient (E next to it, or
-- "افحص أقرب شخص" on the tablet). It has a negative id, is never saved, and goes away with
-- /fakepatientclear, after Config.fake.minutes, or when the admin who made it leaves.
-- =====================================================================

Med = Med or {}

local fakes = Med.fakes   -- [negative id] = test patient (shared with server/wounds.lua)
local nextId = -1000
local STATES = { awake = 1, down = 2, dead = 3 }
local WAIT_READY = 30     -- seconds the admin's game has to make the NPC

local function pick(t) return t[math.random(#t)] end

-- is this entity really our NPC? (network ids get reused by the game once an entity is gone,
-- so the id alone is not enough: the mark on the entity must match too)
local function isOurs(ent, id)
    if ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return false end
    local mark = Entity(ent).state.exti_fake
    return type(mark) == 'table' and mark.id == id
end

--- the NPC's entity on the server (0 if it is not there)
function Med.fakeEntity(f)
    if not f or not f.netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(f.netId)
    return isOurs(ent, f.id) and ent or 0
end

-- tell the admin's game to delete its copy (also one that was never finished)
local function dropOnClient(creator, id)
    if type(creator) == 'number' and creator > 0 and GetPlayerPing(creator) > 0 then
        TriggerClientEvent('exti_medical:client:dropFake', creator, id)
    end
end

local function remove(id)
    local f = fakes[id]
    if not f then return end
    fakes[id] = nil
    local ent = Med.fakeEntity(f)
    if ent ~= 0 then DeleteEntity(ent) end
    dropOnClient(f.creator, id)
    Med.dropExam(f.cid, id) -- medics with it open are told it is gone
end

local function count()
    local n, oldest = 0, nil
    for id in pairs(fakes) do
        n = n + 1
        if not oldest or id > oldest then oldest = id end -- ids go down: the biggest is the oldest
    end
    return n, oldest
end

local function notify(src, kind, text)
    TriggerClientEvent('ox_lib:notify', src, { type = kind, description = text, duration = 6000 })
end

lib.addCommand('fakepatient', {
    help = 'مريض تجريبي (NPC) على الأرض لتجربة الفحص — مثال: /fakepatient gun down',
    restricted = 'group.admin',
    params = {
        { name = 'type', type = 'string', help = 'mix / gun / knife / fall / car / fire / head / chest / smoke / random', optional = true },
        { name = 'state', type = 'string', help = 'awake (واعي) / down (على الأرض) / dead (فاقد الوعي)', optional = true },
    },
}, function(source, args)
    local src = source
    local me = GetPlayerPed(src)
    if me == 0 then return end
    if GetVehiclePedIsIn(me, false) ~= 0 then
        return notify(src, 'error', 'انزل من المركبة أولًا')
    end
    local tests = Med.TESTS or {}
    local kind = tostring(args.type or 'mix'):lower()
    if kind == 'random' then
        local keys = {}
        for k in pairs(tests) do keys[#keys + 1] = k end
        table.sort(keys)
        kind = pick(keys)
    end
    if not tests[kind] then
        return notify(src, 'error', 'نوع غير معروف — اختر: mix / gun / knife / fall / car / fire / head / chest / smoke / random')
    end
    local death = STATES[tostring(args.state or 'down'):lower()]
    if not death then
        return notify(src, 'error', 'الحالة: awake / down / dead')
    end

    local n, oldest = count()
    if n >= Config.fake.max and oldest then remove(oldest) end

    nextId = nextId - 1
    local id = nextId
    local female = math.random() < 0.5
    local sex = female and 'female' or 'male'
    local f = {
        id = id,
        cid = ('npc:%d'):format(-id),
        name = ('%s %s'):format(pick(Config.fake.names[sex]), pick(Config.fake.names.last)),
        female = female,
        age = math.random(19, 64),
        blood = pick(Config.fake.blood),
        death = death,
        hp = death == 3 and 0 or death == 2 and 30 or 85,
        list = {},
        creator = src,
        made = os.time(),
        kind = kind,
    }
    fakes[id] = f
    for _, w in ipairs(tests[kind]) do
        local copy = {}
        for k, v in pairs(w) do copy[k] = v end
        Med.add(id, copy)
    end

    local anim = Config.fake.anims[death][sex]
    TriggerClientEvent('exti_medical:client:spawnFake', src, {
        id = id,
        model = pick(Config.fake.models[sex]),
        dict = anim[1],
        clip = anim[2],
    })
    -- if the NPC never shows up, forget it (and tell the admin's game to drop anything half made)
    SetTimeout(WAIT_READY * 1000, function()
        local g = fakes[id]
        if g and not g.netId and not g.pending then remove(id) end
    end)
end)

-- the admin's game made the NPC: check it, then mark it so the medics' tablets can find it
RegisterNetEvent('exti_medical:server:fakeReady', function(id, netId)
    local src = source
    id, netId = tonumber(id), tonumber(netId)
    if not id or id >= 0 then return end
    local f = fakes[id]
    if not f then
        dropOnClient(src, id) -- removed meanwhile (cleared / too slow): the admin's game deletes it
        return
    end
    if f.creator ~= src or f.netId or f.pending or not netId then return end
    f.pending = true
    CreateThread(function()
        local ent = 0
        for _ = 1, 50 do
            ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then break end
            Wait(100)
        end
        f.pending = nil
        local me = GetPlayerPed(src)
        local valid = ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 1 and not IsPedAPlayer(ent)
            and me ~= 0 and #(GetEntityCoords(ent) - GetEntityCoords(me)) <= 15.0
            and Entity(ent).state.exti_fake == nil
        if fakes[id] ~= f or not valid then
            -- not usable: delete it (only if it really is a fresh NPC next to the admin) and forget it
            if valid then DeleteEntity(ent) end
            dropOnClient(src, id)
            if fakes[id] == f then
                remove(id)
                notify(src, 'error', 'تعذّر تجهيز المريض التجريبي — جرّب مرة ثانية')
            end
            return
        end
        Entity(ent).state:set('exti_fake', { id = id, death = f.death }, true)
        SetEntityOrphanMode(ent, 2) -- stays even if the admin walks far away (we delete it ourselves)
        f.netId = netId
        notify(src, 'success', ('مريض تجريبي جاهز: %s (%s) — قف بجانبه واضغط E، أو "افحص أقرب شخص" في التابلت'):format(f.name, f.kind))
    end)
end)

lib.addCommand('fakepatientclear', {
    help = 'احذف كل المرضى التجريبيين',
    restricted = 'group.admin',
}, function(source)
    local n = 0
    for id in pairs(fakes) do
        remove(id)
        n = n + 1
    end
    notify(source, 'success', ('حُذف %d مريض تجريبي'):format(n))
end)

-- the admin who made them left: they go too
AddEventHandler('playerDropped', function()
    local src = source
    for id, f in pairs(fakes) do
        if f.creator == src then remove(id) end
    end
end)

-- old ones (or ones whose NPC is gone) go away
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for id, f in pairs(fakes) do
            if now - f.made > Config.fake.minutes * 60 or (f.netId and Med.fakeEntity(f) == 0) then
                remove(id)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, f in pairs(fakes) do
        local ent = Med.fakeEntity(f)
        if ent ~= 0 then DeleteEntity(ent) end
    end
end)
