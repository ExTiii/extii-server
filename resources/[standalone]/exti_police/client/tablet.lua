-- =====================================================================
-- EX_Tii Police (client): the police tablet (like the video, the same way as the EMS tablet).
-- F6 on duty: your character takes the tablet out and holds it with both hands. The screen you
-- use is also painted, live, on the tablet in your hands (a second copy of the page, ?mirror=1).
-- Other players see a locked police screen on your tablet, never what you are looking at.
-- The apps ask the server through one door ('call'), and only for the names listed below.
-- =====================================================================

local T = Config.tablet
local RES = GetCurrentResourceName()
local TXD = 'exti_police_tablet'
local STATE = 'exti_police_tablet'

local tablet = { open = false, obj = nil, tuning = false, camera = false }
local screens = nil      -- { live = dui, locked = dui, ready = { live = bool, locked = bool } }
local lastState = nil    -- the last full screen (sent again when the mirror page finishes loading)
local lastClock = ''
local geo = nil          -- the 4 corners of the screen on the tablet model
local others = {}        -- other officers' tablets near you

-- ---------------------------------------------------------------------
-- the two screen pages (made once, the first time they are needed)
-- ---------------------------------------------------------------------
local function sendLive(text)
    if screens and screens.ready.live then SendDuiMessage(screens.live, text) end
end

local function ensureScreens()
    if screens then return end
    local txd = CreateRuntimeTxd(TXD)
    local live = CreateDui(('nui://%s/html/tablet.html?mirror=1'):format(RES), T.screenW, T.screenH)
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
-- where the screen sits on the tablet model (tune it in game: /policetablettune)
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
local function playHold()
    if not tablet.open or tablet.camera then return end
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
-- (only police officers: the EMS tablet uses the same model and looks after its own)
local function clearHands()
    if not POL.isCop() then return end
    local ped = cache.ped
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == T.prop and GetEntityAttachedTo(obj) == ped and obj ~= tablet.obj then
            if NetworkGetEntityIsNetworked(obj) and not NetworkHasControlOfEntity(obj) then NetworkRequestControlOfEntity(obj) end
            deleteProp(obj)
        end
    end
end

local function holdTablet()
    if holding or tablet.camera or (tablet.obj and DoesEntityExist(tablet.obj)) then return end
    holding = true
    local loaded = pcall(lib.requestModel, T.prop, 5000)
    pcall(lib.requestAnimDict, T.dict, 5000)
    -- loading takes a moment: the tablet may have been closed (or already made) meanwhile
    if not loaded or not tablet.open or tablet.camera or (tablet.obj and DoesEntityExist(tablet.obj)) then
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
                LocalPlayer.state:set(STATE, ObjToNet(obj), true)
                return
            end
        end
    end)
end

local function putAway()
    LocalPlayer.state:set(STATE, nil, true)
    deleteProp(tablet.obj)
    tablet.obj = nil
    clearHands()
    -- once more a moment later, in case one was still being made
    SetTimeout(1200, function()
        if not tablet.open and not holding then clearHands() end
    end)
    StopAnimTask(cache.ped, T.dict, T.clip, 2.0)
end

-- ---------------------------------------------------------------------
-- open / close
-- ---------------------------------------------------------------------
local function gameClock()
    return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

-- what the page needs from the config (colours, limits)
local stations = {}
for _, st in pairs(Config.stations) do
    local c = st.duty or (st.garage and st.garage.coords)
    if c then stations[#stations + 1] = { label = st.label, x = c.x, y = c.y } end
end

local function pageConfig()
    return {
        stations = stations,
        colors = Config.calendarColors, bonusMax = Config.bonusMax, salaryMax = Config.salaryMax,
        maxText = Config.chat and Config.chat.maxText or 500,
    }
end

local function closeTablet()
    if not tablet.open then return end
    tablet.open = false
    tablet.camera = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'ptablet:close' })
    lib.hideTextUI()
    putAway()
end

local opening = false

