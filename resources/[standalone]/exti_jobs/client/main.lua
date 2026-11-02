-- =====================================================================
-- EX_Tii jobs (game): the core
--   supervisors at every HQ, the gold circles, the blips (only for your job),
--   the job center tablet, the HQ panel, the shift (vehicle, uniform, rounds)
-- The three jobs live in client/garbage.lua, client/delivery.lua, client/tow.lua
-- =====================================================================
local config = require 'config.shared'

EXJ = {
    config = config,
    jobs = {},          -- filled by the job files: EXJ.jobs.garbage = { start, update, stop }
    shift = nil,        -- { job, netId, round }
}

local GOLD = { 232, 181, 71 }

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
function EXJ.notify(text, kind, duration)
    exports.qbx_core:Notify(text, kind or 'inform', duration)
end

function EXJ.myJob()
    return QBX.PlayerData and QBX.PlayerData.job and QBX.PlayerData.job.name or nil
end

function EXJ.vehicle()
    local shift = EXJ.shift
    if not shift or not shift.netId or not NetworkDoesEntityExistWithNetworkId(shift.netId) then return nil end
    local veh = NetworkGetEntityFromNetworkId(shift.netId)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
end

function EXJ.takeControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local untilTime = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < untilTime do
        Wait(50)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

-- loading a model / an animation never stops the script, even when the game is slow
function EXJ.loadModel(model)
    local ok = pcall(lib.requestModel, model, 8000)
    return ok
end

function EXJ.loadDict(dict)
    local ok = pcall(lib.requestAnimDict, dict, 5000)
    return ok
end

-- the spot just behind a vehicle (where bags go in / parcels come out), from the real size of the model
function EXJ.behind(veh, extra)
    local mn = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, mn.y - (extra or 0.75), 0.0)
end

function EXJ.street(coords)
    local hash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name = GetStreetNameFromHashKey(hash)
    return name ~= '' and name or nil
end

---------------------------------------------------------------------------
-- one "[E] ..." line on screen at a time (every part of the job asks for it here)
---------------------------------------------------------------------------
-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end
EXJ.isDown = isDown

-- E for any job action (never while you are down)
function EXJ.pressedE()
    return IsControlJustPressed(0, 38) and not isDown()
end

local promptOwner, promptText = nil, nil
function EXJ.prompt(owner, text)
    if isDown() then return EXJ.clearPrompt() end
    -- (shown again if another script hid the text box meanwhile)
    if promptOwner == owner and promptText == text and lib.isTextUIOpen() then return end
    promptOwner, promptText = owner, text
    lib.showTextUI(text)
end

function EXJ.clearPrompt(owner)
    if owner and promptOwner ~= owner then return end
    if promptOwner then
        promptOwner, promptText = nil, nil
        lib.hideTextUI()
    end
end

---------------------------------------------------------------------------
-- the gold circle (the same one as at the job center): a small soft ring of light that pops in and fades out
---------------------------------------------------------------------------
local floors = {}
function EXJ.floorZ(p)
    local key = ('%d:%d:%d'):format(math.floor(p.x * 2), math.floor(p.y * 2), math.floor(p.z))
    local z = floors[key]
    if z then return z end
    RequestCollisionAtCoord(p.x, p.y, p.z)
    -- look for the floor just above the spot first (under stairs or a roof the first hit from high up
    -- would be the stairs), then from higher up for spots given at floor level on a slope
    for _, up in ipairs({ 0.5, 2.5 }) do
        local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + up, false)
        if found and math.abs(gz - p.z) < 5.0 then
            floors[key] = gz
            return gz
        end
    end
    return p.z - 0.98 -- not loaded yet: a standing person's coordinates are about 1 m above the floor
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

function EXJ.drawCircle(center, radius, here, arrow)
    local z = EXJ.floorZ(center) + 0.03
    GoldCircle.draw(center.x, center.y, z, radius, here, GOLD)
    return z
end

