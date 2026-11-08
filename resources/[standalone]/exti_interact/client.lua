-- =====================================================================
-- EX_Tii interact: every ox_lib text prompt of every script comes here (ox_lib sends lib.showTextUI /
-- hideTextUI to us, see ox_lib/resource/exti_textui/client.lua). One prompt = one line next to the
-- crosshair. Several = a list: the mouse wheel or the arrow keys pick one, E uses the picked one.
-- Which script owns the picked line is in LocalPlayer.state.interactSel: every script only reacts to
-- E when its own line is the picked one (or when nothing is picked).
-- =====================================================================
local entries = {}      -- [resource] = { text, key, label, selectable, at }
local order = {}        -- resources in the order their prompts appeared
local selected = nil    -- resource of the picked line
local dirty = false
local SCROLL_DOWN, SCROLL_UP = { 14, 16, 242 }, { 15, 17, 241 }
local ARROW_DOWN, ARROW_UP = 173, 172

local function parse(text)
    text = tostring(text or '')
    local key, rest = text:match('^%s*%[([^%]]+)%]%s*(.*)$')
    if key then return key, rest end
    return nil, text
end

local function selectables()
    local list = {}
    for _, res in ipairs(order) do
        local e = entries[res]
        if e and e.selectable then list[#list + 1] = res end
    end
    return list
end

local function setSelected(res)
    if selected == res then return end
    selected = res
    LocalPlayer.state:set('interactSel', res, false)
    dirty = true
end

local function fixSelection()
    local list = selectables()
    for _, r in ipairs(list) do if r == selected then return end end
    setSelected(list[1])
end

local function render()
    dirty = false
    local items = {}
    for _, res in ipairs(order) do
        local e = entries[res]
        if e then items[#items + 1] = { key = e.key, label = e.label, on = res == selected, pick = e.selectable } end
    end
    SendNUIMessage({ action = 'list', items = items, many = #selectables() > 1 })
end

local function show(res, text, options)
    res = res or 'unknown'
    local key, label = parse(text)
    local e = entries[res]
    if e and e.text == text then return end
    if not e then order[#order + 1] = res end
    entries[res] = { text = text, key = key, label = label, selectable = key ~= nil and key:upper() == 'E' }
    fixSelection()
    dirty = true
end

local function hide(res)
    res = res or 'unknown'
    if not entries[res] then return end
    entries[res] = nil
    for i = #order, 1, -1 do if order[i] == res then table.remove(order, i) end end
    fixSelection()
    dirty = true
end

exports('Show', show)
exports('Hide', hide)
exports('IsOpen', function(res)
    local e = entries[res or 'unknown']
    return e ~= nil, e and e.text or nil
end)

AddEventHandler('onClientResourceStop', function(res)
    if res == GetCurrentResourceName() then
        LocalPlayer.state:set('interactSel', nil, false)
        return
    end
    hide(res)
end)

local function pressed(list)
    for _, c in ipairs(list) do if IsDisabledControlJustPressed(0, c) then return true end end
    return false
end

CreateThread(function()
    LocalPlayer.state:set('interactSel', nil, false)
    while true do
        local list = selectables()
        if #list > 1 then
            -- the wheel picks a line instead of a weapon while there is a choice
            for _, c in ipairs(SCROLL_DOWN) do DisableControlAction(0, c, true) end
            for _, c in ipairs(SCROLL_UP) do DisableControlAction(0, c, true) end
            DisableControlAction(0, ARROW_DOWN, true)
            DisableControlAction(0, ARROW_UP, true)
            local step = (pressed(SCROLL_DOWN) or IsDisabledControlJustPressed(0, ARROW_DOWN)) and 1
                or ((pressed(SCROLL_UP) or IsDisabledControlJustPressed(0, ARROW_UP)) and -1) or 0
            if step ~= 0 then
                local at = 1
                for i, r in ipairs(list) do if r == selected then at = i end end
                at = (at - 1 + step) % #list + 1
                setSelected(list[at])
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end
            if dirty then render() end
            Wait(0)
        else
            if dirty then render() end
            Wait(#order > 0 and 50 or 150)
        end
    end
end)

---------------------------------------------------------------------------
-- never stuck: a teleport (prison release, hospital, respawn, admin) or a death clears every line.
-- Scripts that still want their prompt put it back by themselves on their next check.
---------------------------------------------------------------------------
local function clearAll()
    if #order == 0 then return end
    entries, order = {}, {}
    fixSelection()
    dirty = true
end
exports('ClearAll', clearAll)

CreateThread(function()
    local last, wasDead = nil, false
    while true do
        Wait(250)
        local ped = PlayerPedId()
        local here = GetEntityCoords(ped)
        local dead = IsEntityDead(ped)
        if last and #order > 0 then
            local moved = #(here - last)
            local inCar = IsPedInAnyVehicle(ped, false)
            -- on foot nobody covers 25 m in a quarter second; in a car 120 m is far beyond any top speed.
            -- dying clears once (the moment it happens), so a death-screen prompt can still show after.
            if (not inCar and moved > 25.0) or moved > 120.0 or (dead and not wasDead) then clearAll() end
        end
        last, wasDead = here, dead
    end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', clearAll)
AddEventHandler('QBCore:Client:OnPlayerLoaded', clearAll)
AddEventHandler('playerSpawned', clearAll)

-- the player's own way out: /fixui clears every prompt on the screen
RegisterCommand('fixui', function()
    clearAll()
    SendNUIMessage({ action = 'list', items = {}, many = false })
end, false)
TriggerEvent('chat:addSuggestion', '/fixui', 'أزل أي رسالة عالقة على الشاشة')