local function openTablet()
    if tablet.open or opening then return true end
    if not POL.isCop() or POL.isDown() or IsNuiFocused() or IsPauseMenuActive() then return false end
    if not POL.onDuty() then POL.error('off_duty') return false end
    -- ask the server first; the mouse is only taken once the screen is ready to show
    opening = true
    ensureScreens()
    local ok, data, err = pcall(lib.callback.await, 'exti_police:server:tab_open', false)
    opening = false
    if not ok or not data then
        if ok and err and err ~= 'wait' then POL.error(err) end
        return false
    end
    if tablet.open or POL.isDown() or not POL.onDuty() or IsNuiFocused() or IsPauseMenuActive() then return false end
    tablet.open = true
    SetNuiFocus(true, true)
    lastClock = gameClock()
    SendNUIMessage({ action = 'ptablet:open', data = data, cfg = pageConfig(), clock = lastClock })
    holdTablet()
    return true
end

RegisterCommand('policetablet', function()
    if tablet.camera then return end
    if tablet.open then closeTablet() else openTablet() end
end, false)
RegisterNetEvent('exti_police:client:tablet', function()
    if tablet.camera or tablet.open then return end
    openTablet()
end)
RegisterKeyMapping('policetablet', 'تابلت الشرطة (Police)', 'keyboard', Config.tabletKey)

RegisterNUICallback('ptClose', function(_, cb)
    cb(true)
    if tablet.open then
        tablet.open = false
        tablet.camera = false
        SetNuiFocus(false, false)
        putAway()
    end
end)

-- ---------------------------------------------------------------------
-- the one door to the server: only these apps' callbacks
-- ---------------------------------------------------------------------
local ALLOWED = {}
for _, name in ipairs({
    'badges', 'settingsSave', 'mapUnits', 'calls', 'callTake', 'callClose', 'cctv', 'gallery', 'galleryDelete',
    'chats', 'chatDirectory', 'chatOpen', 'chatSend', 'chatStart', 'chatGroup', 'chatLeave',
    'calendar', 'calendarAdd', 'calendarDelete',
    'formsList', 'formGet', 'formAction',
    'offences', 'offenceSave', 'offenceDelete', 'prisonList', 'prisonRelease', 'prisonLocker',
    'citizenSearch', 'citizenGet', 'citizenNote', 'citizenNoteDelete', 'licenceSet', 'vehicleSearch',
    'reports', 'reportGet', 'reportSave', 'reportDelete', 'warrants', 'warrantAdd', 'warrantClose',
    'bolos', 'boloAdd', 'boloClose', 'cases', 'caseGet', 'caseSave', 'caseItem', 'caseItemDelete', 'caseDelete',
    'bossDashboard', 'bossCashFlow', 'bossFunds', 'bossDeposit', 'bossWithdraw', 'bossMembers',
    'bossSetGrade', 'bossFire', 'bossBonus', 'bossNearby', 'bossInvite', 'bossRoles', 'bossRoleSave', 'bossLogs',
}) do ALLOWED[name] = true end

RegisterNUICallback('ptCall', function(data, cb)
    if not tablet.open or type(data) ~= 'table' or not ALLOWED[data.fn] then return cb({ ok = false, e = 'failed' }) end
    local a = type(data.args) == 'table' and data.args or {}
    local ok, res, err = pcall(lib.callback.await, 'exti_police:server:tab_' .. data.fn, false, a[1], a[2], a[3], a[4])
    if not ok then return cb({ ok = false, e = 'failed' }) end
    if res == nil or res == false then return cb({ ok = false, e = err or 'failed' }) end
    cb({ ok = true, r = res })
end)

-- ---------------------------------------------------------------------
-- the mirror (what the tablet in your hands shows)
-- ---------------------------------------------------------------------
RegisterNUICallback('ptMirror', function(data, cb)
    cb(true)
    if type(data) ~= 'table' or type(data.s) ~= 'string' then return end
    lastState = data.s
    sendLive(('{"type":"state","s":%s}'):format(data.s))
end)

RegisterNUICallback('ptMirrorUi', function(data, cb)
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
                SendNUIMessage({ action = 'ptablet:clock', t = t })
                sendLive(json.encode({ type = 'clock', t = t }))
            end
        end
        Wait(1000)
    end
end)

