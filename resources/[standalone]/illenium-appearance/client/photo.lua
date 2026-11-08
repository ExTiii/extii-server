-- EX_Tii photo tool: takes the pictures for the picture cards in the appearance screen.
-- An admin types /extiphotos (or /extiphotos m c11 to do only one part). The character is put in a
-- private world in front of a green screen, every piece is put on one by one, photographed
-- (screencapture), cut out in the screen page (web/ex/ex-photo.js) and saved on the server as
-- web/ex/img/<m|f>-<part>-<number>.webp. Pictures that already exist are skipped, so it can be stopped
-- (/extiphotos stop) and started again. When it is done: refresh, then restart illenium-appearance.

local client = client
local running, stopAsked = false, false
local pending, nextId = {}, 0

local GENDERS = { m = "mp_m_freemode_01", f = "mp_f_freemode_01" }

-- the plain outfit everything is photographed on (no top, no shoes)
local BASE = {
    m = { [1] = 0, [3] = 15, [4] = 21, [5] = 0, [6] = 34, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 },
    f = { [1] = 0, [3] = 15, [4] = 15, [5] = 0, [6] = 35, [7] = 0, [8] = 14, [9] = 0, [10] = 0, [11] = 15 },
}

-- what to photograph and where the camera looks
-- view: head / ear / chest / back / legs / feet / lwrist / rwrist
local PARTS = {
    { key = "c11", comp = 11, view = "chest" },
    { key = "c8", comp = 8, view = "chest" },
    { key = "c3", comp = 3, view = "chest" },
    { key = "c7", comp = 7, view = "chest" },
    { key = "c5", comp = 5, view = "back" },
    { key = "c10", comp = 10, view = "chest" },
    { key = "c9", comp = 9, view = "chest" },
    { key = "c4", comp = 4, view = "legs" },
    { key = "c6", comp = 6, view = "feet" },
    { key = "c1", comp = 1, view = "head" },
    { key = "c2", comp = 2, view = "head" },
    { key = "p0", prop = 0, view = "hat" },
    { key = "p1", prop = 1, view = "head" },
    { key = "p2", prop = 2, view = "ear" },
    { key = "p6", prop = 6, view = "lwrist" },
    { key = "p7", prop = 7, view = "rwrist" },
}

-- barber pictures: overlay index in the game, the key the screen uses, the view
local OVERLAYS = {
    { key = "blemishes", i = 0 }, { key = "beard", i = 1, ctype = 1 }, { key = "eyebrows", i = 2, ctype = 1 },
    { key = "ageing", i = 3 }, { key = "makeUp", i = 4, ctype = 2 }, { key = "blush", i = 5, ctype = 2 },
    { key = "complexion", i = 6 }, { key = "sunDamage", i = 7 }, { key = "lipstick", i = 8, ctype = 2 },
    { key = "moleAndFreckles", i = 9 }, { key = "chestHair", i = 10, ctype = 1, view = "chest" },
    { key = "bodyBlemishes", i = 11, view = "chest" },
}

-- (chest = SKEL_Spine3, the breastbone: the old mid-spine bone put the camera on the hips and the jacket
-- pictures came out as legs and underwear)
local BONE = { head = 31086, chest = 24818, pelvis = 11816, lfoot = 14201, rfoot = 52301, lhand = 18905, rhand = 57005 }

RegisterNUICallback("exti_photo_done", function(data, cb)
    cb(1)
    local p = data and pending[data.id]
    if p then
        pending[data.id] = nil
        p:resolve(data.data)
    end
end)

local function note(text)
    lib.notify({ title = "أداة الصور", description = text, type = "inform", position = "top" })
end

-- green screen: a wall behind the character (seen from the camera) and a floor under the feet
local screen = nil
local function quad(a, b, c, d)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 0, 255, 0, 255)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, 0, 255, 0, 255)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, 0, 255, 0, 255)
    DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, 0, 255, 0, 255)
