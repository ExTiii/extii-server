-- =====================================================================
-- EX_Tii gangs: car theft -> the police (like NoPixel).
--   * attempts come from the car keys script (lockpick / hotwire failed, key search, carjack)
--     through our game side (it adds "did a witness see it"), real thefts from server/chop.lua
--   * who gets an alert: player cars, police cars, super + sports always; normal cars by chance
--     (lower at night); a witness always calls it in. One alert per car per 5 min.
--   * the alert: model, colour, half the plate, how, where (the 911 map + the phone); the tablet
--     shows how long ago
--   * GPS tracker on fast cars: the police see the car live for 2 min unless the thief pulls it
--   * a player car: the owner's alarm (+ where it was on his map), the plate is flagged STOLEN on the
--     police tablet (BOLO) right away; the owner confirms it or calls it off
-- =====================================================================
local T = C.theft
local POLICE_JOB = 'police'
local SYSTEM = 'نظام الإنذار'

local function copsOnDuty()
    local ok, _, list = pcall(function() return exports.qbx_core:GetDutyCountJob(POLICE_JOB) end)
    return ok and type(list) == 'table' and list or {}
end
local function isCopOnDuty(src)
    local p = GANG.player(src)
    local job = p and p.PlayerData.job
    return job and job.name == POLICE_JOB and job.onduty == true
end
GANG.isCopOnDuty, GANG.copsOnDuty = isCopOnDuty, copsOnDuty

local function policeUp() return GetResourceState('exti_police') == 'started' end

local function isNight()
    local t = GlobalState.currentTime
    local h = type(t) == 'table' and tonumber(t.hour) or tonumber(os.date('%H'))
    if T.nightFrom > T.nightTo then return h >= T.nightFrom or h < T.nightTo end
    return h >= T.nightFrom and h < T.nightTo
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function plateOf(veh) return trim(GetVehicleNumberPlateText(veh)):upper() end
local function halfPlate(plate)
    local n = #plate
    if n == 0 then return '?' end
    local keep = math.ceil(n / 2)
    return plate:sub(1, keep) .. string.rep('*', n - keep)
end

---------------------------------------------------------------------------
-- what the car looks like
---------------------------------------------------------------------------
local byHash
local function modelLabel(veh)
    byHash = byHash or exports.qbx_core:GetVehiclesByHash()
    local v = byHash and byHash[GetEntityModel(veh)]
    if not v then return 'سيارة' end
    local name = trim(('%s %s'):format(v.brand or '', v.name or ''))
    return name ~= '' and name or 'سيارة'
end

-- GTA paint numbers -> a colour a witness would say
local PAINT = {}
local function paint(name, list) for _, i in ipairs(list) do PAINT[i] = name end end
paint('سوداء', { 0, 2, 12, 15, 16, 21, 141, 142, 143, 147 })
paint('رمادية', { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 17, 18, 19, 20, 22, 23, 24, 25, 26, 117, 118, 119, 156 })
paint('حمراء', { 27, 28, 29, 30, 31, 32, 33, 34, 35, 39, 40, 43, 44, 45, 46, 47, 48, 150 })
paint('برتقالية', { 36, 38, 41, 104, 123, 124, 130, 138 })
paint('ذهبية', { 37, 158, 159 })
paint('صفراء', { 42, 88, 89, 91, 126 })
paint('خضراء', { 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 92, 125, 128, 133, 139, 144, 151, 152, 155 })
paint('زرقاء', { 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 127, 140, 146, 157 })
paint('بنية', { 90, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 105, 106, 108, 109, 110, 113, 114, 115, 116, 129, 153, 154 })
paint('بيضاء', { 107, 111, 112, 121, 122, 131, 132, 134 })
paint('كروم', { 120 })
paint('وردية', { 135, 136, 137 })
paint('بنفسجية', { 145, 148, 149 })

