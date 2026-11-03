-- =====================================================================
-- EX_Tii heists: the Broker (الوسيط), M4. A voice on the phone for the city's serious crews:
--   * he finds you (Rep 4+), and writes again as you climb (a short story told over months)
--   * sells hacking USBs for clean bank money, a few a day for the whole city
--   * rumours: which Fleeca is fat today, what Pacific holds this week
--   * the Big Score: every week, for Rep 10 crews, inside its window; the first leader who brings him
--     the three preps claims it
-- Text him: "فلاشة", "بنك", "باسيفيك", "الكبيرة", "أطالب"
-- =====================================================================
local C = Config
local B = C.broker

local function text(src, msg, where)
    local to = H.phoneOf(src)
    if not to or GetResourceState('npwd') ~= 'started' then return end
    pcall(function() exports.npwd:emitMessage({ senderNumber = B.number, targetNumber = to, message = msg }) end)
    if where then SetTimeout(1200, function() TriggerClientEvent('exti_heists:client:waypoint', src, { x = where.x, y = where.y, z = where.z }) end) end
end
H.brokerText = text

-- the week (Monday to Sunday), as a number: the same for everyone, no locale needed
local function weekKey(t) return tostring(math.floor(((t or os.time()) - 4 * 86400) / 604800)) end
local function dayKey() return os.date('%Y-%m-%d') end

