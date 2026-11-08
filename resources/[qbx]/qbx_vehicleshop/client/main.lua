-- EX_Tii Roleplay — dealership.
-- Talk to the salesperson (gold circle in front of him, press E) to open the panel: every car for sale,
-- a 3D preview that turns slowly, paint colours, test drive and buy. Display cars are only decoration.

local config = require 'config.client'
local sharedConfig = require 'config.shared'
local catalog = require 'config.catalog'
local VEHICLES_HASH = exports.qbx_core:GetVehiclesByHash()

local insideShop
local showroomPoints = {}
local promptShown = false

-- catalog lookups ------------------------------------------------------------
local categoryById = {}
for i = 1, #catalog.categories do
    local category = catalog.categories[i]
    categoryById[category.id] = category
end

local catalogByModel = {}
for i = 1, #catalog.vehicles do
    local entry = catalog.vehicles[i]
    if categoryById[entry.category] and not catalogByModel[entry.model] then
        catalogByModel[entry.model] = entry
    end
end

---@param shopId string
---@return table[] categories, table[] vehicles
local function shopCatalog(shopId)
    local categories, vehicles = {}, {}
    for i = 1, #catalog.categories do
        local category = catalog.categories[i]
        if category.shop == shopId then
            categories[#categories + 1] = { id = category.id, label = category.label, en = category.en, icon = category.icon }
        end
    end
    for i = 1, #catalog.vehicles do
        local entry = catalog.vehicles[i]
        local category = categoryById[entry.category]
        if category and category.shop == shopId and catalogByModel[entry.model] == entry then
            vehicles[#vehicles + 1] = {
                model = entry.model,
                name = entry.name,
                brand = entry.brand or '',
                price = entry.price,
                category = entry.category,
            }
        end
    end
    return categories, vehicles
end

-- notifications ----------------------------------------------------------------
local ERRORS = {
    no_money = 'لا تملك مالًا كافيًا',
    no_space = 'مكان التسليم مشغول، انتظر قليلًا ثم حاول مرة أخرى',
    not_here = 'يجب أن تكون داخل المعرض',
    not_sold = 'هذه المركبة غير معروضة للبيع هنا',
    in_test = 'أنت في تجربة قيادة الآن',
    busy = 'انتظر قليلًا ثم حاول مرة أخرى',
    failed = 'حدث خطأ، حاول مرة أخرى',
}

local function notifyError(code)
    exports.qbx_core:Notify(ERRORS[code] or ERRORS.failed, 'error')
end

-- prompt -------------------------------------------------------------------------
local function setPrompt(show)
    if show == promptShown then return end
    promptShown = show
    if show then
        lib.showTextUI('[E] تحدّث مع البائع', { icon = 'car' })
    else
        lib.hideTextUI()
    end
end

-- display cars (only on this player's screen) ---------------------------------------
---@param model string
---@param coords vector4
---@return number vehicleEntity
local function createShowroomVehicle(model, coords)
    lib.requestModel(model, config.requestModelTimeout or 10000)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(veh)
    SetEntityInvincible(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleDoorsLocked(veh, 10)
    FreezeEntityPosition(veh, true)
    SetVehicleNumberPlateText(veh, 'EX TII')
    return veh
end

local panel = {
    open = false,
    shopId = nil,
    preview = nil,
    previewModel = nil,
    colour = 0,
    heading = 0.0,
    token = 0,
    cam = nil,
    oldCams = {},
}

local function setDisplayCarsHidden(shopId, hidden)
    local points = showroomPoints[shopId]
    if not points then return end
    for i = 1, #points do
        local veh = points[i].veh
        if veh and DoesEntityExist(veh) then
            SetEntityVisible(veh, not hidden, false)
            SetEntityCollision(veh, not hidden, not hidden)
        end
    end
end

local function createShowroomVehiclePoint(data)
    return lib.points.new({
        coords = data.coords,
        heading = data.coords.w,
        distance = 300,
        shopName = data.shopName,
        model = data.model,
        veh = nil,
        onEnter = function(self)
            if not IsModelInCdimage(joaat(self.model)) then return end
            self.veh = createShowroomVehicle(self.model, vec4(self.coords.x, self.coords.y, self.coords.z, self.heading))
            if panel.open and panel.shopId == self.shopName then
                SetEntityVisible(self.veh, false, false)
                SetEntityCollision(self.veh, false, false)
            end
        end,
        onExit = function(self)
            if self.veh and DoesEntityExist(self.veh) then
                DeleteEntity(self.veh)
            end
            self.veh = nil
        end
    })
end

---@return string? model of the display car closest to the player (within 4 m)
local function closestDisplayModel(shopId)
    local points = showroomPoints[shopId]
    if not points then return end
    local pos = GetEntityCoords(cache.ped)
    local best, bestDist
    for i = 1, #points do
        local point = points[i]
        local dist = #(pos - point.coords.xyz)
        if dist < 4.0 and (not bestDist or dist < bestDist) then
            best, bestDist = point.model, dist
        end
    end
    return best
end

-- 3D preview + camera -------------------------------------------------------------
local function destroyCams()
    for i = 1, #panel.oldCams do
        local cam = panel.oldCams[i]
        if DoesCamExist(cam) then DestroyCam(cam, false) end
    end
    panel.oldCams = {}
    if panel.cam and DoesCamExist(panel.cam) then
        DestroyCam(panel.cam, false)
    end
    panel.cam = nil
end

local function deletePreview()
    if panel.preview and DoesEntityExist(panel.preview) then
        DeleteEntity(panel.preview)
    end
    panel.preview = nil
    panel.previewModel = nil
end

local function applyColour(veh, colour)
    if not veh or not DoesEntityExist(veh) then return end
    local entry = colour and colour > 0 and catalog.colours[colour]
    if entry then
        SetVehicleCustomPrimaryColour(veh, entry.rgb[1], entry.rgb[2], entry.rgb[3])
    else
        ClearVehicleCustomPrimaryColour(veh)
    end
end

---@param veh number
local function aimCamera(veh)
    local shop = sharedConfig.shops[panel.shopId]
    local preview = shop and shop.preview
    if not preview then return end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(veh))
    local size = #(maxDim - minDim)
    local length = math.max(maxDim.y - minDim.y, maxDim.x - minDim.x)

    local dist = math.min(preview.maxDist, math.max(preview.minDist, length * 1.25))
    local fov = math.deg(2.0 * math.atan((size * 0.55) / dist))
    fov = math.min(70.0, math.max(30.0, fov))

    local center = GetEntityCoords(veh)
    center = vec3(center.x, center.y, center.z + (minDim.z + maxDim.z) * 0.5)

    local dir = preview.camDir
    local dirLen = math.sqrt(dir.x * dir.x + dir.y * dir.y)
    local dx, dy = dir.x / dirLen, dir.y / dirLen
    local camPos = vec3(center.x + dx * dist, center.y + dy * dist, center.z + preview.camHeight * math.min(1.6, math.max(0.6, size / 5.0)))

    -- look a little to the right of the car so it sits in the free space left of the panel
    local fx, fy = -dx, -dy
    local rx, ry = fy, -fx
    local shift = dist * math.tan(math.rad(fov) * 0.5) * 1.777 * 0.28
    local target = vec3(center.x + rx * shift, center.y + ry * shift, center.z)

    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, fov, false, 2)
    PointCamAtCoord(cam, target.x, target.y, target.z)

    if panel.cam and DoesCamExist(panel.cam) then
        SetCamActiveWithInterp(cam, panel.cam, 650, 1, 1)
        panel.oldCams[#panel.oldCams + 1] = panel.cam
        local old = panel.cam
        SetTimeout(900, function()
            for i = #panel.oldCams, 1, -1 do
                if panel.oldCams[i] == old then
                    table.remove(panel.oldCams, i)
                    if DoesCamExist(old) then DestroyCam(old, false) end
                end
            end
        end)
    else
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 650, true, true)
    end
    panel.cam = cam
end

---@param hash number
local function modelStats(hash)
    local speed = (GetVehicleModelEstimatedMaxSpeed(hash) or 0.0) * 3.6
    return {
        speed = math.floor(speed + 0.5),
        accel = GetVehicleModelAcceleration(hash) or 0.0,
        brake = GetVehicleModelMaxBraking(hash) or 0.0,
        grip = GetVehicleModelMaxTraction(hash) or 0.0,
        seats = GetVehicleModelNumberOfSeats(hash) or 0,
    }
end

---@param model string
---@return boolean
local function showPreview(model)
    local entry = catalogByModel[model]
    local category = entry and categoryById[entry.category]
    if not entry or not category or category.shop ~= panel.shopId then return false end
    if panel.previewModel == model and panel.preview and DoesEntityExist(panel.preview) then return true end

    panel.token += 1
    local token = panel.token
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return false end

    RequestModel(hash)
    local timeout = GetGameTimer() + (config.requestModelTimeout or 5000)
    while not HasModelLoaded(hash) do
        if token ~= panel.token or not panel.open then return false end
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    if token ~= panel.token or not panel.open then
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    local shop = sharedConfig.shops[panel.shopId]
    local stage = shop.preview.coords
    deletePreview()

    local veh = CreateVehicle(hash, stage.x, stage.y, stage.z, panel.heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    if veh == 0 then return false end

    SetEntityInvincible(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleNumberPlateText(veh, 'EX TII')
    SetEntityCollision(veh, false, false)
    if shop.preview.ground then SetVehicleOnGroundProperly(veh) end
    FreezeEntityPosition(veh, true)
    applyColour(veh, panel.colour)

    panel.preview = veh
    panel.previewModel = model
    aimCamera(veh)

    SendNUIMessage({ action = 'stats', model = model, stats = modelStats(hash) })
    return true
end

local function closePanel()
    if not panel.open then return end
    panel.open = false
    panel.token += 1

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    RenderScriptCams(false, true, 500, true, true)
    destroyCams()
    deletePreview()
    setDisplayCarsHidden(panel.shopId, false)
    panel.shopId = nil
end

local function openPanel()
    if panel.open or not insideShop then return end
    if cache.vehicle or IsEntityDead(cache.ped) then return end
    if LocalPlayer.state.isInTestDrive then return notifyError('in_test') end

    local shopId = insideShop
    local shop = sharedConfig.shops[shopId]
    if not shop or not shop.preview then return end

    local categories, vehicles = shopCatalog(shopId)
    if #vehicles == 0 then return end

    local focus = closestDisplayModel(shopId)
    if not focus or not catalogByModel[focus] then focus = vehicles[1].model end

    panel.open = true
    panel.shopId = shopId
    panel.colour = 0
    panel.heading = shop.preview.coords.w
    setPrompt(false)
    setDisplayCarsHidden(shopId, true)

    local money = QBX.PlayerData and QBX.PlayerData.money or {}
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        shop = { id = shopId, label = shop.blip.label, spin = shop.preview.spin ~= false },
        categories = categories,
        vehicles = vehicles,
        colours = catalog.colours,
        money = { cash = money.cash or 0, bank = money.bank or 0 },
        testDrive = sharedConfig.enableTestDrive and (shop.testDrive and shop.testDrive.limit) or false,
        canBuy = sharedConfig.enableFreeUseBuy,
        focus = focus,
    })

    -- turn the car slowly, keep the player out of the picture, close if something goes wrong
    CreateThread(function()
        while panel.open do
            if panel.preview and DoesEntityExist(panel.preview) and shop.preview.spin ~= false then
                panel.heading = (panel.heading + GetFrameTime() * 14.0) % 360.0
                SetEntityHeading(panel.preview, panel.heading)
            end
            SetEntityLocallyInvisible(cache.ped)
            HideHudAndRadarThisFrame()
            if IsEntityDead(cache.ped) or cache.vehicle or insideShop ~= panel.shopId then
                closePanel()
                break
            end
            Wait(0)
        end
    end)
end

-- NUI ------------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    cb(true)
    closePanel()
end)

