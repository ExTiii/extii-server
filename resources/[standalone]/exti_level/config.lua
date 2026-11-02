-- =====================================================================
-- EX_Tii Level: the player's level, 1 to 300.
-- XP only comes from real work (a job task, a patient revived, a car repaired, a suspect jailed...):
-- every script that pays for work also calls exports.exti_level:AddXP. Standing around, driving
-- for fun, chatting or being AFK on duty gives nothing.
-- The curve: about `hoursToMax` hours of steady work to reach the top (2.5 years at 5 h a day).
-- Early levels come fast, the late ones are slow. Level 10 ≈ 12 h, 50 ≈ 210 h, 100 ≈ 690 h,
-- 200 ≈ 2,250 h, 300 = 4,500 h.
-- =====================================================================

Config = {}

Config.maxLevel = 300
Config.hoursToMax = 4500      -- hours of steady work from level 1 to the top
Config.xpPerHour = 600        -- the XP an hour of steady work gives (the jobs are tuned to this)
Config.curve = 1.7            -- how much slower the late levels are (1 = every level the same)

-- anti-farm
Config.maxPerHour = 1500      -- the most XP anyone can get in one hour (2.5× steady work); more is dropped
Config.repeatMinutes = 30     -- the same thing (the same patient, the same suspect, the same car part)
                              -- only gives XP again after this many minutes

-- the XP card on screen (top of the screen) after every gain
Config.cardSeconds = 4.5
