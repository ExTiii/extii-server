-- =====================================================================
-- EX_Tii gangs (server core). The server decides everything: the game only says "I pressed E here".
--   gangs, members and ranks (kept in sync with Qbox's own gang field so other scripts can read it),
--   invites, kicks, promotions, leadership, the gang bank, weekly rent, gang rep, daily caps, logs.
-- =====================================================================
C = require 'config'
GANG = {}                       -- shared with the other server files of this resource

local gangs = {}                -- [name] = gang row (+ .settings table)
local members = {}              -- [citizenid] = { gang, rank, name, joined, last_seen }
local invites = {}              -- [target source] = { gang, from, expires }
GANG.gangs, GANG.members = gangs, members

local DAY = 86400
local function now() return os.time() end
local function today() return os.date('%Y-%m-%d') end
GANG.now, GANG.today = now, today

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function GANG.notify(src, text, kind, duration)
    TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform', position = 'top', duration = duration or 5000 })
end
local notify = GANG.notify

function GANG.player(src) return exports.qbx_core:GetPlayer(src) end

function GANG.cid(src)
    local p = GANG.player(src)
    return p and p.PlayerData.citizenid
end

function GANG.charName(p)
    local ci = p and p.PlayerData.charinfo
    return ci and ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) or '?'
end

function GANG.coords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function GANG.near(src, pos, dist)
    if not pos then return false end
    local here = GANG.coords(src)
    return here ~= nil and #(here - vec3(pos.x, pos.y, pos.z)) <= (dist or 3.0)
end

local function clampInt(v, lo, hi)
    v = math.floor(tonumber(v) or 0)
    if v ~= v then v = lo end
    return math.max(lo, math.min(hi, v))
end
GANG.clampInt = clampInt

local function srcOf(cid)
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source or nil
end
GANG.srcOf = srcOf

-- a member's gang and rank, only while Qbox agrees (an admin may have changed the gang field)
function GANG.memberOf(src)
    local p = GANG.player(src)
    if not p then return nil end
    local m = members[p.PlayerData.citizenid]
    if not m or not gangs[m.gang] then return nil end
    -- Qbox must agree (an admin may have moved him with a Qbox command): seen() puts it right on login
    local qg = p.PlayerData.gang and p.PlayerData.gang.name
    if qg and qg ~= m.gang and qg ~= 'none' then return nil end
    return gangs[m.gang], m, p
end

---------------------------------------------------------------------------
-- logs (laptop + optional Discord webhook)
---------------------------------------------------------------------------
local webhook = GetConvar(C.webhookConvar, '')
function GANG.log(gang, actor, action, details)
    local g = type(gang) == 'table' and gang.name or gang
    MySQL.insert('INSERT INTO `exti_gang_logs` (`gang`, `actor`, `action`, `details`, `created`) VALUES (?, ?, ?, ?, ?)',
        { g or '-', actor or '-', action, details or '', now() })
    lib.logger(-1, 'gangs', ('[%s] %s: %s %s'):format(g or '-', actor or '-', action, details or ''))
    if webhook ~= '' then
        PerformHttpRequest(webhook, function() end, 'POST', json.encode({
            username = 'EX_Tii Gangs',
            embeds = { { title = (g or '-') .. ' · ' .. action, description = ('**%s**\n%s'):format(actor or '-', details or ''), color = 15250247, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } },
        }), { ['Content-Type'] = 'application/json' })
    end
end
local log = GANG.log