-- this week's special in Pacific's vault (the same all week)
function H.pacificSpecial()
    local list = B.pacificSpecials
    local n = 0
    for ch in weekKey():gmatch('%d') do n = n * 7 + tonumber(ch) end
    return list[(n % #list) + 1]
end

---------------------------------------------------------------------------
-- the story (one text per level he reaches; each only once per character)
---------------------------------------------------------------------------
function H.brokerLevel(src, level)
    local line = B.story[level]
    local cid = H.cid(src)
    if not line or not cid then return end
    local k = ('broker:story:%s:%d'):format(cid, level)
    if GetResourceKvpInt(k) == 1 then return end
    SetTimeout(math.random(20, 60) * 1000 + level * 4000, function()
        -- (marked as sent only when it really goes out: no phone now = next login)
        if GetPlayerName(src) and H.phoneOf(src) and GetResourceState('npwd') == 'started' then SetResourceKvpInt(k, 1); text(src, line) end
    end)
end
-- someone who is already high when this ships: he gets the first text on his next login
local function catchUp(src)
    local lv = H.repLevel(src)
    for l = 4, lv do H.brokerLevel(src, l) end
end
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() local src = source; SetTimeout(30000, function() if GetPlayerName(src) then catchUp(src) end end) end)

---------------------------------------------------------------------------
-- USBs for clean money
---------------------------------------------------------------------------
local sold = { day = dayKey(), n = {} }
do local ok, v = pcall(json.decode, GetResourceKvpString('broker_sold') or ''); if ok and type(v) == 'table' and v.day == dayKey() then sold = v end end
local function sell(src, item)
    local s = B.usbs[item]; if not s then return end
    if sold.day ~= dayKey() then sold = { day = dayKey(), n = {} } end
    if H.repLevel(src) < s.rep then return text(src, ('ليس لك بعد. سمعة %d.'):format(s.rep)) end
    if (sold.n[item] or 0) >= s.daily then return text(src, 'نفدت لليوم. غدًا.') end
    local p = H.player(src)
    if not p or (p.PlayerData.money.bank or 0) < s.price then return text(src, ('الثمن %d$ من حسابك في البنك. لا نقد.'):format(s.price)) end
    if not exports.ox_inventory:CanCarryItem(src, item, 1) then return text(src, 'جيوبك ممتلئة.') end
    p.Functions.RemoveMoney('bank', s.price, 'broker')
    exports.ox_inventory:AddItem(src, item, 1)
    sold.n[item] = (sold.n[item] or 0) + 1
    SetResourceKvp('broker_sold', json.encode(sold))
    H.log(src, 'broker_usb', ('%s · $%d'):format(item, s.price))
    text(src, ('في جيبك. %d$. لا تستعملها قرب كاميرا.'):format(s.price))
end

---------------------------------------------------------------------------
-- the Big Score: the window, the claim
---------------------------------------------------------------------------
-- inside the window? (Fri and Sat, 20:00 - 02:00, at the configured UTC offset)
function H.bigScoreOpen()
    local t = os.time() + B.bigScore.utcOffset * 3600
    local d = os.date('!*t', t)
    local wd, h = d.wday, d.hour        -- (1 = Sunday)
    for _, w in ipairs(B.bigScore.windows) do
        if (wd == w.day and h >= w.from) or (wd == (w.day % 7) + 1 and h < w.to) then return true end
    end
    return false
end
local function claim()
    local ok, v = pcall(json.decode, GetResourceKvpString('bigscore_claim') or '')
    v = ok and type(v) == 'table' and v or {}
    if v.week ~= weekKey() then v = { week = weekKey() } end
    return v
end
function H.bigScoreClaim() return claim() end
-- an admin's test (/bigscoretest): only for him, only for an hour
function H.bigScoreTest(cid)
    local ok, v = pcall(json.decode, GetResourceKvpString('bigscore_test') or '')
    return ok and type(v) == 'table' and v.cid == cid and (v.untilT or 0) > os.time() or false
end
function H.bigScoreDone()
    local v = claim(); v.done = true; SetResourceKvp('bigscore_claim', json.encode(v))
end

local function bigStatus(src)
    local v = claim()
    local lv = H.repLevel(src)
    if lv < B.bigScore.rep then return text(src, 'لا أعرف عمّا تتكلم.') end
    if v.done then return text(src, 'حصلت هذا الأسبوع. الأسبوع القادم.') end
    if v.by then return text(src, v.by == H.cid(src) and 'هي لك هذا الأسبوع. في موعدها فقط: الجمعة والسبت بالليل.' or 'أخذها طاقم آخر هذا الأسبوع.') end
    local need = {}
    for _, item in ipairs(B.bigScore.preps) do if not H.hasPrep(src, item) then need[#need + 1] = C.preps[item] and C.preps[item].label or item end end
    text(src, ('الكبيرة: مستودع الاتحاد، شاحنة الذهب. الجمعة والسبت 20:00-02:00. أول قائد يحضر لي التحضيرات الثلاثة يأخذها.%s'):format(#need > 0 and ('\nينقصك: ' .. table.concat(need, '، ')) or '\nمعك كل شيء: اكتب "أطالب".'))
end

local function claimIt(src)
    local cid = H.cid(src)
    if H.repLevel(src) < B.bigScore.rep then return text(src, 'لا.') end
    local v = claim()
    if v.by or v.done then return text(src, 'أخذها غيرك هذا الأسبوع.') end
    for _, item in ipairs(B.bigScore.preps) do if not H.hasPrep(src, item) then return text(src, 'ينقصك تحضير. اكتب "الكبيرة".') end end
    for _, item in ipairs(B.bigScore.preps) do H.takePrep(src, item) end
    v.by, v.at = cid, os.time()
    SetResourceKvp('bigscore_claim', json.encode(v))
    H.log(src, 'bigscore_claim', weekKey())
    text(src, 'هي لك. حين يُفتح الموعد اكتب لي "ابدأ" وأنت قرب مستودع الاتحاد مع طاقمك. فلاشة ذهبية وثلاث C4.')
end

---------------------------------------------------------------------------
-- his number
---------------------------------------------------------------------------
local function onText(src, msg)
    msg = tostring(msg or '')
    if H.repLevel(src) < B.minRep then return text(src, 'رقم خاطئ.') end
    if msg:find('فلاش') or msg:lower():find('usb') then
        if msg:find('خضر') then return sell(src, 'usb_green') end
        if msg:find('زرق') then return sell(src, 'usb_blue') end
        local lines = {}
        for item, s in pairs(B.usbs) do lines[#lines + 1] = ('%s: %d$ (سمعة %d)'):format(item == 'usb_green' and 'خضراء' or 'زرقاء', s.price, s.rep) end
        return text(src, 'عندي:\n' .. table.concat(lines, '\n') .. '\nاكتب "فلاشة خضراء" أو "فلاشة زرقاء". من البنك فقط.')
    elseif msg:find('باسيفيك') or msg:lower():find('pacific') then
        local sp = H.pacificSpecial()
        return text(src, ('هذا الأسبوع في خزنة باسيفيك: %s. إن وصلت إليها.'):format(sp.label))
    elseif msg:find('بنك') then
        local hot = H.hotBranch and H.hotBranch()
        local v = hot and C.vaults[hot]
        return text(src, v and ('%s. ضعف المال اليوم.'):format(v.label) or 'لا شيء.', v and v.center)
    elseif msg:find('يخت') then
        if not H.startYacht then return end
        local ok, res = H.startYacht(src)
        return text(src, ok and 'اليخت قبالة بانهام كانيون. ارتدِ الزي: يظنونك من التموين، لكن ليس طويلًا. غرفة القيادة ثم خزنة القبطان.' or res, ok and res or nil)
    elseif msg:find('أطالب') or msg:find('اطالب') then
        return claimIt(src)
    elseif msg:find('ابدأ') or msg:find('ابدا') then
        if H.startBigScore then
            local ok, res = H.startBigScore(src)
            return text(src, ok and 'الشاحنة تخرج الآن. لا أخطاء.' or (type(res) == 'string' and res or 'ليس الآن.'), ok and res or nil)
        end
    elseif msg:find('الكبير') then
        return bigStatus(src)
    else
        return text(src, 'اكتب ما تريد: "فلاشة"، "بنك"، "باسيفيك"، "الكبيرة". لا تتصل، لا تكتب أسماء.')
    end
end

local function hook()
    pcall(function()
        exports.npwd:onMessage(B.number, function(ctx)
            local src = ctx and ctx.source
            local msg = ctx and ctx.data and ctx.data.message
            if type(src) == 'number' and src > 0 then SetTimeout(math.random(3000, 8000), function() onText(src, msg) end) end
        end)
    end)
end
CreateThread(function() while GetResourceState('npwd') ~= 'started' do Wait(2000) end Wait(3000); hook() end)
AddEventHandler('onResourceStart', function(res) if res == 'npwd' then SetTimeout(5000, hook) end end)

-- Mondays: the Big Score is up for the week (every Rep 10 character in the city hears it)
CreateThread(function()
    Wait(20000)
    while true do
        local wk = weekKey()
        if GetResourceKvpString('bigscore_announced') ~= wk and os.date('%w') == '1' then
            SetResourceKvp('bigscore_announced', wk)
            for _, s in ipairs(GetPlayers()) do
                local src = tonumber(s)
                if src and H.repLevel(src) >= B.bigScore.rep then text(src, 'الكبيرة متاحة هذا الأسبوع. أول من يحضر التحضيرات الثلاثة. اكتب "الكبيرة".') end
            end
        end
        Wait(600000)
    end
end)

exports('BrokerNumber', function() return B.number end)
