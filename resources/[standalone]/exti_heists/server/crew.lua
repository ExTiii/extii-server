-- =====================================================================
-- EX_Tii heists: crews and the boards (the phone's Crew app).
--   * a crew: up to 6 characters, a leader who invites by phone number, kicks, hands over
--   * the heist board: every robbery, what it needs, and whether it can run right now
--   * the monthly boards: crews (Rep earned together), robbers, police (arrests, freed hostages);
--     on the 1st the top 3 of each get a title for the month (kept forever), and Discord hears it
-- =====================================================================
local C = Config
local CR = C.crew

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_crews` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(40) NOT NULL UNIQUE, `leader` VARCHAR(64) NOT NULL, `created` INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_crew_members` (
        `cid` VARCHAR(64) NOT NULL PRIMARY KEY, `crew_id` INT NOT NULL, `name` VARCHAR(80) NOT NULL, `joined` INT NOT NULL, INDEX `crew` (`crew_id`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_board` (
        `month` VARCHAR(7) NOT NULL, `kind` VARCHAR(8) NOT NULL, `k` VARCHAR(64) NOT NULL, `name` VARCHAR(80) NOT NULL, `points` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`month`, `kind`, `k`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_titles` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `cid` VARCHAR(64) NOT NULL, `title` VARCHAR(120) NOT NULL, `at` INT NOT NULL, INDEX `cid` (`cid`)
    ) DEFAULT CHARSET=utf8mb4]])
end)

