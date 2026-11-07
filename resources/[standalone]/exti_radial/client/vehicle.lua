-- EX_Tii radial menu: the Vehicle menu (doors, windows, seats, engine, extras, flipping a car)

RAD = RAD or {}

local function notify(text, kind) exports.qbx_core:Notify(text, kind or 'inform') end

-- the car you are in, or the closest one within reach
local function vehicle()
    if cache.vehicle then return cache.vehicle end
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.vehicleReach, false)
    return veh and veh ~= 0 and veh or nil
end
RAD.vehicle = vehicle

function RAD.nearVehicle()
    return vehicle() ~= nil
end

local function isDriver(veh)
    return cache.vehicle == veh and cache.seat == -1
end

-- you can open the doors of a car you are in, or an unlocked one next to you
local function canUseDoors(veh)
    if cache.vehicle == veh then return true end
    return GetVehicleDoorLockStatus(veh) <= 1
end

local DOORS = {
    { id = 'door0', label = 'باب السائق', icon = 'door-open', door = 0 },
    { id = 'door1', label = 'باب الراكب', icon = 'door-open', door = 1 },
    { id = 'door2', label = 'الخلفي الأيسر', icon = 'door-open', door = 2 },
    { id = 'door3', label = 'الخلفي الأيمن', icon = 'door-open', door = 3 },
    { id = 'door4', label = 'غطاء المحرك', icon = 'car', door = 4 },
    { id = 'door5', label = 'الصندوق', icon = 'car-rear', door = 5 },
}
local WINDOWS = {
    { id = 'win0', label = 'نافذة السائق', icon = 'window-maximize', window = 0 },
    { id = 'win1', label = 'نافذة الراكب', icon = 'window-maximize', window = 1 },
    { id = 'win2', label = 'الخلفية اليسرى', icon = 'window-maximize', window = 2 },
    { id = 'win3', label = 'الخلفية اليمنى', icon = 'window-maximize', window = 3 },
}
local SEATS = { [1] = 'مقعد السائق', [2] = 'مقعد الراكب', [3] = 'الخلفي الأيسر', [4] = 'الخلفي الأيمن' }

