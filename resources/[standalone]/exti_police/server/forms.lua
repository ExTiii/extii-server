-- =====================================================================
-- EX_Tii Police (server): the public forms — citizens fill a paper form at the front desk (job
-- application, complaint), officers on duty read them in the inbox at the desk computer: notes,
-- reviewed, archive. (Later the inbox also lives in the police tablet.)
-- =====================================================================

local FC = Config.forms

local getPlayer, onDuty, grade, nameOf, nearSpot, notify = POL.getPlayer, POL.onDuty, POL.grade, POL.nameOf, POL.nearSpot, POL.notify

local TYPES = {}
for _, t in ipairs(FC.types) do TYPES[t.id] = t end

local forms = {}     -- the newest forms, newest first: { id, type, citizenid, name, fields, notes, created, reviewedBy, archived }
local byId = {}
local lastSent = {}  -- [citizenid] = os.time()
local ready = false

local function decode(s)
    local ok, v = pcall(json.decode, s or '')
    return ok and type(v) == 'table' and v or nil
end

local function refOf(f)
    local t = TYPES[f.type]
    return ('%s-%04d'):format(t and t.prefix or 'FRM', f.id)
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_police_forms` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `type` VARCHAR(32) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `fields` LONGTEXT NOT NULL,
        `notes` LONGTEXT NULL,
        `created` INT NOT NULL,
        `reviewed_by` VARCHAR(80) NULL,
        `reviewed_at` INT NULL,
        `archived` TINYINT NOT NULL DEFAULT 0,
        INDEX `cid` (`citizenid`)
    )]])
    local rows = MySQL.query.await('SELECT * FROM `exti_police_forms` ORDER BY `id` DESC LIMIT ?', { FC.keep or 300 }) or {}
    for _, r in ipairs(rows) do
        local f = {
            id = r.id, type = r.type, citizenid = r.citizenid, name = r.name,
            fields = decode(r.fields) or {}, notes = decode(r.notes) or {}, created = r.created,
            reviewedBy = r.reviewed_by, archived = (tonumber(r.archived) or 0) == 1,
        }
        forms[#forms + 1] = f
        byId[f.id] = f
    end
    ready = true
end)

local function atSpot(src, kind)
    for _, st in pairs(Config.stations) do
        if st[kind] and nearSpot(src, st[kind], 2.5) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- the citizen's side
---------------------------------------------------------------------------
local function typesView()
    local list = {}
    for _, t in ipairs(FC.types) do
        local fields = {}
        for _, f in ipairs(t.fields) do
            fields[#fields + 1] = { id = f.id, label = f.label, required = f.required == true, type = f.type, placeholder = f.placeholder, max = f.max }
        end
        list[#list + 1] = { id = t.id, icon = t.icon, label = t.label, desc = t.desc, fields = fields }
    end
    return list
end

lib.callback.register('exti_police:server:formsInfo', function(source)
    local player = getPlayer(source)
    if not player or not atSpot(source, 'forms') then return false, 'too_far' end
    local c = player.PlayerData.charinfo or {}
    return { types = typesView(), me = { name = nameOf(player), dob = c.birthdate, phone = c.phone } }
end)

-- one line (or a few lines for the big boxes), no strange characters, not too long
local function clean(value, field)
    if value == nil then return '' end
    if type(value) == 'number' then value = tostring(value) end
    if type(value) ~= 'string' then return nil end
    local area = field.type == 'area'
    local max = tonumber(field.max) or (area and 600 or 60)
    value = value:gsub('\r\n?', '\n')
    value = area and value:gsub('[\0-\9\11-\31\127]', '') or value:gsub('%c', ' ')
    value = value:gsub('\n\n\n+', '\n\n'):gsub('^%s+', ''):gsub('%s+$', '')
    local n = utf8.len(value)
    if not n then return nil end
    if n > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

local function openCount(cid)
    local n = 0
    for _, f in ipairs(forms) do
        if f.citizenid == cid and not f.reviewedBy and not f.archived then n = n + 1 end
    end
    return n
end

lib.callback.register('exti_police:server:formSubmit', function(source, typeId, values)
    local player = getPlayer(source)
    if not player then return { ok = false } end
    if not ready then return { ok = false, text = 'النظام غير جاهز، حاول بعد لحظة.' } end
    if not atSpot(source, 'forms') then return { ok = false, text = 'اقترب من مكتب الاستقبال.' } end
    local t = TYPES[typeId]
    if not t then return { ok = false } end
    local cid = player.PlayerData.citizenid
    local now = os.time()
    if lastSent[cid] and now - lastSent[cid] < (FC.cooldown or 300) then
        return { ok = false, text = 'أرسلت نموذجًا قبل قليل، انتظر بضع دقائق.' }
    end
    if openCount(cid) >= (FC.maxOpen or 3) then
        return { ok = false, text = 'عندك نماذج لم تُراجع بعد، انتظر حتى تراجعها الشرطة.' }
    end
    values = type(values) == 'table' and values or {}
    local fields = {}
    for _, f in ipairs(t.fields) do
        local v = clean(values[f.id], f)
        if v == nil then return { ok = false, text = ('تحقق من: %s'):format(f.label) } end
        if f.required and v == '' then return { ok = false, text = ('املأ: %s'):format(f.label) } end
        if v ~= '' then fields[f.id] = v end
    end
    local name = fields.name or nameOf(player)
    if utf8.len(name) > 60 then name = name:sub(1, utf8.offset(name, 61) - 1) end
    lastSent[cid] = now
    local id = MySQL.insert.await('INSERT INTO `exti_police_forms` (`type`, `citizenid`, `name`, `fields`, `notes`, `created`) VALUES (?, ?, ?, ?, ?, ?)',
        { t.id, cid, name, json.encode(fields), '[]', now })
    if not id then lastSent[cid] = nil return { ok = false } end
    local f = { id = id, type = t.id, citizenid = cid, name = name, fields = fields, notes = {}, created = now, archived = false }
    table.insert(forms, 1, f)
    byId[id] = f
    while #forms > (FC.keep or 300) do
        local old = table.remove(forms)
        byId[old.id] = nil
    end
    lib.logger(source, 'police', ('sent the form %s (%s)'):format(refOf(f), t.id))
    -- (the name is shown as plain text: no links / pictures / big titles in the alert)
    local plainName = name:gsub('[%[%]%(%)!#%*_`<>|~\\=%-]', ''):gsub('%s+', ' ')
    for _, cop in ipairs(POL.copsOnDuty()) do
        notify(cop, 'inform', ('وصل نموذج جديد: %s من %s'):format(t.label, plainName))
    end
    return { ok = true, ref = refOf(f) }
