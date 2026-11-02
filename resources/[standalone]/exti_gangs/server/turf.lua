-- =====================================================================
-- EX_Tii gangs: Turf & graffiti.
--   * zones: drawn by an admin in game (/turfzone: walk the corners), saved in data/turf.json
--   * a gang member sprays his gang's tag on a wall in a zone (spray can, 20 s, 1 can = 1 tag).
--     Up to 5 tags per zone; the gang with the most tags owns it (a tie keeps the owner it had)
--   * a rival scrubs a tag (scrub brush, 15 s, 3 uses); police on duty clean any tag (no brush)
--   * owners get rep every hour per zone; members hear when a rival sprays or scrubs in their turf
--   * spraying can be called in to the police (a witness always, otherwise a chance)
-- =====================================================================
local T = C.turf
local ox = exports.ox_inventory
local FILE = 'data/turf.json'

local zones = {}      -- [i] = { id, name, points = { {x,y}... }, z }
local tags = {}       -- [id] = { id, zone, gang, x, y, z, nx, ny, nz, created }
local owner = {}      -- [zone id] = gang name
local nextZone = 1
local busy = {}       -- [src] = { kind, token, at, ... }

---------------------------------------------------------------------------
-- zones
---------------------------------------------------------------------------
local function num(v) return type(v) == 'number' and v == v and v > -20000 and v < 20000 end

do
    local ok, data = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), FILE) or '')
    if ok and type(data) == 'table' and type(data.zones) == 'table' then
        for _, z in ipairs(data.zones) do
            local pts = {}
            for _, p in ipairs(type(z.points) == 'table' and z.points or {}) do
                if num(p.x) and num(p.y) then pts[#pts + 1] = { x = p.x, y = p.y } end
            end
            local id = math.tointeger(tonumber(z.id))
            if id and #pts >= 3 and type(z.name) == 'string' then
                zones[#zones + 1] = { id = id, name = z.name:sub(1, 40), points = pts, z = num(z.z) and z.z or 0.0 }
                if id >= nextZone then nextZone = id + 1 end
            end
        end
    end
end

local function saveZones()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode({ zones = zones }, { indent = true }), -1)
end

local function zoneById(id) for _, z in ipairs(zones) do if z.id == id then return z end end end

-- is (x, y) inside the zone's outline (ray casting)
local function inside(z, x, y)
    local pts, c = z.points, false
    local j = #pts
    for i = 1, #pts do
        local a, b = pts[i], pts[j]
        if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / ((b.y - a.y) ~= 0 and (b.y - a.y) or 1e-9) + a.x) then c = not c end
        j = i
    end
    return c
end
local function zoneAt(c)
    for _, z in ipairs(zones) do if inside(z, c.x, c.y) then return z end end
end
GANG.zoneAt = zoneAt
function GANG.turfOwner(id) return owner[id] end

---------------------------------------------------------------------------
-- tags + who owns what
---------------------------------------------------------------------------
local function countIn(zoneId)
    local per, total = {}, 0
    for _, t in pairs(tags) do
        if t.zone == zoneId then per[t.gang] = (per[t.gang] or 0) + 1; total = total + 1 end
    end
    return per, total
end

local function recompute(zoneId)
    local per = countIn(zoneId)
    local best, bestN, tie = nil, 0, false
    for gang, n in pairs(per) do
        if n > bestN then best, bestN, tie = gang, n, false elseif n == bestN then tie = true end
    end
    local before = owner[zoneId]
    if not best then owner[zoneId] = nil
    elseif tie then
        -- a tie keeps the owner it had, if he is one of the tied gangs
        if not (before and per[before] == bestN) then owner[zoneId] = nil end
    else owner[zoneId] = best end
    return before, owner[zoneId]
end

