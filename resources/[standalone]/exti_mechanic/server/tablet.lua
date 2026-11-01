-- =====================================================================
-- EX_Tii Mechanic (server): the mechanic tablet (like the video) — everything the apps read and
-- change goes through here and is checked here: on duty, the right person, the right rank.
--   Map (officers and team cars live), Chat (one-to-one and groups, photos, read receipts),
--   Calendar, Camera + Gallery (photos uploaded like the phone's camera), Settings (light / dark,
--   wallpaper), Form Inbox (server/forms.lua), Management for the leader (members, money, ranks,
--   log).
-- Every app callback is 'exti_mechanic:server:tab_<name>'.
-- =====================================================================

local JOB = Config.job

local getPlayer, isCop, onDuty, isBoss, grade, nameOf, notify = MEC.getPlayer, MEC.isCop, MEC.onDuty, MEC.isBoss, MEC.grade, MEC.nameOf, MEC.notify

local function cidOf(p) return p.PlayerData.citizenid end

local function decode(s)
    local ok, v = pcall(json.decode, s or '')
    return ok and v or nil
end

-- one line of text, no strange characters, at most max letters
local function cleanText(value, max, lines)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('\r\n?', '\n')
    value = lines and value:gsub('[\0-\9\11-\31\127]', '') or value:gsub('%c', ' ')
    value = value:gsub('\n\n\n+', '\n\n'):gsub('^%s+', ''):gsub('%s+$', '')
    local n = utf8.len(value)
    if not n then return nil end
    if n > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

-- a picture link: https only, a normal length, nothing that breaks out of a CSS url()
local function cleanUrl(url)
    if type(url) ~= 'string' or #url > 300 then return nil end
    if not url:match('^https://[%w%.%-]+/[%w%-%._~:/%%%?#%[%]@!%$&%*%+,;=]*$') then return nil end
    if url:find('[%(%)"\'\\%s]') then return nil end
    return url
end

-- a whole number from the tablet (or nil)
local function int(x)
    return type(x) == 'number' and math.tointeger(x) or nil
end

-- the first max letters (never cuts an Arabic letter in half)
local function cut(s, max)
    if type(s) ~= 'string' then return s end
    local n = utf8.len(s)
    if not n then return '' end
    if n <= max then return s end
    return s:sub(1, utf8.offset(s, max + 1) - 1) .. '…'
end

-- text shown in a notification: no links, pictures or big titles (the notification reads Markdown)
local function plain(s)
    return (tostring(s or ''):gsub('[%[%]%(%)!#%*_`<>|~\\]', ''):gsub('%s+', ' '))
end

local busy = {}
local function slow(src, key, ms)
    local now = GetGameTimer()
    busy[src] = busy[src] or {}
    if busy[src][key] and now - busy[src][key] < ms then return true end
    busy[src][key] = now
    return false
end
AddEventHandler('playerDropped', function() busy[source] = nil end)

