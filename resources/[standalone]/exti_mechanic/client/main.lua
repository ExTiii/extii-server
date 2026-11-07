-- =====================================================================
-- EX_Tii Mechanic (client): the E spots in the stations (clock in terminal, cloakroom, personal
-- locker, armory, the public forms, the forms inbox, service garage, car garage), the station icons on
-- the map, and the "[E]" line.
-- =====================================================================

MEC = MEC or {}
local JOB = Config.job

local function job()
    return QBX and QBX.PlayerData and QBX.PlayerData.job
end

function MEC.isCop()
    local j = job()
    return j and j.name == JOB
end

function MEC.onDuty()
    local j = job()
    return j and j.name == JOB and j.onduty == true
end

function MEC.isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped)
end

function MEC.notify(kind, text)
    lib.notify({ type = kind, description = text })
end

MEC.ERRORS = {
    off_duty = 'ابدأ مناوبتك في الورشة أولًا',
    too_far = 'اقترب أكثر',
    failed = 'حدث خطأ، حاول مرة أخرى',
    has_one = 'معك مركبة الورشة بالفعل، أعدها أولًا',
    gone = 'لم يعد هذا موجودًا',
    not_boss = 'هذا لمدير الورشة فقط',
    spot = 'مكان المركبة مشغول، أبعد المركبة الموجودة أولًا',
    vehicle_out = 'هذه المركبة خارج المرآب الآن',
    not_fleet = 'هذه ليست من مركبات الورشة',
    driver = 'اجلس مكان السائق أولًا',
    passengers = 'أنزل من في المركبة أولًا',
    fleet_full = 'وصل الفريق للحد الأقصى من المركبات',
    no_money = 'رصيد حساب الورشة في البنك لا يكفي',
    trunk_full = 'أفرغ صندوق المركبة قبل بيعها',
    plate_bad = 'اللوحة: حروف إنجليزية وأرقام فقط، من 2 إلى 8',
    plate_taken = 'هذه اللوحة مستخدمة، اختر غيرها',
}

function MEC.error(code)
    MEC.notify('error', MEC.ERRORS[code] or MEC.ERRORS.failed)
end

---------------------------------------------------------------------------
-- "[E] ..." line
---------------------------------------------------------------------------
local shownText
function MEC.prompt(text)
    -- another script may have hidden it: show it again
    if shownText == text and (not text or lib.isTextUIOpen()) then return end
    shownText = text
    if text then lib.showTextUI(text) else lib.hideTextUI() end
end

---------------------------------------------------------------------------
-- the spots and the station icons on the map
---------------------------------------------------------------------------
local spots = {}
local blips = {}

local function buildBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    local B = Config.blip
    if not B then return end
    for _, st in pairs(Config.stations) do
        local c = st.duty or (st.garage and st.garage.coords)
        if c then
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, B.sprite or 60)
            SetBlipColour(b, B.color or 29)
            SetBlipScale(b, B.scale or 0.8)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(st.label)
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

