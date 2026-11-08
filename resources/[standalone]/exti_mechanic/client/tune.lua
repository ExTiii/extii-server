-- =====================================================================
-- EX_Tii Mechanic (client): TUNING — the customer's menu on a tuning bay.
-- He sits in his own car on the bay and presses E: the menu shows everything his car can take
-- (performance levels, turbo, paint, wheels, body parts, neon, xenon, tint, plate), every pick is
-- shown on the car straight away, the camera moves to the part. Confirm = pay and send the order
-- to the mechanics; the car goes back to how it was until a mechanic installs it.
-- =====================================================================

local T = Config.tuning

local ERR = {
    not_owner = 'التعديل لسيارتك المسجّلة باسمك فقط', no_mechanic = 'لا يوجد ميكانيكي في الخدمة الآن، عد لاحقًا',
    not_bay = 'ادخل بالسيارة إلى منصة التعديل', driver = 'اجلس مكان السائق', no_money = 'لا تملك المبلغ في البنك ولا نقدًا',
    has_order = 'لسيارتك طلب تعديل مفتوح بالفعل', empty = 'لم تختر أي تعديل', too_many = 'تعديلات كثيرة في طلب واحد',
    wait = 'انتظر لحظة', started = 'بدأ الميكانيكي التركيب، لا يمكن الإلغاء الآن', shop_money = 'تعذّر الإرجاع الآن، كلّم الميكانيكي',
    gone = 'لم يعد الطلب موجودًا',
}
local function fail(code) lib.notify({ type = 'error', description = ERR[code] or 'حدث خطأ، حاول مرة أخرى' }) end

local PERF = {}
for _, p in ipairs(T.perf) do PERF[p.key] = p end

local function label(text)
    if not text or text == '' or text == 'NULL' then return nil end
    local l = GetLabelText(text)
    if not l or l == 'NULL' or l == '' then return nil end
    return l
end

---------------------------------------------------------------------------
-- what the car can take (sent to the menu)
---------------------------------------------------------------------------
local WHEEL_TYPES = {
    { 0, 'رياضي' }, { 1, 'مسل' }, { 2, 'لوورايدر' }, { 3, 'دفع رباعي' }, { 4, 'أوفرود' }, { 5, 'تونر' },
    { 7, 'فاخر' }, { 8, 'بينيز الأصلي' }, { 9, 'بينيز الخاص' }, { 11, 'شارع' }, { 12, 'حلبة' },
}

