-- =====================================================================
-- EX_Tii gangs (game side): the Money Wash. The drop box (anyone) and the machine (Crew and up).
-- client/main.lua shows the [E] prompts and calls these.
-- =====================================================================
local WERR = {
    far = 'اقترب أكثر', closed = 'الصندوق مقفل الآن', busy = 'لحظة...', amount = 'المبلغ غير صحيح', orders = 'عندك طلبات مفتوحة كثيرة هنا',
    queue = 'الصندوق ممتلئ الآن، عُد لاحقًا', nomoney = 'ليس معك هذا المبلغ من المال غير النظيف', notready = 'لا شيء جاهز بعد',
    nothing = 'لا يوجد ما يُلغى (ما في الآلة لا يُلغى)', nogang = 'ليس لك شيء هنا', rank = 'الغسيل للطاقم فما فوق', locked = 'المقر مقفل: الإيجار غير مدفوع',
    cooldown = 'الآلة تبرد: انتظر', daily = 'وصلتم حد الغسيل اليومي', empty = 'لا توجد طلبات في الصندوق', supplies = 'مواد الغسيل في المخزن لا تكفي',
}
local function wfail(why, extra)
    local t = WERR[why] or 'لم ينجح'
    if why == 'cooldown' and extra then t = ('%s (%d:%02d)'):format(t, extra // 60, extra % 60) end
    if why == 'supplies' and extra then t = ('%s (تحتاج %d)'):format(t, extra) end
    GC.notify(t, 'error')
end

local function money(n) return ('$%s'):format(tostring(math.floor(n or 0)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')) end

---------------------------------------------------------------------------
-- the drop box
---------------------------------------------------------------------------
function GC.dropBox(name)
    local ok, b = lib.callback.await('exti_gangs:server:washBox', false, name)
    if not ok then return wfail(b) end
    local opts = {
        { title = ('%s · النسبة %d%%'):format(b.label, b.cut), description = ('تضع مالًا غير نظيف، ويعود لك نظيفًا ناقص %d%%. طلباتك: %d من %d'):format(b.cut, b.orders, b.maxOrders),
          icon = 'circle-info', readOnly = true },
        { title = 'ضع مالًا غير نظيف', description = ('معك %s · من %s إلى %s'):format(money(b.dirty), money(b.min), money(b.max)), icon = 'sack-dollar',
          disabled = b.locked or b.dirty < b.min, onSelect = function()
            local input = lib.inputDialog('صندوق الغسيل', {
                { type = 'number', label = 'المبلغ (مال غير نظيف)', description = ('يعود لك نظيفًا ناقص %d%%'):format(b.cut),
                  min = b.min, max = math.min(b.max, b.dirty), default = math.min(b.max, b.dirty), required = true },
            })
            local amount = input and tonumber(input[1])
            if not amount then return end
            local done, r = lib.callback.await('exti_gangs:server:washDrop', false, name, math.floor(amount))
            if not done then return wfail(r) end
            PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', false)
            GC.notify(('وضعت %s · يعود لك %s نظيفًا عندما يُغسل (تعال إلى نفس الصندوق)'):format(money(r.amount), money(r.back)), 'success', 9000)
        end },
        { title = ('خذ مالك النظيف (%s)'):format(money(b.ready)), icon = 'money-bill-wave', disabled = b.ready < 1, onSelect = function()
            local done, n = lib.callback.await('exti_gangs:server:washCollect', false, name)
            if not done then return wfail(n) end
            PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', false)
            GC.notify(('أخذت %s نقدًا نظيفًا'):format(money(n)), 'success')
        end },
        { title = ('ألغِ ما لم يُغسل بعد (%s)'):format(money(b.waiting)), description = 'يعود لك المال غير النظيف كما هو', icon = 'rotate-left',
          disabled = b.waiting < 1, onSelect = function()
            local done, n = lib.callback.await('exti_gangs:server:washCancel', false, name)
            if not done then return wfail(n) end
            GC.notify(('استرجعت %s مالًا غير نظيف'):format(money(n)), 'inform')
        end },
    }
    lib.registerContext({ id = 'exti_gang_washbox', title = 'صندوق الغسيل', options = opts })
    lib.showContext('exti_gang_washbox')
end

---------------------------------------------------------------------------
-- the machine: 3 steps of work
---------------------------------------------------------------------------
local function padTo(startedAt, seconds, label)
    local left = seconds - (GetGameTimer() - startedAt) / 1000 + 1
    if left <= 0.5 then return true end
    return lib.progressBar({
        duration = math.floor(left * 1000), label = label, canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@business@cfm@cfm_counting_notes@', clip = 'note_counting_v2_counter', flag = 1 },
    })
end

local STEPS = {
    { game = 'sort', title = 'افرز الأوراق حسب الفئة', anim = { 'anim@amb@business@cfm@cfm_counting_notes@', 'note_counting_v2_counter' }, pad = 'ترتّب الأوراق...' },
    { game = 'drum', title = 'شغّل الآلة: أبقِ السرعة في المنطقة الخضراء', anim = { 'mini@repair', 'fixing_a_ped' }, pad = 'الآلة تدور...' },
    { game = 'band', title = 'عُدّ كل رزمة واربطها', anim = { 'anim@amb@business@cfm@cfm_counting_notes@', 'note_counting_v2_counter' }, pad = 'تربط الرزم...' },
}

function GC.washer()
    local ok, info, extra = lib.callback.await('exti_gangs:server:washBegin', false)
    if not ok then return wfail(info, extra) end
    GC.notify(('دفعة %s · %d مواد غسيل'):format(money(info.total), info.supplies), 'inform', 5000)
    local function stop()
        ClearPedTasks(PlayerPedId())
        lib.callback.await('exti_gangs:server:washStop', false)
        GC.notify('توقف الغسيل: عاد المال إلى الصندوق (المواد ضاعت)', 'error')
    end
    for i, st in ipairs(STEPS) do
        local t0 = GetGameTimer()
        lib.requestAnimDict(st.anim[1])
        TaskPlayAnim(PlayerPedId(), st.anim[1], st.anim[2], 3.0, 3.0, -1, 1, 0, false, false, false)
        local done = GC.minigame(st.game, ('%s (%d/3)'):format(st.title, i), { stacks = info.stacks, label = 'غسيل الأموال' })
        ClearPedTasks(PlayerPedId())
        if not done then return stop() end
        if not padTo(t0, info.seconds[i] or 15, st.pad) then return stop() end
        local fine, res = lib.callback.await('exti_gangs:server:washStage', false, info.token, i)
        if not fine and res == 'fast' then Wait(2500); fine, res = lib.callback.await('exti_gangs:server:washStage', false, info.token, i) end
        if not fine then return stop() end
        if i == 3 then
            PlaySoundFrontend(-1, 'Bus_Schedule_Pickup', 'DLC_PRISON_BREAK_HEIST_SOUNDS', false)
            GC.notify(('غُسلت %s · لبنك العصابة %s'):format(money(res.total), money(res.bank)), 'success', 8000)
            if res.mine > 0 then GC.notify(('حصّتك: %s نقدًا'):format(money(res.mine)), 'success', 8000) end
        end
    end
end