RegisterNUICallback('select', function(data, cb)
    if not panel.open or type(data) ~= 'table' or type(data.model) ~= 'string' then return cb(false) end
    cb(showPreview(data.model))
end)

RegisterNUICallback('colour', function(data, cb)
    cb(true)
    if not panel.open or type(data) ~= 'table' then return end
    local colour = math.tointeger(tonumber(data.index)) or 0
    if colour ~= 0 and not catalog.colours[colour] then colour = 0 end
    panel.colour = colour
    applyColour(panel.preview, colour)
end)

RegisterNUICallback('buy', function(data, cb)
    if not panel.open or type(data) ~= 'table' or type(data.model) ~= 'string' then return cb({ ok = false, error = 'failed' }) end
    local account = data.account == 'bank' and 'bank' or 'cash'
    local colour = math.tointeger(tonumber(data.colour)) or 0
    -- EX_Tii: "factory colour" = exactly the paint the showroom car has right now (not a new random one)
    local factory
    if colour == 0 and panel.preview and DoesEntityExist(panel.preview) then
        local c1, c2 = GetVehicleColours(panel.preview)
        local pearl, wheel = GetVehicleExtraColours(panel.preview)
        factory = { c1, c2, pearl, wheel }
    end
    local ok, err, vehicleId = lib.callback.await('exti_vshop:server:buy', false, data.model, colour, account, factory)
    cb({ ok = ok == true, error = err })
    if not ok then return end
    closePanel()

    -- EX_Tii: the garage keeps a real photo of the new car in the colour that was picked
    if vehicleId then
        CreateThread(function()
            local waitUntil = GetGameTimer() + 8000
            while not cache.vehicle and GetGameTimer() < waitUntil do Wait(100) end
            if not cache.vehicle then return end
            Wait(1500) -- let the paint settle on the new car
            local veh = cache.vehicle
            if not veh or not DoesEntityExist(veh) then return end
            local props = lib.getVehicleProperties(veh)
            -- EX_Tii: the full look of the car (every colour, wheels...) is saved now, so the garage and the
            -- impound give it back exactly like this even if it is never parked first
            lib.callback.await('exti_vshop:server:saveLook', false, vehicleId, NetworkGetNetworkIdFromEntity(veh), props)
            pcall(exports.qbx_garages.RefreshVehiclePhoto, exports.qbx_garages, vehicleId, props)
        end)
    end
end)