---------------------------------------------------------------------------
-- blips
---------------------------------------------------------------------------
-- EX_Tii map icon plan: yellow = where to go now (with the thin gold GPS line from exti_gps, seen
-- from far away, flashes for 3 seconds when it appears). White = your job (your HQ, your work vehicle).
-- Every icon is the same size (0.75), like every other icon on the map.
local ICON_SIZE = 0.75
local GO_COLOUR, JOB_COLOUR = 5, 0

-- the thin gold line (exti_gps). Without it: GTA's own yellow line, like before.
local routed = {} -- [blip] = { coords = where, thin = true when exti_gps draws its line }
local function gpsOn() return GetResourceState('exti_gps') == 'started' end

local function lineOn(blip, coords)
    local entry = { coords = coords, thin = false }
    if gpsOn() then
        local ok, done = pcall(function()
            return exports.exti_gps:Route('exti_jobs:' .. blip, coords, { blip = blip, routeColour = GO_COLOUR })
        end)
        entry.thin = ok and done == true
    end
    if not entry.thin then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, GO_COLOUR)
    end
    routed[blip] = entry
end

-- exti_gps stopped: GTA's line back on every stop. Started again: the thin line again.
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= 'exti_gps' then return end
    for blip, entry in pairs(routed) do
        if not DoesBlipExist(blip) then
            routed[blip] = nil
        elseif entry.thin then
            entry.thin = false
            SetBlipRoute(blip, true)
            SetBlipRouteColour(blip, GO_COLOUR)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'exti_gps' then return end
    for blip, entry in pairs(routed) do
        if not DoesBlipExist(blip) then
            routed[blip] = nil
        elseif not entry.thin then
            SetBlipRoute(blip, false)
            lineOn(blip, entry.coords)
        end
    end
end)

function EXJ.blip(coords, sprite, label, route)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, GO_COLOUR)
    SetBlipScale(blip, ICON_SIZE)
    SetBlipAsShortRange(blip, false)
    if route then
        lineOn(blip, coords)
        SetBlipFlashes(blip, true)
        SetBlipFlashTimer(blip, 3000)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- your HQ: white, on the small map only when you are close (always on the big map)
local function jobPlaceBlip(coords, sprite, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, JOB_COLOUR)
    SetBlipScale(blip, ICON_SIZE)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

function EXJ.removeBlip(blip)
    local entry = blip and routed[blip]
    if entry then
        routed[blip] = nil
        if entry.thin and gpsOn() then pcall(function() exports.exti_gps:ClearRoute('exti_jobs:' .. blip) end) end
    end
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

---------------------------------------------------------------------------
-- supervisors: a person at every HQ (everyone sees them; the gold circle is only for that job)
---------------------------------------------------------------------------
local supervisors = {} -- [job] = ped

local function spawnSupervisor(name)
    local s = config.jobs[name].hq.supervisor
    local model = joaat(s.model)
    if not EXJ.loadModel(model) then return end
    RequestCollisionAtCoord(s.coords.x, s.coords.y, s.coords.z)
    local z = s.coords.z
    for _ = 1, 30 do
        local found, gz = GetGroundZFor_3dCoord(s.coords.x, s.coords.y, s.coords.z + 0.6, false)
        if found and math.abs(gz - s.coords.z) < 6.0 then z = gz break end
        Wait(100)
    end
    local ped = CreatePed(0, model, s.coords.x, s.coords.y, z, s.coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    if s.scenario then TaskStartScenarioInPlace(ped, s.scenario, 0, true) end
    supervisors[name] = ped
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        for name, job in pairs(config.jobs) do
            local s = job.hq.supervisor.coords
            local dist = #(me - s.xyz)
            local ped = supervisors[name]
            if dist < 120.0 and not (ped and DoesEntityExist(ped)) then
                spawnSupervisor(name)
            elseif dist > 160.0 and ped then
                if DoesEntityExist(ped) then DeletePed(ped) end
                supervisors[name] = nil
            end
        end
        Wait(1500)
    end
end)

