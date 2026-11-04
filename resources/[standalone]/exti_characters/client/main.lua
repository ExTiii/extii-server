-- EX_Tii Roleplay — character screens.
-- 1) choose your character  2) create one
-- Returning players go straight back to where they left (welcome-back camera swoop).
-- New players design their look, then arrive next to the job center (one spawn for everyone).

local config = require 'config'

local ui = { phase = nil, clock = false, cinema = false } -- phase: 'select' | 'create' | 'design' | 'busy' | nil (in the city)
local cam
local oldCams = {}
local characters, allowed = {}, 1
local hasLook = {} -- citizenid -> true / false (false = the look was never saved)
local DEFAULT_MODELS = { [0] = `mp_m_freemode_01`, [1] = `mp_f_freemode_01` }

-- starting looks used for the preview while creating (same as the core's defaults)
local DEFAULT_LOOKS = {
    [0] = {
        headOverlays = {
            beard = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            eyebrows = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            chestHair = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            ageing = { color = 0, style = 0, secondColor = 0, opacity = 1 },
        },
        components = {
            { texture = 0, drawable = 0, component_id = 0 }, { texture = 0, drawable = 0, component_id = 1 },
            { texture = 0, drawable = 0, component_id = 2 }, { texture = 0, drawable = 0, component_id = 5 },
            { texture = 0, drawable = 0, component_id = 7 }, { texture = 0, drawable = 0, component_id = 9 },
            { texture = 0, drawable = 0, component_id = 10 }, { texture = 0, drawable = 15, component_id = 11 },
            { texture = 0, drawable = 15, component_id = 8 }, { texture = 0, drawable = 15, component_id = 3 },
            { texture = 0, drawable = 34, component_id = 6 }, { texture = 0, drawable = 61, component_id = 4 },
        },
    },
    [1] = {
        headBlend = { shapeMix = 0.3, skinFirst = 0, shapeFirst = 31, skinSecond = 0, shapeSecond = 0, skinMix = 0, thirdMix = 0, shapeThird = 0, skinThird = 0 },
        hair = { color = 0, style = 15, texture = 0, highlight = 0 },
        headOverlays = {
            ageing = { secondColor = 0, opacity = 1, color = 0, style = 0 },
            eyebrows = { secondColor = 0, opacity = 1, color = 0, style = 0 },
        },
        components = {
            { drawable = 0, component_id = 0, texture = 0 }, { drawable = 0, component_id = 1, texture = 0 },
            { drawable = 0, component_id = 2, texture = 0 }, { drawable = 0, component_id = 5, texture = 0 },
            { drawable = 0, component_id = 7, texture = 0 }, { drawable = 0, component_id = 9, texture = 0 },
            { drawable = 0, component_id = 10, texture = 0 }, { drawable = 15, component_id = 3, texture = 0 },
            { drawable = 15, component_id = 11, texture = 3 }, { drawable = 14, component_id = 8, texture = 0 },
            { drawable = 15, component_id = 4, texture = 3 }, { drawable = 35, component_id = 6, texture = 0 },
        },
    },
}

-- the look editor needs all 12 face layers; a missing one stops it half way (no hair, no eye colour)
local FACE_LAYERS = {
    'blemishes', 'beard', 'eyebrows', 'ageing', 'makeUp', 'blush',
    'complexion', 'sunDamage', 'lipstick', 'moleAndFreckles', 'chestHair', 'bodyBlemishes',
}

local function completeLook(look)
    if type(look) ~= 'table' then return look end
    if type(look.headOverlays) ~= 'table' then look.headOverlays = nil return look end
    for i = 1, #FACE_LAYERS do
        local name = FACE_LAYERS[i]
        local layer = look.headOverlays[name]
        if type(layer) ~= 'table' then
            look.headOverlays[name] = { style = 0, opacity = 0.0, color = 0, secondColor = 0 }
        else
            layer.style = tonumber(layer.style) or 0
            layer.opacity = tonumber(layer.opacity) or 0.0
        end
    end
    return look
end

for _, look in pairs(DEFAULT_LOOKS) do completeLook(look) end

-- ---------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------
local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function waitFor(check, timeout)
    local untilTime = GetGameTimer() + (timeout or 5000)
    while not check() do
        if GetGameTimer() > untilTime then return false end
        Wait(0)
    end
    return true
end

local function fadeOut(ms)
    if IsScreenFadedOut() then return end
    DoScreenFadeOut(ms)
    waitFor(IsScreenFadedOut, ms + 2000)
end

local function destroyCams()
    for i = 1, #oldCams do
        if DoesCamExist(oldCams[i]) then DestroyCam(oldCams[i], false) end
    end
    oldCams = {}
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
end

local function makeCam(pos, target, fov)
    local c = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov or 40.0, false, 2)
    PointCamAtCoord(c, target.x, target.y, target.z)
    return c
