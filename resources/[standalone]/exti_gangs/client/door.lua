-- =====================================================================
-- EX_Tii gangs (game side): the HQ front door. client/main.lua shows the [E] prompts and calls these.
-- =====================================================================
local D = C.door

local function isCop()
    local j = QBX and QBX.PlayerData and QBX.PlayerData.job
    return j ~= nil and j.name == 'police' and j.onduty == true
end
GC.isCop = isCop

local function teleport(p)
    DoScreenFadeOut(350)
    local t = GetGameTimer()
    while not IsScreenFadedOut() and GetGameTimer() - t < 2000 do Wait(10) end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoords(ped, p.x, p.y, p.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, p.h or 0.0)
    t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 3000 do Wait(0) end
    Wait(250)
    DoScreenFadeIn(350)
end
GC.teleport = teleport
RegisterNetEvent('exti_gangs:client:doorTeleport', function(p) if type(p) == 'table' and p.x then teleport(p) end end)

local ERR = {
    nodoor = 'الباب لم يُضبط بعد', far = 'اقترب من الباب', notmember = 'الباب مقفل', member = 'أنت من العصابة: ادخل',
    soon = 'انتظر قليلًا قبل أن تطرق من جديد', nobody = 'لا أحد يفتح... لا يوجد أحد في الداخل', notcop = 'للشرطة فقط',
}
local function fail(why) GC.notify(ERR[why] or 'لم ينجح', 'error') end

local function enter(name)
    local ok, to = lib.callback.await('exti_gangs:server:door', false, name, 'enter')
    if not ok then return fail(to) end
    PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_PLAYER_APARTMENT', false)
    teleport(to)
end

local function knock(name)
    lib.requestAnimDict('timetable@jimmy@doorknock@')
    TaskPlayAnim(PlayerPedId(), 'timetable@jimmy@doorknock@', 'knockdoor_idle', 3.0, 3.0, 2500, 48, 0, false, false, false)
    local ok, why = lib.callback.await('exti_gangs:server:door', false, name, 'knock')
    if not ok then Wait(1500); return fail(why) end
    GC.notify('طرقت الباب... انتظر أن يفتح لك أحد', 'inform')
end

local function breach(name)
    local ok, res = lib.callback.await('exti_gangs:server:door', false, name, 'breachBegin')
    if not ok then return fail(res) end
    if res.open then return teleport(res.to) end
    local done = lib.progressBar({
        duration = res.seconds * 1000, label = 'تكسر الباب...', canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot', flag = 1 },
    })
    ClearPedTasks(PlayerPedId())
    if not done then return GC.notify('أُلغيت', 'error') end
    local fin, to = lib.callback.await('exti_gangs:server:door', false, name, 'breachFinish')
    if not fin then return fail() end
    PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', false)
    teleport(to)
end

-- [E] at the door outside
function GC.doorOut(name)
    local my = GC.my()
    if my and my.name == name then return enter(name) end
    local opts = { { title = 'اطرق الباب', description = 'أحد في الداخل قد يفتح لك', icon = 'hand', onSelect = function() knock(name) end } }
    if isCop() then
        opts[#opts + 1] = { title = 'اقتحم الباب (شرطة)', description = ('%d ثوانٍ · العصابة تعرف فورًا'):format(D.breachSeconds), icon = 'shield-halved',
                            onSelect = function() breach(name) end }
    end
    lib.registerContext({ id = 'exti_gang_door', title = 'باب', options = opts })
    lib.showContext('exti_gang_door')
end

-- [E] at the door inside
function GC.doorIn(name)
    local ok, to = lib.callback.await('exti_gangs:server:door', false, name, 'exit')
    if not ok then return fail(to) end
    teleport(to)
end

-- a member inside: someone knocks
RegisterNetEvent('exti_gangs:client:knock', function(id, label)
    PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_PLAYER_APARTMENT', false)
    GC.prompt({ title = 'أحدهم يطرق الباب', text = ('أحد عند باب مقر %s. تفتح له؟'):format(label), color = '#20c997', tag = '?',
                yes = 'افتح', no = 'تجاهل', timeout = 20 },
        function(yes) if yes == true then TriggerServerEvent('exti_gangs:server:knockAnswer', id, true) end end)
end)

---------------------------------------------------------------------------
-- real doors: the game's door system keeps them shut (like the police armory doors)
---------------------------------------------------------------------------
local registered = {}   -- [gang:i] = { hash, x, y, z }

