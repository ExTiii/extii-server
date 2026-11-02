-- =====================================================================
-- EX_Tii EMS (client): the E spots in the hospitals (clock in terminal, cloakroom, storage,
-- personal locker, supply cabinet, garage, helicopter, lift), looking after a patient, the tablet.
-- =====================================================================

EMS = EMS or {}
local JOB = Config.job

local function job()
    return QBX and QBX.PlayerData and QBX.PlayerData.job
end

function EMS.isMedic()
    local j = job()
    return j and j.name == JOB
end

function EMS.onDuty()
    local j = job()
    return j and j.name == JOB and j.onduty == true
end

function EMS.isDown(ped)
    if not ped or ped == cache.ped then
        local state = LocalPlayer.state['qbx_medical:deathState']
        return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped)
    end
    return IsEntityDead(ped)
end

function EMS.notify(kind, text)
    lib.notify({ type = kind, description = text })
end

EMS.ERRORS = {
    not_boss = 'هذا لقائد الإسعاف فقط',
    gone = 'لم يعد هذا الطلب موجودًا',
    already = 'هو مسعف بالفعل',
    busy_job = 'يعمل في وظيفة فريق أخرى، يجب أن يتركها أولًا',
    off_duty = 'ابدأ مناوبتك في المستشفى أولًا',
    too_far = 'اقترب أكثر',
    failed = 'حدث خطأ، حاول مرة أخرى',
    no_item = 'لا تملك الأداة اللازمة، خذها من خزانة المستلزمات',
    not_down = 'المريض ليس على الأرض',
    is_down = 'المريض على الأرض: أنعشه أولًا',
    healthy = 'المريض بصحة كاملة',
    has_one = 'معك مركبة إسعاف بالفعل، أعدها أولًا',
    none = 'لا توجد مركبة لك',
    loaded = 'في السيارة نقالة، أنزلها أولًا',
    gone = 'لم يعد هذا موجودًا',
    taken = 'زميلك يدفعها الآن',
    full = 'عليها مريض بالفعل',
    no_patient = 'لا يوجد مريض قريب',
    in_vehicle = 'المريض داخل مركبة',
    down_wheelchair = 'المصاب على الأرض يحتاج نقالة، لا كرسيًا',
    already = 'هذا المريض على نقالة أو كرسي بالفعل',
    has_patient = 'أنزل المريض أولًا',
    not_boss = 'هذا لقائد الإسعاف فقط',
    rank = 'لا يمكنك تغيير رتبة من هو بمستواك أو أعلى',
    not_yours = 'هذا البلاغ استلمه زميلك',
    spot = 'مكان المركبة مشغول، أبعد المركبة الموجودة أولًا',
    vehicle_out = 'هذه المركبة خارج المرآب الآن',
    not_fleet = 'هذه ليست من مركبات الإسعاف',
    driver = 'اجلس مكان السائق أولًا',
    passengers = 'أنزل من في المركبة أولًا',
    fleet_full = 'وصل الفريق للحد الأقصى من المركبات',
    no_money = 'رصيد حساب الإسعاف في البنك لا يكفي',
    trunk_full = 'أفرغ صندوق المركبة قبل بيعها',
    storage_rank = 'المخزن للرتب الأعلى فقط',
}

function EMS.error(code)
    EMS.notify('error', EMS.ERRORS[code] or EMS.ERRORS.failed)
end

---------------------------------------------------------------------------
-- "[E] ..." line
---------------------------------------------------------------------------
local shownText
function EMS.prompt(text)
    -- another script (e.g. the hospital beds) may have hidden it: show it again
    if shownText == text and (not text or lib.isTextUIOpen()) then return end
    shownText = text
    if text then lib.showTextUI(text) else lib.hideTextUI() end
end