end

---@param newCam integer
---@param ms? integer smooth move time (0 = cut)
local function useCam(newCam, ms, ease)
    if cam and DoesCamExist(cam) and ms and ms > 0 then
        local e = ease == false and 0 or 1
        SetCamActiveWithInterp(newCam, cam, ms, e, e)
        local old = cam
        oldCams[#oldCams + 1] = old
        SetTimeout(ms + 400, function()
            for i = #oldCams, 1, -1 do
                if oldCams[i] == old then
                    table.remove(oldCams, i)
                    if DoesCamExist(old) then DestroyCam(old, false) end
                end
            end
        end)
    else
        if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
        SetCamActive(newCam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    cam = newCam
end

local function forwardRight(heading)
    local h = math.rad(heading)
    return vec3(-math.sin(h), math.cos(h), 0.0), vec3(math.cos(h), math.sin(h), 0.0)
end

-- how far you can go from `from` towards `to` before hitting a wall (nil = nothing in the way)
local function freeDistance(from, to, ignore)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, ignore or 0, 7)
    local _, hit, hitAt = GetShapeTestResult(ray)
    if (hit == true or hit == 1) and hitAt then
        return #(hitAt - from)
    end
end

-- ---------------------------------------------------------------------------
-- camera moves that never go through a building
-- ---------------------------------------------------------------------------
local UP = vec3(0.0, 0.0, 1.0)

-- is there room for the camera along the straight line from a to b? (a fat line: walls, roofs, glass)
local function wayClear(a, b)
    local handle = StartShapeTestCapsule(a.x, a.y, a.z, b.x, b.y, b.z, 1.2, 1 + 16, PlayerPedId(), 4)
    local untilTime = GetGameTimer() + 600
    local status, hit
    repeat
        status, hit = GetShapeTestResult(handle)
        if status == 1 then Wait(0) end
    until status ~= 1 or GetGameTimer() > untilTime
    return not (hit == true or hit == 1)
end

-- a camera spot out in the open (not inside a building): nothing between it and the sky above it
local function openSky(p)
    return wayClear(p + UP * 45.0, p)
end

local function loadAround(p)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    RequestAdditionalCollisionAtCoord(p.x, p.y, p.z)
end

-- the way from a to b: straight when free, otherwise up into the sky, across, and down from behind
-- (`behind` = the direction the last part comes from). Returns the list of points after a, or nil.
local function cameraWay(a, b, behind)
    if wayClear(a, b) then return { b } end
    behind = behind or vec3(0.0, 0.0, 0.0)
    for _, height in ipairs({ 20.0, 40.0, 70.0, 110.0 }) do
        for _, back in ipairs({ 18.0, 9.0, 0.0 }) do
            local drop = b - behind * back + UP * height -- where the last part starts
            if wayClear(drop, b) then
                if wayClear(a, drop) then return { drop, b } end
                local rise = vec3(a.x, a.y, drop.z) -- straight up first, then across
                if wayClear(a, rise) and wayClear(rise, drop) then return { rise, drop, b } end
            end
        end
    end
end

-- fly the camera along the way, always looking at `target`; `ms` is the whole trip
local function flyAlong(from, way, target, fov, ms, endCam)
    local total, last = 0.0, from
    for i = 1, #way do total = total + #(way[i] - last) last = way[i] end
    last = from
    for i = 1, #way do
        local part = #(way[i] - last)
        local partMs = math.max(math.floor(ms * part / math.max(total, 0.01)), 500)
        local isLast = i == #way
        local nextCam = (isLast and endCam) or makeCam(way[i], target, fov)
        useCam(nextCam, partMs, isLast) -- smooth stop only at the end, no stops on the way
        Wait(partMs)
        last = way[i]
    end
end

-- can a camera at p see q? (thin line; the player is ignored)
local function sees(p, q)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, p.z, q.x, q.y, q.z, 1 + 16, PlayerPedId(), 4)
    local _, hit = GetShapeTestResult(ray)
    return not (hit == true or hit == 1)
end

local function flat(v)
    local l = math.sqrt(v.x * v.x + v.y * v.y)
    if l < 0.001 then return vec3(0.0, 1.0, 0.0) end
    return vec3(v.x / l, v.y / l, 0.0)
end

