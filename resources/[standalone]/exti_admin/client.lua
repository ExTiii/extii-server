-- =====================================================================
-- EX_Tii admin tablet (game side): F1 opens it; the powers you use on yourself live here
-- =====================================================================
local open = false
local state = { noclip = false, god = false, invisible = false, names = false, spec = nil }

local function nui(action, data) SendNUIMessage({ action = action, data = data }) end
local function close()
    if not open then return end
    open = false; SetNuiFocus(false, false); nui('close')
end

local function toggle()
    if open then return close() end
    local info = lib.callback.await('exti_admin:open', false)
    if not info then return end                    -- not staff: F1 does nothing
    info.self = state
    open = true; SetNuiFocus(true, true); nui('open', info)
end
RegisterCommand('extiadmin', toggle, false)
RegisterKeyMapping('extiadmin', 'لوحة الإدارة (EX_Tii)', 'keyboard', Config.key)
RegisterNetEvent('exti_admin:client:close', close)

RegisterNUICallback('close', function(_, cb) close(); cb(true) end)

-- every server action from the page goes through here; positions come back for goto
-- teleport: always in its own thread (never inside a tablet callback), frozen until the ground around is loaded
local teleporting = false
local function teleport(c)
    if teleporting then return end
    teleporting = true
    CreateThread(function()
        local ped = PlayerPedId()
        local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        local x, y, z = c.x + 0.0, c.y + 0.0, c.z + 0.0
        DoScreenFadeOut(200)
        local t = GetGameTimer()
        while not IsScreenFadedOut() and GetGameTimer() - t < 1000 do Wait(0) end
        FreezeEntityPosition(ent, true)
        RequestCollisionAtCoord(x, y, z)
        SetEntityCoordsNoOffset(ent, x, y, z + 0.5, false, false, false)
        t = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() - t < 3000 do RequestCollisionAtCoord(x, y, z); Wait(0) end
        -- land on the ground near the height you typed (so a slightly wrong Z doesn't drop you or bury you)
        local found, gz = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
        if found and math.abs(gz - z) < 15.0 then SetEntityCoordsNoOffset(ent, x, y, gz + 0.3, false, false, false) end
        FreezeEntityPosition(ent, false)
        DoScreenFadeIn(250)
        teleporting = false
    end)
end

local stopSpectate   -- (below)
local setSelf        -- (below)
RegisterNUICallback('do', function(req, cb)
    local ok, msg, extra = lib.callback.await('exti_admin:do', false, req.action, req.data or {})
    if ok and extra then
        if req.action == 'spectate' then CreateThread(function()
            if state.noclip then setSelf('noclip', false); Wait(100) end
            if state.spec and stopSpectate then stopSpectate(); local t = GetGameTimer(); while state.spec and GetGameTimer() - t < 3000 do Wait(0) end end
            state.spec = extra.id; stopSpectate = startSpectate(extra)
        end)
        elseif extra.x then teleport(extra) end
        if extra.close or extra.x then close() end
    end
    cb({ ok = ok, msg = msg })
end)

RegisterNUICallback('fetch', function(req, cb)
    local name = ({ players = 'exti_admin:players', server = 'exti_admin:server', gangs = 'exti_admin:gangs', logs = 'exti_admin:logs', heist = 'exti_admin:heist', bans = 'exti_admin:bans', staff = 'exti_admin:staff', pinfo = 'exti_admin:pinfo' })[req.what]
    if not name then return cb(false) end
    cb(lib.callback.await(name, false, req.q) or false)
end)

---------------------------------------------------------------------------
-- powers on myself
---------------------------------------------------------------------------
local function noclipLoop()
    local ped = PlayerPedId()
    local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    SetEntityCollision(ent, false, false); FreezeEntityPosition(ent, true); SetEntityInvincible(ent, true)
    if ent == ped then SetEntityVisible(ped, false, false) end
    local speed = 1.0
    while state.noclip do
        Wait(0)
        DisableAllControlActions(0)
        for _, c in ipairs({ 1, 2, 249, 245, 200 }) do EnableControlAction(0, c, true) end   -- look around, push to talk, chat, esc
        local cam = GetGameplayCamRot(2)
        local rz, rx = math.rad(cam.z), math.rad(cam.x)
        local fwd = vec3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
        local right = vec3(math.cos(rz), math.sin(rz), 0.0)
        if IsDisabledControlJustPressed(0, 241) then speed = math.min(12.0, speed * 1.5) end      -- wheel up
        if IsDisabledControlJustPressed(0, 242) then speed = math.max(0.1, speed / 1.5) end      -- wheel down
        local mult = (IsDisabledControlPressed(0, 21) and 4.0) or (IsDisabledControlPressed(0, 19) and 0.25) or 1.0   -- shift fast, alt slow
        local p = GetEntityCoords(ent)
        local move = vec3(0, 0, 0)
        if IsDisabledControlPressed(0, 32) then move = move + fwd end        -- W
        if IsDisabledControlPressed(0, 33) then move = move - fwd end        -- S
        if IsDisabledControlPressed(0, 34) then move = move - right end      -- A
        if IsDisabledControlPressed(0, 35) then move = move + right end      -- D
        if IsDisabledControlPressed(0, 22) then move = move + vec3(0, 0, 1) end   -- Space up
        if IsDisabledControlPressed(0, 36) then move = move - vec3(0, 0, 1) end   -- Ctrl down
        p = p + move * speed * mult
        SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, true, true, true)
        SetEntityHeading(ent, cam.z)
        -- the help line, GTA style
        SetTextFont(4); SetTextScale(0.36, 0.36); SetTextColour(255, 255, 255, 220); SetTextOutline()
        BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(('NOCLIP  W A S D  ·  Space / Ctrl  ·  Shift fast · Alt slow  ·  wheel: %.1f'):format(speed)); EndTextCommandDisplayText(0.4, 0.95)
    end
    SetEntityCollision(ent, true, true); FreezeEntityPosition(ent, false)
    if not state.god then SetEntityInvincible(ent, false) end
    if ent == ped and not state.invisible then SetEntityVisible(ped, true, false) end
    -- land on the ground under us
    local p = GetEntityCoords(ent)
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z, false)
    if found and p.z - gz < 50.0 then SetEntityCoords(ent, p.x, p.y, gz + 0.1, false, false, false, false) end
