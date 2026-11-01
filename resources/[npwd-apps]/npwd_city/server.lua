-- npwd_city (server): البنك والطوارئ في الهاتف
-- كل التحقق من المبالغ والأرقام يتم هنا في الخادم، ولا نثق بأي قيمة تأتي من الهاتف.

local Bank = Config.Bank
local lastTransfer = {}   -- [source] = os.time() لآخر تحويل
local lastService = {}    -- [source] = { [service] = os.time() }

---------------------------------------------------------------------
-- أدوات مساعدة
---------------------------------------------------------------------
-- يأخذ الأرقام فقط من رقم الهاتف (يقبل 555-1234 أو 5551234)
local function digits(value)
    local kind = type(value)
    if kind ~= 'string' and kind ~= 'number' then return nil end
    local d = tostring(value):gsub('%D', '')
    if #d < 3 or #d > 15 then return nil end
    return d
end

-- ينظف النص الذي يكتبه اللاعب ويقصّه إلى طول محدد (يدعم الحروف العربية)
local function cleanText(value, maxLen)
    if type(value) ~= 'string' then return '' end
    if not utf8.len(value) then return '' end
    value = value:gsub('[%c<>~^\\]', ' '):gsub('%s+', ' ')
    value = value:match('^%s*(.-)%s*$') or ''
    local len = utf8.len(value)
    if len and len > maxLen then
        value = value:sub(1, utf8.offset(value, maxLen + 1) - 1)
    end
    return value
end

local function charName(player)
    local info = player.PlayerData.charinfo or {}
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

---------------------------------------------------------------------
-- البنك
---------------------------------------------------------------------
local function bankHistory(cid)
    local ok, list = pcall(function()
        return exports['Renewed-Banking']:getPlayerTransactions(cid, Bank.historyLimit)
    end)
    local history = {}
    if ok and type(list) == 'table' then
        for i = 1, #list do
            local t = list[i]
            history[#history + 1] = {
                id = t.trans_id,
                title = t.title,
                amount = t.amount,
                type = t.trans_type,
                note = t.message,
                from = t.issuer,
                to = t.receiver,
                time = t.time,
            }
        end
    end
    return history
end

local function logTransaction(cid, title, amount, note, issuer, receiver, kind, transId)
    local ok, result = pcall(function()
        return exports['Renewed-Banking']:logPlayerTransaction(cid, title, amount, note, issuer, receiver, kind, transId)
    end)
    if not ok then
        print(('^3[npwd_city]^0 could not save bank history for %s: %s'):format(cid, result))
        return nil
    end
    return result
end

-- الفواتير غير المدفوعة (المخالفات، فواتير الورشة...) من exti_bank
local function billsOf(citizenid)
    if GetResourceState('exti_bank') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports.exti_bank:GetBills(citizenid) end)
    if not ok or type(list) ~= 'table' then return {} end
    local out = {}
    for i, b in ipairs(list) do
        out[i] = { id = b.id, title = b.title, amount = b.amount, note = b.note, issuer = b.issuer,
            society = b.society, societyLabel = b.societyLabel, created = b.created }
    end
    return out
end

lib.callback.register('npwd_city:bank:get', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local money = player.PlayerData.money or {}
    return {
        name = charName(player),
        phone = tostring(player.PlayerData.charinfo.phone or ''),
        balance = money.bank or 0,
        cash = money.cash or 0,
        history = bankHistory(player.PlayerData.citizenid),
        bills = billsOf(player.PlayerData.citizenid),
    }
end)