-- EX_Tii: a supervisor was moved (/jobspots): he stands again in his new place
local refreshHqBlip -- defined below
AddEventHandler('exti_jobs:client:respawnSupervisors', function()
    for name, ped in pairs(supervisors) do
        if DoesEntityExist(ped) then DeletePed(ped) end
        supervisors[name] = nil
    end
    if refreshHqBlip then refreshHqBlip() end
end)

---------------------------------------------------------------------------
-- my job's HQ: the blip on the map and the gold circle in front of the supervisor
---------------------------------------------------------------------------
local hqBlip, vehicleBlip = nil, nil

refreshHqBlip = function()
    EXJ.removeBlip(hqBlip)
    hqBlip = nil
    local job = config.jobs[EXJ.myJob() or '']
    if not job or not LocalPlayer.state.isLoggedIn then return end
    local s = job.hq.supervisor.coords
    hqBlip = jobPlaceBlip(s, job.hq.blip.sprite, job.hq.blip.name or job.hq.label)
    SetBlipPriority(hqBlip, 11) -- EX_Tii: just the icon (no gold ring around it)
end

function EXJ.routeToHq(name)
    local job = config.jobs[name] or (config.teamJobs and config.teamJobs[name])
    if not job then return end
    local s = job.hq.coords or job.hq.supervisor.coords -- EX_Tii: team jobs (EMS) have no supervisor
    -- thin gold line + a pin named after the HQ (exti_gps); without it, GTA's map marker like before
    local ok, done = false, false
    if gpsOn() then
        ok, done = pcall(function() return exports.exti_gps:GoTo(s.x, s.y, s.z, job.hq.label) end)
    end
    if not (ok and done) then SetNewWaypoint(s.x, s.y) end
end

local panelOpen = false
local openHqPanel -- defined below

