return {
    finance = {
        minimumDown = 10, -- minimum percentage allowed down
        maximumPayments = 24, -- maximum payments allowed
        enable = false, -- EX_Tii: no paying in parts. Turning this off does not affect already financed vehicles
        zone = vec3(-29.53, -1103.67, 26.42), -- Where the finance menu is located
    },

    enableFreeUseBuy = true, -- Allows players to buy from the dealership panel
    enableTestDrive = true,

    -- EX_Tii: what each dealership sells is set in config/catalog.lua

    ---@type table<string, Dealership>
    shops = {
        pdm = {
            type = 'free-use',
            zone = {
                shape = {
                    vec3(-56.727394104004, -1086.2325439453, 26.0),
                    vec3(-60.612808227539, -1096.7795410156, 26.0),
                    vec3(-58.26834487915, -1100.572265625, 26.0),
                    vec3(-35.927803039551, -1109.0034179688, 26.0),
                    vec3(-34.427627563477, -1108.5111083984, 26.0),
                    vec3(-32.02657699585, -1101.5877685547, 26.0),
                    vec3(-33.342102050781, -1101.0377197266, 26.0),
                    vec3(-31.292987823486, -1095.3717041016, 26.0)
                },
                size = vec3(3, 3, 4),
                targetDistance = 1,
            },
            blip = {
                label = 'معرض السيارات',
                coords = vec3(-35.16, -1098.77, 26.42), -- EX_Tii: on the salesperson
                show = true,
                sprite = 810, -- EX_Tii: map icon plan
                color = 46, -- EX_Tii: gold like the garages
            },
            testDrive = {
                limit = 1.0, -- minutes
                endBehavior = 'return'
            },
            returnLocation = vec3(-32.77, -1095.75, 26.42),
            -- EX_Tii: the salesperson; players stand in the gold circle in front of him and press E
            salesperson = { coords = vec4(-35.16, -1098.77, 26.42, 70.4), model = 'ig_siemonyetarian', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            vehicleSpawns = {
                vec4(-61.35, -1110.31, 25.86, 71.01),
                vec4(-59.61, -1104.74, 25.85, 70.13),
                vec4(-52.96, -1113.49, 25.87, 71.53),
                vec4(-52.34, -1107.93, 25.87, 71.63),
                vec4(-44.27, -1116.36, 25.87, 71.7),
                vec4(-41.75, -1111.49, 25.87, 71.5),
            },
            -- 3D preview: the car stands here and turns; the camera looks from `camDir`
            preview = {
                coords = vec4(-45.4, -1098.2, 25.6, 130.0),
                camDir = vec2(0.79, 0.61),
                camHeight = 0.9,
                minDist = 3.4,
                maxDist = 6.5,
                ground = true,
            },
            showroomVehicles = {
                { coords = vec4(-45.65, -1093.66, 25.44, 69.5), vehicle = 'zentorno' },
                { coords = vec4(-48.27, -1101.86, 25.44, 294.5), vehicle = 'toros' },
                { coords = vec4(-39.6, -1096.01, 25.44, 66.5), vehicle = 'jubilee' },
                { coords = vec4(-51.21, -1096.77, 25.44, 254.5), vehicle = 'dubsta' },
                { coords = vec4(-40.18, -1104.13, 25.44, 338.5), vehicle = 'paragon' },
                { coords = vec4(-43.31, -1099.02, 25.44, 52.5), vehicle = 'hakuchou' },
                { coords = vec4(-50.66, -1093.05, 25.44, 222.5), vehicle = 'diablous' },
                { coords = vec4(-44.28, -1102.47, 25.44, 298.5), vehicle = 'nemesis' },
            },
        },

        boats = {
            type = 'free-use',
            zone = {
                shape = {
                    vec3(-729.39, -1315.84, 0),
                    vec3(-766.81, -1360.11, 0),
                    vec3(-754.21, -1371.49, 0),
                    vec3(-716.94, -1326.88, 0)
                },
                size = vec3(8, 8, 6),
                targetDistance = 10,
            },
            blip = {
                label = 'معرض القوارب',
                coords = vec3(-728.26, -1319.93, 1.84), -- EX_Tii: on the salesperson
                show = true,
                sprite = 410, -- EX_Tii: map icon plan
                color = 46, -- EX_Tii: gold like the garages
            },
            testDrive = {
                limit = 1.0,
                endBehavior = 'return'
            },
            returnLocation = vec3(-714.34, -1343.31, 0.0),
            -- EX_Tii: on the dock at the bottom of the stairs from the street
            salesperson = { coords = vec4(-728.26, -1319.93, 1.84, 228.5), model = 's_m_m_dockwork_01', scenario = 'WORLD_HUMAN_CLIPBOARD' },
            vehicleSpawns = {
                vec4(-727.87, -1353.1, -0.17, 137.09),
            },
            preview = {
                -- EX_Tii: boats are long, so the boat sits still in its slip (lined up with the docks) instead of turning
                coords = vec4(-737.84, -1340.83, -0.5, 229.5),
                spin = false,
                camDir = vec2(0.41, -0.91),
                camHeight = 1.8,
                minDist = 5.0,
                maxDist = 12.0,
                ground = false,
            },
            showroomVehicles = {
                { coords = vec4(-727.05, -1326.59, -0.50, 229.5), vehicle = 'seashark' },
                { coords = vec4(-732.84, -1333.5, -0.50, 229.5), vehicle = 'dinghy' },
                { coords = vec4(-737.84, -1340.83, -0.50, 229.5), vehicle = 'speeder' },
                { coords = vec4(-741.53, -1349.7, -0.50, 229.5), vehicle = 'marquis' },
            },
        },

        air = {
            type = 'free-use',
            zone = {
                shape = {
                    vec3(-1607.58, -3141.7, 12.99),
                    vec3(-1672.54, -3103.87, 12.99),
                    vec3(-1703.49, -3158.02, 12.99),
                    vec3(-1646.03, -3190.84, 12.99)
                },
                size = vec3(10, 10, 8),
                targetDistance = 5,
            },
            blip = {
                label = 'معرض الطائرات',
                coords = vec3(-1617.43, -3140.84, 13.98), -- EX_Tii: on the salesperson
                show = true,
                sprite = 251, -- EX_Tii: map icon plan
                color = 46, -- EX_Tii: gold like the garages
            },
            testDrive = {
                limit = 1.0,
                endBehavior = 'return'
            },
            returnLocation = vec3(-1628.44, -3104.7, 13.94),
            -- EX_Tii: in front of the hangar office
            salesperson = { coords = vec4(-1617.43, -3140.84, 13.98, 56.69), model = 's_m_m_pilot_01', scenario = 'WORLD_HUMAN_STAND_MOBILE' },
            vehicleSpawns = {
                vec4(-1617.49, -3086.17, 13.94, 329.2),
            },
            preview = {
                coords = vec4(-1653.9, -3146.5, 13.2, 200.0),
                camDir = vec2(0.52, 0.86),
                camHeight = 2.5,
                minDist = 9.0,
                maxDist = 30.0,
                ground = true,
            },
            showroomVehicles = {
                { coords = vec4(-1651.36, -3162.66, 12.99, 346.89), vehicle = 'maverick' },
                { coords = vec4(-1668.53, -3152.56, 12.99, 303.22), vehicle = 'luxor' },
                { coords = vec4(-1632.02, -3144.48, 12.99, 31.08), vehicle = 'buzzard2' },
            },
        },
    },
}
