-- =====================================================================
-- EX_Tii gangs (game side): the Ammo press, the Weapons workbench and the black market buyer.
-- client/main.lua shows the [E] prompts and calls these.
-- =====================================================================
local CERR = {
    nogang = 'ليس لك شيء هنا', rank = 'للطاقم فما فوق', far = 'اقترب أكثر', locked = 'المقر مقفل: الإيجار غير مدفوع', busy = 'الآلة مشغولة',
    cooldown = 'الآلة تبرد: انتظر', rep = 'سمعة العصابة لا تكفي لهذا بعد', daily = 'وصلتم حد اليوم', parts = 'القطع في المخزن لا تكفي',
    bad = 'اختيار غير صحيح', nothing = 'ليس معك شيء يشتريه', notcorner = '', stashfull = 'مخزن العصابة ممتلئ: أفرغوه قليلًا', full = 'حقيبتك ممتلئة',
}
local function cfail(why, extra)
    local t = CERR[why] or 'لم ينجح'
    if why == 'cooldown' and extra then t = ('%s (%d:%02d)'):format(t, extra // 60, extra % 60) end
    if why == 'parts' and extra then t = ('%s (تحتاج %d)'):format(t, extra) end
    GC.notify(t, 'error')
end
local function money(n) return '$' .. tostring(math.floor(n or 0)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '') end

local STEPS = {
    ammo = {
        { game = 'melt', title = 'اصهر الرصاص: أبقِ الحرارة في المنطقة الخضراء', anim = { 'mini@repair', 'fixing_a_ped' }, pad = 'يذوب الرصاص...' },
        { game = 'press', title = 'اضغط الأظرف تحت المكبس', anim = { 'mini@repair', 'fixing_a_ped' }, pad = 'تبرد الأظرف...' },
        { game = 'boxfill', title = 'عبّئ الطلقات في العلبة', anim = { 'anim@amb@business@cfm@cfm_counting_notes@', 'note_counting_v2_counter' }, pad = 'تغلق العلب...' },
    },
    weapons = {
        { game = 'file', title = 'اِبرد الهيكل: A ثم D بالتناوب', anim = { 'mini@repair', 'fixing_a_ped' }, pad = 'تنظّف الهيكل...' },
        { game = 'assemble', title = 'ركّب القطع بنفس الترتيب', anim = { 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', 'weed_spraybottle_crouch_base_inspector' }, pad = 'تشدّ البراغي...' },
        { game = 'range', title = 'جرّب السلاح: أصب الهدف 5 مرات', anim = { 'mini@repair', 'fixing_a_ped' }, pad = 'تنظّف السبطانة...' },
    },
}

local function padTo(startedAt, seconds, label)
    local left = seconds - (GetGameTimer() - startedAt) / 1000 + 1
    if left <= 0.5 then return true end
    return lib.progressBar({ duration = math.floor(left * 1000), label = label, canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 } })
end

local function run(choice, amount)
    local ok, info, extra = lib.callback.await('exti_gangs:server:craftBegin', false, choice, amount)
    if not ok then return cfail(info, extra) end
    local steps = STEPS[info.kind]
    local function stop()
        ClearPedTasks(PlayerPedId())
        lib.callback.await('exti_gangs:server:craftStop', false)
        GC.notify('توقف العمل: القطع ضاعت', 'error')
    end
    for i, st in ipairs(steps) do
        local t0 = GetGameTimer()
        lib.requestAnimDict(st.anim[1])
        TaskPlayAnim(PlayerPedId(), st.anim[1], st.anim[2], 3.0, 3.0, -1, 1, 0, false, false, false)
        local done = GC.minigame(st.game, ('%s (%d/3)'):format(st.title, i), { label = info.kind == 'ammo' and 'مكبس الذخيرة' or 'طاولة الأسلحة' })
        ClearPedTasks(PlayerPedId())
        if not done then return stop() end
        if not padTo(t0, info.seconds[i] or 12, st.pad) then return stop() end
        local fine, res = lib.callback.await('exti_gangs:server:craftStage', false, info.token, i)
        if not fine and res == 'fast' then Wait(2500); fine, res = lib.callback.await('exti_gangs:server:craftStage', false, info.token, i) end
        if not fine then return stop() end
        if i == 3 then
            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            GC.notify(info.kind == 'ammo' and ('صنعت %d طلقة (%s) إلى المخزن'):format(res.count, res.label) or ('صنعت %s إلى المخزن (بلا رقم تسلسلي)'):format(res.label), 'success', 7000)
        end
    end
end

function GC.craft()
    local ok, m = lib.callback.await('exti_gangs:server:craftMenu', false)
    if not ok then return cfail(m) end
    local opts = {}
    if m.cooldown > 0 then opts[#opts + 1] = { title = ('الآلة تبرد: %d:%02d'):format(m.cooldown // 60, m.cooldown % 60), icon = 'clock', readOnly = true } end
    opts[#opts + 1] = { title = m.type == 'ammo' and ('مواد ذخيرة في المخزن: %d · يبقى اليوم %d طلقة'):format(m.parts, m.left)
                        or ('قطع أسلحة في المخزن: %d · يبقى اليوم %d سلاح'):format(m.parts, m.left), icon = 'box', readOnly = true }
    for _, it in ipairs(m.list) do
        opts[#opts + 1] = {
            title = it.label, icon = m.type == 'ammo' and 'circle-dot' or 'gun',
            description = it.open and (m.type == 'ammo' and ('1 مادة = %d طلقة'):format(m.perMaterial) or ('%d قطعة'):format(it.parts)) or ('يُفتح في السمعة %d'):format(it.rep),
            disabled = not it.open or m.cooldown > 0,
            onSelect = function()
                if m.type == 'ammo' then
                    local max = math.max(1, math.min(m.batchMax, m.parts, math.floor(m.left / m.perMaterial)))
                    local input = lib.inputDialog(it.label, { { type = 'number', label = 'كم مادة؟', description = ('كل مادة = %d طلقة'):format(m.perMaterial), min = 1, max = max, default = max, required = true } })
                    local n = input and tonumber(input[1])
                    if not n then return end
                    CreateThread(function() run(it.i, math.floor(n)) end)
                else
                    CreateThread(function() run(it.i) end)
                end
            end,
        }
    end
    lib.registerContext({ id = 'exti_gang_craft', title = m.type == 'ammo' and 'مكبس الذخيرة' or 'طاولة الأسلحة', options = opts })
    lib.showContext('exti_gang_craft')
end

---------------------------------------------------------------------------
-- the black market buyer
---------------------------------------------------------------------------
function GC.blackMarket()
    local ok, r = lib.callback.await('exti_gangs:server:blackMarket', false, true)
    if not ok then return cfail(r) end
    if #r.offer == 0 then return GC.notify('"ما عندك شي يهمني. آخذ فقط أسلحة العصابات بلا رقم، والذخيرة من صنّاعها."', 'inform', 6000) end
    local lines = {}
    for _, o in ipairs(r.offer) do lines[#lines + 1] = ('%s × %d · %s'):format(o.label, o.count, money(o.price * o.count)) end
    local opts = { { title = ('العرض: %s (مال غير نظيف)'):format(money(math.min(r.total, r.room))), description = table.concat(lines, '\n'), icon = 'sack-dollar', readOnly = true } }
    if r.room < r.total then opts[#opts + 1] = { title = ('يشتري منك اليوم حتى %s فقط'):format(money(r.room)), icon = 'circle-info', readOnly = true } end
    opts[#opts + 1] = { title = 'بِع', icon = 'handshake', disabled = r.room < 1, onSelect = function()
        local done, paid = lib.callback.await('exti_gangs:server:blackMarket', false, false)
        if not done then return cfail(paid) end
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', false)
        GC.notify(('بعت بـ %s مال غير نظيف'):format(money(paid)), 'success')
    end }
    lib.registerContext({ id = 'exti_gang_bm', title = 'السوق السوداء', options = opts })
    lib.showContext('exti_gang_bm')
end