end
CreateThread(function()
    while true do
        if screen then
            HideHudAndRadarThisFrame()
            local w, f = screen.wall, screen.floor
            quad(w[1], w[2], w[3], w[4])
            quad(f[1], f[2], f[3], f[4])
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local cam, P
local function aim(view)
    local ped = P or cache.ped
    local fwd = GetEntityForwardVector(ped)
    local right = vec3(fwd.y, -fwd.x, 0.0)
    local up = vec3(0.0, 0.0, 1.0)
    local function bone(b) return GetPedBoneCoords(ped, BONE[b], 0.0, 0.0, 0.0) end
    local target, pos, fov
    if view == "head" then
        target = bone("head") + vec3(0.0, 0.0, 0.03); pos = target + fwd * 0.85; fov = 30.0
    elseif view == "hat" then
        target = bone("head") + vec3(0.0, 0.0, 0.1); pos = target + fwd * 1.0 + up * 0.08; fov = 32.0
    elseif view == "ear" then
        target = bone("head"); pos = target + fwd * 0.3 - right * 0.62; fov = 28.0
    elseif view == "chest" then
        -- shoulders to the waist: halfway between the head and the hips (the spine bones sit too low)
        target = (bone("head") + bone("pelvis")) / 2 - up * 0.02; pos = target + fwd * 1.05; fov = 34.0
    elseif view == "back" then
        target = (bone("head") + bone("pelvis")) / 2 - up * 0.02; pos = target - fwd * 1.1; fov = 34.0
    elseif view == "legs" then
        -- hips to the ankles
        target = bone("pelvis") - up * 0.48; pos = target + fwd * 1.6; fov = 36.0
    elseif view == "feet" then
        target = (bone("lfoot") + bone("rfoot")) / 2 + up * 0.06; pos = target + fwd * 0.95 + up * 0.35; fov = 34.0
    elseif view == "lwrist" then
        target = bone("lhand") + up * 0.05; pos = target + fwd * 0.32 - right * 0.32; fov = 28.0
    else -- rwrist
        target = bone("rhand") + up * 0.05; pos = target + fwd * 0.32 + right * 0.32; fov = 28.0
    end

    -- the wall stands 2.2 m behind what the camera looks at, square to the camera
    local dir = target - pos
    local flat = vec3(dir.x, dir.y, 0.0)
    flat = flat / math.max(math.sqrt(flat.x * flat.x + flat.y * flat.y), 0.001)
    local side = vec3(flat.y, -flat.x, 0.0)
    local wc = target + flat * 2.2
    local coords = GetEntityCoords(ped)
    local fz = coords.z - 0.98
    screen = {
        wall = {
            wc + side * 6.0 + up * 6.0, wc - side * 6.0 + up * 6.0,
            wc - side * 6.0 - vec3(0, 0, wc.z - fz + 0.2), wc + side * 6.0 - vec3(0, 0, wc.z - fz + 0.2),
        },
        floor = {
            vec3(coords.x - 6.0, coords.y - 6.0, fz), vec3(coords.x + 6.0, coords.y - 6.0, fz),
            vec3(coords.x + 6.0, coords.y + 6.0, fz), vec3(coords.x - 6.0, coords.y + 6.0, fz),
        },
    }

    if not cam then cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true) end
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, true)
end

local function shoot()
    nextId = nextId + 1
    local id = nextId
    local p = promise.new()
    pending[id] = p
    SetTimeout(15000, function()
        if pending[id] then pending[id] = nil; p:resolve(nil) end
    end)
    exports.screencapture:requestScreenshot({ encoding = "png" }, function(uri)
        SendNUIMessage({ type = "exti_photo", id = id, src = uri, size = 192 })
    end)
    return Citizen.Await(p)
end

local function save(name, data)
    if not data then return false end
    TriggerLatentServerEvent("illenium-appearance:server:photoSave", 200000, name, data)
    return true
end

local function loadModel(model)
    local hash = joaat(model)
    lib.requestModel(hash, 20000)
    SetPlayerModel(cache.playerId, hash)
    SetModelAsNoLongerNeeded(hash)
    Wait(300)
    local ped = PlayerPedId()
    P = ped
    SetPedDefaultComponentVariation(ped)
    ClearAllPedProps(ped)
    return ped
end