end

function setSelf(what, on)
    if not lib.callback.await('exti_admin:self', false, what, on) then return false end
    state[what] = on
    local ped = PlayerPedId()
    if what == 'noclip' and on then CreateThread(noclipLoop)
    elseif what == 'god' then SetEntityInvincible(ped, on); SetPlayerInvincible(PlayerId(), on)
    elseif what == 'invisible' then SetEntityVisible(ped, not on, false)
    end
    return true
end

-- god mode survives a respawn / new ped
lib.onCache('ped', function(ped)
    if state.god then SetEntityInvincible(ped, true) end
    if state.invisible then SetEntityVisible(ped, false, false) end
end)

-- EX_Tii (Moe): noclip on its own key (the server checks the power, same as from the panel)
RegisterCommand('extinoclip', function()
    if open then return end
    if state.spec then return end                  -- not while spectating
    local on = not state.noclip
    if setSelf('noclip', on) then
        lib.notify({ description = on and 'Noclip: تشغيل' or 'Noclip: إيقاف', type = 'inform' })
    end
end, false)
RegisterKeyMapping('extinoclip', 'Noclip (EX_Tii)', 'keyboard', Config.noclipKey)

RegisterNUICallback('self', function(req, cb)
    local what, on = req.what, req.on == true
    local ped = PlayerPedId()
    if what == 'noclip' or what == 'god' or what == 'invisible' then return cb({ ok = setSelf(what, on), state = state }) end
    if what == 'names' then
        if not lib.callback.await('exti_admin:self', false, 'names', on) then return cb({ ok = false }) end
        state.names = on; return cb({ ok = true, state = state })
    end
    if what == 'waypoint' then
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then return cb({ ok = false, msg = 'ضع علامة على الخريطة أولًا' }) end
        if not lib.callback.await('exti_admin:self', false, 'tp') then return cb({ ok = false }) end
        local c = GetBlipInfoIdCoord(blip)
        close()
        CreateThread(function()
            local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
            local start = GetEntityCoords(ent)
            DoScreenFadeOut(150); Wait(160)
            FreezeEntityPosition(ent, true)
            local landed = false
            for z = 1000.0, -100.0, -25.0 do
                SetEntityCoords(ent, c.x, c.y, z, false, false, false, false)
                RequestCollisionAtCoord(c.x, c.y, z); Wait(50)
                local found, gz = GetGroundZFor_3dCoord(c.x, c.y, z, false)
                if found then SetEntityCoords(ent, c.x, c.y, gz + 0.5, false, false, false, false); landed = true; break end
            end
            if not landed then
                local hz = GetHeightmapTopZForPosition(c.x, c.y)
                if hz and hz > -100.0 then SetEntityCoords(ent, c.x, c.y, hz + 1.0, false, false, false, false)
                else SetEntityCoords(ent, start.x, start.y, start.z, false, false, false, false) end
            end
            FreezeEntityPosition(ent, false)
            DoScreenFadeIn(250)
        end)
        return cb({ ok = true })
    end
    if what == 'coords' then
        if not lib.callback.await('exti_admin:self', false, 'tp') then return cb({ ok = false }) end
        local c = req.c or {}
        local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
        if not x or not y or not z then lib.notify({ type = 'error', description = 'اكتب X و Y و Z' }) return cb({ ok = false }) end
        close(); teleport({ x = x, y = y, z = z })
        return cb({ ok = true })
    end
    if what == 'mycoords' then
        local p, h = GetEntityCoords(ped), GetEntityHeading(ped)
        return cb({ ok = true, text = ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(p.x, p.y, p.z, h) })
    end
    if what == 'fix' or what == 'clean' or what == 'fuel' or what == 'flip' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then veh = lib.getClosestVehicle(GetEntityCoords(ped), 6.0, false) or 0 end
        if veh == 0 then return cb({ ok = false, msg = 'لا سيارة قريبة' }) end
        if not lib.callback.await('exti_admin:self', false, 'fix', what) then return cb({ ok = false }) end
        if what == 'fix' then SetVehicleFixed(veh); SetVehicleDeformationFixed(veh); SetVehicleEngineHealth(veh, 1000.0); SetVehicleBodyHealth(veh, 1000.0); SetVehiclePetrolTankHealth(veh, 1000.0)
        elseif what == 'clean' then SetVehicleDirtLevel(veh, 0.0); WashDecalsFromVehicle(veh, 1.0)
        elseif what == 'fuel' then Entity(veh).state:set('fuel', 100.0, true); SetVehicleFuelLevel(veh, 100.0)
        elseif what == 'flip' then local r = GetEntityRotation(veh, 2); SetEntityRotation(veh, 0.0, 0.0, r.z, 2, true) end
        return cb({ ok = true, msg = 'تم' })
    end
    if what == 'delete' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then veh = lib.getClosestVehicle(GetEntityCoords(ped), 6.0, false) or 0 end
        if veh == 0 then return cb({ ok = false, msg = 'لا سيارة قريبة' }) end
        if not lib.callback.await('exti_admin:self', false, 'delete') then return cb({ ok = false }) end
        SetEntityAsMissionEntity(veh, true, true); NetworkRequestControlOfEntity(veh)
        local t = GetGameTimer(); while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 1000 do Wait(0); NetworkRequestControlOfEntity(veh) end
        DeleteVehicle(veh)
        return cb({ ok = true, msg = 'حُذفت' })
    end
    if what == 'minigame' then
        close()
        local okM = pcall(function() exports.exti_gangs:TestMinigame(req.game) end)
        return cb({ ok = okM })
    end
    cb({ ok = false })
end)

