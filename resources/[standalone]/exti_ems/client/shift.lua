-- =====================================================================
-- EX_Tii EMS (client): starting the shift like the video — the clock in / out terminal (drag
-- your employee card onto the sensor), the cloakroom (one click to wear a uniform; the leader
-- designs them in the clothes editor), and /emsspots for admins.
-- =====================================================================

local ui = nil -- { kind = 'duty'|'cloak', hospital, coords }

local function gender()
    return GetEntityModel(cache.ped) == `mp_f_freemode_01` and 'female' or 'male'
end

local function gameTime()
    return { h = GetClockHours(), m = GetClockMinutes() }
end

local function closeUI(tellPage)
    if not ui then return end
    local kind = ui.kind
    ui = nil
    SetNuiFocus(false, false)
    if tellPage then SendNUIMessage({ action = kind, open = false }) end
end
EMS.closeShiftUI = closeUI

-- walking away / going down / no longer a medic closes the screen
CreateThread(function()
    while true do
        if ui and not ui.editing then
            if EMS.isDown() or not EMS.isMedic() or #(GetEntityCoords(cache.ped) - ui.coords) > Config.reachPoint + 2.5 then
                closeUI(true)
            elseif ui.kind == 'duty' then
                SendNUIMessage({ action = 'duty', time = gameTime() })
            end
        end
        Wait(ui and 1000 or 1500)
    end
end)

---------------------------------------------------------------------------
-- the clock in / out terminal at the reception computer
---------------------------------------------------------------------------
function EMS.openDuty(spot)
    if ui then return end
    local info = lib.callback.await('exti_ems:server:dutyInfo', false, spot.hospital)
    if not info then return EMS.error('too_far') end
    ui = { kind = 'duty', hospital = spot.hospital, coords = spot.coords }
    info.time = gameTime()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'duty', open = true, data = info })
end

RegisterNUICallback('dutySwipe', function(_, cb)
    if not ui or ui.kind ~= 'duty' then return cb({ ok = false }) end
    local res = lib.callback.await('exti_ems:server:swipe', false, ui.hospital) or { ok = false }
    res.time = gameTime()
    cb(res)
end)

RegisterNUICallback('dutyClose', function(_, cb)
    cb(true)
    if ui and ui.kind == 'duty' then closeUI(false) end
end)

---------------------------------------------------------------------------
-- the cloakroom
---------------------------------------------------------------------------
-- put the saved clothes on (only the clothes: the face and hair stay yours)
local function wear(clothes)
    if type(clothes) ~= 'table' then return end
    local ped = cache.ped
    for _, c in ipairs(clothes.components or {}) do
        if c.component_id ~= 0 and c.component_id ~= 2 then
            SetPedComponentVariation(ped, c.component_id, c.drawable, c.texture, 0)
        end
    end
    for _, p in ipairs(clothes.props or {}) do
        if p.drawable == -1 then
            ClearPedProp(ped, p.prop_id)
        else
            SetPedPropIndex(ped, p.prop_id, p.drawable, p.texture, true)
        end
    end
end

-- keep = { gender, clothes, key, chosen }: coming back from the clothes editor with the form kept
local function openCloak(spot, keep)
    local data, err = lib.callback.await('exti_ems:server:cloakroom', false, spot.hospital, keep and keep.gender or gender())
    if not data then ui = nil return EMS.error(err) end
    ui = { kind = 'cloak', hospital = spot.hospital, coords = spot.coords, gender = data.gender }
    if keep then
        ui.clothes, ui.clothesKey = keep.clothes, keep.key
        data.keepForm = true
        data.clothesChosen = keep.chosen
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'cloak', open = true, data = data })
end

function EMS.openCloakroom(spot)
    if ui then return end
    openCloak(spot)
end

-- the leader looks at the men's / women's uniforms
RegisterNUICallback('cloakGender', function(data, cb)
    local u = ui
    if not u or u.kind ~= 'cloak' or u.editing then return cb({}) end
    local view = lib.callback.await('exti_ems:server:cloakroom', false, u.hospital, data and data.gender == 'female' and 'female' or 'male')
    if ui ~= u or not view then return cb({}) end
    u.gender, u.clothes, u.clothesKey = view.gender, nil, nil
    cb(view)
end)