CreateThread(function()
    while true do
        local sleep = 1000
        local name = EXJ.myJob()
        local job = config.jobs[name or '']
        if job and LocalPlayer.state.isLoggedIn and not panelOpen then
            local s = job.hq.supervisor.coords
            local h = math.rad(s.w)
            local center = vec3(s.x - math.sin(h) * 1.15, s.y + math.cos(h) * 1.15, s.z)
            local me = GetEntityCoords(cache.ped)
            local dist = #(me.xy - center.xy)
            if dist < 80.0 then
                sleep = 0
                -- EX_Tii: no circle in front of the supervisor: walk up to them and press E
                local here = dist < 1.4 and not cache.vehicle
                local z = EXJ.floorZ(center) + 0.03
                if here and math.abs(me.z - z) < 2.0 then
                    EXJ.prompt('hq', ('[E] %s'):format(job.hq.supervisor.name))
                    if EXJ.pressedE() then
                        EXJ.clearPrompt('hq')
                        openHqPanel(name)
                    end
                else
                    EXJ.clearPrompt('hq')
                end
            else
                EXJ.clearPrompt('hq')
            end
        else
            EXJ.clearPrompt('hq') -- logged out / lost the job while standing in the circle
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- the work vehicle: a small blip on it while you are not inside
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local veh = EXJ.vehicle()
        if EXJ.shift and veh then
            local inside = cache.vehicle == veh
            if inside and vehicleBlip then
                EXJ.removeBlip(vehicleBlip) vehicleBlip = nil
            elseif not inside and not (vehicleBlip and DoesBlipExist(vehicleBlip)) then
                local job = config.jobs[EXJ.shift.job]
                -- your work vehicle: the same white truck icon in every job
                vehicleBlip = AddBlipForEntity(veh)
                SetBlipSprite(vehicleBlip, 477)
                SetBlipDisplay(vehicleBlip, 4)
                SetBlipColour(vehicleBlip, JOB_COLOUR)
                SetBlipScale(vehicleBlip, ICON_SIZE)
                SetBlipAsShortRange(vehicleBlip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(job.vehicle.blipName or job.vehicle.label)
                EndTextCommandSetBlipName(vehicleBlip)
            end
            if IsEntityDead(veh) and not EXJ.shift.broken then
                EXJ.shift.broken = true
                EXJ.notify('تعطّلت مركبة العمل. عد إلى المشرف لإنهاء المناوبة', 'error', 9000)
            end
        elseif vehicleBlip then
            EXJ.removeBlip(vehicleBlip) vehicleBlip = nil
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------------
-- uniforms: put on at the start of the shift, your own clothes come back at the end
---------------------------------------------------------------------------
local savedLook, savedProps = nil, nil

local function wearUniform(name)
    local uniforms = EXJ.uniforms and EXJ.uniforms[name]
    if not uniforms then return end
    local ped = cache.ped
    local model = GetEntityModel(ped)
    local set = (model == `mp_f_freemode_01`) and uniforms.female or (model == `mp_m_freemode_01`) and uniforms.male or nil
    if not set then return end
    if not savedLook then
        local ok, look = pcall(function() return exports['illenium-appearance']:getPedAppearance(ped) end)
        savedLook = ok and look or nil
        -- hats and glasses are put back by hand: the look editor does not take a hat off again
        savedProps = {}
        for slot in pairs(set.props or {}) do
            savedProps[slot] = { GetPedPropIndex(ped, slot), GetPedPropTextureIndex(ped, slot) }
        end
    end
    for comp, v in pairs(set.components or {}) do
        SetPedComponentVariation(ped, comp, v[1], v[2] or 0, 0)
    end
    for prop, v in pairs(set.props or {}) do
        if v[1] < 0 then ClearPedProp(ped, prop) else SetPedPropIndex(ped, prop, v[1], v[2] or 0, true) end
    end
end

local function removeUniform()
    if not savedLook then return end
    local look, props = savedLook, savedProps or {}
    savedLook, savedProps = nil, nil
    pcall(function() exports['illenium-appearance']:setPedAppearance(cache.ped, look) end)
    for slot, v in pairs(props) do
        if v[1] < 0 then ClearPedProp(cache.ped, slot) else SetPedPropIndex(cache.ped, slot, v[1], math.max(v[2], 0), true) end
    end
end

---------------------------------------------------------------------------
-- the shift
---------------------------------------------------------------------------
function EXJ.setRound(round)
    if not EXJ.shift then return end
    EXJ.shift.round = round
    local handler = EXJ.jobs[EXJ.shift.job]
    if handler and handler.update then handler.update(round) end
end

local function beginShift(data)
    EXJ.shift = { job = data.job, netId = data.netId, round = data.round }
    wearUniform(data.job)
    local handler = EXJ.jobs[data.job]
    if handler and handler.start then handler.start(data.round) end
end

local function finishShift()
    local shift = EXJ.shift
    if not shift then return end
    local handler = EXJ.jobs[shift.job]
    if handler and handler.stop then pcall(handler.stop) end
    EXJ.shift = nil
    EXJ.removeBlip(vehicleBlip) vehicleBlip = nil
    removeUniform()
end

RegisterNetEvent('exti_jobs:client:shiftEnded', function()
    if GetInvokingResource() then return end
    if EXJ.shift then
        finishShift()
        EXJ.notify('انتهت مناوبتك', 'inform')
    end
end)

---------------------------------------------------------------------------
-- the tablet (job center) and the HQ panel
---------------------------------------------------------------------------
local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openPanel(mode, data)
    panelOpen = true
    SendNUIMessage({ action = 'open', mode = mode, data = data })
    SetNuiFocus(true, true)
end

-- the job center (qbx_cityhall calls this when you press E in its gold circle)
local function openJobCenter()
    if panelOpen then return end
    local data = lib.callback.await('exti_jobs:server:center', false)
    if not data then return end
    openPanel('center', data)
end
exports('openJobCenter', openJobCenter)
exports('isPanelOpen', function() return panelOpen end)

openHqPanel = function(name)
    if panelOpen then return end
    local data = lib.callback.await('exti_jobs:server:hq', false, name)
    if not data then return end
    openPanel('hq', data)
end

RegisterNUICallback('close', function(_, cb)
    cb(true)
    closePanel()
end)

local ERR = {
    far = 'اقترب أكثر',
    same = 'هذه وظيفتك الحالية',
    locked = 'لا يمكنك ترك وظيفتك الحالية من هنا',
    shift = 'أنهِ مناوبتك أولًا عند المشرف',
    licence = 'تحتاج إلى رخصة قيادة',
    level = 'مستواك لا يكفي لهذه الوظيفة بعد',
    notmine = 'هذه ليست وظيفتك',
    already = 'أنت في مناوبة الآن',
    money = ('تحتاج إلى %s$ للتأمين'):format(config.deposit),
    spot = 'مكان المركبة مشغول، انتظر قليلًا',
    spawn = 'تعذّر إخراج المركبة، حاول مرة أخرى',
    vehicle = 'أحضر مركبة العمل إلى المقر أولًا',
    loaded = 'أنزل المركبة من الشاحنة أولًا',
    failed = 'حدث خطأ، حاول مرة أخرى',
}
EXJ.errors = ERR

RegisterNUICallback('apply', function(data, cb)
    local ok, err = lib.callback.await('exti_jobs:server:apply', false, data and data.job)
    if ok then
        local job = config.jobs[data.job] or config.teamJobs[data.job]
        cb({ ok = true })
        Wait(300)
        refreshHqBlip()
        EXJ.routeToHq(data.job)
        EXJ.notify(('أصبحت %s! حدّدنا لك %s على الخريطة'):format(job.label, job.hq.label), 'success', 8000)
    else
        cb({ ok = false, error = ERR[err] or ERR.failed })
    end
end)

RegisterNUICallback('resign', function(_, cb)
    local ok, err = lib.callback.await('exti_jobs:server:resign', false)
    cb({ ok = ok == true, error = not ok and (ERR[err] or ERR.failed) or nil })
    if ok then
        Wait(300)
        refreshHqBlip()
    end
end)

RegisterNUICallback('gps', function(data, cb)
    cb(true)
    local job = data and (config.jobs[data.job] or config.teamJobs[data.job])
    if job and data.job == EXJ.myJob() then
        EXJ.routeToHq(data.job)
        EXJ.notify(('حدّدنا %s على الخريطة'):format(job.hq.label), 'success')
    end
end)

-- documents: the job center already sells them (qbx_cityhall checks everything)
RegisterNUICallback('document', function(data, cb)
    local ok = lib.callback.await('qbx_cityhall:server:requestId', false, data and data.item, 1)
    cb({ ok = ok == true })
end)

RegisterNUICallback('refresh', function(data, cb)
    if data and data.mode == 'hq' then
        cb(lib.callback.await('exti_jobs:server:hq', false, data.job) or false)
    else
        cb(lib.callback.await('exti_jobs:server:center', false) or false)
    end
end)

RegisterNUICallback('startShift', function(data, cb)
    -- level jobs: the truck comes on the road next to the supervisor (when no spot was set with /jobspots)
    local road = data and EXJ.roadSpot and EXJ.roadSpot(data.job) or nil
    local ok, result = lib.callback.await('exti_jobs:server:startShift', false, data and data.job, road)
    if not ok then return cb({ ok = false, error = ERR[result] or ERR.failed }) end
    cb({ ok = true })
    closePanel()
    beginShift(result)
end)

RegisterNUICallback('endShift', function(data, cb)
    local ok, result = lib.callback.await('exti_jobs:server:endShift', false, data and data.withoutVehicle == true)
    if not ok then return cb({ ok = false, error = ERR[result] or ERR.failed }) end
    cb({ ok = true })
    closePanel()
    finishShift()
    local parts = { ('انتهت مناوبتك: كسبت %s$'):format(result.earned) }
    if result.refund > 0 then parts[#parts + 1] = ('واسترجعت التأمين %s$'):format(result.refund) end
    if result.bonus > 0 then parts[#parts + 1] = ('مع مكافأة إرجاع %s$'):format(result.bonus) end
    if result.refund == 0 then parts[#parts + 1] = 'ولم يُسترجع التأمين لأن المركبة لم تُرجع' end
    EXJ.notify(table.concat(parts, '، '), 'success', 10000)
end)

---------------------------------------------------------------------------
-- admins: /jobskip jumps to where the job wants you next (with the work vehicle if you sit in it)
---------------------------------------------------------------------------
-- admins (testing): /joblast = jump to the last stop of this round
RegisterCommand('joblast', function()
    if not EXJ.shift then return end
    local ok, round = lib.callback.await('exti_jobs:server:devLastStop', false)
    if ok and round then
        EXJ.setRound(round)
        EXJ.notify(('اختبار: المحطة الأخيرة (%d من %d)'):format(round.index, round.total), 'inform', 5000)
    end
end, false)

RegisterCommand('jobskip', function(_, args)
    if not EXJ.shift or not lib.callback.await('exti_jobs:server:isAdmin', false) then return end
    if args[1] == 'back' then -- just behind the work vehicle
        local veh = EXJ.vehicle()
        if veh then
            local p = EXJ.behind(veh, 1.0)
            SetEntityCoords(cache.ped, p.x, p.y, p.z, false, false, false, false)
            SetEntityHeading(cache.ped, GetEntityHeading(veh))
        end
        return
    end
    local handler = EXJ.jobs[EXJ.shift.job]
    local target, exact
    if handler and handler.target then target, exact = handler.target() end
    if not target then return end
    local veh = cache.vehicle
    if veh then
        local x, y, z, h = target.x, target.y, target.z, GetEntityHeading(veh)
        if not exact then
            -- park on the road next to the stop
            local ok, node, heading = GetClosestVehicleNodeWithHeading(target.x, target.y, target.z, 1, 3.0, 0)
            if ok then x, y, z, h = node.x, node.y, node.z, heading end
        end
        RequestCollisionAtCoord(x, y, z)
        SetEntityCoords(veh, x, y, z + 0.5, false, false, false, false)
        SetEntityHeading(veh, h)
        Wait(500)
        SetVehicleOnGroundProperly(veh)
    else
        -- on foot: the tow car stands on the spot itself, so stop a few steps short of it, on your side
        local me = GetEntityCoords(cache.ped)
        local dx, dy = me.x - target.x, me.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)
        local x, y = target.x, target.y
        if EXJ.shift.job == 'tow' and len > 0.1 then x, y = target.x + dx / len * 2.8, target.y + dy / len * 2.8 end
        RequestCollisionAtCoord(x, y, target.z)
        local found, gz = GetGroundZFor_3dCoord(x, y, target.z + 2.0, false)
        SetEntityCoords(cache.ped, x, y, (found and gz or target.z) + 0.1, false, false, false, false)
    end
end, false)

---------------------------------------------------------------------------
-- start / job changes / restarts
---------------------------------------------------------------------------
local function onJobChanged()
    refreshHqBlip()
    if EXJ.shift and EXJ.shift.job ~= EXJ.myJob() then finishShift() end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function() Wait(250) onJobChanged() end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() Wait(1000) onJobChanged() end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    closePanel()
    finishShift()
    EXJ.removeBlip(hqBlip) hqBlip = nil
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    Wait(1500)
    refreshHqBlip()
    local state = lib.callback.await('exti_jobs:server:state', false)
    if state then beginShift(state) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if panelOpen then SetNuiFocus(false, false) end
    EXJ.clearPrompt()
    EXJ.removeBlip(hqBlip)
    EXJ.removeBlip(vehicleBlip)
    if EXJ.shift then
        local handler = EXJ.jobs[EXJ.shift.job]
        if handler and handler.stop then pcall(handler.stop) end
    end
    removeUniform()
    for _, ped in pairs(supervisors) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
end)
