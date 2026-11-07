-- EX_Tii Roleplay — real photos of each player's own car for the garage screen.
-- How it works: a copy of the car (only on this player's screen) is placed high above the
-- player inside a plain magenta box, lit at midday, and photographed from the front-left.
-- The garage page removes the magenta background so the photo looks like the stock pictures,
-- then the server stores it. The player only sees a short "taking a photo" screen.

local PHOTO_VERSION = 'v1'
local FOV = 30.0
local KEY = { 255, 0, 255 } -- background colour (removed later)

local busy = false
local queue = {}
local queued = {}

-- ---------------------------------------------------------------------------
-- "Look" of a car: when this changes (paint, wheels, body parts…), the photo is retaken
-- ---------------------------------------------------------------------------
local LOOK_KEYS = {
    'model', 'color1', 'color2', 'pearlescentColor', 'wheelColor', 'paintType1', 'paintType2',
    'modLivery', 'livery', 'roofLivery', 'wheels', 'windowTint', 'xenonColor',
    'modFrontWheels', 'modBackWheels', 'modCustomTiresF', 'modCustomTiresR',
    'modSpoilers', 'modFrontBumper', 'modRearBumper', 'modSideSkirt', 'modExhaust', 'modFrame',
    'modGrille', 'modHood', 'modFender', 'modRightFender', 'modRoof', 'modArchCover', 'modAerials',
    'modTrimA', 'modTrimB', 'modTank', 'modWindows', 'modPlateHolder', 'modVanityPlate', 'modStruts',
    'extras',
}

local function serial(value)
    local t = type(value)
    if t == 'table' then
        local keys = {}
        for k in pairs(value) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local out = {}
        for i = 1, #keys do
            local k = keys[i]
            out[#out + 1] = tostring(k) .. '=' .. serial(value[k])
        end
        return '{' .. table.concat(out, ',') .. '}'
    elseif t == 'number' then
        if math.type(value) == 'float' then return ('%.2f'):format(value) end
        return tostring(value)
    end
    return tostring(value)
end

---@param props table
---@return string
local function lookOf(props)
    local parts = {}
    for i = 1, #LOOK_KEYS do
        local key = LOOK_KEYS[i]
        parts[#parts + 1] = key .. ':' .. serial(props[key])
    end
    local text = table.concat(parts, '|')
    local hash = 2166136261
    for i = 1, #text do
        hash = (hash ~ text:byte(i)) * 16777619 & 0xFFFFFFFF
    end
    return ('%s-%08x'):format(PHOTO_VERSION, hash)
end

-- ---------------------------------------------------------------------------
-- The magenta studio
-- ---------------------------------------------------------------------------
local function quad(a, b, c, d)
    local r, g, bl = KEY[1], KEY[2], KEY[3]
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, 255)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z, r, g, bl, 255)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, bl, 255)
    DrawPoly(a.x, a.y, a.z, d.x, d.y, d.z, c.x, c.y, c.z, r, g, bl, 255)
end

local function drawBox(c, h)
    local x0, x1, y0, y1, z0, z1 = c.x - h, c.x + h, c.y - h, c.y + h, c.z - h, c.z + h
    local p000, p100, p110, p010 = vec3(x0, y0, z0), vec3(x1, y0, z0), vec3(x1, y1, z0), vec3(x0, y1, z0)
    local p001, p101, p111, p011 = vec3(x0, y0, z1), vec3(x1, y0, z1), vec3(x1, y1, z1), vec3(x0, y1, z1)
    quad(p000, p100, p110, p010) -- floor
    quad(p001, p101, p111, p011) -- ceiling
    quad(p000, p100, p101, p001)
    quad(p010, p110, p111, p011)
    quad(p000, p010, p011, p001)
    quad(p100, p110, p111, p101)
end