local function month(t) return os.date('%Y-%m', t or os.time()) end
local function clean(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c<>"\'`\\]', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if s == '' or utf8.len(s) == nil then return nil end
    if utf8.len(s) > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

---------------------------------------------------------------------------
-- crew lookups
---------------------------------------------------------------------------
local function crewOf(cid)
    local r = cid and MySQL.single.await('SELECT m.`crew_id` AS id, c.`name`, c.`leader` FROM `exti_heist_crew_members` m JOIN `exti_heist_crews` c ON c.`id` = m.`crew_id` WHERE m.`cid` = ?', { cid })
    return r
end
H.crewOf = crewOf
local function members(crewId)
    return MySQL.query.await('SELECT `cid`, `name`, `joined` FROM `exti_heist_crew_members` WHERE `crew_id` = ? ORDER BY `joined`', { crewId }) or {}
end
local function srcOfCid(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    return ok and p and p.PlayerData.source or nil
end
local function srcOfPhone(phone)
    phone = tostring(phone or ''):gsub('%D', '')
    if phone == '' then return nil end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local mine = H.phoneOf(src)
        if mine and mine:gsub('%D', '') == phone then return src end
    end
end
-- the online members of a robber's crew (himself included)
function H.crewOnline(src)
    local c = crewOf(H.cid(src))
    if not c then return { src } end
    local out = {}
    for _, m in ipairs(members(c.id)) do local s = srcOfCid(m.cid); if s then out[#out + 1] = s end end
    return out
end

---------------------------------------------------------------------------
-- the boards
---------------------------------------------------------------------------
function H.boardAdd(kind, src, n)
    n = math.floor(n or 0); if n <= 0 then return end
    local cid = H.cid(src); if not cid then return end
    local m = month()
    local function add(k, key, name)
        MySQL.prepare('INSERT INTO `exti_heist_board` (`month`, `kind`, `k`, `name`, `points`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `points` = `points` + VALUES(`points`), `name` = VALUES(`name`)',
            { m, k, key, name, n })
    end
    if kind == 'cop' then add('cop', cid, H.name(src)) return end
    add('rob', cid, H.name(src))
    local c = crewOf(cid)
    if c then add('crew', tostring(c.id), c.name) end
end
local function top(kind, m, n)
    return MySQL.query.await('SELECT `k`, `name`, `points` FROM `exti_heist_board` WHERE `month` = ? AND `kind` = ? ORDER BY `points` DESC LIMIT ?', { m, kind, n or 10 }) or {}
end

-- the 1st of the month: titles for last month's top 3
local function awardMonth(m)
    local lines = {}
    local function give(cid, title)
        MySQL.insert.await('INSERT INTO `exti_heist_titles` (`cid`, `title`, `at`) VALUES (?, ?, ?)', { cid, title, os.time() })
        local s = srcOfCid(cid); if s then H.notify(s, ('لقب جديد: %s'):format(title), 'success', 10000) end
    end
    for i, r in ipairs(top('crew', m, 3)) do
        local title = ('%s · %s %s'):format(CR.titles.crew[i], r.name, m)
        for _, mb in ipairs(members(tonumber(r.k))) do give(mb.cid, title) end
        lines[#lines + 1] = ('طاقم %d: %s (%d)'):format(i, r.name, r.points)
    end
    for i, r in ipairs(top('rob', m, 3)) do give(r.k, ('%s · %s'):format(CR.titles.rob[i], m)); lines[#lines + 1] = ('لص %d: %s (%d)'):format(i, r.name, r.points) end
    for i, r in ipairs(top('cop', m, 3)) do give(r.k, ('%s · %s'):format(CR.titles.cop[i], m)); lines[#lines + 1] = ('شرطي %d: %s (%d)'):format(i, r.name, r.points) end
    H.log('board', 'month_winners', ('%s\n%s'):format(m, table.concat(lines, '\n')))
end
CreateThread(function()
    Wait(15000)
    while true do
        local done = GetResourceKvpString('board_awarded') or ''
        local last = month(os.time() - 86400 * (tonumber(os.date('%d')) + 0))   -- (any day of last month)
        if done ~= last and done ~= '' then awardMonth(last); SetResourceKvp('board_awarded', last)
        elseif done == '' then SetResourceKvp('board_awarded', last) end
        Wait(3600000)
    end
end)

---------------------------------------------------------------------------
-- the heist board: each robbery says what it needs and whether it can run now
---------------------------------------------------------------------------
H.heists = {}   -- { id, label, tier, where, status = function(src) return state, left, extra end }
function H.registerHeist(h) H.heists[#H.heists + 1] = h end

local function heistBoard(src)
    local lv = H.repLevel(src)
    local out = {}
    for _, h in ipairs(H.heists) do
        local need = math.ceil(h.tier * C.rep.leaderNeeds)
        local mode, copsNeed, counted = H.modeFor(h.tier)
        local st, left, note = 'ready', 0, nil
        if h.status then st, left, note = h.status(src) end
        if st == 'ready' and lv < need then st = 'rep' end
        if st == 'ready' and not mode then st = 'cops' end
        out[#out + 1] = { id = h.id, label = h.label, tier = h.tier, where = h.where, need = need, state = st, left = math.max(0, math.floor(left or 0)),
            note = note, police = mode and mode.police or false, copsNeed = copsNeed or (mode and mode.need) or 0, copsNow = counted or (mode and mode.counted) or 0 }
    end
    return out
end

---------------------------------------------------------------------------
-- invites (kept 10 minutes)
---------------------------------------------------------------------------
local invites = {}   -- [targetCid] = { [crewId] = { name, from, at } }

local function view(src)
    local r, cid = H.rec(src); if not r then return nil end
    for tc, list in pairs(invites) do
        for id, i in pairs(list) do if H.now() - i.at > 600 then list[id] = nil end end
        if not next(list) then invites[tc] = nil end
    end
    local lv = H.levelOf(r.xp)
    local c = crewOf(cid)
    local crew
    if c then
        local list = {}
        for _, m in ipairs(members(c.id)) do
            local s = srcOfCid(m.cid)
            list[#list + 1] = { cid = m.cid, name = m.name, online = s ~= nil, leader = m.cid == c.leader, me = m.cid == cid }
        end
        crew = { id = c.id, name = c.name, leader = c.leader == cid, members = list, max = CR.maxMembers }
    end
    local inv = {}
    for crewId, i in pairs(invites[cid] or {}) do
        if H.now() - i.at < 600 then inv[#inv + 1] = { id = crewId, name = i.name, from = i.from } end
    end
    local m = month()
    local titles = MySQL.query.await('SELECT `title` FROM `exti_heist_titles` WHERE `cid` = ? ORDER BY `id` DESC LIMIT 5', { cid }) or {}
    local tl = {}
    for _, t in ipairs(titles) do tl[#tl + 1] = t.title end
    local known = r.xp > 0 or GetResourceKvpInt('fencemet:' .. cid) == 1
    return {
        known = known,
        me = { name = H.name(src), level = lv, xp = r.xp, cur = C.rep.levels[lv], nextXp = C.rep.levels[lv + 1], maxLevel = #C.rep.levels,
               skills = { { id = 'lockpick', label = C.skills.lockpick.label, level = H.skillLevel(r, 'lockpick') },
                          { id = 'hacking', label = C.skills.hacking.label, level = H.skillLevel(r, 'hacking') },
                          { id = 'breaching', label = C.skills.breaching.label, level = H.skillLevel(r, 'breaching') } },
               heat = math.max(0, r.heat_until - H.now()), titles = tl, fence = known and C.fence.number or nil },
        crew = crew, invites = inv,
        heists = known and heistBoard(src) or {},
        board = { month = m, crews = top('crew', m, 10), robbers = top('rob', m, 10), cops = top('cop', m, 10) },
        cops = H.copsCounted(),
    }
end

local actions = {}
actions.get = function(src) return view(src) end

actions.create = function(src, d)
    local cid = H.cid(src); if not cid then return { ok = false } end
    if H.isCopOnDuty(src) then return { ok = false, error = 'cop' } end
    if crewOf(cid) then return { ok = false, error = 'in_crew' } end
    local name = clean(d and d.name, 24)
    if not name or utf8.len(name) < 3 then return { ok = false, error = 'name' } end
    if MySQL.scalar.await('SELECT `id` FROM `exti_heist_crews` WHERE `name` = ?', { name }) then return { ok = false, error = 'taken' } end
    local id = MySQL.insert.await('INSERT INTO `exti_heist_crews` (`name`, `leader`, `created`) VALUES (?, ?, ?)', { name, cid, H.now() })
    if not id then return { ok = false } end
    MySQL.insert.await('INSERT INTO `exti_heist_crew_members` (`cid`, `crew_id`, `name`, `joined`) VALUES (?, ?, ?, ?)', { cid, id, H.name(src), H.now() })
    H.log(src, 'crew_create', name)
    return { ok = true, data = view(src) }
end

actions.invite = function(src, d)
    local cid = H.cid(src)
    local c = crewOf(cid)
    if not c or c.leader ~= cid then return { ok = false, error = 'not_leader' } end
    if #members(c.id) >= CR.maxMembers then return { ok = false, error = 'full' } end
    local t = srcOfPhone(d and d.phone)
    if not t then return { ok = false, error = 'not_found' } end
    local tcid = H.cid(t)
    if not tcid or tcid == cid then return { ok = false, error = 'self' } end
    if crewOf(tcid) then return { ok = false, error = 'has_crew' } end
    invites[tcid] = invites[tcid] or {}
    invites[tcid][c.id] = { name = c.name, from = H.name(src), at = H.now() }
    pcall(function()
        exports.npwd:emitMessage({ senderNumber = C.fence.number, targetNumber = H.phoneOf(t),
            message = ('%s يريدك في طاقمه "%s". افتح تطبيق الطاقم لتقبل.'):format(H.name(src), c.name) })
    end)
    return { ok = true, name = H.name(t) }
end

actions.accept = function(src, d)
    local cid = H.cid(src)
    local id = math.tointeger(d and d.id)
    local inv = cid and id and invites[cid] and invites[cid][id]
    if not inv or H.now() - inv.at > 600 then return { ok = false, error = 'gone' } end
    if crewOf(cid) then return { ok = false, error = 'in_crew' } end
    if not MySQL.scalar.await('SELECT `id` FROM `exti_heist_crews` WHERE `id` = ?', { id }) then return { ok = false, error = 'gone' } end
    if #members(id) >= CR.maxMembers then return { ok = false, error = 'full' } end
    MySQL.insert.await('INSERT INTO `exti_heist_crew_members` (`cid`, `crew_id`, `name`, `joined`) VALUES (?, ?, ?, ?)', { cid, id, H.name(src), H.now() })
    invites[cid] = nil
    for _, m in ipairs(members(id)) do
        local s = srcOfCid(m.cid)
        if s and s ~= src then H.notify(s, ('انضم %s إلى الطاقم'):format(H.name(src)), 'success') end
    end
    H.log(src, 'crew_join', inv.name)
    return { ok = true, data = view(src) }
end

actions.decline = function(src, d)
    local cid = H.cid(src); local id = math.tointeger(d and d.id)
    if cid and id and invites[cid] then invites[cid][id] = nil end
    return { ok = true, data = view(src) }
end

local function leave(cid, crewId, leaderCid)
    MySQL.query.await('DELETE FROM `exti_heist_crew_members` WHERE `cid` = ?', { cid })
    local rest = members(crewId)
    if #rest == 0 then
        MySQL.query.await('DELETE FROM `exti_heist_crews` WHERE `id` = ?', { crewId })
    elseif leaderCid == cid then
        MySQL.update.await('UPDATE `exti_heist_crews` SET `leader` = ? WHERE `id` = ?', { rest[1].cid, crewId })
        local s = srcOfCid(rest[1].cid); if s then H.notify(s, 'أنت قائد الطاقم الآن', 'inform', 7000) end
    end
end

actions.leave = function(src)
    local cid = H.cid(src); local c = crewOf(cid)
    if not c then return { ok = false } end
    leave(cid, c.id, c.leader)
    H.log(src, 'crew_leave', c.name)
    return { ok = true, data = view(src) }
end

actions.kick = function(src, d)
    local cid = H.cid(src); local c = crewOf(cid)
    if not c or c.leader ~= cid then return { ok = false, error = 'not_leader' } end
    local who = type(d) == 'table' and tostring(d.cid or '') or ''
    local t = crewOf(who)
    if who == cid or not t or t.id ~= c.id then return { ok = false } end
    leave(who, c.id, c.leader)
    local s = srcOfCid(who); if s then H.notify(s, ('أُخرجت من طاقم "%s"'):format(c.name), 'error', 7000) end
    H.log(src, 'crew_kick', who)
    return { ok = true, data = view(src) }
end

actions.lead = function(src, d)
    local cid = H.cid(src); local c = crewOf(cid)
    if not c or c.leader ~= cid then return { ok = false, error = 'not_leader' } end
    local who = type(d) == 'table' and tostring(d.cid or '') or ''
    local t = crewOf(who)
    if not t or t.id ~= c.id or who == cid then return { ok = false } end
    MySQL.update.await('UPDATE `exti_heist_crews` SET `leader` = ? WHERE `id` = ?', { who, c.id })
    local s = srcOfCid(who); if s then H.notify(s, 'أنت قائد الطاقم الآن', 'inform', 7000) end
    return { ok = true, data = view(src) }
end

-- a waypoint to the fence from the app
actions.fence = function(src)
    local f = H.fenceSpot and H.fenceSpot()
    local cid = H.cid(src)
    if not f or not cid or GetResourceKvpInt('fencemet:' .. cid) ~= 1 then return { ok = false } end
    TriggerClientEvent('exti_heists:client:waypoint', src, { x = f.x, y = f.y, z = f.z })
    return { ok = true }
end

local last, cached = {}, {}
lib.callback.register('exti_heists:server:crew', function(src, action, data)
    local fn = actions[action]
    if not fn then return nil end
    if action == 'get' then
        -- (the app may ask often: once a second is plenty)
        local c = cached[src]
        if c and GetGameTimer() - c.at < 1000 then return c.v end
        local ok, v = pcall(fn, src, data)
        v = ok and v or nil
        cached[src] = { at = GetGameTimer(), v = v }
        return v
    else
        if (last[src] or 0) + 1 > H.now() then return { ok = false, error = 'slow' } end
        last[src] = H.now(); cached[src] = nil
    end
    local ok, res = pcall(fn, src, data)
    if not ok then lib.print.error(('[crew] %s: %s'):format(action, tostring(res))) return { ok = false } end
    return res
end)
AddEventHandler('playerDropped', function() last[source] = nil; cached[source] = nil end)

exports('CrewOf', function(src) local c = crewOf(H.cid(src)); return c and { id = c.id, name = c.name } or nil end)