local function rgbName(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local v, d = mx, mx - mn
    local s = mx == 0 and 0 or d / mx
    if v < 0.18 then return 'سوداء' end
    if s < 0.15 then return v > 0.8 and 'بيضاء' or 'رمادية' end
    local h
    if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    h = h * 60
    if h >= 15 and h < 45 and v < 0.6 then return 'بنية' end
    if h < 15 or h >= 345 then return 'حمراء' end
    if h < 40 then return 'برتقالية' end
    if h < 70 then return 'صفراء' end
    if h < 170 then return 'خضراء' end
    if h < 260 then return 'زرقاء' end
    if h < 300 then return 'بنفسجية' end
    return 'وردية'
end

local function colourOf(veh)
    local ok, name = pcall(function()
        if GetIsVehiclePrimaryColourCustom(veh) then return rgbName(GetVehicleCustomPrimaryColour(veh)) end
        local primary = GetVehicleColours(veh)
        return PAINT[primary]
    end)
    return ok and name or nil
end

local HOW = {
    lockpick = 'كسر القفل', hotwire = 'توصيل الأسلاك', keys = 'سرقة بالإكراه', carjack = 'محاولة كسر قفل',
    steal = 'بحث عن المفتاح داخل السيارة',
}

---------------------------------------------------------------------------
-- the alert
---------------------------------------------------------------------------
local seen = {}       -- [vehicle] = { alerted = t, rolled = t, at = t }
local lastFrom = {}   -- [src] = os.time() (attempt events)
local recent = {}     -- [src] = { [vehicle] = os.time() }: cars he touched in the last minute

-- a cheat could fire the car keys events over a whole parking lot: a few cars a minute at most
local function tooMany(src, veh)
    local now = os.time()
    local r = recent[src] or {}
    recent[src] = r
    local n = 0
    for v, t in pairs(r) do if now - t > 60 then r[v] = nil elseif v ~= veh then n = n + 1 end end
    if not r[veh] and n >= 3 then return true end
    r[veh] = r[veh] or now
    return false
end

local function alertPolice(veh, how, witness, police)
    if not policeUp() then return end
    local plate = plateOf(veh)
    local colour = colourOf(veh)
    local text = ('%s%s · اللوحة %s · %s%s'):format(modelLabel(veh), colour and (' ' .. colour) or '', halfPlate(plate),
        HOW[how] or 'سرقة', witness and ' · شاهد رأى السرقة' or '')
    pcall(function()
        exports.exti_police:AddCall({
            kind = 'alarm', label = police and 'سرقة مركبة شرطة' or 'سرقة سيارة',
            coords = (function() local c = GetEntityCoords(veh) return { x = c.x, y = c.y, z = c.z } end)(), text = text, number = witness and 'شاهد' or SYSTEM,
        })
    end)
end

-- returns true when an alert went out
local function maybeAlert(src, veh, how, witness, owned)
    if isCopOnDuty(src) then return false end           -- an officer opening a car for the job
    local now = os.time()
    local s = seen[veh] or {}
    seen[veh] = s
    s.at = now
    if s.alerted and now - s.alerted < T.repeatWindow then return false end
    local st = Entity(veh).state
    local police = st.exti_police ~= nil
    local tier = GANG.tierOf(veh, nil)
    local go = witness == true or police or owned ~= nil or (tier and T.alwaysTiers[tier]) or false
    if not go then
        if s.rolled and now - s.rolled < T.repeatWindow then return false end
        s.rolled = now
        go = math.random() < (isNight() and T.nightChance or T.dayChance)
    end
    if not go then return false end
    s.alerted = now
    alertPolice(veh, how, witness == true, police)
    return true
end

-- purge old cars
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for veh, s in pairs(seen) do
            if now - (s.at or 0) > 900 or not DoesEntityExist(veh) then seen[veh] = nil end
        end
        for src, t in pairs(lastFrom) do if now - t > 60 then lastFrom[src] = nil; recent[src] = nil end end
        for plate, pd in pairs(pending) do if now - pd.at > 120 then pending[plate] = nil end end
    end
end)

---------------------------------------------------------------------------
-- the GPS tracker (fast cars): the police see the car live
---------------------------------------------------------------------------
local tracked = {}    -- [vehicle] = { id, ends, label }
local nextTracker = 0

local function trackerEnd(veh, why)
    local t = tracked[veh]
    if not t then return end
    tracked[veh] = nil
    if DoesEntityExist(veh) then Entity(veh).state:set('exti_tracker', nil, true) end
    for _, cop in ipairs(copsOnDuty()) do TriggerClientEvent('exti_gangs:client:trackerEnd', cop, t.id, why) end
end

local function trackerStart(src, veh)
    if tracked[veh] or Entity(veh).state.exti_tracker_pulled then return end
    nextTracker = nextTracker + 1
    tracked[veh] = { id = nextTracker, ends = os.time() + T.trackerSeconds,
                     label = ('%s · %s'):format(modelLabel(veh), halfPlate(plateOf(veh))) }
    Entity(veh).state:set('exti_tracker', true, true)
    GANG.notify(src, 'سمعت صفيرًا: في هذه السيارة متتبع GPS! انزل وانزعه (تحت السيارة من الخلف)', 'error', 9000)