-- دفع فاتورة من الهاتف: نفس الدفع في الفرع والصراف (exti_bank يتحقق من كل شيء ويحوّل المال لحساب الجهة)
local lastBillPay = {}
lib.callback.register('npwd_city:bank:payBill', function(source, data)
    local id = math.tointeger(tonumber(type(data) == 'table' and data.id or nil))
    if not id then return { ok = false, error = 'generic' } end
    local now = os.time()
    if lastBillPay[source] and now - lastBillPay[source] < 2 then
        return { ok = false, error = 'cooldown', wait = 2 - (now - lastBillPay[source]) }
    end
    lastBillPay[source] = now
    if GetResourceState('exti_bank') ~= 'started' then return { ok = false, error = 'generic' } end
    local ok, done, code, bill = pcall(function() return exports.exti_bank:PayBill(source, id, 'bank') end)
    if not ok then return { ok = false, error = 'generic' } end
    if not done then
        return { ok = false, error = (code == 'no_bank' or code == 'no_bill') and code or 'generic' }
    end
    local updated = exports.qbx_core:GetPlayer(source)
    return { ok = true, amount = bill and bill.amount or nil, balance = updated and updated.PlayerData.money.bank or nil }
end)

AddEventHandler('playerDropped', function() lastBillPay[source] = nil end)

-- يبحث عن صاحب الرقم: أولًا بين المتصلين، ثم في قاعدة البيانات إذا كان مسموحًا
local function onlineInfo(player)
    return {
        online = true,
        source = player.PlayerData.source,
        citizenid = player.PlayerData.citizenid,
        name = charName(player),
    }
end

local function findByPhone(number)
    -- رقم الهاتف قد يكون محفوظًا كنص أو كرقم
    local online = exports.qbx_core:GetPlayerByPhone(number)
        or exports.qbx_core:GetPlayerByPhone(tonumber(number))
    if online then return onlineInfo(online) end

    local row = MySQL.single.await(
        "SELECT citizenid, charinfo FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) = ? LIMIT 1",
        { number }
    )
    if not row then return nil end

    -- قد يكون صاحب الرقم متصلًا لكن رقمه محفوظ بصيغة مختلفة
    local player = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
    if player then return onlineInfo(player) end

    if not Bank.allowOffline then return nil end

    local info = json.decode(row.charinfo or '{}') or {}
    return {
        online = false,
        citizenid = row.citizenid,
        name = ('%s %s'):format(info.firstname or '', info.lastname or ''),
    }
end

lib.callback.register('npwd_city:bank:transfer', function(source, data)
    if type(data) ~= 'table' then return { ok = false, error = 'generic' } end
    if not exports.qbx_core:GetPlayer(source) then return { ok = false, error = 'generic' } end

    local now = os.time()
    local last = lastTransfer[source]
    if last and now - last < Bank.cooldown then
        return { ok = false, error = 'cooldown', wait = Bank.cooldown - (now - last) }
    end

    local amount = tonumber(data.amount)
    if not amount or amount ~= amount or amount % 1 ~= 0
        or amount < Bank.minTransfer or amount > Bank.maxTransfer then
        return { ok = false, error = 'amount', min = Bank.minTransfer, max = Bank.maxTransfer }
    end
    amount = math.floor(amount)

    local number = digits(data.number)
    if not number then return { ok = false, error = 'number' } end

    local note = cleanText(data.note, Bank.noteLength)
    lastTransfer[source] = now

    local target = findByPhone(number) -- قد ينتظر قاعدة البيانات
    if not target then return { ok = false, error = 'not_found' } end
    if not target.online then
        -- EX_Tii: التحويل يعمل فقط لمن هو في المدينة الآن
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'inform',
            description = 'صاحب هذا الرقم ليس في المدينة الآن. التحويل يعمل فقط لمن هو في المدينة.',
        })
        return { ok = false, error = 'not_found' }
    end

    -- نقرأ اللاعب من جديد بعد الانتظار
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { ok = false, error = 'generic' } end
    if target.citizenid == player.PlayerData.citizenid then return { ok = false, error = 'self' } end
    if (player.PlayerData.money.bank or 0) < amount then return { ok = false, error = 'balance' } end

    -- EX_Tii: المال يتحرك عبر EX_Tii Bank (نفس التحقق والحدود والسجل مثل جهاز البنك)
    if GetResourceState('exti_bank') ~= 'started' then return { ok = false, error = 'generic' } end
    local ok, code = exports.exti_bank:Transfer(source, target.source, amount, note, 'phone')
    if not ok then
        local errors = { no_bank = 'balance', self = 'self', not_found = 'not_found', amount = 'amount', busy = 'cooldown', cooldown = 'cooldown' }
        return { ok = false, error = errors[code] or 'generic', min = Bank.minTransfer, max = Bank.maxTransfer, wait = 2 }
    end

    local senderName = charName(player)
    local senderPhone = digits(player.PlayerData.charinfo.phone) or ''
    TriggerClientEvent('npwd_city:client:bankReceived', target.source, {
        amount = amount,
        number = senderPhone,
        name = senderName,
        note = note,
    })

    local updated = exports.qbx_core:GetPlayer(source)
    return {
        ok = true,
        amount = amount,
        name = target.name,
        balance = updated and updated.PlayerData.money.bank or nil,
    }
