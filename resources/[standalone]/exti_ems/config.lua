-- =====================================================================
-- EX_Tii EMS (الإسعاف): clocking in, uniforms, ambulances + helicopter, the supply cabinet,
-- reviving and treating people (paid per patient), the calls tablet with GPS, stretcher and
-- wheelchair. The hospitals themselves (beds, reception, pharmacy) are qbx_ambulancejob,
-- exti_hospital and exti_shops.
-- =====================================================================

Config = {}

Config.job = 'ambulance'          -- the qbx_core job (grades and pay every 10 minutes are in qbx_core/shared/jobs.lua)
Config.tabletKey = 'F6'           -- opens the EMS tablet (players can change it in GTA settings > key bindings > FiveM)

-- the rugged tablet your character holds. Its screen shows, live, the same page you use.
-- If the picture sits a bit off on the tablet, open the tablet and type /tablettune.
Config.tablet = {
    prop = `prop_cs_tablet`,
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base',
    bone = 60309, pos = vec3(0.03, 0.002, -0.0), rot = vec3(10.0, 160.0, 0.0),
    screenW = 1220, screenH = 776,   -- the size of the screen page (do not change)
    screen = { face = -1, push = 0.0015, insetLong = 0.050, insetShort = 0.070, scale = 1.000, shiftLong = 0.0040, shiftShort = 0.0000, rot = 2, mirror = false, w = 1.0, both = true }, -- lined up in game with /tablettune
    othersDistance = 20.0,           -- other medics' tablets show a locked EMS screen within this distance
}

-- kneeling next to a patient on the ground while you examine them
Config.examKneel = { dict = 'amb@medic@standing@kneel@base', clip = 'base' }

-- paid to the medic's bank for each patient (on top of the job pay)
Config.pay = {
    revive = 300,                 -- picking up someone who is down
    treat = 150,                  -- healing someone who is hurt (only paid when their health is below treatBelow)
}
Config.treatBelow = 85            -- %: treating someone healthier than this is free (no pay)
Config.payCooldown = 30           -- minutes: the same patient only pays again after this (no farming with friends)

-- joining EMS: the job application at the hospital reception, the chief hires from the tablet
Config.applications = {
    retryHours = 24,              -- after a "no", the same person can apply again after this
}

Config.items = {
    revive = 'firstaid',          -- revive kit (إسعافات أولية), from the supply cabinet
    treat = 'gauze',              -- gauze, from the supply cabinet or the pharmacy
}
-- EX_Tii (Moe): quick care needs no medical items any more, so the supply cabinet spot is gone (true brings it back)
Config.supplyCabinet = false
Config.reviveTime = 12            -- seconds of CPR
Config.treatTime = 6              -- seconds to treat
Config.reach = 2.5                -- how close to the patient you must be (meters)
Config.callExpire = 15            -- minutes: old calls disappear from the tablet

-- stretcher and wheelchair (medics on duty only). pos/rot = where they sit against the medic,
-- the patient, and the back of the ambulance. Admins can fine-tune them in game: /emstune
Config.equipment = {
    stretcher = {
        label = 'النقالة',
        model = 'v_med_emptybed',
        push = { pos = vec3(0.0, 1.55, -0.45), rot = vec3(0.0, 0.0, 180.0) },
        patient = { pos = vec3(0.0, 0.0, 0.17), rot = vec3(0.0, 0.0, 172.0), dict = 'anim@gangops@morgue@table@', clip = 'body_search' },
        vehicle = { pos = vec3(0.0, -1.75, 0.35), rot = vec3(0.0, 0.0, 0.0) },
    },
    wheelchair = {
        label = 'الكرسي المتحرك',
        model = 'prop_wheelchair_01',
        push = { pos = vec3(0.0, 0.85, -0.45), rot = vec3(0.0, 0.0, 180.0) },
        patient = { pos = vec3(0.0, 0.05, 0.42), rot = vec3(0.0, 0.0, 180.0), dict = 'missfinale_c2leadinoutfin_c_int', clip = '_leadin_loop2_lester' },
    },
    pushAnim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
    ambulances = { `ambulance` }, -- vehicles a stretcher can be loaded into
}

-- =====================================================================
-- starting the shift (like the video): clock in at the reception computer (drag your card onto
-- the sensor), change in the cloakroom, the team storage, your personal locker, the garages
-- =====================================================================