local function turned(v, deg)
    local r = math.rad(deg)
    local c, sn = math.cos(r), math.sin(r)
    return vec3(v.x * c - v.y * sn, v.x * sn + v.y * c, 0.0)
end

-- a camera spot around `look`, out in the open, that really sees it. Tries the given direction first,
-- then turns left/right step by step. nil when there is none (for example under a roof).
local function findView(look, dir, dist, height, turns)
    turns = turns or { 0, 30, -30, 60, -60, 100, -100, 140, -140, 180 }
    local spots = {}
    for i = 1, #turns do
        spots[i] = look + turned(flat(dir), turns[i]) * dist + UP * height
        loadAround(spots[i])
    end
    Wait(400) -- let the ground/buildings there load before testing
    for i = 1, #spots do
        if openSky(spots[i]) and sees(spots[i], look) then return spots[i] end
    end
end

-- no HUD while the screens and the camera moves are on; evening light only while choosing
-- (characterScreen tells qbx_hud to keep its bars, money, car HUD and compass hidden)
local hidingHud = false
local function hideHudWhileBusy()
    if hidingHud then return end
    hidingHud = true
    LocalPlayer.state:set('characterScreen', true, false)
    CreateThread(function()
        while ui.phase or ui.cinema do
            HideHudAndRadarThisFrame()
            if ui.clock then
                NetworkOverrideClockTime(config.scene.clock.hour, config.scene.clock.minute, 0)
            end
            Wait(0)
        end
        LocalPlayer.state:set('characterScreen', false, false)
        hidingHud = false
    end)
end

local function stopEveningLight()
    if not ui.clock then return end
    ui.clock = false
    NetworkClearClockTimeOverride()
end

-- ---------------------------------------------------------------------------
-- the character in the scene
-- ---------------------------------------------------------------------------
-- the floor under the character (measured once, so the character always stands on it, never in the air)
local sceneFloor
local function sceneFloorZ(p)
    if sceneFloor then return sceneFloor end
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.6, false)
    if found and z > p.z - 4.0 and z < p.z + 0.6 then
        sceneFloor = z
        return z
    end
    return p.z
end

-- face the camera. A character standing on the floor snaps back to its old facing on the next frame
-- unless its movement state is cleared right after the turn (tested in game: this is the way that holds)
local function faceScene(ped, heading)
    local frozen = IsEntityPositionFrozen(ped)
    if frozen then FreezeEntityPosition(ped, false) end
    SetEntityHeading(ped, heading)
    ClearPedTasksImmediately(ped)
    SetPedDesiredHeading(ped, heading)
    if frozen then FreezeEntityPosition(ped, true) end
end

local function placeAtScene()
    local ped = PlayerPedId()
    local p = config.scene.ped
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    if not sceneFloor then
        waitFor(function() return HasCollisionLoadedAroundEntity(ped) end, 3000)
    end
    SetEntityCoords(ped, p.x, p.y, sceneFloorZ(p), false, false, false, false)
    faceScene(ped, p.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
end

local previewToken = 0 -- EX_Tii: a slow preview that finishes after "Play" must not change anything

---@param token integer? a preview's number: stop when a newer preview or "Play" came meanwhile
local function applyLook(model, look, token)
    if not IsModelInCdimage(model) then model = DEFAULT_MODELS[0] end
    pcall(lib.requestModel, model, 20000)
    if token and token ~= previewToken then return end
    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    if look then
        completeLook(look)
        pcall(function() exports['illenium-appearance']:setPedAppearance(ped, look) end)
    end
    if token and token ~= previewToken then return end
    placeAtScene()
end

local function findCharacter(citizenid)
    for i = 1, #characters do
        if characters[i].citizenid == citizenid then return characters[i] end
    end
end

local function genderOf(c)
    return c and c.charinfo and tonumber(c.charinfo.gender) == 1 and 1 or 0
end

local function previewCharacter(citizenid)
    previewToken = previewToken + 1
    local token = previewToken
    if citizenid then
        local clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenid)
        if token ~= previewToken then return end
        if model and clothing then
            hasLook[citizenid] = true
            local ok, look = pcall(json.decode, clothing)
            return applyLook(model, ok and look or nil, token)
        end
        hasLook[citizenid] = false
    end
    local g = genderOf(citizenid and findCharacter(citizenid))
    applyLook(DEFAULT_MODELS[g], DEFAULT_LOOKS[g], token)
end

-- camera in front of the character: measures the body (head and feet) so the whole
-- character always fits, sits in the free space left of the panel, and never goes through a wall
local BONE_HEAD, BONE_LFOOT, BONE_RFOOT = 31086, 14201, 52301