---------------------------------------------------------------------------
-- daily counters (saved, so a restart or a relog doesn't reset caps)
---------------------------------------------------------------------------
local daily = {}   -- ['g:name:key' or 'm:cid:key'] = { day, value }
local function dkey(scope, id, key) return scope .. ':' .. id .. ':' .. key end
function GANG.getDaily(scope, id, key)
    local k = dkey(scope, id, key); local d = daily[k]
    if d and d.day == today() then return d.value end
    return 0
end
function GANG.addDaily(scope, id, key, amount)
    local k = dkey(scope, id, key)
    local v = GANG.getDaily(scope, id, key) + amount
    daily[k] = { day = today(), value = v }
    MySQL.query('INSERT INTO `exti_gang_daily` (`k`, `day`, `value`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `value` = IF(`day` = VALUES(`day`), GREATEST(`value`, VALUES(`value`)), VALUES(`value`)), `day` = VALUES(`day`)', { k, today(), v })
    return v
end

-- cooldowns (saved): key -> unix time it ends
local cooldowns = {}
function GANG.cooldownLeft(key)
    local t = cooldowns[key]
    return t and math.max(0, t - now()) or 0
end
function GANG.setCooldown(key, seconds)
    cooldowns[key] = now() + seconds
    MySQL.query('INSERT INTO `exti_gang_cooldowns` (`k`, `until`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `until` = VALUES(`until`)', { key, cooldowns[key] })
end

---------------------------------------------------------------------------
-- rep levels
---------------------------------------------------------------------------
function GANG.level(g)
    local xp, lv = g.rep_xp or 0, 1
    for i, l in ipairs(C.rep.levels) do if xp >= l.xp then lv = i end end
    return lv, C.rep.levels[lv], C.rep.levels[lv + 1]
end

local function stashId(g) return 'gang_' .. g.name end
GANG.stashId = stashId

local function registerStash(g)
    local _, L = GANG.level(g)
    local s = GANG.spot and GANG.spot(g, 'stash')
    exports.ox_inventory:RegisterStash(stashId(g), ('مخزن %s'):format(g.label), L.stashSlots, L.stashWeight, false, { [g.name] = 0 },
        s and vec3(s.x, s.y, s.z) or nil)
end
GANG.registerStash = registerStash

function GANG.addRep(g, amount, why)
    local before = GANG.level(g)
    g.rep_xp = (g.rep_xp or 0) + amount
    MySQL.update('UPDATE `exti_gangs` SET `rep_xp` = ? WHERE `name` = ?', { g.rep_xp, g.name })
    local after, L = GANG.level(g)
    if after > before then
        registerStash(g)
        log(g, 'النظام', 'rep_level', ('وصلت العصابة إلى مستوى %d (%s)'):format(after, L.name))
        GANG.toGang(g, ('سمعة العصابة ارتفعت! المستوى %d: %s'):format(after, L.name), 'success')
    end
end

-- message every online member
function GANG.toGang(g, text, kind, minRank)
    for cid, m in pairs(members) do
        if m.gang == g.name and m.rank >= (minRank or 0) then
            local s = srcOf(cid)
            if s then notify(s, text, kind) end
        end
    end
end

---------------------------------------------------------------------------
-- Qbox gang field: our 4 ranks for every gang we run
---------------------------------------------------------------------------
local function qbxGrades()
    local grades = {}
    for lv, r in pairs(C.ranks) do grades[lv] = { name = r.name, isboss = lv == 3 or nil, bankAuth = lv == 3 or nil } end
    return grades
end

local function qbxCreate(g)
    local ok, err = exports.qbx_core:CreateGangs({ [g.name] = { label = g.label, grades = qbxGrades() } }, false)
    if not ok then lib.print.error(('could not create Qbox gang %s: %s'):format(g.name, tostring(err))) end
end

local function qbxSet(cid, gangName, rank)
    exports.qbx_core:AddPlayerToGang(cid, gangName, rank)
    exports.qbx_core:SetPlayerPrimaryGang(cid, gangName)
end

local function qbxRemove(cid, gangName)
    pcall(function() exports.qbx_core:RemovePlayerFromGang(cid, gangName) end)
end

---------------------------------------------------------------------------
-- the database
---------------------------------------------------------------------------
local function saveGang(g)
    MySQL.update('UPDATE `exti_gangs` SET `label` = ?, `leader` = ?, `bank` = ?, `settings` = ?, `color` = ?, `tag` = ?, `rep_xp` = ?, `rent_due` = ?, `locked` = ?, `outfit` = ? WHERE `name` = ?',
        { g.label, g.leader, g.bank, json.encode(g.settings), g.color, g.tag, g.rep_xp, g.rent_due, g.locked and 1 or 0, g.outfit and json.encode(g.outfit) or nil, g.name })
end
GANG.saveGang = saveGang

local function defaultSettings()
    return {
        partPay = C.partPay.default,
        thiefCut = C.chop.split.thief.def,
        chopperCut = C.chop.split.chopper.def,
        washCut = C.wash.cut.def,
        deposits = true,
    }
end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gangs` (
        `name` VARCHAR(40) NOT NULL PRIMARY KEY,
        `label` VARCHAR(60) NOT NULL,
        `type` VARCHAR(12) NOT NULL,
        `leader` VARCHAR(60) NULL,
        `bank` INT NOT NULL DEFAULT 0,
        `settings` TEXT NULL,
        `color` VARCHAR(9) NOT NULL DEFAULT '#20c997',
        `tag` VARCHAR(6) NULL,
        `rep_xp` INT NOT NULL DEFAULT 0,
        `rent_due` INT NOT NULL DEFAULT 0,
        `locked` TINYINT NOT NULL DEFAULT 0,
        `outfit` TEXT NULL,
        `created` INT NOT NULL DEFAULT 0
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_members` (
        `citizenid` VARCHAR(60) NOT NULL PRIMARY KEY,
        `gang` VARCHAR(40) NOT NULL,
        `rank` TINYINT NOT NULL DEFAULT 0,
        `name` VARCHAR(80) NOT NULL DEFAULT '',
        `joined` INT NOT NULL DEFAULT 0,
        `last_seen` INT NOT NULL DEFAULT 0,
        INDEX `gang` (`gang`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_left` (
        `citizenid` VARCHAR(60) NOT NULL PRIMARY KEY,
        `left_at` INT NOT NULL
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_daily` (
        `k` VARCHAR(120) NOT NULL PRIMARY KEY,
        `day` VARCHAR(10) NOT NULL,
        `value` INT NOT NULL DEFAULT 0
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_cooldowns` (
        `k` VARCHAR(120) NOT NULL PRIMARY KEY,
        `until` INT NOT NULL
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_logs` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `gang` VARCHAR(40) NOT NULL,
        `actor` VARCHAR(80) NOT NULL,
        `action` VARCHAR(40) NOT NULL,
        `details` VARCHAR(500) NULL,
        `created` INT NOT NULL,
        INDEX `gang` (`gang`, `id`)
    ) DEFAULT CHARSET=utf8mb4]])

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `exti_gangs`') or {}) do
        local ok, s = pcall(json.decode, row.settings or '')
        row.settings = ok and type(s) == 'table' and s or {}
        for k, v in pairs(defaultSettings()) do if row.settings[k] == nil then row.settings[k] = v end end
        local ok2, o = pcall(json.decode, row.outfit or '')
        row.outfit = ok2 and type(o) == 'table' and o or nil
        row.locked = row.locked == 1
        gangs[row.name] = row
        qbxCreate(row)
        registerStash(row)
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `exti_gang_members`') or {}) do
        if gangs[row.gang] then members[row.citizenid] = row end
    end
    local t = today()
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `exti_gang_daily` WHERE `day` = ?', { t }) or {}) do
        daily[row.k] = { day = row.day, value = row.value }
    end
    MySQL.query('DELETE FROM `exti_gang_daily` WHERE `day` <> ?', { t })
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `exti_gang_cooldowns` WHERE `until` > ?', { now() }) or {}) do
        cooldowns[row.k] = row['until']
    end
    GANG.ready = true
    TriggerEvent('exti_gangs:server:ready')
    lib.print.info(('[exti_gangs] %d gangs, %d members'):format(qbx.table.size(gangs), qbx.table.size(members)))
