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
local shown = nil
local owners, ORDER = {}, { 'vault', 'bigbank', 'truck', 'stash', 'yacht', 'prep', 'jewel', 'atm', 'houses', 'stores', 'jobs', 'hostage' }
function HC.prompt(text, owner)
    if owner then owners[owner] = text else owners = {} end
    local want
    for _, o in ipairs(ORDER) do if owners[o] then want = owners[o] break end end
    if want == shown then return end
    shown = want
    if want then lib.showTextUI(want, { position = 'left-center' }) else lib.hideTextUI() end
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
    if not IsPedArmed(cache.ped, 4) or not IsPlayerFreeAiming(cache.playerId) then return false end
    local cam = GetGameplayCamCoord()
    local target = GetPedBoneCoords(ped, 24818, 0.0, 0.0, 0.0)   -- upper chest
    local to = target - cam
    local dist = #to
    if dist > (maxDist or 12.0) or dist < 0.5 then return false end
    local dir = rotToDir(GetGameplayCamRot(2))
    local cos = (to.x * dir.x + to.y * dir.y + to.z * dir.z) / dist
    return cos > math.cos(math.rad(9.0)) and HasEntityClearLosToEntity(cache.ped, ped, 17)
end