local function publish()
    local list = {}
    for _, t in pairs(tags) do
        local g = GANG.gangs[t.gang]
        if g and not t.pending then list[#list + 1] = { id = t.id, zone = t.zone, gang = t.gang, x = t.x, y = t.y, z = t.z, nx = t.nx, ny = t.ny, nz = t.nz, tag = g.tag, color = g.color } end
    end
    local zl = {}
    for _, z in ipairs(zones) do
        local o = owner[z.id] and GANG.gangs[owner[z.id]]
        zl[#zl + 1] = { id = z.id, name = z.name, points = z.points, z = z.z, owner = owner[z.id], ownerLabel = o and o.label or nil, color = o and o.color or nil }
    end
    GlobalState['exti_gangs:turf'] = { zones = zl, tags = list }
end
GANG.publishTurf = publish   -- (a gang changing its tag / colour calls this)

-- a gang was deleted: its tags go too
function GANG.turfDropGang(name)
    local touched = {}
    for id, t in pairs(tags) do
        if t.gang == name and not t.pending then tags[id] = nil; touched[t.zone] = true end
    end
    MySQL.query('DELETE FROM `exti_gang_tags` WHERE `gang` = ?', { name })
    for zid in pairs(touched) do recompute(zid) end
    for zid, gname in pairs(owner) do if gname == name then owner[zid] = nil; recompute(zid) end end
    publish()
end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_tags` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `zone` INT NOT NULL,
        `gang` VARCHAR(50) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `nx` FLOAT NOT NULL, `ny` FLOAT NOT NULL, `nz` FLOAT NOT NULL,
        `by` VARCHAR(50) NOT NULL,
        `created` INT NOT NULL,
        INDEX `zone` (`zone`)
    ) DEFAULT CHARSET=utf8mb4]])
    -- the gangs must be loaded first (server/main.lua), or every tag would look like it has no gang
    while not GANG.ready do Wait(100) end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `exti_gang_tags`') or {}) do
        if zoneById(r.zone) and GANG.gangs[r.gang] then
            tags[r.id] = { id = r.id, zone = r.zone, gang = r.gang, x = r.x, y = r.y, z = r.z, nx = r.nx, ny = r.ny, nz = r.nz, created = r.created }
        end
    end
    for _, z in ipairs(zones) do recompute(z.id) end
    publish()
end)

local function zonesOf(gang)
    local n = 0
    for _, g in pairs(owner) do if g == gang then n = n + 1 end end
    return n
end

-- every hour: rep for every zone owned
CreateThread(function()
    while true do
        Wait(3600 * 1000)
        for name, g in pairs(GANG.gangs) do
            local n = zonesOf(name)
            if n > 0 then GANG.addRep(g, T.repPerZoneHour * n, 'turf') end
        end
    end
end)

---------------------------------------------------------------------------
-- spraying + scrubbing
---------------------------------------------------------------------------
local function cleanVec(v, isNormal)
    if type(v) ~= 'table' or not num(v.x) or not num(v.y) or not num(v.z) then return nil end
    if isNormal then
        local l = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if l < 0.5 or l > 1.5 then return nil end
        return { x = v.x / l, y = v.y / l, z = v.z / l }
    end
    return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 }
end

local function warnGangs(zone, actorGang, text)
    -- every gang with tags in the zone (or owning it), but not the one doing it
    local per = countIn(zone.id)
    local told = {}
    if owner[zone.id] then per[owner[zone.id]] = per[owner[zone.id]] or 1 end
    for gang in pairs(per) do
        if gang ~= actorGang and not told[gang] and GANG.gangs[gang] then
            told[gang] = true
            GANG.toGang(GANG.gangs[gang], text, 'error')
        end
    end
end

local function policeMaybe(src, here, zone, witness)
    if GetResourceState('exti_police') ~= 'started' then return end
    local th = C.theft
    if not (witness or math.random() < ((GANG.nightNow and GANG.nightNow()) and th.nightChance or th.dayChance)) then return end
    pcall(function()
        exports.exti_police:AddCall({ kind = 'alarm', label = 'كتابة على الجدران', coords = { x = here.x, y = here.y, z = here.z },
            text = ('شخص يرسم علامة عصابة · %s%s'):format(zone.name, witness and ' · شاهد رأى ذلك' or ''), number = witness and 'شاهد' or 'نظام الإنذار' })
    end)
end

lib.callback.register('exti_gangs:server:tagBegin', function(source, pos, normal)
    local g, m = GANG.memberOf(source)
    if not g then return false, 'nogang' end
    pos, normal = cleanVec(pos), cleanVec(normal, true)
    if not pos or not normal or math.abs(normal.z) > 0.35 then return false, 'wall' end
    if not GANG.near(source, pos, 3.5) then return false, 'far' end
    local zone = zoneAt(pos)
    if not zone then return false, 'nozone' end
    local cd = GANG.cooldownLeft('tag:' .. m.citizenid)
    if cd > 0 then return false, 'cooldown', cd end
    local _, total = countIn(zone.id)
    if total >= T.maxPerZone then return false, 'full' end
    for _, t in pairs(tags) do
        if #(vec3(t.x, t.y, t.z) - vec3(pos.x, pos.y, pos.z)) < T.minGap then return false, 'close' end
    end
    if (ox:GetItemCount(source, 'spray_can') or 0) < 1 then return false, 'nocan' end
    local token = math.random(100000, 999999)
    busy[source] = { kind = 'tag', token = token, at = os.time(), pos = pos, normal = normal, zone = zone.id, gang = g.name }
    return true, { token = token, seconds = T.spraySeconds, zone = zone.name }
end)

lib.callback.register('exti_gangs:server:tagFinish', function(source, token, witness)
    local b = busy[source]; busy[source] = nil
    if not b or b.kind ~= 'tag' or b.token ~= token or os.time() - b.at < T.spraySeconds - 1 then return false end
    local g, m, p = GANG.memberOf(source)
    if not g or g.name ~= b.gang or not GANG.near(source, b.pos, 4.0) then return false end
    local zone = zoneById(b.zone)
    if not zone then return false end
    local _, total = countIn(zone.id)
    if total >= T.maxPerZone then return false, 'full' end
    for _, t in pairs(tags) do
        if #(vec3(t.x, t.y, t.z) - vec3(b.pos.x, b.pos.y, b.pos.z)) < T.minGap then return false, 'close' end
    end
    if not ox:RemoveItem(source, 'spray_can', 1) then return false, 'nocan' end
    -- hold the spot while the database writes (two players finishing at once can't make a 6th tag)
    local hold = 'p' .. source
    tags[hold] = { id = hold, zone = zone.id, gang = g.name, x = b.pos.x, y = b.pos.y, z = b.pos.z, nx = 0, ny = 0, nz = 0, pending = true }
    local id = MySQL.insert.await('INSERT INTO `exti_gang_tags` (`zone`, `gang`, `x`, `y`, `z`, `nx`, `ny`, `nz`, `by`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { zone.id, g.name, b.pos.x, b.pos.y, b.pos.z, b.normal.x, b.normal.y, b.normal.z, m.citizenid, os.time() })
    tags[hold] = nil
    if not id then ox:AddItem(source, 'spray_can', 1); return false end
    tags[id] = { id = id, zone = zone.id, gang = g.name, x = b.pos.x, y = b.pos.y, z = b.pos.z, nx = b.normal.x, ny = b.normal.y, nz = b.normal.z, created = os.time() }
    GANG.setCooldown('tag:' .. m.citizenid, T.cooldown)
    local before, after = recompute(zone.id)
    publish()
    warnGangs(zone, g.name, ('عصابة %s رسمت علامتها في منطقتكم: %s'):format(g.label, zone.name))
    if after == g.name and before ~= g.name then
        GANG.toGang(g, ('سيطرتم على %s!'):format(zone.name), 'success')
        if before and GANG.gangs[before] then GANG.toGang(GANG.gangs[before], ('خسرتم %s لصالح %s'):format(zone.name, g.label), 'error') end
    end
    GANG.log(g, GANG.charName(p), 'turf_tag', zone.name)
    policeMaybe(source, b.pos, zone, witness == true)
    return true, { zone = zone.name, owner = after == g.name }
end)

lib.callback.register('exti_gangs:server:scrubBegin', function(source, tagId)
    tagId = math.tointeger(tonumber(tagId))
    local t = tagId and tags[tagId]
    if not t then return false, 'gone' end
    local here = GANG.coords(source)
    if not here or #(vec3(t.x, t.y, t.z) - here) > 3.0 then return false, 'far' end
    local cop = GANG.isCopOnDuty and GANG.isCopOnDuty(source)
    if not cop then
        local g = GANG.memberOf(source)
        if not g then return false, 'nogang' end
        if g.name == t.gang then return false, 'own' end
        if (ox:GetItemCount(source, 'scrub_brush') or 0) < 1 then return false, 'nobrush' end
    end
    local token = math.random(100000, 999999)
    busy[source] = { kind = 'scrub', token = token, at = os.time(), tag = tagId, cop = cop }
    return true, { token = token, seconds = T.scrubSeconds, cop = cop }
end)

-- one use off the brush (3 uses, kept in the item's metadata)
local function useBrush(src)
    local slot = ox:GetSlotWithItem(src, 'scrub_brush')
    if not slot then return false end
    local uses = (slot.metadata and tonumber(slot.metadata.uses)) or T.brushUses
    uses = uses - 1
    if uses <= 0 then return ox:RemoveItem(src, 'scrub_brush', 1, nil, slot.slot) end
    local meta = slot.metadata or {}
    meta.uses = uses
    meta.description = ('استعمالات متبقية: %d'):format(uses)
    ox:SetMetadata(src, slot.slot, meta)
    return true
end

lib.callback.register('exti_gangs:server:scrubFinish', function(source, token)
    local b = busy[source]; busy[source] = nil
    if not b or b.kind ~= 'scrub' or b.token ~= token or os.time() - b.at < T.scrubSeconds - 1 then return false end
    local t = tags[b.tag]
    if not t then return false, 'gone' end
    local here = GANG.coords(source)
    if not here or #(vec3(t.x, t.y, t.z) - here) > 3.5 then return false, 'far' end
    local g, _, p = GANG.memberOf(source)
    if not b.cop then
        if not g or g.name == t.gang then return false end
        if not useBrush(source) then return false, 'nobrush' end
    end
    tags[t.id] = nil
    MySQL.query('DELETE FROM `exti_gang_tags` WHERE `id` = ?', { t.id })
    local zone = zoneById(t.zone)
    local before, after = recompute(t.zone)
    publish()
    local victim = GANG.gangs[t.gang]
    if zone and victim then
        GANG.toGang(victim, b.cop and ('الشرطة نظّفت علامتكم في %s'):format(zone.name) or ('عصابة %s مسحت علامتكم في %s'):format(g.label, zone.name), 'error')
        if before == t.gang and after ~= t.gang then GANG.toGang(victim, ('خسرتم السيطرة على %s'):format(zone.name), 'error') end
        GANG.log(victim, b.cop and 'الشرطة' or GANG.charName(p), 'turf_scrubbed', zone.name)
    end
    if g and not b.cop then GANG.log(g, GANG.charName(p), 'turf_scrub', zone and zone.name or '') end
    return true, { zone = zone and zone.name or '' }
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)

---------------------------------------------------------------------------
-- admins: /turfzone (draw on the game side, save here)
---------------------------------------------------------------------------
local function isAdmin(src) return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command') end

lib.addCommand('turfzone', { help = 'رسم مناطق النفوذ للعصابات', restricted = 'group.admin' }, function(source)
    TriggerClientEvent('exti_gangs:client:turfMenu', source)
end)

lib.callback.register('exti_gangs:server:zoneSave', function(source, name, points, id)
    if not isAdmin(source) then return false end
    if type(name) ~= 'string' or #name < 2 or type(points) ~= 'table' or #points < 3 or #points > T.maxPoints then return false, 'bad' end
    local pts, zsum = {}, 0
    for _, p in ipairs(points) do
        if not num(p.x) or not num(p.y) then return false, 'bad' end
        pts[#pts + 1] = { x = p.x + 0.0, y = p.y + 0.0 }
        zsum = zsum + (num(p.z) and p.z or 0)
    end
    name = name:gsub('[%c<>]', ''):sub(1, 40)
    id = math.tointeger(tonumber(id))
    local z = id and zoneById(id)
    if z then
        z.name, z.points, z.z = name, pts, zsum / #pts
    else
        z = { id = nextZone, name = name, points = pts, z = zsum / #pts }
        nextZone = nextZone + 1
        zones[#zones + 1] = z
    end
    -- tags that are no longer inside their zone go
    for tid, t in pairs(tags) do
        if t.zone == z.id and not inside(z, t.x, t.y) then tags[tid] = nil; MySQL.query('DELETE FROM `exti_gang_tags` WHERE `id` = ?', { tid }) end
    end
    recompute(z.id)
    saveZones(); publish()
    return true, z.id
end)

lib.callback.register('exti_gangs:server:zoneDelete', function(source, id)
    if not isAdmin(source) then return false end
    id = math.tointeger(tonumber(id))
    for i, z in ipairs(zones) do
        if z.id == id then
            table.remove(zones, i)
            for tid, t in pairs(tags) do if t.zone == id then tags[tid] = nil end end
            MySQL.query('DELETE FROM `exti_gang_tags` WHERE `zone` = ?', { id })
            owner[id] = nil
            saveZones(); publish()
            return true
        end
    end
    return false
end)

---------------------------------------------------------------------------
-- the laptop's Turf tab
---------------------------------------------------------------------------
function GANG.turfView(g)
    local list = {}
    for _, z in ipairs(zones) do
        local per, total = countIn(z.id)
        local o = owner[z.id] and GANG.gangs[owner[z.id]]
        list[#list + 1] = { name = z.name, owner = o and o.label or nil, color = o and o.color or nil, mine = owner[z.id] == g.name,
                            myTags = per[g.name] or 0, total = total, max = T.maxPerZone }
    end
    return { zones = list, owned = zonesOf(g.name), repPerHour = T.repPerZoneHour * zonesOf(g.name) }
end