RegisterNUICallback('cloakWear', function(data, cb)
    cb(true)
    local u = ui
    if not u or u.kind ~= 'cloak' then return end
    local clothes = lib.callback.await('exti_ems:server:outfitClothes', false, u.hospital, u.gender, tonumber(data and data.id))
    if clothes then wear(clothes) else EMS.error('failed') end
end)

RegisterNUICallback('cloakCivilian', function(_, cb)
    cb(true)
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end)

-- the leader picks the clothes in the clothes editor (only clothes, never the face or hair);
-- this screen comes back when they press save there
local EDITOR = {
    ped = false, headBlend = false, faceFeatures = false, headOverlays = false, tattoos = false,
    components = true, props = true, enableExit = true, hasTracker = false, automaticFade = false,
    componentConfig = { masks = true, upperBody = true, lowerBody = true, bags = true, shoes = true, scarfAndChains = true, bodyArmor = true, shirts = true, decals = true, jackets = true },
    propConfig = { hats = true, glasses = true, ear = true, watches = true, bracelets = true },
}

-- which form the picked clothes belong to (a new uniform, or editing uniform N)
local function formKey(mode, id)
    return ('%s:%s'):format(mode == 'edit' and 'edit' or 'new', mode == 'edit' and tostring(tonumber(id)) or '')
end

RegisterNUICallback('cloakEditor', function(data, cb)
    cb(true)
    local u = ui
    if not u or u.kind ~= 'cloak' or u.editing then return end
    u.editing = true -- one editor at a time
    local spot = { hospital = u.hospital, coords = u.coords }
    local key = formKey(data and data.mode, data and data.id)
    local before = u.clothesKey == key and u.clothes or nil
    -- editing a uniform: start from it
    if data and data.mode == 'edit' and tonumber(data.id) and not before then
        local clothes = lib.callback.await('exti_ems:server:outfitClothes', false, u.hospital, u.gender, tonumber(data.id))
        if clothes then wear(clothes) end
    end
    if ui ~= u then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'cloak', open = false })
    local back = { gender = u.gender }
    local ok = pcall(function()
        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
            CreateThread(function()
                if ui == u then ui = nil end
                Wait(300)
                if appearance and type(appearance.components) == 'table' then
                    local picked = { components = {}, props = {} }
                    for _, c in ipairs(appearance.components) do
                        if c.component_id ~= 0 and c.component_id ~= 2 then picked.components[#picked.components + 1] = c end
                    end
                    for _, p in ipairs(appearance.props or {}) do picked.props[#picked.props + 1] = p end
                    back.clothes, back.key, back.chosen = picked, key, true
                else
                    back.clothes, back.key, back.chosen = before, before and key or nil, before ~= nil
                end
                openCloak(spot, back)
            end)
        end, EDITOR)
    end)
    if not ok then
        if ui == u then ui = nil end
        EMS.notify('error', 'محرر الملابس غير متاح الآن')
        back.clothes, back.key, back.chosen = before, before and key or nil, before ~= nil
        openCloak(spot, back)
    end
end)

RegisterNUICallback('cloakSave', function(data, cb)
    local u = ui
    if not u or u.kind ~= 'cloak' or type(data) ~= 'table' then return cb({ ok = false }) end
    local key = formKey(data.mode, data.id)
    local res = lib.callback.await('exti_ems:server:outfitSave', false, u.hospital, {
        mode = data.mode, id = tonumber(data.id), label = data.label, grades = data.grades,
        gender = u.gender, clothes = (data.clothes and u.clothesKey == key) and u.clothes or nil,
    }) or { ok = false }
    if res.ok and ui == u then u.clothes, u.clothesKey = nil, nil end
    cb(res)
end)

RegisterNUICallback('cloakDelete', function(data, cb)
    local u = ui
    if not u or u.kind ~= 'cloak' then return cb({}) end
    cb(lib.callback.await('exti_ems:server:outfitDelete', false, u.hospital, u.gender, tonumber(data and data.id)) or {})
end)

