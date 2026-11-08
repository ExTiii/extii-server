-- =====================================================================
-- EX_Tii heists: the fence (المصرّف). He is the gang fence (exti_gangs places him, on a new spot every day),
-- and for robberies he also:
--   * buys stolen goods and jewelry for dirty money, with a daily limit per item for the whole city
--   * hands out house leads (an address, the size, night only)
--   * answers texts on his number: "شغل" = a lead, "مكان" = where he is today
-- =====================================================================
local C = Config
local F = C.fence

local function today() return os.date('%Y-%m-%d') end
local bought = { day = today(), n = {} }   -- what he took today, per item (kept in KVP: a restart resets nothing)
do
    local ok, saved = pcall(json.decode, GetResourceKvpString('fence_daily') or '')
    if ok and type(saved) == 'table' and saved.day == today() and type(saved.n) == 'table' then bought = saved end
end
local function saveBought() SetResourceKvp('fence_daily', json.encode(bought)) end
local function rollDay() if bought.day ~= today() then bought = { day = today(), n = {} }; saveBought() end end

function H.fenceSpot()
    local s = GlobalState['exti_gangs:spots']
    local f = type(s) == 'table' and s.fence
    return f and vec3(f.x, f.y, f.z) or nil
end
-- (2D: a spot from the daily list is stood on the ground in game, so its height may differ a little)
local function atFence(src)
    local f, here = H.fenceSpot(), H.coords(src)
    return f ~= nil and here ~= nil and #(vec2(here.x, here.y) - vec2(f.x, f.y)) <= 3.5 and math.abs(here.z - f.z) < 15.0
end

---------------------------------------------------------------------------
-- the phone
---------------------------------------------------------------------------
function H.phoneOf(src)
    local p = H.player(src); local ci = p and p.PlayerData.charinfo
    return ci and ci.phone and tostring(ci.phone) or nil
end
-- a text from the fence (or anyone in config) to this player; `where` adds a location card
function H.text(src, message, where)
    local to = H.phoneOf(src)
    if not to or GetResourceState('npwd') ~= 'started' then return false end
    local ok = pcall(function() exports.npwd:emitMessage({ senderNumber = F.number, targetNumber = to, message = message }) end)
    -- (the place goes on his map as a waypoint, with a little delay so it feels like it came with the text)
    if where then SetTimeout(1200, function() TriggerClientEvent('exti_heists:client:waypoint', src, { x = where.x, y = where.y, z = where.z }) end) end
    return ok
end

