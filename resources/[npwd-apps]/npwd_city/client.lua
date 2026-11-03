-- npwd_city (client): يربط تطبيقات الهاتف (البنك، الأماكن، الطوارئ) باللعبة
-- الهاتف يرسل الطلبات إلى https://npwd_city/<name>

local alerts = {}       -- البلاغات التي وصلت لهذا اللاعب (للموظفين المناوبين)
local placesCache = nil

---------------------------------------------------------------------
-- أدوات مساعدة
---------------------------------------------------------------------
local function zoneLabel(x, y, z)
    local zone = GetNameOfZone(x, y, z)
    if not zone or zone == '' then return nil end
    local label = GetLabelText(zone)
    if not label or label == '' or label == 'NULL' then return nil end
    return label
end

local function formatMoney(amount)
    local text = tostring(math.floor(tonumber(amount) or 0))
    local result = text:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (result:gsub('^,', ''))
end

local function phoneOpen()
    local ok, visible = pcall(function() return exports.npwd:isPhoneVisible() end)
    return ok and visible
end

-- إشعار داخل الهاتف (يظهر في مركز الإشعارات)
local function phoneNotify(appId, title, content, path)
    pcall(function()
        exports.npwd:createNotification({
            notisId = ('npwd_city:%s:%d'):format(appId, GetGameTimer()),
            appId = appId,
            secondaryTitle = title,
            content = content,
            keepOpen = false,
            duration = 6000,
            path = path,
        })
    end)
end

---------------------------------------------------------------------
-- البنك
---------------------------------------------------------------------
RegisterNUICallback('bank:get', function(_, cb)
    cb(lib.callback.await('npwd_city:bank:get', false) or {})
end)

RegisterNUICallback('bank:transfer', function(data, cb)
    cb(lib.callback.await('npwd_city:bank:transfer', false, data) or { ok = false, error = 'generic' })
end)

RegisterNUICallback('bank:payBill', function(data, cb)
    cb(lib.callback.await('npwd_city:bank:payBill', false, data) or { ok = false, error = 'generic' })
end)

RegisterNetEvent('npwd_city:client:bankReceived', function(data)
    if type(data) ~= 'table' then return end
    local text = ('وصلك $%s من الرقم %s'):format(formatMoney(data.amount), tostring(data.number or ''))
    if data.note and data.note ~= '' then
        text = ('%s: %s'):format(text, data.note)
    end
    phoneNotify('BANK', 'تحويل وارد', text, '/bank')
    if not phoneOpen() then
        lib.notify({ title = 'البنك', description = text, type = 'success', duration = 7000 })
    end
end)

---------------------------------------------------------------------
-- الأماكن
---------------------------------------------------------------------
local function buildPlaces()
    if placesCache then return placesCache end
    local list = {}
    for index, place in ipairs(Config.Places) do
        local kind = Config.PlaceKinds[place.kind]
        if kind then
            local label = place.label
            if not label then
                local zone = zoneLabel(place.coords.x, place.coords.y, place.coords.z)
                label = zone and ('%s (%s)'):format(kind.label, zone) or kind.label
            end
            list[#list + 1] = {
                id = index,
                cat = kind.cat,
                icon = kind.icon,
                label = label,
                coords = vec3(place.coords.x, place.coords.y, place.coords.z),
            }
        end
    end
    placesCache = list
    return list
end