RegisterNUICallback('cloakClose', function(_, cb)
    cb(true)
    if ui and ui.kind == 'cloak' then closeUI(false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ui then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------------
-- /emsspots (admins): move a spot to where you stand
---------------------------------------------------------------------------
local KIND_LABEL = {
    duty = 'جهاز تسجيل الدخول (الاستقبال)',
    cloakroom = 'غرفة الملابس',
    storage = 'مخزن الإسعاف',
    locker = 'الخزانة الشخصية',
    garage = 'مرآب السيارات (مكان الزر)',
    garageSpawn = 'مرآب السيارات (مكان ظهور السيارة)',
    heli = 'مهبط المروحية (مكان الزر)',
    heliSpawn = 'مهبط المروحية (مكان ظهور المروحية)',
}
local KIND_ORDER = { 'duty', 'cloakroom', 'storage', 'locker', 'garage', 'garageSpawn', 'heli', 'heliSpawn' }

local function spotNow(h, kind)
    if kind == 'garageSpawn' then return h.garage and h.garage.spawn end
    if kind == 'heliSpawn' then return h.heli and h.heli.spawn end
    if kind == 'garage' then return h.garage and h.garage.coords end
    if kind == 'heli' then return h.heli and h.heli.coords end
    return h[kind]
end

local function kindMenu(hospital, kind)
    local h = Config.hospitals[hospital]
    local now = spotNow(h, kind)
    local options = {
        { title = 'ضعه هنا', icon = 'location-crosshairs', iconColor = '#3ddc97',
          description = EMS.SPOT_KINDS[kind] == 'spawn' and 'قف (أو اجلس في المركبة) حيث تظهر واتجه للجهة الصحيحة' or 'قف في المكان الذي يضغط فيه الطاقم E',
          onSelect = function()
              if lib.callback.await('exti_ems:server:setSpot', false, hospital, kind) then
                  EMS.notify('success', ('تم: %s'):format(KIND_LABEL[kind]))
              else
                  EMS.error('failed')
              end
          end },
        { title = 'رجّعه لمكانه في الإعدادات', icon = 'rotate-left',
          onSelect = function()
              if lib.callback.await('exti_ems:server:resetSpot', false, hospital, kind) then EMS.notify('inform', 'رجع لمكانه الأصلي') end
          end },
    }
    if EMS.SPOT_OPTIONAL[kind] then
        options[#options + 1] = { title = 'احذفه من هذا المستشفى', icon = 'trash', iconColor = '#ff6b6b',
            onSelect = function()
                if lib.callback.await('exti_ems:server:setSpot', false, hospital, kind, true) then EMS.notify('inform', 'حُذف') end
            end }
    end
    if now then
        options[#options + 1] = { title = ('مكانه الآن: %.1f، %.1f، %.1f'):format(now.x, now.y, now.z), icon = 'map-pin', readOnly = true,
            description = ('يبعد عنك %.0f متر'):format(#(GetEntityCoords(cache.ped) - vec3(now.x, now.y, now.z))) }
    end
    lib.registerContext({ id = 'exti_ems_spot_kind', title = KIND_LABEL[kind], menu = 'exti_ems_spot_hospital', options = options })
    lib.showContext('exti_ems_spot_kind')
end

local function hospitalMenu(hospital)
    local h = Config.hospitals[hospital]
    local options = {}
    for _, kind in ipairs(KIND_ORDER) do
        local now = spotNow(h, kind)
        options[#options + 1] = {
            title = KIND_LABEL[kind], icon = now and 'circle-check' or 'circle-plus', iconColor = now and '#3ddc97' or '#a19f99',
            description = now and ('على بعد %.0f متر منك'):format(#(GetEntityCoords(cache.ped) - vec3(now.x, now.y, now.z))) or 'غير موجود في هذا المستشفى',
            arrow = true,
            onSelect = function() kindMenu(hospital, kind) end,
        }
    end
    lib.registerContext({ id = 'exti_ems_spot_hospital', title = h.label, menu = 'exti_ems_spots', options = options })
    lib.showContext('exti_ems_spot_hospital')
end

RegisterNetEvent('exti_ems:client:spots', function()
    local p = GetEntityCoords(cache.ped)
    local list = {}
    for name, h in pairs(Config.hospitals) do
        local c = h.duty or (h.garage and h.garage.coords)
        list[#list + 1] = { name = name, label = h.label, dist = c and #(p - vec3(c.x, c.y, c.z)) or 99999 }
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local options = {}
    for _, x in ipairs(list) do
        options[#options + 1] = { title = x.label, description = ('على بعد %.0f متر'):format(x.dist), icon = 'hospital', arrow = true,
            onSelect = function() hospitalMenu(x.name) end }
    end
    lib.registerContext({ id = 'exti_ems_spots', title = 'أماكن الإسعاف', options = options })
    lib.showContext('exti_ems_spots')
end)