local function normalize(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return vec3(v.x / len, v.y / len, v.z / len)
end

local function awaitWithTimeout(start, ms)
    local p = promise.new()
    local settled = false
    local function settle(value)
        if settled then return end
        settled = true
        p:resolve(value)
    end
    start(settle)
    SetTimeout(ms, function() settle(false) end)
    return Citizen.Await(p)
end

local pendingResults = {}

RegisterNUICallback('photoResult', function(data, cb)
    cb(true)
    if type(data) ~= 'table' then return end
    local settle = pendingResults[data.token]
    if settle then
        pendingResults[data.token] = nil
        settle(data)
    end
end)

---@param props table
---@param notBefore? integer game time: the photo is not taken earlier (lets the animation play)
---@return string|false photo webp data url
local function takePhoto(props, notBefore)
    local model = props.model
    if type(model) ~= 'number' or not IsModelInCdimage(model) or not IsModelAVehicle(model) then return false end
    if GetResourceState('screencapture') ~= 'started' then return false end

    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end

    local origin = GetEntityCoords(cache.ped)
    local base = vec3(origin.x, origin.y, origin.z + 320.0)
    local veh = CreateVehicle(model, base.x, base.y, base.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    if veh == 0 then return false end

    local cam, drawing
    local clockH, clockM, clockS = GetClockHours(), GetClockMinutes(), GetClockSeconds()

    local ok, result = pcall(function()
        FreezeEntityPosition(veh, true)
        SetEntityCollision(veh, false, false)
        SetEntityInvincible(veh, true)
        lib.setVehicleProperties(veh, props)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleDoorsShut(veh, true)
        SetVehicleEngineOn(veh, false, true, true)

        local modsUntil = GetGameTimer() + 3000
        while not IsVehicleModLoadDone(veh) and GetGameTimer() < modsUntil do Wait(0) end

        local minDim, maxDim = GetModelDimensions(model)
        local centerLocal = vec3((minDim.x + maxDim.x) * 0.5, (minDim.y + maxDim.y) * 0.5, (minDim.z + maxDim.z) * 0.5)
        local radius = #(maxDim - minDim) * 0.5
        local dist = radius / math.sin(math.rad(FOV * 0.5)) * 1.05
        local dir = normalize(vec3(-0.78, 1.0, 0.38)) -- front-left, a little above
        local camLocal = centerLocal + dir * dist
        local camPos = GetOffsetFromEntityInWorldCoords(veh, camLocal.x, camLocal.y, camLocal.z)
        local center = GetOffsetFromEntityInWorldCoords(veh, centerLocal.x, centerLocal.y, centerLocal.z)
        local half = dist + 8.0

        drawing = true
        CreateThread(function()
            while drawing do
                NetworkOverrideClockTime(12, 30, 0)
                drawBox(center, half)
                HideHudAndRadarThisFrame()
                DisableAllControlActions(0)
                Wait(0)
            end
        end)

        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, FOV, false, 2)
        PointCamAtCoord(cam, center.x, center.y, center.z)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)

        for _ = 1, 12 do Wait(0) end
        while notBefore and GetGameTimer() < notBefore do Wait(0) end

        local raw = awaitWithTimeout(function(settle)
            exports.screencapture:requestScreenshot({ encoding = 'png', maxWidth = 1280, maxHeight = 720 }, function(data)
                settle(data)
            end)
        end, 8000)
        return raw
    end)

    drawing = false
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    if DoesEntityExist(veh) then DeleteEntity(veh) end
    NetworkOverrideClockTime(clockH, clockM, clockS)

    if not ok then
        lib.print.warn('[car photos] studio failed: ' .. tostring(result))
        return false
    end
    if type(result) ~= 'string' or result:sub(1, 11) ~= 'data:image/' then return false end

    -- the garage page removes the magenta background and makes the small photo
    local token = ('%d-%d'):format(GetGameTimer(), math.random(100000, 999999))
    local processed = awaitWithTimeout(function(settle)
        pendingResults[token] = settle
        SendNUIMessage({ action = 'photoProcess', token = token, image = result })
    end, 10000)
    pendingResults[token] = nil

    if type(processed) ~= 'table' or processed.ok ~= true or type(processed.data) ~= 'string' then
        lib.print.warn('[car photos] photo not usable: ' .. tostring(type(processed) == 'table' and processed.reason or 'timeout'))
        return false
    end
    return processed.data
