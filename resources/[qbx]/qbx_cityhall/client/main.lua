local config = require 'config.client'
local sharedConfig = require 'config.shared'
local inRangeCityhall = false
local pedsSpawned = false
local table_clone = table.clone
local blips = {}      -- every blip we made (main icons + the soft glow around them)
local mainBlips = {}  -- just the icons (used to make them flash for new players)
local zones = {}
local pedGeneration = 0 -- EX_Tii: old helper threads stop when the employee is made again

local function getClosestHall()
    local playerCoords = GetEntityCoords(cache.ped)
    local distance = #(playerCoords - sharedConfig.cityhalls[1].coords)
    local closest = 1
    for i = 1, #sharedConfig.cityhalls do
        local hall = sharedConfig.cityhalls[i]
        local dist = #(playerCoords - hall.coords)
        if dist < distance then
            distance = dist
            closest = i
        end
    end
    return closest
end

local function pairsInOrder(object, _)
    local a = {}
    for n in pairs(object) do
        a[#a + 1] = n
    end
    table.sort(a, _)
    local i = 0
    local iterator = function()
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], object[a[i]]
        end
    end
    return iterator
end

local function openIdentificationMenu(closestCityhall)
    local licensesMeta = QBX.PlayerData.metadata.licences
    local availableLicenses = table_clone(sharedConfig.cityhalls[closestCityhall].licenses)
    for license in pairs(availableLicenses) do
        if license and not licensesMeta[license] then
            availableLicenses[license] = nil
        end
    end
    local identityOptions = {}
    for item, id in pairsInOrder(availableLicenses) do
        identityOptions[#identityOptions + 1] = {
            title = id.label,
            description = locale('info.price', id.cost),
            onSelect = function()
                lib.callback.await('qbx_cityhall:server:requestId', false, item, closestCityhall)
                if not config.useTarget and inRangeCityhall then
                    lib.showTextUI(locale('info.open_cityhall'))
                end
            end
        }
    end
    lib.registerContext({
        id = 'cityhall_identity_menu',
        title = locale('info.identity'),
        menu = 'cityhall_menu',
        onExit = function()
            if not config.useTarget and inRangeCityhall then
                lib.showTextUI(locale('info.open_cityhall'))
            end
        end,
        options = identityOptions
    })
    lib.showContext('cityhall_identity_menu')
end

local function openEmploymentMenu()
    local jobOptions = {}
    for job, label in pairsInOrder(sharedConfig.employment.jobs) do
        jobOptions[#jobOptions + 1] = {
            title = label,
            onSelect = function()
                lib.callback.await('qbx_cityhall:server:applyJob', false, job)
                if not config.useTarget and inRangeCityhall then
                    lib.showTextUI(locale('info.open_cityhall'))
                end
            end
        }
    end
    lib.registerContext({
        id = 'cityhall_employment_menu',
        title = locale('info.employment'),
        menu = 'cityhall_menu',
        onExit = function()
            if not config.useTarget and inRangeCityhall then
                lib.showTextUI(locale('info.open_cityhall'))
            end
        end,
        options = jobOptions
    })
    lib.showContext('cityhall_employment_menu')
end

local function openCityhallMenu()
    local closestCityhall = getClosestHall()
    local options = {}

    options[#options + 1] = {
        title = locale('info.identity'),
        description = locale('info.obtain_license_identity'),
        onSelect = function()
            openIdentificationMenu(closestCityhall)
        end
    }

    if sharedConfig.employment.enabled then
        options[#options + 1] = {
            title = locale('info.employment'),
            description = locale('info.select_job'),
            onSelect = openEmploymentMenu
        }
    end

    lib.registerContext({
        id = 'cityhall_menu',
        title = locale('info.cityhall'),
        onExit = function()
            if not config.useTarget and inRangeCityhall then
                lib.showTextUI(locale('info.open_cityhall'))
            end
        end,
        options = options
    })
    lib.showContext('cityhall_menu')
    if not config.useTarget then return end
    inRangeCityhall = false
end

