-- EX_Tii: repair kits that players can use on a car next to them (moved here from the old mechanic job)
-- repairkit         -> engine back to at least 65% so the car drives again (body stays damaged)
-- advancedrepairkit -> full repair (engine + body)

-- EX_Tii (Moe): someone hands you an item: a window asks you to accept or refuse (15 seconds, then it is a refusal)
lib.callback.register('exti_tools:give:ask', function(data)
    data = data or {}
    local answered = false
    CreateThread(function()
        local t = GetGameTimer()
        while not answered and GetGameTimer() - t < 15000 do Wait(100) end
        if not answered then pcall(lib.closeAlertDialog) end
    end)
    local r = lib.alertDialog({
        header = 'عرض غرض',
        content = ('**%s** يعطيك **%d × %s**.\n\nتقبل؟'):format(data.from or 'شخص', tonumber(data.count) or 1, data.label or 'غرض'),
        centered = true, cancel = true,
        labels = { confirm = 'أقبل', cancel = 'أرفض' },
    })
    answered = true
    return r == 'confirm'
end)

-- repair kits: the old mechanic job had these; while it is still on the server it keeps doing them
if GetResourceState('qbx_mechanicjob'):find('start') then return end

local KITS = {
    repairkit = { minEngine = 650.0, full = false, duration = 10000, label = 'جارٍ إصلاح المحرك...' },
    advancedrepairkit = { minEngine = 1000.0, full = true, duration = 20000, label = 'جارٍ إصلاح المركبة بالكامل...' }, -- EX_Tii: 20 s (normal kit 10 s)
}

local function notify(text, kind)
    exports.qbx_core:Notify(text, kind or 'inform')
end

local function takeControl(vehicle)
    if NetworkHasControlOfEntity(vehicle) then return true end
    NetworkRequestControlOfEntity(vehicle)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(vehicle)
    end
    return NetworkHasControlOfEntity(vehicle)
end

lib.callback.register('exti_repairkit:client:use', function(itemName)
    local kit = KITS[itemName]
    if not kit then return false end

    if cache.vehicle then
        notify('اخرج من المركبة أولًا', 'error')
        return false
    end

    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3.5, false)
    if not vehicle then
        notify('لا توجد مركبة قريبة منك', 'error')
        return false
    end

    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    if engine >= kit.minEngine and (not kit.full or body >= 999.0) then
        if not kit.full and (engine < 999.0 or body < 999.0) then
            -- EX_Tii: the engine already works; dents and the rest need the advanced kit
            notify('المحرك يعمل جيدًا. للإصلاح الكامل (المحرك والهيكل) استخدم عدة إصلاح متطورة من متجر العدد', 'inform')
        else
            notify('هذه المركبة لا تحتاج إلى إصلاح', 'inform')
        end
        return false
    end

    TaskTurnPedToFaceEntity(cache.ped, vehicle, 1000)
    Wait(1000)
    SetVehicleDoorOpen(vehicle, 4, false, false)

    local done = lib.progressBar({
        duration = kit.duration,
        label = kit.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })

    if not done then
        SetVehicleDoorShut(vehicle, 4, false)
        notify('تم إلغاء الإصلاح', 'error')
        return false
    end

    if not DoesEntityExist(vehicle) or #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle)) > 5.0 then
        notify('ابتعدت عن المركبة', 'error')
        return false
    end

    -- EX_Tii: someone sitting in the driver seat keeps control of the car; the repair would not
    -- stick and the kit would be gone, so stop here and keep the kit
    if not takeControl(vehicle) then
        SetVehicleDoorShut(vehicle, 4, false)
        notify('لا يمكن الإصلاح الآن: يجب أن يخرج السائق من المركبة', 'error')
        return false
    end
    if kit.full then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
    else
        SetVehicleEngineHealth(vehicle, math.max(GetVehicleEngineHealth(vehicle), kit.minEngine))
        if GetVehiclePetrolTankHealth(vehicle) < 650.0 then SetVehiclePetrolTankHealth(vehicle, 650.0) end
    end
    SetVehicleUndriveable(vehicle, false)
    SetVehicleDoorShut(vehicle, 4, false)

    notify(kit.full and 'تم إصلاح المركبة بالكامل' or 'تم إصلاح المحرك، يمكنك القيادة الآن', 'success')
    return true
end)