-- ---------------------------------------------------------------------
-- map: a waypoint to an officer / a vehicle
-- ---------------------------------------------------------------------
RegisterNUICallback('ptWaypoint', function(data, cb)
    cb(true)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if not x or not y then return end
    local label = type(data.label) == 'string' and data.label:sub(1, 60) or 'الشرطة'
    if GetResourceState('exti_gps') == 'started' then
        local ok = pcall(function() exports.exti_gps:GoTo(x, y, 0.0, label) end)
        if ok then return POL.notify('success', 'تم تحديد الوجهة على الخريطة') end
    end
    SetNewWaypoint(x, y)
    POL.notify('success', 'تم تحديد الوجهة على الخريطة')
end)

-- ---------------------------------------------------------------------
-- the camera app: the tablet goes down, you aim with the game camera, E / left click takes the
-- photo (uploaded to the same picture host as the phone), Backspace goes back to the tablet
-- ---------------------------------------------------------------------
local CAMERA_HELP = 'الكاميرا  \nE أو زر الماوس الأيسر: التصوير  \nBackspace: رجوع للتابلت'

local function backFromCamera(result)
    if not tablet.camera then return end
    tablet.camera = false
    lib.hideTextUI()
    if not tablet.open then return end
    SendNUIMessage({ action = 'ptablet:cameraDone', result = result })
    SetNuiFocus(true, true)
    holdTablet()
end

local CAMERA_ERRORS = {
    no_camera = 'الكاميرا غير متاحة الآن (السيرفر ليس له عنوان عام بعد)',
    wait = 'انتظر لحظة قبل الصورة التالية',
    upload = 'تعذّر حفظ الصورة، حاول مرة أخرى',
}

RegisterNUICallback('ptCamera', function(_, cb)
    cb(true)
    if not tablet.open or tablet.camera then return end
    tablet.camera = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'ptablet:hide' })
    LocalPlayer.state:set(STATE, nil, true)
    deleteProp(tablet.obj)
    tablet.obj = nil
    StopAnimTask(cache.ped, T.dict, T.clip, 2.0)
    lib.showTextUI(CAMERA_HELP)
    local shooting = false
    local function shoot()
        shooting = true
        lib.hideTextUI()
        Wait(250) -- the help box is gone from the picture
        if not tablet.camera then shooting = false return end
        PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
        local ok, res, err = pcall(lib.callback.await, 'exti_police:server:tab_snap', false)
        shooting = false
        if not tablet.camera then return end
        if ok and res then
            POL.notify('success', 'حُفظت الصورة في المعرض')
            backFromCamera(res)
            return
        end
        local code = ok and err or 'failed'
        POL.notify('error', CAMERA_ERRORS[code] or POL.ERRORS[code] or POL.ERRORS.failed)
        lib.showTextUI(CAMERA_HELP)
    end
    CreateThread(function()
        while tablet.camera and tablet.open do
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 24, true)   -- shooting
            DisableControlAction(0, 25, true)   -- aiming
            DisableControlAction(0, 140, true)  -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 200, true)  -- the pause menu (Esc)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 177, true)  -- Backspace
            DisableControlAction(0, 38, true)   -- E
            if not shooting then
                if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                    backFromCamera(nil)
                    break
                end
                if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 38) then
                    CreateThread(shoot)
                end
            end
            Wait(0)
        end
        if tablet.camera then backFromCamera(nil) end
    end)
end)

-- an inmate's locker from the Prison app: the tablet closes, the stash opens
RegisterNUICallback('ptPrisonLocker', function(data, cb)
    cb(true)
    local cid = type(data) == 'table' and data.cid or nil
    if not tablet.open or type(cid) ~= 'string' then return end
    closeTablet()
    SetTimeout(300, function()
        local ok, err = lib.callback.await('exti_police:server:tab_prisonLocker', false, cid)
        if not ok then POL.error(err) end
    end)
end)

