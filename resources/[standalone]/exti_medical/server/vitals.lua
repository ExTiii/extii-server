-- =====================================================================
-- EX_Tii medical (server): what the medic finds.
-- The numbers come from the injuries: bleeding -> fast pulse, low blood pressure;
-- a shot / stab in the chest -> low oxygen and weak breathing on one side; a knock on the
-- head -> slow, unequal pupils; down -> confused; dead -> no pulse.
-- =====================================================================

Med = Med or {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function seedOf(text)
    local h = 7
    text = tostring(text or '')
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 1000003 end
    return h
end

local function deathOf(src)
    if type(src) == 'number' and src < 0 then -- a test patient (NPC)
        local f = Med.fakeOf(src)
        return f and f.death or 1
    end
    local s = Player(src).state['qbx_medical:deathState']
    if s == 2 or s == 3 then return s end
    local ped = GetPlayerPed(src)
    if ped ~= 0 and GetEntityHealth(ped) <= 0 then return 3 end
    return 1
end
Med.deathOf = deathOf

local function healthOf(src)
    if type(src) == 'number' and src < 0 then
        local f = Med.fakeOf(src)
        return f and f.hp or 100
    end
    local ped = GetPlayerPed(src)
    if ped == 0 then return 100 end
    return clamp(math.floor(GetEntityHealth(ped) - 100 + 0.5), 0, 100)
end

local FLUID = { blood = 700, saline = 350 } -- ml a full bag gives back (saline only fills the volume)

--- how much fluid the infusions gave so far (a running bag counts by how far it got)
function Med.fluid(meta, now)
    local total = 0
    for _, inf in ipairs(meta and meta.inf or {}) do
        local part = inf.d and inf.d > 0 and math.min(1, math.max(0, (now - inf.s) / inf.d)) or 1
        total = total + (FLUID[inf.k] or 0) * part
    end
    return total
end

-- minutes a wound bled: from when it started until it was dressed (or now), without the time a
-- tourniquet held it
local function bleedMinutes(w, now)
    local start = w.t0 or w.t or now
    local stop = w.stop or now
    local secs = stop - start
    if w.tq then
        local tqEnd = math.min(stop, w.tq + (Config.treat and Config.treat.tourniquetMinutes or 10) * 60)
        if tqEnd > w.tq then secs = secs - (tqEnd - math.max(w.tq, start)) end
    end
    return math.max(3, secs / 60)
end
Med.bleedMinutes = bleedMinutes

--- is this wound bleeding right now? (a fresh tourniquet holds it for a while)
function Med.isBleeding(w, now)
    if (w.b or 0) <= 0 then return false end
    if w.tq and now - w.tq < (Config.treat and Config.treat.tourniquetMinutes or 10) * 60 then return false end
    return true
end

--- the hidden truth behind every measurement (each measurement adds a small error)
function Med.body(src)
    local list = Med.list(src)
    local cid = Med.cidOf(src) or tostring(src)
    local seed = seedOf(cid)
    local death = deathOf(src)
    local hp = healthOf(src)
    local now = os.time()
    local meta = Med.meta and Med.meta(src) or nil
    if death == 3 and meta and meta.rosc then death = 2 end -- CPR brought the pulse back: still down, but alive

    -- blood lost (ml): bleeding wounds over time, capped so a walking player stays possible.
    -- a dressed wound keeps what it already lost (b0 = how hard it bled) but loses no more
    local rate, cap = { 8, 25, 60 }, { 400, 900, 1600 }
    local loss = 0
    local lungL, lungR, air, conc, burns, pain, serious = false, false, nil, false, 0, 0, 0
    for i = 1, #list do
        local w = list[i]
        local b = (w.b or 0) > 0 and w.b or (w.b0 or 0)
        if b > 0 then
            b = math.min(3, b)
            loss = loss + math.min(rate[b] * bleedMinutes(w, now), cap[b])
        end
        if w.lung == 'L' then lungL = true elseif w.lung == 'R' then lungR = true end
        if w.k == 'smoke' or w.k == 'drown' then air = w.k end
        if w.conc then conc = true end
        if w.k == 'burn' then burns = math.max(burns, w.deg or 1) end
        local p = ({ gunshot = 8, fracture = 8, pellets = 7, shrapnel = 7, stab = 7, bite = 6, sprain = 5, laceration = 5, probes = 3, smoke = 3, drown = 3, abrasion = 2 })[w.k]
            or (w.k == 'burn' and math.min(9, (w.deg or 1) * 3)) or (w.k == 'bruise' and ((w.s or 1) >= 2 and 4 or 2)) or 2
        if p >= 7 then serious = serious + 1 end
        pain = math.max(pain, p)
    end
    if serious >= 2 then pain = pain + 1 end
    pain = clamp(pain, 0, 10)
    if meta and meta.pain and now < (meta.pain.u or 0) then pain = clamp(pain - (meta.pain.d or 0), 0, 10) end
    if meta and meta.ox then -- oxygen given: the air is clean again, a hurt lung counts half
        air = nil
        if lungL and lungR then lungR = false else lungL, lungR = false, false end
    end
    loss = loss + (100 - hp) * 10
    local limit = death == 3 and 2600 or death == 2 and 2200 or (hp >= 80 and 1200 or 1800)
    loss = math.min(loss, limit)
    loss = math.max(0, loss - Med.fluid(meta, now))
    local class = loss < 750 and 1 or loss < 1500 and 2 or loss < 2000 and 3 or 4
    local lungHits = (lungL and 1 or 0) + (lungR and 1 or 0)

    local b = { death = death, hp = hp, loss = math.floor(loss), class = class, pain = pain, conc = conc,
        lungL = lungL, lungR = lungR, air = air, burns = burns, wounds = #list }

    if death == 3 then
        b.hr, b.sys, b.dia, b.spo2, b.resp = 0, 0, 0, nil, 0
        b.temp = 36.2 - (class >= 3 and 0.8 or 0)
    else
        b.hr = 66 + seed % 14 + ({ 0, 22, 42, 62 })[class] + (pain >= 6 and 8 or 0) + (death == 2 and 10 or 0)
        b.sys = 122 - seed % 9 - ({ 0, 10, 30, 48 })[class] - (death == 2 and 8 or 0)
        b.dia = 79 - seed % 6 - ({ 0, 5, 17, 30 })[class] - (death == 2 and 5 or 0)
        b.spo2 = clamp(98 - lungHits * 6 - (air and 9 or 0) - (class == 4 and 5 or 0) - (death == 2 and 3 or 0), 70, 100)
        b.resp = 14 + ({ 0, 4, 9, 13 })[class] + lungHits * 4 + (air and 6 or 0) + (death == 2 and 4 or 0)
        b.temp = 36.8 + (seed % 5) / 10 - (class >= 3 and 1.0 or 0) + (burns >= 2 and 0.6 or 0) - (air == 'drown' and 1.4 or 0)
    end
    b.consciousness = death == 3 and 'none' or (death == 2 or conc or class == 4) and 'confused' or 'alert'
    b.pupils = death == 3 and 'fixed' or conc and 'unequal' or (air or class == 4) and 'slow' or 'normal'
    return b
end

-- ---------------------------------------------------------------------
-- words
-- ---------------------------------------------------------------------
local T = {}
Med.T = T

function T.hr(v, sys)
    if v <= 0 then return 'لا يوجد نبض!', 'bad' end
    if v >= 110 then return (sys and sys < 100) and 'سريع وضعيف' or 'سريع', 'warn' end
    if v < 55 then return 'بطيء', 'warn' end
    return 'منتظم', 'ok'
end

function T.bp(sys)
    if sys <= 0 then return 'لا يمكن قياسه', 'bad' end
    if sys < 90 then return 'منخفض جدًا', 'bad' end
    if sys < 105 then return 'منخفض', 'warn' end
    if sys > 140 then return 'مرتفع', 'warn' end
    return 'طبيعي', 'ok'
end

function T.spo2(v)
    if not v then return 'لا توجد قراءة', 'bad' end
    if v < 90 then return 'منخفض', 'bad' end
    if v < 94 then return 'أقل من الطبيعي', 'warn' end
    return 'طبيعي', 'ok'
end

function T.resp(v)
    if v <= 0 then return 'لا يتنفس!', 'bad' end
    if v > 24 then return 'سريع جدًا', 'bad' end
    if v > 20 then return 'سريع', 'warn' end
    if v < 10 then return 'بطيء', 'warn' end
    return 'طبيعي', 'ok'
end

function T.temp(v)
    if v < 35.5 then return 'منخفضة', 'warn' end
    if v > 37.6 then return 'مرتفعة', 'warn' end
    return 'طبيعية', 'ok'
end

T.pupils = {
    normal = { 'تتفاعل مع الضوء بشكل طبيعي', 'ok' },
    unequal = { 'غير متساوية وبطيئة — اشتباه إصابة في الرأس (ارتجاج)', 'bad' },
    slow = { 'بطيئة الاستجابة للضوء', 'warn' },
    fixed = { 'متوسعة ولا تتفاعل مع الضوء', 'bad' },
}

function T.heart(b)
    if b.death == 3 then return 'لا توجد أصوات للقلب!', 'bad' end
    if b.hr >= 110 then return 'القلب سريع', 'warn' end
    if b.hr < 55 then return 'القلب بطيء', 'warn' end
    return 'دقات القلب طبيعية ومنتظمة', 'ok'
end

function T.lung(b, side)
    if b.death == 3 then return 'لا يوجد تنفس', 'bad' end
    if (side == 'L' and b.lungL) or (side == 'R' and b.lungR) then return 'دخول الهواء ضعيف جدًا — اشتباه إصابة في الرئة', 'bad' end
    if b.air == 'drown' then return 'أصوات خشخشة — ماء في الرئة', 'warn' end
    if b.air == 'smoke' then return 'أصوات صفير وخشخشة — دخان في الرئة', 'warn' end
    return 'دخول الهواء طبيعي', 'ok'
end

local BLEED = { { 'نزيف خفيف', 'r' }, { 'نزيف متوسط', 'r' }, { 'نزيف شديد', 'r' } }
local function plural(n, one, two, many)
    if n <= 1 then return one end
    if n == 2 then return two end
    return (many):format(n)
end

--- one wound, as the medic sees it
function T.wound(w)
    local k, n = w.k, w.n or 1
    local text, tags, cause = '', {}, nil
    if k == 'gunshot' then
        text = plural(n, 'جرح ناري', 'جرحان ناريان', '%d جروح نارية')
        if (w.r or 0) > 0 then
            text = text .. ' بدون مخرج — ' .. plural(w.r, 'الرصاصة ما زالت في الداخل', 'رصاصتان ما زالتا في الداخل', '%d رصاصات ما زالت في الداخل')
            tags[#tags + 1] = { 'إخراج الرصاصة', 'g' }
        elseif (w.x or 0) > 0 then
            text = text .. ' — أُخرجت الرصاصة'
        else
            text = text .. ' نافذ — دخلت الرصاصة وخرجت'
        end
        cause = ({ 'فتحة صغيرة (مسدس على الأغلب)', 'فتحة متوسطة', 'فتحة كبيرة (بندقية على الأغلب)' })[w.pw or 2]
    elseif k == 'pellets' then
        if (w.r or 0) > 0 then
            text = ('إصابة بطلقة شوزن — %d كرات صغيرة تحت الجلد'):format(w.r)
            tags[#tags + 1] = { 'إخراج الشظايا', 'g' }
        else
            text = 'إصابة بطلقة شوزن — أُخرجت كل الكرات'
        end
    elseif k == 'shrapnel' then
        if (w.r or 0) > 0 then
            text = ('شظايا انفجار — %d قطع في الداخل'):format(w.r)
            tags[#tags + 1] = { 'إخراج الشظايا', 'g' }
        else
            text = 'شظايا انفجار — أُخرجت كل القطع'
        end
    elseif k == 'stab' then
        text = plural(n, 'جرح طعني عميق', 'طعنتان عميقتان', '%d طعنات عميقة')
        tags[#tags + 1] = { 'ضماد ضاغط', 'g' }
    elseif k == 'laceration' then
        text = ('جرح قطعي، طوله %d سم تقريبًا'):format(w.cm or 5)
        if n > 1 then text = text .. (' (%d جروح)'):format(n) end
        tags[#tags + 1] = { 'تنظيف وخياطة', 'g' }
    elseif k == 'bruise' then
        if w.vest then
            text = 'كدمة تحت الدرع — الدرع أوقف الرصاصة'
        elseif w.conc then
            text = 'كدمة وتورّم في الرأس — قد يكون عنده ارتجاج (افحص العين)'
            tags[#tags + 1] = { 'مراقبة', 'o' }
        else
            text = (w.s or 1) >= 2 and 'كدمة كبيرة وتورّم' or 'كدمة خفيفة'
        end
        tags[#tags + 1] = { 'كمادة باردة', 'g' }
    elseif k == 'fracture' then
        if w.p == 'UPPER_BODY' then text = 'ألم شديد عند لمس الأضلاع — اشتباه كسر في الضلوع'
        elseif w.p == 'SPINE' then text = 'ألم في الظهر — لا تحرّكه كثيرًا، اشتباه إصابة في العمود الفقري'
        elseif w.p == 'HEAD' then text = 'تشوّه في الجمجمة — اشتباه كسر'
        else text = 'تورّم وتشوّه واضح — اشتباه كسر' end
        tags[#tags + 1] = { 'يحتاج أشعة', 'o' }
        tags[#tags + 1] = { w.p == 'SPINE' and 'نقالة فقط' or 'جبيرة', 'g' }
    elseif k == 'sprain' then
        text = 'التواء وتورّم'
        tags[#tags + 1] = { 'رباط ضاغط', 'g' }
    elseif k == 'abrasion' then
        text = 'خدوش وسحجات'
        tags[#tags + 1] = { 'تنظيف', 'g' }
    elseif k == 'burn' then
        text = ({ 'حرق من الدرجة الأولى — احمرار', 'حرق من الدرجة الثانية — فقاعات', 'حرق من الدرجة الثالثة — جلد متفحّم' })[w.deg or 1]
        tags[#tags + 1] = { 'ضماد حروق', 'g' }
    elseif k == 'bite' then
        text = 'عضة حيوان — جرح ممزق'
        tags[#tags + 1] = { 'تنظيف وتعقيم', 'g' }
    elseif k == 'probes' then
        if (w.r or 0) > 0 then
            text = 'سهما صاعق كهربائي مغروسان في الجلد'
            tags[#tags + 1] = { 'نزع السهمين', 'g' }
        else
            text = 'نُزع سهما الصاعق — أثر بسيط'
        end
    elseif k == 'smoke' then
        text = 'استنشق دخانًا أو غازًا — سعال وصعوبة في التنفس'
        tags[#tags + 1] = { 'أكسجين', 'g' }
    elseif k == 'drown' then
        text = 'كاد يغرق — ماء في الرئة'
        tags[#tags + 1] = { 'أكسجين', 'g' }
    else
        text = 'إصابة'
    end
    local now = os.time()
    if w.dr then
        -- dressed: the care tags are done
        local kept = {}
        for _, t in ipairs(tags) do
            if t[1] == 'يحتاج أشعة' or t[1] == 'جبيرة' or t[1] == 'نقالة فقط' then kept[#kept + 1] = t end
        end
        tags = kept
        table.insert(tags, 1, { 'تم التضميد ✓', 'k' })
    elseif (w.b or 0) > 0 then
        if Med.isBleeding and not Med.isBleeding(w, now) then
            table.insert(tags, 1, { 'عاصبة مؤقتة', 'o' })
        else
            table.insert(tags, 1, BLEED[math.min(3, w.b)])
        end
    end
    if not cause and w.w and w.w ~= '' then cause = 'السبب المحتمل: ' .. w.w end
    local level = ((w.s or 1) >= 3 or (w.b or 0) >= 2) and 3 or (w.s or 1) >= 2 and 2 or 1
    if w.dr and (w.r or 0) == 0 and w.k ~= 'fracture' then level = 1 end
    return { kind = k, part = Config.parts[w.p] or '', text = text, tags = tags, cause = cause, level = level }
end

--- what the patient says when asked (if awake)
function T.say(src, b)
    if b.death == 3 then return nil end
    local list = {}
    for i, w in ipairs(Med.list(src)) do list[i] = w end -- a copy: sorting must not reorder the saved list
    table.sort(list, function(a, c)
        local la = ((a.s or 1) * 10) + (a.b or 0)
        local lc = ((c.s or 1) * 10) + (c.b or 0)
        return la > lc
    end)
    local lines = {}
    local used = {}
    for i = 1, #list do
        local w = list[i]
        local place = Config.parts[w.p] or ''
        local line
        if w.lung or w.k == 'smoke' or w.k == 'drown' then line = 'صدري… ما أقدر أتنفس زين'
        elseif w.conc then line = 'راسي يدور… ما أتذكر وش صار'
        elseif w.k == 'fracture' and Config.limbs[w.p] then line = ('%s… ما أقدر أحرّكها'):format(place)
        elseif w.k == 'fracture' then line = ('ألم قوي في %s'):format(place)
        elseif w.k == 'burn' then line = ('جلدي يحرق في %s'):format(place)
        elseif (w.b or 0) >= 1 then line = ('فيه دم كثير من %s'):format(place)
        elseif w.k == 'gunshot' or w.k == 'pellets' or w.k == 'shrapnel' then line = ('أحس بحرقة قوية في %s'):format(place)
        elseif w.k == 'bruise' or w.k == 'abrasion' then line = nil
        else line = ('عندي ألم في %s'):format(place) end
        if line and not used[line] then
            used[line] = true
            lines[#lines + 1] = line
        end
        if #lines >= 2 then break end
    end
    local quote
    if #lines == 0 then
        quote = #list > 0 and 'عندي كدمات بس، ما فيني شي كبير' or 'أنا بخير، ما فيني شي'
    else
        quote = table.concat(lines, '، و')
    end
    if b.consciousness == 'confused' then quote = quote .. '…' end
    return { quote = ('«%s»'):format(quote), pain = b.pain, weak = b.consciousness == 'confused' }
end