local function sceneCam()
    local ped = PlayerPedId()
    local root = GetEntityCoords(ped)
    local head = GetPedBoneCoords(ped, BONE_HEAD, 0.0, 0.0, 0.0)
    local lf = GetPedBoneCoords(ped, BONE_LFOOT, 0.0, 0.0, 0.0)
    local rf = GetPedBoneCoords(ped, BONE_RFOOT, 0.0, 0.0, 0.0)
    local top, bottom = head.z + 0.2, math.min(lf.z, rf.z) - 0.08
    if top - bottom < 1.2 or top - bottom > 2.6 or #(vec2(head.x, head.y) - vec2(root.x, root.y)) > 1.0 then
        top, bottom = root.z + 0.82, root.z - 1.0 -- body not ready yet: a normal standing person
    end
    local height = top - bottom

    local fwd = forwardRight(config.scene.ped.w) -- always in front of the character, whatever the game did to it
    local fill = 0.76 -- the body takes this much of the screen height
    local fov = config.scene.fov or 40.0
    local tanHalf = math.tan(math.rad(fov / 2))
    local dist = (height / fill) / 2 / tanHalf

    -- a wall or furniture in front: come closer and widen the lens instead
    local chest = vec3(root.x, root.y, bottom + height * 0.62)
    local free = freeDistance(chest, chest + fwd * (dist + 0.4), ped)
    if free and free - 0.4 < dist then
        dist = math.max(free - 0.4, 1.4)
        tanHalf = (height / fill) / 2 / dist
        fov = math.min(math.deg(math.atan(tanHalf)) * 2, 75.0)
        tanHalf = math.tan(math.rad(fov / 2))
    end

    local aspect = math.min(math.max(GetAspectRatio(false), 1.25), 3.6)
    local camRight = vec3(-fwd.y, fwd.x, 0.0)            -- the camera looks back at the character
    local side = dist * tanHalf * aspect * 0.22          -- character at ~40% of the screen width
    local pos = vec3(root.x, root.y, bottom + height * 0.58) + fwd * dist
    local target = vec3(root.x, root.y, bottom + height * 0.55) + camRight * side
    return makeCam(pos, target, fov)
end

local function frameCharacter(ms)
    Wait(120) -- let the body settle so the measuring is right
    useCam(sceneCam(), ms)
end

-- ---------------------------------------------------------------------------
-- data for the panels
-- ---------------------------------------------------------------------------
local function charView(c)
    local info = c.charinfo or {}
    local money = c.money or {}
    local job = c.job or {}
    return {
        citizenid = c.citizenid,
        firstname = info.firstname or '',
        lastname = info.lastname or '',
        gender = info.gender,
        birthdate = info.birthdate or '',
        nationality = info.nationality or '',
        phone = info.phone or '',
        cash = money.cash or 0,
        bank = money.bank or 0,
        job = job.label or '',
        grade = job.grade and job.grade.name or '',
    }
end

local function selectViews()
    local views = {}
    for i = 1, #characters do views[i] = charView(characters[i]) end
    return views
end

-- ---------------------------------------------------------------------------
-- 1) choose your character
-- ---------------------------------------------------------------------------
local protecting = false
-- people can die while choosing; keep them safe until they are in the city
local function protectWhileChoosing()
    if protecting then return end
    protecting = true
    CreateThread(function()
        while ui.phase or NetworkIsInTutorialSession() do
            local ped = PlayerPedId()
            SetEntityInvincible(ped, true)
            -- while choosing or creating: the screen is never left black (another script may have faded it)
            -- and the character keeps looking at the camera
            if ui.phase == 'select' or ui.phase == 'create' then
                if IsScreenFadedOut() and not IsScreenFadingIn() then DoScreenFadeIn(600) end
                local want = config.scene.ped.w
                local off = math.abs(((GetEntityHeading(ped) - want) + 180.0) % 360.0 - 180.0)
                if off > 2.0 then faceScene(ped, want) end
            end
            Wait(250)
        end
        SetEntityInvincible(PlayerPedId(), false)
        protecting = false
    end)
end

