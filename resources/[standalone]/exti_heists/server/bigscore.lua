-- =====================================================================
-- EX_Tii heists: the Big Score (Tier 10). Once a week, for the Rep 10 crew whose leader claimed it from
-- the Broker (the three preps). Only inside its window (Fri and Sat nights, Gulf time). A gold truck
-- leaves the Union Depository with three escort cars of armed men; its GPS talks to the police for 5
-- minutes once it stops. Three C4 on the back doors, then the gold: 20-30 bars.
-- The truck engine is trucks.lua; this file is the gate in front of it.
-- =====================================================================
local C = Config

function H.startBigScore(src)
    local cid = H.cid(src)
    if not cid or H.isCopOnDuty(src) then return false, 'لا' end
    local test = H.bigScoreTest(cid)
    if not test then
        if not H.bigScoreOpen() then return false, 'ليس الآن. الجمعة والسبت بالليل فقط.' end
        local claim = H.bigScoreClaim()
        if claim.done then return false, 'حصلت هذا الأسبوع.' end
        if claim.by ~= cid then return false, 'ليست لك هذا الأسبوع.' end
    end
    if not H.near(src, vec3(C.trucks.bigscore.route[1].x, C.trucks.bigscore.route[1].y, C.trucks.bigscore.route[1].z), 400.0) then
        return false, 'تعال قرب مستودع الاتحاد أولًا.'
    end
    local ok, res = H.startTruck(src, 'bigscore', test)
    if ok then H.log(src, 'bigscore_start', test and 'TEST' or '') end
    return ok, ok and res.pos or res
end

-- when the gold truck is emptied (trucks.lua calls this)
function H.bigScoreFinished(crew, test)
    if test then return end   -- (an admin's test run: the real week stays open, no titles)
    H.bigScoreDone()
    for s in pairs(crew) do
        if GetPlayerName(s) then
            local n = H.countUp(s, 'bigscore')
            H.title(s, 'bigscore1', 'نفّذ الكبيرة')
            if n >= 10 then H.title(s, 'bigscore10', 'أسطورة المدينة: عشر مرات الكبيرة') end
        end
    end
end

H.registerHeist({ id = 'bigscore', label = 'الكبيرة (مستودع الاتحاد)', tier = 10, where = 'كل أسبوع · طاقم واحد', status = function(src)
    local claim = H.bigScoreClaim()
    if claim.done then return 'cooldown', 0, 'حصلت هذا الأسبوع' end
    if not H.bigScoreOpen() then return 'window', 0, 'الجمعة والسبت 20:00-02:00 (بتوقيت الخليج)' end
    if claim.by and claim.by ~= H.cid(src) then return 'busy', 0, 'لطاقم آخر هذا الأسبوع' end
    return claim.by and 'ready' or 'prep', 0, claim.by and 'لك: اكتب للوسيط "ابدأ"' or 'ثلاثة تحضيرات ثم "أطالب" عند الوسيط'
end })

-- admins: test the Big Score now (opens the window for an hour and gives you this week's claim)
lib.addCommand('bigscoretest', { help = 'Heists: open the Big Score for you for 1 hour (admin, testing)', restricted = 'group.admin' }, function(src)
    local cid = H.cid(src); if not cid then return end
    SetResourceKvp('bigscore_test', json.encode({ cid = cid, untilT = os.time() + 3600 }))
    H.notify(src, 'الكبيرة لك الآن لمدة ساعة (تجربة). اكتب للوسيط "ابدأ" قرب مستودع الاتحاد', 'success', 9000)
    H.log(src, 'bigscore_test', '')
end)