local function applyDoors()
    local sp = GC.spots() or {}
    local locks = GlobalState['exti_gangs:locks'] or {}
    local want = {}
    for name, set in pairs(sp.hq or {}) do
        for i, d in ipairs(set.doors or {}) do
            local key = name .. ':' .. i
            want[key] = true
            local r = registered[key]
            if not r or r.x ~= d.x or r.y ~= d.y or r.z ~= d.z or r.model ~= d.model then
                if r and IsDoorRegisteredWithSystem(r.hash) then RemoveDoorFromSystem(r.hash) end
                local hash = joaat('exti_gang_door_' .. key)
                if IsDoorRegisteredWithSystem(hash) then RemoveDoorFromSystem(hash) end
                AddDoorToSystem(hash, d.model, d.x, d.y, d.z, false, false, false)
                r = { hash = hash, x = d.x, y = d.y, z = d.z, model = d.model }
                registered[key] = r
            end
            local open = locks[name] ~= nil and locks[name][i] == false
            DoorSystemSetDoorState(r.hash, open and 0 or 1, false, true)
            if not open then DoorSystemSetOpenRatio(r.hash, 0.0, false, true) end
        end
    end
    for key, r in pairs(registered) do
        if not want[key] then
            if IsDoorRegisteredWithSystem(r.hash) then DoorSystemSetDoorState(r.hash, 0, false, true); RemoveDoorFromSystem(r.hash) end
            registered[key] = nil
        end
    end
end
GC.applyDoors = applyDoors

AddStateBagChangeHandler('exti_gangs:locks', 'global', function() SetTimeout(0, applyDoors) end)
CreateThread(function()
    Wait(2500)
    while true do
        applyDoors()   -- the door may stream in later: apply again now and then
        Wait(5000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(registered) do
        if IsDoorRegisteredWithSystem(r.hash) then DoorSystemSetDoorState(r.hash, 0, false, true); RemoveDoorFromSystem(r.hash) end
    end
end)

function GC.realDoorOpen(name, i)
    local locks = GlobalState['exti_gangs:locks'] or {}
    return locks[name] ~= nil and locks[name][i] == false
end

local RERR = { open = 'الباب مفتوح', notmember = 'الباب مقفل', member = 'أنت من العصابة: افتحه' }
local function rfail(why) GC.notify(RERR[why] or ERR[why] or 'لم ينجح', 'error') end

local function realBreach(name, i)
    local ok, res = lib.callback.await('exti_gangs:server:realDoor', false, name, i, 'breachBegin')
    if not ok then return rfail(res) end
    local done = lib.progressBar({
        duration = res.seconds * 1000, label = 'تكسر الباب...', canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot', flag = 1 },
    })
    ClearPedTasks(PlayerPedId())
    if not done then return GC.notify('أُلغيت', 'error') end
    local fin = lib.callback.await('exti_gangs:server:realDoor', false, name, i, 'breachFinish')
    if fin then GC.notify('كسرت الباب: مفتوح للشرطة 10 دقائق', 'success') else rfail() end
end

-- [E] at a real door
function GC.realDoor(name, i)
    local my = GC.my()
    if my and my.name == name then
        local ok, open = lib.callback.await('exti_gangs:server:realDoor', false, name, i, 'toggle')
        if not ok then return rfail(open) end
        PlaySoundFrontend(-1, open and 'DOOR_BUZZ' or 'CONFIRM_BEEP', open and 'MP_PLAYER_APARTMENT' or 'HUD_MINI_GAME_SOUNDSET', false)
        return GC.notify(open and ('فتحت الباب (يقفل وحده بعد %d ثوانٍ)'):format(C.realDoor.autoLock) or 'قفلت الباب', 'success')
    end
    local opts = { { title = 'اطرق الباب', description = 'أحد من العصابة قريب قد يفتح لك', icon = 'hand', onSelect = function()
        lib.requestAnimDict('timetable@jimmy@doorknock@')
        TaskPlayAnim(PlayerPedId(), 'timetable@jimmy@doorknock@', 'knockdoor_idle', 3.0, 3.0, 2500, 48, 0, false, false, false)
        local ok, why = lib.callback.await('exti_gangs:server:realDoor', false, name, i, 'knock')
        if not ok then Wait(1500); return rfail(why) end
        GC.notify('طرقت الباب... انتظر أن يفتح لك أحد', 'inform')
    end } }
    if isCop() then
        opts[#opts + 1] = { title = 'اقتحم الباب (شرطة)', description = ('%d ثوانٍ · العصابة تعرف فورًا'):format(D.breachSeconds), icon = 'shield-halved',
                            onSelect = function() realBreach(name, i) end }
    end
    lib.registerContext({ id = 'exti_gang_rdoor', title = 'باب مقفل', options = opts })
    lib.showContext('exti_gang_rdoor')
end

-- admins (/gangspots): look at the door, pick "add this door"
function GC.aimDoor()
    local hit, entity = lib.raycast.cam(16, 4, 6.0)
    if not hit or not entity or entity == 0 or GetEntityType(entity) ~= 3 then return nil end
    local c = GetEntityCoords(entity)
    return GetEntityModel(entity), { x = c.x, y = c.y, z = c.z }
end