local function dress(ped, g)
    for comp, d in pairs(BASE[g]) do SetPedComponentVariation(ped, comp, d, 0, 0) end
    ClearAllPedProps(ped)
    for i = 0, 12 do SetPedHeadOverlay(ped, i, 255, 0.0) end
    if g == "m" then
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
    else
        SetPedHeadBlendData(ped, 21, 21, 0, 21, 21, 0, 0.0, 0.0, 0.0, false)
    end
    SetPedHeadOverlay(ped, 2, 0, 1.0) -- eyebrows, so the face does not look strange
    SetPedHeadOverlayColor(ped, 2, 1, 0, 0)
    SetPedHairColor(ped, 3, 3)
end

local function stand(ped, at)
    SetEntityCoordsNoOffset(ped, at.x, at.y, at.z, false, false, false)
    SetEntityHeading(ped, at.w)
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    Wait(200)
end

local function setPiece(ped, part, d)
    if part.prop then
        SetPedPreloadPropData(ped, part.prop, d, 0)
        local t = GetGameTimer() + 4000
        while not HasPedPreloadPropDataFinished(ped) and GetGameTimer() < t do Wait(0) end
        SetPedPropIndex(ped, part.prop, d, 0, true)
        ReleasePedPreloadPropData(ped)
    else
        SetPedPreloadVariationData(ped, part.comp, d, 0)
        local t = GetGameTimer() + 4000
        while not HasPedPreloadVariationDataFinished(ped) and GetGameTimer() < t do Wait(0) end
        SetPedComponentVariation(ped, part.comp, d, 0, 0)
        ReleasePedPreloadVariationData(ped)
    end
    Wait(120)
end

local restore
local saved = {}
local function run(onlyG, onlyKey)
    local at = vec4(-1267.0, -3013.0, 420.0, 330.0) -- high above the airport, in a private world (only you): nothing but sky behind the green
    local back = GetEntityCoords(cache.ped)
    local look = client.getPedAppearance(cache.ped)
    saved.back, saved.look = back, look
    TriggerServerEvent("illenium-appearance:server:ChangeRoutingBucket")
    LocalPlayer.state:set("characterScreen", true, false)   -- (the HUD hides itself, like on the character screen)
    DoScreenFadeOut(300); Wait(400)
    NetworkOverrideClockTime(12, 0, 0)
    SetWeatherTypeNowPersist("EXTRASUNNY")
    DoScreenFadeIn(300)

    local made, skipped, failed = 0, 0, 0
    for _, g in ipairs({ "m", "f" }) do
        if stopAsked then break end
        if not onlyG or onlyG == g then
            local ped = loadModel(GENDERS[g])
            dress(ped, g)
            stand(ped, at)

            -- clothes, hair and accessories
            for _, part in ipairs(PARTS) do
                if stopAsked then break end
                if not onlyKey or onlyKey == part.key then
                    local count = part.prop and GetNumberOfPedPropDrawableVariations(ped, part.prop)
                        or GetNumberOfPedDrawableVariations(ped, part.comp)
                    local have = redoAll and {} or lib.callback.await("illenium-appearance:server:photoHave", false, g .. "-" .. part.key, count) or {}
                    note(("%s %s: %d قطعة"):format(g == "m" and "رجال" or "نساء", part.key, count))
                    dress(ped, g)
                    aim(part.view)
                    Wait(300)
                    for d = 0, count - 1 do
                        if stopAsked then break end
                        if have[d + 1] then
                            skipped = skipped + 1
                        else
                            local okP, data = pcall(function() setPiece(ped, part, d); return shoot() end)
                            if okP and save(("%s-%s-%d"):format(g, part.key, d), data) then made = made + 1
                            else failed = failed + 1; print(("[photo tool] no picture for %s-%s-%d%s"):format(g, part.key, d, okP and "" or (": " .. tostring(data)))) end
                            if (d + 1) % 25 == 0 then print(("[photo tool] %s %s: %d / %d"):format(g, part.key, d + 1, count)) end
                        end
                    end
                    dress(ped, g)
                end
            end

            -- barber pictures
            for _, ov in ipairs(OVERLAYS) do
                if stopAsked then break end
                if not onlyKey or onlyKey == ov.key then
                    local count = GetPedHeadOverlayNum(ov.i)
                    local have = redoAll and {} or lib.callback.await("illenium-appearance:server:photoHave", false, g .. "-" .. ov.key, count) or {}
                    dress(ped, g)
                    SetPedHeadOverlay(ped, 2, 255, 0.0)
                    aim(ov.view or "head")
                    Wait(300)
                    for s = 0, count - 1 do
                        if stopAsked then break end
                        if have[s + 1] then
                            skipped = skipped + 1
                        else
                            SetPedHeadOverlay(ped, ov.i, s, 1.0)
                            if ov.ctype then SetPedHeadOverlayColor(ped, ov.i, ov.ctype, ov.ctype == 2 and 6 or 0, 0) end
                            Wait(120)
                            local okP, data = pcall(shoot)
                            if okP and save(("%s-%s-%d"):format(g, ov.key, s), data) then made = made + 1 else failed = failed + 1 end
                        end
                    end
                    SetPedHeadOverlay(ped, ov.i, 255, 0.0)
                end
            end
        end
    end

    -- the 46 parents (faces for the character creator and the clinic)
    if not stopAsked and (not onlyKey or onlyKey == "parents") then
        local have = redoAll and {} or lib.callback.await("illenium-appearance:server:photoHave", false, "p", 46) or {}
        local current
        for i = 0, 45 do
            if stopAsked then break end
            if not have[i + 1] then
                local g = ((i >= 21 and i <= 41) or i == 45) and "f" or "m"
                if current ~= g then
                    local ped = loadModel(GENDERS[g]); dress(ped, g); stand(ped, at); current = g
                end
                local ped = P
                SetPedComponentVariation(ped, 2, 0, 0, 0)
                SetPedHeadBlendData(ped, i, i, 0, i, i, 0, 0.0, 0.0, 0.0, false)
                aim("head")
                Wait(400)
                if save(("p-%d"):format(i), shoot()) then made = made + 1 end
            else
                skipped = skipped + 1
            end
        end
    end

    restore(back, look)
    print(("[photo tool] done: %d new, %d already there, %d failed"):format(made, skipped, failed))
    note(("انتهى: %d صورة جديدة، %d موجودة، %d فشلت. اكتب refresh ثم ensure illenium-appearance"):format(made, skipped, failed))
