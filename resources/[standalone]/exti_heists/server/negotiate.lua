-- =====================================================================
-- EX_Tii heists: the NPC negotiator (no-police mode). When "حراسة الحي" is on scene, their negotiator
-- texts every robber they want. Reply with a number:
--   1 = the drop: they text you a spot (marked on your map). Take your hostages there and let them go:
--       30 s, then they come after you. They follow you there and never shoot.
--   2 = let him go here: every hostage goes free right now, 15 s, then they come after you.
--   3 = more time: +5 min before they storm (once).
--   4 = give up: your hostages go, the loot is gone, prison.
-- Without hostages you have nothing to trade but giving up. Hurt a hostage and they stop answering.
-- =====================================================================
local C = Config
local NG = C.negotiator
local HG = C.hostages

local function text(src, msg)
    local to = H.phoneOf(src)
    if not to or GetResourceState('npwd') ~= 'started' then return end
    pcall(function() exports.npwd:emitMessage({ senderNumber = NG.number, targetNumber = to, message = msg }) end)
end
H.negotiatorText = text

local MENU = 'ردّ برقم:\n1 = نحدد لك مكانًا تترك فيه الرهائن\n2 = أطلقهم هنا الآن\n3 = أحتاج وقتًا (+%d دقائق، مرة واحدة)\n4 = أستسلم'
local function menu() return MENU:format(HG.moreTimeMinutes) end

function H.negotiateStart(r)
    for _, s in ipairs(H.npcTargets(r)) do
        local n = H.hostageCount({ s })
        if n > 0 then
            text(s, ('هنا مفاوض حراسة الحي. المكان محاصر. نرى معك %d %s. لن نطلق النار ما دام لا أحد يتأذى. معك %d دقيقة.\n%s')
                :format(n, n == 1 and 'رهينة' or 'رهائن', math.ceil(H.npcStandoffLeft(r) / 60), menu()))
        else
            text(s, 'هنا مفاوض حراسة الحي. المكان محاصر ولا نرى معك رهائن. ردّ 4 لتستسلم.')
        end
    end
end

local REASON = {
    none = 'لا أعرف عمّا تتكلم.', rage = 'انتهى الكلام. آذيت أحدهم.', chase = 'فات وقت الكلام.',
    nohostage = 'بلا رهائن لا اتفاق. ردّ 4 لتستسلم.', once = 'أعطيناك وقتًا مرة. لن نفعلها مرتين.',
    nospot = 'لحظة... أعد المحاولة بعد قليل.',
    broken = 'خرقت الاتفاق. لا اتفاق آخر.',
}

local function onText(src, msg)
    msg = tostring(msg or ''):gsub('%s+', '')
    local pick = msg:match('^[1-4]')
    local digits = { ['١'] = '1', ['٢'] = '2', ['٣'] = '3', ['٤'] = '4' }   -- (Arabic digits too)
    for a, b in pairs(digits) do if msg:sub(1, #a) == a then pick = b end end
    if msg:find('استسلم') or msg:find('أستسلم') then pick = '4' end
    if not pick then
        local r = H.npcOf(src)
        if not r then return text(src, REASON.none) end
        return text(src, 'لم أفهم. ' .. menu())
    end
    local kind = ({ ['1'] = 'drop', ['2'] = 'release', ['3'] = 'time', ['4'] = 'surrender' })[pick]
    local ok, res, again = H.npcDeal(src, kind)
    if not ok then return text(src, REASON[res] or REASON.none) end
    if kind == 'drop' then
        local s = res
        text(src, ('%s النقطة على خريطتك%s. اذهب بالرهائن إلى هناك وأطلقهم. نحن خلفك ولن نطلق النار. معك %d دقائق.')
            :format(again and 'المكان كما قلنا:' or 'اتفقنا.', (s.street and s.street ~= '') and (' (' .. s.street .. ')') or '', HG.dropMinutes))
    elseif kind == 'release' then
        text(src, ('رأيناهم يخرجون. معك %d ثانية.'):format(res))
    elseif kind == 'time' then
        text(src, ('حسنًا. معك %d دقيقة الآن. لا تضيّعها.'):format(res))
    elseif kind == 'surrender' then
        H.addXP(src, NG.surrenderXp, 'surrendered to NPC security')
        text(src, 'قرار ذكي. أخذنا ما سرقت. ستُسلَّم إلى السجن.')
    end
end

local function hook()
    pcall(function()
        exports.npwd:onMessage(NG.number, function(ctx)
            local src = ctx and ctx.source
            local msg = ctx and ctx.data and ctx.data.message
            if type(src) == 'number' and src > 0 then SetTimeout(math.random(1500, 3500), function() onText(src, msg) end) end
        end)
    end)
end
CreateThread(function()
    while GetResourceState('npwd') ~= 'started' do Wait(2000) end
    Wait(3000); hook()
end)
AddEventHandler('onResourceStart', function(res) if res == 'npwd' then SetTimeout(5000, hook) end end)