-- the CCTV: the tablet goes away while you look through a camera (client/cctv.lua)
RegisterNUICallback('ptCctv', function(data, cb)
    cb(true)
    if not tablet.open or tablet.camera or not POL.cctvView then return end
    local index = math.tointeger(tonumber(data and data.index))
    if not index then return end
    tablet.camera = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'ptablet:hide' })
    LocalPlayer.state:set(STATE, nil, true)
    deleteProp(tablet.obj)
    tablet.obj = nil
    StopAnimTask(cache.ped, T.dict, T.clip, 2.0)
    CreateThread(function()
        POL.cctvView(index)
        if not tablet.camera then return end
        tablet.camera = false
        if not tablet.open then return end
        SendNUIMessage({ action = 'ptablet:cctvDone' })
        SetNuiFocus(true, true)
        holdTablet()
    end)
end)

-- ---------------------------------------------------------------------
-- chat: a new message / someone read yours (the page asks the server again)
-- ---------------------------------------------------------------------
local myCid = function() return QBX and QBX.PlayerData and QBX.PlayerData.citizenid end

RegisterNetEvent('exti_police:client:chatMessage', function(chatId, name, text, fromCid)
    if not POL.onDuty() then return end
    if tablet.open and not tablet.camera then
        SendNUIMessage({ action = 'ptablet:chat', chatId = chatId, from = fromCid })
    end
    if fromCid ~= myCid() and (not tablet.open or tablet.camera) then
        local function plain(v) return (type(v) == 'string' and v or ''):gsub('[%[%]%(%)!#%*_`<>|~\\]', '') end
        local who = plain(name)
        local what = plain(text)
        lib.notify({ title = ('رسالة من %s'):format(who), description = what, type = 'inform', icon = 'comments' })
    end
end)

RegisterNetEvent('exti_police:client:chatRead', function(chatId)
    if tablet.open and not tablet.camera then SendNUIMessage({ action = 'ptablet:chatRead', chatId = chatId }) end
end)

-- ---------------------------------------------------------------------
-- hiring: the police leader invited you
-- ---------------------------------------------------------------------
local asking = false
RegisterNetEvent('exti_police:client:invite', function(bossName, rankName)
    if asking then return end
    asking = true
    local answer = lib.alertDialog({
        header = 'دعوة للانضمام إلى الشرطة',
        content = ('%s يدعوك للانضمام إلى شرطة لوس سانتوس برتبة **%s**.  \nهل تقبل؟'):format((tostring(bossName or ''):gsub('[%[%]%(%)!#%*_`<>|~\\]', '')), (tostring(rankName or ''):gsub('[%[%]%(%)!#%*_`<>|~\\]', ''))),
        centered = true,
        cancel = true,
        labels = { confirm = 'أقبل', cancel = 'لا' },
    })
    asking = false
    lib.callback('exti_police:server:inviteAnswer', false, function() end, answer == 'confirm')
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
                local netId = Player(GetPlayerServerId(player)).state[STATE]
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
        if tablet.open and not tablet.camera then
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
            if tablet.open and not tablet.camera and tablet.obj and DoesEntityExist(tablet.obj) then
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

-- close the tablet if you go down, go off duty or stop being an officer
CreateThread(function()
    while true do
        if tablet.open and not tablet.tuning and (POL.isDown() or not POL.onDuty()) then closeTablet() end
        Wait(500)
    end
end)

-- ---------------------------------------------------------------------
-- /policetablettune: line the live screen up with the tablet in your hands
-- ---------------------------------------------------------------------
local TUNE_HELP = table.concat({
    'ضبط شاشة تابلت الشرطة',
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
    print('[exti_police] ' .. line)
    TriggerEvent('chat:addMessage', { args = { 'Police', line } })
    POL.notify('success', 'الأرقام في F8 والشات: أرسلها لي')
end

RegisterCommand('policetablettune', function()
    if not tablet.open or tablet.camera then return POL.notify('error', 'افتح التابلت أولًا (F6)') end
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
POL.tabletOpen = function() return tablet.open end
POL.closeTablet = function() if tablet.open then closeTablet() end end

CreateThread(function()
    Wait(1500)
    if not tablet.open then clearHands() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RES then return end
    if tablet.open then SetNuiFocus(false, false) end
    if tablet.camera then lib.hideTextUI() end
    putAway()
    if screens then
        DestroyDui(screens.live)
        DestroyDui(screens.locked)
        screens = nil
    end
end)