end

CreateThread(function()
    while true do
        Wait(T.trackerEvery * 1000)
        if next(tracked) then
            local cops = copsOnDuty()
            local now = os.time()
            for veh, t in pairs(tracked) do
                if not DoesEntityExist(veh) then trackerEnd(veh, 'gone')
                elseif now >= t.ends then trackerEnd(veh, 'time')
                else
                    local c = GetEntityCoords(veh)
                    for _, cop in ipairs(cops) do
                        TriggerClientEvent('exti_gangs:client:tracker', cop, t.id, { x = c.x, y = c.y, z = c.z }, t.label, t.ends - now)
                    end
                end
            end
        end
    end
end)

-- the thief pulls it out (under the back of the car)
local pulling = {}
lib.callback.register('exti_gangs:server:pullBegin', function(source, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or not tracked[veh] then return false end
    if isCopOnDuty(source) then return false end
    local here = GANG.coords(source)
    if not here or #(here - GetEntityCoords(veh)) > 4.0 then return false end
    pulling[source] = { veh = veh, at = os.time() }
    return true, T.pullSeconds
end)
lib.callback.register('exti_gangs:server:pullFinish', function(source, passed)
    local p = pulling[source]; pulling[source] = nil
    if not p or not DoesEntityExist(p.veh) or not tracked[p.veh] then return false end
    if os.time() - p.at < T.pullSeconds - 1 then return false end
    local here = GANG.coords(source)
    if not here or #(here - GetEntityCoords(p.veh)) > 4.5 then return false end
    if passed ~= true then return false, 'skill' end
    Entity(p.veh).state:set('exti_tracker_pulled', true, true)
    trackerEnd(p.veh, 'pulled')
    return true
end)
AddEventHandler('playerDropped', function() pulling[source] = nil; lastFrom[source] = nil; recent[source] = nil end)

---------------------------------------------------------------------------
-- a player car: the owner's alarm + the STOLEN flag on the police tablet
---------------------------------------------------------------------------
local alarmed = {}    -- [plate] = os.time() (one alarm per car per 10 min)
local pending = {}    -- [plate] = { cid, at }: the owner may answer this alarm (once, within 60 s)

local function openBolo(plate)
    return MySQL.single.await('SELECT `id`, `officer` FROM `exti_police_bolos` WHERE `plate` = ? AND `closed` IS NULL ORDER BY `id` DESC LIMIT 1', { plate })
end

local function ownerAlarm(veh, owned)
    local plate = plateOf(veh)
    if (alarmed[plate] or 0) + 600 > os.time() then return end
    alarmed[plate] = os.time()
    local where = GetEntityCoords(veh)
    local colour = colourOf(veh)
    local label = ('%s%s'):format(modelLabel(veh), colour and (' ' .. colour) or '')
    CreateThread(function()
        local flagged = false
        if policeUp() and not openBolo(plate) then
            MySQL.insert.await('INSERT INTO `exti_police_bolos` (`kind`, `title`, `text`, `plate`, `officer`, `created`) VALUES (?, ?, ?, ?, ?, ?)', {
                'vehicle', ('سيارة مسروقة %s'):format(plate), ('%s · انطلق إنذارها، بانتظار تأكيد المالك'):format(label), plate, SYSTEM, os.time() })
            flagged = true
        end
        local os_ = GANG.srcOf(owned.citizenid)
        if os_ then
            pending[plate] = { cid = owned.citizenid, at = os.time() }
            TriggerClientEvent('exti_gangs:client:carAlarm', os_, { plate = plate, coords = { x = where.x, y = where.y, z = where.z }, flagged = flagged,
                blip = T.ownerBlipSeconds })
        end
    end)
end

-- an alarm nobody confirmed comes off the tablet after 30 min (the owner can still report it himself at the police)
CreateThread(function()
    while true do
        Wait(300000)
        if policeUp() then
            pcall(function()
                MySQL.update.await('UPDATE `exti_police_bolos` SET `closed` = ?, `closed_by` = ? WHERE `officer` = ? AND `closed` IS NULL AND `created` < ?',
                    { os.time(), SYSTEM, SYSTEM, os.time() - 1800 })
            end)
        end
    end
end)

-- the owner answers the alarm: yes = confirm it's stolen, no = it's fine (a friend), nil = no answer (stays)
RegisterNetEvent('exti_gangs:server:reportStolen', function(plate, confirm)
    local src = source
    if type(plate) ~= 'string' or #plate > 12 or not policeUp() then return end
    plate = trim(plate):upper()
    local p = GANG.player(src)
    if not p then return end
    local ok, vid = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(plate) end)
    local owned = ok and vid and exports.qbx_vehicles:GetPlayerVehicle(vid)
    if not owned or owned.citizenid ~= p.PlayerData.citizenid then return end
    -- only an answer to a real alarm, once
    local pd = pending[plate]
    pending[plate] = nil
    if not pd or pd.cid ~= owned.citizenid or os.time() - pd.at > 60 then return end
    local bolo = openBolo(plate)
    if confirm == true then
        if bolo and bolo.officer ~= SYSTEM then
            -- an officer's own BOLO on this plate: leave it as he wrote it
        elseif bolo then
            MySQL.update.await('UPDATE `exti_police_bolos` SET `title` = ?, `officer` = ? WHERE `id` = ?',
                { ('سيارة مسروقة %s (بلاغ المالك)'):format(plate), 'بلاغ مواطن', bolo.id })
        else
            MySQL.insert.await('INSERT INTO `exti_police_bolos` (`kind`, `title`, `text`, `plate`, `officer`, `created`) VALUES (?, ?, ?, ?, ?, ?)', {
                'vehicle', ('سيارة مسروقة %s (بلاغ المالك)'):format(plate), ('بلاغ من المالك %s'):format(GANG.charName(p)), plate, 'بلاغ مواطن', os.time() })
        end
        for _, cop in ipairs(copsOnDuty()) do
            TriggerClientEvent('ox_lib:notify', cop, { type = 'inform', title = 'تعميم: سيارة مسروقة', description = ('المالك أكّد سرقة اللوحة %s'):format(plate) })
        end
        GANG.notify(src, ('تم: اللوحة %s مطلوبة الآن عند الشرطة'):format(plate), 'success')
        GANG.log('-', GANG.charName(p), 'stolen_report', plate)
    elseif confirm == false then
        if bolo and bolo.officer == SYSTEM then
            MySQL.update.await('UPDATE `exti_police_bolos` SET `closed` = ?, `closed_by` = ? WHERE `id` = ?', { os.time(), 'المالك', bolo.id })
        end
        GANG.notify(src, 'تم: لا بلاغ على سيارتك', 'inform')
    end
end)

