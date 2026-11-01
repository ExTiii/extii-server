-- =====================================================================
-- EX_Tii EMS (client): the rugged tablet.
-- Your character takes the tablet out and holds it with both hands. The screen you use is also
-- painted, live, on the tablet in your hands (a second copy of the page, ?mirror=1).
-- Other players see a locked EMS screen on your tablet, never your patient's details.
-- =====================================================================

local T = Config.tablet
local RES = GetCurrentResourceName()
local TXD = 'exti_ems_tablet'

local tablet = { open = false, obj = nil, target = nil, acting = false, tuning = false }
local screens = nil      -- { live = dui, locked = dui, ready = { live = bool, locked = bool } }
local lastState = nil    -- the last full screen (sent again when the mirror page finishes loading)
local lastClock = ''
local geo = nil          -- the 4 corners of the screen on the tablet model
local others = {}        -- other medics' tablets near you

local function exam() return GetResourceState('exti_medical') == 'started' end

-- ---------------------------------------------------------------------
-- the two screen pages (made once, the first time they are needed)
-- ---------------------------------------------------------------------
local function sendLive(json)
    if screens and screens.ready.live then SendDuiMessage(screens.live, json) end
end

local function ensureScreens()
    if screens then return end
    local txd = CreateRuntimeTxd(TXD)
    local live = CreateDui(('nui://%s/html/index.html?mirror=1'):format(RES), T.screenW, T.screenH)
    local locked = CreateDui(('nui://%s/html/locked.html'):format(RES), 610, 388)
    CreateRuntimeTextureFromDuiHandle(txd, 'live', GetDuiHandle(live))
    CreateRuntimeTextureFromDuiHandle(txd, 'locked', GetDuiHandle(locked))
    screens = { live = live, locked = locked, ready = { live = false, locked = false } }
    CreateThread(function()
        local tries = 0
        while screens and not IsDuiAvailable(screens.live) and tries < 100 do tries = tries + 1 Wait(100) end
        Wait(600) -- give the page a moment to run its script
        if not screens then return end
        screens.ready.live = true
        screens.ready.locked = true
        if lastState then sendLive(('{"type":"state","s":%s}'):format(lastState)) end
        if lastClock ~= '' then sendLive(json.encode({ type = 'clock', t = lastClock })) end
    end)
end

-- ---------------------------------------------------------------------
-- where the screen sits on the tablet model (tune it in game: /tablettune)
-- ---------------------------------------------------------------------
local function screenGeo()
    if geo then return geo end
    local s = T.screen
    local mn, mx = GetModelDimensions(T.prop)
    local MN, MX = { x = mn.x, y = mn.y, z = mn.z }, { x = mx.x, y = mx.y, z = mx.z }
    local size = { x = MX.x - MN.x, y = MX.y - MN.y, z = MX.z - MN.z }
    local axes = { 'x', 'y', 'z' }
    table.sort(axes, function(a, b) return size[a] < size[b] end)
    local thin, short, long = axes[1], axes[2], axes[3]
    local c = { x = (MN.x + MX.x) / 2, y = (MN.y + MX.y) / 2, z = (MN.z + MX.z) / 2 }
    local face = (s.face >= 0 and MX[thin] or MN[thin]) + (s.face >= 0 and 1 or -1) * s.push
    local hl = size[long] / 2 * (1 - s.insetLong * 2) * s.scale
    local hs = size[short] / 2 * (1 - s.insetShort * 2) * s.scale
    local function at(a, b)
        local p = { x = c.x, y = c.y, z = c.z }
        p[long] = p[long] + a + s.shiftLong
        p[short] = p[short] + b + s.shiftShort
        p[thin] = face
        return vec3(p.x, p.y, p.z)
    end
    local corners = { at(-hl, hs), at(hl, hs), at(hl, -hs), at(-hl, -hs) } -- top-left, top-right, bottom-right, bottom-left
    for _ = 1, (s.rot or 0) % 4 do corners = { corners[4], corners[1], corners[2], corners[3] } end
    if s.mirror then corners = { corners[2], corners[1], corners[4], corners[3] } end
    geo = corners
    return geo
