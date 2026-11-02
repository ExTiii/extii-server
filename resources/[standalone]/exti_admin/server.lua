-- =====================================================================
-- EX_Tii admin tablet (server). Every action is checked here (role + right) and logged.
-- =====================================================================
local ox = exports.ox_inventory
local started = os.time()
local staff = {}        -- [license] = { name, role }
local reports = {}      -- [id] = { id, src, name, text, at, status, by }
local nextReport = 0

local function getPlayer(src) local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end); return ok and p or nil end
local function charName(src)
    local p = getPlayer(src)
    local c = p and p.PlayerData.charinfo
    return c and ((c.firstname or '') .. ' ' .. (c.lastname or '')) or (GetPlayerName(src) or ('#' .. tostring(src)))
end
local function license(src) return GetPlayerIdentifierByType(src, 'license') end
local function notify(src, text, kind) TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform' }) end

---------------------------------------------------------------------------
-- database
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_admin_staff` (
        `license` VARCHAR(80) NOT NULL PRIMARY KEY, `name` VARCHAR(80), `role` VARCHAR(20) NOT NULL, `added_by` VARCHAR(80), `added_at` INT)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_admin_log` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `at` INT, `actor` VARCHAR(80), `actor_license` VARCHAR(80), `action` VARCHAR(40), `target` VARCHAR(120), `details` VARCHAR(400), KEY (`at`))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_admin_bans` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `license` VARCHAR(80), `license2` VARCHAR(80), `fivem` VARCHAR(60), `discord` VARCHAR(60),
        `name` VARCHAR(80), `reason` VARCHAR(300), `by` VARCHAR(80), `at` INT, `until` INT, `active` TINYINT NOT NULL DEFAULT 1, KEY (`license`))]])
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `exti_admin_staff`') or {}) do staff[r.license] = { name = r.name, role = r.role } end
end)

---------------------------------------------------------------------------
-- rights
---------------------------------------------------------------------------
local function roleOf(src)
    if src == 0 then return 'owner' end
    -- the owner: whoever server.cfg makes admin (group.admin gets the "command" ace; Qbox admin permission too)
    if IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'group.admin') then return 'owner' end
    local okP, isAdmin = pcall(function() return exports.qbx_core:HasPermission(src, 'admin') end)
    if okP and isAdmin then return 'owner' end
    local s = staff[license(src) or '']
    return s and Config.roles[s.role] and s.role or nil
end
local function can(src, right)
    local r = roleOf(src); if not r then return false end
    local c = Config.roles[r].can
    if c == '*' then return true end
    for _, v in ipairs(c) do if v == right then return true end end
    return false
end
local RANK = { helper = 1, admin = 2, owner = 3 }
-- staff can't use their powers on someone of the same or higher rank (an admin can't ban another admin)
local function outranks(src, t)
    if t == src then return true end
    return (RANK[roleOf(t)] or 0) < (RANK[roleOf(src)] or 0)
end
local function rightsOf(src)
    local r = roleOf(src); if not r then return nil end
    local c = Config.roles[r].can
    local out = {}
    if c == '*' then out['*'] = true else for _, v in ipairs(c) do out[v] = true end end
    return r, out
end

---------------------------------------------------------------------------
-- log (database + Discord if set: setr exti_admin_webhook "https://discord.com/api/webhooks/...")
---------------------------------------------------------------------------
local function log(src, action, target, details)
    local actor = src == 0 and 'الكونسول' or (GetPlayerName(src) or '?')
    MySQL.insert('INSERT INTO `exti_admin_log` (`at`, `actor`, `actor_license`, `action`, `target`, `details`) VALUES (?, ?, ?, ?, ?, ?)',
        { os.time(), actor, src ~= 0 and license(src) or 'console', action, target and tostring(target):sub(1, 120) or nil, details and tostring(details):sub(1, 400) or nil })
    local hook = GetConvar('exti_admin_webhook', '')
    if hook ~= '' then
        PerformHttpRequest(hook, function() end, 'POST', json.encode({ username = 'EX_Tii Admin', embeds = { {
            title = action, color = 15248711, description = ('**%s** → %s\n%s'):format(actor, target or '-', details or ''), timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } }),
            { ['Content-Type'] = 'application/json' })
    end
end

---------------------------------------------------------------------------
-- bans: checked when someone connects
---------------------------------------------------------------------------
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer(); Wait(0)
    deferrals.update('EX_Tii: التحقق من الحظر...')
    local ids = {}
    for _, t in ipairs({ 'license', 'license2', 'fivem', 'discord' }) do ids[t] = GetPlayerIdentifierByType(src, t) end
    local okQ, row = pcall(MySQL.single.await, [[SELECT * FROM `exti_admin_bans` WHERE `active` = 1 AND (`until` = 0 OR `until` > ?) AND
        ((`license` IS NOT NULL AND `license` = ?) OR (`license2` IS NOT NULL AND `license2` = ?) OR (`fivem` IS NOT NULL AND `fivem` = ?) OR (`discord` IS NOT NULL AND `discord` = ?)) LIMIT 1]],
        { os.time(), ids.license or '-', ids.license2 or '-', ids.fivem or '-', ids.discord or '-' })
    if not okQ then print('[exti_admin] ban check failed: ' .. tostring(row)); return deferrals.done() end
    if row then
        local untilTxt = row['until'] == 0 and 'دائم' or os.date('%Y-%m-%d %H:%M', row['until'])
        deferrals.done(('أنت محظور من EX_Tii Roleplay.\nالسبب: %s\nحتى: %s\nرقم الحظر: %d'):format(row.reason or '-', untilTxt, row.id))
    else
        deferrals.done()
    end
end)

---------------------------------------------------------------------------
-- reports: /report <text> (anyone)
---------------------------------------------------------------------------
local function staffOnline()
    local list = {}
    for _, id in ipairs(GetPlayers()) do local s = tonumber(id); if roleOf(s) and can(s, 'reports') then list[#list + 1] = s end end
    return list
end
local lastReport = {}
lib.addCommand('report', { help = 'أرسل بلاغًا للإدارة', params = { { name = 'text', type = 'longString', help = 'ما المشكلة؟' } } }, function(src, args)
    local text = tostring(args.text or ''):sub(1, 300)
    if #text < 3 then return notify(src, 'اكتب ما المشكلة', 'error') end
    if lastReport[src] and os.time() - lastReport[src] < 60 then return notify(src, 'انتظر دقيقة قبل بلاغ آخر', 'error') end
    local open = 0
    for _, r in pairs(reports) do if r.src == src and r.status == 'open' then open = open + 1 end end
    if open >= 3 then return notify(src, 'لديك 3 بلاغات مفتوحة: انتظر حتى تُعالج', 'error') end
    lastReport[src] = os.time()
    nextReport = nextReport + 1
    reports[nextReport] = { id = nextReport, src = src, name = charName(src) .. ' (' .. (GetPlayerName(src) or '') .. ')', text = text, at = os.time(), status = 'open' }
    notify(src, 'وصل بلاغك للإدارة، شكرًا', 'success')
    for _, s in ipairs(staffOnline()) do notify(s, ('بلاغ جديد #%d من %s: %s'):format(nextReport, GetPlayerName(src) or src, text), 'warning') end
end)
AddEventHandler('playerDropped', function()
    local src = source
    for _, r in pairs(reports) do if r.src == src and r.status == 'open' then r.left = true end end
end)

---------------------------------------------------------------------------
-- the tablet opens: who am I, what can I do
---------------------------------------------------------------------------
lib.callback.register('exti_admin:open', function(src)
    local role, rights = rightsOf(src)
    if not role then return false end
    local items = {}
    for name, it in pairs(ox:Items() or {}) do items[#items + 1] = { name = name, label = it.label or name } end
    table.sort(items, function(a, b) return a.label < b.label end)
    local jobs = {}
    local ok, J = pcall(function() return exports.qbx_core:GetJobs() end)
    for name, j in pairs(ok and J or {}) do
        local grades = {}
        for g, gd in pairs(j.grades or {}) do grades[#grades + 1] = { grade = tonumber(g), label = gd.name or gd.label or tostring(g) } end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        jobs[#jobs + 1] = { name = name, label = j.label or name, grades = grades }
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)
    local gangTypes = {}
    pcall(function() gangTypes = exports.exti_gangs:AdminTypes() end)
    return { role = role, roleLabel = Config.roles[role].label, rights = rights, me = src, items = items, jobs = jobs, gangTypes = gangTypes,
             kits = Config.kits, minigames = Config.minigames, cars = Config.cars, weathers = Config.weathers }
end)

-- the live lists (the tablet refreshes them while it's open)
lib.callback.register('exti_admin:players', function(src)
    if not can(src, 'view') then return false end
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local p = getPlayer(s)
        local ped = GetPlayerPed(s)
        local pd = p and p.PlayerData or {}
        local gm
        pcall(function() gm = exports.exti_gangs:GetMember(s) end)
        list[#list + 1] = {
            id = s, name = GetPlayerName(s), char = p and charName(s) or nil, cid = pd.citizenid,
            job = pd.job and (pd.job.label .. ' · ' .. ((pd.job.grade and pd.job.grade.name) or '')) or nil, duty = pd.job and pd.job.onduty or false,
            gang = gm and (gm.label or gm.gang) or nil, ping = GetPlayerPing(s), hp = ped ~= 0 and GetEntityHealth(ped) or 0,
            cash = pd.money and pd.money.cash or 0, bank = pd.money and pd.money.bank or 0, staff = roleOf(s),
            dead = pd.metadata and (pd.metadata.isdead or pd.metadata.inlaststand) or false,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

lib.callback.register('exti_admin:server', function(src)
    if not can(src, 'view') then return false end
    local open = {}
    for _, r in pairs(reports) do if r.status == 'open' then open[#open + 1] = r end end
    table.sort(open, function(a, b) return a.id > b.id end)
    local res = {}
    if can(src, 'resource') then
        for i = 0, GetNumResources() - 1 do
            local n = GetResourceByFindIndex(i)
            if n and n:sub(1, 1) ~= '_' then res[#res + 1] = { name = n, state = GetResourceState(n), locked = Config.noRestart[n] == true } end
        end
        table.sort(res, function(a, b) return a.name < b.name end)
    end
    return { players = #GetPlayers(), max = GetConvarInt('sv_maxclients', 48), uptime = os.time() - started, reports = open, resources = res,
             time = GlobalState.currentTime, weather = GlobalState.weather and GlobalState.weather.weather, frozen = GlobalState.freezeTime == true, blackout = GlobalState.blackOut == true }
end)

lib.callback.register('exti_admin:gangs', function(src)
    if not can(src, 'gangs') then return false end
    local ok, list = pcall(function() return exports.exti_gangs:AdminList() end)
    local ok2, places = pcall(function() return exports.exti_gangs:AdminPlaces() end)
    return { gangs = ok and list or {}, places = ok2 and places or {} }
end)

lib.callback.register('exti_admin:logs', function(src, q)
    if not can(src, 'logs') then return false end
    q = type(q) == 'string' and q:sub(1, 60) or ''
    if q ~= '' then
        local like = '%' .. q .. '%'
        return MySQL.query.await('SELECT * FROM `exti_admin_log` WHERE `actor` LIKE ? OR `action` LIKE ? OR `target` LIKE ? OR `details` LIKE ? ORDER BY `id` DESC LIMIT 200', { like, like, like, like }) or {}
    end
    return MySQL.query.await('SELECT * FROM `exti_admin_log` ORDER BY `id` DESC LIMIT 200') or {}
end)

lib.callback.register('exti_admin:bans', function(src)
    if not can(src, 'ban') then return false end
    return MySQL.query.await('SELECT `id`, `name`, `reason`, `by`, `at`, `until` FROM `exti_admin_bans` WHERE `active` = 1 AND (`until` = 0 OR `until` > ?) ORDER BY `id` DESC LIMIT 200', { os.time() }) or {}
end)

lib.callback.register('exti_admin:staff', function(src)
    if not can(src, 'staff') then return false end
    local out = {}
    for lic, s in pairs(staff) do
        local online
        for _, id in ipairs(GetPlayers()) do if license(tonumber(id)) == lic then online = tonumber(id) end end
        out[#out + 1] = { license = lic, name = s.name, role = s.role, roleLabel = Config.roles[s.role] and Config.roles[s.role].label or s.role, online = online }
    end
    return out
end)

---------------------------------------------------------------------------
-- actions: one door in, every one has its right
---------------------------------------------------------------------------
local function target(d)
    local t = math.tointeger(tonumber(d and d.id))
    if t and GetPlayerPing(t) > 0 then return t end
end
local function num(v, lo, hi) v = tonumber(v); if not v then return nil end; return math.max(lo, math.min(hi, math.floor(v))) end

local A = {}
A['goto'] = { 'goto', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    local c = GetEntityCoords(GetPlayerPed(t))
    log(src, 'goto', GetPlayerName(t))
    return true, nil, { x = c.x, y = c.y, z = c.z }
end }
A.bring = { 'bring', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    local c = GetEntityCoords(GetPlayerPed(src))
    TriggerClientEvent('exti_admin:client:moveTo', t, { x = c.x + 1.0, y = c.y, z = c.z })
    log(src, 'bring', GetPlayerName(t)); return true, 'جلبته إليك'
end }
A.spectate = { 'spectate', function(src, d)
    local t = target(d); if not t or t == src then return false, 'اختر لاعبًا آخر' end
    local c = GetEntityCoords(GetPlayerPed(t))
    log(src, 'spectate', GetPlayerName(t))
    return true, nil, { id = t, x = c.x, y = c.y, z = c.z }
end }
A.spectateFollow = { 'spectate', function(src, d)
    local t = target(d); if not t then return false end
    local c = GetEntityCoords(GetPlayerPed(t)); return true, nil, { x = c.x, y = c.y, z = c.z }
end }
A.freeze = { 'freeze', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    local on = d.on == true
    TriggerClientEvent('exti_admin:client:freeze', t, on)
    log(src, on and 'freeze' or 'unfreeze', GetPlayerName(t)); return true, on and 'جمّدته' or 'فككت التجميد'
end }
A.revive = { 'revive', function(src, d)
    local t = target(d) or (d.self and src); if not t then return false, 'اللاعب غير موجود' end
    pcall(function() exports.qbx_medical:Revive(t) end)
    pcall(function() exports.exti_medical:ClearWounds(t) end)
    TriggerClientEvent('exti_admin:client:heal', t)
    log(src, 'revive', GetPlayerName(t)); return true, 'أنعشته'
end }
A.heal = { 'heal', function(src, d)
    local t = target(d) or (d.self and src); if not t then return false, 'اللاعب غير موجود' end
    local p = getPlayer(t)
    if p then p.Functions.SetMetaData('hunger', 100); p.Functions.SetMetaData('thirst', 100); p.Functions.SetMetaData('stress', 0) end
    pcall(function() exports.exti_medical:ClearWounds(t) end)
    TriggerClientEvent('exti_admin:client:heal', t)
    log(src, 'heal', GetPlayerName(t)); return true, 'عالجته (صحة، أكل، شرب)'
end }
A.kick = { 'kick', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    if roleOf(t) == 'owner' then return false, 'لا يمكن طرد المالك' end
    local reason = tostring(d.reason or 'طرد من الإدارة'):sub(1, 200)
    log(src, 'kick', GetPlayerName(t), reason)
    DropPlayer(t, 'طُردت من EX_Tii Roleplay: ' .. reason); return true, 'طردته'
end }
A.ban = { 'ban', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    if roleOf(t) == 'owner' then return false, 'لا يمكن حظر المالك' end
    local hours = num(d.hours, 0, 24 * 365 * 5) or 0
    local reason = tostring(d.reason or 'مخالفة القوانين'):sub(1, 300)
    local untilT = hours == 0 and 0 or os.time() + hours * 3600
    local id = MySQL.insert.await('INSERT INTO `exti_admin_bans` (`license`, `license2`, `fivem`, `discord`, `name`, `reason`, `by`, `at`, `until`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { GetPlayerIdentifierByType(t, 'license'), GetPlayerIdentifierByType(t, 'license2'), GetPlayerIdentifierByType(t, 'fivem'), GetPlayerIdentifierByType(t, 'discord'),
          GetPlayerName(t), reason, GetPlayerName(src) or 'console', os.time(), untilT })
    log(src, 'ban', GetPlayerName(t), ('%s · %s'):format(hours == 0 and 'دائم' or (hours .. ' ساعة'), reason))
    DropPlayer(t, ('حُظرت من EX_Tii Roleplay (%s). السبب: %s · رقم الحظر %s'):format(hours == 0 and 'دائم' or (hours .. ' ساعة'), reason, tostring(id)))
    return true, 'حظرته'
end }
A.unban = { 'ban', function(src, d)
    local id = num(d.ban, 1, 2 ^ 31); if not id then return false end
    MySQL.update.await('UPDATE `exti_admin_bans` SET `active` = 0 WHERE `id` = ?', { id })
    log(src, 'unban', '#' .. id); return true, 'فككت الحظر'
end }
A.message = { 'message', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    local text = tostring(d.text or ''):sub(1, 300); if #text < 1 then return false, 'اكتب الرسالة' end
    TriggerClientEvent('exti_admin:client:message', t, text)
    log(src, 'message', GetPlayerName(t), text); return true, 'أرسلت'
end }
A.money = { 'money', function(src, d)
    local t = target(d) or (d.self and src); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    local p = getPlayer(t); if not p then return false, 'اللاعب لم يختر شخصيته بعد' end
    local acc = d.account == 'bank' and 'bank' or 'cash'
    local amount = num(d.amount, -100000000, 100000000); if not amount or amount == 0 then return false, 'اكتب المبلغ' end
    if amount > 0 then p.Functions.AddMoney(acc, amount, 'admin')
    elseif not p.Functions.RemoveMoney(acc, -amount, 'admin') then return false, 'ليس معه هذا المبلغ' end
    log(src, 'money', GetPlayerName(t), ('%s %+d'):format(acc, amount)); return true, 'تم'
end }
A.item = { 'item', function(src, d)
    local t = target(d) or (d.self and src); if not t then return false, 'اللاعب غير موجود' end
    local item = type(d.item) == 'string' and d.item or nil; if not item or not ox:Items(item) then return false, 'غرض غير معروف' end
    local count = num(d.count, 1, 100000) or 1
    if not ox:CanCarryItem(t, item, count) then return false, 'لا مكان في حقيبته' end
    local ok = ox:AddItem(t, item, count)
    if ok then log(src, 'item', GetPlayerName(t), ('%s × %d'):format(item, count)) end
    return ok and true or false, ok and 'أعطيته' or 'لم ينجح'
end }
A.clearinv = { 'item', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    ox:ClearInventory(t)
    log(src, 'clear_inventory', GetPlayerName(t)); return true, 'أفرغت حقيبته'
end }
A.inventory = { 'inventory', function(src, d)
    local t = target(d); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    ox:forceOpenInventory(src, 'player', t)
    log(src, 'inventory', GetPlayerName(t)); return true, nil, { close = true }
end }
A.job = { 'job', function(src, d)
    local t = target(d) or (d.self and src); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    local p = getPlayer(t); if not p then return false, 'لا شخصية' end
    local job, grade = tostring(d.job or 'unemployed'), num(d.grade, 0, 50) or 0
    local okJ, J = pcall(function() return exports.qbx_core:GetJobs() end)
    local jd = okJ and J and J[job]
    if not jd then return false, 'وظيفة غير معروفة' end
    if jd.grades and not (jd.grades[grade] or jd.grades[tostring(grade)]) then return false, 'رتبة غير موجودة في هذه الوظيفة' end
    local ok, res = pcall(function() return exports.qbx_core:SetJob(p.PlayerData.citizenid, job, grade) end)
    if not ok or res == false then ok, res = pcall(function() return p.Functions.SetJob(job, grade) end); ok = ok and res ~= false end
    if d.duty ~= nil then pcall(function() exports.qbx_core:SetJobDuty(t, d.duty == true) end) end
    log(src, 'job', GetPlayerName(t), ('%s %d'):format(job, grade)); return ok, ok and 'غيّرت وظيفته' or 'لم ينجح'
end }
A.setgang = { 'gang', function(src, d)
    local t = target(d) or (d.self and src); if not t then return false, 'اللاعب غير موجود' end
    if t and not outranks(src, t) then return false, 'لا تستطيع هذا على طاقم برتبة مثلك أو أعلى' end
    local ok, why = exports.exti_gangs:AdminSetMember(t, tostring(d.gang or ''), d.rank, GetPlayerName(src))
    if ok then log(src, 'set_gang', GetPlayerName(t), ('%s رتبة %s'):format(d.gang, tostring(d.rank))) end
    return ok, ok and 'وضعته في العصابة' or ('لم ينجح: ' .. tostring(why))
end }
A.kickgang = { 'gangs', function(src, d)
    local ok, why = exports.exti_gangs:AdminRemoveMember(tostring(d.cid or ''), GetPlayerName(src))
    if ok then log(src, 'gang_remove', d.cid) end
    return ok, ok and 'أخرجته من العصابة' or (why == 'leader' and 'هذا الزعيم: عيّن زعيمًا آخر أولًا' or 'لم ينجح')
end }

-- me & world
A.car = { 'car', function(src, d)
    local model = tostring(d.model or ''):lower():gsub('[^%w_]', '')
    if model == '' then return false, 'اكتب اسم السيارة' end
    local ok, netId, veh = pcall(function() return qbx.spawnVehicle({ model = model, spawnSource = GetPlayerPed(src), warp = GetPlayerPed(src) }) end)
    if not ok or not veh then return false, 'موديل غير صالح' end
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
    Entity(veh).state:set('fuel', 100.0, true)
    log(src, 'spawn_car', model); return true, 'تفضل', { close = true }
end }
A.time = { 'world', function(src, d)
    local h, m = num(d.hour, 0, 23), num(d.minute, 0, 59) or 0
    if h then GlobalState.currentTime = { hour = h, minute = m } end
    if d.freeze ~= nil then GlobalState.freezeTime = d.freeze == true end
    log(src, 'time', h and ('%02d:%02d'):format(h, m) or '-', d.freeze ~= nil and ('freeze=' .. tostring(d.freeze)) or nil); return true, 'تم'
end }
A.weather = { 'world', function(src, d)
    local w = tostring(d.weather or '')
    if d.auto then GlobalState.weather = { weather = (GlobalState.weather and GlobalState.weather.weather) or 'CLEAR', time = os.time() + 5 }
    else
        local okW = false
        for _, v in ipairs(Config.weathers) do if v == w then okW = true end end
        if not okW then return false, 'طقس غير معروف' end
        GlobalState.weather = { weather = w, time = 9999999999 }
    end
    log(src, 'weather', d.auto and 'auto' or w); return true, 'تم'
end }
A.blackout = { 'world', function(src, d)
    GlobalState.blackOut = d.on == true
    log(src, 'blackout', tostring(d.on)); return true, 'تم'
end }

-- server
A.announce = { 'announce', function(src, d)
    local text = tostring(d.text or ''):sub(1, 300); if #text < 2 then return false, 'اكتب الإعلان' end
    TriggerClientEvent('exti_admin:client:announce', -1, text, GetPlayerName(src))
    log(src, 'announce', 'الجميع', text); return true, 'نُشر الإعلان'
end }
A.report = { 'reports', function(src, d)
    local r = reports[num(d.report, 1, 2 ^ 31) or 0]; if not r then return false, 'البلاغ غير موجود' end
    if d.op == 'close' then
        r.status = 'closed'; r.by = GetPlayerName(src)
        if not r.left then notify(r.src, ('تم التعامل مع بلاغك #%d'):format(r.id), 'success') end
        log(src, 'report_close', '#' .. r.id, r.text); return true, 'أُغلق البلاغ'
    end
    if r.left then return false, 'صاحب البلاغ خرج' end
    local c = GetEntityCoords(GetPlayerPed(r.src))
    if d.op == 'goto' then log(src, 'report_goto', '#' .. r.id); return true, nil, { x = c.x, y = c.y, z = c.z } end
    if d.op == 'bring' then
        local me = GetEntityCoords(GetPlayerPed(src))
        TriggerClientEvent('exti_admin:client:moveTo', r.src, { x = me.x + 1.0, y = me.y, z = me.z })
        log(src, 'report_bring', '#' .. r.id); return true, 'جلبته'
    end
    return false
end }
A.resource = { 'resource', function(src, d)
    local n = tostring(d.name or '')
    if not n:match('^[%w_%-]+$') or GetResourceState(n) == 'missing' then return false, 'غير موجود' end
    if Config.noRestart[n] then return false, 'هذا المورد لا يُعاد تشغيله من هنا (يكسر السيرفر): استعمل Restart Server في txAdmin' end
    log(src, 'restart_resource', n)
    if GetResourceState(n) == 'started' then StopResource(n) end
    local ok = StartResource(n)
    return ok and true or false, ok and ('أُعيد تشغيل ' .. n) or ('لم يبدأ ' .. n .. ': انظر الكونسول في txAdmin')
end }

-- gangs
A.gangset = { 'gangs', function(src, d)
    local ok, why = exports.exti_gangs:AdminSet(tostring(d.gang or ''), tostring(d.field or ''), d.value, GetPlayerName(src))
    if ok then log(src, 'gang_set', d.gang, ('%s = %s'):format(d.field, tostring(d.value))) end
    return ok, ok and 'تم' or tostring(why)
end }
A.gangstash = { 'gangs', function(src, d)
    local ok, why = exports.exti_gangs:AdminGiveStash(tostring(d.gang or ''), d.item, d.count, GetPlayerName(src))
    if ok then log(src, 'gang_stash', d.gang, ('%s × %s'):format(tostring(d.item or 'parts'), tostring(d.count))) end
    return ok, ok and 'وضعته في مخزنها' or (why == 'stashfull' and 'المخزن ممتلئ' or tostring(why))
end }
A.gangcool = { 'gangs', function(src, d)
    if not d.gang or d.gang == '' then return false, 'اختر عصابة' end
    local n = exports.exti_gangs:AdminClearCooldowns(tostring(d.gang or ''), nil)
    log(src, 'gang_cooldowns', d.gang, tostring(n)); return true, ('أُزيلت %d مدة انتظار'):format(n)
end }
A.gangtags = { 'gangs', function(src, d)
    exports.exti_gangs:AdminClearTags(tostring(d.gang or ''))
    log(src, 'gang_tags_clear', d.gang); return true, 'مُسحت علاماتها'
end }
A.gangcreate = { 'gangs', function(src, d)
    local t = target(d); if not t then return false, 'اختر الزعيم من اللاعبين' end
    local name = tostring(d.name or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
    if name == '' then return false, 'اكتب اسمًا قصيرًا بالإنجليزية' end
    local label = tostring(d.label or ''):gsub('[%c]', ''):sub(1, 60)
    if label == '' then label = name end
    local kind = tostring(d.kind or ''):lower():gsub('[^%w]', '')
    local ok = exports.exti_gangs:AdminCreate(src, name, kind, t, label)
    if ok then log(src, 'gang_create', name, ('%s · leader %s'):format(kind, GetPlayerName(t))) end
    return ok, ok and 'أُنشئت العصابة' or 'لم تُنشأ (انظر الرسالة)'
end }
A.gangdelete = { 'gangs', function(src, d)
    local name = tostring(d.gang or ''):lower():gsub('[^%w_]', '')
    if name == '' then return false end
    local ok = exports.exti_gangs:AdminDelete(src, name)
    if ok then log(src, 'gang_delete', name) end
    return ok, ok and 'حُذفت' or 'لم تُحذف'
end }

-- tests (for me)
A.kit = { 'test', function(src, d)
    local k = Config.kits[num(d.kit, 1, #Config.kits) or 0]; if not k then return false end
    for _, it in ipairs(k.items) do if ox:Items(it[1]) then ox:AddItem(src, it[1], it[2]) end end
    log(src, 'test_kit', k.label); return true, 'أعطيتك ' .. k.label
end }
A.mycool = { 'test', function(src)
    local p = getPlayer(src); local cid = p and p.PlayerData.citizenid
    local gm; pcall(function() gm = exports.exti_gangs:GetMember(src) end)
    local n = 0
    pcall(function() n = exports.exti_gangs:AdminClearCooldowns(gm and gm.gang or nil, cid) end)
    log(src, 'test_cooldowns', tostring(n)); return true, ('أُزيلت %d مدة انتظار عنك وعن عصابتك'):format(n)
end }
A.fakecall = { 'test', function(src, d)
    local c = GetEntityCoords(GetPlayerPed(src))
    local kinds = { theft = 'سرقة سيارة (تجربة)', shots = 'إطلاق نار (تجربة)', call = 'بلاغ 911 (تجربة)' }
    local label = kinds[d.kind] or kinds.call
    pcall(function() exports.exti_police:AddCall({ kind = 'alarm', label = label, coords = c, text = 'تجربة من لوحة الإدارة' }) end)
    log(src, 'test_call', label); return true, 'أُرسل بلاغ تجربة للشرطة'
end }
A.copduty = { 'test', function(src, d)
    local p = getPlayer(src); if not p then return false end
    if d.on then
        local okJ, J = pcall(function() return exports.qbx_core:GetJobs() end)
        local top = 0
        for g in pairs(okJ and J.police and J.police.grades or {}) do top = math.max(top, tonumber(g) or 0) end
        pcall(function() exports.qbx_core:SetJob(p.PlayerData.citizenid, 'police', top) end)
        pcall(function() exports.qbx_core:SetJobDuty(src, true) end)
    else
        pcall(function() exports.qbx_core:SetJob(p.PlayerData.citizenid, 'unemployed', 0) end)
    end
    log(src, 'test_cop', tostring(d.on)); return true, d.on and 'أنت شرطي في الخدمة الآن' or 'رجعت مدنيًا'
end }

-- staff (owner)
A.staffadd = { 'staff', function(src, d)
    local t = target(d); if not t then return false, 'اختر لاعبًا' end
    local role = d.role == 'admin' and 'admin' or 'helper'
    local lic = license(t); if not lic then return false, 'لا رخصة' end
    staff[lic] = { name = GetPlayerName(t), role = role }
    MySQL.insert('INSERT INTO `exti_admin_staff` (`license`, `name`, `role`, `added_by`, `added_at`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `role` = VALUES(`role`), `name` = VALUES(`name`)',
        { lic, GetPlayerName(t), role, GetPlayerName(src), os.time() })
    notify(t, ('صرت %s في EX_Tii: اضغط %s لفتح لوحة الإدارة'):format(Config.roles[role].label, Config.key), 'success')
    log(src, 'staff_add', GetPlayerName(t), role); return true, 'أُضيف للطاقم'
end }
A.staffremove = { 'staff', function(src, d)
    local lic = tostring(d.license or ''); if not staff[lic] then return false end
    local name = staff[lic].name
    staff[lic] = nil
    MySQL.query('DELETE FROM `exti_admin_staff` WHERE `license` = ?', { lic })
    for _, id in ipairs(GetPlayers()) do if license(tonumber(id)) == lic then TriggerClientEvent('exti_admin:client:close', tonumber(id)) end end
    log(src, 'staff_remove', name); return true, 'أُزيل من الطاقم'
end }

lib.callback.register('exti_admin:do', function(src, action, d)
    local a = A[action]
    if not a then return false, 'أمر غير معروف' end
    if type(d) ~= 'table' then d = {} end
    if not can(src, a[1]) then return false, 'ليس لك هذا الحق' end
    local ok, res, msg, extra = pcall(a[2], src, d)
    if not ok then print(('[exti_admin] %s failed: %s'):format(action, tostring(res))); return false, 'خطأ في السيرفر' end
    return res, msg, extra
end)

-- the client asks before using powers on itself (noclip, god, invisible...): logged, checked
lib.callback.register('exti_admin:self', function(src, what, on)
    local need = ({ noclip = 'noclip', tp = 'tp', god = 'me', invisible = 'me', fix = 'car', delete = 'car', names = 'me' })[what]
    if not need or not can(src, need) then return false end
    log(src, 'self_' .. what, nil, on ~= nil and tostring(on) or nil)
    return true
end)
