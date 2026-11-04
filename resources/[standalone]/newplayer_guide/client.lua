-- newplayer_guide / client.lua

local text = Config.text
local myJob

local function refreshJob()
    local data = exports.qbx_core:GetPlayerData()
    myJob = data and data.job and data.job.name or nil
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    myJob = job and job.name or nil
end)

---------------------------------------------------------------------
-- Guide menu
---------------------------------------------------------------------

local function setCityHallWaypoint()
    -- EX_Tii: thin gold GPS line + a pin (exti_gps); without it, GTA's map marker like before
    local c = Config.cityHall
    local ok, done = false, false
    if GetResourceState('exti_gps') == 'started' then
        ok, done = pcall(function() return exports.exti_gps:GoTo(c.x, c.y, c.z, 'مركز التوظيف') end)
    end
    if not (ok and done) then SetNewWaypoint(c.x, c.y) end
    lib.notify({ description = text.waypointSet, type = 'success' })
end

local function registerGuide()
    local mainOptions = {}

    for _, page in ipairs(Config.guide.pages) do
        local pageId = 'npg_page_' .. page.id
        local options = {}

        for _, line in ipairs(page.lines) do
            options[#options + 1] = {
                title = line[1],
                description = line[2],
                readOnly = true,
            }
        end

        if page.waypoint then
            options[#options + 1] = {
                title = 'حدّد مركز التوظيف على الخريطة',
                icon = 'location-dot',
                onSelect = setCityHallWaypoint,
            }
        end

        lib.registerContext({
            id = pageId,
            title = page.title,
            menu = 'npg_main',
            options = options,
        })

        mainOptions[#mainOptions + 1] = {
            title = page.title,
            description = page.description,
            icon = page.icon,
            menu = pageId,
            arrow = true,
        }
    end

    mainOptions[#mainOptions + 1] = {
        title = 'حدّد مركز التوظيف على الخريطة',
        description = 'مركز التوظيف (Job Center): هنا تجد الوظائف',
        icon = 'location-dot',
        onSelect = setCityHallWaypoint,
    }

    lib.registerContext({
        id = 'npg_main',
        title = Config.guide.title,
        options = mainOptions,
    })
end

local function openGuide()
    lib.showContext('npg_main')
end

RegisterCommand(Config.guideCommand, openGuide, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.guideCommand, 'افتح دليل اللاعب الجديد')

---------------------------------------------------------------------
-- Welcome on first spawn
---------------------------------------------------------------------

local function showWelcome()
    -- wait until the screen is visible after spawning
    while IsScreenFadedOut() or IsScreenFadingIn() do
        Wait(500)
    end
    Wait(3000)

    local choice = lib.alertDialog({
        header = text.welcomeHeader,
        content = text.welcomeBody,
        centered = true,
        cancel = true,
        labels = { confirm = text.welcomeConfirm, cancel = text.welcomeCancel },
    })

    if choice == 'confirm' then
        openGuide()
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshJob()

    local result = lib.callback.await('newplayer_guide:server:loaded', false)
    if result and result.firstTime then
        CreateThread(showWelcome)
    end
end)

---------------------------------------------------------------------
-- Safe zones
---------------------------------------------------------------------

local zonesInside = 0
local showingSafeUI = false

local nextLabelCheck = 0

local function blockCombat()
    if Config.safeZones.ignoreJobs[myJob] then return end

    -- EX_Tii: the "[E] ..." labels (job center, shops) use the same spot on screen; when one of them
    -- closes, bring the safe-zone label back
    if showingSafeUI and GetGameTimer() > nextLabelCheck then
        nextLabelCheck = GetGameTimer() + 500
        if not lib.isTextUIOpen() then
            lib.showTextUI(text.safeZoneEnter, { position = 'top-center', icon = 'shield-halved' })
        end
    end

    DisablePlayerFiring(cache.playerId, true)
    DisableControlAction(0, 24, true)  -- attack
    DisableControlAction(0, 25, true)  -- aim
    DisableControlAction(0, 140, true) -- melee light
    DisableControlAction(0, 141, true) -- melee heavy
    DisableControlAction(0, 142, true) -- melee alternate
    DisableControlAction(0, 257, true) -- attack 2
    DisableControlAction(0, 263, true) -- melee attack 1
    DisableControlAction(0, 264, true) -- melee attack 2
    DisableControlAction(0, 69, true)  -- vehicle attack
    DisableControlAction(0, 70, true)  -- vehicle attack 2
    DisableControlAction(0, 92, true)  -- vehicle passenger attack
