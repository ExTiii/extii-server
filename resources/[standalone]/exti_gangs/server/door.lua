-- =====================================================================
-- EX_Tii gangs: the HQ front door (the houses have no working door of their own).
--   door_out (outside) -> door_in (inside) and back. Members walk in, anyone inside can walk out.
--   Anyone else knocks: the members inside get a [Y]/[U] prompt, the first yes lets him in.
--   Police on duty breach it (10 s, the gang is told); then the door stays open to the police for 10 min.
-- =====================================================================
local D = C.door
local inside = {}     -- [src] = gang name (came in through the door)
local knocks = {}     -- [knock id] = { src, gang, at }
local lastKnock = {}  -- [src] = os.time()
local breaching = {}  -- [src] = { gang, at }
local breached = {}   -- [gang] = os.time()
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
        GANG.toGang(g, 'الشرطة تقتحم باب المقر!', 'error')
        GANG.log(g, 'الشرطة', 'door_breach_start', '')
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

-- a member inside answers the knock
RegisterNetEvent('exti_gangs:server:knockAnswer', function(id, yes)
    local src = source
    id = tonumber(id) or 0
    local k = knocks[id]
    if not k or yes ~= true or os.time() - k.at > 30 then return end
    local g = GANG.memberOf(src)
    if not g or g.name ~= k.gang or not isInside(src, g) then return end
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
