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
    GC.prompt({ title = 'أحدهم يطرق الباب', text = ('أحد عند باب مقر %s. تفتح له؟'):format(label), color = '#e8b547', tag = '?',
                yes = 'افتح', no = 'تجاهل', timeout = 20 },
        function(yes) if yes == true then TriggerServerEvent('exti_gangs:server:knockAnswer', id, true) end end)
end)
