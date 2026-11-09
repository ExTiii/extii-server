-- =====================================================================
-- EX_Tii Police (client): the E spots in the stations (clock in terminal, cloakroom, personal
-- locker, armory, the public forms, the forms inbox, garage, helicopter pad), the station icons on
-- the map, and the "[E]" line.
-- =====================================================================

POL = POL or {}
local JOB = Config.job

local function job()
    return QBX and QBX.PlayerData and QBX.PlayerData.job
end

function POL.isCop()
    local j = job()
    return j and j.name == JOB
end

function POL.onDuty()
    local j = job()
    return j and j.name == JOB and j.onduty == true
end

function POL.isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped)
end

function POL.notify(kind, text)
    lib.notify({ type = kind, description = text })
end

POL.ERRORS = {
    off_duty = 'ابدأ مناوبتك في المركز أولًا',
    too_far = 'اقترب أكثر',
    failed = 'حدث خطأ، حاول مرة أخرى',
    has_one = 'معك مركبة شرطة بالفعل، أعدها أولًا',
    gone = 'لم يعد هذا موجودًا',
    not_boss = 'هذا لقائد الشرطة فقط',
    spot = 'مكان المركبة مشغول، أبعد المركبة الموجودة أولًا',
    vehicle_out = 'هذه المركبة خارج المرآب الآن',
    not_fleet = 'هذه ليست من مركبات الشرطة',
    driver = 'اجلس مكان السائق أولًا',
    passengers = 'أنزل من في المركبة أولًا',
    fleet_full = 'وصل الفريق للحد الأقصى من المركبات',
    no_money = 'رصيد حساب الشرطة في البنك لا يكفي',
    trunk_full = 'أفرغ صندوق المركبة قبل بيعها',
    plate_bad = 'اللوحة: حروف إنجليزية وأرقام فقط، من 2 إلى 8',
    plate_taken = 'هذه اللوحة مستخدمة، اختر غيرها',
}

function POL.error(code)
    POL.notify('error', POL.ERRORS[code] or POL.ERRORS.failed)
end

