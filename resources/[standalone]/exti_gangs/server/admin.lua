-- =====================================================================
-- EX_Tii gangs: what the admin panel (exti_admin) can see and change.
-- Only exti_admin calls these (exports run server side; it checks the admin's rights first).
-- =====================================================================
local ox = exports.ox_inventory

local function ownerOf(name) return GANG.gangs[name] end

-- every gang, with what the panel shows
exports('AdminList', function()
    local list = {}
    for name, g in pairs(GANG.gangs) do
        local lv, L = GANG.level(g)
        local ms = {}
        for cid, m in pairs(GANG.members) do
            if m.gang == name then ms[#ms + 1] = { cid = cid, name = m.name, rank = m.rank, online = GANG.srcOf(cid) ~= nil } end
        end
        table.sort(ms, function(a, b) return a.rank > b.rank end)
        local hq = GANG.spots.hq[name] or {}
        list[#list + 1] = {
            name = name, label = g.label, type = g.type, typeLabel = C.types[g.type] and C.types[g.type].label or g.type,
            bank = g.bank or 0, rep = g.rep_xp or 0, level = lv, levelName = L and L.name or '', locked = g.locked == true,
            color = g.color, tag = g.tag, members = ms, rentDue = g.rent_due,
            hq = hq.door_out or hq.laptop or hq.stash,
            stash = GANG.stashSummary and GANG.stashSummary(g) or nil,
            part = C.types[g.type] and C.types[g.type].part,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)

exports('AdminTypes', function()
    local t = {}
    for k, v in pairs(C.types) do t[#t + 1] = { id = k, label = v.label, part = v.part } end
    return t
end)

-- set a value: rep, bank, locked
exports('AdminSet', function(name, field, value, actor)
    local g = ownerOf(name); if not g then return false, 'nogang' end
    if field == 'rep' then
        local v = math.max(0, math.floor(tonumber(value) or 0))
        GANG.addRep(g, v - (g.rep_xp or 0), 'admin')
    elseif field == 'bank' then
        g.bank = math.max(0, math.floor(tonumber(value) or 0)); GANG.saveGang(g)
    elseif field == 'locked' then
        g.locked = value == true; if not g.locked then g.rent_due = os.time() + C.rentEveryDays * 86400 end; GANG.saveGang(g)
    else return false, 'field' end
    GANG.log(g, actor or 'الإدارة', 'admin_set', ('%s = %s'):format(field, tostring(value)))
    TriggerClientEvent('exti_gangs:client:gangsChanged', -1)
    return true
end)

-- put a player in a gang (or change his rank); rank 3 makes him the leader
exports('AdminSetMember', function(src, name, rank, actor)
    local g = ownerOf(name); if not g then return false, 'nogang' end
    local p = GANG.player(src); if not p then return false, 'noplayer' end
    local cid = p.PlayerData.citizenid
    local m = GANG.members[cid]
    rank = math.max(0, math.min(3, math.floor(tonumber(rank) or 0)))
    -- a leader can't be moved out (his gang would have none), nor dropped below leader in his own gang
    if m and m.gang ~= name and GANG.gangs[m.gang] and GANG.gangs[m.gang].leader == cid then return false, 'leader' end
    if g.leader == cid and rank < 3 then return false, 'leader' end
    if m and m.gang ~= name then GANG.removeMember(cid, nil, true) end
    if rank == 3 then
        local old = g.leader
        g.leader = cid; GANG.saveGang(g)
        if old and old ~= cid and GANG.members[old] then GANG.setMember(old, g, 2) end
    end
    GANG.setMember(cid, g, rank, GANG.charName(p))
    GANG.log(g, actor or 'الإدارة', 'admin_member', ('%s · رتبة %d'):format(GANG.charName(p), rank))
    return true
end)

exports('AdminRemoveMember', function(cid, actor)
    local m = GANG.members[cid]; if not m then return false, 'nomember' end
    local g = ownerOf(m.gang)
    if g and g.leader == cid then return false, 'leader' end
    GANG.removeMember(cid, nil, true)      -- (no 48 h wait for an admin move)
    if g then GANG.log(g, actor or 'الإدارة', 'admin_kick', m.name or cid) end
    return true
end)

-- supplies / any item straight into the gang stash
exports('AdminGiveStash', function(name, item, count, actor)
    local g = ownerOf(name); if not g then return false, 'nogang' end
    count = math.max(1, math.min(1000, math.floor(tonumber(count) or 1)))
    item = item or (C.types[g.type] and C.types[g.type].part)
    local ok = ox:AddItem(GANG.stashId(g), item, count)
    if ok then GANG.log(g, actor or 'الإدارة', 'admin_stash', ('%s × %d'):format(item, count)) end
    return ok and true or false, ok and nil or 'stashfull'
end)

-- every cooldown that names this gang or this character goes (the test button)
exports('AdminClearCooldowns', function(name, cid)
    if name == '' then name = nil end
    if cid == '' then cid = nil end
    if not name and not cid then return 0 end
    local n = 0
    for k in pairs(GANG.cooldowns) do
        -- keys are "<what>:<gang or citizenid>[:...]": match that part exactly, never a piece of a word
        local matched = false
        for part in k:gmatch('[^:]+') do if part == name or part == cid then matched = true end end
        if matched then
            GANG.cooldowns[k] = nil; n = n + 1
            MySQL.query('DELETE FROM `exti_gang_cooldowns` WHERE `k` = ?', { k })
        end
    end
    return n
end)

exports('AdminClearTags', function(name)
    if GANG.turfDropGang then GANG.turfDropGang(name) end
    return true
end)

-- the places an admin wants to jump to
exports('AdminPlaces', function()
    local out = {}
    for name, set in pairs(GANG.spots.hq) do
        local g = GANG.gangs[name]
        local p = set.door_out or set.laptop or set.stash
        if p then out[#out + 1] = { label = ('مقر %s'):format(g and g.label or name), x = p.x, y = p.y, z = p.z } end
    end
    for _, h in ipairs(C.houses or {}) do out[#out + 1] = { label = 'بيت فخم · ' .. h.label, x = h.coords.x, y = h.coords.y, z = h.coords.z } end
    local s = GANG.spots
    if s.blackmarket then out[#out + 1] = { label = 'السوق السوداء', x = s.blackmarket.x, y = s.blackmarket.y, z = s.blackmarket.z } end
    if s.fence then out[#out + 1] = { label = 'المصرّف (Fence)', x = s.fence.x, y = s.fence.y, z = s.fence.z } end
    if s.collect.crates[1] then local c = s.collect.crates[1]; out[#out + 1] = { label = 'نقطة جمع القطع', x = c.x, y = c.y, z = c.z } end
    return out
end)

-- create / delete (the same code as /creategang and /deletegang, called directly: no console command)
exports('AdminCreate', function(adminSrc, name, kind, leaderSrc, label)
    return GANG.createGang(adminSrc, { name = name, kind = kind, leader = leaderSrc, label = label }) == true
end)
exports('AdminDelete', function(adminSrc, name)
    return GANG.deleteGang(adminSrc, { name = name }) == true
end)