---------------------------------------------------------------------------
-- spectate: my body waits hidden under him; my own camera orbits him (mouse = look around,
-- wheel = closer / further), the world loads around HIM. BACKSPACE = back where I was.
---------------------------------------------------------------------------
function startSpectate(t)
    local ped = PlayerPedId()
    local back = GetEntityCoords(ped)
    local backH = GetEntityHeading(ped)
    SetEntityVisible(ped, false, false); SetEntityCollision(ped, false, false); FreezeEntityPosition(ped, true); SetEntityInvincible(ped, true)
    SetEntityCoords(ped, t.x, t.y, t.z - 12.0, false, false, false, false)
    local stop = false
    CreateThread(function()
        local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(cam, 55.0)
        local yaw, pitch, dist = GetGameplayCamRot(2).z, -12.0, 4.5
        local t0, lastAsk, tped = GetGameTimer(), 0, 0
        local name = t.name or ('#' .. t.id)
        local lastPos = vec3(t.x, t.y, t.z)
        while not stop do
            local pl = GetPlayerFromServerId(t.id)
            tped = pl ~= -1 and GetPlayerPed(pl) or 0
            local focus
            if tped ~= 0 and DoesEntityExist(tped) then
                focus = GetEntityCoords(tped) + vec3(0.0, 0.0, 0.6)
                lastPos = focus
            else
                -- he's too far for my game to have him: ask where he is and move there
                focus = lastPos
                if GetGameTimer() - lastAsk > 1500 then
                    lastAsk = GetGameTimer()
                    CreateThread(function()
                        local ok, _, c = lib.callback.await('exti_admin:do', false, 'spectateFollow', { id = t.id })
                        if ok and c then lastPos = vec3(c.x, c.y, c.z + 0.6)
                        elseif not ok and GetGameTimer() - t0 > 3000 then stop = true end
                    end)
                end
            end
            -- keep my hidden body under him (so his surroundings exist in my game) and load the world there
            if #(GetEntityCoords(ped) - focus) > 30.0 then SetEntityCoords(ped, focus.x, focus.y, focus.z - 12.0, false, false, false, false) end
            SetFocusPosAndVel(focus.x, focus.y, focus.z, 0.0, 0.0, 0.0)
            -- mouse look and zoom
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true); EnableControlAction(0, 245, true)   -- push-to-talk, chat
            yaw = yaw - GetDisabledControlNormal(0, 1) * 6.0
            pitch = math.max(-70.0, math.min(30.0, pitch - GetDisabledControlNormal(0, 2) * 6.0))
            if IsDisabledControlJustPressed(0, 241) then dist = math.max(1.5, dist - 0.75) end
            if IsDisabledControlJustPressed(0, 242) then dist = math.min(25.0, dist + 0.75) end
            local ry, rp = math.rad(yaw), math.rad(pitch)
            local off = vec3(math.sin(ry) * math.cos(rp), -math.cos(ry) * math.cos(rp), -math.sin(rp)) * dist
            -- (don't go through walls: stop the camera where something solid is)
            local want = focus + off
            local ray = StartShapeTestRay(focus.x, focus.y, focus.z, want.x, want.y, want.z, 1 | 16, tped ~= 0 and tped or ped, 7)
            local _, hit, hitPos = GetShapeTestResult(ray)
            local camPos = (hit == 1 or hit == true) and (focus + (hitPos - focus) * 0.9) or want
            SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
            PointCamAtCoord(cam, focus.x, focus.y, focus.z)
            if not IsCamRendering(cam) then RenderScriptCams(true, false, 0, true, true) end
            SetTextFont(4); SetTextScale(0.36, 0.36); SetTextColour(255, 255, 255, 220); SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('مراقبة %s  ·  الفأرة للنظر · العجلة للتقريب · BACKSPACE للخروج'):format(name))
            EndTextCommandDisplayText(0.30, 0.95)
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then break end
            Wait(0)
        end
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        ClearFocus()
        SetEntityCoords(ped, back.x, back.y, back.z, false, false, false, false)
        SetEntityHeading(ped, backH)
        RequestCollisionAtCoord(back.x, back.y, back.z)
        local tw = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - tw < 2500 do Wait(0) end
        FreezeEntityPosition(ped, false); SetEntityCollision(ped, true, true)
        if not state.invisible then SetEntityVisible(ped, true, false) end
        if not state.god then SetEntityInvincible(ped, false) end
        state.spec = nil
    end)
    return function() stop = true end
