-- =====================================================================
-- EX_Tii Level: the player's level, 1 to 300.
-- XP only comes from real work (a job task, a patient revived, a car repaired, a suspect jailed...):
-- every script that pays for work also calls exports.exti_level:AddXP. Standing around, driving
-- for fun, chatting or being AFK on duty gives nothing.
-- The curve: anchor points (Config.anchors): level 3 after 4 hours of starter work, 8 after 12 h, 15 after 30 h,
-- 22 after 60 h, 30 after 100 h, 40 after 160 h, 55 after 300 h, 75 after 500 h, 300 after about 4,500 h.
-- =====================================================================

Config = {}

Config.maxLevel = 300
-- EX_Tii (Moe, Nov 2026): the curve is a set of anchor points: total XP needed to reach a level. Between two
-- anchors every level costs the same. Built from the hours of work Moe wants (starter jobs give 150 XP an hour,
-- chicken 200, raisins 250, bread 300, fishing 350, metals 400, fabrics 450):
--   level 3 = 4 h · 8 = 12 h · 15 = 30 h · 22 = 60 h · 30 = 100 h · 40 = 160 h · 55 = 300 h · 75 = 500 h · 300 ≈ 4,500 h
Config.anchors = {
    { 1, 0 }, { 3, 600 }, { 8, 2200 }, { 15, 6700 }, { 22, 15700 }, { 30, 29700 }, { 40, 53700 },
    { 55, 116700 }, { 75, 206700 }, { 100, 350000 }, { 150, 700000 }, { 200, 1100000 }, { 300, 2000000 },
}
Config.xpPerHour = 300        -- a typical hour of work (for texts only: the jobs set their own XP per item)

-- anti-farm
Config.maxPerHour = 1500      -- the most XP anyone can get in one hour (2.5× steady work); more is dropped
Config.repeatMinutes = 30     -- the same thing (the same patient, the same suspect, the same car part)
                              -- only gives XP again after this many minutes

-- the XP card on screen (top of the screen) after every gain
Config.cardSeconds = 4.5
