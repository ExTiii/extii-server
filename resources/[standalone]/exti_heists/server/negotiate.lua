-- =====================================================================
-- EX_Tii heists: the NPC negotiator (no-police mode). When "حراسة الحي" is on scene, their negotiator
-- texts every robber they want. Reply with a number:
--   1 = a head start: let one hostage go, they hold their fire and stay put for 30 s
--   2 = pull back:   with 2+ hostages, they go back to their cars for 60 s (once)
--   3 = give up:     the loot of this robbery is gone, they leave you be (no hospital)
-- Without hostages you have nothing to trade. Hurt a hostage and they stop answering.
-- =====================================================================
local C = Config
local NG = C.negotiator

local function text(src, msg)
    local to = H.phoneOf(src)
    if not to or GetResourceState('npwd') ~= 'started' then return end
    pcall(function() exports.npwd:emitMessage({ senderNumber = NG.number, targetNumber = to, message = msg }) end)
end

local MENU = 'ردّ برقم: 1 = مهلة (تطلق رهينة) · 2 = انسحبوا (رهينتان على الأقل) · 3 = أستسلم'

function H.negotiateStart(r)
    for _, s in ipairs(H.npcTargets(r)) do
        local n = H.hostageCount({ s })
        text(s, ('هنا مفاوض حراسة الحي. المكان محاصر. %s\n%s'):format(n > 0 and ('نرى معك %d رهائن. لا أحد يتأذى.'):format(n) or 'لا نرى معك رهائن.', MENU))
    end
end

local function onText(src, msg)
    local r = H.npcOf(src)
    if not r or r.phase ~= 'on scene' then return text(src, 'لا أعرف عمّا تتكلم.') end
    if r.rage then return text(src, 'انتهى الكلام. آذيت أحدهم.') end
    msg = tostring(msg or ''):gsub('%s+', '')
    local n = H.hostageCount(H.npcTargets(r))
    if msg == '1' or msg:find('مهل') then
        if n < 1 then return text(src, 'بلا رهائن لا مهلة. ' .. MENU) end
        if not H.releaseOne(src) then return text(src, 'أطلق واحدًا بنفسك وسنرى.') end
        H.npcHold(r, NG.headStartSeconds, 'deal')
        text(src, ('اتفقنا. رأيناه يخرج. معك %d ثانية، لن نطلق النار.'):format(NG.headStartSeconds))
        H.log(src, 'negotiate', 'head start')
    elseif msg == '2' or msg:find('انسحب') then
        if r.pulledBack then return text(src, 'انسحبنا مرة. لن نفعلها مرتين.') end
        if n < NG.pullBackHostages then return text(src, ('تحتاج %d رهائن على الأقل لهذا. معك %d.'):format(NG.pullBackHostages, n)) end
        r.pulledBack = true
        H.npcHold(r, NG.pullBackSeconds, 'pullback')
        if r.owner then TriggerClientEvent('exti_heists:client:npcPullBack', r.owner, r.id, NG.pullBackSeconds) end
        text(src, ('سنرجع إلى سياراتنا %d ثانية. لا تجعلنا نندم.'):format(NG.pullBackSeconds))
        H.log(src, 'negotiate', 'pull back')
    elseif msg == '3' or msg:find('استسلم') or msg:find('أستسلم') then
        H.releaseAll(src)
        if H.npcSurrender(src) then
            H.addXP(src, NG.surrenderXp, 'surrendered to NPC security')
            text(src, 'قرار ذكي. أخذنا ما سرقت. اختفِ.')
        end
    else
        text(src, 'لم أفهم. ' .. MENU)
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
