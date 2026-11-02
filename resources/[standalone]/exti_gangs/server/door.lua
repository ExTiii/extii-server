-- =====================================================================
-- EX_Tii gangs: the HQ front door (the houses have no working door of their own).
--   door_out (outside) -> door_in (inside) and back. Members walk in, anyone inside can walk out.
--   Anyone else knocks: the members inside get a [Y]/[U] prompt, the first yes lets him in.
--   Police on duty breach it (10 s, the gang is told); then the door stays open to the police for 10 min.
--   Real doors (a house with its own door): locked for everyone, members open them with [E], they lock
--   again by themselves; others knock; police breach.
-- =====================================================================
local D = C.door
local inside = {}     -- [src] = gang name (came in through the door)
local knocks = {}     -- [knock id] = { src, gang, at }
local lastKnock = {}  -- [src] = os.time()
local breaching = {}  -- [src] = { gang, at }
local breached = {}   -- [gang] = os.time()
local warned = {}     -- [gang] = os.time() (the gang is told once per 30 s)
local nextKnock = 0

local function doors(name)
    local set = GANG.spots.hq[name]
    return set and set.door_out, set and set.door_in
end
local function pos(p) return { x = p.x, y = p.y, z = p.z, h = p.h or 0.0 } end

-- is he inside? came in through the door (and still near the inside door), or simply right by it
local function isInside(src, g)
    local _, din = doors(g.name)
    if not din then return false end
    if inside[src] == g.name then
        if GANG.near(src, din, D.insideRange) then return true end
        inside[src] = nil
    end
    return GANG.near(src, din, 12.0)
end