end

local vehiclesByHash
---@param model integer
---@return string
local function labelOf(model)
    if not vehiclesByHash then
        local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByHash() end)
        vehiclesByHash = ok and type(list) == 'table' and list or {}
    end
    local v = vehiclesByHash[model]
    if not v then return '' end
    local brand = v.brand and v.brand ~= '' and (v.brand .. ' ') or ''
    return brand .. (v.name or '')
end

-- ---------------------------------------------------------------------------
-- Queue: one photo at a time, never while dead or in a menu
-- ---------------------------------------------------------------------------
local function runQueue()
    if busy then return end
    busy = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            queued[job.vehicleId] = nil

            while IsPauseMenuActive() or IsEntityDead(cache.ped) do Wait(500) end

            local okLook, storedLook = lib.callback.await('qbx_garages:server:getPhotoLook', false, job.vehicleId)
            local look = lookOf(job.props)
            if okLook and (job.force or storedLook ~= look) then
                SendNUIMessage({ action = 'photoOverlay', show = true, label = labelOf(job.props.model) })
                local photo = takePhoto(job.props, GetGameTimer() + 1100)
                SendNUIMessage({ action = 'photoOverlay', show = false })
                if photo then
                    TriggerLatentServerEvent('qbx_garages:server:savePhoto', 200000, job.vehicleId, look, photo)
                    Wait(4500) -- the server accepts one photo every few seconds
                end
            end
        end
        busy = false
    end)
end

---@param vehicleId integer
---@param props table ox_lib vehicle properties
---@param force? boolean take a new photo even if the car looks the same
local function refreshPhoto(vehicleId, props, force)
    if type(vehicleId) ~= 'number' or vehicleId % 1 ~= 0 or type(props) ~= 'table' or type(props.model) ~= 'number' then return end
    if queued[vehicleId] then
        queued[vehicleId].props = props
        queued[vehicleId].force = queued[vehicleId].force or force == true
    else
        local job = { vehicleId = vehicleId, props = props, force = force == true }
        queued[vehicleId] = job
        queue[#queue + 1] = job
    end
    runQueue()
end

AddEventHandler('qbx_garages:client:refreshPhoto', function(vehicleId, props)
    refreshPhoto(vehicleId, props, false)
end)
exports('RefreshVehiclePhoto', function(vehicleId, props)
    refreshPhoto(vehicleId, props, false)
end)

-- /carphoto: take a new photo of the car you are sitting in (your own cars only)
RegisterCommand('carphoto', function()
    local vehicle = cache.vehicle
    if not vehicle then
        return exports.qbx_core:Notify('اجلس داخل مركبتك أولًا', 'error')
    end
    local vehicleId = lib.callback.await('qbx_garages:server:ownedVehicleId', false, NetworkGetNetworkIdFromEntity(vehicle))
    if not vehicleId then
        return exports.qbx_core:Notify('هذه المركبة ليست ملكك', 'error')
    end
    exports.qbx_core:Notify('سنلتقط صورة جديدة لمركبتك الآن', 'inform')
    refreshPhoto(vehicleId, lib.getVehicleProperties(vehicle), true)
end, false)

-- the garage screen asks for the real photos it does not have yet
RegisterNUICallback('photos', function(data, cb)
    local ids = {}
    if type(data) == 'table' and type(data.ids) == 'table' then
        for i = 1, math.min(#data.ids, 40) do
            local n = tonumber(data.ids[i])
            if n and n % 1 == 0 and n > 0 then ids[#ids + 1] = math.floor(n) end
        end
    end
    if #ids == 0 then return cb({}) end
    cb(lib.callback.await('qbx_garages:server:getPhotos', false, ids) or {})
end)
