-- =====================================================================
-- EX_Tii heists (game side core): the minigame bridge, the [E] prompt, small helpers.
-- =====================================================================
HC = {}

---------------------------------------------------------------------------
-- the minigames (html/hgames.js): HC.play('lockpick', { pins = 4 }) -> true | false
---------------------------------------------------------------------------
local playing = nil
function HC.play(game, params, title)
    if playing then return false end
    local p = promise.new()
    playing = p
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'start', game = game, params = params or {}, title = title })
    local ok = Citizen.Await(p)
    playing = nil
    SetNuiFocus(false, false)
    return ok == true
end
RegisterNUICallback('done', function(data, cb)
    cb(true)
    if playing then playing:resolve(data and data.passed == true) end
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and playing then SetNuiFocus(false, false) end
end)
function HC.busy() return playing ~= nil end

---------------------------------------------------------------------------
-- the [E] prompt (left side, like the gangs and the jobs)
---------------------------------------------------------------------------
-- several loops (stores, houses, ATMs, the jewelry store) each own a prompt; the first one that has
-- something to say is shown. HC.prompt(nil) with no owner (an action starting) clears them all.
local shown, shownAt = nil, 0
local owners, ORDER = {}, { 'vault', 'bigbank', 'truck', 'stash', 'yacht', 'prep', 'jewel', 'atm', 'houses', 'stores', 'jobs', 'hostage' }
function HC.prompt(text, owner)
    if owner then owners[owner] = text else owners = {} end
    local want
    for _, o in ipairs(ORDER) do if owners[o] then want = owners[o] break end end
    -- exti_interact keeps one line per script, so this line is always ours: shown again if it went missing,
    -- hidden the moment we have nothing to say (no text comparing: a changing countdown never leaves a stuck line)
    local open = lib.isTextUIOpen()
    -- (tell the shopkeeper script a robbery/heist prompt is up: it stays quiet and ignores E)
    if (want ~= nil) ~= (LocalPlayer.state.extiPrompt == true) then LocalPlayer.state:set('extiPrompt', want ~= nil, false) end
    if want then
        -- (shown again every second: exti_interact drops a line its owner stopped renewing)
        if want == shown and open and GetGameTimer() - shownAt < 1000 then return end
        shown, shownAt = want, GetGameTimer()
        lib.showTextUI(want, { position = 'left-center' })
    else
        if shown or open then lib.hideTextUI() end
        shown = nil
    end
end

-- EX_Tii (Moe): E belongs to the line on screen. Several features of this script share one line (only the
-- first that has something to say is shown): a feature acts on E only when its own text is the one showing,
-- so one press never does two things (the till and the ATM, the safe and a door...)
local claimedFrame = -1
function HC.lineIs(text)
    if not text then return false end
    local open, cur = lib.isTextUIOpen()
    if open ~= true or cur ~= text then return false end
    -- (and one press is used once: two features showing in the same instant can't both act)
    local f = GetFrameCount()
    if claimedFrame == f then return false end
    claimedFrame = f
    return true
end

function HC.notify(text, kind, duration)
    lib.notify({ description = text, type = kind or 'inform', position = 'top', duration = duration or 5000 })
end

function HC.anim(ped, dict, clip, flag, duration)
    if not ped or not DoesEntityExist(ped) then return end
    if not pcall(lib.requestAnimDict, dict, 3000) then return end
    TaskPlayAnim(ped, dict, clip, 3.0, 3.0, duration or -1, flag or 1, 0.0, false, false, false)
    RemoveAnimDict(dict)
end

function HC.canAct()
    return not HC.busy() and not lib.progressActive() and not cache.vehicle and not IsPedDeadOrDying(cache.ped, true) and not IsPauseMenuActive()
        and not HC.isDown()
end
function HC.isDown()
    local ds = LocalPlayer.state['qbx_medical:deathState']
    return (ds ~= nil and ds ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

function HC.count(item)
    local n = exports.ox_inventory:Search('count', item)
    return tonumber(n) or 0
end

-- is the player aiming (free aim, a gun) at this ped's chest/head?
local function rotToDir(r)
    local x, z = math.rad(r.x), math.rad(r.z)
    return vec3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end
function HC.aimingAt(ped, maxDist)
    if not ped or not DoesEntityExist(ped) then return false end
    if not IsPedArmed(cache.ped, 4) then return false end
    if not (IsPlayerFreeAiming(cache.playerId) or IsAimCamActive() or IsControlPressed(0, 25)) then return false end
    -- what GTA itself says you're aiming at
    local okA, ent = GetEntityPlayerIsFreeAimingAt(cache.playerId)
    if okA and ent == ped and #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) <= (maxDist or 12.0) then return true end
    -- else: the crosshair is on his body (chest or head), seen from the camera
    local cam = GetGameplayCamCoord()
    local dir = rotToDir(GetGameplayCamRot(2))
    for _, bone in ipairs({ 24818, 31086, 11816 }) do   -- upper chest, head, pelvis
        local target = GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
        local to = target - cam
        local dist = #to
        if dist <= (maxDist or 12.0) + 3.0 and dist >= 0.5
            and #(target - GetEntityCoords(cache.ped)) <= (maxDist or 12.0)
            and (to.x * dir.x + to.y * dir.y + to.z * dir.z) / dist > math.cos(math.rad(12.0)) then
            -- nothing solid between the camera and him (the counter is lower than his chest)
            local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, target.x, target.y, target.z, 1 | 16, cache.ped, 7)
            local _, hit, pos = GetShapeTestResult(ray)
            if hit ~= 1 and hit ~= true then return true end
            if #(pos - target) < 0.8 then return true end
        end
    end
    return false
end