local function createBlip(cityhall)
    local data = cityhall.blip
    local c = cityhall.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipDisplay(blip, data.display or 4)
    SetBlipScale(blip, data.scale or 1.0)
    SetBlipColour(blip, data.colour or 1)
    SetBlipAsShortRange(blip, data.shortRange or false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.label or locale('info.cityhall'))
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
    mainBlips[#mainBlips + 1] = blip

    -- EX_Tii: gold ring around the icon, always on top, and a soft gold glow on the map
    if data.fancy then
        SetBlipPriority(blip, 12)
        SetBlipSecondaryColour(blip, 232, 181, 71)
        ShowOutlineIndicatorOnBlip(blip, true)
        local glow = AddBlipForRadius(c.x, c.y, c.z, data.glowRadius or 28.0)
        SetBlipColour(glow, data.colour or 5)
        SetBlipAlpha(glow, data.glowAlpha or 70)
        SetBlipDisplay(glow, 4)
        blips[#blips + 1] = glow
    end
end

local function deleteBlips()
    for i = 1, #blips do
        local blip = blips[i]
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blips = {}
    mainBlips = {}
end

local function initBlips()
    deleteBlips() -- never twice (resource start + character loaded)
    for i = 1, #sharedConfig.cityhalls do
        local cityhall = sharedConfig.cityhalls[i]
        if cityhall.showBlip and cityhall.blip then
            createBlip({ blip = cityhall.blip, coords = cityhall.coords })
        end
    end
end

-- new players: make the job center flash on the map for a few seconds
AddEventHandler('qbx_cityhall:client:highlight', function()
    for i = 1, #mainBlips do
        local blip = mainBlips[i]
        if DoesBlipExist(blip) then
            SetBlipFlashes(blip, true)
            SetBlipFlashInterval(blip, 450)
        end
    end
    SetTimeout(15000, function()
        for i = 1, #mainBlips do
            if DoesBlipExist(mainBlips[i]) then SetBlipFlashes(mainBlips[i], false) end
        end
    end)
end)

local function makePed(current, i, z)
    local ped = CreatePed(0, current.model, current.coords.x, current.coords.y, z, current.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, current.scenario, 0, true)
    current.pedHandle = ped
    if config.useTarget then
        exports.ox_target:addLocalEntity(ped, {{
            name = 'open_cityhall' .. i,
            icon = 'fa-solid fa-city',
            label = locale('info.target_open_cityhall'),
            distance = 1.5,
            debug = true,
            onSelect = function()
                inRangeCityhall = true
                openCityhallMenu()
            end
        }})
    end
end

-- EX_Tii: once you are close enough for the ground to be loaded, stand the employee
-- exactly on the floor (the height in the config may be a little off)
local function standOnGround(current, i)
    local generation = pedGeneration
    CreateThread(function()
        local c = current.coords
        local spot = vec3(c.x, c.y, c.z)
        while pedsSpawned and current.pedHandle and generation == pedGeneration do
            if #(GetEntityCoords(cache.ped) - spot) < 120.0 then
                RequestCollisionAtCoord(c.x, c.y, c.z)
                for _ = 1, 50 do
                    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 3.0, false)
                    if found then
                        if math.abs(gz - c.z) > 0.2 and math.abs(gz - c.z) < 6.0 and current.pedHandle and generation == pedGeneration then
                            if DoesEntityExist(current.pedHandle) then DeletePed(current.pedHandle) end
                            lib.requestModel(current.model, 5000)
                            makePed(current, i, gz)
                            SetModelAsNoLongerNeeded(current.model)
                        end
                        return
                    end
                    Wait(100)
                end
            end
            Wait(2000)
        end
    end)
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

-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

-- EX_Tii: the spot in front of the employee; walk up and press E (the gold circle only shows with
-- circle.show = true in config/client.lua). Replaces the old invisible box around the employee.
local circleGeneration = 0
local function goldCircle(current)
    circleGeneration += 1
    local generation = circleGeneration
    local cfg = current.circle
    local c = current.coords
    local h = math.rad(c.w)
    local center = vec3(c.x - math.sin(h) * cfg.distance, c.y + math.cos(h) * cfg.distance, c.z)
    local floorZ
    local colour = { cfg.colour[1], cfg.colour[2], cfg.colour[3] }
    local inside = false

    local function leave()
        if inside then
            inside = false
            inRangeCityhall = false
            lib.hideTextUI()
        end
    end

    CreateThread(function()
        while generation == circleGeneration do
            local me = GetEntityCoords(cache.ped)
            local dist = #(me.xy - center.xy)
            if dist > cfg.drawDistance then
                leave()
                Wait(1000)
            else
                if not floorZ then
                    RequestCollisionAtCoord(center.x, center.y, center.z)
                    local found, gz = GetGroundZFor_3dCoord(center.x, center.y, center.z + 3.0, false)
                    if found and math.abs(gz - center.z) < 6.0 then floorZ = gz end
                end
                local z = (floorZ or center.z) + 0.03
                -- (it also shows in the new-player arrival camera; E only works once you are in the city)
                local reach = cfg.show == false and (cfg.reach or 1.4) or (cfg.radius + 0.25)
                local here = dist < reach and math.abs(me.z - z) < 2.0 and LocalPlayer.state.isLoggedIn and not isDown()
                if cfg.show ~= false then GoldCircle.draw(center.x, center.y, z, cfg.radius, here, colour) end

                -- EX_Tii: no "[E]" line under the job center tablet while it is open
                if here and GetResourceState('exti_jobs') == 'started' and exports.exti_jobs:isPanelOpen() then
                    here = false
                end
                if here then
                    if not inside then
                        inside = true
                        inRangeCityhall = true
                        lib.showTextUI(locale('info.open_cityhall'))
                    end
                    if (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then
                        lib.hideTextUI()
                        -- EX_Tii: the job center tablet (jobs + documents); the old menu only if it is missing
                        if GetResourceState('exti_jobs') == 'started' then
                            exports.exti_jobs:openJobCenter()
                        else
                            openCityhallMenu()
                        end
                    end
                else
                    leave()
                end
                Wait(0)
            end
        end
        leave()
    end)
end

local function spawnPeds()
    if not config.peds or not next(config.peds) or pedsSpawned then return end
    pedGeneration += 1
    for i = 1, #config.peds do
        local current = config.peds[i]
        current.model = type(current.model) == 'string' and joaat(current.model) or current.model
        lib.requestModel(current.model, 5000)
        makePed(current, i, current.coords.z)
        SetModelAsNoLongerNeeded(current.model)
        if not config.useTarget and current.circle then
            goldCircle(current)
        elseif not config.useTarget then
            local options = current.zoneOptions
            if options then
                zones[#zones + 1] = lib.zones.box({
                    name = 'cityhall',
                    coords = current.coords.xyz,
                    size = vec3(2, 2, current.groundFix and 5 or 3),
                    rotation = current.coords.w,
                    debug = false,
                    onEnter = function()
                        inRangeCityhall = true
                        lib.showTextUI(locale('info.open_cityhall'))
                    end,
                    onExit = function()
                        lib.hideTextUI()
                        inRangeCityhall = false
                    end,
                    inside = function()
                        if (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then
                            openCityhallMenu()
                            lib.hideTextUI()
                        end
                    end,
                })
            end
        end
    end
    pedsSpawned = true
    for i = 1, #config.peds do
        if config.peds[i].groundFix then standOnGround(config.peds[i], i) end
    end
end

local function deletePeds()
    if not config.peds or not next(config.peds) or not pedsSpawned then return end
    for i = 1, #config.peds do
        local current = config.peds[i]
        if current.pedHandle then
            if DoesEntityExist(current.pedHandle) then DeletePed(current.pedHandle) end
            current.pedHandle = nil
        end
    end
    for i = 1, #zones do zones[i]:remove() end
    zones = {}
    circleGeneration += 1 -- the gold circle stops too
    if inRangeCityhall and not config.useTarget then lib.hideTextUI() end
    inRangeCityhall = false
    pedsSpawned = false -- EX_Tii: so the employee can be made again
    pedGeneration += 1
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    initBlips()
    spawnPeds()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    initBlips()
    spawnPeds()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    deleteBlips()
    -- EX_Tii: the employee stays (new players see him in the arrival camera)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    deleteBlips()
    deletePeds()
end)