local function catalog(veh)
    SetVehicleModKit(veh, 0)
    local model = GetEntityModel(veh)
    local bike = IsThisModelABike(model)
    local c = { perf = {}, body = {}, bike = bike }
    for _, p in ipairs(T.perf) do
        local n = GetNumVehicleMods(veh, p.mod)
        if n > 0 then c.perf[#c.perf + 1] = { key = p.key, label = p.label, n = n, cur = GetVehicleMod(veh, p.mod) } end
    end
    c.turbo = IsToggleModOn(veh, 18)
    for _, b in ipairs(T.body) do
        local n = GetNumVehicleMods(veh, b.mod)
        if n > 0 then
            local opts = {}
            for i = 0, math.min(n, 200) - 1 do
                opts[#opts + 1] = label(GetModTextLabel(veh, b.mod, i)) or ('%s %d'):format(b.label, i + 1)
            end
            c.body[#c.body + 1] = { mod = b.mod, label = b.label, cur = GetVehicleMod(veh, b.mod), opts = opts, price = b.price or 'body' }
        end
    end
    -- paint
    local t1 = GetVehicleModColor_1(veh)
    local t2 = GetVehicleModColor_2(veh)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(veh)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(veh)
    local pearl, wheelColor = GetVehicleExtraColours(veh)
    c.paint1 = { t = math.max(0, math.min(5, t1 or 0)), c = { r1, g1, b1 } }
    c.paint2 = { t = math.max(0, math.min(5, t2 or 0)), c = { r2, g2, b2 } }
    c.pearl, c.wheelColor = pearl, wheelColor
    -- wheels
    c.wheels = { t = GetVehicleWheelType(veh), i = GetVehicleMod(veh, 23), bike = bike }
    if bike then
        c.wheelTypes = { { 6, 'دراجة' } }
    else
        c.wheelTypes = {}
        for _, w in ipairs(WHEEL_TYPES) do c.wheelTypes[#c.wheelTypes + 1] = { w[1], w[2] } end
        if GetVehicleClass(veh) == 22 then c.wheelTypes[#c.wheelTypes + 1] = { 10, 'فورمولا' } end
    end
    -- lights and the rest
    local neon = false
    for i = 0, 3 do if IsVehicleNeonLightEnabled(veh, i) then neon = true end end
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)
    c.neon = { on = neon, c = { nr, ng, nb } }
    local xc = GetVehicleXenonLightsColor(veh)
    if not xc or xc < -1 or xc > 12 then xc = -1 end
    c.xenon = { on = IsToggleModOn(veh, 22), c = xc }
    c.tint = math.max(0, GetVehicleWindowTint(veh))
    c.plate = GetVehicleNumberPlateTextIndex(veh)
    return c
end

---------------------------------------------------------------------------
-- the live preview on the car
---------------------------------------------------------------------------
local veh, orig, frozen, cam = nil, nil, false, nil
local origEngine = nil -- the engine the car has now (swap), for the sound when the menu closes
local revving = false
local radioWas = nil -- the station the driver had (given back when the menu closes)

-- the radio off: the player's own station (the car's switch alone is not enough for the driver)
local function radioOff(v)
    SetVehicleRadioEnabled(v, false)
    SetVehRadioStation(v, 'OFF')
    SetRadioToStationName('OFF')
end
local view = { a = 210.0, ta = 210.0, d = 5.5, td = 5.5, h = 1.2, th = 1.2, inside = false }

local function preview(k, v)
    if not veh or not DoesEntityExist(veh) then return end
    SetVehicleModKit(veh, 0)
    if PERF[k] then
        SetVehicleMod(veh, PERF[k].mod, math.tointeger(v) or -1, false)
    elseif k == 'turbo' then
        ToggleVehicleMod(veh, 18, v == true)
    elseif k == 'body' and type(v) == 'table' then
        SetVehicleMod(veh, math.tointeger(v.mod) or 0, math.tointeger(v.i) or -1, false)
    elseif (k == 'paint1' or k == 'paint2') and type(v) == 'table' and type(v.c) == 'table' then
        local t = math.tointeger(v.t) or 0
        if k == 'paint1' then
            local pearl = GetVehicleExtraColours(veh)
            SetVehicleModColor_1(veh, t, 0, pearl)
            SetVehicleCustomPrimaryColour(veh, v.c[1], v.c[2], v.c[3])
        else
            SetVehicleModColor_2(veh, t, 0)
            SetVehicleCustomSecondaryColour(veh, v.c[1], v.c[2], v.c[3])
        end
    elseif k == 'pearl' then
        local _, w = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, math.tointeger(v) or 0, w)
    elseif k == 'wheelColor' then
        local p = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, p, math.tointeger(v) or 0)
    elseif k == 'wheels' and type(v) == 'table' then
        SetVehicleWheelType(veh, math.tointeger(v.t) or 0)
        SetVehicleMod(veh, 23, math.tointeger(v.i) or -1, false)
        if v.bike then SetVehicleMod(veh, 24, math.tointeger(v.i) or -1, false) end
    elseif k == 'tint' then
        SetVehicleWindowTint(veh, math.tointeger(v) or 0)
    elseif k == 'neon' and type(v) == 'table' then
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, v.on == true) end
        if type(v.c) == 'table' then SetVehicleNeonLightsColour(veh, v.c[1], v.c[2], v.c[3]) end
    elseif k == 'xenon' and type(v) == 'table' then
        ToggleVehicleMod(veh, 22, v.on == true)
        SetVehicleXenonLightsColor(veh, math.tointeger(v.c) or -1)
    elseif k == 'plate' then
        SetVehicleNumberPlateTextIndex(veh, math.tointeger(v) or 0)
    elseif k == 'lights' then
        SetVehicleLights(veh, v == true and 2 or 0)
    elseif k == 'swap' then
        local id = type(v) == 'string' and v or 'stock'
        ForceVehicleEngineAudio(veh, id == 'stock' and GetEntityArchetypeName(veh) or id)
    elseif k == 'rev' then
        -- listen to the engine: a short rev in place (the car stays frozen)
        if revving then return end
        revving = true
        CreateThread(function()
            local v2 = veh
            SetVehicleEngineOn(v2, true, true, false)
            local t0 = GetGameTimer()
            while v2 and DoesEntityExist(v2) and GetGameTimer() - t0 < 3200 do
                radioOff(v2) -- starting the engine starts the radio: keep it off
                local k2 = (GetGameTimer() - t0) / 3200
                SetVehicleCurrentRpm(v2, k2 < 0.6 and 0.2 + k2 / 0.6 * 0.8 or 1.0 - (k2 - 0.6) / 0.4 * 0.8)
                Wait(0)
            end
            if v2 and DoesEntityExist(v2) then SetVehicleEngineOn(v2, false, true, true) end
            revving = false
        end)
    elseif k == 'hood' then
        if v == true then SetVehicleDoorOpen(veh, 4, false, false) else SetVehicleDoorShut(veh, 4, false) end
    end