---------------------------------------------------------------------------
-- "[E] ..." line
---------------------------------------------------------------------------
-- EX_Tii (Moe): E belongs to the line on screen. This script has several features that share one line in the
-- list: a feature acts on E only when its own text is the one showing (one press never does two things)
local claimedFrame = -1
function POL.lineIs(text)
    if not text then return false end
    local open, cur = lib.isTextUIOpen()
    if open ~= true or cur ~= text then return false end
    -- (and one press is used once: two features showing in the same instant can't both act)
    local f = GetFrameCount()
    if claimedFrame == f then return false end
    claimedFrame = f
    return true
end

local shownText, shownAt = nil, 0
function POL.prompt(text)
    -- another script may have hidden it: show it again (and every second: exti_interact drops a line its owner stopped renewing)
    local open, cur = lib.isTextUIOpen()
    if shownText == text and (not text or (open and cur == text and GetGameTimer() - shownAt < 1000)) then return end
    local mine = shownText
    shownText, shownAt = text, GetGameTimer()
    if text then lib.showTextUI(text)
    elseif mine or open then lib.hideTextUI() end   -- (exti_interact keeps one line per script: only ours goes)
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
            SetBlipScale(b, B.scale or 0.72)
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
        for _, kind in ipairs(POL.POINTS) do
            if st[kind] then list[#list + 1] = { station = name, kind = kind, coords = st[kind], public = kind == 'forms' } end
        end
        if st.garage then list[#list + 1] = { station = name, kind = 'garage', coords = st.garage.coords } end
        if st.heli then list[#list + 1] = { station = name, kind = 'heli', coords = st.heli.coords } end
    end
    spots = list
    buildBlips()
end
-- spots moved in game by an admin (/policespots) come from the server
POL.applySpots(GlobalState.exti_police_spots)
buildSpots()
AddStateBagChangeHandler('exti_police_spots', 'global', function(_, _, value)
    POL.applySpots(value)
    buildSpots()
end)

-- in your car / helicopter you can return it from a bit further away
local function reachOf(spot)
    if cache.vehicle and (spot.kind == 'garage' or spot.kind == 'heli') then return Config.vehicleReach or Config.reachPoint end
    return Config.reachPoint
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
            if not POL.isDown() then
                local cop = POL.isCop()
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

---------------------------------------------------------------------------
-- what each spot does
---------------------------------------------------------------------------
local function openLocker(spot)
    local ok, err = lib.callback.await('exti_police:server:openLocker', false, spot.station)
    if not ok then POL.error(err) end
end

local function openArmory()
    local ok, err = lib.callback.await('exti_police:server:canArmory', false)
    if not ok then return POL.error(err) end
    local opened = pcall(function()
        exports.ox_inventory:openInventory('shop', { type = 'exti_police_armory' })
    end)
    if not opened then POL.error('failed') end
end

local SPOT_TEXT = {
    duty = '[E] تسجيل الدخول والخروج',
    cloakroom = '[E] غرفة الملابس',
    locker = '[E] خزانتك الشخصية',
    armory = '[E] مستودع الأسلحة',
    forms = '[E] نماذج الشرطة',
    inbox = '[E] صندوق النماذج',
    evidence = '[E] غرفة المصادرات',
    garage = '[E] مرآب الشرطة',
    heli = '[E] مهبط المروحية',
}

local function runSpot(spot)
    if spot.kind == 'forms' then return POL.openForms(spot) end
    if spot.kind == 'duty' then return POL.openDuty(spot) end
    if spot.kind == 'cloakroom' then return POL.openCloakroom(spot) end
    if spot.kind == 'locker' then return openLocker(spot) end
    if not POL.onDuty() then return POL.error('off_duty') end
    if spot.kind == 'armory' then return openArmory() end
    if spot.kind == 'evidence' then
        -- the seized items room is also where the lab takes the evidence bags
        lib.registerContext({ id = 'exti_police_evroom', title = 'غرفة المصادرات', options = {
            { title = 'المصادرات', description = 'الأسلحة والأغراض المصادرة', icon = 'box-archive', onSelect = function() POL.openSeized(spot) end },
            { title = 'مختبر الأدلة', description = 'سلّم أكياس الأدلة، وشاهد النتائج', icon = 'flask', onSelect = function() POL.openLab() end },
        } })
        return lib.showContext('exti_police_evroom')
    end
    if spot.kind == 'inbox' then return POL.openInbox(spot) end
    if spot.kind == 'garage' or spot.kind == 'heli' then
        if cache.vehicle then return POL.parkIn(spot) end
        return POL.openGarage(spot, spot.kind == 'heli' and 'air' or 'ground')
    end
end

---------------------------------------------------------------------------
-- the main loop: which "[E]" to show
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 600
        local text, action
        -- (nothing while the police tablet is out: its camera uses E too)
        if not POL.isDown() and not IsNuiFocused() and not lib.progressActive() and not (POL.tabletOpen and POL.tabletOpen()) then
            local cop = POL.isCop()
            local p = GetEntityCoords(cache.ped)
            local best, bestDist
            for i = 1, #spots do
                local s = spots[i]
                if canSee(s, cop) then
                    local d = #(p - s.coords)
                    if d < 12.0 then sleep = math.min(sleep, 150) end
                    if d < reachOf(s) and (not bestDist or d < bestDist) then best, bestDist = s, d end
                end
            end
            if best and cache.vehicle and best.kind ~= 'garage' and best.kind ~= 'heli' then best = nil end
            if best then
                sleep = 0
                text = (cache.vehicle and (best.kind == 'garage' or best.kind == 'heli')) and '[E] أدخل المركبة للمرآب' or SPOT_TEXT[best.kind]
                local spot = best
                action = function() runSpot(spot) end
            elseif cop and POL.evidencePrompt and POL.evidencePrompt(p) then
                -- a mark on the ground (evidence)
                text, action = POL.evidencePrompt(p)
                sleep = 0
            elseif cop and POL.trunkPrompt then
                -- the trunk of one of the team's vehicles
                local tText, tAction = POL.trunkPrompt(p)
                if tText then text, action, sleep = tText, tAction, 0 end
            end
            if not text and POL.prisonPrompt then
                -- the prison gate (officers) and the yard jobs (prisoners)
                local pText, pAction = POL.prisonPrompt(p)
                if pText then text, action, sleep = pText, pAction, 0 end
            end
        end
        POL.prompt(text)
        if action and (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) and POL.lineIs(text) then
            POL.prompt(nil)
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