end

local function drawScreen(obj, txn)
    local g = screenGeo()
    local a = GetOffsetFromEntityInWorldCoords(obj, g[1].x, g[1].y, g[1].z)
    local b = GetOffsetFromEntityInWorldCoords(obj, g[2].x, g[2].y, g[2].z)
    local c = GetOffsetFromEntityInWorldCoords(obj, g[3].x, g[3].y, g[3].z)
    local d = GetOffsetFromEntityInWorldCoords(obj, g[4].x, g[4].y, g[4].z)
    local w = T.screen.w
    DrawTexturedPoly(a.x, a.y, a.z, d.x, d.y, d.z, c.x, c.y, c.z, 255, 255, 255, 255, TXD, txn, 0.0, 0.0, w, 0.0, 1.0, w, 1.0, 1.0, w)
    DrawTexturedPoly(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z, 255, 255, 255, 255, TXD, txn, 0.0, 0.0, w, 1.0, 1.0, w, 1.0, 0.0, w)
    if T.screen.both then
        DrawTexturedPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, 255, 255, 255, 255, TXD, txn, 0.0, 0.0, w, 1.0, 1.0, w, 0.0, 1.0, w)
        DrawTexturedPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, TXD, txn, 0.0, 0.0, w, 1.0, 0.0, w, 1.0, 1.0, w)
    end
end

-- ---------------------------------------------------------------------
-- holding the tablet
-- ---------------------------------------------------------------------
-- the hands holding the tablet (upper body only, so it also works while kneeling)
local function playHold()
    if not tablet.open then return end
    if not IsEntityPlayingAnim(cache.ped, T.dict, T.clip, 3) then
        TaskPlayAnim(cache.ped, T.dict, T.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
    end
end

local holding = false -- a tablet is being made right now (only one at a time)

local function deleteProp(obj)
    if not obj or not DoesEntityExist(obj) then return end
    DetachEntity(obj, true, false)
    SetEntityAsMissionEntity(obj, true, true)
    DeleteEntity(obj)
    if DoesEntityExist(obj) then DeleteObject(obj) end
end

-- any tablet left stuck to your hands (two made at once, an old version, a restart) goes away
local function clearHands()
    local ped = cache.ped
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == T.prop and GetEntityAttachedTo(obj) == ped and obj ~= tablet.obj then
            if NetworkGetEntityIsNetworked(obj) and not NetworkHasControlOfEntity(obj) then NetworkRequestControlOfEntity(obj) end
            deleteProp(obj)
        end
    end
end

local function holdTablet()
    if holding or (tablet.obj and DoesEntityExist(tablet.obj)) then return end
    holding = true
    local loaded = pcall(lib.requestModel, T.prop, 5000)
    pcall(lib.requestAnimDict, T.dict, 5000)
    -- loading takes a moment: the tablet may have been closed (or already made) meanwhile
    if not loaded or not tablet.open or (tablet.obj and DoesEntityExist(tablet.obj)) then
        holding = false
        return
    end
    local ped = cache.ped
    local p = GetEntityCoords(ped)
    local obj = CreateObject(T.prop, p.x, p.y, p.z + 0.2, true, true, false)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, T.bone), T.pos.x, T.pos.y, T.pos.z, T.rot.x, T.rot.y, T.rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(T.prop)
    tablet.obj = obj
    holding = false
    playHold()
    -- tell the others which object is my tablet (once the game has made it shared)
    CreateThread(function()
        for _ = 1, 30 do
            Wait(200)
            if tablet.obj ~= obj or not DoesEntityExist(obj) then return end
            if NetworkGetEntityIsNetworked(obj) then
                LocalPlayer.state:set('exti_tablet', ObjToNet(obj), true)
                return
            end
        end
    end)
end

