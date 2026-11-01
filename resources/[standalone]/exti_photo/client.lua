-- EX_Tii photo camera (see server.lua for the commands)
local cam = nil
local hiding = false

local function num(v) return tonumber(v) end

local function stop()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    local ped = cache.ped
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
end

RegisterNetEvent('exti_photo:cam', function(a, b, c, d, e, f, g)
    local ped = cache.ped
    if a == nil or a == 'off' then return stop() end

    if a == 'ped' then
        local x, y, z, h = num(b), num(c), num(d), num(e)
        if not (x and y and z) then return end
        stop()
        SetEntityCoords(ped, x, y, z - 1.0, false, false, false, false)
        SetEntityHeading(ped, h or 0.0)
        SetGameplayCamRelativeHeading(0.0)
        SetGameplayCamRelativePitch(-8.0, 1.0)
        return
    end

    local x, y, z, lx, ly, lz = num(a), num(b), num(c), num(d), num(e), num(f)
    if not (x and y and z and lx and ly and lz) then
        lib.notify({ title = 'Camera', description = '/cam x y z lookX lookY lookZ [fov]', type = 'error' })
        return
    end
    local fov = num(g) or 55.0
    -- you stand (hidden) where the camera is, so the place and its inside are loaded
    SetEntityCoords(ped, x, y, z - 1.0, false, false, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    if not cam then cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetCamCoord(cam, x, y, z)
    PointCamAtCoord(cam, lx, ly, lz)
    SetCamFov(cam, fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    DisplayRadar(false)
    if not hiding then
        hiding = true
        CreateThread(function()
            while cam do
                HideHudAndRadarThisFrame()
                Wait(0)
            end
            hiding = false
        end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == cache.resource then stop() end
end)
