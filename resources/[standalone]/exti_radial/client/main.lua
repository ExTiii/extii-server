-- EX_Tii radial menu: opening and closing the wheel, moving between menus, running what you pick.
-- The pieces: client/vehicle.lua (car menu), client/clothing.lua, client/walk.lua, client/blips.lua,
-- client/actions.lua (what each item does).

RAD = RAD or {}

local isOpen = false
local stack = {}      -- the menus you went through (to go back)
local current = nil   -- the items on the wheel right now

---------------------------------------------------------------------------
-- building the wheel
---------------------------------------------------------------------------
local function playerJob()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    return job and job.name or 'unemployed'
end

-- items can be a list or a function that makes the list now (seats, extras, walk styles...)
local function resolve(items)
    if type(items) == 'function' then items = items() end
    local out = {}
    for _, it in ipairs(items or {}) do
        local ok = true
        if it.when == 'vehicle' and not RAD.nearVehicle() then ok = false end
        if ok then out[#out + 1] = it end
    end
    return out
end

local function rootMenu()
    local items = {}
    for _, it in ipairs(Config.menu) do items[#items + 1] = it end
    if RAD.nearVehicle() then
        items[#items + 1] = { id = 'vehicle', label = 'المركبة', icon = 'car', items = RAD.vehicleMenu }
    end
    -- menus from other scripts (the police menu next to a person)
    for _, p in ipairs(Config.providers or {}) do
        if GetResourceState(p.resource) == 'started' then
            local ok, menu = pcall(function() return exports[p.resource][p.export]() end)
            if ok and type(menu) == 'table' and type(menu.items) == 'table' and #menu.items > 0 then
                items[#items + 1] = { id = p.resource, label = menu.label, icon = menu.icon, items = menu.items }
            end
        end
    end
    items[#items + 1] = { id = 'map', label = 'الخريطة', icon = 'map', items = RAD.blipMenu }
    local work = Config.work[playerJob()]
    if work then
        items[#items + 1] = { id = 'work', label = 'العمل', icon = 'briefcase', items = work }
    end
    return items
end

-- what the page gets (no functions, no args)
local function view(items)
    local out = {}
    for _, it in ipairs(items) do
        out[#out + 1] = { id = it.id, label = it.label, icon = it.icon, more = it.items ~= nil or it.menu == true, disabled = it.disabled == true }
    end
    return out
end

local function show(items, isSub)
    current = resolve(items)
    SendNUIMessage({ action = isSub and 'sub' or 'open', items = view(current) })
end

---------------------------------------------------------------------------
-- open / close
---------------------------------------------------------------------------
local function close()
    if not isOpen then return end
    isOpen = false
    stack, current = {}, nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end
RAD.close = close

local function canOpen()
    if not LocalPlayer.state.isLoggedIn then return false end
    if IsNuiFocused() or IsPauseMenuActive() then return false end
    if LocalPlayer.state.characterScreen then return false end
    if IsEntityDead(cache.ped) then return false end
    if LocalPlayer.state.cuffed then return false end -- cuffed by the police
    if LocalPlayer.state.exti_tied then return false end -- zip tied (a hostage)
    local down = LocalPlayer.state['qbx_medical:deathState']
    if down and down ~= 1 then return false end
    return true
end

local function open()
    if isOpen then return close() end
    if not canOpen() then return end
    isOpen = true
    stack = {}
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- you can keep walking / driving with the wheel open (like the old one)
    SetCursorLocation(0.64, 0.5)
    show(rootMenu(), false)
    -- no looking around or shooting while the wheel is open; close by itself if the game takes over
    CreateThread(function()
        local tick = 0
        while isOpen do
            Wait(0)
            DisableControlAction(0, 1, true)   -- look left/right
            DisableControlAction(0, 2, true)   -- look up/down
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 142, true) -- melee
            DisableControlAction(0, 257, true) -- attack 2
            DisablePlayerFiring(cache.playerId, true)
            tick += 1
            if tick % 15 == 0 and (IsPauseMenuActive() or IsEntityDead(cache.ped) or LocalPlayer.state.cuffed or LocalPlayer.state.exti_tied) then close() end
        end
    end)
end
RAD.open = open

-- the wheel is still open: draw it again (a toggle changed, a car door opened...)
function RAD.refresh()
    if not isOpen or not current then return end
    local top = stack[#stack]
    show(top and top.items or rootMenu(), #stack > 0)
end

-- ox_lib has its own wheel on Z: keep it off so only ours opens (again after an ox_lib restart)
lib.disableRadial(true)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ox_lib' then SetTimeout(500, function() lib.disableRadial(true) end) end
end)

lib.addKeybind({
    name = 'exti_radial',
    description = 'القائمة الدائرية',
    defaultKey = Config.key,
    onPressed = function() open() end,
})

---------------------------------------------------------------------------
-- the page tells us what was picked
---------------------------------------------------------------------------
RegisterNUICallback('select', function(data, cb)
    cb(1)
    if not isOpen or not current then return end
    local id = data and data.id
    local item
    for _, it in ipairs(current) do
        if it.id == id then item = it break end
    end
    if not item or item.disabled then return end
    if item.items then
        stack[#stack + 1] = { items = item.items }
        show(item.items, true)
        return
    end
    local fn = RAD.actions[item.action]
    if not fn then return close() end
    local result, extra = fn(item.arg, item)
    if result == 'menu' then
        -- the action made a submenu (walk styles)
        stack[#stack + 1] = { items = extra }
        show(extra, true)
    elseif result == 'stay' then
        RAD.refresh()
    else
        close()
    end
end)

RegisterNUICallback('back', function(_, cb)
    cb(1)
    if not isOpen then return end
    stack[#stack] = nil
    local top = stack[#stack]
    show(top and top.items or rootMenu(), #stack > 0)
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    close()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        pcall(lib.disableRadial, false)
    end
end)
