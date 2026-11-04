-- =====================================================================
-- EX_Tii heists: the NPC negotiator (no-police mode) as a PHONE CALL on the screen.
-- When "حراسة الحي" is on scene the negotiator calls every robber. He talks, the robber picks one of 3-4
-- sentences (keys 1-4, he keeps moving and aiming), and the negotiator answers depending on what he said.
-- A trust meter (0-100) runs under the talk: calm and fair words raise it, threats lower it. Trust decides
-- what he agrees to:
--   more time (+5 min, once)  ·  a drop-off spot (the red circle, then a head start)
--   a head start (let one hostage go now: when the rest go, 60 s before they move)
--   food / a call to the family (roleplay, raises trust)  ·  giving up
-- Trust down to 0 = he ends the talk: the SWAT team. Hurt a hostage = the same.
-- The call can be put away ("سأتصل بك لاحقًا") and picked up again from the Z wheel (الرهينة ← المفاوض).
-- =====================================================================
local C = Config
local NG = C.negotiator
local HG = C.hostages

local talk = {}   -- [robber] = { rid, node, trust, opts = { {t, go} }, flags = {} }

local function count(src) return H.hostageCount({ src }) end
local function hostageWord(n) return n == 1 and 'رهينة واحدة' or (n == 2 and 'رهينتين' or ('%d رهائن'):format(n)) end
local function mins(r) return math.max(1, math.ceil(H.npcStandoffLeft(r) / 60)) end
local function activeFor(src)
    local t = talk[src]
    local r = H.npcOf(src)
    if not t or not r or r.id ~= t.rid then return nil end
    return t, r
end
local function trust(t, d) t.trust = math.max(0, math.min(100, t.trust + d)) end

---------------------------------------------------------------------------
-- the screen (client/negotiate.lua)
---------------------------------------------------------------------------
local function send(src, payload) TriggerClientEvent('exti_heists:client:negCall', src, payload) end

-- the negotiator says something outside the tree (the storm, the head start...): on the call, no answers
function H.negotiatorText(src, msg)
    local t = talk[src]
    if t then t.opts = {} end
    send(src, { say = msg, opts = {}, close = 9 })
end

---------------------------------------------------------------------------
-- the talk: every node returns what he says and the answers (each answer: its words + what happens)
---------------------------------------------------------------------------
local N = {}
local function show(src, name)
    local t, r = activeFor(src)
    if not t then return end
    if r.rage then talk[src] = nil; return send(src, { say = 'لا كلام بعد الآن.', opts = {}, close = 6 }) end
    local node = N[name]
    if not node then return end
    local say, opts, close = node({ src = src, r = r, t = t, n = count(src) })
    if not say then return end
    t.node = name
    t.opts = opts or {}
    local list = {}
    for i, o in ipairs(t.opts) do list[i] = o.t end
    send(src, { say = say, opts = list, close = close, trust = t.trust })
end

-- he ends it: the SWAT team
local function endTalk(c, line)
    talk[c.src] = nil
    send(c.src, { say = line or 'انتهى الكلام. فريق التدخل يقتحم الآن.', opts = {}, close = 6 })
    H.npcStorm(c.r, 'talk')
end

-- hello
N.open = function(c)
    if c.n == 0 then
        return 'هنا مفاوض حراسة الحي. المكان محاصر بالكامل ولا نرى معك أحدًا. اخرج ويداك مرفوعتان، ولن يتأذى أحد.', {
            { t = 'حسنًا... سأخرج. لا تطلقوا النار.', go = function() return 'surrender' end },
            { t = 'لن أخرج! تعالوا خذوني إن استطعتم.', go = function() talk[c.src] = nil; return nil, 'كما تريد. نحن في الخارج.' end },
        }
    end
    return ('هنا المفاوض من حراسة الحي. المكان محاصر بالكامل. نرى معك %s. أنا هنا لأتأكد أن لا أحد يتأذى اليوم... ولا أنت. معك %d دقيقة. ماذا تريد؟')
        :format(hostageWord(c.n), mins(c.r)), {
        { t = 'لا أحد سيتأذى إذا تركتموني أخرج من هنا.', go = function() trust(c.t, 5); return 'wants' end },
        { t = 'ابتعدوا عن الباب وإلا سيدفع أحدهم الثمن!', go = function() trust(c.t, -15); return 'threat' end },
        { t = 'أحتاج وقتًا لأفكر.', go = function() return 'time' end },
        { t = 'انتهى الأمر... أريد أن أستسلم.', go = function() return 'surrenderAsk' end },
    }
end