end)

---------------------------------------------------------------------------
-- membership
---------------------------------------------------------------------------
local function countRank(g, rank)
    local n = 0
    for _, m in pairs(members) do if m.gang == g.name and m.rank == rank then n = n + 1 end end
    return n
end
local function countRankExcept(g, rank, cid)
    local n = 0
    for c, m in pairs(members) do if m.gang == g.name and m.rank == rank and c ~= cid then n = n + 1 end end
    return n
end
-- an old leader steps down to the highest rank that still has a free place
local function stepDownRank(g, cid)
    for r = 2, 0, -1 do
        if r == 0 or countRankExcept(g, r, cid) < C.rankSlots[r] then return r end
    end
    return 0
end

local function countMembers(g)
    local n = 0
    for _, m in pairs(members) do if m.gang == g.name then n = n + 1 end end
    return n
end
GANG.countMembers = countMembers

local function setMember(cid, g, rank, name)
    local m = members[cid]
    if m then
        m.gang, m.rank = g.name, rank
        if name then m.name = name end
        MySQL.update('UPDATE `exti_gang_members` SET `gang` = ?, `rank` = ?, `name` = ? WHERE `citizenid` = ?', { g.name, rank, m.name, cid })
    else
        m = { citizenid = cid, gang = g.name, rank = rank, name = name or '', joined = now(), last_seen = now() }
        members[cid] = m
        MySQL.insert('INSERT INTO `exti_gang_members` (`citizenid`, `gang`, `rank`, `name`, `joined`, `last_seen`) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `gang` = VALUES(`gang`), `rank` = VALUES(`rank`), `name` = VALUES(`name`), `joined` = VALUES(`joined`)',
            { cid, g.name, rank, m.name, m.joined, m.last_seen })
    end
    qbxSet(cid, g.name, rank)
    local s = srcOf(cid)
    if s then TriggerClientEvent('exti_gangs:client:refresh', s) end
    return m
end

local function removeMember(cid, why, noWait)
    local m = members[cid]
    if not m then return end
    members[cid] = nil
    MySQL.query('DELETE FROM `exti_gang_members` WHERE `citizenid` = ?', { cid })
    if noWait then MySQL.query('DELETE FROM `exti_gang_left` WHERE `citizenid` = ?', { cid })
    else MySQL.query('INSERT INTO `exti_gang_left` (`citizenid`, `left_at`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `left_at` = VALUES(`left_at`)', { cid, now() }) end
    qbxRemove(cid, m.gang)
    local s = srcOf(cid)
    if s then TriggerClientEvent('exti_gangs:client:refresh', s) end
    return m
end

GANG.setMember, GANG.removeMember = setMember, removeMember
GANG.cooldowns = cooldowns

local function leftWait(cid)
    local row = MySQL.single.await('SELECT `left_at` FROM `exti_gang_left` WHERE `citizenid` = ?', { cid })
    if not row then return 0 end
    return math.max(0, row.left_at + C.leaveWaitHours * 3600 - now())
end