-- where things are in each hospital (E spots, no NPC). Admins can move any spot in game with
-- /emsspots (stand where you want it, pick the spot, done: it is saved in data/spots.json and
-- wins over the numbers here).
--   duty      = the reception computer: clock in / out
--   cloakroom = the uniforms
--   storage   = the team storage (from rank Config.storage.grade)
--   locker    = your personal locker (the same locker in every hospital)
--   supply    = the free supply cabinet (the ox_inventory shop 'AmbulanceArmory' from
--               qbx_ambulancejob, shopId = which of its locations)
--   garage    = ambulances (spawn = where the vehicle appears)
--   heli      = helicopters (the pad)
--   lift      = the lift between floors
Config.hospitals = {
    pillbox = {
        label = 'مستشفى بيلبوكس',
        duty = vec3(311.18, -599.25, 43.29),
        cloakroom = vec3(309.78, -596.60, 43.29),
        storage = vec3(310.45, -597.95, 43.29),
        locker = vec3(310.60, -601.15, 43.29),
        supply = { coords = vec3(309.93, -602.94, 43.29), shopId = 1 },
        garage = { coords = vec3(294.58, -574.76, 43.18), spawn = vec4(294.58, -574.76, 43.18, 35.79) },
        heli = { coords = vec3(351.58, -587.45, 74.16), spawn = vec4(351.58, -587.45, 74.16, 160.5) },
        lift = {
            { label = 'الطابق الأرضي', coords = vec4(298.62, -599.66, 43.29, 70.0) },
            { label = 'السطح (مهبط المروحية)', coords = vec4(338.54, -583.88, 74.17, 250.0) },
        },
    },
    paleto = {
        label = 'مركز باليتو الطبي',
        duty = vec3(-254.88, 6324.50, 32.58),
        supply = { coords = vec3(-254.90, 6328.50, 32.42), shopId = 2 },
        garage = { coords = vec3(-234.28, 6329.16, 32.15), spawn = vec4(-234.28, 6329.16, 32.15, 222.5) },
    },
}

-- the team storage: one per hospital, only from this rank up (2 = طبيب)
Config.storage = { label = 'مخزن الإسعاف', slots = 60, weight = 400000, grade = 2 }
-- your personal locker: only you can open it, the same one in every hospital
Config.locker = { label = 'خزانتك الشخصية', slots = 10, weight = 60000 }

-- the uniforms the cloakroom starts with (the first time only; after that the leader adds, edits
-- and deletes them in game and they are saved in the database). "زي المسعف" is the uniform from
-- the video: the light blue short-sleeve service shirt, the stethoscope, navy trousers, black shoes.
-- components = { component id, drawable, texture }  (3 arms, 4 trousers, 6 shoes, 7 neck,
-- 8 undershirt, 11 shirt/jacket ...);  props = { prop id, drawable, texture } (-1 = none)
-- grades = which ranks can wear it
Config.defaultOutfits = {
    male = {
        { label = 'زي المسعف', grades = { 0, 1, 2, 3, 4 },
          components = { { 3, 0, 0 }, { 4, 25, 2 }, { 6, 10, 0 }, { 7, 126, 0 }, { 8, 15, 0 }, { 9, 0, 0 }, { 10, 0, 0 }, { 11, 337, 8 }, { 5, 0, 0 }, { 1, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'معطف الطبيب', grades = { 3, 4 },
          components = { { 3, 93, 0 }, { 4, 28, 0 }, { 6, 10, 0 }, { 7, 126, 0 }, { 8, 32, 3 }, { 9, 0, 0 }, { 10, 0, 0 }, { 11, 31, 7 }, { 5, 0, 0 }, { 1, 0, 0 } },
          props = { { 0, -1, 0 } } },
    },
    female = {
        { label = 'زي المسعفة', grades = { 0, 1, 2, 3, 4 },
          components = { { 3, 0, 0 }, { 4, 37, 2 }, { 6, 29, 0 }, { 7, 96, 0 }, { 8, 14, 0 }, { 9, 0, 0 }, { 10, 0, 0 }, { 11, 352, 8 }, { 5, 0, 0 }, { 1, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'معطف الطبيبة', grades = { 3, 4 },
          components = { { 3, 105, 0 }, { 4, 34, 0 }, { 6, 29, 0 }, { 7, 96, 0 }, { 8, 39, 3 }, { 9, 0, 0 }, { 10, 0, 0 }, { 11, 7, 1 }, { 5, 0, 0 }, { 1, 0, 0 } },
          props = { { 0, -1, 0 } } },
    },
}
Config.maxOutfits = 12            -- per men / women

-- the EMS vehicles (the team's fleet, like the video): every vehicle has its own plate and its own
-- trunk that keeps what you leave in it between shifts. The leader buys / sells vehicles in the
-- garage (paid from the EMS account in the bank).
Config.fleet = {
    plate = 'EMS',               -- every EMS plate starts with this (EMS + 5 letters/numbers)
    trunk = { slots = 30, weight = 200000 },
    sellBack = 0.5,              -- selling a vehicle gives back this much of its price
    max = 20,                    -- how many vehicles the team can own
    models = {
        ambulance = { label = 'سيارة إسعاف', kind = 'ground', price = 45000 },
        lguard = { label = 'سيارة إنقاذ', kind = 'ground', price = 38000 },
        polmav = { label = 'مروحية الإسعاف', kind = 'air', price = 250000, livery = 1 },
    },
    start = { 'ambulance', 'ambulance', 'lguard', 'polmav' }, -- what the team has the first time
}

Config.reachPoint = 1.6           -- how close to an E spot you must be (meters)
Config.vehicleReach = 4.0         -- in your ambulance / helicopter: how close to the garage / pad to return it

-- the small white circle on the floor at every spot (only medics see it)
Config.circle = { size = 1.0, color = { 255, 255, 255 }, distance = 20.0 }

-- what the calls are called on the tablet
Config.callLabels = {
    down = 'مواطن مصاب على الأرض',
    reception = 'مريض ينتظر في الاستقبال',
    phone = 'اتصال طوارئ',
}