local function startSelect()
    ui.phase = 'busy'
    ui.clock = true
    hideHudWhileBusy()
    protectWhileChoosing()
    fadeOut(400)
    SetNuiFocus(false, false)
    nui('hide')
    pcall(lib.hideTextUI) -- no "[E] ..." prompt left over from the city
    pcall(lib.closeAlertDialog) -- and no question box left open (like the new-player welcome)
    pcall(lib.closeInputDialog)

    local list, amount = lib.callback.await('qbx_core:server:getCharacters')
    characters = type(list) == 'table' and list or {}
    allowed = tonumber(amount) or 1

    DisplayRadar(false)
    NetworkStartSoloTutorialSession()
    waitFor(NetworkIsInTutorialSession, 5000)

    previewCharacter(characters[1] and characters[1].citizenid)
    Wait(400)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    destroyCams()
    frameCharacter(0)

    ui.phase = 'select'
    nui('select', { characters = selectViews(), allowed = allowed })
    SetNuiFocus(true, true)
    DoScreenFadeIn(900)
end

-- ---------------------------------------------------------------------------
-- into the city
-- ---------------------------------------------------------------------------
local preview = false -- admins replaying the camera moves (/arrivaltest): already in the city, load nothing again

local function finishLoad()
    if preview then
        stopEveningLight()
        ui.phase = nil
        DisplayRadar(true)
        return
    end
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    TriggerEvent('qb-weathersync:client:EnableSync')
    stopEveningLight()
    ui.phase = nil
    DisplayRadar(true)
end

local function placeOnGround(coords)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    waitFor(function() return HasCollisionLoadedAroundEntity(ped) end, 5000)
    -- stand exactly on the ground (saved spots are at body height, so they would float a little)
    local found, gz = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    if found and math.abs(gz - coords.z) < 3.0 then
        SetEntityCoords(ped, coords.x, coords.y, gz, false, false, false, false)
    end
    faceScene(ped, coords.w or 0.0) -- a frozen character only keeps a new facing this way
    SetEntityVisible(ped, true, false)
end

-- the last camera: just behind the character, looking where they look (never inside a wall)
local function behindCam(c)
    local fwd = forwardRight(c.w or 0.0)
    local base = vec3(c.x, c.y, c.z)
    local eye = base + vec3(0.0, 0.0, 0.7)
    local back = 4.4
    local free = freeDistance(eye, eye - fwd * (back + 0.3), PlayerPedId())
    if free and free - 0.3 < back then back = math.max(free - 0.3, 1.2) end
    return makeCam(base - fwd * back + vec3(0.0, 0.0, 1.3), base + fwd * 2.0 + vec3(0.0, 0.0, 0.6), 50.0)
end

-- hand the camera back to the player smoothly
local function giveControl()
    FreezeEntityPosition(PlayerPedId(), false)
    finishLoad()
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(-6.0, 1.0)
    RenderScriptCams(false, true, 1100, true, true)
    Wait(1200)
    destroyCams()
    ClearFocus()
end

local function goDark()
    ui.phase = 'busy'
    SetNuiFocus(false, false)
    nui('hide')
    fadeOut(600)
    RenderScriptCams(false, false, 0, true, true)
    destroyCams()
    stopEveningLight()
end

-- returning player: from high above, down to where they left
local function swoopDown(c, text)
    goDark()
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
    placeOnGround(c)

    local fwd, right = forwardRight(c.w or 0.0)
    local base = vec3(c.x, c.y, c.z)
    local head = base + UP * 0.9
    local endCam = behindCam(c)
    local endPos = GetCamCoord(endCam)

    -- from high above (out in the open, seeing you) down to just behind you, never through a building
    local start = findView(head, -fwd * 40.0 + right * 24.0, 46.0, 95.0)
    local way = start and cameraWay(start, endPos, fwd)
    if not way then start = nil end -- under a roof or between tall walls: no flight, just show you

    useCam(start and makeCam(start, head, 50.0) or endCam, 0)
    Wait(300)
    nui('cinema', text)
    DoScreenFadeIn(900)
    Wait(700)

    if start then
        flyAlong(start, way, head, 50.0, 3400, endCam)
    else
        Wait(2600)
    end
    Wait(100)
    nui('cinemaEnd')
    giveControl()
end

-- returning player who left inside their home
local function enterHome(propertyId, text)
    goDark()
    ui.cinema = true
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
    finishLoad()
    TriggerServerEvent('qbx_properties:server:enterProperty', { id = propertyId, isSpawn = true })
    Wait(1200)
    nui('cinema', text)
    DoScreenFadeIn(900)
    Wait(3400)
    nui('cinemaEnd')
    ui.cinema = false
    -- EX_Tii: the home did not let us in (no keys any more...): never stay in the character room
    local scene = config.scene.ped
    if #(GetEntityCoords(PlayerPedId()) - vec3(scene.x, scene.y, scene.z)) < 40.0 then
        DoScreenFadeOut(300)
        Wait(300)
        placeOnGround(config.newPlayer.spawn) -- waits for the ground before standing on it
        FreezeEntityPosition(PlayerPedId(), false)
        DoScreenFadeIn(600)
    end
