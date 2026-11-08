-- EX_Tii Fuel (client): station icons, gold circles at the pumps, E to open the pump, the nozzle and hose,
-- the live pump screen, the jerry can, and how fast vehicles use fuel / battery while driving.

local GOLD = { 232, 181, 71 }
local DRAW = 16.0            -- pump circles show from this close
local STATION_NEAR = 80.0    -- pumps of a station are checked from this close
local CAN = `WEAPON_PETROLCAN`
local NOZZLE = `prop_cs_fuel_nozle`

local ui = { open = false }
local fueling                -- the pump running right now
local canBusy = false        -- jerry can being filled / poured
local lastVehicle            -- the last vehicle you were in (picked first at the pump)
local drive = {}             -- { vehicle, token, sent } the vehicle you drive

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(Config.fuelUseMultiplier)

local function iso(text) return '\u{2066}' .. text .. '\u{2069}' end
local function money(n) return iso('$' .. math.floor(n + 0.5)) end
local function amount(n) return iso(('%.1f'):format(n)) end

local function notify(kind, text) lib.notify({ type = kind, description = text }) end

local ERRORS = {
    no_vehicle = 'لا توجد مركبة قرب المضخة',
    vehicle_far = 'قرّب المركبة من المضخة أكثر',
    vehicle_moving = 'أوقف المركبة أولًا',
    vehicle_busy = 'هذه المركبة تُعبّأ الآن',
    no_fuel = 'هذه المركبة لا تحتاج وقودًا',
    too_far = 'اقترب من المضخة أكثر',
    tank_full = 'الخزان ممتلئ',
    no_money = 'المبلغ لا يكفي',
    busy = 'لحظة… جارٍ تنفيذ طلبك السابق',
    failed = 'حدث خطأ، حاول مرة أخرى',
    no_can = 'أمسك جالون الوقود بيدك أولًا',
    can_full = 'الجالون ممتلئ',
    can_empty = 'الجالون فارغ، عبّئه من أي مضخة',
    electric = 'هذه مركبة كهربائية، اشحنها من مضخة المحطة',
    cancelled = 'أُلغيت العملية',
    too_heavy = 'حقيبتك ثقيلة جدًا، الجالون الممتلئ يزن 15 كغ إضافية',
}
local function fail(code) notify('error', ERRORS[code] or ERRORS.failed) end

