-- =====================================================================
-- EX_Tii Police (server): what the person who reported it saw (like NoPixel).
-- A call made about a suspect (shots, a stolen car, a corner sale, graffiti) carries:
--   who reported it  (a CCTV camera close by, else a witness)
--   the person       (man / woman, or only "masked")
--   the car          (model + colour) and half the plate
--   where they went  (north, south-west ... while moving)
-- Nobody sees everything: each detail can be missing; a camera sees most, a witness at night least.
-- The chances are in Config.dispatch.witness.
-- =====================================================================
local W = Config.dispatch.witness or {}

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- GTA paint numbers -> the colour a witness would say (the same table as the gangs' car theft)
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
paint('فضية', { 120 })
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
        return PAINT[(GetVehicleColours(veh))]
    end)
    return ok and name or nil
end

local byHash
local function modelOf(veh)
    if not byHash then
        local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByHash() end)
        byHash = ok and list or {}
    end
    local v = byHash[GetEntityModel(veh)]
    if not v then return nil end
    local name = trim(('%s %s'):format(v.brand or '', v.name or ''))
    return name ~= '' and name or nil
end

local function halfPlate(veh)
    local plate = trim(GetVehicleNumberPlateText(veh)):upper():gsub('%s+', '')
    local n = #plate
    if n == 0 then return nil end
    local keep = math.ceil(n / 2)
    return plate:sub(1, keep) .. string.rep('•', n - keep)
end

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`
local function personOf(ped)
    local masked = (GetPedDrawableVariation(ped, 1) or 0) > 0
    if masked then return 'ملثّم' end
    local m = GetEntityModel(ped)
    if m == MALE then return 'رجل' elseif m == FEMALE then return 'امرأة' end
    return 'شخص'
end

local DIRS = { 'الشمال', 'الشمال الشرقي', 'الشرق', 'الجنوب الشرقي', 'الجنوب', 'الجنوب الغربي', 'الغرب', 'الشمال الغربي' }
local function headingOf(ent)
    local v = GetEntityVelocity(ent)
    if not v or #(vec2(v.x, v.y)) < (W.movingSpeed or 2.5) then return nil end
    local deg = math.deg(math.atan(v.x, v.y)) % 360          -- 0 = north (+y), 90 = east (+x)
    return DIRS[math.floor((deg + 22.5) / 45) % 8 + 1]
end

local function isNight()
    local t = GlobalState.currentTime
    local h = type(t) == 'table' and tonumber(t.hour) or tonumber(os.date('%H'))
    return h >= (W.nightFrom or 21) or h < (W.nightTo or 6)
end

-- a CCTV camera that can see this spot?
local function cameraNear(pos)
    local list = POL.cctvList
    if type(list) ~= 'table' then return false end
    local r = W.cameraRange or 45.0
    for _, cam in ipairs(list) do
        local c = cam.coords
        if c and #(vec3(c.x, c.y, c.z) - pos) < r then return true end
    end
    return false
end

-- opts: { suspect = server id, vehicle = entity, seen = true (someone surely saw it) }
function POL.describe(opts)
    if type(opts) ~= 'table' then return nil end
    local ped = opts.suspect and GetPlayerPed(opts.suspect) or 0
    if ped == 0 then ped = nil end
    local veh = opts.vehicle
    if (not veh or veh == 0 or not DoesEntityExist(veh)) and ped then
        local inside = GetVehiclePedIsIn(ped, false)
        veh = inside ~= 0 and inside or nil
    end
    if veh == 0 then veh = nil end
    if not ped and not veh then return nil end
    local pos = GetEntityCoords(ped or veh)

    local camera = cameraNear(pos)
    local odds = camera and (W.camera or {}) or ((isNight() and not opts.seen) and (W.night or {}) or (W.day or {}))
    local function roll(k) return math.random() < (tonumber(odds[k]) or 0.5) end

    local out = { by = camera and 'كاميرا مراقبة' or 'شاهد عيان' }
    if ped and roll('person') then out.person = personOf(ped) end
    if veh then
        if roll('car') then
            local model, colour = modelOf(veh), colourOf(veh)
            if model or colour then out.car = trim(('%s %s'):format(model or 'سيارة', colour or '')) end
        end
        if roll('plate') then out.plate = halfPlate(veh) end
    end
    if roll('dir') then out.dir = headingOf(veh or ped) end
    if not (out.person or out.car or out.plate or out.dir) then out.vague = true end
    return out
end

-- one line for the tablet's list: "شاهد عيان: رجل · Karin Sultan سوداء · 4AB•••• · باتجاه الشمال"
function POL.witnessLine(w)
    if type(w) ~= 'table' then return nil end
    local bits = {}
    for _, k in ipairs({ 'person', 'car' }) do if w[k] then bits[#bits + 1] = w[k] end end
    if w.plate then bits[#bits + 1] = 'لوحة ' .. w.plate end
    if w.dir then bits[#bits + 1] = 'باتجاه ' .. w.dir end
    if #bits == 0 then return w.by .. ': لم يرَ التفاصيل' end
    return w.by .. ': ' .. table.concat(bits, ' · ')
end