end)

---------------------------------------------------------------------------
-- the officers' side: the inbox
---------------------------------------------------------------------------
-- the list only shows a short line per form; a form's boxes and notes come when it is opened
local function summary(f)
    local t = TYPES[f.type]
    return {
        id = f.id, ref = refOf(f), type = f.type, typeLabel = t and t.label or f.type, name = f.name, time = f.created,
        reviewed = f.reviewedBy ~= nil, reviewedBy = f.reviewedBy, archived = f.archived,
    }
end

local function full(f)
    local x = summary(f)
    x.fields, x.notes = f.fields, f.notes
    return x
end

local function inboxView()
    local list = {}
    for _, f in ipairs(forms) do list[#list + 1] = summary(f) end
    return list
end

-- on duty; at the desk computer (the old inbox spot) or from the police tablet
local function inboxCheck(src, fromTablet)
    local player = getPlayer(src)
    if not onDuty(player) then return nil, 'off_duty' end
    if not fromTablet and not atSpot(src, 'inbox') then return nil, 'too_far' end
    if not ready then return nil, 'failed' end
    return player
end

local lastNote = {}

local function doAction(source, player, id, action, note)
    local f = type(id) == 'number' and byId[id]
    if not f then return { items = inboxView() } end
    local who = nameOf(player)
    if action == 'note' then
        local text = clean(note, { max = 300 })
        if not text or text == '' then return { items = inboxView(), item = full(f) } end
        local now = GetGameTimer()
        if lastNote[source] and now - lastNote[source] < 2000 then return { items = inboxView(), item = full(f), text = 'انتظر لحظة قبل الملاحظة التالية.' } end
        if #f.notes >= 30 then return { items = inboxView(), item = full(f), text = 'وصل هذا النموذج للحد الأقصى من الملاحظات.' } end
        lastNote[source] = now
        f.notes[#f.notes + 1] = { by = who, time = os.time(), text = text }
        MySQL.update('UPDATE `exti_police_forms` SET `notes` = ? WHERE `id` = ?', { json.encode(f.notes), f.id })
    elseif action == 'review' then
        if not f.reviewedBy then
            f.reviewedBy = who
            MySQL.update('UPDATE `exti_police_forms` SET `reviewed_by` = ?, `reviewed_at` = ? WHERE `id` = ?', { who, os.time(), f.id })
        end
    elseif action == 'archive' or action == 'unarchive' then
        if grade(player) < (FC.archiveGrade or 0) then
            return { items = inboxView(), item = full(f), text = ('الأرشفة لرتبة %s فما فوق'):format(POL.gradeName(FC.archiveGrade)) }
        end
        f.archived = action == 'archive'
        MySQL.update('UPDATE `exti_police_forms` SET `archived` = ? WHERE `id` = ?', { f.archived and 1 or 0, f.id })
    else
        return { items = inboxView(), item = full(f) }
    end
    lib.logger(source, 'police', ('%s on the form %s'):format(action, refOf(f)))
    return { items = inboxView(), item = full(f) }
end

for _, kind in ipairs({ 'desk', 'tablet' }) do
    local fromTablet = kind == 'tablet'
    local prefix = fromTablet and 'exti_police:server:tab_' or 'exti_police:server:'
    lib.callback.register(prefix .. (fromTablet and 'formsList' or 'inbox'), function(source)
        local player, err = inboxCheck(source, fromTablet)
        if not player then return false, err end
        return { types = typesView(), items = inboxView() }
    end)
    lib.callback.register(prefix .. 'formGet', function(source, id)
        local player = inboxCheck(source, fromTablet)
        if not player then return false end
        local f = type(id) == 'number' and byId[id]
        return f and full(f) or false
    end)
    lib.callback.register(prefix .. 'formAction', function(source, id, action, note)
        local player, err = inboxCheck(source, fromTablet)
        if not player then return { text = err } end
        return doAction(source, player, id, action, note)
    end)
end

-- how many forms nobody has looked at yet (the badge on the tablet)
function POL.newForms()
    local n = 0
    for _, f in ipairs(forms) do
        if not f.reviewedBy and not f.archived then n = n + 1 end
    end
    return n
end

AddEventHandler('playerDropped', function()
    lastNote[source] = nil
end)