end

-- where this character left the city last time (nil when there is nowhere sensible to go back to)
local function lastPlace()
    local coords, propertyId
    if GetResourceState('qbx_spawn'):find('start') then
        coords, propertyId = lib.callback.await('qbx_spawn:server:getLastLocation', false)
    end
    if not (coords and coords.x) then
        local pos = QBX.PlayerData and QBX.PlayerData.position
        if pos and pos.x then coords = pos end
    end
    if propertyId then return nil, propertyId end
    if not (coords and coords.x) then return end

    local spot = vec4(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, (coords.w or 0.0) + 0.0)
    local scene = config.scene.ped
    -- never back into the character room (left while still choosing) or to the middle of nowhere
    if #(vec3(spot.x, spot.y, spot.z) - vec3(scene.x, scene.y, scene.z)) < 40.0 then return end
    if math.abs(spot.x) < 5.0 and math.abs(spot.y) < 5.0 then return end
    return spot
end

-- ---------------------------------------------------------------------------
-- 2) new players: design the look, then arrive next to the job center
-- ---------------------------------------------------------------------------
-- keep exactly what is on screen right now (used when the look editor closes: without it the game
-- shows the back of the character for a moment before the next camera move)
local function holdView()
    local pos, rot, fov = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2), GetFinalRenderedCamFov()
    useCam(CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, fov, false, 2), 0)
end

local function designLook()
    ui.phase = 'design'
    SetNuiFocus(false, false)
    nui('hide')
    local ped = PlayerPedId()
    local p = config.scene.ped
    local here = GetEntityCoords(ped)
    -- coming from the create form or the list the character is already standing there with our camera
    -- on it: no fade, no jump. Only when something moved it (rare) put it back behind a quick fade.
    local inPlace = cam and DoesCamExist(cam) and #(vec2(here.x, here.y) - vec2(p.x, p.y)) < 0.6
    if not inPlace then
        fadeOut(400)
        placeAtScene()
        ped = PlayerPedId()
    end
    -- the look editor turns the character around and lets it take a step: it must not be frozen
    -- (it stands on the floor, so it stays where it is)
    FreezeEntityPosition(ped, false)
    faceScene(ped, p.w)

    -- the editor puts its camera in front of the character: for the first moments keep the character
    -- facing that camera (the game sometimes turns a new character back to an old direction)
    CreateThread(function()
        local untilTime = GetGameTimer() + 3500
        while ui.phase == 'design' and GetGameTimer() < untilTime do
            local me = PlayerPedId()
            local off = math.abs(((GetEntityHeading(me) - p.w) + 180.0) % 360.0 - 180.0)
            if off > 2.0 then faceScene(me, p.w) end
            Wait(100)
        end
    end)

    -- glide our camera to exactly where the look editor puts its own (illenium-appearance "default"
    -- camera: 2.2 m in front, 0.2 m up, looking at the body, lens 49), so the switch to it can't be seen
    local editorPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.2, 0.2)
    local editorLook = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, -0.05)
    useCam(makeCam(editorPos, editorLook, 49.0), inPlace and 900 or 0)
    if inPlace then
        Wait(950)
    else
        Wait(250)
        DoScreenFadeIn(500)
        waitFor(IsScreenFadedIn, 2500)
    end

    local finished = false
    local opened = pcall(function()
        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
            -- the editor has just switched its camera off: keep its last picture on screen
            pcall(holdView)
            if appearance then
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            end
            finished = true
        end, config.editor)
    end)
    if not opened then return end -- no look editor: they can change clothes in any shop later
    while not finished and GetResourceState('illenium-appearance') == 'started' do Wait(100) end
end

