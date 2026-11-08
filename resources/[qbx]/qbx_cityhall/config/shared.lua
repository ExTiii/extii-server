return {
    cityhalls = {
        {
            coords = vec3(-232.44, -915.57, 32.30), -- EX_Tii: the job center (PostOP Couriers door, where the employee stands)
            showBlip = true,
            blip = {
                label = 'مركز التوظيف',
                shortRange = true,  -- EX_Tii: on the small map only when close (always on the big map)
                sprite = 457,       -- briefcase
                display = 4,
                scale = 0.675,      -- EX_Tii: the same size as every other icon
                colour = 0,         -- EX_Tii map icon plan: work = white
                fancy = false,      -- EX_Tii: just the briefcase (no ring or glow around it)
                glowRadius = 28.0,
                glowAlpha = 70,
            },
            licenses = {
                ['id'] = {
                    item = 'id_card',
                    label = 'الهوية',
                    cost = 50,
                },
                ['driver'] = {
                    item = 'driver_license',
                    label = 'رخصة القيادة',
                    cost = 50,
                },
                ['weapon'] = {
                    item = 'weaponlicense',
                    label = 'رخصة السلاح',
                    cost = 50,
                },
            },
        },
    },

    employment = {
        enabled = false, -- EX_Tii: jobs are taken at the exti_jobs job center (its own checks); the old menu is off
        jobs = {
            unemployed = 'عاطل عن العمل',
            trucker = 'سائق شاحنة',
            taxi = 'سائق أجرة',
            tow = 'سائق سحب',
            reporter = 'مراسل أخبار',
            garbage = 'عامل نظافة',
            bus = 'سائق حافلة',
        },
    },
}