end

-- put the admin back as they were (also used when the tool stops on an error)
restore = function(back, look)
    screen = nil
    LocalPlayer.state:set("characterScreen", false, false)
    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false); cam = nil end
    DoScreenFadeOut(300); Wait(400)
    if look then
        client.setPlayerAppearance(look)
        Wait(300)
        client.setPedAppearance(PlayerPedId(), look) -- in case the model swap was not picked up yet
    end
    P = nil
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityCoordsNoOffset(PlayerPedId(), back.x, back.y, back.z, false, false, false)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    NetworkClearClockTimeOverride()
    TriggerServerEvent("illenium-appearance:server:ResetRoutingBucket")
    Wait(300)
    DoScreenFadeIn(300)
    Framework.CachePed()
end

local redoAll = false
RegisterNetEvent("illenium-appearance:client:photoTool", function(g, key, redo)
    redoAll = redo == true
    if g == "stop" then
        if running then stopAsked = true; note("سيتوقف بعد الصورة الحالية") end
        return
    end
    if running then return note("الأداة تعمل الآن. اكتب /extiphotos stop لإيقافها") end
    if GetResourceState("screencapture") ~= "started" then return note("مورد screencapture غير شغال") end
    if ExtiShop then return note("أغلق شاشة الملابس أولًا") end
    if g and g ~= "m" and g ~= "f" then key = g; g = nil end -- /extiphotos parents
    running, stopAsked = true, false
    saved.back, saved.look = nil, nil
    local ok, err = pcall(run, g, key)
    if not ok then
        print("^1[photo tool] " .. tostring(err))
        if saved.back then pcall(restore, saved.back, saved.look) end
        DoScreenFadeIn(300)
        note("توقفت الأداة بسبب خطأ (انظر F8)")
    end
    running = false
end)