end

---------------------------------------------------------------------------
-- what admins do to you
---------------------------------------------------------------------------
local frozen = false
RegisterNetEvent('exti_admin:client:freeze', function(on)
    frozen = on
    FreezeEntityPosition(PlayerPedId(), on)
    lib.notify({ description = on and 'جمّدتك الإدارة' or 'فكّت الإدارة التجميد', type = on and 'warning' or 'success' })
    if on then CreateThread(function()
        while frozen do DisableAllControlActions(0); EnableControlAction(0, 1, true); EnableControlAction(0, 2, true); EnableControlAction(0, 249, true); EnableControlAction(0, 245, true); Wait(0) end
    end) end
end)
RegisterNetEvent('exti_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped)); ClearPedBloodDamage(ped)
end)
RegisterNetEvent('exti_admin:client:moveTo', function(c)
    if GetInvokingResource() then return end
    local ped = PlayerPedId()
    local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    FreezeEntityPosition(ent, true)
    SetEntityCoords(ent, c.x, c.y, c.z, false, false, false, false)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() - t < 2500 do Wait(0) end
    if not frozen then FreezeEntityPosition(ent, false) end
end)
RegisterNetEvent('exti_admin:client:message', function(text)
    nui('message', { text = text })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)
RegisterNetEvent('exti_admin:client:announce', function(text, by)
    nui('announce', { text = text, by = by })
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
end)

---------------------------------------------------------------------------
-- names over heads (id · name), only for the admin who turned it on
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        if state.names then
            local me = GetEntityCoords(PlayerPedId())
            for _, pl in ipairs(GetActivePlayers()) do
                local p = GetPlayerPed(pl)
                local c = GetEntityCoords(p)
                if #(me - c) < 80.0 then
                    local on, sx, sy = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 1.1)
                    if on then
                        SetTextFont(4); SetTextScale(0.32, 0.32); SetTextColour(255, 255, 255, 230); SetTextOutline(); SetTextCentre(true)
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName(('[%d] %s  %d'):format(GetPlayerServerId(pl), GetPlayerName(pl), GetEntityHealth(p)))
                        EndTextCommandDisplayText(sx, sy)
                    end
                end
            end
            Wait(0)
        else Wait(500) end
    end
end)
