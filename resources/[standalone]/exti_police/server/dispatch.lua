-- =====================================================================
-- EX_Tii Police (server): 911 calls. A call to the police from the phone (npwd_city) or /911 in the
-- chat lands on every officer's phone and on the tablet map (البلاغات): take it, route to it, close it.
-- Calls live in memory and go away after Config.dispatch.expireMinutes.
-- =====================================================================

local D = Config.dispatch
local getPlayer, onDuty, nameOf, notify, pedOf = POL.getPlayer, POL.onDuty, POL.nameOf, POL.notify, POL.pedOf

local calls = {}       -- [id] = { id, kind, label, coords, caller, number, text, time, takenBy, takenByName }
local nextId = 0
local lastCall = {}    -- [src] = os.time() of his last /911

local function cleanText(value, max)
    if type(value) ~= 'string' or not utf8.len(value) then return nil end
    value = value:gsub('[%c<>~^\\]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if value == '' then return nil end
    local len = utf8.len(value)
    if len and len > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

local function tellCops(event, ...)
    for _, src in ipairs(POL.copsOnDuty()) do TriggerClientEvent(event, src, ...) end
end

local function callView(c, src)
    return {
        id = c.id, kind = c.kind, label = c.label, text = c.text, number = c.number,
        x = c.coords.x, y = c.coords.y, z = c.coords.z, ago = os.time() - c.time,
        takenBy = c.takenByName, mine = c.takenBy == src,
    }
end

local function openCalls()
    local n = 0
    for _ in pairs(calls) do n = n + 1 end
    return n
end
POL.openCalls = openCalls

---@param data { kind: 'phone'|'chat'|'alarm', coords: vector3, caller?: number, text?: string, number?: string, label?: string, alert?: boolean }
local function addCall(data)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' or not tonumber(data.coords.x) then return nil end
    local kind = D.labels[data.kind] and data.kind or 'chat'
    local coords = vec3(data.coords.x + 0.0, data.coords.y + 0.0, (data.coords.z or 0.0) + 0.0)
    local text = cleanText(data.text, D.textLength)
    local c
    -- the same person again within a minute: his call is updated (new place, new text), not doubled
    if data.caller then
        for _, old in pairs(calls) do
            if old.caller == data.caller and not old.takenBy and os.time() - old.time < 60 then
                old.coords, old.time = coords, os.time()
                if text then old.text = text end
                c = old
            end
        end
    end
    if not c then
        nextId = nextId + 1
        c = {
            id = nextId, kind = kind, label = data.label or D.labels[kind], coords = coords, caller = data.caller,
            number = cleanText(data.number, 20), text = text, time = os.time(),
        }
        calls[nextId] = c
    end
    -- the same alert the phone shows (blip + notification + the phone's services list)
    if data.alert ~= false then
        tellCops('npwd_city:client:serviceAlert', {
            id = ('911-%d-%d'):format(c.id, c.time), service = 'police', label = 'الشرطة', blip = 'بلاغ للشرطة', sprite = 526, color = 38,
            number = c.number or '', message = c.text or '', x = coords.x, y = coords.y, z = coords.z, time = c.time,
        })
    end
    tellCops('exti_police:client:callsChanged', true)
    return c.id
end
exports('AddCall', addCall)

-- /911 <text>: for the chat (the phone's services app does the same with the number)
lib.addCommand('911', {
    help = 'بلاغ للشرطة',
    params = { { name = 'message', type = 'longString', help = 'ماذا يحدث؟' } },
}, function(source, args, raw)
    local player = getPlayer(source)
    local ped = pedOf(source)
    if not player or not ped then return end
    local text = cleanText(type(raw) == 'string' and raw:gsub('^/?911%s*', '') or args.message, D.textLength)
    if not text then return notify(source, 'error', 'اكتب ما يحدث: /911 سرقة في المتجر') end
    local now = os.time()
    if lastCall[source] and now - lastCall[source] < D.cooldown then
        return notify(source, 'error', ('انتظر %d ثانية قبل بلاغ آخر'):format(D.cooldown - (now - lastCall[source])))
    end
    lastCall[source] = now
    local number = player.PlayerData.charinfo and player.PlayerData.charinfo.phone
    addCall({ kind = 'chat', coords = GetEntityCoords(ped), caller = source, text = text, number = number and tostring(number) or nil })
    notify(source, 'success', 'وصل بلاغك إلى الشرطة')
end)

-- old calls go away
CreateThread(function()
    while true do
        Wait(60000)
        local now, changed = os.time(), false
        for id, c in pairs(calls) do
            if now - c.time > D.expireMinutes * 60 then calls[id] = nil changed = true end
        end
        if changed then tellCops('exti_police:client:callsChanged') end
    end
end)

---------------------------------------------------------------------------
-- the tablet map
---------------------------------------------------------------------------
local busy = {}
local function slow(src, key, ms)
    local now = GetGameTimer()
    busy[src] = busy[src] or {}
    if busy[src][key] and now - busy[src][key] < ms then return true end
    busy[src][key] = now
    return false
end
local function cb(name, fn)
    lib.callback.register('exti_police:server:tab_' .. name, function(source, ...)
        if slow(source, 'cb:' .. name, 200) then return false, 'wait' end
        return fn(source, ...)
    end)
end

local function list(src)
    local out = {}
    for _, c in pairs(calls) do out[#out + 1] = callView(c, src) end
    table.sort(out, function(a, b) return a.ago < b.ago end)
    return out
end

cb('calls', function(source)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    return { calls = list(source) }
end)

cb('callTake', function(source, id)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local c = calls[math.tointeger(tonumber(id)) or 0]
    if not c then return false, 'gone' end
    if c.takenBy == source then
        c.takenBy, c.takenByName = nil, nil
    else
        c.takenBy, c.takenByName = source, nameOf(player)
    end
    tellCops('exti_police:client:callsChanged')
    return { calls = list(source), call = callView(c, source) }
end)

cb('callClose', function(source, id)
    local player = getPlayer(source)
    if not onDuty(player) then return false, 'off_duty' end
    local c = calls[math.tointeger(tonumber(id)) or 0]
    if not c then return false, 'gone' end
    calls[c.id] = nil
    if c.caller and getPlayer(c.caller) then notify(c.caller, 'inform', 'أغلقت الشرطة بلاغك') end
    tellCops('exti_police:client:callsChanged')
    return { calls = list(source) }
end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src], lastCall[src] = nil, nil
    for _, c in pairs(calls) do
        if c.takenBy == src then c.takenBy, c.takenByName = nil, nil end
    end
end)
