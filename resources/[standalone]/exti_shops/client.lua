-- EX_Tii shops (client): shopkeepers, gold circles, map icons, E to talk, the shop panel.

local GOLD = { 232, 181, 71 }
local CLERK_IN, CLERK_OUT = 70.0, 90.0 -- shopkeepers appear / disappear at these distances
local DRAW = 14.0                      -- circles show from this close
local places = {}
local nearby = {}
local ui = { open = false }

-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

---------------------------------------------------------------------------
-- floor height under a spot (cached)
---------------------------------------------------------------------------
local floors = {}
local function floorZ(x, y, z)
    local key = ('%d:%d:%d'):format(math.floor(x * 2), math.floor(y * 2), math.floor(z))
    local hit = floors[key]
    if hit then return hit end
    RequestCollisionAtCoord(x, y, z)
    for _, up in ipairs({ 0.5, 1.5 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + up, false)
        if found and math.abs(gz - z) < 4.0 then
            floors[key] = gz
            return gz
        end
    end
    return z - 0.98
end

---------------------------------------------------------------------------
-- the gold circle (same look as the garages, dealers and jobs)
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

    function GoldCircle.draw(x, y, fz, radius, here, color)
        local now = GetGameTimer()
        local c
        for i = 1, #list do
            local o = list[i]
            if o.radius == radius and now - o.last <= GRACE_MS + FADE_MS and (o.x - x) ^ 2 + (o.y - y) ^ 2 < 9.0 then
                c = o
                break
            end
        end
        if not c then
            c = { radius = radius }
            list[#list + 1] = c
        elseif now - c.last > GRACE_MS + 100 then
            c.born = nil
        end
        c.x, c.y, c.z, c.here, c.last, c.color = x, y, fz, here, now, color
        loop()
    end
end

---------------------------------------------------------------------------
-- "[E] ..." line
---------------------------------------------------------------------------
local shownText
local function showPrompt(text)
    if shownText == text then return end
    shownText = text
    lib.showTextUI(text)
end
local function hidePrompt()
    if not shownText then return end
    local mine = shownText
    shownText = nil
    -- (only our own text: a robbery prompt at the till may be up right next to the shopkeeper)
    local open, text = lib.isTextUIOpen()
    if open and type(text) == 'string' and text ~= mine then return end
    lib.hideTextUI()
end

---------------------------------------------------------------------------
-- shopkeepers
---------------------------------------------------------------------------
local function removeClerk(place)
    if place.ped and DoesEntityExist(place.ped) then DeletePed(place.ped) end
    place.ped = nil
end

local function spawnClerk(place)
    if place.spawning or place.ped then return end
    place.spawning = true
    CreateThread(function()
        local model = joaat(place.store.model or place.kind.clerk.model)
        local ok = pcall(lib.requestModel, model, 10000)
        local c = place.store.clerk
        if ok and not place.ped then
            local z = c.z - 1.0
            for _ = 1, 30 do -- wait for the floor to load
                RequestCollisionAtCoord(c.x, c.y, c.z)
                local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
                if found and math.abs(gz - c.z) < 4.0 then z = gz break end
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
                SetPedCanPlayAmbientAnims(ped, true)
                if place.kind.clerk.scenario then TaskStartScenarioInPlace(ped, place.kind.clerk.scenario, 0, true) end
                place.ped = ped
            end
        end
        place.spawning = false
    end)
end

local function say(place, line)
    if place and place.ped and DoesEntityExist(place.ped) then
        PlayPedAmbientSpeechNative(place.ped, line, 'SPEECH_PARAMS_FORCE_NORMAL')
    end
end

---------------------------------------------------------------------------
-- map icons
---------------------------------------------------------------------------
local function createBlip(place)
    local b = place.kind.blip
    if not b then return end
    local c = place.store.clerk
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, b.colour or 3)
    SetBlipScale(blip, 0.75)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(place.kind.label)
    EndTextCommandSetBlipName(blip)
    place.blip = blip
end

---------------------------------------------------------------------------
-- the shop panel
---------------------------------------------------------------------------
local function closePanel()
    if not ui.open then return end
    ui.open = false
    ui.place = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- clothing, barber and tattoo shops open the appearance menu (illenium-appearance)
local APPEARANCE = {
    clothing = 'illenium-appearance:client:openClothingShopMenu',
    barber = 'illenium-appearance:client:OpenBarberShop',
    tattoo = 'illenium-appearance:client:OpenTattooShop',
}

local function openAppearance(place)
    local event = APPEARANCE[place.kind.opens]
    if not event or GetResourceState('illenium-appearance') ~= 'started' then
        lib.notify({ type = 'error', description = 'المتجر مغلق الآن، حاول لاحقًا' })
        return
    end
    hidePrompt()
    say(place, 'GENERIC_HI')
    TriggerEvent(event)
end

-- banks: EX_Tii Bank (the tablet at the teller, the ATM screen)
local function bankReady()
    if GetResourceState('exti_bank') == 'started' then return true end
    lib.notify({ type = 'error', description = 'البنك مغلق الآن، حاول لاحقًا' })
    return false
end

local function openBank(place)
    if not bankReady() then return end
    hidePrompt()
    say(place, 'GENERIC_HI')
    TriggerEvent('exti_bank:client:openTablet')
end

-- EX_Tii hospitals: the receptionist opens the hospital panel (exti_hospital)
local function openHospital(place)
    if GetResourceState('exti_hospital') ~= 'started' then
        lib.notify({ type = 'error', description = 'الاستقبال مشغول الآن، حاول بعد قليل' })
        return
    end
    hidePrompt()
    say(place, 'GENERIC_HI')
    TriggerEvent('exti_hospital:client:openReception', place.store.hospital, place.store.area)
end

local function openPanel(place)
    if place.kind.opens == 'bank' then return openBank(place) end
    if place.kind.opens == 'hospital' then return openHospital(place) end
    if place.kind.opens then return openAppearance(place) end
    if ui.open or ui.opening then return end
    -- EX_Tii heists: a store being robbed (or just robbed) is closed
    local robbed = GlobalState['exti_heists:stores']
    if robbed and robbed[place.index] then
        lib.notify({ type = 'error', description = 'المحل مغلق الآن', position = 'top' })
        return
    end
    ui.opening = true
    local data = lib.callback.await('exti_shops:server:open', false, place.index)
    ui.opening = false
    if not data then
        lib.notify({ type = 'error', description = 'اقترب من البائع أكثر' })
        return
    end
    ui.open = true
    ui.place = place
    hidePrompt()
    say(place, 'GENERIC_HI')
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', shop = data })
end

RegisterNUICallback('close', function(_, cb)
    cb(true)
    closePanel()
end)

RegisterNUICallback('buy', function(data, cb)
    if not ui.open or not ui.place or type(data) ~= 'table' then return cb({ ok = false, code = 'failed' }) end
    local cart = {}
    if type(data.cart) == 'table' then
        for i = 1, #data.cart do
            local line = data.cart[i]
            if type(line) == 'table' and type(line.name) == 'string' then
                cart[#cart + 1] = { name = line.name, count = math.floor(tonumber(line.count) or 0) }
            end
        end
    end
    local ok, code, result = lib.callback.await('exti_shops:server:buy', false, ui.place.index, cart, data.account)
    if ok then say(ui.place, 'GENERIC_THANKS') end
    cb({ ok = ok and true or false, code = code, cash = result and result.cash, bank = result and result.bank, paid = result and result.paid })
end)

-- close the panel if you walk away, get in a car or go down
CreateThread(function()
    while true do
        if ui.open and ui.place then
            local p = GetEntityCoords(cache.ped)
            local circle = ui.place.circle
            if #(p - circle) > Config.useDistance or cache.vehicle or isDown() then
                closePanel()
            end
            Wait(250)
        else
            Wait(750)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ui.open then SetNuiFocus(false, false) end
    hidePrompt()
    for _, place in ipairs(places) do
        removeClerk(place)
        if place.blip then RemoveBlip(place.blip) end
    end
end)

---------------------------------------------------------------------------
-- places
---------------------------------------------------------------------------
for index, store in ipairs(Config.stores) do
    local kind = Config.types[store.type]
    if kind then
        local place = { index = index, store = store, kind = kind, circle = Config.circleOf(store) }
        places[#places + 1] = place
        createBlip(place)
    end
end

-- who is near (twice a second): spawn / remove shopkeepers, list the shops close by
CreateThread(function()
    while true do
        local p = GetEntityCoords(cache.ped)
        local list = {}
        for i = 1, #places do
            local place = places[i]
            local c = place.store.clerk
            local dist = #(p - vec3(c.x, c.y, c.z))
            if dist < CLERK_IN then
                if not place.ped then spawnClerk(place) end
            elseif dist > CLERK_OUT and place.ped then
                removeClerk(place)
            end
            if dist < DRAW + 3.0 then list[#list + 1] = place end
        end
        nearby = list
        Wait(500)
    end
end)

---------------------------------------------------------------------------
-- E only spots (no shopkeeper, no circle): ATMs, vending machines, lockers...
---------------------------------------------------------------------------
local service -- the closest one you can use right now: { prompt, run }
local spotCooldown = 0 -- no second E right after the first (the bank / inventory takes a moment to open)

local function hasJob(jobs)
    if not jobs then return true end
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not job then return false end
    for i = 1, #jobs do
        if jobs[i] == job.name then return true end
    end
    return false
end

local function inventoryReady()
    if GetResourceState('ox_inventory') == 'started' then return true end
    lib.notify({ type = 'error', description = 'غير متاح الآن، حاول لاحقًا' })
    return false
end

local ACTIONS = {
    atm = function()
        if bankReady() then TriggerEvent('exti_bank:client:openAtm') end
    end,
    vending = function()
        if inventoryReady() then exports.ox_inventory:openInventory('shop', { type = 'VendingMachineDrinks' }) end
    end,
    stash = function(point)
        if inventoryReady() then exports.ox_inventory:openInventory('stash', point.stash) end
    end,
    evidence = function()
        if inventoryReady() then exports.ox_inventory:openInventory('policeevidence') end
    end,
    shop = function(point)
        if inventoryReady() then exports.ox_inventory:openInventory('shop', { type = point.shop, id = point.shopId }) end
    end,
}

local function closestObject(p, models, range)
    local best, bestDist
    for i = 1, #models do
        local obj = GetClosestObjectOfType(p.x, p.y, p.z, range, models[i], false, false, false)
        if obj and obj ~= 0 then
            local d = #(p - GetEntityCoords(obj))
            if not bestDist or d < bestDist then best, bestDist = obj, d end
        end
    end
    return best, bestDist
end

CreateThread(function()
    while true do
        local found
        if not ui.open and not cache.vehicle and not isDown() then
            local p = GetEntityCoords(cache.ped)
            local bestDist

            for i = 1, #Config.points do
                local point = Config.points[i]
                local d = #(p - point.coords)
                if d <= (point.radius or 1.2) and (not bestDist or d < bestDist) and hasJob(point.jobs) then
                    found, bestDist = { prompt = point.prompt, run = function() ACTIONS[point.action](point) end }, d
                end
            end

            local atm, atmDist = closestObject(p, Config.atmModels, 1.6)
            if atm and atmDist <= 1.4 and (not bestDist or atmDist < bestDist) then
                found, bestDist = { prompt = '[E] الصراف الآلي', run = ACTIONS.atm }, atmDist
            end

            local machine, machineDist = closestObject(p, Config.vendingModels, 1.6)
            if machine and machineDist <= 1.4 and (not bestDist or machineDist < bestDist) then
                found, bestDist = { prompt = '[E] آلة البيع', run = ACTIONS.vending }, machineDist
            end
        end
        service = found
        Wait(found and 150 or 400)
    end
end)

-- circles and the E key (a shop circle you stand in wins over an E-only spot)
CreateThread(function()
    while true do
        local sleep = 400
        local target, targetDist
        if #nearby > 0 and not ui.open then
            local p = GetEntityCoords(cache.ped)
            for i = 1, #nearby do
                local place = nearby[i]
                local c = place.circle
                local d = #(p.xy - c.xy)
                if d < DRAW and math.abs(p.z - c.z) < 3.0 then
                    sleep = 0
                    -- EX_Tii: no circle at the shopkeepers: walk up to the counter and press E
                    -- (Config.circles = true brings the gold circle back)
                    local reach = Config.circles and Config.circleRadius or Config.reach
                    local here = d <= reach and not cache.vehicle and math.abs(p.z - c.z) < 2.0
                    if Config.circles then
                        local fz = floorZ(c.x, c.y, c.z) + 0.03
                        GoldCircle.draw(c.x, c.y, fz, Config.circleRadius, here, GOLD)
                    end
                    if here and (not target or d < targetDist) then target, targetDist = place, d end
                end
            end
        end

        local busy = IsNuiFocused() or lib.progressActive() or GetGameTimer() < spotCooldown or isDown()
        if busy then target = nil end
        local spot = not busy and not target and not ui.open and service or nil
        if target then
            showPrompt(target.kind.prompt or '[E] تحدّث مع البائع')
            if IsControlJustPressed(0, 38) then
                hidePrompt()
                CreateThread(function() openPanel(target) end)
            end
        elseif spot then
            sleep = 0
            showPrompt(spot.prompt)
            if IsControlJustPressed(0, 38) then
                hidePrompt()
                spotCooldown = GetGameTimer() + 2500
                CreateThread(spot.run)
            end
        else
            hidePrompt()
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- EX_Tii heists: the store robbery uses our shopkeepers (each player's game has its own copy)
---------------------------------------------------------------------------
local function placeOf(index)
    for i = 1, #places do if places[i].index == index then return places[i] end end
end
exports('Stores', function() return Config.stores end)
exports('Clerk', function(index) local p = placeOf(index); return p and p.ped or nil end)
-- back to normal after a robbery: stand where he stands, doing what he does
exports('ClerkReset', function(index)
    local p = placeOf(index)
    if not p or not p.ped or not DoesEntityExist(p.ped) then return end
    local c = p.store.clerk
    ClearPedTasksImmediately(p.ped)
    SetEntityHeading(p.ped, c.w or 0.0)
    if p.kind.clerk.scenario then TaskStartScenarioInPlace(p.ped, p.kind.clerk.scenario, 0, true) end
end)
