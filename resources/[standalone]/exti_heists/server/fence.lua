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
    if msg:find('شغل') or msg:lower():find('job') then
        local ok, lead = giveLead(src)
        if ok then
            H.text(src, ('%s في %s. بالليل فقط. معك ساعة.'):format(lead.label, lead.area), lead.pos)
        else
            H.text(src, type(lead) == 'string' and #lead > 12 and lead or 'لا شيء لك الآن.')
        end
    elseif msg:find('مكان') or msg:find('وين') or msg:find('أين') or msg:lower():find('where') then
        local f = H.fenceSpot()
        if f then H.text(src, 'هنا اليوم. تعال وحدك.', f) else H.text(src, 'لست في المدينة اليوم.') end
    else
        H.text(src, 'اكتب "شغل" إن كنت تريد بيتًا، أو "مكان" لتعرف أين أنا اليوم. لا تتصل.')
    end
end
CreateThread(function()
    while GetResourceState('npwd') ~= 'started' do Wait(2000) end
    Wait(3000)
    pcall(function()
        exports.npwd:onMessage(F.number, function(ctx)
            local src = ctx and ctx.source
            local msg = ctx and ctx.data and ctx.data.message
            if type(src) == 'number' and src > 0 then SetTimeout(math.random(2500, 6000), function() onText(src, msg) end) end
        end)
    end)
end)

-- the first time he meets you, he gives his number
lib.callback.register('exti_heists:server:fenceHello', function(src)
    if not atFence(src) then return false end
    H.text(src, 'هذا رقمي. احفظه. اكتب "شغل" حين تريد بيتًا، و"مكان" لتعرف أين أجدك.')
    return F.number
end)

exports('FenceNumber', function() return F.number end)