---------------------------------------------------------------------------
-- the spots
---------------------------------------------------------------------------
local spots = {}
local function buildSpots()
    local list = {}
    for name, h in pairs(Config.hospitals) do
        for _, kind in ipairs({ 'duty', 'cloakroom', 'storage', 'locker' }) do
            if h[kind] then list[#list + 1] = { hospital = name, kind = kind, coords = h[kind] } end
        end
        if h.supply then list[#list + 1] = { hospital = name, kind = 'supply', coords = h.supply.coords, shopId = h.supply.shopId } end
        if h.garage then list[#list + 1] = { hospital = name, kind = 'garage', coords = h.garage.coords } end
        if h.heli then list[#list + 1] = { hospital = name, kind = 'heli', coords = h.heli.coords } end
        for i, floor in ipairs(h.lift or {}) do
            list[#list + 1] = { hospital = name, kind = 'lift', coords = floor.coords.xyz, floor = i }
        end
    end
    spots = list
end
-- spots moved in game by an admin (/emsspots) come from the server
EMS.applySpots(GlobalState.exti_ems_spots)
buildSpots()
AddStateBagChangeHandler('exti_ems_spots', 'global', function(_, _, value)
    EMS.applySpots(value)
    buildSpots()
end)

-- in your ambulance / helicopter you can return it from a bit further away
local function reachOf(spot)
    if cache.vehicle and (spot.kind == 'garage' or spot.kind == 'heli') then return Config.vehicleReach or Config.reachPoint end
    return Config.reachPoint
end

---------------------------------------------------------------------------
-- the small white circles on the floor (only medics see them)
---------------------------------------------------------------------------
do
    local circle = Config.circle or {}
    local SIZE = circle.size or 1.0
    local COLOR = circle.color or { 255, 255, 255 }
    local DISTANCE = circle.distance or 20.0
    local near = {} -- spots close enough to draw, refreshed twice a second

    -- the floor under a spot (kept once found; until then a guess)
    local function floorOf(spot)
        if spot.floorZ then return spot.floorZ end
        local c = spot.coords
        RequestCollisionAtCoord(c.x, c.y, c.z)
        for _, up in ipairs({ 0.5, 1.5 }) do
            local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + up, false)
            if found and math.abs(gz - c.z) < 4.0 then
                spot.floorZ = gz
                return gz
            end
        end
        return c.z - 0.98
    end

    CreateThread(function()
        while true do
            local list = {}
            if EMS.isMedic() and not EMS.isDown() then
                local p = GetEntityCoords(cache.ped)
                for i = 1, #spots do
                    local s = spots[i]
                    if #(p - s.coords) < DISTANCE then
                        s.drawZ = floorOf(s) + 0.03
                        list[#list + 1] = s
                    end
                end
            end
            near = list
            Wait(500)
        end
    end)

    CreateThread(function()
        while true do
            if #near == 0 then
                Wait(500)
            else
                local p = GetEntityCoords(cache.ped)
                local r, g, b = COLOR[1], COLOR[2], COLOR[3]
                for i = 1, #near do
                    local s = near[i]
                    if s.drawZ and (not cache.vehicle or s.kind == 'garage' or s.kind == 'heli') then
                        local here = #(p - s.coords) < reachOf(s)
                        local size = here and SIZE * 1.08 or SIZE
                        local alpha = here and 210 or 140
                        DrawMarker(1, s.coords.x, s.coords.y, s.drawZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.3,
                            r, g, b, alpha, false, false, 2, false, nil, nil, false)
                        DrawMarker(1, s.coords.x, s.coords.y, s.drawZ - 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size * 0.96, size * 0.96, 0.02,
                            r, g, b, math.floor(alpha * 0.25), false, false, 2, false, nil, nil, false)
                    end
                end
                Wait(0)
            end
        end
    end)
end

local function normalClothes()
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end
EMS.normalClothes = normalClothes

local function openSupply(spot)
    local ok = pcall(function()
        exports.ox_inventory:openInventory('shop', { type = 'AmbulanceArmory', id = spot.shopId })
    end)
    if not ok then EMS.error('failed') end
end

local function openStash(spot)
    local ok, err = lib.callback.await('exti_ems:server:openStash', false, spot.hospital, spot.kind)
    if not ok then
        if err == 'storage_rank' then
            local okJob, jobData = pcall(function() return exports.qbx_core:GetJob(JOB) end)
            local g = okJob and jobData and jobData.grades and jobData.grades[Config.storage.grade]
            return EMS.notify('error', ('المخزن لرتبة %s فما فوق'):format(g and g.name or Config.storage.grade))
        end
        EMS.error(err)
    end
end

local function useLift(spot)
    local h = Config.hospitals[spot.hospital]
    local options = {}
    for i, floor in ipairs(h.lift) do
        if i ~= spot.floor then
            options[#options + 1] = {
                title = floor.label, icon = 'elevator',
                onSelect = function()
                    DoScreenFadeOut(400)
                    Wait(450)
                    SetEntityCoords(cache.ped, floor.coords.x, floor.coords.y, floor.coords.z - 0.98, false, false, false, false)
                    SetEntityHeading(cache.ped, floor.coords.w)
                    Wait(600)
                    DoScreenFadeIn(400)
                end,
            }
        end
    end
    lib.registerContext({ id = 'exti_ems_lift', title = 'المصعد', options = options })
    lib.showContext('exti_ems_lift')
end

local SPOT_TEXT = {
    duty = '[E] تسجيل الدخول والخروج',
    cloakroom = '[E] غرفة الملابس',
    storage = '[E] مخزن الإسعاف',
    locker = '[E] خزانتك الشخصية',
    supply = '[E] خزانة المستلزمات',
    garage = '[E] مرآب الإسعاف',
    heli = '[E] مهبط المروحية',
    lift = '[E] المصعد',
}

local function runSpot(spot)
    if spot.kind == 'duty' then return EMS.openDuty(spot) end
    if spot.kind == 'cloakroom' then return EMS.openCloakroom(spot) end
    if spot.kind == 'locker' then return openStash(spot) end
    if spot.kind == 'lift' then return useLift(spot) end
    if not EMS.onDuty() then return EMS.error('off_duty') end
    if spot.kind == 'storage' then return openStash(spot) end
    if spot.kind == 'supply' then return openSupply(spot) end
    if spot.kind == 'garage' or spot.kind == 'heli' then
        if cache.vehicle then return EMS.parkIn(spot) end
        return EMS.openGarage(spot, spot.kind == 'heli' and 'air' or 'ground')
    end
end

---------------------------------------------------------------------------
-- looking after a patient (revive / treat / hospital bed)
---------------------------------------------------------------------------
local caring = false

-- someone next to you who needs help: down, not at full health, or with injuries on record
local function playerAhead()
    local player, ped = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.reach, false)
    if not player or GetVehiclePedIsIn(ped, false) ~= 0 then return end
    local serverId = GetPlayerServerId(player)
    local bag = Player(serverId).state
    local state = bag['qbx_medical:deathState']
    local down = state ~= nil and state ~= 1
    local wounded = (tonumber(bag.exti_wounds) or 0) > 0
    local hurt = GetEntityHealth(ped) < GetEntityMaxHealth(ped)
    if not down and not wounded and not hurt then return end
    return serverId, ped, down or hurt -- urgent: down or hurt (not just an old injury on record)
end

-- a hospital bed next to you (qbx_ambulancejob knows the beds)
local function nearestBed()
    local ok, hospital, index = pcall(function()
        return exports.qbx_ambulancejob:GetNearestBed(GetEntityCoords(cache.ped), 3.0)
    end)
    if ok and hospital then return hospital, index end
end

function EMS.putInBed(target)
    local hospital, index = nearestBed()
    if not hospital then return EMS.notify('error', 'قف بجانب سرير في المستشفى') end
    TriggerServerEvent('hospital:server:putPlayerInBed', target, hospital, index)
end

local openPatient
EMS.openPatient = function(target) return openPatient(target) end
function openPatient(target)
    local info = lib.callback.await('exti_ems:server:patient', false, target)
    if not info then return EMS.error('too_far') end
    local stateText = info.state == 'down' and 'على الأرض — يحتاج إنعاشًا'
        or info.state == 'hurt' and ('مصاب — صحته %d%%'):format(info.health)
        or 'بصحة جيدة'
    local options = {
        { title = ('الحالة: %s'):format(stateText), icon = 'heart-pulse', readOnly = true,
          progress = info.state == 'down' and 0 or info.health, colorScheme = info.state == 'down' and 'red' or (info.health < 60 and 'orange' or 'green') },
        { title = 'فحص بالتابلت', icon = 'stethoscope', iconColor = '#e8b547',
          description = 'افحص كل جزء من الجسم وقِس النبض والضغط والأكسجين',
          onSelect = function() EMS.openExam(target) end },
    }
    -- the treatment (step by step, like the video) does what the quick revive / heal used to do
    if info.state ~= 'ok' and EMS.openTreatment then
        options[#options + 1] = {
            title = 'علاج المريض', icon = 'kit-medical', iconColor = '#ff6b6b',
            description = info.state == 'down' and 'خطة علاج خطوة بخطوة حتى يقوم المريض (أجرك $' .. Config.pay.revive .. ')'
                or 'أوقف النزيف، ضمّد الجروح، أعطه ما يحتاج',
            onSelect = function() EMS.openTreatment(target) end,
        }
    end
    if nearestBed() then
        options[#options + 1] = {
            title = 'ضعه على السرير', icon = 'bed-pulse', description = 'يستلقي المريض على السرير الذي بجانبك',
            onSelect = function() EMS.putInBed(target) end,
        }
    end
    lib.registerContext({ id = 'exti_ems_patient', title = ('المريض: %s'):format(info.name), options = options })
    lib.showContext('exti_ems_patient')
end

---------------------------------------------------------------------------
-- the main loop: which "[E]" to show
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 600
        local text, action
        if EMS.isMedic() and not EMS.isDown() and not IsNuiFocused() and not lib.progressActive() and not caring then
            local p = GetEntityCoords(cache.ped)
            -- 1) pushing a stretcher / wheelchair
            if EMS.isPushing and EMS.isPushing() then
                text, action = EMS.equipmentPrompt(p)
                sleep = 0
            else
                -- 2) a patient next to you (someone down or hurt; someone with only an old injury on
                -- record does not hide the hospital spots)
                local target, urgent, fakeId
                if EMS.onDuty() and not cache.vehicle then
                    local id, _, isUrgent = playerAhead()
                    target, urgent = id, isUrgent
                    -- a test patient NPC (/fakepatient) next to you
                    if not target and EMS.fakeNear then fakeId = EMS.fakeNear(p, Config.reach) end
                end
                local best, bestDist
                for i = 1, #spots do
                    local s = spots[i]
                    local d = #(p - s.coords)
                    if d < 12.0 then sleep = math.min(sleep, 150) end
                    if d < reachOf(s) and (not bestDist or d < bestDist) then best, bestDist = s, d end
                end
                if best and cache.vehicle and best.kind ~= 'garage' and best.kind ~= 'heli' then best = nil end
                if target and (urgent or not best) then
                    sleep = 0
                    text = '[E] افحص المريض'
                    action = function() openPatient(target) end
                elseif fakeId then
                    sleep = 0
                    text = '[E] المريض (تجريبي)'
                    action = function()
                        lib.registerContext({ id = 'exti_ems_fake', title = 'مريض تجريبي', options = {
                            { title = 'فحص بالتابلت', icon = 'stethoscope', iconColor = '#e8b547',
                              description = 'افحص كل جزء من الجسم وقِس النبض والضغط والأكسجين',
                              onSelect = function() EMS.openExam(fakeId) end },
                            { title = 'علاج المريض', icon = 'kit-medical', iconColor = '#ff6b6b',
                              description = 'خطة علاج خطوة بخطوة — مثل المريض الحقيقي',
                              onSelect = function() if EMS.openTreatment then EMS.openTreatment(fakeId) end end },
                        } })
                        lib.showContext('exti_ems_fake')
                    end
                else
                    -- 3) the hospital spots
                    if best then
                        sleep = 0
                        text = (cache.vehicle and (best.kind == 'garage' or best.kind == 'heli')) and '[E] أدخل المركبة للمرآب' or SPOT_TEXT[best.kind]
                        action = function() runSpot(best) end
                    else
                        -- 4) a stretcher / wheelchair lying here, or the back of an ambulance
                        local eqText, eqAction
                        if EMS.equipmentPrompt then eqText, eqAction = EMS.equipmentPrompt(p) end
                        -- 5) the trunk of one of the team's vehicles
                        if not eqText and EMS.trunkPrompt then eqText, eqAction = EMS.trunkPrompt(p) end
                        if eqText then text, action, sleep = eqText, eqAction, 0 end
                    end
                end
            end
        end
        EMS.prompt(text)
        if action and IsControlJustPressed(0, 38) then
            EMS.prompt(nil)
            CreateThread(action)
            Wait(400)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if shownText then lib.hideTextUI() end
end)
