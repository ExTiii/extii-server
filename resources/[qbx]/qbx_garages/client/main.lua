local config = require 'config.client'
if not config.enableClient then return end

local VehicleCategory = {
	all = {
		[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true,
		[6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true,
		[12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true,
		[18] = true, [19] = true, [20] = true, [21] = true, [22] = true,
	},
	car = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[7] = true,
		[8] = true,
		[9] = true,
		[10] = true,
		[11] = true,
		[12] = true,
		[13] = true,
		[17] = true,
		[18] = true,
		[19] = true,
		[20] = true,
		[22] = true,
	},
	air = { [15] = true, [16] = true },
	sea = { [14] = true },
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
	local classes = VehicleCategory[category]
	return classes ~= nil and classes[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'), 'error')
        return
    end
    spawnLock = true

    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'), 'error')
            return
        end

        local netId = lib.callback.await('qbx_garages:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
        if not netId then return end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            exports.qbx_core:Notify(locale('error.spawn_failed'), 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    assert(success, result)
end

---------------------------------------------------------------------------
-- Garage screen (list / grid of cars, details, nickname, favourites,
-- shared keys, move here, give to a player, finance payments)
---------------------------------------------------------------------------
local ui = { open = false }

local function closeGarageUI()
    if not ui.open then return end
    ui.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function fetchGarageData()
    if not ui.garageName then return end
    local data = lib.callback.await('qbx_garages:server:getGarageData', false, ui.garageName)
    -- EX_Tii: every impound lot shows its own name
    local point = ui.garageInfo and ui.garageInfo.accessPoints and ui.garageInfo.accessPoints[ui.accessPoint]
    if type(data) == 'table' and point and point.label then data.label = point.label end
    return data
end

---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function openGarageMenu(garageName, garageInfo, accessPoint)
    if ui.open then return end
    ui.garageName, ui.garageInfo, ui.accessPoint = garageName, garageInfo, accessPoint

    local data = fetchGarageData()
    if not data then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return
    end

    ui.open = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)

    -- Close the screen if the player walks away, dies or ends up in a vehicle
    CreateThread(function()
        local point = garageInfo.accessPoints[accessPoint]
        while ui.open do
            Wait(500)
            if not point or #(GetEntityCoords(cache.ped) - point.coords.xyz) > 6.0
                or IsEntityDead(cache.ped) or cache.vehicle then
                closeGarageUI()
            end
        end
    end)
end

local function toId(value)
    local n = tonumber(value)
    if not n or n % 1 ~= 0 then return end
    return math.floor(n)
end

RegisterNUICallback('close', function(_, cb)
    closeGarageUI()
    cb(true)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(ui.open and fetchGarageData() or false)
end)

RegisterNUICallback('takeOut', function(data, cb)
    cb(true)
    local id = toId(data and data.id)
    if not id or not ui.open then return end
    local garageName, accessPoint = ui.garageName, ui.accessPoint
    closeGarageUI()
    takeOutOfGarage(id, garageName, accessPoint)
end)

RegisterNUICallback('favourite', function(data, cb)
    local id = toId(data and data.id)
    if not id then return cb(false) end
    cb(lib.callback.await('qbx_garages:server:setFavourite', false, id, data.value == true) == true)
end)

RegisterNUICallback('rename', function(data, cb)
    local id = toId(data and data.id)
    if not id or type(data.name) ~= 'string' then return cb(false) end
    cb(lib.callback.await('qbx_garages:server:renameVehicle', false, id, data.name) == true)
end)

RegisterNUICallback('moveHere', function(data, cb)
    local id = toId(data and data.id)
    if not id or not ui.open then return cb({ ok = false }) end
    local ok, err = lib.callback.await('qbx_garages:server:moveVehicleHere', false, id, ui.garageName, ui.accessPoint)
    cb({ ok = ok == true, error = err })
end)

RegisterNUICallback('share', function(data, cb)
    local id, target = toId(data and data.id), toId(data and data.target)
    if not id or not target or not ui.open then return cb({ ok = false, error = 'bad_player' }) end
    local ok, result = lib.callback.await('qbx_garages:server:shareKeys', false, id, target, ui.garageName, ui.accessPoint)
    cb({ ok = ok == true, error = not ok and result or nil })
end)

RegisterNUICallback('unshare', function(data, cb)
    local id = toId(data and data.id)
    if not id or type(data.citizenid) ~= 'string' then return cb(false) end
    cb(lib.callback.await('qbx_garages:server:unshareKeys', false, id, data.citizenid) == true)
end)

RegisterNUICallback('give', function(data, cb)
    local id, target = toId(data and data.id), toId(data and data.target)
    if not id or not target or not ui.open then return cb({ ok = false, error = 'bad_player' }) end
    local ok, err = lib.callback.await('qbx_garages:server:giveVehicle', false, id, target, ui.garageName, ui.accessPoint)
    cb({ ok = ok == true, error = err })
end)

-- Finance payments go through the vehicle shop, which keeps the payment schedule
RegisterNUICallback('payFinance', function(data, cb)
    local id = toId(data and data.id)
    if not id or not ui.open then return cb(false) end
    if data.full == true then
        TriggerServerEvent('qbx_vehicleshop:server:financePaymentFull', id)
    else
        local amount = toId(data.amount)
        if not amount or amount <= 0 then return cb(false) end
        TriggerServerEvent('qbx_vehicleshop:server:financePayment', amount, id)
    end
    Wait(900)
    cb(fetchGarageData() or false)
end)

-- Someone wants to give this player a vehicle
RegisterNetEvent('qbx_garages:client:askTransfer', function(token, info)
    if type(token) ~= 'string' or type(info) ~= 'table' then return end
    if ui.open then closeGarageUI() end -- EX_Tii: the question needs the mouse; the garage screen would stay stuck
    local answered = false
    SetTimeout(math.max(5, (tonumber(info.timeout) or 30) - 1) * 1000, function()
        if not answered then lib.closeAlertDialog() end
    end)
    local result = lib.alertDialog({
        header = locale('ui.transfer_title'),
        content = locale('ui.transfer_text', tostring(info.from or ''), tostring(info.label or ''), tostring(info.plate or '')),
        centered = true,
        cancel = true,
        labels = { confirm = locale('ui.accept'), cancel = locale('ui.decline') },
    })
    answered = true
    TriggerServerEvent('qbx_garages:server:answerTransfer', token, result == 'confirm')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not ui.open then return end
    SetNuiFocus(false, false)
end)

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    -- EX_Tii: the count does not include the driver, so any passenger means "occupied"
    -- (it was ~= 1: one passenger was refused but two or more got thrown out and the car parked)
    if GetVehicleNumberOfPassengers(vehicle) == 0 then
        local isParkable = lib.callback.await('qbx_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        local props = lib.getVehicleProperties(vehicle)
        local parked, vehicleId = lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), props, garageName)
        if parked then
            exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
            -- EX_Tii: new paint or parts? take a fresh photo of the car for the garage screen
            if vehicleId then TriggerEvent('qbx_garages:client:refreshPhoto', vehicleId, props) end
        end
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

-- EX_Tii: job / gang garages. Before your character has loaded there is no job yet and qbx_core's check
-- crashes on that (it killed the attendants and circles for every garage). No job yet = not yours yet.
---@param groups? table
---@return boolean
local function hasGroupAccess(groups)
    if not groups then return true end
    local data = QBX.PlayerData
    if not data or not data.job or not data.gang then return false end
    local ok, result = pcall(function() return exports.qbx_core:HasPrimaryGroup(groups) end)
    return ok and result == true
end

-- EX_Tii: one error must never stop a garage loop for good; print it (at most every 10 s) and keep going
local lastErrorAt = {}
local function safeStep(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        local now = GetGameTimer()
        if not lastErrorAt[name] or now - lastErrorAt[name] > 10000 then
            lastErrorAt[name] = now
            print(('^1[qbx_garages] %s: %s^7'):format(name, tostring(err)))
        end
    end
    return ok
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not hasGroupAccess(garage.groups) then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- EX_Tii: garages and impound lots in the city
-- * an attendant stands at every place; walk into the gold circle in front of him and press E
-- * cars are parked by driving into the big gold circle and pressing E
-- * own map icons (garage = gold garage with a car, impound = red car on a tow hook)
---------------------------------------------------------------------------
local GOLD = { 232, 181, 71 }
local NPC_IN, NPC_OUT = 110.0, 140.0 -- attendants appear / disappear at these distances
local DRAW_FOOT, DRAW_CAR = 30.0, 45.0
local BLIP_CATEGORIES = {
    garage = { id = 77, label = 'مرائب السيارات' },
    impound = { id = 78, label = 'ساحات الحجز' },
}
for _, c in pairs(BLIP_CATEGORIES) do AddTextEntry('BLIP_CAT_' .. c.id, c.label) end

local places = {}   -- every garage / impound place: { name, garage, index, point, ring, radius, attendant, ped, park, parkRadius }
local blips = {}
local nearby = {}   -- places close to the player (updated twice a second)
local busy = false

-- the floor under a spot (cached), found from a little above it
local floors = {}
local function floorZ(x, y, z)
    local key = ('%d:%d:%d'):format(math.floor(x * 2), math.floor(y * 2), math.floor(z))
    local hit = floors[key]
    if hit then return hit end
    RequestCollisionAtCoord(x, y, z)
    for _, up in ipairs({ 0.5, 2.5, 6.0 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + up, false)
        if found and math.abs(gz - z) < 8.0 then
            floors[key] = gz
            return gz
        end
    end
    return z - 0.98 -- not loaded yet: a standing person's position is about 1 m above the floor
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

-- the same gold circle as the job centre
local function drawCircle(x, y, z, radius, here, arrow)
    local fz = floorZ(x, y, z) + 0.03
    GoldCircle.draw(x, y, fz, radius, here, GOLD)
    return fz
end

-- one "[E] ..." line at a time
local shownText
local function showPrompt(text)
    if shownText == text then return end
    shownText = text
    lib.showTextUI(text)
end
local function hidePrompt()
    if not shownText then return end
    shownText = nil
    lib.hideTextUI()
end

---------------------------------------------------------------------------
-- attendants
---------------------------------------------------------------------------
local function removeAttendant(place)
    if place.ped and DoesEntityExist(place.ped) then DeletePed(place.ped) end
    place.ped = nil
end

local function spawnAttendant(place)
    if place.spawning then return end
    place.spawning = true
    CreateThread(function()
        local att = place.attendant
        local model = joaat(att.model)
        local ok = pcall(lib.requestModel, model, 10000)
        local c = place.point.coords
        if ok and not place.ped then
            local z = c.z - 1.0
            for _ = 1, 30 do -- wait for the ground to load
                RequestCollisionAtCoord(c.x, c.y, c.z)
                local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
                if found and math.abs(gz - c.z) < 6.0 then z = gz break end
                Wait(100)
            end
            local ped = CreatePed(0, model, c.x, c.y, z, c.w or 0.0, false, false)
            SetModelAsNoLongerNeeded(model)
            if ped and ped ~= 0 then
                SetEntityHeading(ped, c.w or 0.0)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCanRagdoll(ped, false)
                SetPedFleeAttributes(ped, 0, false)
                SetPedCanBeTargetted(ped, false)
                SetPedDiesWhenInjured(ped, false)
                if att.scenario then TaskStartScenarioInPlace(ped, att.scenario, 0, true) end
                place.ped = ped
            end
        end
        place.spawning = false
    end)
end

---------------------------------------------------------------------------
-- places, blips and parking spots
---------------------------------------------------------------------------
local function createBlip(garage, point)
    local b = point.blip
    local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
    SetBlipSprite(blip, b.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, b.scale or 0.75)
    SetBlipColour(blip, b.color or 3)
    SetBlipAsShortRange(blip, true) -- always on the big map, on the small map only when close
    local category = b.category and BLIP_CATEGORIES[b.category]
    if category then SetBlipCategory(blip, category.id) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.name or garage.label)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
    return blip
end

-- no parked game cars on the spots where player cars come out
local function keepSpotClear(spot)
    local x, y, z = spot.x, spot.y, spot.z
    SetAllVehicleGeneratorsActiveInArea(x - 7.0, y - 7.0, z - 4.0, x + 7.0, y + 7.0, z + 4.0, false, false)
    RemoveVehiclesFromGeneratorsInArea(x - 7.0, y - 7.0, z - 4.0, x + 7.0, y + 7.0, z + 4.0)
end

---@param name string
---@param garage GarageConfig
local function createGarage(name, garage)
    -- a garage registered again replaces its old places
    for i = #places, 1, -1 do
        if places[i].name == name then
            removeAttendant(places[i])
            if places[i].blip and DoesBlipExist(places[i].blip) then RemoveBlip(places[i].blip) end
            table.remove(places, i)
        end
    end
    local isDepot = garage.type == GarageType.DEPOT
    for index, point in ipairs(garage.accessPoints or {}) do
        local c = point.coords
        local attendant = garage.attendant
        local ring
        if attendant then
            local h = math.rad(c.w or 0.0)
            ring = vec3(c.x - math.sin(h) * 1.2, c.y + math.cos(h) * 1.2, c.z)
        else
            ring = vec3(c.x, c.y, c.z)
        end
        -- EX_Tii: garages without a car spot (house garages) are parked into at the door itself
        local drop = point.dropPoint or point.spawn or (not attendant and point.coords) or nil
        local place = {
            name = name,
            garage = garage,
            index = index,
            point = point,
            ring = ring,
            radius = point.useRadius or (attendant and 0.65 or 1.0),
            attendant = attendant,
            isDepot = isDepot,
            park = (not isDepot and drop) and vec3(drop.x, drop.y, drop.z) or nil,
            parkRadius = point.dropUseRadius or 1.5,
            water = garage.vehicleType == VehicleType.SEA,
        }
        if point.blip then place.blip = createBlip(garage, point) end
        places[#places + 1] = place
        if point.spawn then keepSpotClear(point.spawn) end
    end
end

---------------------------------------------------------------------------
-- talking to the attendant opens the garage screen
---------------------------------------------------------------------------
local function talkTo(place)
    if busy then return end
    busy = true
    hidePrompt()
    if checkCanAccess(place.garage) then
        if place.ped and DoesEntityExist(place.ped) then
            TaskTurnPedToFaceEntity(cache.ped, place.ped, 700)
            PlayPedAmbientSpeechNative(place.ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NORMAL')
            Wait(600)
        end
        openGarageMenu(place.name, place.garage, place.index)
    end
    busy = false
end

local function parkHere(place)
    if busy then return end
    busy = true
    hidePrompt()
    if checkCanAccess(place.garage) then parkVehicle(cache.vehicle, place.name) end
    busy = false
end

-- which places are close (and attendants in / out of the world)
CreateThread(function()
    while true do
        safeStep('nearby', function()
        local me = GetEntityCoords(cache.ped)
        local list = {}
        for i = 1, #places do
            local place = places[i]
            local dist = #(me.xy - place.ring.xy)
            if place.attendant then
                local alive = place.ped and DoesEntityExist(place.ped)
                if dist < NPC_IN and not alive then
                    place.ped = nil
                    spawnAttendant(place)
                elseif dist > NPC_OUT and place.ped then
                    removeAttendant(place)
                end
            end
            local parkDist = place.park and #(me.xy - place.park.xy) or math.huge
            local allowed = hasGroupAccess(place.garage.groups)
            if allowed and (dist < DRAW_CAR or parkDist < DRAW_CAR) then list[#list + 1] = place end
        end
        nearby = list
        end)
        Wait(500)
    end
end)

-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

-- circles and the E key
CreateThread(function()
    while true do
        local sleep = 400
        safeStep('circles', function()
        if #nearby > 0 and LocalPlayer.state.isLoggedIn and not ui.open then
            sleep = 0
            local me = GetEntityCoords(cache.ped)
            local vehicle = cache.vehicle
            local driving = vehicle and cache.seat == -1
            local prompt, action, target
            for i = 1, #nearby do
                local place = nearby[i]
                if not vehicle then
                    local ring = place.ring
                    local dist = #(me.xy - ring.xy)
                    if dist < DRAW_FOOT then
                        local here = dist <= place.radius + 0.35
                        local fz = drawCircle(ring.x, ring.y, ring.z, place.radius, here, dist > 7.0)
                        if here and math.abs(me.z - fz) < 2.5 and not prompt then
                            local role = place.attendant and place.attendant.role
                            prompt = role and ('[E] تحدّث مع ' .. role) or locale('info.' .. (place.isDepot and 'impound' or 'car') .. '_e')
                            action, target = 'talk', place
                        end
                    end
                elseif driving and place.park then
                    local park = place.park
                    local dist = #(GetEntityCoords(vehicle).xy - park.xy)
                    if dist < DRAW_CAR then
                        local here = dist <= place.parkRadius
                        local pz = park.z
                        if place.water then
                            local found, wz = GetWaterHeightNoWaves(park.x, park.y, park.z)
                            if found then pz = wz + 0.98 end
                        end
                        local fz
                        if place.water then
                            fz = pz - 0.95 -- on the water
                            GoldCircle.draw(park.x, park.y, fz, place.parkRadius, here, GOLD)
                        else
                            fz = drawCircle(park.x, park.y, pz, place.parkRadius, here, false)
                        end
                        if here and math.abs(me.z - fz) < 4.0 and not prompt then
                            prompt = locale('info.park_e')
                            action, target = 'park', place
                        end
                    end
                end
            end
            if prompt and not busy and not isDown() then
                showPrompt(prompt)
                if IsControlJustReleased(0, 38) then
                    if action == 'talk' then CreateThread(function() talkTo(target) end)
                    else CreateThread(function() parkHere(target) end) end
                end
            else
                hidePrompt()
            end
        else
            hidePrompt()
        end
        end)
        Wait(sleep)
    end
end)

-- garage screen: "show me the nearest impound lot"
RegisterNUICallback('routeImpound', function(_, cb)
    local me = GetEntityCoords(cache.ped)
    local best, bestDist
    -- EX_Tii: aircraft go to the air impound, boats to the boat impound
    local kind = ui.garageInfo and ui.garageInfo.vehicleType or VehicleType.CAR
    if kind == VehicleType.ALL then kind = VehicleType.CAR end
    for i = 1, #places do
        local place = places[i]
        if place.isDepot and place.garage.vehicleType == kind then
            local dist = #(me.xy - place.ring.xy)
            if not bestDist or dist < bestDist then best, bestDist = place, dist end
        end
    end
    if best then
        -- EX_Tii: thin gold GPS line + a pin named after the lot (exti_gps); without it, GTA's map marker
        local label = (best.point and best.point.label) or best.garage.label
        local ok, done = false, false
        if GetResourceState('exti_gps') == 'started' then
            ok, done = pcall(function() return exports.exti_gps:GoTo(best.ring.x, best.ring.y, best.ring.z, label) end)
        end
        if not (ok and done) then SetNewWaypoint(best.ring.x, best.ring.y) end
    end
    cb(best ~= nil)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    hidePrompt()
    for i = 1, #places do removeAttendant(places[i]) end
    for i = 1, #blips do if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end end
end)

local function createGarages()
    local garages = lib.callback.await('qbx_garages:server:getGarages')
    for name, garage in pairs(garages or {}) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('qbx_garages:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

CreateThread(function()
    createGarages()
end)