local function buildSpots()
    local list = {}
    for name, st in pairs(Config.stations) do
        for _, kind in ipairs(MEC.POINTS) do
            if st[kind] then list[#list + 1] = { station = name, kind = kind, coords = st[kind], public = kind == 'forms' or MEC.BAYS[kind] == true, bay = MEC.BAYS[kind] == true, pad = kind == 'dyno' } end
        end
        if st.garage then list[#list + 1] = { station = name, kind = 'garage', coords = st.garage.coords } end
        if st.cars then list[#list + 1] = { station = name, kind = 'cars', coords = st.cars.coords } end
    end
    spots = list
    buildBlips()
end
-- spots moved in game by an admin (/mechspots) come from the server
MEC.applySpots(GlobalState.exti_mechanic_spots)
buildSpots()
AddStateBagChangeHandler('exti_mechanic_spots', 'global', function(_, _, value)
    MEC.applySpots(value)
    buildSpots()
end)

-- in a workshop vehicle you can return it from a bit further away
local function reachOf(spot)
    if spot.bay then return (Config.tuning and Config.tuning.bayReach) or 3.5 end
    if cache.vehicle and (spot.kind == 'garage' or spot.kind == 'cars') then return Config.vehicleReach or Config.reachPoint end
    return Config.reachPoint
end

-- the spots you use from inside a car: the garages (to park) and the tuning bays
local function carSpot(spot)
    return spot.bay or spot.pad or spot.kind == 'garage' or spot.kind == 'cars'
end

-- how far: a tuning bay is measured flat (the car sits higher than the circle)
local function distTo(p, spot)
    if spot.bay then return #(p.xy - spot.coords.xy) + math.max(0.0, math.abs(p.z - spot.coords.z) - 2.0) end
    return #(p - spot.coords)
end

-- who sees / can use this spot: the forms are for everyone, the rest for officers
local function canSee(spot, cop)
    return spot.public or cop
end

---------------------------------------------------------------------------
-- the small white circles on the floor
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
            if not MEC.isDown() then
                local cop = MEC.isCop()
                local p = GetEntityCoords(cache.ped)
                for i = 1, #spots do
                    local s = spots[i]
                    if canSee(s, cop) and #(p - s.coords) < DISTANCE then
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
                    if s.drawZ and (not cache.vehicle or carSpot(s)) then
                        local here = distTo(p, s) < reachOf(s)
                        local base = (s.bay or s.pad) and SIZE * 4.2 or SIZE
                        local size = here and base * 1.04 or base
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

---------------------------------------------------------------------------
-- what each spot does
---------------------------------------------------------------------------
local function openLocker(spot)
    local ok, err = lib.callback.await('exti_mechanic:server:openLocker', false, spot.station)
    if not ok then MEC.error(err) end
end

local function openArmory()
    local ok, err = lib.callback.await('exti_mechanic:server:canArmory', false)
    if not ok then return MEC.error(err) end
    local opened = pcall(function()
        exports.ox_inventory:openInventory('shop', { type = 'exti_mechanic_armory' })
    end)
    if not opened then MEC.error('failed') end
end

local SPOT_TEXT = {
    duty = '[E] تسجيل الدخول والخروج',
    cloakroom = '[E] غرفة الملابس',
    locker = '[E] خزانتك الشخصية',
    armory = '[E] خزانة الأدوات',
    forms = '[E] نماذج الورشة',
    inbox = '[E] صندوق النماذج',
    evidence = '[E] رفّ القطع',
    garage = '[E] مرآب مركبات الخدمة',
    cars = '[E] مرآب السيارات',
    delivery = '[E] استلام طلبيات القطع',
    bay = '[E] قائمة التعديل',
}

local function runSpot(spot)
    if spot.kind == 'forms' then return MEC.openForms(spot) end
    if spot.kind == 'duty' then return MEC.openDuty(spot) end
    if spot.kind == 'cloakroom' then return MEC.openCloakroom(spot) end
    if spot.kind == 'locker' then return openLocker(spot) end
    if spot.bay then return MEC.openTune(spot) end
    if not MEC.onDuty() then return MEC.error('off_duty') end
    if spot.kind == 'armory' then return openArmory() end
    if spot.kind == 'evidence' then return MEC.openShelf(spot) end
    if spot.kind == 'inbox' then return MEC.openInbox(spot) end
    if spot.kind == 'delivery' then return MEC.collectParts(spot) end
    if spot.kind == 'garage' or spot.kind == 'cars' then
        if cache.vehicle then return MEC.parkIn(spot) end
        return MEC.openGarage(spot, spot.kind == 'cars' and 'car' or 'ground')
    end
end

---------------------------------------------------------------------------
-- the main loop: which "[E]" to show
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 600
        local text, action
        -- (nothing while the mechanic tablet is out: its camera uses E too)
        if not MEC.isDown() and not IsNuiFocused() and not lib.progressActive() and not (MEC.tabletOpen and MEC.tabletOpen()) then
            local cop = MEC.isCop()
            local p = GetEntityCoords(cache.ped)
            local best, bestDist
            for i = 1, #spots do
                local s = spots[i]
                -- (the dyno circle is only a mark: the test runs from the tablet)
                if canSee(s, cop) and not s.pad and (not s.bay or cache.vehicle) then
                    local d = distTo(p, s)
                    if d < 12.0 then sleep = math.min(sleep, 150) end
                    if d < reachOf(s) and (not bestDist or d < bestDist) then best, bestDist = s, d end
                end
            end
            if best and cache.vehicle and not carSpot(best) then best = nil end
            -- a tuning bay: only the driver
            if best and best.bay and GetPedInVehicleSeat(cache.vehicle, -1) ~= cache.ped then best = nil end
            if best then
                sleep = 0
                text = best.bay and SPOT_TEXT.bay or (cache.vehicle and (best.kind == 'garage' or best.kind == 'cars')) and '[E] أدخل المركبة للمرآب' or SPOT_TEXT[best.kind]
                local spot = best
                action = function() runSpot(spot) end
            elseif cop and MEC.trunkPrompt then
                -- the trunk of one of the team's vehicles
                local tText, tAction = MEC.trunkPrompt(p)
                if tText then text, action, sleep = tText, tAction, 0 end
                -- any car next to an on-duty mechanic: the service menu
                if not tText and MEC.servicePrompt then
                    local sText, sAction = MEC.servicePrompt(p)
                    if sText then text, action, sleep = sText, sAction, 0 end
                end
            end
        end
        MEC.prompt(text)
        if action and (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then
            MEC.prompt(nil)
            CreateThread(action)
            Wait(400)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if shownText then lib.hideTextUI() end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)

-- the parts shelf (the evidence spot): a shared stash for the whole workshop
function MEC.openShelf(spot)
    local ok, err = lib.callback.await('exti_mechanic:server:openShelf', false, spot.station)
    if not ok then MEC.error(err) end
end