-- new player: from high over the city straight down to where they spawned.
-- The camera looks at the player the whole time (not at the job center).
local function arriveAtJobCenter(firstname)
    goDark()
    local s = config.newPlayer.spawn
    SetFocusPosAndVel(s.x, s.y, s.z, 0.0, 0.0, 0.0)
    placeOnGround(s)

    local fwd, right = forwardRight(s.w or 0.0)
    local head = vec3(s.x, s.y, s.z) + UP * 0.9
    loadAround(head)
    local endCam = behindCam(s)
    local endPos = GetCamCoord(endCam)

    -- the start spot is checked first: out in the open and seeing you, and the way down to you never
    -- goes through a building (up over the roofs instead). Very high first, then a bit lower.
    local high = findView(head, -fwd * 80.0 + right * 45.0, 90.0, 110.0)
    local way = high and cameraWay(high, endPos, fwd)
    if not way then
        high = findView(head, -fwd * 40.0 + right * 24.0, 46.0, 95.0)
        way = high and cameraWay(high, endPos, fwd)
    end
    if not way then high = nil end -- no free way: no flight, just show you

    -- 1) high over the city, looking at you
    useCam(high and makeCam(high, head, 50.0) or endCam, 0)
    Wait(300)
    nui('cinema', {
        title = 'أهلًا بك في لوس سانتوس',
        sub = (firstname and firstname ~= '') and (firstname .. '، قصتك تبدأ الآن') or 'قصتك تبدأ الآن',
    })
    DoScreenFadeIn(1200)
    Wait(1800)

    -- 2) down to just behind you
    if high then
        flyAlong(high, way, head, 50.0, 5200, endCam)
    else
        Wait(2600)
    end
    Wait(100)
    nui('cinemaEnd')
    giveControl()
    TriggerEvent('qbx_cityhall:client:highlight')
end

-- ---------------------------------------------------------------------------
-- buttons in the panels
-- ---------------------------------------------------------------------------
RegisterNUICallback('preview', function(data, cb)
    cb(true)
    if ui.phase ~= 'select' or type(data) ~= 'table' then return end
    local c = findCharacter(data.citizenid)
    if not c then return end
    previewCharacter(c.citizenid)
    if ui.phase == 'select' then frameCharacter(700) end
end)

RegisterNUICallback('play', function(data, cb)
    if ui.phase ~= 'select' or type(data) ~= 'table' then return cb({ ok = false }) end
    local c = findCharacter(data.citizenid)
    if not c then return cb({ ok = false }) end
    ui.phase = 'busy'
    previewToken = previewToken + 1 -- (stops a preview that is still loading)
    cb({ ok = true })

    CreateThread(function()
        lib.callback.await('qbx_core:server:loadCharacter', false, c.citizenid)
        local loaded = waitFor(function()
            return QBX.PlayerData and QBX.PlayerData.citizenid == c.citizenid
        end, 8000)
        if not loaded then return startSelect() end

        local info = c.charinfo or {}
        local text = { title = 'مرحبًا بعودتك', sub = ('%s %s'):format(info.firstname or '', info.lastname or '') }
        local spot, propertyId = lastPlace()

        -- the look was never saved (they left during the look editor): design it first, whatever happens next
        if hasLook[c.citizenid] == false then designLook() end

        if propertyId then return enterHome(propertyId, text) end
        if spot then return swoopDown(spot, text) end
        -- nowhere to go back to: they left before arriving in the city
        arriveAtJobCenter(info.firstname)
    end)
end)

RegisterNUICallback('newCharacter', function(_, cb)
    if ui.phase ~= 'select' or #characters >= allowed then return cb({ ok = false }) end
    ui.phase = 'create'
    applyLook(DEFAULT_MODELS[0], DEFAULT_LOOKS[0])
    cb({ ok = true })
    nui('create', {
        nationalities = config.nationalities,
        nameMin = config.nameMin,
        nameMax = config.nameMax,
        yearMin = config.birthYearMin,
        yearMax = config.birthYearMax,
        canGoBack = #characters > 0,
    })
    frameCharacter(700)
end)

RegisterNUICallback('gender', function(data, cb)
    cb(true)
    if ui.phase ~= 'create' or type(data) ~= 'table' then return end
    local g = data.gender == 1 and 1 or 0
    applyLook(DEFAULT_MODELS[g], DEFAULT_LOOKS[g])
    if ui.phase == 'create' then frameCharacter(500) end
end)

RegisterNUICallback('back', function(_, cb)
    cb(true)
    if ui.phase ~= 'create' then return end
    ui.phase = 'select'
    previewCharacter(characters[1] and characters[1].citizenid)
    nui('select', { characters = selectViews(), allowed = allowed })
    if ui.phase == 'select' then frameCharacter(700) end
end)

local function cleanName(value, min, max)
    if type(value) ~= 'string' then return end
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8.len(value)
    if not len or len < min or len > max then return end
    -- letters (Arabic or English), spaces, - and '
    for _, code in utf8.codes(value) do
        local ok = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 32 or code == 45 or code == 39
            or (code >= 0x0621 and code <= 0x064A) or (code >= 0x0671 and code <= 0x06D3) or code == 0x0640
        if not ok then return end
    end
    -- English names start with a capital letter
    return (value:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest:lower() end))
end

