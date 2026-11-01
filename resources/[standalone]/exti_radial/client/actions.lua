-- EX_Tii radial menu: the small actions (use an item, a command, a route)

RAD = RAD or {}
RAD.actions = RAD.actions or {}

local function notify(text, kind) exports.qbx_core:Notify(text, kind or 'inform') end

-- show an item from your bag (ID card, driver's licence)
RAD.actions.useItem = function(item)
    RAD.close()
    local ok, slots = pcall(function() return exports.ox_inventory:Search('slots', item) end)
    local slot = ok and type(slots) == 'table' and slots[1]
    if not slot then
        notify(item == 'driver_license' and 'ليس معك رخصة قيادة' or 'ليس معك بطاقة هوية', 'error')
        return
    end
    exports.ox_inventory:useSlot(slot.slot)
end

-- a command of one of our scripts (the police / EMS tablet)
RAD.actions.command = function(name)
    RAD.close()
    SetTimeout(50, function() ExecuteCommand(name) end)
end

-- the gold line to a place (exti_gps)
RAD.actions['goto'] = function(arg)
    RAD.close()
    if GetResourceState('exti_gps') ~= 'started' then
        SetNewWaypoint(arg.x, arg.y)
        return
    end
    exports.exti_gps:GoTo(arg.x, arg.y, arg.z, arg.label)
end

-- an event of another script (the police menu): arg = { name = 'the:event', data = { ... } }
RAD.actions.event = function(arg)
    RAD.close()
    if type(arg) ~= 'table' or type(arg.name) ~= 'string' then return end
    local data = type(arg.data) == 'table' and arg.data or {}
    SetTimeout(50, function() TriggerEvent(arg.name, table.unpack(data)) end)
end