local function membersInside(g)
    local out = {}
    for cid, m in pairs(GANG.members) do
        if m.gang == g.name then
            local s = GANG.srcOf(cid)
            if s and isInside(s, g) then out[#out + 1] = s end
        end
    end
    return out
end

lib.callback.register('exti_gangs:server:door', function(source, name, action)
    local g = type(name) == 'string' and GANG.gangs[name]
    if not g then return false end
    local dout, din = doors(name)
    if not dout or not din then return false, 'nodoor' end
    local now = os.time()

    if action == 'exit' then
        if not GANG.near(source, din, D.reach + 1.0) then return false, 'far' end
        inside[source] = nil
        return true, pos(dout)
    end

    if not GANG.near(source, dout, D.reach + 1.0) then return false, 'far' end
    local mg, m = GANG.memberOf(source)
    local member = mg and mg.name == name

    if action == 'enter' then
        local cop = GANG.isCopOnDuty(source)
        if not member and not (cop and (breached[name] or 0) + D.breachOpen > now) then return false, 'notmember' end
        inside[source] = name
        return true, pos(din)

    elseif action == 'knock' then
        if member then return false, 'member' end
        if (lastKnock[source] or 0) + D.knockCooldown > now then return false, 'soon' end
        lastKnock[source] = now
        local list = membersInside(g)
        if #list == 0 then return false, 'nobody' end
        nextKnock = nextKnock + 1
        knocks[nextKnock] = { src = source, gang = name, at = now }
        for _, s in ipairs(list) do TriggerClientEvent('exti_gangs:client:knock', s, nextKnock, g.label) end
        return true

    elseif action == 'breachBegin' then
        if not GANG.isCopOnDuty(source) then return false, 'notcop' end
        if (breached[name] or 0) + D.breachOpen > now then inside[source] = name; return true, { open = true, to = pos(din) } end
        breaching[source] = { gang = name, at = now }
        if (warned[name] or 0) + 30 <= now then
            warned[name] = now
            GANG.toGang(g, 'الشرطة تقتحم باب المقر!', 'error')
            GANG.log(g, 'الشرطة', 'door_breach_start', '')
        end
        return true, { seconds = D.breachSeconds }

    elseif action == 'breachFinish' then
        local b = breaching[source]; breaching[source] = nil
        if not b or b.gang ~= name or now - b.at < D.breachSeconds - 1 or not GANG.isCopOnDuty(source) then return false end
        breached[name] = now
        inside[source] = name
        GANG.toGang(g, 'الشرطة كسرت باب المقر ودخلت!', 'error')
        GANG.log(g, 'الشرطة', 'door_breached', '')
        return true, pos(din)
    end
    return false
end)

---------------------------------------------------------------------------
-- real doors (the house has its own door): locked for everyone, members open with [E]
---------------------------------------------------------------------------
local R = C.realDoor
local locks = {}      -- [gang] = { [i] = false when open }   (missing = locked)
local lockTimer = {}  -- [gang .. i] = n (a newer open cancels the older auto-lock)
local breachedDoor = {} -- [gang .. i] = os.time()

local function publishLocks() GlobalState['exti_gangs:locks'] = locks end
publishLocks()

local function realDoors(name) local set = GANG.spots.hq[name]; return set and set.doors or {} end
local function isOpen(name, i) return locks[name] ~= nil and locks[name][i] == false end

-- open it (for a while, or until locked again)
local function setOpen(name, i, open, seconds)
    locks[name] = locks[name] or {}
    if open then locks[name][i] = false else locks[name][i] = nil end
    if not next(locks[name]) then locks[name] = nil end
    local key = name .. ':' .. i
    lockTimer[key] = (lockTimer[key] or 0) + 1
    publishLocks()
    if open and seconds then
        local my = lockTimer[key]
        SetTimeout(seconds * 1000, function()
            if lockTimer[key] == my and isOpen(name, i) then setOpen(name, i, false) end
        end)
    end
end
GANG.realDoorOpen = isOpen

local function nearDoor(src, name, i)
    local d = realDoors(name)[i]
    return d and GANG.near(src, d, R.reach) and d or nil
end

lib.callback.register('exti_gangs:server:realDoor', function(source, name, i, action)
    local g = type(name) == 'string' and GANG.gangs[name]
    i = math.tointeger(tonumber(i))
    if not g or not i or not nearDoor(source, name, i) then return false, 'far' end
    local now = os.time()
    local mg = GANG.memberOf(source)
    local member = mg and mg.name == name
    local key = name .. ':' .. i

    if action == 'toggle' then
        if not member then return false, 'notmember' end
        local open = not isOpen(name, i)
        setOpen(name, i, open, open and R.autoLock or nil)
        return true, open

    elseif action == 'knock' then
        if member then return false, 'member' end
        if isOpen(name, i) then return false, 'open' end
        if (lastKnock[source] or 0) + D.knockCooldown > now then return false, 'soon' end
        lastKnock[source] = now
        local d = realDoors(name)[i]
        local list = {}
        for cid, m in pairs(GANG.members) do
            local s = m.gang == name and GANG.srcOf(cid)
            if s and s ~= source and GANG.near(s, d, R.knockRange) then list[#list + 1] = s end
        end
        if #list == 0 then return false, 'nobody' end
        nextKnock = nextKnock + 1
        knocks[nextKnock] = { src = source, gang = name, at = now, door = i }
        for _, s in ipairs(list) do TriggerClientEvent('exti_gangs:client:knock', s, nextKnock, g.label) end
        return true

    elseif action == 'breachBegin' then
        if not GANG.isCopOnDuty(source) then return false, 'notcop' end
        if isOpen(name, i) then return false, 'open' end
        breaching[source] = { gang = name, at = now, door = i }
        if (warned[name] or 0) + 30 <= now then
            warned[name] = now
            GANG.toGang(g, 'الشرطة تقتحم باب المقر!', 'error')
            GANG.log(g, 'الشرطة', 'door_breach_start', '')
        end
        return true, { seconds = D.breachSeconds }

    elseif action == 'breachFinish' then
        local b = breaching[source]; breaching[source] = nil
        if not b or b.gang ~= name or b.door ~= i or now - b.at < D.breachSeconds - 1 or not GANG.isCopOnDuty(source) then return false end
        breachedDoor[key] = now
        setOpen(name, i, true, D.breachOpen)   -- broken: open for 10 min
        GANG.toGang(g, 'الشرطة كسرت باب المقر!', 'error')
        GANG.log(g, 'الشرطة', 'door_breached', '')
        return true
    end
    return false
end)

-- admins: aim at a real door and add it to the HQ (see /gangspots)
lib.callback.register('exti_gangs:server:realDoorAdd', function(source, name, model, coords)
    if not (IsPlayerAceAllowed(source, 'group.admin') or IsPlayerAceAllowed(source, 'command')) then return false end
    model = math.tointeger(tonumber(model))
    if not GANG.gangs[name] or not model or type(coords) ~= 'table' or not tonumber(coords.x) then return false end
    local c = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0, h = 0.0, model = model }
    if not GANG.near(source, c, 8.0) then return false, 'far' end
    local set = GANG.spots.hq[name] or {}
    GANG.spots.hq[name] = set
    set.doors = set.doors or {}
    for _, d in ipairs(set.doors) do
        if d.model == model and math.abs(d.x - c.x) < 0.3 and math.abs(d.y - c.y) < 0.3 and math.abs(d.z - c.z) < 0.3 then return false, 'dupe' end
    end
    if #set.doors >= R.max then return false, 'max' end
    set.doors[#set.doors + 1] = c
    GANG.publishSpots()
    GANG.log(name, GANG.charName(GANG.player(source)), 'spot_realdoor', tostring(#set.doors))
    return true, #set.doors
end)
lib.callback.register('exti_gangs:server:realDoorClear', function(source, name)
    if not (IsPlayerAceAllowed(source, 'group.admin') or IsPlayerAceAllowed(source, 'command')) then return false end
    local set = GANG.spots.hq[name]
    if not set then return false end
    set.doors = nil
    locks[name] = nil
    publishLocks()
    GANG.publishSpots()
    return true
end)

-- a member inside answers the knock
RegisterNetEvent('exti_gangs:server:knockAnswer', function(id, yes)
    local src = source
    id = tonumber(id) or 0
    local k = knocks[id]
    if not k or yes ~= true or os.time() - k.at > 30 then return end
    local g = GANG.memberOf(src)
    if not g or g.name ~= k.gang then return end
    if k.door then
        -- a real door: it opens for a moment (the member must be close to it)
        local d = realDoors(k.gang)[k.door]
        if not d or not GANG.near(src, d, R.knockRange) then return end
        knocks[id] = nil
        setOpen(k.gang, k.door, true, R.autoLock)
        GANG.notify(k.src, 'فُتح لك الباب', 'success')
        GANG.notify(src, 'فتحت الباب', 'success')
        return
    end
    if not isInside(src, g) then return end
    knocks[id] = nil
    local dout, din = doors(k.gang)
    if not dout or not din or not GANG.near(k.src, dout, D.reach + 2.0) then return end
    inside[k.src] = k.gang
    TriggerClientEvent('exti_gangs:client:doorTeleport', k.src, pos(din))
    GANG.notify(src, 'فتحت الباب', 'success')
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, k in pairs(knocks) do if now - k.at > 60 then knocks[id] = nil end end
    end
end)

AddEventHandler('playerDropped', function()
    inside[source] = nil; lastKnock[source] = nil; breaching[source] = nil
end)