local function doorItems()
    local veh = vehicle()
    local out = {}
    if not veh then return out end
    for _, d in ipairs(DOORS) do
        if GetIsDoorValid(veh, d.door) then
            local openNow = GetVehicleDoorAngleRatio(veh, d.door) > 0.0
            out[#out + 1] = { id = d.id, label = d.label, icon = openNow and 'xmark' or d.icon, action = 'door', arg = d.door }
        end
    end
    return out
end

local function windowItems()
    local out = {}
    for _, w in ipairs(WINDOWS) do
        out[#out + 1] = { id = w.id, label = w.label, icon = w.icon, action = 'window', arg = w.window }
    end
    return out
end

local function seatItems()
    local veh = cache.vehicle
    local out = {}
    if not veh then return out end
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for i = 1, math.min(seats, 8) do
        local free = IsVehicleSeatFree(veh, i - 2)
        local mine = cache.seat == i - 2
        out[#out + 1] = { id = 'seat' .. i, label = SEATS[i] or ('مقعد %d'):format(i), icon = 'chair', action = 'seat', arg = i - 2, disabled = mine or not free }
    end
    return out
end

local function extraItems()
    local veh = cache.vehicle
    local out = {}
    if not veh then return out end
    for i = 1, 14 do
        if DoesExtraExist(veh, i) then
            local on = IsVehicleExtraTurnedOn(veh, i)
            out[#out + 1] = { id = 'extra' .. i, label = ('إضافة %d'):format(i) .. (on and ' ✓' or ''), icon = 'cubes', action = 'extra', arg = i }
        end
    end
    if #out == 0 then out[1] = { id = 'noextra', label = 'لا توجد إضافات', icon = 'cubes', disabled = true } end
    return out
end

function RAD.vehicleMenu()
    local veh = vehicle()
    local items = {}
    if not veh then return items end
    if canUseDoors(veh) then
        items[#items + 1] = { id = 'doors', label = 'الأبواب', icon = 'door-open', items = doorItems }
    end
    if cache.vehicle == veh then
        items[#items + 1] = { id = 'windows', label = 'النوافذ', icon = 'window-maximize', items = windowItems }
        items[#items + 1] = { id = 'seats', label = 'المقاعد', icon = 'chair', items = seatItems }
        if isDriver(veh) then
            local running = GetIsVehicleEngineRunning(veh)
            items[#items + 1] = { id = 'engine', label = running and 'إطفاء المحرك' or 'تشغيل المحرك', icon = 'power-off', action = 'engine' }
            items[#items + 1] = { id = 'extras', label = 'الإضافات', icon = 'cubes', items = extraItems }
        end
    else
        if IsEntityUpsidedown(veh) or GetEntityRoll(veh) > 75.0 or GetEntityRoll(veh) < -75.0 then
            items[#items + 1] = { id = 'flip', label = 'قلب المركبة', icon = 'rotate', action = 'flip' }
        end
    end
    items[#items + 1] = { id = 'keys', label = 'إعطاء المفتاح', icon = 'key', action = 'giveKeys' }
    items[#items + 1] = { id = 'takekeys', label = 'استرجاع المفاتيح', icon = 'key', action = 'takeKeys' }
    return items
end

---------------------------------------------------------------------------
-- the actions
---------------------------------------------------------------------------
RAD.actions = RAD.actions or {}

RAD.actions.door = function(door)
    local veh = vehicle()
    if not veh or not canUseDoors(veh) then notify('لا توجد مركبة قريبة', 'error') return end
    if not NetworkHasControlOfEntity(veh) then NetworkRequestControlOfEntity(veh) end
    if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
        SetVehicleDoorShut(veh, door, false)
    else
        SetVehicleDoorOpen(veh, door, false, false)
    end
    return 'stay'
end

RAD.actions.window = function(window)
    local veh = cache.vehicle
    if not veh then notify('يجب أن تكون داخل المركبة', 'error') return end
    -- the game has no "is it down?" for windows, so we remember it per car
    RAD.windows = RAD.windows or {}
    local key = tostring(NetworkGetNetworkIdFromEntity(veh)) .. ':' .. window
    if RAD.windows[key] then
        RollUpWindow(veh, window)
        RAD.windows[key] = nil
    else
        RollDownWindow(veh, window)
        RAD.windows[key] = true
    end
    return 'stay'
end

lib.onCache('vehicle', function() RAD.windows = {} end)

RAD.actions.seat = function(seat)
    local veh = cache.vehicle
    if not veh then notify('يجب أن تكون داخل المركبة', 'error') return end
    if not IsVehicleSeatFree(veh, seat) then notify('المقعد مشغول', 'error') return end
    if GetEntitySpeed(veh) * 3.6 > 100.0 then notify('المركبة سريعة جدًا لتغيير المقعد', 'error') return end
    SetPedIntoVehicle(cache.ped, veh, seat)
end

RAD.actions.engine = function()
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then notify('يجب أن تكون السائق', 'error') return end
    local running = GetIsVehicleEngineRunning(veh)
    SetVehicleEngineOn(veh, not running, false, true)
    return 'stay'
end

RAD.actions.extra = function(i)
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then notify('يجب أن تكون السائق', 'error') return end
    if not DoesExtraExist(veh, i) then return 'stay' end
    SetVehicleAutoRepairDisabled(veh, true) -- turning an extra on would otherwise repair the car
    SetVehicleExtra(veh, i, IsVehicleExtraTurnedOn(veh, i))
    return 'stay'
end

RAD.actions.flip = function()
    local veh = vehicle()
    if not veh or cache.vehicle then notify('اخرج من المركبة أولًا', 'error') return end
    RAD.close()
    if lib.progressBar({
        duration = Config.flipTime,
        label = 'تقلب المركبة...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    }) then
        if not DoesEntityExist(veh) then return end
        if not NetworkHasControlOfEntity(veh) then
            NetworkRequestControlOfEntity(veh)
            local tries = 0
            while not NetworkHasControlOfEntity(veh) and tries < 50 do Wait(20) tries += 1 end
        end
        SetVehicleOnGroundProperly(veh)
        notify('قلبت المركبة', 'success')
    end
end

RAD.actions.giveKeys = function()
    RAD.close()
    local ok, err = lib.callback.await('exti_radial:server:giveKeys', false)
    if ok then
        notify('أعطيت المفتاح', 'success')
    elseif err == 'vehicle' then
        notify('لا توجد مركبة قريبة', 'error')
    elseif err == 'nokeys' then
        notify('نظام المفاتيح غير مفعّل', 'error')
    elseif err == 'keys' then
        notify('ليس معك مفتاح هذه المركبة', 'error')
    elseif err == 'nobody' then
        notify('لا يوجد أحد قريب منك', 'error')
    end
end

RAD.actions.takeKeys = function()
    RAD.close()
    local ok, err = lib.callback.await('exti_radial:server:takeKeys', false)
    if ok then
        notify(err and err > 1 and ('استرجعت %d مفاتيح لمركبتك'):format(err) or 'استرجعت مفتاح مركبتك', 'success')
    elseif err == 'vehicle' then
        notify('لا توجد مركبة قريبة', 'error')
    elseif err == 'owner' then
        notify('هذه المركبة ليست ملكك', 'error')
    elseif err == 'nobody' then
        notify('لم تعطِ مفتاح هذه المركبة لأحد', 'error')
    elseif err == 'nokeys' then
        notify('نظام المفاتيح غير مفعّل', 'error')
    end
end

-- EX_Tii: /unhook in a tow truck lets go of the car on the hook (GTA's own key is hard to find)
RegisterCommand('unhook', function()
    local tow = cache.vehicle
    if not tow or not IsVehicleModel(tow, `towtruck`) and not IsVehicleModel(tow, `towtruck2`) then
        return notify('اجلس في شاحنة السحب أولًا', 'error')
    end
    local car = GetEntityAttachedToTowTruck(tow)
    if not car or car == 0 then return notify('لا توجد مركبة على الخطّاف', 'error') end
    DetachVehicleFromTowTruck(tow, car)
    notify('أفلتّ المركبة من الخطّاف', 'success')
end, false)
