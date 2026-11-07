-- =====================================================================
-- EX_Tii Police (game side): the call card (like NoPixel's dispatch). Every new call pops up for
-- officers on duty: code, title, street, details, how long ago, how far, who took it.
--   G = take the call (again = let it go) + the gold route to it
--   Arrow up / down = look through the last calls
-- A flashing icon marks the place on the map for a few minutes.
-- =====================================================================
local D = Config.dispatch
local list = {}            -- the last calls, newest first: { id, code, icon, urgent, label, text, x, y, z, time, takenBy, mine, street, area, shownUntil, blip }
local MAX = 10
local TAKEN_MS = 6000      -- after a cop takes it: the card shows who took it for 6 s, then goes
local CARD_MS = (D.cardSeconds or 60) * 1000   -- EX_Tii (Moe): a call nobody takes leaves the screen after a minute
                                                -- (still in the list: arrows up / down, and on the tablet map)
local flip = { on = false, index = 1, untilAt = 0 }
local ticking = false

local function now() return GetGameTimer() end

local function placeOf(x, y, z)
    local s1 = GetStreetNameAtCoord(x, y, z)
    local street = s1 and GetStreetNameFromHashKey(s1) or ''
    local zone = GetNameOfZone(x, y, z)
    local area = zone and GetLabelText(zone) or ''
    if area == 'NULL' then area = '' end
    return street, area
end

-- what the page shows right now
local function render()
    local me = GetEntityCoords(cache.ped)
    local function view(c, extra)
        local v = { id = c.id, code = c.code, icon = c.icon, urgent = c.urgent, label = c.label, text = c.text, street = c.street, area = c.area,
            takenBy = c.takenBy, mine = c.mine, witness = c.witness, dist = math.floor(#(me - vec3(c.x, c.y, c.z))), seen = math.floor((now() - c.at) / 1000) }
        if extra then for k, val in pairs(extra) do v[k] = val end end
        return v
    end
    local cards = {}
    if flip.on and list[flip.index] then
        cards[1] = view(list[flip.index], { focus = true })
    else
        for _, c in ipairs(list) do
            if c.shownUntil > now() then cards[#cards + 1] = view(c) end
            if #cards >= 3 then break end
        end
    end
    SendNUIMessage({ action = 'dispatch:render', cards = cards, index = flip.on and flip.index or nil, total = #list })
    return #cards > 0
end

local function tick()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while true do
            if flip.on and now() > flip.untilAt then flip.on = false end
            if not render() then break end
            Wait(1000)
        end
        ticking = false
    end)
end

local function find(id)
    for i, c in ipairs(list) do if c.id == id then return c, i end end
end

local function removeBlip(c)
    if c.blip and DoesBlipExist(c.blip) then RemoveBlip(c.blip) end
    c.blip = nil
end

local function addBlip(c)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, c.urgent and 161 or 526)
    SetBlipColour(b, c.urgent and 1 or 38)
    SetBlipScale(b, c.urgent and 1.1 or 0.85)
    SetBlipAsShortRange(b, false)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s %s'):format(c.code or '', c.label or 'بلاغ'))
    EndTextCommandSetBlipName(b)
    c.blip = b
    local id = c.id
    SetTimeout((D.blipSeconds or 180) * 1000, function()
        local cc = find(id); if cc then removeBlip(cc) elseif DoesBlipExist(b) then RemoveBlip(b) end
    end)
end

-- quiet = a call from before you came on duty: no beep, and it keeps its real age
local function addCard(card, quiet)
    if type(card) ~= 'table' or not card.id or not card.x then return end
    local old = find(card.id)
    if old then removeBlip(old) end
    for i = #list, 1, -1 do if list[i].id == card.id then table.remove(list, i) end end
    local street, area = placeOf(card.x + 0.0, card.y + 0.0, (card.z or 0.0) + 0.0)
    local c = {
        id = card.id, code = card.code, icon = card.icon, urgent = card.urgent == true, label = card.label, text = card.text,
        x = card.x + 0.0, y = card.y + 0.0, z = (card.z or 0.0) + 0.0, takenBy = card.takenBy or false, mine = false, witness = type(card.witness) == 'table' and card.witness or nil,
        street = street, area = area, at = now() - (tonumber(card.ago) or 0) * 1000, shownUntil = card.takenBy and (now() + TAKEN_MS) or (now() + CARD_MS),
    }
    table.insert(list, 1, c)
    while #list > MAX do removeBlip(list[#list]); table.remove(list) end
    addBlip(c)
    if not quiet then SendNUIMessage({ action = 'dispatch:sound', urgent = c.urgent }) end
    if flip.on then flip.index = 1 end
    tick()
end
RegisterNetEvent('exti_police:client:dispatchCard', function(card) addCard(card, false) end)

RegisterNetEvent('exti_police:client:dispatchTaken', function(id, name, by)
    local c = find(id); if not c then return end
    c.takenBy = name or false
    c.mine = name and by == cache.serverId or false
    c.shownUntil = name and (now() + TAKEN_MS) or (now() + CARD_MS)   -- let go again: back on screen for a while
    tick()
end)

RegisterNetEvent('exti_police:client:dispatchClosed', function(id)
    local c, i = find(id); if not c then return end
    removeBlip(c); table.remove(list, i)
    if flip.index > #list then flip.index = math.max(1, #list) end
    tick()
end)

-- the card the keys act on: the one you are looking through, or the newest one on screen
local function current()
    if flip.on then return list[flip.index] end
    for _, c in ipairs(list) do if c.shownUntil > now() then return c end end
end

local function route(c)
    if GetResourceState('exti_gps') == 'started' then
        local ok = pcall(function() exports.exti_gps:GoTo(c.x, c.y, c.z, ('%s %s'):format(c.code or '', c.label or '')) end)
        if ok then return end
    end
    SetNewWaypoint(c.x, c.y)
end

RegisterCommand('+exti_dispatch_take', function()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    local c = current(); if not c then return end
    local res = lib.callback.await('exti_police:server:tab_callTake', false, c.id)
    if type(res) ~= 'table' or not res.call then return end
    c.mine = res.call.mine == true
    c.takenBy = res.call.takenBy or false
    if c.mine then route(c) end
    c.shownUntil = c.takenBy and (now() + TAKEN_MS) or (now() + CARD_MS)
    tick()
end, false)
RegisterCommand('-exti_dispatch_take', function() end, false)
RegisterKeyMapping('+exti_dispatch_take', 'الشرطة: استلم البلاغ (بطاقة البلاغ)', 'keyboard', 'G')

-- EX_Tii (Moe): J = hide this call from MY screen (it stays in the list, the others still see it)
RegisterCommand('+exti_dispatch_hide', function()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    local c = current(); if not c then return end
    c.shownUntil = 0
    flip.on = false
    tick()
    SendNUIMessage({ action = 'dispatch:render', cards = {} })
    render()
end, false)
RegisterCommand('-exti_dispatch_hide', function() end, false)
RegisterKeyMapping('+exti_dispatch_hide', 'الشرطة: أخفِ البلاغ من شاشتي', 'keyboard', 'J')

local function look(step)
    if IsNuiFocused() or IsPauseMenuActive() or #list == 0 then return end
    if not flip.on then flip.on, flip.index = true, 1
    else flip.index = math.max(1, math.min(#list, flip.index + step)) end
    flip.untilAt = now() + 8000
    tick()
end
RegisterCommand('+exti_dispatch_older', function() look(1) end, false)
RegisterCommand('-exti_dispatch_older', function() end, false)
RegisterCommand('+exti_dispatch_newer', function() look(-1) end, false)
RegisterCommand('-exti_dispatch_newer', function() end, false)
RegisterKeyMapping('+exti_dispatch_older', 'الشرطة: البلاغ الأقدم', 'keyboard', 'DOWN')
RegisterKeyMapping('+exti_dispatch_newer', 'الشرطة: البلاغ الأحدث', 'keyboard', 'UP')

-- off duty / a new character: no cards, no icons
local function clearAll()
    for _, c in ipairs(list) do removeBlip(c) end
    list = {}; flip.on = false
    SendNUIMessage({ action = 'dispatch:render', cards = {} })
end
-- coming on duty: the calls of the last 2 minutes that are still open pop up too (once, without a beep)
local wasOn = false
local function dutyNow(on)
    if not on then wasOn = false; clearAll(); return end
    if wasOn then return end
    wasOn = true
    SetTimeout(800, function()
        if not wasOn then return end
        local cards = lib.callback.await('exti_police:server:tab_dispatchRecent', false)
        if type(cards) ~= 'table' then return end
        for _, card in ipairs(cards) do
            if not find(card.id) and not card.takenBy then addCard(card, true) end
        end
    end)
end
local function jobOn(job) return job and job.name == 'police' and job.onduty == true end
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) dutyNow(jobOn(job)) end)
RegisterNetEvent('QBCore:Client:SetDuty', function(on) local j = QBX.PlayerData and QBX.PlayerData.job; dutyNow(on == true and j ~= nil and j.name == 'police') end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(1500, function() dutyNow(jobOn(QBX.PlayerData and QBX.PlayerData.job)) end) end)
RegisterNetEvent('qbx_core:client:playerLoggedOut', function() wasOn = false; clearAll() end)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and QBX and QBX.PlayerData and jobOn(QBX.PlayerData.job) then dutyNow(true) end
end)

-- the mask (for what a witness sees): kept on the player's state, only when it changes
CreateThread(function()
    local last
    while true do
        local m = GetPedDrawableVariation(cache.ped, 1) > 0
        if m ~= last then last = m; LocalPlayer.state:set('exti_mask', m, true) end
        Wait(2000)
    end
end)