end

---------------------------------------------------------------------------
-- the camera: goes round the car, moves to the part being picked
---------------------------------------------------------------------------
local VIEWS = {
    front = { a = 0.0, d = 1.0, h = 0.8 }, rear = { a = 180.0, d = 1.0, h = 0.9 }, side = { a = 270.0, d = 1.05, h = 0.9 },
    wheel = { a = 300.0, d = 0.62, h = 0.35 }, top = { a = 200.0, d = 1.1, h = 2.6 }, three = { a = 210.0, d = 1.1, h = 1.2 },
}

local function size()
    local min, max = GetModelDimensions(GetEntityModel(veh))
    return math.max(2.5, #(max - min))
end

local function setView(name)
    if name == 'inside' then view.inside = true return end
    local v = VIEWS[name] or VIEWS.three
    view.inside = false
    -- the shortest way round
    local a = v.a
    while a - view.a > 180 do a = a - 360 end
    while view.a - a > 180 do a = a + 360 end
    view.ta, view.td, view.th = a, v.d * size(), v.h
end

local function startCam()
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    view.a, view.ta = 210.0, 210.0
    view.d, view.td = 1.1 * size(), 1.1 * size()
    view.h, view.th = 1.2, 1.2
    SetCamFov(cam, 50.0)
    RenderScriptCams(true, true, 600, true, false)
    CreateThread(function()
        while cam do
            if veh and DoesEntityExist(veh) then
                view.a = view.a + (view.ta - view.a) * 0.12
                view.d = view.d + (view.td - view.d) * 0.12
                view.h = view.h + (view.th - view.h) * 0.12
                if view.inside then
                    local p = GetOffsetFromEntityInWorldCoords(veh, 0.25, -0.35, 0.62)
                    local look = GetOffsetFromEntityInWorldCoords(veh, -0.15, 1.2, 0.35)
                    SetCamCoord(cam, p.x, p.y, p.z)
                    PointCamAtCoord(cam, look.x, look.y, look.z)
                else
                    local r = math.rad(view.a)
                    local p = GetOffsetFromEntityInWorldCoords(veh, math.sin(r) * view.d, math.cos(r) * view.d, view.h)
                    SetCamCoord(cam, p.x, p.y, p.z)
                    PointCamAtEntity(cam, veh, 0.0, 0.0, 0.1, true)
                end
            end
            Wait(0)
        end
    end)
end

local function stopCam()
    if cam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
end

---------------------------------------------------------------------------
-- open / close
---------------------------------------------------------------------------
local open = false

local function close(keep)
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tune', open = false })
    stopCam()
    if veh and DoesEntityExist(veh) then
        if orig and not keep then lib.setVehicleProperties(veh, orig) end
        ForceVehicleEngineAudio(veh, (origEngine and origEngine ~= 'stock') and origEngine or GetEntityArchetypeName(veh))
        SetVehicleLights(veh, 0)
        SetVehicleRadioEnabled(veh, true)
        if radioWas and radioWas ~= '' and radioWas ~= 'OFF' then SetVehRadioStation(veh, radioWas) end
        radioWas = nil
        if frozen then FreezeEntityPosition(veh, false) end
    end
    veh, orig, frozen = nil, nil, false
end

-- an order is already open for the car: what is in it, and cancel while nothing is installed
local function openOrder(netId, o)
    local options = {
        { title = ('طلب التعديل #%d · $%s'):format(o.id, o.total), icon = 'receipt', readOnly = true,
          description = o.mname and ('الميكانيكي: %s'):format(o.mname) or 'بانتظار ميكانيكي يستلمه' },
    }
    for _, l in ipairs(o.lines) do
        options[#options + 1] = { title = (l.done and '✓ ' or '') .. l.label, description = l.done and 'تم التركيب' or 'بانتظار التركيب',
            icon = l.done and 'circle-check' or 'hourglass-half', iconColor = l.done and '#3ddc97' or '#20c997', readOnly = true }
    end
    if not o.started then
        options[#options + 1] = { title = 'إلغاء الطلب واسترجاع المبلغ', icon = 'xmark', iconColor = '#ff6b6b',
            onSelect = function()
                local ok = lib.alertDialog({ header = 'إلغاء طلب التعديل', content = ('يرجع لك $%s في البنك.'):format(o.total), centered = true, cancel = true,
                    labels = { confirm = 'نعم، ألغِ الطلب', cancel = 'رجوع' } })
                if ok ~= 'confirm' then return end
                local res, err = lib.callback.await('exti_mechanic:server:tuneCustomerCancel', false, netId)
                if not res then return fail(err) end
                lib.notify({ type = 'success', description = ('أُلغي الطلب ورجع لك $%s'):format(res.refunded) })
            end }
    end
    lib.registerContext({ id = 'exti_mechanic_tune_open', title = 'طلب التعديل', options = options })
    lib.showContext('exti_mechanic_tune_open')
end

function MEC.openTune()
    if open then return end
    local v = cache.vehicle
    if not v or GetPedInVehicleSeat(v, -1) ~= cache.ped then return fail('driver') end
    if not NetworkGetEntityIsNetworked(v) then return fail('not_owner') end
    local netId = NetworkGetNetworkIdFromEntity(v)
    local res, err = lib.callback.await('exti_mechanic:server:tuneOpen', false, netId)
    if not res then return fail(err) end
    if res.open then return openOrder(netId, res.open) end
    if GetEntitySpeed(v) > 1.0 then return lib.notify({ type = 'error', description = 'توقف تمامًا على المنصة أولًا' }) end
    veh = v
    orig = lib.getVehicleProperties(veh)
    SetVehicleEngineOn(veh, false, true, true)
    -- no radio music over the engine sounds while picking
    radioWas = GetPlayerRadioStationName()
    radioOff(veh)
    FreezeEntityPosition(veh, true)
    frozen = true
    open = true
    local c = catalog(veh)
    -- nitro and engine swap come from the server (they are not in the game's car properties)
    local m = type(res.mods) == 'table' and res.mods or {}
    c.nitro = m.nitro == true
    c.swap = m.engine or 'stock'
    c.engines = res.engines or {}
    origEngine = c.swap
    -- the saved car knows the performance better (the server counts the parts from it)
    for _, p in ipairs(c.perf) do
        local s = res.stored and res.stored[p.key]
        if s ~= nil then p.saved = s end
    end
    startCam()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'tune', open = true,
        data = { plate = res.plate, model = label(GetDisplayNameFromVehicleModel(GetEntityModel(veh))) or GetDisplayNameFromVehicleModel(GetEntityModel(veh)), prices = res.prices,
            bank = res.bank, cash = res.cash, car = c },
    })
    -- the car can not drive off while the menu is open; leaving the car closes it
    CreateThread(function()
        while open do
            if not veh or not DoesEntityExist(veh) or cache.vehicle ~= veh or MEC.isDown() then close() break end
            Wait(500)
        end
    end)