RegisterNUICallback('places:list', function(_, cb)
    local pos = GetEntityCoords(cache.ped)
    local list = buildPlaces()
    local out = {}
    for i = 1, #list do
        local place = list[i]
        out[i] = {
            id = place.id,
            cat = place.cat,
            icon = place.icon,
            label = place.label,
            dist = math.floor(#(pos - place.coords)),
        }
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    cb({ categories = Config.PlaceCategories, places = out })
end)

-- EX_Tii: "take me there" = thin gold GPS line + a pin named after the place (exti_gps).
-- Without exti_gps: GTA's own map marker, like before.
local function goTo(x, y, z, label)
    local ok, done = false, false
    if GetResourceState('exti_gps') == 'started' then
        ok, done = pcall(function() return exports.exti_gps:GoTo(x, y, z, label) end)
    end
    if not (ok and done) then SetNewWaypoint(x, y) end
end

RegisterNUICallback('places:waypoint', function(data, cb)
    local place = type(data) == 'table' and Config.Places[tonumber(data.id) or -1]
    if not place then return cb({ ok = false }) end
    local label = place.label
    if not label then
        for _, p in ipairs(buildPlaces()) do
            if p.id == tonumber(data.id) then label = p.label break end
        end
    end
    goTo(place.coords.x, place.coords.y, place.coords.z, label)
    PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    cb({ ok = true })
end)

---------------------------------------------------------------------
-- الطوارئ
---------------------------------------------------------------------
RegisterNUICallback('services:info', function(_, cb)
    local services = {}
    for _, id in ipairs(Config.ServiceOrder) do
        local service = Config.Services[id]
        if service then
            services[#services + 1] = { id = id, label = service.label }
        end
    end
    cb({ services = services, alerts = alerts, cooldown = Config.ServiceCooldown, maxLength = Config.MessageLength })
end)

RegisterNUICallback('services:send', function(data, cb)
    cb(lib.callback.await('npwd_city:services:send', false, data) or { ok = false, error = 'generic' })
end)

RegisterNUICallback('services:waypoint', function(data, cb)
    local id = type(data) == 'table' and data.id
    for i = 1, #alerts do
        if alerts[i].id == id then
            goTo(alerts[i].x, alerts[i].y, alerts[i].z, alerts[i].label and ('بلاغ: %s'):format(alerts[i].label) or nil)
            PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            return cb({ ok = true })
        end
    end
    cb({ ok = false })
end)

RegisterNetEvent('npwd_city:client:serviceAlert', function(alert)
    if type(alert) ~= 'table' or not alert.x then return end

    -- EX_Tii: a quiet alert (police calls: exti_police shows its own call card) only goes in the list
    if alert.quiet then
        alert.zone = zoneLabel(alert.x, alert.y, alert.z)
        table.insert(alerts, 1, alert)
        while #alerts > Config.AlertsKept do table.remove(alerts) end
        return
    end

    local blip = AddBlipForCoord(alert.x, alert.y, alert.z)
    SetBlipSprite(blip, alert.sprite or 280)
    SetBlipColour(blip, alert.color or 1)
    SetBlipScale(blip, 0.75) -- EX_Tii: same size as every icon
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    SetBlipFlashTimer(blip, 10000)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(alert.blip or 'بلاغ')
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.AlertBlipTime * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)

    alert.zone = zoneLabel(alert.x, alert.y, alert.z)
    table.insert(alerts, 1, alert)
    while #alerts > Config.AlertsKept do table.remove(alerts) end

    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)

    local details = (alert.message and alert.message ~= '') and alert.message or 'بدون تفاصيل'
    local where = alert.zone and (' - %s'):format(alert.zone) or ''
    local text = ('من الرقم %s%s: %s'):format(alert.number or '', where, details)
    phoneNotify('SERVICES', ('بلاغ جديد: %s'):format(alert.label or ''), text, '/services')
    lib.notify({
        title = ('بلاغ جديد: %s'):format(alert.label or ''),
        description = text .. '\nافتح تطبيق الطوارئ في الهاتف لتحديد المسار.',
        type = 'inform',
        duration = 10000,
    })
end)

---------------------------------------------------------------------
-- المستوى (exti_level)
---------------------------------------------------------------------
RegisterNUICallback('level:get', function(_, cb)
    cb(lib.callback.await('npwd_city:level:get', false) or {})
end)

---------------------------------------------------------------------
-- الطاقم (exti_heists): السمعة، الطاقم، لوحة السرقات، الترتيب
---------------------------------------------------------------------
for _, action in ipairs({ 'get', 'create', 'invite', 'accept', 'decline', 'leave', 'kick', 'lead', 'fence' }) do
    RegisterNUICallback('crew:' .. action, function(data, cb)
        if GetResourceState('exti_heists') ~= 'started' then return cb(action == 'get' and {} or { ok = false }) end
        local ok, res = pcall(lib.callback.await, 'exti_heists:server:crew', false, action, data)
        cb(ok and res or (action == 'get' and {} or { ok = false }))
    end)
end