end

local function onEnterSafeZone()
    zonesInside = zonesInside + 1
    if zonesInside == 1 and not Config.safeZones.ignoreJobs[myJob] then
        lib.showTextUI(text.safeZoneEnter, { position = 'top-center', icon = 'shield-halved' })
        showingSafeUI = true
    end
end

local function onExitSafeZone()
    zonesInside = math.max(zonesInside - 1, 0)
    if zonesInside == 0 and showingSafeUI then
        lib.hideTextUI()
        showingSafeUI = false
    end
end

local function createSafeZones()
    if not Config.safeZones.enabled then return end

    for _, zone in ipairs(Config.safeZones.zones) do
        lib.zones.sphere({
            coords = zone.coords,
            radius = zone.radius,
            onEnter = onEnterSafeZone,
            onExit = onExitSafeZone,
            inside = blockCombat,
        })
    end
end

---------------------------------------------------------------------
-- NEW tag above new players' heads
---------------------------------------------------------------------

local nearbyNew = {}

local function drawTag(coords)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(120, 230, 120, 230)
    SetTextOutline()
    SetTextCentre(true)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(Config.newPlayerTag.text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function startTagThreads()
    if not Config.newPlayerTag.enabled then return end

    local maxDist = Config.newPlayerTag.distance

    -- scan once a second for new players close by
    CreateThread(function()
        while true do
            local list = {}
            local myCoords = GetEntityCoords(cache.ped)

            for _, pid in ipairs(GetActivePlayers()) do
                if pid ~= cache.playerId then
                    local serverId = GetPlayerServerId(pid)
                    if Player(serverId).state.npg_new then
                        local ped = GetPlayerPed(pid)
                        if ped ~= 0 and IsEntityVisible(ped)
                            and #(myCoords - GetEntityCoords(ped)) < maxDist + 5.0 then
                            list[#list + 1] = ped
                        end
                    end
                end
            end

            nearbyNew = list
            Wait(1000)
        end
    end)

    -- draw only while someone is near, otherwise sleep
    CreateThread(function()
        while true do
            if #nearbyNew == 0 then
                Wait(500)
            else
                local myCoords = GetEntityCoords(cache.ped)
                for i = 1, #nearbyNew do
                    local ped = nearbyNew[i]
                    if DoesEntityExist(ped) then
                        local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                        if #(myCoords - head) < maxDist then
                            drawTag(vec3(head.x, head.y, head.z + 0.45))
                        end
                    end
                end
                Wait(0)
            end
        end
    end)
end

---------------------------------------------------------------------
-- Staff list of new players (/newplayers)
---------------------------------------------------------------------

RegisterNetEvent('newplayer_guide:client:staffList', function(players)
    local options = {}

    for _, p in ipairs(players) do
        options[#options + 1] = {
            title = ('[%d] %s'):format(p.id, p.name),
            description = text.staffMinutes:format(p.minutes),
            readOnly = true,
        }
    end

    if #options == 0 then
        options[1] = { title = text.staffNone, readOnly = true }
    end

    lib.registerContext({ id = 'npg_staff', title = text.staffTitle, options = options })
    lib.showContext('npg_staff')
end)

---------------------------------------------------------------------
-- Start
---------------------------------------------------------------------

CreateThread(function()
    registerGuide()
    createSafeZones()
    startTagThreads()
    refreshJob()
end)