RegisterNUICallback('create', function(data, cb)
    if ui.phase ~= 'create' or type(data) ~= 'table' then return cb({ ok = false, error = 'failed' }) end

    local first = cleanName(data.firstname, config.nameMin, config.nameMax)
    local last = cleanName(data.lastname, config.nameMin, config.nameMax)
    if not first or not last then return cb({ ok = false, error = 'name' }) end

    local gender = data.gender == 1 and 1 or 0
    local nationality
    for i = 1, #config.nationalities do
        if config.nationalities[i] == data.nationality then nationality = config.nationalities[i] break end
    end
    if not nationality then return cb({ ok = false, error = 'nationality' }) end
    if gender == 1 then nationality = nationality .. 'ة' end

    local y, m, d = tostring(data.birthdate or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or y < config.birthYearMin or y > config.birthYearMax or m < 1 or m > 12 or d < 1 or d > 31 then
        return cb({ ok = false, error = 'birthdate' })
    end

    ui.phase = 'busy'
    local newData = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = first,
        lastname = last,
        nationality = nationality,
        gender = gender,
        birthdate = ('%04d-%02d-%02d'):format(y, m, d),
        cid = 1,
    })

    if not newData then
        -- EX_Tii: the character can already be made and loaded even when a later step failed
        -- (starting items...); then carry on instead of leaving the player on this screen
        local made = waitFor(function()
            return LocalPlayer.state.isLoggedIn and QBX.PlayerData and QBX.PlayerData.citizenid ~= nil
        end, 3000)
        if made then
            cb({ ok = true })
            CreateThread(function()
                designLook()
                arriveAtJobCenter(first)
            end)
            return
        end
        ui.phase = 'create'
        return cb({ ok = false, error = 'failed' })
    end

    cb({ ok = true })
    CreateThread(function()
        designLook()
        arriveAtJobCenter(first)
    end)
end)

RegisterNUICallback('delete', function(_, cb)
    -- EX_Tii: players can't delete their character (one per player); admins use /delcharacter
    cb({ ok = false })
end)

-- ---------------------------------------------------------------------------
-- admins: replay the camera moves to check them (/arrivaltest, /arrivaltest back)
-- ---------------------------------------------------------------------------
RegisterNetEvent('exti_characters:client:preview', function(kind)
    if GetInvokingResource() then return end -- only from the server (admin command)
    if ui.phase or preview or not LocalPlayer.state.isLoggedIn then return end
    preview = true
    CreateThread(function()
        local ped = PlayerPedId()
        local here = GetEntityCoords(ped)
        local spot = vec4(here.x, here.y, here.z, GetEntityHeading(ped))
        ui.phase = 'busy'
        hideHudWhileBusy()
        local ok, err = pcall(function()
            if kind == 'back' then
                swoopDown(spot, { title = 'مرحبًا بعودتك', sub = 'معاينة' })
            else
                arriveAtJobCenter('معاينة')
            end
        end)
        if not ok then
            print('[exti_characters] preview failed: ' .. tostring(err))
            nui('cinemaEnd')
            DoScreenFadeIn(300)
            RenderScriptCams(false, false, 0, true, true)
            destroyCams()
            ClearFocus()
            FreezeEntityPosition(PlayerPedId(), false)
            ui.phase = nil
        end
        preview = false
    end)
end)

-- admins: /delcharacter asks first, with the character's name
RegisterNetEvent('exti_characters:client:confirmDelete', function(citizenid, name)
    if GetInvokingResource() then return end
    local choice = lib.alertDialog({
        header = 'حذف شخصية نهائيًا',
        content = ('ستُحذف شخصية **%s** (%s) وكل ما تملكه: المال، السيارات، الأغراض، العصابة.  \nلا يمكن التراجع.'):format(name, citizenid),
        centered = true,
        cancel = true,
        labels = { confirm = 'احذف نهائيًا', cancel = 'إلغاء' },
    })
    if choice == 'confirm' then TriggerServerEvent('exti_characters:server:confirmDelete', citizenid) end
end)

-- ---------------------------------------------------------------------------
-- start / logout
-- ---------------------------------------------------------------------------
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end -- only from the server
    CreateThread(startSelect)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(0) end
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    Wait(250)
    -- this script was restarted while you are already in the city: leave you there
    if LocalPlayer.state.isLoggedIn then return end
    startSelect()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LocalPlayer.state:set('characterScreen', false, false)
    if ui.phase then
        SetNuiFocus(false, false)
        RenderScriptCams(false, false, 0, true, true)
        destroyCams()
        ClearFocus()
        if ui.clock then NetworkClearClockTimeOverride() end
    end
end)