---------------------------------------------------------------------------
-- floor height under a spot (cached)
---------------------------------------------------------------------------
local floors = {}
local function floorZ(x, y, z)
    local key = ('%d:%d:%d'):format(math.floor(x * 2), math.floor(y * 2), math.floor(z))
    local hit = floors[key]
    if hit then return hit end
    RequestCollisionAtCoord(x, y, z)
    for _, up in ipairs({ 1.0, 2.0 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + up, false)
        if found and math.abs(gz - z) < 4.0 then
            floors[key] = gz
            return gz
        end
    end
    return z
end

---------------------------------------------------------------------------
-- the gold circle (same look as the garages, dealers, jobs and shops)
---------------------------------------------------------------------------
local GoldCircle = {}
do
    local POP_MS, GRACE_MS, FADE_MS = 420, 250, 380
    local list = {}
    local awake = false

    local function easeOutBack(t)
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
        local size = c.radius * 2.0 * 0.9 * easeOutBack(t) * (c.here and 1.05 or 1.0)
        local alpha = (c.here and 215 or 150) * show
        local r, g, b = c.color[1], c.color[2], c.color[3]
        DrawMarker(1, c.x, c.y, c.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.42,
            r, g, b, math.floor(alpha), false, false, 2, false, nil, nil, false)
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

    -- every pump circle has its own key, so two pumps close together never share one circle
    function GoldCircle.draw(key, x, y, fz, radius, here, color)
        local now = GetGameTimer()
        local c
        for i = 1, #list do
            if list[i].key == key then c = list[i] break end
        end
        if not c then
            c = { key = key, radius = radius }
            list[#list + 1] = c
        elseif now - c.last > GRACE_MS + FADE_MS then
            c.born = nil
        end
        c.x, c.y, c.z, c.here, c.last, c.color = x, y, fz, here, now, color
        loop()
    end
end

---------------------------------------------------------------------------
-- "[E] ..." line (shown again if another script hid the text box)
---------------------------------------------------------------------------
local shownText, shownAt = nil, 0
local function showPrompt(text)
    -- (sent again every second: exti_interact drops a line its owner stopped renewing)
    if shownText == text and lib.isTextUIOpen() and GetGameTimer() - shownAt < 1000 then return end
    shownText, shownAt = text, GetGameTimer()
    lib.showTextUI(text)
end
-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

local function hidePrompt()
    if not shownText then return end
    shownText = nil
    lib.hideTextUI()   -- (exti_interact keeps one line per script: this only takes down ours)
end

---------------------------------------------------------------------------
-- map icons: one per station (fuel + its store)
---------------------------------------------------------------------------
local blips = {}
for sid, station in ipairs(Config.stations) do
    local c = station.center
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, Config.blip.colour)
    SetBlipScale(blip, Config.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.storeStations[sid] and Config.blip.label or Config.blip.labelNoStore)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

---------------------------------------------------------------------------
-- vehicles
---------------------------------------------------------------------------
---@return boolean uses, boolean electric
local function fuelKind(vehicle)
    if Config.electricModel(GetEntityModel(vehicle)) then return true, true end
    local class = GetVehicleClass(vehicle)
    if class == 13 or class == 21 then return false, false end -- bicycles, trains
    return DoesVehicleUseFuel(vehicle) and true or false, false
end

local function vehicleName(vehicle)
    local code = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local label = code and GetLabelText(code)
    if not label or label == 'NULL' then label = code or '' end
    return label
end

local CAP_BONES = { 'petrolcap', 'petroltank', 'petroltank_l', 'hub_lr', 'engine' }
local function capPosition(vehicle)
    for i = 1, #CAP_BONES do
        local bone = GetEntityBoneIndexByName(vehicle, CAP_BONES[i])
        if bone ~= -1 then return GetWorldPositionOfEntityBone(vehicle, bone) end
    end
    return GetEntityCoords(vehicle)
end

lib.onCache('vehicle', function(vehicle)
    if vehicle then lastVehicle = vehicle end
end)

---------------------------------------------------------------------------
-- pumps: one gold circle around each pump (two pumps almost touching share one circle)
---------------------------------------------------------------------------
local spots = {}
for sid, station in ipairs(Config.stations) do
    local mine = {}
    for pid, pump in ipairs(station.pumps) do
        local joined
        for _, s in ipairs(mine) do
            if #(s.pos.xy - pump.xy) < 2.9 then joined = s break end
        end
        if joined then
            joined.pumps[#joined.pumps + 1] = pid
            local n = #joined.pumps
            joined.pos = (joined.pos * (n - 1) + pump) / n
        else
            local s = { key = ('%d:%d'):format(sid, pid), station = sid, pumps = { pid }, pos = pump }
            mine[#mine + 1] = s
            spots[#spots + 1] = s
        end
    end
end

-- the pump of a circle closest to where you stand (the server checks that pump)
local function pumpOf(spot, at)
    local best, bestDist
    for _, pid in ipairs(spot.pumps) do
        local d = #(Config.stations[spot.station].pumps[pid].xy - at.xy)
        if not bestDist or d < bestDist then best, bestDist = pid, d end
    end
    return best
end

local function pumpObject(pos)
    local best, bestDist
    for i = 1, #Config.pumpModels do
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, 3.0, Config.pumpModels[i], false, false, false)
        if obj and obj ~= 0 then
            local d = #(GetEntityCoords(obj) - pos)
            if not bestDist or d < bestDist then best, bestDist = obj, d end
        end
    end
    return best
end

-- the vehicle this pump fills: your last vehicle if it is parked here, otherwise the closest one
local found = { at = 0 }
local function vehicleAtPump(pos)
    local now = GetGameTimer()
    if found.pos == pos and now - found.at < 300 then return found.vehicle end
    local best, bestDist
    local me = GetEntityCoords(cache.ped)
    for _, v in ipairs(lib.getNearbyVehicles(pos, Config.vehicleReach, true)) do
        local vehicle = v.vehicle
        local uses = fuelKind(vehicle)
        if uses and NetworkGetEntityIsNetworked(vehicle) and GetEntitySpeed(vehicle) < 1.0 then
            local d = #(GetEntityCoords(vehicle) - me)
            if vehicle == lastVehicle then d = -1.0 end
            if not bestDist or d < bestDist then best, bestDist = vehicle, d end
        end
    end
    found.pos, found.at, found.vehicle = pos, now, best
    return best
end

---------------------------------------------------------------------------
-- the pump screen
---------------------------------------------------------------------------
local function closePanel(tellUi)
    if not ui.open then return end
    ui.open = false
    ui.spot, ui.vehicle, ui.netId, ui.pump, ui.canOnly = nil, nil, nil, nil, nil
    SetNuiFocus(false, false)
    if tellUi ~= false then SendNUIMessage({ action = 'close' }) end
end

local function openPanel(spot, vehicle)
    if ui.open or ui.opening or fueling then return end
    ui.opening = true
    local pump = pumpOf(spot, GetEntityCoords(cache.ped))
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local ok, code, data = lib.callback.await('exti_fuel:server:quote', false, spot.station, pump, netId,
        GetVehicleFuelLevel(vehicle) + 0.0)
    ui.opening = false
    if not ok or type(data) ~= 'table' then return fail(code) end
    if cache.vehicle or isDown() then return end

    hidePrompt()
    ui.open, ui.spot, ui.vehicle, ui.netId, ui.pump = true, spot, vehicle, netId, pump
    data.vehicle = { name = vehicleName(vehicle), plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '') }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterNUICallback('close', function(_, cb)
    cb(true)
    closePanel(false)
end)

---------------------------------------------------------------------------
-- the nozzle, the hose and the pump running
---------------------------------------------------------------------------
local function attachNozzle()
    local ok = pcall(lib.requestModel, NOZZLE, 3000)
    if not ok then return nil end
    local c = GetEntityCoords(cache.ped)
    local obj = CreateObject(NOZZLE, c.x, c.y, c.z + 0.2, false, true, false)
    SetModelAsNoLongerNeeded(NOZZLE)
    if not obj or obj == 0 then return nil end
    AttachEntityToEntity(obj, cache.ped, GetPedBoneIndex(cache.ped, 18905), 0.1, 0.02, 0.02, 90.0, 40.0, 170.0,
        true, true, false, true, 1, true)
    return obj
end

local function makeHose(pump, nozzle)
    if not Config.hose or not pump or not nozzle then return nil end
    local ok, rope = pcall(function()
        RopeLoadTextures()
        local untilMs = GetGameTimer() + 1500
        while not RopeAreTexturesLoaded() and GetGameTimer() < untilMs do Wait(0) end
        if not RopeAreTexturesLoaded() then return nil end
        local p = GetEntityCoords(pump)
        local r = AddRope(p.x, p.y, p.z + 1.3, 0.0, 0.0, 0.0, 3.0, 1, 10.0, 0.5, 1.0, false, false, false, 1.0, true)
        if not r or r == 0 then return nil end
        local n = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)
        AttachEntitiesToRope(r, pump, nozzle, p.x, p.y, p.z + 1.3, n.x, n.y, n.z, 5.0, false, false, nil, nil)
        return r
    end)
    return ok and rope or nil
end

local function removeHose(rope)
    if not rope then return end
    pcall(DeleteRope, rope) -- (rope textures stay loaded: other scripts may use ropes too)
end

local FILL_DICT, FILL_CLIP = 'timetable@gardener@filling_can', 'gar_ig_5_filling_can'
local BLOCK = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

local function runPump(spot, pump, vehicle, s)
    fueling = { vehicle = vehicle, electric = s.electric }
    local ped = cache.ped
    local cap = capPosition(vehicle)
    TaskTurnPedToFaceCoord(ped, cap.x, cap.y, cap.z, 900)
    Wait(700)

    local nozzle = attachNozzle()
    local hose = makeHose(pumpObject(Config.stations[spot.station].pumps[pump]), nozzle)
    fueling.nozzle, fueling.hose = nozzle, hose
    local animOk = pcall(lib.requestAnimDict, FILL_DICT, 3000)
    if animOk then TaskPlayAnim(ped, FILL_DICT, FILL_CLIP, 2.0, 2.0, -1, 49, 0.0, false, false, false) end

    SendNUIMessage({ action = 'fuelStart', data = s })

    local stopSent = false
    local deadline = GetGameTimer() + s.duration + 6000
    while fueling and not fueling.result do
        for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
        if animOk and not IsEntityPlayingAnim(ped, FILL_DICT, FILL_CLIP, 3) then
            TaskPlayAnim(ped, FILL_DICT, FILL_CLIP, 2.0, 2.0, -1, 49, 0.0, false, false, false)
        end
        local stop = IsControlJustPressed(0, 38) or isDown() or IsPedRagdoll(ped) or cache.vehicle
        if (stop or GetGameTimer() > deadline) and not stopSent then
            stopSent = true
            deadline = GetGameTimer() + 4000
            lib.callback('exti_fuel:server:stop', false, function(stopped)
                -- already finished on the server: its message is on the way
                if not stopped then deadline = math.min(deadline, GetGameTimer() + 1500) end
            end)
        elseif stopSent and GetGameTimer() > deadline then
            break
        end
        Wait(0)
    end

    StopAnimTask(ped, FILL_DICT, FILL_CLIP, 2.0)
    removeHose(hose)
    if nozzle and DoesEntityExist(nozzle) then DeleteEntity(nozzle) end
    RemoveAnimDict(FILL_DICT)

    local result = fueling and fueling.result
    fueling = nil
    SendNUIMessage({ action = 'fuelEnd', data = result or { failed = true } })
    if not result then return notify('error', 'توقفت المضخة') end

    local unit = result.electric and 'ك.و.س' or 'لتر'
    if result.paid <= 0 then
        notify('inform', ('لم يُعبّأ شيء، أُعيد لك %s'):format(money(result.refund)))
    elseif result.refund > 0 then
        notify('success', ('%s %s %s — دفعت %s وأُعيد لك %s'):format(result.electric and 'شحنت' or 'عبّأت',
            amount(result.units), unit, money(result.paid), money(result.refund)))
    else
        notify('success', ('%s %s %s — دفعت %s'):format(result.electric and 'تم الشحن:' or 'تمت التعبئة:',
            amount(result.units), unit, money(result.paid)))
    end
end

RegisterNetEvent('exti_fuel:client:finished', function(result)
    if fueling and type(result) == 'table' then fueling.result = result end
end)

RegisterNUICallback('start', function(data, cb)
    if not ui.open or fueling or type(data) ~= 'table' then return cb({ ok = false, code = 'busy' }) end
    local target = tonumber(data.target)
    local account = data.account
    if not target or (account ~= 'cash' and account ~= 'bank') then return cb({ ok = false, code = 'failed' }) end

    local spot, pump, vehicle, netId = ui.spot, ui.pump, ui.vehicle, ui.netId
    local ok, code, s = lib.callback.await('exti_fuel:server:start', false, spot.station, pump, netId, target, account)
    if not ok or type(s) ~= 'table' then return cb({ ok = false, code = code }) end
    cb({ ok = true })
    closePanel()
    CreateThread(function() runPump(spot, pump, vehicle, s) end)
end)

-- close the screen if you walk away, get in a car or go down
CreateThread(function()
    while true do
        if ui.open and ui.spot then
            local p = GetEntityCoords(cache.ped)
            if #(p.xy - ui.spot.pos.xy) > Config.pumpRadius + 1.5 or cache.vehicle or isDown()
                or (not ui.canOnly and not DoesEntityExist(ui.vehicle)) then
                closePanel()
            end
            Wait(250)
        else
            Wait(750)
        end
    end
end)

---------------------------------------------------------------------------
-- jerry can
---------------------------------------------------------------------------
-- pouring the can on the ground: the inventory saves the new can level a moment after you stop.
-- A fill / pour only starts after that, so the two never overwrite each other.
local lastShot = 0
CreateThread(function()
    while true do
        if GetSelectedPedWeapon(cache.ped) == CAN then
            if IsPedShooting(cache.ped) or IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24) then
                lastShot = GetGameTimer()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function canSettled()
    local untilMs = GetGameTimer() + 3000
    while GetGameTimer() - lastShot < 1200 and GetGameTimer() < untilMs do Wait(100) end
    return GetGameTimer() - lastShot >= 1200
end

local function fillCan(spot)
    if canBusy or fueling then return end
    canBusy = true
    hidePrompt()
    if not canSettled() then canBusy = false return fail('busy') end
    local pump = pumpOf(spot, GetEntityCoords(cache.ped))
    local ok, code, job = lib.callback.await('exti_fuel:server:canStart', false, spot.station, pump)
    if not ok or type(job) ~= 'table' then canBusy = false return fail(code) end

    local at = Config.stations[spot.station].pumps[pump]
    TaskTurnPedToFaceCoord(cache.ped, at.x, at.y, at.z, 700)
    Wait(600)
    local completed = lib.progressCircle({
        duration = job.duration,
        label = ('تعبئة الجالون · %s لتر · %s'):format(amount(job.liters), money(job.cost)),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = FILL_DICT, clip = FILL_CLIP, flag = 49 },
        prop = { model = NOZZLE, bone = 18905, pos = vec3(0.1, 0.02, 0.02), rot = vec3(90.0, 40.0, 170.0), rotOrder = 1 },
    })
    local done, err, r = lib.callback.await('exti_fuel:server:canFinish', false, completed and true or false)
    canBusy = false
    if not done or type(r) ~= 'table' then return fail(err) end
    notify('success', ('عبّأت الجالون %s لتر — دفعت %s'):format(amount(r.liters), money(r.paid)))