local function putAway()
    LocalPlayer.state:set('exti_tablet', nil, true)
    deleteProp(tablet.obj)
    tablet.obj = nil
    clearHands()
    -- once more a moment later, in case one was still being made
    SetTimeout(1200, function()
        if not tablet.open and not holding then clearHands() end
    end)
    tablet.acting = false
    tablet.kneelFor = nil
    StopAnimTask(cache.ped, T.dict, T.clip, 2.0)
    StopAnimTask(cache.ped, Config.examKneel.dict, Config.examKneel.clip, 2.0)
end

-- ---------------------------------------------------------------------
-- open / close
-- ---------------------------------------------------------------------
local function gameClock()
    return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

local function sendTablet(tab)
    local ok, data = pcall(lib.callback.await, 'exti_ems:server:tablet', false)
    if not ok or not data or not tablet.open then return false end
    local me = GetEntityCoords(cache.ped)
    for _, c in ipairs(data.calls or {}) do
        local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
        c.street = GetStreetNameFromHashKey(s1)
        if s2 ~= 0 then c.street = c.street .. ' / ' .. GetStreetNameFromHashKey(s2) end
        c.distance = math.floor(#(me - vec3(c.x, c.y, c.z)))
    end
    lastClock = gameClock()
    SendNUIMessage({ action = 'tablet', data = data, tab = tab, clock = lastClock })
    return true
end

local stopKneel -- (below)

local function endExam()
    stopKneel()
    if tablet.target and exam() then
        lib.callback('exti_medical:server:close', false, function() end, tablet.target)
    end
    tablet.target = nil
end

local function closeTablet()
    if not tablet.open then return end
    tablet.open = false
    SetNuiFocus(false, false)
    endExam()
    SendNUIMessage({ action = 'examEnd', clear = true })
    SendNUIMessage({ action = 'close' })
    putAway()
end

-- force: opened from a menu that has only just let go of the mouse
local function openTablet(tab, force)
    if tablet.open then
        if tab then sendTablet(tab) end
        return true
    end
    if not EMS.isMedic() or EMS.isDown() or (IsNuiFocused() and not force) then return false end
    tablet.open = true
    ensureScreens()
    SetNuiFocus(true, true)
    if not sendTablet(tab) then
        if tablet.open then
            tablet.open = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
        end
        putAway()
        return false
    end
    if not tablet.open then putAway() return false end -- closed while it was opening
    holdTablet()
    return true
end

RegisterCommand('emstablet', function()
    if tablet.open then closeTablet() else openTablet() end
end, false)
RegisterKeyMapping('emstablet', 'تابلت الإسعاف (EMS)', 'keyboard', Config.tabletKey)

RegisterNetEvent('exti_ems:client:callsChanged', function()
    if tablet.open then sendTablet() end
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    if tablet.open then
        tablet.open = false
        SetNuiFocus(false, false)
        endExam()
        putAway()
    end
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(true)
    sendTablet()
end)

-- ---------------------------------------------------------------------
-- the mirror (what the tablet in your hands shows)
-- ---------------------------------------------------------------------
RegisterNUICallback('mirror', function(data, cb)
    cb(true)
    if type(data) ~= 'table' or type(data.s) ~= 'string' then return end
    lastState = data.s
    sendLive(('{"type":"state","s":%s}'):format(data.s))
end)

RegisterNUICallback('mirrorUi', function(data, cb)
    cb(true)
    if type(data) == 'table' and data.type then sendLive(json.encode(data)) end
end)

-- the clock on the tablet follows the game clock
CreateThread(function()
    while true do
        if tablet.open then
            local t = gameClock()
            if t ~= lastClock then
                lastClock = t
                SendNUIMessage({ action = 'clock', t = t })
                sendLive(json.encode({ type = 'clock', t = t }))
            end
        end
        Wait(1000)
    end
end)

-- ---------------------------------------------------------------------
-- drawing the screens on the tablets
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        local list = {}
        local me = GetEntityCoords(cache.ped)
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= cache.playerId then
                local netId = Player(GetPlayerServerId(player)).state.exti_tablet
                if type(netId) == 'number' and NetworkDoesNetworkIdExist(netId) then
                    local ent = NetToObj(netId)
                    -- only a real tablet, held by that player
                    if ent ~= 0 and DoesEntityExist(ent) and GetEntityModel(ent) == T.prop
                        and GetEntityAttachedTo(ent) == GetPlayerPed(player)
                        and #(GetEntityCoords(ent) - me) < T.othersDistance then
                        list[#list + 1] = ent
                    end
                end
            end
        end
        if #list > 0 then ensureScreens() end
        others = list
        if tablet.open then
            playHold()
            if not tablet.obj or not DoesEntityExist(tablet.obj) then holdTablet() end
        end
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        local drew = false
        if screens and screens.ready.live then
            if tablet.open and tablet.obj and DoesEntityExist(tablet.obj) then
                drawScreen(tablet.obj, 'live')
                drew = true
            end
            for i = 1, #others do
                if DoesEntityExist(others[i]) then
                    drawScreen(others[i], 'locked')
                    drew = true
                end
            end
        end
        Wait(drew and 0 or 250)
    end
end)

-- ---------------------------------------------------------------------
-- the exam (the server does the checking; the tablet just asks)
-- ---------------------------------------------------------------------
-- test patients (NPCs an admin made with /fakepatient): the server marks them 'exti_fake'.
-- They have a negative id instead of a player id. Looked up every 1.5 s, only for medics.
local fakes = {} -- [negative id] = { ped, death }

CreateThread(function()
    while true do
        local found = {}
        if EMS.isMedic() and GetResourceState('exti_medical') == 'started' then
            local pool = GetGamePool('CPed')
            for i = 1, #pool do
                local ped = pool[i]
                if not IsPedAPlayer(ped) and NetworkGetEntityIsNetworked(ped) then
                    local info = Entity(ped).state.exti_fake
                    local id = type(info) == 'table' and tonumber(info.id)
                    if id and id < 0 then found[id] = { ped = ped, death = tonumber(info.death) or 2 } end
                end
            end
        end
        fakes = found
        Wait(1500)
    end
end)

--- the closest test patient within maxDist (id, distance)
function EMS.fakeNear(coords, maxDist)
    local best, bestDist
    for id, f in pairs(fakes) do
        if DoesEntityExist(f.ped) then
            local d = #(coords - GetEntityCoords(f.ped))
            if d <= maxDist and (not bestDist or d < bestDist) then best, bestDist = id, d end
        end
    end
    return best, bestDist
end

local function patientPed(target)
    if target < 0 then
        local f = fakes[target]
        return f and DoesEntityExist(f.ped) and f.ped or 0
    end
    local player = GetPlayerFromServerId(target)
    return player ~= -1 and GetPlayerPed(player) or 0
end

-- 1 awake, 2 down, 3 dead
local function deathState(target)
    if target < 0 then
        local f = fakes[target]
        return f and f.death or 2
    end
    return Player(target).state['qbx_medical:deathState']
end

local function facePatient(target)
    local ped = patientPed(target)
    if ped ~= 0 then TaskTurnPedToFaceEntity(cache.ped, ped, 900) end
end

-- shared with client/treat.lua
EMS.patientPed = patientPed
EMS.deathState = deathState

-- kneel next to a patient who is on the ground, and STAY kneeling (tablet in hand) until the exam
-- ends: closing the exam / the tablet, the patient getting up, or you walking away
-- returns true if you are (or now will be) kneeling
local function startKneel(target)
    if tablet.acting then return tablet.kneelFor == target end
    local state = deathState(target)
    if state ~= 2 and state ~= 3 then return false end
    tablet.acting = true
    tablet.kneelFor = target
    CreateThread(function()
        facePatient(target)
        Wait(600)
        if not tablet.acting or tablet.kneelFor ~= target then return end
        if pcall(lib.requestAnimDict, Config.examKneel.dict, 3000) and tablet.acting and tablet.kneelFor == target then
            TaskPlayAnim(cache.ped, Config.examKneel.dict, Config.examKneel.clip, 3.0, 3.0, -1, 1, 0, false, false, false)
            Wait(100)
            playHold()
        end
    end)
    return true
end

function stopKneel()
    if not tablet.acting then return end
    tablet.acting = false
    tablet.kneelFor = nil
    StopAnimTask(cache.ped, Config.examKneel.dict, Config.examKneel.clip, 2.0)
    SetTimeout(150, playHold)
end

-- get up by yourself when the exam can't go on (patient got up / you moved away / exam closed)
CreateThread(function()
    while true do
        if tablet.acting then
            local t = tablet.kneelFor
            local ped = t and patientPed(t) or 0
            local state = t and deathState(t)
            if not tablet.open or not t or tablet.target ~= t or (state ~= 2 and state ~= 3) or ped == 0
                or #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > 4.0 then
                stopKneel()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

-- ask the server, and never leave the tablet hanging if the answer fails
local function ask(name, ...)
    local ok, a, b = pcall(lib.callback.await, name, false, ...)
    if not ok then return false, 'failed' end
    return a, b
end

function EMS.openExam(target)
    target = tonumber(target)
    if not target then return end
    if not exam() then return EMS.error('failed') end
    if not EMS.onDuty() then return EMS.error('off_duty') end
    Wait(50)
    if not openTablet('exam', true) then return end
    if tablet.target and tablet.target ~= target then endExam() end
    local state = deathState(target)
    if target > 0 and state ~= 2 and state ~= 3 then -- an awake player is asked first (a test patient is not)
        SendNUIMessage({ action = 'examWait', text = 'بانتظار موافقة المريض…' })
    end
    facePatient(target)
    local ok, res = ask('exti_medical:server:open', target)
    if not tablet.open then return end
    if ok then
        tablet.target = target
        SendNUIMessage({ action = 'exam', data = res, focus = true })
        startKneel(target) -- a patient on the ground: kneel now and stay down for the whole exam
    else
        SendNUIMessage({ action = 'examEnd', error = res })
    end
end

RegisterNUICallback('examNearest', function(_, cb)
    cb(true)
    local p = GetEntityCoords(cache.ped)
    local player, ped = lib.getClosestPlayer(p, Config.reach, false)
    local fakeId, fakeDist = EMS.fakeNear(p, Config.reach)
    if fakeId and (not player or fakeDist < #(p - GetEntityCoords(ped))) then
        return EMS.openExam(fakeId)
    end
    if not player then
        SendNUIMessage({ action = 'toast', text = 'لا يوجد أحد قريب منك', type = 'error' })
        return
    end
    EMS.openExam(GetPlayerServerId(player))
end)

RegisterNUICallback('examStep', function(data, cb)
    local target = tablet.target
    if not target or not exam() or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    -- already kneeling: stay down (turning to face him would make you stand up)
    if not startKneel(target) then facePatient(target) end
    local ok, res = false, 'failed'
    if data.kind == 'zone' then
        ok, res = ask('exti_medical:server:zone', target, data.zone)
    elseif data.kind == 'measure' then
        ok, res = ask('exti_medical:server:measure', target, data.tool)
    elseif data.kind == 'ask' then
        ok, res = ask('exti_medical:server:ask', target)
    end
    if ok and tablet.target == target then cb({ ok = true, data = res }) else cb({ ok = false, error = ok and 'not_open' or (res or 'failed') }) end
end)

RegisterNUICallback('examBp', function(data, cb)
    local target = tablet.target
    if not target or not exam() or type(data) ~= 'table' then return cb({ ok = false, error = 'not_open' }) end
    if data.stage == 'start' then
        if not startKneel(target) then facePatient(target) end
        local ok, res = ask('exti_medical:server:bpStart', target)
        cb(ok and { ok = true, data = res } or { ok = false, error = res or 'failed' })
    elseif data.stage == 'finish' then
        local ok, res = ask('exti_medical:server:bpFinish', target, data.token, data.sys, data.dia)
        cb(ok and { ok = true, data = res } or { ok = false, error = res or 'failed' })
    else
        cb({ ok = true })
    end
end)

RegisterNUICallback('examClose', function(_, cb)
    cb(true)
    endExam()
end)

-- "ابدأ العلاج" on the tablet: the tablet goes away and the treatment opens for the same patient
RegisterNUICallback('examTreat', function(_, cb)
    cb(true)
    local target = tablet.target
    if not target or not EMS.openTreatment then return end
    closeTablet()
    Wait(150)
    EMS.openTreatment(target)
end)

EMS.tabletOpen = function() return tablet.open end
EMS.closeTablet = function() if tablet.open then closeTablet() end end

RegisterNetEvent('exti_medical:client:examUpdate', function(target, view)
    if tablet.open and tablet.target == target then
        SendNUIMessage({ action = 'exam', data = view })
    end
end)

-- a test patient was removed while you had it open
RegisterNetEvent('exti_medical:client:examGone', function(target)
    if tablet.target ~= target then return end
    tablet.target = nil
    if tablet.open then SendNUIMessage({ action = 'examEnd', error = 'no_patient', clear = true }) end
    stopKneel()
end)

-- ---------------------------------------------------------------------
-- calls, team, boss (as before)
-- ---------------------------------------------------------------------
local function goTo(x, y, z, label)
    if GetResourceState('exti_gps') == 'started' then
        local ok = pcall(function() exports.exti_gps:GoTo(x, y, z, label) end)
        if ok then return end
    end
    SetNewWaypoint(x, y)
end

RegisterNUICallback('takeCall', function(data, cb)
    local ok, where = lib.callback.await('exti_ems:server:takeCall', false, tonumber(data and data.id))
    cb({ ok = ok and true or false })
    if ok and where then
        goTo(where.x, where.y, where.z, ('بلاغ: %s'):format(where.label))
        EMS.notify('success', where.helping and 'أنت تساعد زميلك في هذا البلاغ: اتبع الخط الذهبي' or 'استلمت البلاغ: اتبع الخط الذهبي')
        closeTablet()
    elseif not ok then
        EMS.error(where)
        sendTablet()
    end
end)

RegisterNUICallback('closeCall', function(data, cb)
    local ok, err = lib.callback.await('exti_ems:server:closeCall', false, tonumber(data and data.id))
    cb({ ok = ok and true or false })
    if not ok then EMS.error(err) end
    sendTablet()
end)

RegisterNUICallback('gps', function(data, cb)
    cb(true)
    local x, y, z = tonumber(data and data.x), tonumber(data and data.y), tonumber(data and data.z)
    if x and y then goTo(x, y, z, data.label) closeTablet() end
end)

RegisterNUICallback('hospitalGps', function(data, cb)
    cb(true)
    local h = Config.hospitals[data and data.hospital or '']
    local c = h and (h.duty or (h.garage and h.garage.coords))
    if c then goTo(c.x, c.y, c.z, h.label) closeTablet() end
end)

RegisterNUICallback('setGrade', function(data, cb)
    local ok, err = lib.callback.await('exti_ems:server:setGrade', false, data and data.citizenid, tonumber(data and data.grade))
    cb({ ok = ok and true or false, error = not ok and (EMS.ERRORS[err] or EMS.ERRORS.failed) or nil })
    if ok then sendTablet() end
end)

RegisterNUICallback('fire', function(data, cb)
    local ok, err = lib.callback.await('exti_ems:server:fire', false, data and data.citizenid)
    cb({ ok = ok and true or false, error = not ok and (EMS.ERRORS[err] or EMS.ERRORS.failed) or nil })
    if ok then sendTablet() end
end)

RegisterNUICallback('quit', function(_, cb)
    local ok = lib.callback.await('exti_ems:server:quit', false)
    cb({ ok = ok and true or false })
    if ok then
        closeTablet()
        EMS.normalClothes()
        EMS.notify('inform', 'تركت العمل في الإسعاف')
    end
end)

-- close the tablet if you go down or stop being a medic
CreateThread(function()
    while true do
        if tablet.open and not tablet.tuning and (EMS.isDown() or not EMS.isMedic()) then closeTablet() end
        Wait(500)
    end
end)

-- ---------------------------------------------------------------------
-- /tablettune: line the live screen up with the tablet in your hands
-- ---------------------------------------------------------------------
local TUNE_HELP = table.concat({
    'ضبط شاشة التابلت',
    '← → / ↑ ↓ : تحريك الشاشة',
    'Shift + الأسهم : حجم الحواف',
    'عجلة الماوس : تكبير / تصغير',
    'PageUp / PageDown : أقرب / أبعد عن الزجاج',
    'R : تدوير · G : قلب · H : الوجه الآخر · Z : تبديل الرسم',
    'Enter : حفظ وطباعة الأرقام · Backspace : خروج',
}, '  \n')

local function printTune()
    local s = T.screen
    local line = ('screen = { face = %d, push = %.4f, insetLong = %.3f, insetShort = %.3f, scale = %.3f, shiftLong = %.4f, shiftShort = %.4f, rot = %d, mirror = %s, w = %.1f, both = true },')
        :format(s.face, s.push, s.insetLong, s.insetShort, s.scale, s.shiftLong, s.shiftShort, s.rot % 4, tostring(s.mirror), s.w)
    print('[exti_ems] ' .. line)
    TriggerEvent('chat:addMessage', { args = { 'EMS', line } })
    EMS.notify('success', 'الأرقام في F8 والشات: أرسلها لي')
end

RegisterCommand('tablettune', function()
    if not tablet.open then return EMS.notify('error', 'افتح التابلت أولًا (F6)') end
    if tablet.tuning then return end
    tablet.tuning = true
    SetNuiFocus(false, false)
    lib.showTextUI(TUNE_HELP)
    CreateThread(function()
        local s = T.screen
        while tablet.tuning and tablet.open do
            for _, c in ipairs({ 172, 173, 174, 175, 10, 11, 14, 15, 45, 47, 74, 20, 191, 194, 177, 21, 241, 242 }) do DisableControlAction(0, c, true) end
            local shift = IsDisabledControlPressed(0, 21)
            local changed = false
            local function hit(c) return IsDisabledControlJustPressed(0, c) end
            if hit(174) then if shift then s.insetLong = s.insetLong + 0.005 else s.shiftLong = s.shiftLong - 0.002 end changed = true end
            if hit(175) then if shift then s.insetLong = s.insetLong - 0.005 else s.shiftLong = s.shiftLong + 0.002 end changed = true end
            if hit(172) then if shift then s.insetShort = s.insetShort - 0.005 else s.shiftShort = s.shiftShort + 0.002 end changed = true end
            if hit(173) then if shift then s.insetShort = s.insetShort + 0.005 else s.shiftShort = s.shiftShort - 0.002 end changed = true end
            if hit(10) then s.push = s.push + 0.0005 changed = true end
            if hit(11) then s.push = s.push - 0.0005 changed = true end
            if hit(241) or hit(14) then s.scale = s.scale + 0.01 changed = true end
            if hit(242) or hit(15) then s.scale = math.max(0.3, s.scale - 0.01) changed = true end
            if hit(45) then s.rot = (s.rot + 1) % 4 changed = true end
            if hit(47) then s.mirror = not s.mirror changed = true end
            if hit(74) then s.face = -s.face changed = true end
            if hit(20) then s.w = s.w > 0.5 and 0.0 or 1.0 changed = true end
            if changed then geo = nil end
            if hit(191) then printTune() break end
            if hit(194) or hit(177) then break end
            Wait(0)
        end
        tablet.tuning = false
        lib.hideTextUI()
        if tablet.open then SetNuiFocus(true, true) end
    end)
end, false)

-- ---------------------------------------------------------------------
CreateThread(function()
    Wait(1500)
    if not tablet.open then clearHands() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RES then return end
    if tablet.open then SetNuiFocus(false, false) end
    putAway()
    if screens then
        DestroyDui(screens.live)
        DestroyDui(screens.locked)
        screens = nil
    end
end)
