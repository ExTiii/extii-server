-- newplayer_guide / client.lua

local text = Config.text
local myJob -- the job table (name, type, onduty)

local function refreshJob()
    local data = exports.qbx_core:GetPlayerData()
    myJob = data and data.job or nil
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    myJob = job
end)
RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    if myJob then myJob.onduty = onDuty end
end)

-- EX_Tii: only police (any police job) and EMS who are ON DUTY may use weapons in a safe zone
local function exempt()
    if not myJob or not myJob.onduty then return false end
    return myJob.type == 'leo' or myJob.type == 'ems' or Config.safeZones.ignoreJobs[myJob.name] == true
end

-- the label waits until the player is really in the city (not in the arrival movie)
local function canShowLabel()
    return LocalPlayer.state.isLoggedIn and GetRenderingCam() == -1
end

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

-- EX_Tii: the guide is our own black & gold screen (html/), its text is in config.lua (Config.guide)
local guideOpen = false

local function openGuide(welcome)
    if guideOpen then return end
    guideOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', guide = Config.guide, welcome = welcome == true })
end

local function closeGuide()
    if not guideOpen then return end
    guideOpen = false
    SetNuiFocus(false, false)
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closeGuide()
end)

RegisterNUICallback('gps', function(_, cb)
    cb(1)
    setCityHallWaypoint()
end)

RegisterCommand(Config.guideCommand, function() openGuide(false) end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.guideCommand, 'افتح دليل المدينة')

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and guideOpen then SetNuiFocus(false, false) end
end)

-- logging out (back to the character list) closes the guide
local function forceClose()
    if not guideOpen then return end
    SendNUIMessage({ action = 'close' })
    closeGuide()
end
RegisterNetEvent('QBCore:Client:OnPlayerUnload', forceClose)
RegisterNetEvent('qbx_core:client:playerLoggedOut', forceClose)

---------------------------------------------------------------------
-- Welcome on first spawn: the guide opens by itself, on its first page
---------------------------------------------------------------------

local function showWelcome()
    -- wait until the arrival movie is over and the player can move
    local untilTime = GetGameTimer() + 60000
    while (IsScreenFadedOut() or IsScreenFadingIn() or IsPlayerSwitchInProgress() or GetRenderingCam() ~= -1)
        and GetGameTimer() < untilTime do
        Wait(500)
    end
    Wait(2000)
    openGuide(true)
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

-- EX_Tii (Moe): the safe zone shows as a green half-circle light at the bottom of the screen (not a text line)
local function safeLight(on)
    if showingSafeUI == on then return end
    showingSafeUI = on
    SendNUIMessage({ action = 'safe', on = on, text = text.safeZoneEnter })
end

local nextLabelCheck = 0

local function blockCombat()
    if exempt() then
        safeLight(false)
        return
    end

    -- EX_Tii: the "[E] ..." labels (job center, shops) use the same spot on screen; when one of them
    -- closes, bring the safe-zone label back (and show it once the arrival movie is over)
    if GetGameTimer() > nextLabelCheck then
        nextLabelCheck = GetGameTimer() + 500
        if canShowLabel() then safeLight(true) end
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
    if zonesInside == 1 and not exempt() and canShowLabel() then safeLight(true) end
end

local function onExitSafeZone()
    zonesInside = math.max(zonesInside - 1, 0)
    if zonesInside == 0 then safeLight(false) end
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
    createSafeZones()
    startTagThreads()
    refreshJob()
end)