end

local function pourTarget()
    local p = GetEntityCoords(cache.ped)
    local vehicle = lib.getClosestVehicle(p, Config.canReach, false)
    if not vehicle or not NetworkGetEntityIsNetworked(vehicle) then return nil end
    local uses, electric = fuelKind(vehicle)
    if not uses or electric then return nil end
    if #(p - capPosition(vehicle)) > 2.4 then return nil end
    return vehicle
end

local function pourCan(vehicle)
    if canBusy or fueling then return end
    canBusy = true
    hidePrompt()
    if not canSettled() then canBusy = false return fail('busy') end
    local ok, code, job = lib.callback.await('exti_fuel:server:pourStart', false, NetworkGetNetworkIdFromEntity(vehicle))
    if not ok or type(job) ~= 'table' then canBusy = false return fail(code) end

    local cap = capPosition(vehicle)
    TaskTurnPedToFaceCoord(cache.ped, cap.x, cap.y, cap.z, 700)
    Wait(600)
    local completed = lib.progressCircle({
        duration = job.duration,
        label = ('صب الوقود · %s لتر'):format(amount(job.liters)),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flag = 49 },
    })
    local done, err, r = lib.callback.await('exti_fuel:server:canFinish', false, completed and true or false)
    canBusy = false
    if not done or type(r) ~= 'table' then return fail(err) end
    notify('success', ('صببت %s لتر في المركبة — بقي في الجالون %s'):format(amount(r.liters), iso(('%d%%'):format(r.can))))