---------------------------------------------------------------------------
-- selling stolen goods
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:fenceGoods', function(src)
    if not atFence(src) then return false, 'far' end
    rollDay()
    local sold, total, full = {}, 0, {}
    for item, g in pairs(F.goods) do
        local have = exports.ox_inventory:Search(src, 'count', item) or 0
        if have > 0 then
            local room = math.max(0, g.daily - (bought.n[item] or 0))
            local n = math.min(have, room)
            if n < have then full[#full + 1] = item end
            if n > 0 and exports.ox_inventory:RemoveItem(src, item, n) then
                bought.n[item] = (bought.n[item] or 0) + n
                if H.contract then H.contract(src, 'sell', { item = item, n = n }) end
                sold[#sold + 1] = { item = item, n = n }
                total = total + n * g.price
            end
        end
    end
    if total == 0 then return false, #full > 0 and 'limit' or 'none' end
    saveBought()
    exports.ox_inventory:AddItem(src, 'black_money', total)
    local parts = {}
    for _, s in ipairs(sold) do parts[#parts + 1] = ('%dx %s'):format(s.n, s.item) end
    H.log(src, 'fence_sell', ('$%d · %s'):format(total, table.concat(parts, ', ')))
    return true, { money = total, count = #sold, limited = #full > 0 }
end)

-- what he pays today (for the menu)
lib.callback.register('exti_heists:server:fencePrices', function(src)
    if not atFence(src) then return false end
    rollDay()
    local out = {}
    for item, g in pairs(F.goods) do
        local have = exports.ox_inventory:Search(src, 'count', item) or 0
        out[#out + 1] = { item = item, price = g.price, left = math.max(0, g.daily - (bought.n[item] or 0)), have = have }
    end
    table.sort(out, function(a, b) return a.price > b.price end)
    return out
end)

---------------------------------------------------------------------------
-- house leads (houses.lua makes them)
---------------------------------------------------------------------------
local lastLead = {}   -- [cid] = os.time()
local function giveLead(src)
    local cid = H.cid(src); if not cid then return false, 'nochar' end
    if H.isCopOnDuty(src) then return false, 'cop' end
    local wait = (lastLead[cid] or 0) + F.leadCooldownMinutes * 60 - H.now()
    if wait > 0 then return false, ('لا شيء الآن. كلّمني بعد %d دقيقة'):format(math.ceil(wait / 60)) end
    if not H.houseLead then return false, 'off' end
    local lead, why = H.houseLead(src)
    if not lead then return false, why end
    lastLead[cid] = H.now()
    return true, lead
end
H.giveLead = giveLead

lib.callback.register('exti_heists:server:fenceLead', function(src)
    if not atFence(src) then return false, 'far' end
    local ok, lead = giveLead(src)
    if not ok then return false, lead end
    H.text(src, ('عندي لك شغل: %s في %s. البيت فاضي بالليل (من 10 مساءً حتى 5 صباحًا). معك ساعة. لا تكسر شيئًا لا تحتاجه.'):format(lead.label, lead.area), lead.pos)
    return true, lead
end)

---------------------------------------------------------------------------
-- texts to his number
---------------------------------------------------------------------------
local function onText(src, msg)
    msg = tostring(msg or '')
    local function say(ok, res, okText)
        if ok then H.text(src, okText(res), res and res.pos) else H.text(src, type(res) == 'string' and #res > 6 and res or 'لا شيء لك الآن.') end
    end
    if msg:find('تحضير') then
        -- the prep for a big job
        local kind = msg:find('قافل') and 'blueprints' or ((msg:find('مزرع') or msg:find('كارتيل')) and 'guard_keycard' or ((msg:find('يخت') or msg:find('تموين')) and 'catering_uniform' or ((msg:find('باليتو') or msg:find('باسيفيك') or msg:find('بنك')) and 'blueprints' or nil)))
        if not kind then return H.text(src, 'تحضير لأي شغل؟ "تحضير مزرعة"، "تحضير قافلة"، "تحضير بنك"، "تحضير يخت".') end
        local ok, res = H.startPrep(src, kind)
        return say(ok, res, function(r) return ('%s في سيارة واقفة هنا. معك %d دقيقة. افتح الباب وخذها من الدرج. قد يكون عندها رجال.'):format(r.label, r.minutes) end)
    elseif msg:find('شاحن') then
        local ok, res = H.startTruck(src, 'armored')
        return say(ok, res, function() return 'شاحنة غروبه 6 تخرج من هنا الآن. أوقفها، فجّر الباب الخلفي، خذ الحقائب. GPS الشاحنة يكلّم الشرطة ثلاث دقائق بعد أن توقفها.' end)
    elseif msg:find('قافل') then
        local ok, res = H.startTruck(src, 'convoy')
        return say(ok, res, function() return 'الفلاشة دلّتني عليها: قافلة ميري ويذر تتحرك من هنا. سيارتان حراسة وشاحنة. لا تتأخر.' end)
    elseif msg:find('مزرع') or msg:find('كارتيل') then
        local ok, res = H.startStash(src)
        return say(ok, res and type(res) ~= 'string' and { pos = res } or res, function() return 'المال في الحظيرة خلف البيت. ستة رجال في الساحة. كاميرا البوابة أولًا، بالفلاشة الزرقاء. لا تُرى.' end)
    elseif msg:find('بنك') then
        if H.repLevel(src) < 4 then return H.text(src, 'البنوك ليست لك بعد.') end
        local hot = H.hotBranch and H.hotBranch()
        local v = hot and C.vaults[hot]
        return H.text(src, v and ('سمعت أن %s فيه ضعف المال اليوم. فلاشة خضراء ومثقاب، ولا تنسَ لوحة الإنذار.'):format(v.label) or 'لا أعرف شيئًا عن البنوك اليوم.', v and v.center)
    elseif msg:find('شغل') or msg:lower():find('job') then
        local ok, lead = giveLead(src)
        if ok then
            H.text(src, ('%s في %s. بالليل فقط. معك ساعة.'):format(lead.label, lead.area), lead.pos)
        else
            H.text(src, type(lead) == 'string' and #lead > 12 and lead or 'لا شيء لك الآن.')
        end
    elseif msg:find('مهام') or msg:find('مهمة') then
        if H.contractStatus then H.contractStatus(src) end
    elseif msg:find('مكان') or msg:find('وين') or msg:find('أين') or msg:lower():find('where') then
        local f = H.fenceSpot()
        if f then H.text(src, 'هنا اليوم. تعال وحدك.', f) else H.text(src, 'لست في المدينة اليوم.') end
    else
        H.text(src, 'اختر من الأزرار فوق خانة الكتابة: بيت، مهام اليوم، مكاني... لا تتصل.')
    end
end
local function hook()
    pcall(function()
        exports.npwd:onMessage(F.number, function(ctx)
            local src = ctx and ctx.source
            local msg = ctx and ctx.data and ctx.data.message
            if type(src) == 'number' and src > 0 then SetTimeout(math.random(2500, 6000), function() onText(src, msg) end) end
        end)
    end)
end
CreateThread(function()
    while GetResourceState('npwd') ~= 'started' do Wait(2000) end
    Wait(3000); hook()
end)
-- (npwd restarted: tell it again who answers his number)
AddEventHandler('onResourceStart', function(res) if res == 'npwd' then SetTimeout(5000, hook) end end)

-- the first time he meets you, he gives his number
lib.callback.register('exti_heists:server:fenceHello', function(src)
    if not atFence(src) then return false end
    local cid = H.cid(src); if cid then SetResourceKvpInt('fencemet:' .. cid, 1) end
    TriggerClientEvent('exti_heists:client:fenceArea', src, nil)
    H.text(src, 'هذا رقمي. احفظه. اضغط الأزرار فوق خانة الكتابة: "عندك بيت؟" حين تريد شغلًا، و"وين مكانك اليوم؟" لتعرف أين أجدك.')
    return F.number
end)

-- someone who never met him, after a robbery: an unknown number tips him off about where to look today
-- (a rough area on the map, never the spot; once a day until he has met the fence)
local AREAS = {
    { vec3(-468.0, -1716.0, 18.7), 'ساحة روجرز للخردة' }, { vec3(1003.5, -3105.0, 5.9), 'الميناء، بين الحاويات' },
    { vec3(1380.0, -2055.0, 52.0), 'حقول النفط في إل بورو' }, { vec3(1993.0, 3050.0, 47.2), 'ساندي شورز، خلف اليلو جاك' },
    { vec3(2416.0, 4993.0, 46.2), 'المزرعة في غريبسيد' }, { vec3(-569.0, 5326.0, 70.2), 'منشرة الخشب في باليتو' },
}
-- the circle stays on his map until he has met the fence (every day around where the fence is that day)
local function circleFor(src, cid)
    local f = H.fenceSpot(); if not f then return nil end
    local day = os.date('%Y-%m-%d')
    local ok, c = pcall(json.decode, GetResourceKvpString('fencecircle:' .. cid) or '')
    if not (ok and type(c) == 'table' and c.day == day and c.fx and math.abs(c.fx - f.x) < 1 and math.abs(c.fy - f.y) < 1) then
        local a, r = math.random() * math.pi * 2, math.random(40, 110)
        c = { day = day, fx = f.x, fy = f.y, x = f.x + math.cos(a) * r, y = f.y + math.sin(a) * r, z = f.z }
        SetResourceKvp('fencecircle:' .. cid, json.encode(c))
    end
    return c
end
local function sendCircle(src, loud)
    local cid = H.cid(src); if not cid then return end
    if GetResourceKvpInt('fencemet:' .. cid) == 1 then return end
    if GetResourceKvpInt('fencehinted:' .. cid) ~= 1 and not GetResourceKvpString('fencehint:' .. cid) then return end
    local c = circleFor(src, cid); if not c then return end
    TriggerClientEvent('exti_heists:client:fenceArea', src, { x = c.x, y = c.y, z = c.z }, F.hintRadius, 0, loud)
    return c
end

function H.fenceHint(src)
    local cid = H.cid(src); if not cid or H.isCopOnDuty(src) then return end
    if GetResourceKvpInt('fencemet:' .. cid) == 1 then return end
    local day = os.date('%Y-%m-%d')
    if GetResourceKvpString('fencehint:' .. cid) == day then return end
    local f = H.fenceSpot(); if not f then return end
    local name, bd = nil, nil
    for _, a in ipairs(AREAS) do local d = #(a[1] - f); if not bd or d < bd then name, bd = a[2], d end end
    SetResourceKvp('fencehint:' .. cid, day)
    SetResourceKvpInt('fencehinted:' .. cid, 1)
    local to = H.phoneOf(src)
    if to and GetResourceState('npwd') == 'started' then
        pcall(function() exports.npwd:emitMessage({ senderNumber = F.hintNumber, targetNumber = to,
            message = ('سمعت أن معك أشياء تريد بيعها. هناك رجل يشتري كل شيء ولا يسأل. اليوم تجده في مكان ما قرب %s. وضعت لك علامة على الخريطة، تبقى حتى تجده. ابحث عن رجل يدخن وحده.'):format(bd and bd < 300 and name or 'المكان الذي على خريطتك') }) end)
    end
    sendCircle(src, true)
    H.log(src, 'fence_hint', name or '?')
end

-- back in the city (log in, script restart) or a new day (the fence moved): the circle again
AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(5000, function() if GetPlayerName(src) then sendCircle(src, false) end end)
end)
CreateThread(function()
    Wait(8000)
    local sent = {}   -- [src] = the fence spot his circle is around
    while true do
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local f = H.fenceSpot()
            local key = f and ('%.0f,%.0f'):format(f.x, f.y) or nil
            if key and sent[src] ~= key then
                if sendCircle(src, false) then sent[src] = key end
            end
        end
        Wait(5 * 60000)
    end
end)

exports('FenceNumber', function() return F.number end)