RegisterNUICallback('testdrive', function(data, cb)
    if not panel.open or type(data) ~= 'table' or type(data.model) ~= 'string' then return cb({ ok = false, error = 'failed' }) end
    local colour = math.tointeger(tonumber(data.colour)) or 0
    local ok, err = lib.callback.await('exti_vshop:server:testDrive', false, data.model, colour)
    cb({ ok = ok == true, error = err })
    if ok then closePanel() end
end)

-- test drive timer ----------------------------------------------------------------------
lib.onCache('vehicle', function(value)
    if value or not LocalPlayer.state.isInTestDrive then return end
    LocalPlayer.state:set('isInTestDrive', nil, true)
end)

local function startTestDriveTimer(minutes)
    local endsAt = GetGameTimer() + math.floor(minutes * 60000)
    CreateThread(function()
        local playerState = LocalPlayer.state
        local last
        while playerState.isInTestDrive do
            local left = math.max(0, math.ceil((endsAt - GetGameTimer()) / 1000))
            if left ~= last then
                last = left
                lib.showTextUI(('تجربة القيادة: %d:%02d'):format(left // 60, left % 60), { icon = 'stopwatch' })
            end
            Wait(200)
        end
        lib.hideTextUI()
        promptShown = false
        exports.qbx_core:Notify(locale('general.testdrive_complete'), 'success')
    end)
end

AddStateBagChangeHandler('isInTestDrive', ('player:%s'):format(cache.serverId), function(_, _, value)
    if not value then return end

    local waitUntil = GetGameTimer() + 10000
    while not cache.vehicle and GetGameTimer() < waitUntil do
        Wait(10)
    end

    exports.qbx_core:Notify('بدأت تجربة القيادة، استمتع!', 'inform')
    startTestDriveTimer(value)
end)

-- vehicles sold between players ----------------------------------------------------------
local function confirmTrade(confirmationText)
    local accepted

    exports.npwd:createSystemNotification({
        uniqId = "vehicleShop:confirmTrade",
        content = confirmationText,
        secondary = "تأكيد الصفقة",
        keepOpen = true,
        duration = 10000,
        controls = true,
        onConfirm = function()
            accepted = true
        end,
        onCancel = function()
            accepted = false
        end,
    })

    local timeout = GetGameTimer() + 15000
    while accepted == nil and GetGameTimer() < timeout do
        Wait(100)
    end

    return accepted == true
end

lib.callback.register('qbx_vehicleshop:client:confirmFinance', function(financeData)
    local alert = lib.alertDialog({
        header = locale('general.financed_vehicle_header'),
        content = locale('general.financed_vehicle_warning', lib.math.groupdigits(financeData.balance), lib.math.groupdigits(financeData.paymentamount), financeData.timer),
        centered = true,
        cancel = true,
        labels = {
            cancel = 'لا',
            confirm = 'نعم',
        }
    })
    return alert
end)

lib.callback.register('qbx_vehicleshop:client:confirmTrade', function(vehicle, sellAmount)
    local info = VEHICLES_HASH[vehicle] or { brand = '', name = '' }
    local confirmationText = locale('general.transfervehicle_confirm', info.brand, info.name, lib.math.groupdigits(sellAmount) or 0)

    if GetResourceState('npwd') ~= 'started' then
        local input = lib.inputDialog(confirmationText, {
            {
                type = 'checkbox',
                label = 'موافق'
            },
        })
        return input?[1]
    end

    return confirmTrade(confirmationText)
end)

-- shops, blips, display cars ------------------------------------------------------------------
local function createShop(shopShape, name)
    lib.zones.poly({
        name = name,
        points = shopShape,
        thickness = 5,
        debug = config.debugPoly,
        onEnter = function(self)
            insideShop = self.name
        end,
        onExit = function()
            insideShop = nil
            setPrompt(false)
        end,
    })
end

-- EX_Tii: the salesperson and the gold circle in front of him ------------------------------
local GOLD = { 232, 181, 71 }
local RING_RADIUS = 0.65
local sellers = {} -- [shopId] = { coords, ring, ped, spawning }

for shopId, shop in pairs(sharedConfig.shops) do
    local s = shop.salesperson
    if s then
        local h = math.rad(s.coords.w)
        sellers[shopId] = {
            shopId = shopId,
            data = s,
            coords = s.coords,
            ring = vec3(s.coords.x - math.sin(h) * 1.2, s.coords.y + math.cos(h) * 1.2, s.coords.z),
        }
    end
end

local floors = {}
local function floorZ(x, y, z)
    local key = ('%d:%d:%d'):format(math.floor(x * 2), math.floor(y * 2), math.floor(z))
    local hit = floors[key]
    if hit then return hit end
    RequestCollisionAtCoord(x, y, z)
    for _, up in ipairs({ 0.5, 2.5 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + up, false)
        if found and math.abs(gz - z) < 5.0 then
            floors[key] = gz
            return gz
        end
    end
    return z - 0.98
end

-- EX_Tii: the gold circle — a small, smooth ring of soft light that fades upward.
-- It pops in when you come close and fades out when you leave. Callers only say
-- "show a circle here this frame"; one loop draws every circle exactly once per frame.
local GoldCircle = {}
do
    local POP_MS, GRACE_MS, FADE_MS = 420, 250, 380
    local list = {}
    local awake = false

    local function easeOutBack(t) -- grows a little past full size, then settles: the "pop"
        local c1 = 1.25
        local u = t - 1.0
        return 1.0 + (c1 + 1.0) * u * u * u + c1 * u * u
    end

    local function render(c, now)
        c.born = c.born or now
        local t = math.min(1.0, (now - c.born) / POP_MS)
        local gone = now - c.last
        local fade = gone <= GRACE_MS and 1.0 or math.max(0.0, 1.0 - (gone - GRACE_MS) / FADE_MS)
        local show = math.min(1.0, t * 1.6) * fade
        if show <= 0.01 then return end
        local small = c.radius <= 1.5
        local size = c.radius * 2.0 * (small and 0.9 or 1.0) * easeOutBack(t) * (c.here and 1.05 or 1.0)
        local alpha = (c.here and 215 or 150) * show
        local r, g, b = c.color[1], c.color[2], c.color[3]
        -- the glowing wall (bright at the floor, fading upward)
        DrawMarker(1, c.x, c.y, c.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, small and 0.42 or 0.6,
            r, g, b, math.floor(alpha), false, false, 2, false, nil, nil, false)
        -- a faint glow on the floor inside
        DrawMarker(1, c.x, c.y, c.z - 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size * 0.96, size * 0.96, 0.02,
            r, g, b, math.floor(alpha * 0.22), false, false, 2, false, nil, nil, false)
    end

    local function loop()
        if awake then return end
        awake = true
        CreateThread(function()
            while #list > 0 do
                local now = GetGameTimer()
                for i = #list, 1, -1 do
                    local c = list[i]
                    if now - c.last > GRACE_MS + FADE_MS then
                        table.remove(list, i)
                    else
                        render(c, now)
                    end
                end
                Wait(0)
            end
            awake = false
        end)
    end

    ---Show a gold circle this frame. fz = floor height, color = { r, g, b }
    function GoldCircle.draw(x, y, fz, radius, here, color)
        local now = GetGameTimer()
        local c
        for i = 1, #list do
            local o = list[i]
            -- the same circle as before (it may move a little, like the back of a parked truck)
            if o.radius == radius and now - o.last <= GRACE_MS + FADE_MS and (o.x - x) ^ 2 + (o.y - y) ^ 2 < 9.0 then
                c = o
                break
            end
        end
        if not c then
            c = { radius = radius }
            list[#list + 1] = c
        elseif now - c.last > GRACE_MS + 100 then
            c.born = nil -- it was fading out: pop in again
        end
        c.x, c.y, c.z, c.here, c.last, c.color = x, y, fz, here, now, color
        loop()
    end
end

local function drawCircle(x, y, z, radius, here, arrow)
    local fz = floorZ(x, y, z) + 0.03
    GoldCircle.draw(x, y, fz, radius, here, GOLD)
    return fz
end

local function removeSeller(seller)
    if seller.ped and DoesEntityExist(seller.ped) then DeletePed(seller.ped) end
    seller.ped = nil
end

local function spawnSeller(seller)
    if seller.spawning then return end
    seller.spawning = true
    CreateThread(function()
        local model = joaat(seller.data.model)
        local ok = pcall(lib.requestModel, model, 10000)
        local c = seller.coords
        if ok and not seller.ped then
            local z = c.z - 1.0
            for _ = 1, 30 do
                RequestCollisionAtCoord(c.x, c.y, c.z)
                local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
                if found and math.abs(gz - c.z) < 5.0 then z = gz break end
                Wait(100)
            end
            local ped = CreatePed(0, model, c.x, c.y, z, c.w, false, false)
            SetModelAsNoLongerNeeded(model)
            if ped and ped ~= 0 then
                SetEntityHeading(ped, c.w)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCanRagdoll(ped, false)
                SetPedFleeAttributes(ped, 0, false)
                SetPedCanBeTargetted(ped, false)
                SetPedDiesWhenInjured(ped, false)
                if seller.data.scenario then TaskStartScenarioInPlace(ped, seller.data.scenario, 0, true) end
                seller.ped = ped
            end
        end
        seller.spawning = false
    end)
end

local talking = false
local function talkTo(seller)
    if talking then return end
    talking = true
    setPrompt(false)
    if seller.ped and DoesEntityExist(seller.ped) then
        TaskTurnPedToFaceEntity(cache.ped, seller.ped, 700)
        PlayPedAmbientSpeechNative(seller.ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NORMAL')
        Wait(600)
    end
    if insideShop == seller.shopId then openPanel() end
    talking = false
end

-- salespeople appear when you come close
CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        for _, seller in pairs(sellers) do
            local dist = #(me.xy - seller.ring.xy)
            local alive = seller.ped and DoesEntityExist(seller.ped)
            if dist < 110.0 and not alive then
                seller.ped = nil
                spawnSeller(seller)
            elseif dist > 140.0 and seller.ped then
                removeSeller(seller)
            end
        end
        Wait(1000)
    end
end)

-- the gold circle and the E key
-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

CreateThread(function()
    while true do
        local sleep = 500
        local seller = insideShop and sellers[insideShop]
        if seller and not panel.open and not cache.vehicle then
            local me = GetEntityCoords(cache.ped)
            local dist = #(me.xy - seller.ring.xy)
            if dist < 30.0 then
                sleep = 0
                local here = dist <= RING_RADIUS + 0.35
                local fz = drawCircle(seller.ring.x, seller.ring.y, seller.ring.z, RING_RADIUS, here, dist > 7.0)
                local canOpen = here and math.abs(me.z - fz) < 2.5 and not talking
                    and not LocalPlayer.state.isInTestDrive and not isDown()
                setPrompt(canOpen)
                if canOpen and (IsControlJustReleased(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then
                    CreateThread(function() talkTo(seller) end)
                end
            else
                setPrompt(false)
            end
        else
            setPrompt(false)
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    for _, v in pairs(sharedConfig.shops) do
        local blip = v.blip
        if blip.show then
            local dealer = AddBlipForCoord(blip.coords.x, blip.coords.y, blip.coords.z)
            SetBlipSprite(dealer, blip.sprite)
            SetBlipDisplay(dealer, 4)
            SetBlipScale(dealer, 0.675) -- EX_Tii: same size as every icon
            SetBlipAsShortRange(dealer, true)
            SetBlipColour(dealer, blip.color)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(blip.label)
            EndTextCommandSetBlipName(dealer)
        end
    end

    for shopName, shop in pairs(sharedConfig.shops) do
        createShop(shop.zone.shape, shopName)
        showroomPoints[shopName] = {}

        local showroomVehicles = shop.showroomVehicles
        for i = 1, #showroomVehicles do
            local showroomVehicle = showroomVehicles[i]
            showroomPoints[shopName][i] = createShowroomVehiclePoint({
                coords = showroomVehicle.coords,
                shopName = shopName,
                model = showroomVehicle.vehicle
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if cache.resource ~= resourceName then return end
    if panel.open then closePanel() end
    if promptShown then lib.hideTextUI() end
    for _, seller in pairs(sellers) do removeSeller(seller) end
end)