end

---------------------------------------------------------------------------
-- buying a jerry can at the pump: from the pump screen (with a vehicle), or straight from the pump
-- with E when no vehicle is parked at it
---------------------------------------------------------------------------
local function openCanCard(spot)
    if ui.open or ui.opening or fueling or canBusy then return end
    ui.opening = true
    local pump = pumpOf(spot, GetEntityCoords(cache.ped))
    local ok, code, data = lib.callback.await('exti_fuel:server:canQuote', false, spot.station, pump)
    ui.opening = false
    if not ok or type(data) ~= 'table' then return fail(code) end
    if cache.vehicle or isDown() then return end
    hidePrompt()
    ui.open, ui.spot, ui.pump, ui.canOnly = true, spot, pump, true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCan', data = data })
end

-- from the pump screen or the jerry can card: the pump you are standing at sells it
RegisterNUICallback('buyCan', function(data, cb)
    if not ui.open or not ui.spot or not ui.pump or type(data) ~= 'table' then return cb({ ok = false, code = 'failed' }) end
    local ok, code, r = lib.callback.await('exti_fuel:server:buyCan', false, ui.spot.station, ui.pump, data.account)
    cb({ ok = ok and true or false, code = code, cash = r and r.cash, bank = r and r.bank })
end)

---------------------------------------------------------------------------
-- stations close to you (twice a second)
---------------------------------------------------------------------------
local nearSpots = {}
CreateThread(function()
    while true do
        local p = GetEntityCoords(cache.ped)
        local list = {}
        for _, spot in ipairs(spots) do
            local center = Config.stations[spot.station].center
            if #(p.xy - center.xy) < STATION_NEAR and #(p.xy - spot.pos.xy) < DRAW + 4.0 then
                list[#list + 1] = spot
            end
        end
        nearSpots = list
        Wait(500)
    end
end)

---------------------------------------------------------------------------
-- circles, prompts and the E key
---------------------------------------------------------------------------
local pourCheck = { at = 0 }
CreateThread(function()
    while true do
        local sleep = 400
        local ped = cache.ped
        local onFoot = not cache.vehicle
        local blocked = ui.open or ui.opening or fueling or canBusy or IsNuiFocused() or lib.progressActive()
            or isDown()
        local p = GetEntityCoords(ped)
        local here, inCarNear

        for i = 1, #nearSpots do
            local spot = nearSpots[i]
            local d = #(p.xy - spot.pos.xy)
            local dz = math.abs(p.z - spot.pos.z)
            if d < DRAW and dz < 4.0 then
                sleep = 0
                local inside = onFoot and not blocked and d <= Config.pumpRadius and dz < 2.6
                -- EX_Tii: no circle at the pumps (walk up to the pump and press E), unless turned back on in config
                if Config.pumpCircles then
                    GoldCircle.draw(spot.key, spot.pos.x, spot.pos.y, floorZ(spot.pos.x, spot.pos.y, spot.pos.z) + 0.03,
                        Config.pumpRadius, inside, GOLD)
                end
                if inside and (not here or d < here.d) then here = { spot = spot, d = d } end
                if not onFoot and cache.seat == -1 and d < Config.vehicleReach then inCarNear = true end
            end
        end

        local holdingCan = onFoot and not blocked and GetSelectedPedWeapon(ped) == CAN
        local pressed = (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName()))

        if here then
            sleep = 0
            local spot = here.spot
            if holdingCan then
                showPrompt('[E] تعبئة الجالون')
                if pressed then CreateThread(function() fillCan(spot) end) end
            else
                local vehicle = vehicleAtPump(spot.pos)
                if vehicle then
                    local _, electric = fuelKind(vehicle)
                    showPrompt(electric and '[E] شحن المركبة' or '[E] تعبئة الوقود')
                    if pressed then CreateThread(function() openPanel(spot, vehicle) end) end
                else
                    -- no vehicle here: the pump sells a full jerry can
                    showPrompt(('[E] جالون وقود · %s'):format(money(Config.canPrice)))
                    if pressed then CreateThread(function() openCanCard(spot) end) end
                end
            end
        elseif holdingCan then
            local now = GetGameTimer()
            if now - pourCheck.at > 250 then pourCheck.at, pourCheck.vehicle = now, pourTarget() end
            local vehicle = pourCheck.vehicle
            if vehicle and DoesEntityExist(vehicle) then
                sleep = 0
                showPrompt('[E] صب الوقود في المركبة')
                if pressed then
                    pourCheck.vehicle = nil
                    CreateThread(function() pourCan(vehicle) end)
                end
            else
                sleep = math.min(sleep, 250)
                hidePrompt()
            end
        elseif inCarNear and GetEntitySpeed(cache.vehicle) < 1.5 and not blocked then
            showPrompt('انزل من المركبة لتبدأ التعبئة')
        else
            hidePrompt()
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- driving: fuel goes down with GTA's own fuel use (x Config.fuelUseMultiplier),
-- electric battery goes down with the distance driven. The server gets the new level now and then.
---------------------------------------------------------------------------
local function report(vehicle, level)
    if not NetworkGetEntityIsNetworked(vehicle) then return end
    level = math.floor(level * 10 + 0.5) / 10 -- the server keeps one decimal
    drive.sent = level
    TriggerServerEvent('exti_fuel:server:report', level + 0.0, NetworkGetNetworkIdFromEntity(vehicle))
end

local function driveLoop(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local uses, electric = fuelKind(vehicle)
    if not uses then return end

    local token = {}
    drive.token, drive.vehicle, drive.sent = token, vehicle, nil
    local state = Entity(vehicle).state
    local function known() return type(state.fuel) == 'number' end

    -- first time this vehicle is seen (new or AI car): the game's own level, sent again until the
    -- server has it (right after you sit down the server may not see you in the seat yet)
    local tries = 0
    while not known() and tries < 5 and drive.token == token and cache.vehicle == vehicle and cache.seat == -1 do
        tries = tries + 1
        local reading = GetVehicleFuelLevel(vehicle)
        if electric and reading <= 0.5 then reading = 100.0 end -- a new electric car reads 0: it is charged
        report(vehicle, reading)
        local untilMs = GetGameTimer() + 1000
        while not known() and GetGameTimer() < untilMs do Wait(50) end
    end
    if drive.token ~= token then return end

    -- electric: the battery level is kept here (the game itself never uses an electric car's "fuel")
    local level
    if known() then
        level = state.fuel + 0.0
        drive.sent = level
    else
        level = GetVehicleFuelLevel(vehicle)
        if electric and level <= 0.5 then level = 100.0 end
    end
    SetVehicleFuelLevel(vehicle, level)
    drive.level = level

    local lastSend = GetGameTimer()
    local lastPos = GetEntityCoords(vehicle)
    while drive.token == token and cache.vehicle == vehicle and cache.seat == -1 and DoesEntityExist(vehicle) do
        local running = GetIsVehicleEngineRunning(vehicle)

        if electric then
            SetFuelConsumptionRateMultiplier(0.0)
            level = drive.level
            local pos = GetEntityCoords(vehicle)
            if running and level > 0.0 then
                local meters = #(pos - lastPos)
                if meters > 150.0 then meters = 0.0 end -- teleported
                level = math.max(0.0, level - meters / (Config.evRangeKm * 1000.0) * 100.0 - Config.evIdlePerMinute / 60.0)
            end
            lastPos = pos
            drive.level = level
            SetVehicleFuelLevel(vehicle, level)
            if level <= 0.0 and known() then SetVehicleUndriveable(vehicle, true) end
        else
            SetFuelConsumptionRateMultiplier(running and Config.fuelUseMultiplier or 0.0)
            level = GetVehicleFuelLevel(vehicle)
            if running and level > 0.0 and GetVehiclePetrolTankHealth(vehicle) < Config.leakWhenTankBelow then
                level = math.max(0.0, level - math.random(10, 20) * 0.01)
                SetVehicleFuelLevel(vehicle, level)
            end
        end

        local now = GetGameTimer()
        local unset = not known()
        if now - lastSend >= (unset and 2000 or Config.reportEvery * 1000) then
            lastSend = now
            if unset or not drive.sent or math.abs(level - drive.sent) >= 0.05 then report(vehicle, level) end
        end
        Wait(1000)
    end

    -- got out or changed seat: the last level
    if DoesEntityExist(vehicle) and level then
        if not drive.sent or math.abs(level - drive.sent) >= 0.05 then report(vehicle, level) end
    end
    if drive.token == token then drive.token, drive.vehicle, drive.sent, drive.level = nil, nil, nil, nil end
end

lib.onCache('seat', function(seat)
    if seat == -1 then
        SetTimeout(0, function() driveLoop(cache.vehicle) end)
    end
end)
if cache.seat == -1 and cache.vehicle then CreateThread(function() driveLoop(cache.vehicle) end) end

-- a new level from the server (pump, jerry can, admin, mechanic): every game near the vehicle shows it
local function applyLevel(vehicle, value)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    local before = GetVehicleFuelLevel(vehicle)
    if drive.vehicle == vehicle then
        if drive.sent and math.abs(value - drive.sent) < 0.06 then return end -- our own report coming back
        drive.sent = value
        before = drive.level or before
        drive.level = value
    end
    SetVehicleFuelLevel(vehicle, value + 0.0)
    -- filled up: the car drives again (vehiclehandler stops fuel cars at 7%, an empty battery stops at 0%)
    local electric = Config.electricModel(GetEntityModel(vehicle))
    if value > before + 0.5 and value > (electric and 0.5 or 7.5) and GetVehicleEngineHealth(vehicle) > 0.0 then
        SetVehicleUndriveable(vehicle, false)
    end
end

AddStateBagChangeHandler('fuel', nil, function(bagName, _, value)
    if type(value) ~= 'number' then return end
    local vehicle = GetEntityFromStateBagName(bagName)
    if vehicle and vehicle ~= 0 then return applyLevel(vehicle, value) end
    -- a vehicle that was just created: the level can arrive a moment before the vehicle itself
    CreateThread(function()
        local untilMs = GetGameTimer() + 3000
        repeat
            Wait(100)
            vehicle = GetEntityFromStateBagName(bagName)
        until (vehicle and vehicle ~= 0) or GetGameTimer() > untilMs
        if vehicle and vehicle ~= 0 and Entity(vehicle).state.fuel == value then applyLevel(vehicle, value) end
    end)
end)

---------------------------------------------------------------------------
-- clean up
---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ui.open then SetNuiFocus(false, false) end
    if shownText then lib.hideTextUI() end
    if fueling then
        removeHose(fueling.hose)
        if fueling.nozzle and DoesEntityExist(fueling.nozzle) then DeleteEntity(fueling.nozzle) end
        ClearPedTasks(cache.ped)
    end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)

-- for other scripts
exports('GetFuel', function(vehicle)
    vehicle = vehicle or cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    local level = Entity(vehicle).state.fuel
    return type(level) == 'number' and level or GetVehicleFuelLevel(vehicle)
end)