---------------------------------------------------------------------------
-- the two ways in
---------------------------------------------------------------------------
-- a real theft (lockpick opened it, hotwired it, took the keys): from server/chop.lua
local lastStolen = {}  -- [src] = os.time()
AddEventHandler('playerDropped', function() lastStolen[source] = nil end)
function GANG.stolen(src, veh, how, owned)
    local now = os.time()
    if (lastStolen[src] or 0) + 2 > now or tooMany(src, veh) then return end
    lastStolen[src] = now
    CreateThread(function()
        if isCopOnDuty(src) then return end -- an officer opening a car for the job
        -- ask his game whether an NPC saw it (no answer in 1.5 s = nobody)
        local p, done = promise.new(), false
        local function answer(v) if not done then done = true; p:resolve(v) end end
        lib.callback('exti_gangs:client:witness', src, function(saw) answer(saw == true) end)
        SetTimeout(1500, function() answer(false) end)
        local witness = Citizen.Await(p)
        if not DoesEntityExist(veh) then return end
        maybeAlert(src, veh, how, witness, owned)
        local tier = GANG.tierOf(veh, nil)
        if tier and T.trackerTiers[tier] and how ~= 'lockpick' then trackerStart(src, veh) end
        if owned then ownerAlarm(veh, owned) end
    end)
end

-- an attempt the car keys script reports (failed lockpick / hotwire, key search, carjack)
RegisterNetEvent('exti_gangs:server:theftAttempt', function(crime, netId, witness)
    local src = source
    local now = os.time()
    if (lastFrom[src] or 0) + 3 > now then return end
    lastFrom[src] = now
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    local here = GANG.coords(src)
    if not here or #(here - GetEntityCoords(veh)) > 8.0 then return end
    local cid = GANG.cid(src)
    local owned = GANG.isOwnedBy(veh)
    if owned and owned.citizenid == cid then return end
    if tooMany(src, veh) then return end
    maybeAlert(src, veh, HOW[crime] and crime or 'carjack', witness == true, owned)
end)