-- who may do what to whom (the rules of Moe's plan)
local function canManage(actor, target)
    if actor.rank == 3 then return target.rank < 3 end
    if actor.rank == 2 then return target.rank <= 1 end -- an Underboss handles Runners and Crew
    return false
end

---------------------------------------------------------------------------
-- admin: create / delete a gang
---------------------------------------------------------------------------
local function slug(s) return (tostring(s or ''):lower():gsub('[^%w_]', ''):sub(1, 30)) end

function GANG.createGang(source, args)
    local name, kind = slug(args.name), tostring(args.kind or ''):lower()
    if name == '' or name == 'none' then return notify(source, 'اسم غير صالح', 'error') end
    if gangs[name] then return notify(source, 'هذه العصابة موجودة', 'error') end
    if not C.types[kind] then return notify(source, 'نوع غير معروف: chop / wash / ammo / weapons / weed', 'error') end
    if C.onePerType then
        for _, g in pairs(gangs) do if g.type == kind then return notify(source, ('يوجد بالفعل عصابة من نوع %s: %s'):format(C.types[kind].label, g.label), 'error') end end
    end
    local leader = GANG.player(args.leader)
    if not leader then return notify(source, 'الزعيم غير موجود', 'error') end
    local lcid = leader.PlayerData.citizenid
    if members[lcid] then return notify(source, 'هذا اللاعب في عصابة أخرى', 'error') end
    local g = { name = name, label = args.label and args.label:sub(1, 60) or name, type = kind, leader = lcid, bank = 0,
        settings = defaultSettings(), color = C.colors[math.random(#C.colors)], tag = name:sub(1, 4):upper(), rep_xp = 0,
        rent_due = now() + C.rentEveryDays * DAY, locked = false, created = now() }
    MySQL.insert.await('INSERT INTO `exti_gangs` (`name`, `label`, `type`, `leader`, `bank`, `settings`, `color`, `tag`, `rep_xp`, `rent_due`, `locked`, `created`) VALUES (?, ?, ?, ?, 0, ?, ?, ?, 0, ?, 0, ?)',
        { g.name, g.label, g.type, lcid, json.encode(g.settings), g.color, g.tag, g.rent_due, g.created })
    gangs[name] = g
    qbxCreate(g)
    registerStash(g)
    setMember(lcid, g, 3, GANG.charName(leader))
    log(g, GANG.charName(GANG.player(source)), 'gang_created', ('النوع %s · الزعيم %s'):format(kind, GANG.charName(leader)))
    notify(source, ('تم إنشاء العصابة %s. ضع مقرّها بالأمر /gangspots'):format(g.label), 'success')
    notify(args.leader, ('أصبحت زعيم عصابة %s (%s)'):format(g.label, C.types[kind].label), 'success', 9000)
    TriggerClientEvent('exti_gangs:client:gangsChanged', -1)
    return true
end

lib.addCommand('creategang', {
    help = 'إنشاء عصابة: /creategang [الاسم] [النوع chop|wash|ammo|weapons|weed] [رقم الزعيم] [الاسم الظاهر]',
    params = {
        { name = 'name', type = 'string', help = 'اسم قصير بالإنجليزية (بدون مسافات)' },
        { name = 'kind', type = 'string', help = 'chop | wash | ammo | weapons | weed' },
        { name = 'leader', type = 'playerId', help = 'رقم الزعيم في السيرفر' },
        { name = 'label', type = 'longString', help = 'الاسم الظاهر', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args) GANG.createGang(source, args) end)

function GANG.deleteGang(source, args)
    local g = gangs[slug(args.name)]
    if not g then return notify(source, 'لا توجد عصابة بهذا الاسم', 'error') end
    -- (an admin removed the gang: nobody has to wait 48 h because of it)
    for cid, m in pairs(members) do
        if m.gang == g.name then removeMember(cid, nil, true) end
    end
    MySQL.query('DELETE FROM `exti_gangs` WHERE `name` = ?', { g.name })
    gangs[g.name] = nil
    exports.ox_inventory:ClearInventory(stashId(g))
    if GANG.turfDropGang then GANG.turfDropGang(g.name) end
    -- its HQ places go too (no locked doors left behind on the map)
    if GANG.spots and GANG.spots.hq[g.name] then GANG.spots.hq[g.name] = nil; if GANG.publishSpots then GANG.publishSpots() end end
    log(g.name, GANG.charName(GANG.player(source)), 'gang_deleted', g.label)
    notify(source, 'تم حذف العصابة', 'success')
    TriggerClientEvent('exti_gangs:client:gangsChanged', -1)
    return true
end

lib.addCommand('deletegang', {
    help = 'حذف عصابة (المخزن والبنك يُحذفان)',
    params = { { name = 'name', type = 'string' } },
    restricted = 'group.admin',
}, function(source, args) GANG.deleteGang(source, args) end)

lib.addCommand('gangsetleader', {
    help = 'تغيير زعيم عصابة (للإدارة)',
    params = { { name = 'name', type = 'string' }, { name = 'leader', type = 'playerId' } },
    restricted = 'group.admin',
}, function(source, args)
    local g = gangs[slug(args.name)]
    local p = GANG.player(args.leader)
    if not g or not p then return notify(source, 'عصابة أو لاعب غير موجود', 'error') end
    local cid = p.PlayerData.citizenid
    if members[cid] and members[cid].gang ~= g.name then return notify(source, 'اللاعب في عصابة أخرى', 'error') end
    local old = g.leader
    g.leader = cid; saveGang(g)
    setMember(cid, g, 3, GANG.charName(p))
    if old and old ~= cid and members[old] then setMember(old, g, stepDownRank(g, old)) end
    log(g, GANG.charName(GANG.player(source)), 'leader_set_admin', GANG.charName(p))
    notify(source, 'تم', 'success')
end)

---------------------------------------------------------------------------
-- invites
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:invite', function(source, target)
    local g, m, p = GANG.memberOf(source)
    if not g or m.rank < 2 then return false, 'rank' end
    target = tonumber(target)
    local tp = target and GANG.player(target)
    if not tp or target == source then return false, 'noplayer' end
    if not GANG.near(source, GANG.coords(target), 8.0) then return false, 'far' end
    local tcid = tp.PlayerData.citizenid
    if members[tcid] then return false, 'ingang' end
    if countMembers(g) >= C.maxMembers then return false, 'full' end
    local wait = leftWait(tcid)
    if wait > 0 then return false, 'wait', math.ceil(wait / 3600) end
    invites[target] = { gang = g.name, from = GANG.charName(p), expires = now() + 30 }
    TriggerClientEvent('exti_gangs:client:invite', target, { gang = g.label, color = g.color, tag = g.tag, from = GANG.charName(p), type = C.types[g.type].label })
    return true
end)

RegisterNetEvent('exti_gangs:server:inviteAnswer', function(accept)
    local src = source
    local inv = invites[src]
    invites[src] = nil
    if not inv or inv.expires < now() then return end
    local g = gangs[inv.gang]
    local p = GANG.player(src)
    if not g or not p then return end
    local cid = p.PlayerData.citizenid
    if not accept then
        GANG.toGang(g, ('%s رفض الدعوة'):format(GANG.charName(p)), 'error', 2)
        return
    end
    local wait = leftWait(cid)   -- (a database wait: every other check comes after it, with no wait in between)
    if wait > 0 or members[cid] or not gangs[g.name] or countMembers(g) >= C.maxMembers then return notify(src, 'لا يمكنك الانضمام الآن', 'error') end
    setMember(cid, g, 0, GANG.charName(p))
    log(g, GANG.charName(p), 'joined', ('دعوة من %s'):format(inv.from))
    notify(src, ('انضممت إلى %s كـ %s'):format(g.label, C.ranks[0].name), 'success', 8000)
    GANG.toGang(g, ('%s انضم إلى العصابة'):format(GANG.charName(p)), 'success')
end)

---------------------------------------------------------------------------
-- ranks, kicks, leaving, leadership
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:setRank', function(source, cid, rank)
    local g, m, p = GANG.memberOf(source)
    local t = type(cid) == 'string' and members[cid]
    if math.type(rank) ~= 'integer' then return false, 'rank' end
    if not g or not t or t.gang ~= g.name or rank < 0 or rank > 2 or not canManage(m, t) then return false, 'rank' end
    if m.rank == 2 and rank > 1 then return false, 'rank' end   -- Underboss: Runner <-> Crew only
    if rank == t.rank then return true end
    if rank > 0 and countRankExcept(g, rank, cid) >= C.rankSlots[rank] then return false, 'slots' end
    setMember(cid, g, rank)
    log(g, GANG.charName(p), rank > (t.rank or 0) and 'promote' or 'demote', ('%s → %s'):format(t.name, C.ranks[rank].name))
    local s = srcOf(cid)
    if s then notify(s, ('رتبتك الآن: %s'):format(C.ranks[rank].name), 'inform', 7000) end
    return true
end)

lib.callback.register('exti_gangs:server:kick', function(source, cid)
    local g, m, p = GANG.memberOf(source)
    local t = type(cid) == 'string' and members[cid]
    if not g or not t or t.gang ~= g.name or not canManage(m, t) then return false, 'rank' end
    removeMember(cid)
    log(g, GANG.charName(p), 'kick', t.name)
    local s = srcOf(cid)
    if s then notify(s, ('طُردت من %s. تنتظر %d ساعة قبل الانضمام لعصابة أخرى'):format(g.label, C.leaveWaitHours), 'error', 9000) end
    return true
end)

lib.callback.register('exti_gangs:server:leave', function(source)
    local g, m, p = GANG.memberOf(source)
    if not g then return false end
    if m.rank == 3 then return false, 'leader' end
    removeMember(m.citizenid)
    log(g, GANG.charName(p), 'left', '')
    return true
end)

lib.callback.register('exti_gangs:server:transfer', function(source, cid, confirm1, confirm2)
    local g, m, p = GANG.memberOf(source)
    local t = type(cid) == 'string' and members[cid]
    if not g or m.rank ~= 3 or not t or t.gang ~= g.name or cid == m.citizenid then return false, 'rank' end
    if confirm1 ~= true or confirm2 ~= true then return false, 'confirm' end
    setMember(cid, g, 3)
    setMember(m.citizenid, g, stepDownRank(g, m.citizenid))
    g.leader = cid; saveGang(g)
    log(g, GANG.charName(p), 'leader_transfer', t.name)
    GANG.toGang(g, ('%s أصبح زعيم العصابة'):format(t.name), 'inform', 0)
    return true
end)

---------------------------------------------------------------------------
-- the gang bank (clean cash in, only the leader takes it out)
---------------------------------------------------------------------------
local function tryRent(g)
    local _, L = GANG.level(g)
    local rent = math.floor(C.rentWeekly * (1 - (L.rentOff or 0)))
    if g.bank >= rent then
        g.bank = g.bank - rent
        g.rent_due = math.max(g.rent_due, now()) + C.rentEveryDays * DAY
        if g.locked then g.locked = false; GANG.toGang(g, 'تم دفع الإيجار: المقر مفتوح من جديد', 'success') end
        saveGang(g)
        log(g, 'النظام', 'rent_paid', ('$%d'):format(rent))
        return true
    end
    if not g.locked then
        g.locked = true; saveGang(g)
        log(g, 'النظام', 'rent_unpaid', ('مطلوب $%d'):format(rent))
        GANG.toGang(g, ('لم يُدفع إيجار المقر ($%d): المقر مقفل حتى تودِعوا المبلغ في بنك العصابة'):format(rent), 'error', 0)
    end
    return false
end
GANG.rentFor = function(g) local _, L = GANG.level(g); return math.floor(C.rentWeekly * (1 - (L.rentOff or 0))) end

lib.callback.register('exti_gangs:server:bank', function(source, action, amount)
    local g, m, p = GANG.memberOf(source)
    if not g or not GANG.near(source, GANG.spot(g, 'laptop'), 3.0) then return false, 'far' end
    amount = clampInt(amount, 0, 10000000)
    if amount < 1 then return false, 'amount' end
    if action == 'deposit' then
        if m.rank < 1 then return false, 'rank' end
        if not p.Functions.RemoveMoney('cash', amount, 'gang-bank-deposit') then return false, 'money' end
        g.bank = g.bank + amount; saveGang(g)
        log(g, GANG.charName(p), 'bank_deposit', ('$%d'):format(amount))
        if g.locked or g.rent_due <= now() then tryRent(g) end
        return true, g.bank
    elseif action == 'withdraw' then
        if m.rank < 3 then return false, 'rank' end
        if g.bank < amount then return false, 'bank' end
        g.bank = g.bank - amount; saveGang(g)
        p.Functions.AddMoney('cash', amount, 'gang-bank-withdraw')
        log(g, GANG.charName(p), 'bank_withdraw', ('$%d'):format(amount))
        return true, g.bank
    end
    return false
end)

---------------------------------------------------------------------------
-- settings (leader only) and gang identity
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:settings', function(source, s)
    local g, m, p = GANG.memberOf(source)
    if not g or m.rank ~= 3 or type(s) ~= 'table' then return false, 'rank' end
    local st = g.settings
    st.partPay = clampInt(s.partPay or st.partPay, C.partPay.min, C.partPay.max)
    st.thiefCut = clampInt(s.thiefCut or st.thiefCut, C.chop.split.thief.min, C.chop.split.thief.max)
    st.chopperCut = clampInt(s.chopperCut or st.chopperCut, C.chop.split.chopper.min, C.chop.split.chopper.max)
    st.washCut = clampInt(s.washCut or st.washCut, C.wash.cut.min, C.wash.cut.max)
    if s.deposits ~= nil then st.deposits = s.deposits == true end
    if type(s.color) == 'string' then
        for _, c in ipairs(C.colors) do if c == s.color then g.color = c end end
    end
    if type(s.tag) == 'string' then
        local tag = s.tag:upper():gsub('[^%w]', ''):sub(1, 4)
        if #tag >= 2 then g.tag = tag end
    end
    saveGang(g)
    if GANG.publishTurf then GANG.publishTurf() end   -- the tags on the walls show the new tag / colour
    log(g, GANG.charName(p), 'settings', g.type == 'wash'
        and ('أجر القطعة $%d · نسبة الغسيل %d%% · التسليم %s'):format(st.partPay, st.washCut, st.deposits and 'مفتوح' or 'مقفل')
        or ('أجر القطعة $%d · السارق %d%% · المفكك %d%% · التسليم %s'):format(st.partPay, st.thiefCut, st.chopperCut, st.deposits and 'مفتوح' or 'مقفل'))
    return true
end)

-- the gang outfit (the leader saves what he wears; members put it on at the locker)
lib.callback.register('exti_gangs:server:saveOutfit', function(source, outfit)
    local g, m, p = GANG.memberOf(source)
    if not g or m.rank ~= 3 or type(outfit) ~= 'table' then return false end
    if not GANG.near(source, GANG.spot(g, 'locker'), 3.0) then return false, 'far' end
    local clean = { male = nil, female = nil }
    local sex = outfit.sex == 'female' and 'female' or 'male'
    local comps, props = {}, {}
    for k, v in pairs(outfit.components or {}) do
        local id = tonumber(k)
        if id and id >= 0 and id <= 11 and type(v) == 'table' then comps[tostring(id)] = { clampInt(v[1], 0, 999), clampInt(v[2], 0, 99) } end
    end
    for k, v in pairs(outfit.props or {}) do
        local id = tonumber(k)
        if id and id >= 0 and id <= 7 and type(v) == 'table' then props[tostring(id)] = { clampInt(v[1], -1, 999), clampInt(v[2], 0, 99) } end
    end
    g.outfit = g.outfit or {}
    g.outfit[sex] = { components = comps, props = props }
    saveGang(g)
    log(g, GANG.charName(p), 'outfit_saved', sex)
    return true
end)

lib.callback.register('exti_gangs:server:getOutfit', function(source, sex)
    local g = GANG.memberOf(source)
    if not g or not GANG.near(source, GANG.spot(g, 'locker'), 3.0) then return nil end
    return g.outfit and g.outfit[sex == 'female' and 'female' or 'male'] or nil
end)

---------------------------------------------------------------------------
-- the laptop data (each rank sees what it can use)
---------------------------------------------------------------------------
local function memberList(g)
    local list = {}
    for cid, mm in pairs(members) do
        if mm.gang == g.name then
            list[#list + 1] = {
                cid = cid, name = mm.name, rank = mm.rank, rankName = C.ranks[mm.rank].name, online = srcOf(cid) ~= nil,
                joined = mm.joined, lastSeen = mm.last_seen,
                partsToday = GANG.getDaily('m', cid, 'parts'), paidToday = GANG.getDaily('m', cid, 'paid'),
            }
        end
    end
    table.sort(list, function(a, b) if a.rank ~= b.rank then return a.rank > b.rank end return a.name < b.name end)
    return list
end

local function stashSummary(g)
    local out = {}
    local inv = exports.ox_inventory:GetInventoryItems(stashId(g)) or {}
    for _, it in pairs(inv) do
        if it and it.name then out[it.name] = (out[it.name] or 0) + (it.count or 0) end
    end
    return out
end
GANG.stashSummary = stashSummary

lib.callback.register('exti_gangs:server:laptop', function(source)
    local g, m, p = GANG.memberOf(source)
    if not g then return nil end
    if not GANG.near(source, GANG.spot(g, 'laptop'), 3.0) then return nil, 'far' end
    local lv, L, nextL = GANG.level(g)
    local t = C.types[g.type]
    local data = {
        me = { cid = m.citizenid, rank = m.rank, rankName = C.ranks[m.rank].name, name = m.name,
               partsToday = GANG.getDaily('m', m.citizenid, 'parts'), paidToday = GANG.getDaily('m', m.citizenid, 'paid'),
               collectWait = GANG.cooldownLeft('collect:' .. m.citizenid), memberDaily = C.collect.memberDaily },
        gang = { name = g.name, label = g.label, type = g.type, typeLabel = t.label, typeEn = t.en, color = g.color, tag = g.tag,
                 locked = g.locked, rentDue = g.rent_due, rent = GANG.rentFor(g), members = countMembers(g), maxMembers = C.maxMembers,
                 part = t.part, partPay = g.settings.partPay, deposits = g.settings.deposits },
        rep = { level = lv, name = L.name, xp = g.rep_xp, from = L.xp, to = nextL and nextL.xp or nil, levels = C.rep.levels },
        today = { parts = GANG.getDaily('g', g.name, 'parts'), partsCap = L.partsDaily },
        ranks = C.ranks, slots = { crew = C.rankSlots[1], underboss = C.rankSlots[2] }, colors = C.colors, now = now(),
        limits = { partPay = C.partPay, thief = C.chop.split.thief, chopper = C.chop.split.chopper, wash = C.wash.cut },
        ammoDaily = C.ammo.dailyRounds,
    }
    if m.rank >= 1 then
        data.gang.bank = g.bank
        data.stash = stashSummary(g)
        data.members = memberList(g)
    end
    if m.rank >= 2 then
        data.logs = MySQL.query.await('SELECT `actor`, `action`, `details`, `created` FROM `exti_gang_logs` WHERE `gang` = ? ORDER BY `id` DESC LIMIT 100', { g.name })
    end
    if m.rank == 3 then data.settings = g.settings end
    if g.type == 'chop' and GANG.chopView then data.chop = GANG.chopView(g, m) end
    if g.type == 'wash' and GANG.washView then data.wash = GANG.washView(g, m) end
    if GANG.turfView then data.turf = GANG.turfView(g) end
    if (g.type == 'ammo' or g.type == 'weapons') and GANG.craftView then data.craft = GANG.craftView(g) end
    if g.type == 'weed' and GANG.weedView then data.weed = GANG.weedView(g) end
    return data
end)

---------------------------------------------------------------------------
-- seen times, the weekly rent and absent leaders
---------------------------------------------------------------------------
local function seen(src)
    local cid = GANG.cid(src)
    local m = cid and members[cid]
    if not m then
        -- in one of our gangs in Qbox but not in our list (a failed kick): take him out
        local p = cid and GANG.player(src)
        local qg = p and p.PlayerData.gang and p.PlayerData.gang.name
        if qg and gangs[qg] then qbxRemove(cid, qg) end
        return
    end
    m.last_seen = now()
    MySQL.update('UPDATE `exti_gang_members` SET `last_seen` = ? WHERE `citizenid` = ?', { m.last_seen, cid })
    -- Qbox and our list must agree (an admin may have cleared the gang with a Qbox command)
    local p = GANG.player(src)
    local pg = p and p.PlayerData.gang
    if pg and (pg.name ~= m.gang or (pg.grade and pg.grade.level ~= m.rank)) then qbxSet(cid, m.gang, m.rank) end
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() seen(source) end)
AddEventHandler('playerDropped', function() seen(source); invites[source] = nil end)

CreateThread(function()
    while not GANG.ready do Wait(1000) end
    while true do
        local t = now()
        for _, g in pairs(gangs) do
            if g.rent_due <= t then tryRent(g) end
            -- the leader has been away too long: the longest-serving Underboss takes over
            local L = g.leader and members[g.leader]
            if L and srcOf(g.leader) == nil and t - (L.last_seen or t) > C.leaderInactiveDays * DAY then
                local best
                for cid, mm in pairs(members) do
                    if mm.gang == g.name and mm.rank == 2 and (not best or mm.joined < best.joined) then best = mm end
                end
                if best then
                    local old = g.leader
                    setMember(best.citizenid, g, 3)
                    setMember(old, g, stepDownRank(g, old))
                    g.leader = best.citizenid; saveGang(g)
                    log(g, 'النظام', 'leader_auto', ('الزعيم غائب %d يومًا: %s أصبح الزعيم'):format(C.leaderInactiveDays, best.name))
                end
            end
        end
        Wait(10 * 60 * 1000)
    end
end)

-- the gang list for every game (HQ spots, colours, tags) — no money or members in here
function GANG.publicList()
    local out = {}
    for name, g in pairs(gangs) do
        out[name] = { label = g.label, type = g.type, color = g.color, tag = g.tag, locked = g.locked }
    end
    return out
end
lib.callback.register('exti_gangs:server:myGang', function(source)
    local g, m = GANG.memberOf(source)
    return { gangs = GANG.publicList(), mine = g and { name = g.name, type = g.type, rank = m.rank, color = g.color, tag = g.tag, label = g.label, locked = g.locked } or nil }
end)

exports('GetMember', function(src) local g, m = GANG.memberOf(src); return g and { gang = g.name, label = g.label, type = g.type, rank = m.rank } or nil end)

---------------------------------------------------------------------------
-- deleted characters leave their gang (a deleted leader hands the gang to the highest rank,
-- the longest-serving first). Runs when a character is deleted and once at start for old ones.
---------------------------------------------------------------------------
local function dropDeleted(cid)
    local m = members[cid]
    if not m then return end
    if MySQL.scalar.await('SELECT 1 FROM `players` WHERE `citizenid` = ?', { cid }) then return end -- still exists
    local g = gangs[m.gang]
    if g and g.leader == cid then
        local best
        for c, mm in pairs(members) do
            if c ~= cid and mm.gang == g.name and (not best or mm.rank > best.rank or (mm.rank == best.rank and (mm.joined or 0) < (best.joined or 0))) then best = mm end
        end
        if best then
            setMember(best.citizenid, g, 3)
            g.leader = best.citizenid
            log(g, 'النظام', 'leader_auto', ('حُذفت شخصية الزعيم: %s أصبح الزعيم'):format(best.name))
            GANG.toGang(g, ('%s أصبح زعيم العصابة'):format(best.name), 'inform', 0)
        else
            g.leader = nil
        end
        saveGang(g)
    end
    removeMember(cid, nil, true)
    if g then log(g, 'النظام', 'left', ('شخصية محذوفة: %s'):format(m.name or '')) end
end

exports('RemoveDeletedCharacter', function(cid)
    if type(cid) ~= 'string' or not GANG.ready then return end
    dropDeleted(cid)
end)

CreateThread(function()
    while not GANG.ready do Wait(1000) end
    local gone = MySQL.query.await('SELECT m.`citizenid` FROM `exti_gang_members` m LEFT JOIN `players` p ON p.`citizenid` = m.`citizenid` WHERE p.`citizenid` IS NULL') or {}
    for i = 1, #gone do dropDeleted(gone[i].citizenid) end
    if #gone > 0 then lib.print.info(('removed %d deleted characters from gangs'):format(#gone)) end
end)