---------------------------------------------------------------------------
-- database
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_settings` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `data` LONGTEXT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_gallery` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `url` VARCHAR(300) NOT NULL,
        `created` INT NOT NULL,
        INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_chats` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `kind` VARCHAR(8) NOT NULL,
        `name` VARCHAR(60) NULL,
        `photo` VARCHAR(300) NULL,
        `created_by` VARCHAR(50) NOT NULL,
        `created` INT NOT NULL,
        `last` INT NOT NULL DEFAULT 0
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_chat_members` (
        `chat_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `last_read` INT NOT NULL DEFAULT 0,
        `hidden` TINYINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`chat_id`, `citizenid`),
        INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_chat_messages` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `chat_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `text` TEXT NULL,
        `image` VARCHAR(300) NULL,
        `created` INT NOT NULL,
        INDEX `chat` (`chat_id`, `id`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_calendar` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(120) NOT NULL,
        `at` INT NOT NULL,
        `color` VARCHAR(10) NOT NULL,
        `created_by` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        INDEX `at` (`at`)
    ) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_mechanic_roles` (
        `grade` INT NOT NULL PRIMARY KEY,
        `name` VARCHAR(40) NOT NULL,
        `payment` INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4]])
end)

-- every app callback; the same one again within 0.2 s is ignored (no flooding the database)
local function cb(name, fn)
    local key = 'cb:' .. name
    lib.callback.register('exti_mechanic:server:tab_' .. name, function(source, ...)
        if slow(source, key, 200) then return false, 'wait' end
        return fn(source, ...)
    end)
end

-- every app needs the officer on duty
local function check(src)
    local player = getPlayer(src)
    if not onDuty(player) then return nil, 'off_duty' end
    return player
end

---------------------------------------------------------------------------
-- opening the tablet
---------------------------------------------------------------------------
local DEFAULT_SETTINGS = { mode = 'dark', wallpaper = '' }

local function settingsOf(cid)
    local row = MySQL.scalar.await('SELECT `data` FROM `exti_mechanic_settings` WHERE `citizenid` = ?', { cid })
    local s = decode(row) or {}
    return { mode = s.mode == 'light' and 'light' or 'dark', wallpaper = cleanUrl(s.wallpaper) or '' }
end

local function unreadChats(cid)
    local ok, n = pcall(function()
        return MySQL.scalar.await([[SELECT COUNT(*) FROM `exti_mechanic_chat_messages` m
            JOIN `exti_mechanic_chat_members` cm ON cm.chat_id = m.chat_id AND cm.citizenid = ? AND cm.hidden = 0
            WHERE m.id > cm.last_read AND m.citizenid <> ?]], { cid, cid })
    end)
    return ok and tonumber(n) or 0
end

cb('open', function(source)
    local player, err = check(source)
    if not player then return false, err end
    local cid = cidOf(player)
    local job = player.PlayerData.job
    return {
        me = { cid = cid, name = nameOf(player), grade = job.grade.level, gradeLabel = job.grade.name, isBoss = job.isboss == true },
        settings = settingsOf(cid),
        badges = { chat = unreadChats(cid), forms = MEC.newForms and MEC.newForms() or 0 },
        now = os.time(),
    }
end)

cb('badges', function(source)
    local player = check(source)
    if not player then return false end
    return { chat = unreadChats(cidOf(player)), forms = MEC.newForms and MEC.newForms() or 0, calls = MEC.openCalls and MEC.openCalls() or 0 }
end)

---------------------------------------------------------------------------
-- settings: light / dark and the wallpaper
---------------------------------------------------------------------------
cb('settingsSave', function(source, data)
    local player = check(source)
    if not player or type(data) ~= 'table' then return false end
    local s = { mode = data.mode == 'light' and 'light' or 'dark', wallpaper = '' }
    if data.wallpaper ~= nil and data.wallpaper ~= '' then
        s.wallpaper = cleanUrl(data.wallpaper)
        if not s.wallpaper then return false, 'bad_url' end
    end
    MySQL.prepare.await('INSERT INTO `exti_mechanic_settings` (`citizenid`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { cidOf(player), json.encode(s) })
    return s
end)

---------------------------------------------------------------------------
-- the map: officers on duty and the team's cars, live
---------------------------------------------------------------------------
cb('mapUnits', function(source)
    local player = check(source)
    if not player then return false end
    local staff = {}
    for _, src in ipairs(MEC.copsOnDuty()) do
        local p = getPlayer(src)
        local ped = GetPlayerPed(src)
        if p and ped ~= 0 then
            local c = GetEntityCoords(ped)
            staff[#staff + 1] = {
                id = src, name = nameOf(p), rank = p.PlayerData.job.grade.name,
                x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10,
                car = GetVehiclePedIsIn(ped, false) ~= 0, me = src == source,
            }
        end
    end
    table.sort(staff, function(a, b) return a.name < b.name end)
    return { staff = staff, vehicles = MEC.fleetOut and MEC.fleetOut() or {} }
end)

---------------------------------------------------------------------------
-- the gallery and the camera
---------------------------------------------------------------------------
local function galleryOf(cid)
    return MySQL.query.await('SELECT `id`, `url`, `created` FROM `exti_mechanic_gallery` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 120', { cid }) or {}
end

cb('gallery', function(source)
    local player = check(source)
    if not player then return false end
    return galleryOf(cidOf(player))
end)

cb('galleryDelete', function(source, id)
    local player = check(source)
    id = int(id)
    if not player or not id then return false end
    MySQL.update.await('DELETE FROM `exti_mechanic_gallery` WHERE `id` = ? AND `citizenid` = ?', { id, cidOf(player) })
    return galleryOf(cidOf(player))
end)

-- is this picture one of yours (only your own photos go in a chat)
local function ownPhoto(cid, url)
    url = cleanUrl(url)
    if not url then return nil end
    local found = MySQL.scalar.await('SELECT 1 FROM `exti_mechanic_gallery` WHERE `citizenid` = ? AND `url` = ? LIMIT 1', { cid, url })
    return found and url or nil
end

-- the photos are kept on this server, like the phone's (server/photos.js saves and shows them).
-- Only if the server has no public address yet, and a picture-service token is set, they go there.
local RES = GetCurrentResourceName()

local upload
do
    local raw = LoadResourceFile('npwd', 'config.json')
    local cfg = decode(raw) or {}
    local img = type(cfg.images) == 'table' and cfg.images or {}
    upload = {
        url = type(img.url) == 'string' and img.url or 'https://api.fivemanage.com/api/image',
        header = type(img.authorizationHeader) == 'string' and img.authorizationHeader or 'Authorization',
        prefix = type(img.authorizationPrefix) == 'string' and img.authorizationPrefix or '',
        field = type(img.type) == 'string' and img.type or 'image',
        index = type(img.returnedDataIndexes) == 'table' and img.returnedDataIndexes or { 'url' },
    }
end

local function urlFrom(response)
    if type(response) == 'string' then response = decode(response) or {} end
    if type(response) ~= 'table' then return nil end
    local v = response
    for _, key in ipairs(upload.index) do
        if type(v) ~= 'table' then return nil end
        v = v[key]
    end
    if type(v) ~= 'string' and type(response.data) == 'table' then v = response.data.url end
    return cleanUrl(v)
end

local function selfHosted()
    local ok, base = pcall(function() return exports[RES]:photoBase() end)
    return ok and type(base) == 'string' and base ~= ''
end

-- takes the picture of the player's screen: its link, or nil + why
local function capture(source)
    local p, done = promise.new(), false
    local function finish(url)
        if done then return end
        done = true
        p:resolve(url)
    end
    local ok
    if selfHosted() then
        ok = pcall(function()
            exports.screencapture:serverCapture(source, { encoding = 'webp', maxWidth = 1280, maxHeight = 720 }, function(data)
                local saved, url = pcall(function() return exports[RES]:savePhoto(data) end)
                finish(saved and url or nil)
            end, 'base64')
        end)
    else
        local token = GetConvar('SCREENSHOT_BASIC_TOKEN', '')
        if token == '' or token == 'none' then return nil, 'no_camera' end
        local headers = { [upload.header] = (upload.prefix ~= '' and (upload.prefix .. ' ') or '') .. token }
        ok = pcall(function()
            exports.screencapture:remoteUpload(source, upload.url, {
                encoding = 'webp', headers = headers, formField = upload.field, maxWidth = 1280, maxHeight = 720,
            }, function(response) finish(urlFrom(response)) end, 'blob')
        end)
    end
    if not ok then return nil, 'no_camera' end
    SetTimeout(20000, function() finish(nil) end)
    local url = cleanUrl(Citizen.Await(p))
    if not url then return nil, 'upload' end
    return url
end

cb('snap', function(source)
    local player, err = check(source)
    if not player then return false, err end
    if slow(source, 'snap', 4000) then return false, 'wait' end
    if GetResourceState('screencapture') ~= 'started' then return false, 'no_camera' end
    local url, why = capture(source)
    if not url then return false, why end
    local cid = cidOf(player)
    MySQL.insert.await('INSERT INTO `exti_mechanic_gallery` (`citizenid`, `url`, `created`) VALUES (?, ?, ?)', { cid, url, os.time() })
    lib.logger(source, 'mechanic', ('took a photo: %s'):format(url))
    return { url = url, gallery = galleryOf(cid) }
end)

---------------------------------------------------------------------------
-- chat (Staff Network)
---------------------------------------------------------------------------
local function members(chatId)
    return MySQL.query.await('SELECT `citizenid`, `last_read` FROM `exti_mechanic_chat_members` WHERE `chat_id` = ?', { chatId }) or {}
end

local function isMember(chatId, cid)
    return MySQL.scalar.await('SELECT `last_read` FROM `exti_mechanic_chat_members` WHERE `chat_id` = ? AND `citizenid` = ?', { chatId, cid })
end

-- names for a list of citizen ids (online first, the database for the rest)
local function namesOf(cids)
    local out, missing = {}, {}
    for _, cid in ipairs(cids) do
        local p = exports.qbx_core:GetPlayerByCitizenId(cid)
        if p then
            out[cid] = { name = nameOf(p), rank = p.PlayerData.job.name == JOB and p.PlayerData.job.grade.name or '', online = true }
        else
            missing[#missing + 1] = cid
        end
    end
    if #missing > 0 then
        local rows = MySQL.query.await(('SELECT `citizenid`, `charinfo`, `job` FROM `players` WHERE `citizenid` IN (%s)'):format(('?,'):rep(#missing):sub(1, -2)), missing) or {}
        for _, r in ipairs(rows) do
            local c = decode(r.charinfo) or {}
            local j = decode(r.job) or {}
            out[r.citizenid] = { name = ('%s %s'):format(c.firstname or '', c.lastname or ''), rank = j.name == JOB and j.grade and j.grade.name or '', online = false }
        end
    end
    return out
end

-- tell the members who are officers on duty right now (nobody else gets anything)
local function pushTo(chatId, event, ...)
    for _, m in ipairs(members(chatId)) do
        local p = exports.qbx_core:GetPlayerByCitizenId(m.citizenid)
        if p and onDuty(p) then TriggerClientEvent(event, p.PlayerData.source, chatId, ...) end
    end
end

local function chatList(cid)
    local rows = MySQL.query.await([[SELECT c.`id`, c.`kind`, c.`name`, c.`photo`, c.`last`, cm.`last_read`
        FROM `exti_mechanic_chats` c JOIN `exti_mechanic_chat_members` cm ON cm.chat_id = c.id AND cm.citizenid = ? AND cm.hidden = 0
        ORDER BY c.`last` DESC LIMIT 60]], { cid }) or {}
    local list, others = {}, {}
    for _, r in ipairs(rows) do
        local item = { id = r.id, kind = r.kind, name = r.name, photo = r.photo, last = r.last }
        local unread = MySQL.scalar.await('SELECT COUNT(*) FROM `exti_mechanic_chat_messages` WHERE `chat_id` = ? AND `id` > ? AND `citizenid` <> ?', { r.id, r.last_read, cid })
        item.unread = tonumber(unread) or 0
        local lastMsg = MySQL.single.await('SELECT `name`, `text`, `image` FROM `exti_mechanic_chat_messages` WHERE `chat_id` = ? ORDER BY `id` DESC LIMIT 1', { r.id })
        if lastMsg then item.preview = lastMsg.text and cut(lastMsg.text:gsub('%s+', ' '), 60) or (lastMsg.image and '📷') or '' end
        if r.kind == 'dm' then
            local other = MySQL.scalar.await('SELECT `citizenid` FROM `exti_mechanic_chat_members` WHERE `chat_id` = ? AND `citizenid` <> ? LIMIT 1', { r.id, cid })
            item.other = other
            if other then others[#others + 1] = other end
        else
            item.count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `exti_mechanic_chat_members` WHERE `chat_id` = ?', { r.id })) or 0
        end
        list[#list + 1] = item
    end
    local names = #others > 0 and namesOf(others) or {}
    for _, item in ipairs(list) do
        if item.kind == 'dm' then
            local n = names[item.other or ''] or {}
            item.name, item.rank, item.online = n.name or '—', n.rank, n.online
        end
    end
    return list
end

cb('chats', function(source)
    local player = check(source)
    if not player then return false end
    return chatList(cidOf(player))
end)

-- the member directory: everyone in the workshop
cb('chatDirectory', function(source)
    local player = check(source)
    if not player then return false end
    local ok, list = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    if not ok or type(list) ~= 'table' then list = {} end
    local cids = {}
    for _, m in ipairs(list) do cids[#cids + 1] = m.citizenid end
    local names = #cids > 0 and namesOf(cids) or {}
    local out = {}
    for _, m in ipairs(list) do
        if m.citizenid ~= cidOf(player) then
            local n = names[m.citizenid] or {}
            out[#out + 1] = { cid = m.citizenid, name = n.name or m.citizenid, rank = MEC.gradeName(m.grade), grade = m.grade, online = n.online == true }
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return out
end)

local function chatView(chatId, cid)
    local chat = MySQL.single.await('SELECT * FROM `exti_mechanic_chats` WHERE `id` = ?', { chatId })
    if not chat then return nil end
    local msgs = MySQL.query.await('SELECT * FROM `exti_mechanic_chat_messages` WHERE `chat_id` = ? ORDER BY `id` DESC LIMIT ?', { chatId, Config.chat.history or 100 }) or {}
    local list = {}
    for i = #msgs, 1, -1 do
        local m = msgs[i]
        list[#list + 1] = { id = m.id, cid = m.citizenid, name = m.name, text = m.text, image = m.image, at = m.created, mine = m.citizenid == cid }
    end
    local mem = members(chatId)
    local cids = {}
    for _, m in ipairs(mem) do cids[#cids + 1] = m.citizenid end
    local names = namesOf(cids)
    local people = {}
    for _, m in ipairs(mem) do
        local n = names[m.citizenid] or {}
        people[#people + 1] = { cid = m.citizenid, name = n.name or m.citizenid, rank = n.rank, online = n.online == true, lastRead = m.last_read, me = m.citizenid == cid }
    end
    local title, rank = chat.name, nil
    if chat.kind == 'dm' then
        for _, p in ipairs(people) do if not p.me then title, rank = p.name, p.rank end end
    end
    return { id = chat.id, kind = chat.kind, name = title, rank = rank, photo = chat.photo, owner = chat.created_by == cid, messages = list, people = people }
end

local function markRead(chatId, cid)
    local last = MySQL.scalar.await('SELECT MAX(`id`) FROM `exti_mechanic_chat_messages` WHERE `chat_id` = ?', { chatId })
    last = tonumber(last) or 0
    local was = tonumber(isMember(chatId, cid)) or 0
    if last > was then
        MySQL.update.await('UPDATE `exti_mechanic_chat_members` SET `last_read` = ? WHERE `chat_id` = ? AND `citizenid` = ?', { last, chatId, cid })
        pushTo(chatId, 'exti_mechanic:client:chatRead')
    end
end

cb('chatOpen', function(source, chatId)
    local player = check(source)
    chatId = int(chatId)
    if not player or not chatId then return false end
    local cid = cidOf(player)
    if not isMember(chatId, cid) then return false end
    markRead(chatId, cid)
    return chatView(chatId, cid)
end)

cb('chatSend', function(source, chatId, text, image)
    local player = check(source)
    chatId = int(chatId)
    if not player or not chatId then return false end
    local cid = cidOf(player)
    if not isMember(chatId, cid) then return false end
    if slow(source, 'chat', 600) then return false, 'wait' end
    text = text ~= nil and cleanText(text, Config.chat.maxText or 500, true) or nil
    if text == '' then text = nil end
    image = image ~= nil and image ~= '' and ownPhoto(cid, image) or nil
    if not text and not image then return false end
    local now = os.time()
    local name = nameOf(player)
    local id = MySQL.insert.await('INSERT INTO `exti_mechanic_chat_messages` (`chat_id`, `citizenid`, `name`, `text`, `image`, `created`) VALUES (?, ?, ?, ?, ?, ?)', { chatId, cid, name, text, image, now })
    if not id then return false end
    MySQL.update.await('UPDATE `exti_mechanic_chats` SET `last` = ? WHERE `id` = ?', { now, chatId })
    MySQL.update.await('UPDATE `exti_mechanic_chat_members` SET `hidden` = 0 WHERE `chat_id` = ?', { chatId })
    MySQL.update.await('UPDATE `exti_mechanic_chat_members` SET `last_read` = ? WHERE `chat_id` = ? AND `citizenid` = ?', { id, chatId, cid })
    pushTo(chatId, 'exti_mechanic:client:chatMessage', plain(name), text and cut(plain(text), 80) or '📷', cid)
    return chatView(chatId, cid)
end)

-- a one-to-one chat (the same one again if it already exists)
cb('chatStart', function(source, other)
    local player = check(source)
    if not player or type(other) ~= 'string' then return false end
    local cid = cidOf(player)
    if other == cid then return false end
    local member = false
    local ok, list = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    for _, m in ipairs(ok and list or {}) do if m.citizenid == other then member = true break end end
    if not member then return false end
    local found = MySQL.scalar.await([[SELECT c.id FROM `exti_mechanic_chats` c
        JOIN `exti_mechanic_chat_members` a ON a.chat_id = c.id AND a.citizenid = ?
        JOIN `exti_mechanic_chat_members` b ON b.chat_id = c.id AND b.citizenid = ?
        WHERE c.kind = 'dm' LIMIT 1]], { cid, other })
    if not found then
        if slow(source, 'newchat', 2000) then return false, 'wait' end
        found = MySQL.insert.await('INSERT INTO `exti_mechanic_chats` (`kind`, `created_by`, `created`, `last`) VALUES (?, ?, ?, ?)', { 'dm', cid, os.time(), os.time() })
        if not found then return false end
        MySQL.insert.await('INSERT INTO `exti_mechanic_chat_members` (`chat_id`, `citizenid`) VALUES (?, ?), (?, ?)', { found, cid, found, other })
    else
        MySQL.update.await('UPDATE `exti_mechanic_chat_members` SET `hidden` = 0 WHERE `chat_id` = ? AND `citizenid` = ?', { found, cid })
    end
    return { id = found, list = chatList(cid), chat = chatView(found, cid) }
end)

-- a group: a name, a photo from your gallery, and the members
cb('chatGroup', function(source, data)
    local player = check(source)
    if not player or type(data) ~= 'table' or type(data.members) ~= 'table' then return false end
    local cid = cidOf(player)
    if slow(source, 'newchat', 2000) then return false, 'wait' end
    local name = cleanText(data.name, 40)
    if not name or utf8.len(name) < 2 then return false, 'name' end
    local photo = data.photo and data.photo ~= '' and ownPhoto(cid, data.photo) or nil
    local valid = {}
    local ok, list = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    for _, m in ipairs(ok and list or {}) do valid[m.citizenid] = true end
    local chosen, seen = { cid }, { [cid] = true }
    for _, m in ipairs(data.members) do
        if type(m) == 'string' and valid[m] and not seen[m] and #chosen < 40 then seen[m] = true chosen[#chosen + 1] = m end
    end
    if #chosen < 2 then return false, 'members' end
    local id = MySQL.insert.await('INSERT INTO `exti_mechanic_chats` (`kind`, `name`, `photo`, `created_by`, `created`, `last`) VALUES (?, ?, ?, ?, ?, ?)', { 'group', name, photo, cid, os.time(), os.time() })
    if not id then return false end
    for _, m in ipairs(chosen) do
        MySQL.insert.await('INSERT INTO `exti_mechanic_chat_members` (`chat_id`, `citizenid`) VALUES (?, ?)', { id, m })
    end
    pushTo(id, 'exti_mechanic:client:chatMessage', plain(nameOf(player)), ('أضافك إلى %s'):format(plain(name)), cid)
    return { id = id, list = chatList(cid), chat = chatView(id, cid) }
end)

cb('chatLeave', function(source, chatId)
    local player = check(source)
    chatId = int(chatId)
    if not player or not chatId then return false end
    local cid = cidOf(player)
    local kind = MySQL.scalar.await('SELECT `kind` FROM `exti_mechanic_chats` WHERE `id` = ?', { chatId })
    if kind == 'dm' then
        -- a private line is only hidden from your list: it comes back with the next message
        MySQL.update.await('UPDATE `exti_mechanic_chat_members` SET `hidden` = 1 WHERE `chat_id` = ? AND `citizenid` = ?', { chatId, cid })
    else
        MySQL.update.await('DELETE FROM `exti_mechanic_chat_members` WHERE `chat_id` = ? AND `citizenid` = ?', { chatId, cid })
        local left = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `exti_mechanic_chat_members` WHERE `chat_id` = ?', { chatId })) or 0
        if left == 0 then
            MySQL.update.await('DELETE FROM `exti_mechanic_chat_messages` WHERE `chat_id` = ?', { chatId })
            MySQL.update.await('DELETE FROM `exti_mechanic_chats` WHERE `id` = ?', { chatId })
        end
    end
    return chatList(cid)
end)

-- someone left the workshop (fired, quit, a new job): out of every chat, and chats with nobody
-- left are deleted. (A private line stays for the other officer, with the old messages.)
function MEC.leftPolice(cid)
    if type(cid) ~= 'string' then return end
    MySQL.update.await('DELETE FROM `exti_mechanic_chat_members` WHERE `citizenid` = ?', { cid })
    MySQL.update.await([[DELETE c FROM `exti_mechanic_chats` c LEFT JOIN `exti_mechanic_chat_members` m ON m.chat_id = c.id WHERE m.chat_id IS NULL]])
    MySQL.update.await([[DELETE msg FROM `exti_mechanic_chat_messages` msg LEFT JOIN `exti_mechanic_chats` c ON c.id = msg.chat_id WHERE c.id IS NULL]])
end

---------------------------------------------------------------------------
-- calendar (Staff Schedule)
---------------------------------------------------------------------------
local COLORS = {}
for _, c in ipairs(Config.calendarColors or {}) do COLORS[c] = true end

cb('calendar', function(source, from, to)
    local player = check(source)
    from, to = int(from), int(to)
    if not player or not from or not to or to < from or to - from > 3600 * 24 * 45 then return false end
    local rows = MySQL.query.await('SELECT `id`, `title`, `at`, `color`, `name`, `created_by` FROM `exti_mechanic_calendar` WHERE `at` >= ? AND `at` < ? ORDER BY `at` LIMIT 400', { from, to }) or {}
    local cid = cidOf(player)
    for _, r in ipairs(rows) do
        r.mine = r.created_by == cid
        r.created_by = nil
    end
    return rows
end)

cb('calendarAdd', function(source, data)
    local player = check(source)
    if not player or type(data) ~= 'table' then return false end
    if slow(source, 'cal', 1500) then return false, 'wait' end
    local title = cleanText(data.title, 80)
    local at = int(data.at)
    if not title or utf8.len(title) < 2 then return false, 'title' end
    if not at or math.abs(at - os.time()) > 3600 * 24 * 400 then return false, 'date' end
    local color = COLORS[data.color] and data.color or (Config.calendarColors or { '#3b8cf0' })[1]
    MySQL.insert.await('INSERT INTO `exti_mechanic_calendar` (`title`, `at`, `color`, `created_by`, `name`) VALUES (?, ?, ?, ?, ?)', { title, at, color, cidOf(player), nameOf(player) })
    MEC.log(source, 'calendar_added', title)
    return true
end)

cb('calendarDelete', function(source, id)
    local player = check(source)
    id = int(id)
    if not player or not id then return false end
    if isBoss(player) then
        MySQL.update.await('DELETE FROM `exti_mechanic_calendar` WHERE `id` = ?', { id })
    else
        MySQL.update.await('DELETE FROM `exti_mechanic_calendar` WHERE `id` = ? AND `created_by` = ?', { id, cidOf(player) })
    end
    return true
end)

---------------------------------------------------------------------------
-- Management (the leader): dashboard, cash flow, funds, members, roles, logs
---------------------------------------------------------------------------
local function bossCheck(src)
    local player, err = check(src)
    if not player then return nil, err end
    if not isBoss(player) then return nil, 'not_boss' end
    return player
end

local function balance()
    local ok, money = pcall(function() return exports['Renewed-Banking']:getAccountMoney(JOB) end)
    return ok and tonumber(money) or 0
end

local function startOfWeek(now)
    local t = os.date('*t', now)
    local back = (t.wday + 5) % 7
    return os.time({ year = t.year, month = t.month, day = t.day - back, hour = 0, min = 0, sec = 0 })
end

-- minutes worked this week by everyone (finished shifts + the shifts running now)
local function weekMinutes()
    local out = {}
    local rows = MySQL.query.await('SELECT `citizenid`, SUM(`minutes`) AS m FROM `exti_mechanic_shifts` WHERE `ended` >= ? GROUP BY `citizenid`', { startOfWeek(os.time()) }) or {}
    for _, r in ipairs(rows) do out[r.citizenid] = tonumber(r.m) or 0 end
    for _, s in pairs(MEC.shifts) do
        if s.cid then out[s.cid] = (out[s.cid] or 0) + math.floor((os.time() - s.start) / 60) end
    end
    return out
end

local function roster()
    local ok, list = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    if not ok or type(list) ~= 'table' then list = {} end
    local cids = {}
    for _, m in ipairs(list) do cids[#cids + 1] = m.citizenid end
    local names = #cids > 0 and namesOf(cids) or {}
    local lastSeen = {}
    if #cids > 0 then
        local ok, rows = pcall(function()
            return MySQL.query.await(('SELECT `citizenid`, UNIX_TIMESTAMP(`last_updated`) AS t FROM `players` WHERE `citizenid` IN (%s)'):format(('?,'):rep(#cids):sub(1, -2)), cids)
        end)
        for _, r in ipairs(ok and rows or {}) do lastSeen[r.citizenid] = tonumber(r.t) end
    end
    local week = weekMinutes()
    local out = {}
    for _, m in ipairs(list) do
        local n = names[m.citizenid] or {}
        local online = exports.qbx_core:GetPlayerByCitizenId(m.citizenid)
        out[#out + 1] = {
            cid = m.citizenid, name = n.name or m.citizenid, grade = m.grade, rank = MEC.gradeName(m.grade),
            online = online ~= nil, onDuty = online ~= nil and online.PlayerData.job.name == JOB and online.PlayerData.job.onduty == true,
            lastSeen = online and os.time() or lastSeen[m.citizenid], hours = math.floor((week[m.citizenid] or 0) / 6 + 0.5) / 10,
        }
    end
    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    return out
end

local function gradesView()
    local ok, job = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    local list = {}
    if ok and job and job.grades then
        for g = 0, 20 do
            local d = job.grades[g]
            if not d then break end
            list[#list + 1] = { grade = g, name = d.name, payment = d.payment or 0, boss = d.isboss == true }
        end
    end
    return list
end

cb('bossDashboard', function(source)
    local player, err = bossCheck(source)
    if not player then return false, err end
    local list = roster()
    local onDutyList, offDutyList, active = {}, {}, {}
    for _, m in ipairs(list) do
        if m.onDuty then onDutyList[#onDutyList + 1] = m.name elseif m.online then offDutyList[#offDutyList + 1] = m.name end
        if m.hours > 0 then active[#active + 1] = { name = m.name, hours = m.hours } end
    end
    table.sort(active, function(a, b) return a.hours > b.hours end)
    while #active > 5 do table.remove(active) end
    return { funds = balance(), onDuty = onDutyList, offDuty = offDutyList, active = active, members = #list }
end)

-- money in / out of the workshop account for the last 14 days (from the department log)
cb('bossCashFlow', function(source)
    local player, err = bossCheck(source)
    if not player then return false, err end
    local since = os.time() - 14 * 86400
    local rows = MySQL.query.await("SELECT `at`, `action`, `amount`, `money` FROM `exti_mechanic_logs` WHERE `at` >= ? AND `money` IS NOT NULL AND `amount` IS NOT NULL", { since }) or {}
    local days, inCat, outCat = {}, {}, {}
    local revenue, expenses = 0, 0
    for i = 13, 0, -1 do
        local t = os.date('*t', os.time() - i * 86400)
        days[#days + 1] = { day = ('%02d/%02d'):format(t.day, t.month), key = ('%d-%d-%d'):format(t.year, t.month, t.day), rev = 0, exp = 0 }
    end
    local index = {}
    for i, d in ipairs(days) do index[d.key] = i end
    for _, r in ipairs(rows) do
        local t = os.date('*t', r.at)
        local d = days[index[('%d-%d-%d'):format(t.year, t.month, t.day)] or 0]
        local amount = tonumber(r.amount) or 0
        if r.money == 'in' then
            revenue = revenue + amount
            inCat[r.action] = (inCat[r.action] or 0) + amount
            if d then d.rev = d.rev + amount end
        elseif r.money == 'out' then
            expenses = expenses + amount
            outCat[r.action] = (outCat[r.action] or 0) + amount
            if d then d.exp = d.exp + amount end
        end
    end
    local function cats(t)
        local l = {}
        for k, v in pairs(t) do l[#l + 1] = { action = k, amount = v } end
        table.sort(l, function(a, b) return a.amount > b.amount end)
        return l
    end
    return { revenue = revenue, expenses = expenses, profit = revenue - expenses, days = days, inCat = cats(inCat), outCat = cats(outCat) }
end)

cb('bossFunds', function(source)
    local player, err = bossCheck(source)
    if not player then return false, err end
    local rows = MySQL.query.await("SELECT `at`, `name`, `action`, `content`, `amount`, `money` FROM `exti_mechanic_logs` WHERE `money` IS NOT NULL ORDER BY `id` DESC LIMIT 40") or {}
    return { balance = balance(), recent = rows }
end)

local function moneyMove(source, amount, deposit)
    local player, err = bossCheck(source)
    if not player then return false, err end
    amount = int(amount)
    if not amount or amount < 1 or amount > 10000000 then return false, 'amount' end
    if slow(source, 'money', 1500) then return false, 'wait' end
    local name = nameOf(player)
    if deposit then
        if (player.PlayerData.money.bank or 0) < amount then return false, 'no_money_me' end
        if not player.Functions.RemoveMoney('bank', amount, 'mechanic-deposit') then return false, 'no_money_me' end
        local ok, added = pcall(function() return exports['Renewed-Banking']:addAccountMoney(JOB, amount) end)
        if not ok or added == false then player.Functions.AddMoney('bank', amount, 'mechanic-deposit-refund') return false, 'failed' end
        pcall(function() exports['Renewed-Banking']:handleTransaction(JOB, 'إيداع', amount, 'إيداع من المدير', name, 'EX MOTORS', 'deposit') end)
        MEC.log(source, 'money_deposited', nil, amount, 'in')
    else
        local okPay, paid = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(JOB, amount) end)
        if not okPay or not paid then return false, 'no_money' end
        pcall(function() exports['Renewed-Banking']:handleTransaction(JOB, 'سحب', amount, 'سحب إلى حساب المدير', 'EX MOTORS', name, 'withdraw') end)
        player.Functions.AddMoney('bank', amount, 'mechanic-withdraw')
        MEC.log(source, 'money_withdrawn', nil, amount, 'out')
    end
    lib.logger(source, 'mechanic', ('%s $%d %s the workshop account'):format(deposit and 'deposited' or 'withdrew', amount, deposit and 'into' or 'from'))
    return true
end

cb('bossDeposit', function(source, amount) return moneyMove(source, amount, true) end)
cb('bossWithdraw', function(source, amount) return moneyMove(source, amount, false) end)

cb('bossMembers', function(source)
    local player, err = bossCheck(source)
    if not player then return false, err end
    return { members = roster(), grades = gradesView(), me = cidOf(player), myGrade = grade(player) }
end)

-- a member the leader may change: not yourself, someone below your rank
local function memberCheck(source, cid)
    local player, err = bossCheck(source)
    if not player then return nil, err end
    if type(cid) ~= 'string' or cid == cidOf(player) then return nil, 'failed' end
    local ok, list = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    for _, m in ipairs(ok and list or {}) do
        if m.citizenid == cid then
            if m.grade >= grade(player) then return nil, 'rank' end
            m.name = (namesOf({ cid })[cid] or {}).name or cid
            return player, m
        end
    end
    return nil, 'failed'
end

cb('bossSetGrade', function(source, cid, newGrade)
    local player, member = memberCheck(source, cid)
    if not player then return false, member end
    newGrade = int(newGrade)
    if not newGrade or newGrade < 0 or newGrade >= grade(player) then return false, 'rank' end
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    local wasOn = online and online.PlayerData.job.name == JOB and online.PlayerData.job.onduty == true
    if not exports.qbx_core:AddPlayerToJob(cid, JOB, newGrade) then return false, 'failed' end
    -- a new rank rebuilds the job (on duty by itself on this server): keep the duty as it was
    if online and online.PlayerData.job.name == JOB then exports.qbx_core:SetJobDuty(online.PlayerData.source, wasOn == true) end
    if online then notify(online.PlayerData.source, 'inform', ('رتبتك في الورشة الآن: %s'):format(plain(MEC.gradeName(newGrade)))) end
    MEC.log(source, newGrade > member.grade and 'promoted' or 'demoted', ('%s: %s → %s'):format(member.name, MEC.gradeName(member.grade), MEC.gradeName(newGrade)))
    return true
end)

cb('bossFire', function(source, cid)
    local player, member = memberCheck(source, cid)
    if not player then return false, member end
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online and online.PlayerData.job.name == JOB then
        online.Functions.SetJob('unemployed', 0)
        notify(online.PlayerData.source, 'error', 'أُنهيت خدمتك في الورشة')
    else
        exports.qbx_core:RemovePlayerFromJob(cid, JOB)
    end
    MEC.leftPolice(cid)
    MEC.log(source, 'fired', ('%s · %s'):format(member.name, MEC.gradeName(member.grade)))
    return true
end)

-- a bonus goes to any member of the workshop (not to yourself)
cb('bossBonus', function(source, cid, amount)
    local player, err = bossCheck(source)
    if not player then return false, err end
    if type(cid) ~= 'string' or cid == cidOf(player) then return false, 'failed' end
    local member
    local okList, list = pcall(function() return exports.qbx_core:GetGroupMembers(JOB, 'job') end)
    for _, m in ipairs(okList and list or {}) do if m.citizenid == cid then member = m break end end
    if not member then return false, 'failed' end
    local memberName = (namesOf({ cid })[cid] or {}).name or cid
    amount = int(amount)
    if not amount or amount < 1 or amount > (Config.bonusMax or 50000) then return false, 'amount' end
    if slow(source, 'money', 1500) then return false, 'wait' end
    local okPay, paid = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(JOB, amount) end)
    if not okPay or not paid then return false, 'no_money' end
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online then
        online.Functions.AddMoney('bank', amount, 'mechanic-bonus')
        notify(online.PlayerData.source, 'success', ('حصلت على مكافأة من الورشة: $%d'):format(amount))
    else
        local ok, added = pcall(function() return exports.qbx_core:AddMoney(cid, 'bank', amount, 'mechanic-bonus') end)
        if not ok or not added then pcall(function() exports['Renewed-Banking']:addAccountMoney(JOB, amount) end) return false, 'failed' end
    end
    pcall(function() exports['Renewed-Banking']:handleTransaction(JOB, 'مكافأة', amount, ('مكافأة لـ %s'):format(memberName), nameOf(player), memberName, 'withdraw') end)
    MEC.log(source, 'bonus_paid', memberName, amount, 'out')
    return true
end)

-- hiring: the leader invites someone standing near them; they say yes on their screen
local invites = {} -- [target source] = { from, grade, until }

cb('bossNearby', function(source)
    local player, err = bossCheck(source)
    if not player then return false, err end
    local me = GetEntityCoords(GetPlayerPed(source))
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local p = id ~= source and getPlayer(id)
        local ped = GetPlayerPed(id)
        if p and not isCop(p) and ped ~= 0 and #(GetEntityCoords(ped) - me) < 8.0 then
            out[#out + 1] = { id = id, name = nameOf(p) }
        end
    end
    return out
end)

cb('bossInvite', function(source, target, newGrade)
    local player, err = bossCheck(source)
    if not player then return false, err end
    target = int(target)
    newGrade = int(newGrade)
    local t = target and getPlayer(target)
    if not t or isCop(t) then return false, 'failed' end
    if not newGrade or newGrade < 0 or newGrade >= grade(player) then return false, 'rank' end
    local a, b = GetPlayerPed(source), GetPlayerPed(target)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > 8.0 then return false, 'too_far' end
    if slow(source, 'invite', 3000) then return false, 'wait' end
    invites[target] = { from = source, grade = newGrade, ['until'] = os.time() + 60 }
    TriggerClientEvent('exti_mechanic:client:invite', target, nameOf(player), MEC.gradeName(newGrade))
    return true
end)

lib.callback.register('exti_mechanic:server:inviteAnswer', function(source, yes)
    local inv = invites[source]
    invites[source] = nil
    if not inv or inv['until'] < os.time() then return false end
    local boss = getPlayer(inv.from)
    if not yes then
        if boss then notify(inv.from, 'inform', ('%s رفض الدعوة'):format(plain(nameOf(getPlayer(source))))) end
        return true
    end
    local player = getPlayer(source)
    if not player or isCop(player) or not boss or not isBoss(boss) then return false end
    local ok, done = pcall(function() return exports.qbx_core:SetJob(source, JOB, inv.grade) end)
    if not ok or not done then
        notify(inv.from, 'error', 'تعذّر التوظيف (ربما عنده وظيفة لا يمكن تركها)')
        return false
    end
    exports.qbx_core:SetJobDuty(source, false)
    notify(source, 'success', ('انضممت للورشة: %s. ابدأ مناوبتك من جهاز البطاقة في الورشة'):format(plain(MEC.gradeName(inv.grade))))
    notify(inv.from, 'success', ('انضم %s للورشة'):format(plain(nameOf(player))))
    MEC.log(inv.from, 'hired', ('%s (%s) · %s'):format(nameOf(player), player.PlayerData.citizenid, MEC.gradeName(inv.grade)))
    return true
end)

AddEventHandler('playerDropped', function() invites[source] = nil end)

-- ranks: the leader changes a rank's name and salary (for the ranks below the leader)
local function applyRoles()
    local rows = MySQL.query.await('SELECT * FROM `exti_mechanic_roles`') or {}
    local ok, job = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    if not ok or not job or not job.grades then return end
    for _, r in ipairs(rows) do
        local g = job.grades[r.grade]
        if g and not g.isboss then
            local data = {}
            for k, v in pairs(g) do data[k] = v end
            data.name, data.payment = r.name, r.payment
            pcall(function() exports.qbx_core:UpsertJobGrade(JOB, r.grade, data, false) end)
        end
    end
end
CreateThread(function()
    Wait(3000)
    pcall(applyRoles)
end)
AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'qbx_core' then SetTimeout(3000, function() pcall(applyRoles) end) end
end)

cb('bossRoles', function(source)
    local player, err = bossCheck(source)
    if not player then return false, err end
    return { grades = gradesView(), myGrade = grade(player), interval = 10 }
end)

cb('bossRoleSave', function(source, g, name, payment)
    local player, err = bossCheck(source)
    if not player then return false, err end
    g = int(g)
    payment = int(payment)
    name = cleanText(name, 24)
    if name then name = plain(name):gsub('^%s+', ''):gsub('%s+$', '') end
    if not g or g < 0 or g >= grade(player) then return false, 'rank' end
    if not name or utf8.len(name) < 2 then return false, 'name' end
    if not payment or payment < 0 or payment > (Config.salaryMax or 1000) then return false, 'amount' end
    local ok, job = pcall(function() return exports.qbx_core:GetJob(JOB) end)
    local cur = ok and job and job.grades and job.grades[g]
    if not cur or cur.isboss then return false, 'rank' end
    local data = {}
    for k, v in pairs(cur) do data[k] = v end
    data.name, data.payment = name, payment
    local done = pcall(function() exports.qbx_core:UpsertJobGrade(JOB, g, data, false) end)
    if not done then return false, 'failed' end
    MySQL.prepare.await('INSERT INTO `exti_mechanic_roles` (`grade`, `name`, `payment`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `payment` = VALUES(`payment`)', { g, name, payment })
    MEC.log(source, 'role_changed', ('%d: %s · $%d'):format(g, name, payment))
    return { grades = gradesView(), myGrade = grade(player), interval = 10 }
end)

cb('bossLogs', function(source, from, to, salaries)
    local player, err = bossCheck(source)
    if not player then return false, err end
    from, to = int(from), int(to)
    if not from or from <= 0 then from = os.time() - 7 * 86400 end
    if not to or to <= 0 then to = os.time() + 86400 end
    local rows = MySQL.query.await('SELECT `at`, `name`, `action`, `content`, `amount` FROM `exti_mechanic_logs` WHERE `at` >= ? AND `at` < ? AND (? = 1 OR `action` <> \'salary_paid\') ORDER BY `id` DESC LIMIT 300', { from, to, salaries == true and 1 or 0 }) or {}
    return rows
end)

-- salaries paid to mechanic officers go in the log (the paycheck comes from the city, not the account)
AddEventHandler('qbx_core:server:onPaycheck', function(src, payment)
    local p = getPlayer(src)
    if p and isCop(p) then MEC.log(src, 'salary_paid', ('$%d'):format(tonumber(payment) or 0)) end
end)