end

RegisterNUICallback('tunePreview', function(data, cb)
    cb(true)
    if open and type(data) == 'table' then preview(data.k, data.v) end
end)

RegisterNUICallback('tuneCam', function(data, cb)
    cb(true)
    if not open or type(data) ~= 'table' then return end
    if data.view then setView(data.view) end
    if tonumber(data.rot) then view.inside = false view.ta = view.ta + tonumber(data.rot) end
    if tonumber(data.zoom) then view.td = math.max(0.45 * size(), math.min(1.6 * size(), view.td + tonumber(data.zoom))) end
end)

-- the wheels of one kind (names), and the car shows the first one
RegisterNUICallback('tuneWheels', function(data, cb)
    if not open or type(data) ~= 'table' then return cb({ n = 0, list = {} }) end
    local t = math.tointeger(tonumber(data.t)) or 0
    SetVehicleModKit(veh, 0)
    SetVehicleWheelType(veh, t)
    local n = GetNumVehicleMods(veh, 23)
    local list = {}
    for i = 0, math.min(n, 400) - 1 do
        list[#list + 1] = label(GetModTextLabel(veh, 23, i)) or ('جنط %d'):format(i + 1)
    end
    cb({ n = n, list = list })
end)

RegisterNUICallback('tuneClose', function(_, cb)
    cb(true)
    close()
end)

RegisterNUICallback('tuneConfirm', function(data, cb)
    if not open or type(data) ~= 'table' then return cb({ ok = false, e = 'failed' }) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local cur = type(data.cur) == 'table' and data.cur or {}
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local res, err = lib.callback.await('exti_mechanic:server:tuneOrder', false, netId, data.changes, cur, model)
    if not res then return cb({ ok = false, e = err or 'failed', msg = ERR[err] }) end
    cb({ ok = true, r = res })
    close()
    lib.notify({ type = 'success', duration = 9000, description = ('تم الطلب #%d ودفعت $%s. الميكانيكي سيركّب التعديلات، اترك السيارة في الورشة'):format(res.id, res.total) })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then close() end
end)