end)

---------------------------------------------------------------------
-- الطوارئ
---------------------------------------------------------------------
-- يرجع قائمة اللاعبين المناوبين لهذه الجهة (بدون تكرار)
local function onDuty(service)
    local seen, list = {}, {}
    local function add(sources)
        if type(sources) ~= 'table' then return end
        for i = 1, #sources do
            local src = sources[i]
            if not seen[src] then
                seen[src] = true
                list[#list + 1] = src
            end
        end
    end
    for _, jobType in ipairs(service.types or {}) do
        local _, sources = exports.qbx_core:GetDutyCountType(jobType)
        add(sources)
    end
    for _, jobName in ipairs(service.jobs or {}) do
        local _, sources = exports.qbx_core:GetDutyCountJob(jobName)
        add(sources)
    end
    return list
end

lib.callback.register('npwd_city:services:send', function(source, data)
    if type(data) ~= 'table' or type(data.service) ~= 'string' then return { ok = false, error = 'generic' } end
    local service = Config.Services[data.service]
    if not service then return { ok = false, error = 'generic' } end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { ok = false, error = 'generic' } end

    local now = os.time()
    lastService[source] = lastService[source] or {}
    local last = lastService[source][data.service]
    if last and now - last < Config.ServiceCooldown then
        return { ok = false, error = 'cooldown', wait = Config.ServiceCooldown - (now - last) }
    end
    lastService[source][data.service] = now

    -- الموقع يؤخذ من الخادم وليس من الهاتف
    local coords = GetEntityCoords(GetPlayerPed(source))
    local alert = {
        id = ('%d-%d'):format(source, now),
        service = data.service,
        label = service.label,
        blip = service.blip,
        sprite = service.sprite,
        color = service.color,
        number = digits(player.PlayerData.charinfo.phone) or '',
        message = cleanText(data.message, Config.MessageLength),
        x = coords.x, y = coords.y, z = coords.z,
        time = now,
    }

    local count = 0
    local targets = onDuty(service)
    for i = 1, #targets do
        if targets[i] ~= source then
            count += 1
            TriggerClientEvent('npwd_city:client:serviceAlert', targets[i], alert)
        end
    end

    -- EX_Tii: a call to the ambulance also goes on the medics' tablet (exti_ems)
    if data.service == 'ems' and GetResourceState('exti_ems') == 'started' then
        pcall(function()
            exports.exti_ems:AddCall({ kind = 'phone', coords = coords, patient = source, text = alert.message, number = alert.number })
        end)
    end
    -- EX_Tii: a call to the police also goes on the police tablet map (exti_police); the phone alert above is enough
    if data.service == 'police' and GetResourceState('exti_police') == 'started' then
        pcall(function()
            exports.exti_police:AddCall({ kind = 'phone', coords = coords, caller = source, text = alert.message, number = alert.number, alert = false })
        end)
    end

    -- عدد الشرطة لا يُعرض حتى لا يستغله أحد قبل السرقات
    local showCount = data.service ~= 'police'
    return { ok = true, count = showCount and count or nil, hidden = not showCount }
end)

AddEventHandler('playerDropped', function()
    lastTransfer[source] = nil
    lastService[source] = nil
end)