-- what he wants
N.wants = function(c)
    local f = c.t.flags
    local opts = {
        { t = 'أريد مكانًا أترك فيه الرهائن ثم أذهب.', go = function() return 'drop' end },
    }
    if not f.headDeal then
        opts[#opts + 1] = { t = 'سأطلق واحدًا الآن، وأنتم تعطونني وقتًا لأهرب.', go = function() return 'head' end }
    end
    if not f.food then
        opts[#opts + 1] = { t = 'الرهائن جائعون وخائفون. أحضروا لهم ماءً وطعامًا.', go = function() return 'food' end }
    elseif not f.family then
        opts[#opts + 1] = { t = 'أريد أن أكلّم أحدًا من عائلتي أولًا.', go = function() return 'family' end }
    end
    opts[#opts + 1] = { t = 'شيء آخر...', go = function() return 'other' end }
    local lead = c.t.trust >= 60 and 'نحن نتقدم. أخبرني ما الذي تحتاجه.'
        or (c.t.trust >= 30 and 'أفهمك. كلنا نريد أن ينتهي هذا اليوم بلا دماء. ما الذي تحتاجه بالضبط؟'
        or 'أنا ما زلت على الخط. لكن صبرنا له حدود. ماذا تريد؟')
    return lead, opts
end

-- the rest: time, let them go here, give up, call back
N.other = function(c)
    local opts = {}
    if not c.r.moreUsed then opts[#opts + 1] = { t = 'أحتاج وقتًا أطول.', go = function() return 'time' end } end
    opts[#opts + 1] = { t = 'سأطلقهم جميعًا هنا الآن، وأنتم تتركونني أذهب.', go = function() return 'releaseAsk' end }
    opts[#opts + 1] = { t = 'أريد أن أستسلم.', go = function() return 'surrenderAsk' end }
    opts[#opts + 1] = { t = 'سأتصل بك لاحقًا.', go = function() return nil, 'لا تتأخر. أنا هنا. (Z ← الرهينة ← المفاوض)' end }
    return 'أسمعك.', opts
end

-- threats
N.threat = function(c)
    if c.t.trust <= 0 then return endTalk(c, 'كفى. لن أسمع تهديدًا آخر. فريق التدخل يقتحم الآن.') end
    return 'هكذا لن نصل إلى شيء. إذا تأذى أي شخص، ندخل فورًا ولن يبقى ما نتكلم عنه. هل نتكلم كرجلين؟', {
        { t = 'حسنًا... آسف. أنا متوتر فقط.', go = function() trust(c.t, 10); return 'wants' end },
        { t = 'لا تختبرني! أنا جاد.', go = function() trust(c.t, -15); return 'threat' end },
        { t = 'أريد مكانًا آمنًا أترك فيه الرهائن.', go = function() return 'drop' end },
    }
end

-- more time (once)
N.time = function(c)
    if c.r.moreUsed then
        return 'أعطيناك وقتًا من قبل. الوقت ينفد، استعمله.', { { t = 'حسنًا. لنتكلم عن طريقة أخرج بها.', go = function() return 'wants' end } }
    end
    if c.t.trust < 30 then
        return 'ولماذا أعطيك وقتًا وأنت تهددنا؟', {
            { t = 'لأني سأطلق واحدًا منهم بعدها. أعدك.', go = function() trust(c.t, 10); c.t.flags.promised = true; return 'timeGive' end },
            { t = 'انسَ الأمر.', go = function() return 'wants' end },
        }
    end
    return N.timeGive(c)
end
N.timeGive = function(c)
    local ok, m = H.npcDeal(c.src, 'time')
    if not ok then return 'لا أستطيع أكثر من هذا.', { { t = 'حسنًا.', go = function() return 'wants' end } } end
    trust(c.t, 5)
    return ('حسنًا. معك الآن %d دقيقة. لا تضيّعها%s'):format(m, c.t.flags.promised and '، وأنا أنتظر وعدك.' or '.'), {
        { t = 'شكرًا. لنتكلم عن طريقة أخرج بها.', go = function() return 'wants' end },
        { t = 'سأتصل بك لاحقًا.', go = function() return nil, 'أنا هنا.' end },
    }
end

-- the drop-off spot
N.drop = function(c)
    if c.r.deal and c.r.deal.kind == 'drop' then
        return 'المكان كما قلنا: النقطة على خريطتك. اذهب الآن.', { { t = 'تمام، أنا في الطريق.', go = function() return nil, 'نحن خلفك.' end } }
    end
    if c.t.trust < 35 then
        return 'لا أثق بك بعد. أطلق واحدًا منهم أولًا كدليل على حسن نيتك، وبعدها نتكلم عن المكان.', {
            { t = 'حسنًا. سأطلق واحدًا الآن.', go = function() c.t.flags.goodwill = 'drop'; return nil, 'أطلقه الآن (Z ← الرهينة ← أطلق سراحه). أنا أنتظر.' end },
            { t = 'لن أطلق أحدًا قبل الاتفاق!', go = function() trust(c.t, -5); return 'wants' end },
            { t = 'لكني لم أؤذِ أحدًا... صدقني.', go = function() trust(c.t, 8); return 'drop' end },
        }
    end
    local ok, spot = H.npcDeal(c.src, 'drop')
    if not ok then return 'لحظة... نبحث لك عن مكان آمن. اسألني بعد قليل.', { { t = 'حسنًا، أنتظر.', go = function() return 'wants' end } } end
    local head = math.max(HG.dropHeadStart, c.r.bonusHead or 0)
    return ('اتفقنا. أرسلت النقطة على خريطتك%s. خذ الرهائن إلى الدائرة الحمراء وأطلقهم داخلها. سنكون خلفك ولن نطلق النار. معك %d دقائق.')
        :format((spot.street and spot.street ~= '') and (' (' .. spot.street .. ')') or '', HG.dropMinutes), {
        { t = 'وبعد أن أطلقهم؟', go = function() return 'dropAfter' end },
        { t = ('أريد وقتًا أطول من %d ثوانٍ قبل أن تلحقوا بي.'):format(head), go = function() return 'dropMore' end },
        { t = 'تمام. أنا في الطريق.', go = function() return nil, 'نحن خلفك. لا تفعل شيئًا غبيًا.' end },
    }
end
N.dropAfter = function(c)
    return ('تحصل على %d ثانية قبل أن نتحرك. هذا وعد.'):format(math.max(HG.dropHeadStart, c.r.bonusHead or 0)), {
        { t = 'تمام. أنا في الطريق.', go = function() return nil, 'نحن خلفك.' end },
        { t = 'أريد وقتًا أطول.', go = function() return 'dropMore' end },
    }
end
N.dropMore = function(c)
    if c.t.flags.dropMore then return 'قلت لك ما عندي.', { { t = 'حسنًا. أنا في الطريق.', go = function() return nil, 'نحن خلفك.' end } } end
    c.t.flags.dropMore = true
    if c.t.trust >= 55 then
        c.r.bonusHead = math.max(c.r.bonusHead or 0, 30)
        return 'سأعطيك ثلاثين ثانية. لا أكثر.', { { t = 'اتفقنا. أنا في الطريق.', go = function() return nil, 'نحن خلفك.' end } }
    end
    trust(c.t, -5)
    return 'لا تضغط عليّ. خذ ما عرضته عليك.', { { t = 'حسنًا. أنا في الطريق.', go = function() return nil, 'نحن خلفك.' end } }
end

-- a head start: one hostage now, then 60 s when the rest go
N.head = function(c)
    if c.n <= 1 then
        return 'معك واحد فقط. أطلقه هنا الآن، وأعطيك ستين ثانية قبل أن نتحرك.', {
            { t = 'اتفقنا. سأطلقه الآن.', go = function() c.r.bonusHead = math.max(c.r.bonusHead or 0, 60); c.t.flags.headDeal = true; return 'releaseDo' end },
            { t = 'لا، أريد مكانًا آمنًا بدل ذلك.', go = function() return 'drop' end },
        }
    end
    return 'اتفقنا: أطلق واحدًا الآن. وحين تطلق الباقين، تحصل على ستين ثانية قبل أن نتحرك.', {
        { t = 'سأطلق واحدًا الآن.', go = function() c.t.flags.headDeal = true; c.t.flags.goodwill = 'head'; return nil, 'أطلقه الآن (Z ← الرهينة ← أطلق سراحه). أنا أنتظر.' end },
        { t = 'غيّرت رأيي.', go = function() trust(c.t, -3); return 'wants' end },
    }
end

-- roleplay favours
N.food = function(c)
    c.t.flags.food = true
    if c.t.trust < 20 then
        trust(c.t, -3)
        return 'لا شيء مجاني وأنت تهدد. أطلق واحدًا أولًا.', { { t = 'حسنًا... لنتكلم.', go = function() return 'wants' end } }
    end
    trust(c.t, 10)
    return 'سأترك الماء والطعام عند الباب. لا أحد من رجالي يقترب، وعد. هذا يُحسب لك.', {
        { t = 'شكرًا.', go = function() return 'wants' end },
    }
end
N.family = function(c)
    c.t.flags.family = true
    return 'سأصلك بمن تريد بعد أن يخرج أول رهينة. هذا عادل؟', {
        { t = 'عادل.', go = function() trust(c.t, 6); return 'wants' end },
        { t = 'لا، الآن!', go = function() trust(c.t, -10); return 'threat' end },
    }
end

-- let them all go here
N.releaseAsk = function(c)
    return 'إذا أطلقتهم الآن وخرجوا سالمين، تأخذ وقتك قبل أن نتحرك. هل أنت متأكد؟', {
        { t = 'نعم. أطلقهم الآن.', go = function() return 'releaseDo' end },
        { t = 'لا، انتظر...', go = function() return 'wants' end },
    }
end
N.releaseDo = function(c)
    local ok, secs = H.npcDeal(c.src, 'release')
    talk[c.src] = nil
    if not ok then return 'لم أرهم يخرجون.', {}, 6 end
    return ('رأيناهم يخرجون. معك %d ثانية.'):format(secs), {}, 6
end

-- giving up
N.surrenderAsk = function(c)
    return 'قرار شجاع. اترك سلاحك، وأطلق الرهائن، واخرج ويداك مرفوعتان. هل أنت متأكد؟', {
        { t = 'نعم. أنا خارج.', go = function() return 'surrender' end },
        { t = 'لا، انتظر...', go = function() return 'wants' end },
    }
end
N.surrender = function(c)
    talk[c.src] = nil
    local ok = H.npcDeal(c.src, 'surrender')
    if not ok then return 'لا أفهم ما تقصد.', {}, 6 end
    H.addXP(c.src, NG.surrenderXp, 'surrendered to NPC security')
    return 'قرار ذكي. لن يتأذى أحد. ستُسلَّم إلى السجن.', {}, 7
end

---------------------------------------------------------------------------
-- the robber answers (keys 1-4)
---------------------------------------------------------------------------
local busy = {}
RegisterNetEvent('exti_heists:server:negPick', function(i)
    local src = source
    i = math.tointeger(tonumber(i))
    local t, r = activeFor(src)
    if not t or not i or busy[src] then return end
    local o = t.opts[i]
    if not o then return end
    busy[src] = true
    t.opts = {}
    send(src, { me = o.t, typing = true })
    -- (he thinks before he answers)
    SetTimeout(math.random(1300, 2300), function()
        busy[src] = nil
        if not activeFor(src) then return end
        local ok, nextNode, line = pcall(o.go)
        if not ok then return end
        if nextNode then return show(src, nextNode) end
        if line then send(src, { say = line, opts = {}, close = 6 }) end
    end)
end)

-- picked up again from the Z wheel
RegisterNetEvent('exti_heists:server:negReopen', function()
    local src = source
    local t, r = activeFor(src)
    if not t then
        if r and r.standoff and not r.rage then
            talk[src] = { rid = r.id, trust = NG.startTrust or 40, flags = {} }
            return show(src, 'open')
        end
        return send(src, { say = 'لا أحد على الخط.', opts = {}, close = 3 })
    end
    show(src, (t.node == 'open' or not N[t.node]) and 'open' or 'wants')
end)

-- a hostage let go with no deal: good faith
function H.negotiateGoodwill(r, by, left)
    local t = talk[by]
    if not t or t.rid ~= r.id then return end
    trust(t, 25)
    local why = t.flags.goodwill
    t.flags.goodwill = nil
    if left == 0 then
        -- the last one: as if he let them all go
        local secs = math.max(HG.releaseHeadStart, r.bonusHead or 0)
        talk[by] = nil
        H.npcHeadStart(r, secs)
        return send(by, { say = ('رأيناه يخرج. لم يعد معك أحد. معك %d ثانية.'):format(secs), opts = {}, close = 7 })
    end
    if why == 'head' then
        r.bonusHead = math.max(r.bonusHead or 0, 60)
        send(by, { say = 'رأيناه يخرج سالمًا. وعدي قائم: حين تطلق الباقين تحصل على ستين ثانية.', opts = {}, close = 0 })
        SetTimeout(2500, function() show(by, 'wants') end)
    else
        send(by, { say = 'رأيناه يخرج سالمًا. هذا جيد. الآن نستطيع أن نتكلم بجد.', opts = {}, close = 0 })
        SetTimeout(2500, function() show(by, why == 'drop' and 'drop' or 'wants') end)
    end
end

-- the call starts (they are on scene)
function H.negotiateStart(r)
    for _, s in ipairs(H.npcTargets(r)) do
        if not talk[s] or talk[s].rid ~= r.id then
            talk[s] = { rid = r.id, trust = NG.startTrust or 40, flags = {} }
            TriggerClientEvent('exti_heists:client:negRing', s)
            SetTimeout(2500, function() show(s, 'open') end)
        end
    end
end

-- two minutes left: he calls
function H.negotiateWarn(r)
    for _, s in ipairs(H.npcTargets(r)) do
        if talk[s] and talk[s].rid == r.id then
            send(s, { say = 'دقيقتان. بعدها ندخل. هذه فرصتك الأخيرة لتتكلم معي.', opts = {}, close = 0 })
            SetTimeout(2500, function() show(s, 'wants') end)
        end
    end
end

AddEventHandler('playerDropped', function() talk[source] = nil; busy[source] = nil end)
