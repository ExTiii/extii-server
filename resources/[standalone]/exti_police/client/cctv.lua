-- =====================================================================
-- EX_Tii Police (client): looking through a CCTV camera from the tablet. The tablet goes away,
-- the view jumps to the camera: mouse = turn (within limits), wheel = zoom, ← → = the next /
-- previous camera, Esc / Backspace = back to the tablet.
-- =====================================================================

local C = Config.cctv

local cameras = GlobalState.exti_police_cctv
AddStateBagChangeHandler('exti_police_cctv', 'global', function(_, _, value) if type(value) == 'table' then cameras = value end end)
CreateThread(function()
    while type(cameras) ~= 'table' do Wait(1000) cameras = GlobalState.exti_police_cctv end
end)

local viewing = false

local function overlay(show, cam, index)
    SendNUIMessage({ action = 'cctv', open = show, data = show and { label = cam.label, area = cam.area, index = index, count = #cameras } or nil })
end

-- blocks until the officer leaves the camera; returns nothing
function POL.cctvView(index)
    if viewing or type(cameras) ~= 'table' or not cameras[index] then return end
    viewing = true
    local ped = cache.ped
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local current = index
    local yaw, pitch, fov
    local baseYaw, basePitch

    local function aim(i)
        local c = cameras[i]
        baseYaw, basePitch = c.rot.z + 0.0, c.rot.x + 0.0
        yaw, pitch, fov = baseYaw, basePitch, 50.0
        SetCamCoord(cam, c.coords.x, c.coords.y, c.coords.z)
        SetCamRot(cam, pitch, 0.0, yaw, 2)
        SetCamFov(cam, fov)
        SetFocusPosAndVel(c.coords.x, c.coords.y, c.coords.z, 0.0, 0.0, 0.0)
        overlay(true, c, i)
    end

    aim(current)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, true)
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(0.6)

    local function wrap(a) return (a + 180.0) % 360.0 - 180.0 end

    while viewing do
        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)
        EnableControlAction(0, 249, true) -- push to talk
        -- turn with the mouse
        local dx = GetDisabledControlNormal(0, 1)
        local dy = GetDisabledControlNormal(0, 2)
        if dx ~= 0.0 or dy ~= 0.0 then
            yaw = yaw - dx * 6.0 * (fov / 50.0)
            pitch = pitch - dy * 5.0 * (fov / 50.0)
            local turn = wrap(yaw - baseYaw)
            if turn > C.maxTurn then yaw = baseYaw + C.maxTurn elseif turn < -C.maxTurn then yaw = baseYaw - C.maxTurn end
            pitch = math.max(basePitch - C.maxTilt, math.min(basePitch + C.maxTilt, pitch))
            SetCamRot(cam, pitch, 0.0, yaw, 2)
        end
        -- zoom with the wheel
        if IsDisabledControlJustPressed(0, 241) then fov = math.max(C.fov[1], fov - 5.0) SetCamFov(cam, fov) end
        if IsDisabledControlJustPressed(0, 242) then fov = math.min(C.fov[2], fov + 5.0) SetCamFov(cam, fov) end
        -- the next / previous camera
        if IsDisabledControlJustPressed(0, 175) or IsDisabledControlJustPressed(0, 174) then
            local dir = IsDisabledControlJustPressed(0, 175) and 1 or -1
            current = ((current - 1 + dir) % #cameras) + 1
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            aim(current)
        end
        -- out
        if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 322)
            or POL.isDown() or not POL.onDuty() then
            viewing = false
        end
        Wait(0)
    end

    overlay(false)
    ClearTimecycleModifier()
    RenderScriptCams(false, true, 600, true, true)
    DestroyCam(cam, false)
    ClearFocus()
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
end

POL.cctvViewing = function() return viewing end

-- /cctvspot n (admins): the server asks for your camera's place and angle
RegisterNetEvent('exti_police:client:cctvAsk', function(n)
    local pos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    TriggerServerEvent('exti_police:server:cctvPlace', n, { x = pos.x, y = pos.y, z = pos.z }, { x = rot.x, y = rot.y, z = rot.z })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if viewing then
        viewing = false
        ClearTimecycleModifier()
        RenderScriptCams(false, false, 0, true, true)
        DestroyAllCams(true)
        ClearFocus()
    end
end)
