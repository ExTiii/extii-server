---Represents a function that calculates a fee based on vehicle data.
---
---The function receives a vehicle identifier and a model name,
---retrieves or derives the necessary vehicle information,
---and returns a numeric fee based on custom logic.
---
---@alias FeeCalculator fun(vehicleId: number, modelName: string): number

-----------------------------------------------------------------------
-- EX_Tii: how the garages and impound lots look in the city
-----------------------------------------------------------------------
-- Map icons: a garage with a car inside (gold) and a car lifted by a tow hook (red),
-- grouped in their own sections of the map legend.
local GARAGE_BLIP = { name = 'مرآب سيارات', sprite = 524, color = 46, scale = 0.675, category = 'garage' }
local IMPOUND_BLIP = { name = 'ساحة حجز', sprite = 524, color = 1, scale = 0.675, category = 'impound' } -- EX_Tii: same icon as the garages, in red

-- The person waiting at each place (players talk to him in the gold circle in front of him)
local VALET = { model = 's_m_y_valet_01', scenario = 'WORLD_HUMAN_CLIPBOARD', role = 'موظف المرآب' }
local IMPOUND_CLERK = { model = 's_m_m_security_01', scenario = 'WORLD_HUMAN_GUARD_STAND', role = 'موظف الحجز' }
local HANGAR_CREW = { model = 's_m_y_airworker', scenario = 'WORLD_HUMAN_CLIPBOARD', role = 'موظف الحظيرة' }
local DOCK_CREW = { model = 's_m_y_dockwork_01', scenario = 'WORLD_HUMAN_CLIPBOARD', role = 'موظف المرسى' }

---One place where the attendant stands and cars come out / are parked.
---@param npc vector4 where the attendant stands and the way he faces (the gold circle is 1.2 m in front of him)
---@param car vector4 where the car is brought out, and the parking circle for cars
---@param blip table map icon
---@param label? string name shown on the screen for this place (impound lots)
local function point(npc, car, blip, label)
    return {
        coords = npc,
        spawn = car,
        dropPoint = car.xyz,
        blip = blip,
        label = label,
        useRadius = 0.65,     -- the gold circle in front of the attendant
        dropUseRadius = 3.0,  -- the parking circle for cars
    }
end

return {
    autoRespawn = false,   -- True == auto respawn cars that are outside into your garage on script restart, false == does not put them into your garage and players have to go to the impound
    warpInVehicle = false, -- If false, player will no longer warp into vehicle upon taking the vehicle out.
    doorsLocked = true, -- If true, the doors will be locked upon taking the vehicle out.
    distanceCheck = 5.0, -- The distance that needs to bee clear to let the vehicle spawn, this prevents vehicles stacking on top of each other
    calculateImpoundFee = function() return 500 end, -- EX_Tii: fixed $500 to get a lost car back (was 2% of the car price)
    -- Garage screen settings
    garageUi = {
        moveFee = 0,          -- EX_Tii: not used any more (a car parked in any garage comes out free at every garage)
        maxShares = 5,        -- how many friends can share the keys of one car
        transferTimeout = 30, -- seconds the other player has to accept a car you give them
    },
    -- EX_Tii: the impound staff take away vehicles that were left alone
    autoImpound = {
        enabled = true,
        ownedMinutes = 30,        -- a player's car left alone this long (owner in the city)...
        offlineMinutes = 10,      -- ...or this long after its owner logged out (a window for car thieves)
        ownedNobodyWithin = 35.0, -- ...is towed once no player is this close (meters; nobody sees it vanish)
        dumpedFee = 250,          -- a stolen player car the thief left: the owner pays only this
        looseMinutes = 15,        -- anything else (NPC cars someone drove, wrecks)...
        nobodyWithin = 100.0,     -- ...once no player is this close
        checkEvery = 30,          -- seconds between checks
        -- vehicles other scripts look after themselves (work trucks, tow job cars, a car being
        -- chopped, robbery trucks / prep cars / NPC security cars)
        keepStates = { 'exti_job', 'exti_broken', 'exti_keep', 'exti_chop', 'exti_truck', 'exti_prep', 'exti_npcsec' },
    },
    logging = {
        webhook = {
            error = nil,
            default = nil,
            anticheat = nil,
        },
    },

    ---@class GarageBlip
    ---@field name? string -- Name of the blip. Defaults to garage label.
    ---@field sprite? number -- Sprite for the blip. Defaults to 357
    ---@field color? number -- Color for the blip. Defaults to 3.

    ---The place where the player can access the garage and spawn a car
    ---@class AccessPoint
    ---@field coords vector4 where the garage menu can be accessed from
    ---@field blip? GarageBlip
    ---@field spawn? vector4 where the vehicle will spawn. Defaults to coords
    ---@field dropPoint? vector3 where a vehicle can be stored, Defaults to spawn or coords
    ---@field drawRadius? number draw distance for the garage marker (default: 60)
    ---@field dropDrawRadius? number draw distance for the drop-off marker (default: 60)
    ---@field useRadius? number interaction distance for the garage marker (default: 1)
    ---@field dropUseRadius? number interaction distance for the drop-off marker (default: 1.5)

    ---@class GarageConfig
    ---@field label string -- Label for the garage
    ---@field type? GarageType -- Optional special type of garage. Currently only used to mark DEPOT garages.
    ---@field vehicleType VehicleType -- Vehicle type
    ---@field groups? string | string[] | table<string, number> job/gangs that can access the garage
    ---@field shared? boolean defaults to false. Shared garages give all players with access to the garage access to all vehicles in it. If shared is off, the garage will only give access to player's vehicles which they own.
    ---@field states? VehicleState | VehicleState[] if set, only vehicles in the given states will be retrievable from the garage. Defaults to GARAGED.
    ---@field skipGarageCheck? boolean if true, returns vehicles for retrieval regardless of if that vehicle's garage matches this garage's name
    ---@field canAccess? fun(source: number): boolean checks access as an additional guard clause. Other filter fields still need to pass in addition to this function.
    ---@field accessPoints AccessPoint[]

    ---@type table<string, GarageConfig>

    garages = {
        -- Public car garages (EX_Tii: 5 in Los Santos, 3 around Sandy Shores, 3 in Paleto Bay)
        ls_legion = {
            label = 'مرآب ليجن سكوير (Legion Square)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(215.70, -808.72, 30.75, 252.28), vec4(221.10, -806.55, 29.90, 246.61), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        ls_alta = {
            label = 'مرآب ألتا (Alta)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(277.33, -346.64, 44.92, 249.45), vec4(283.64, -342.46, 44.14, 252.28), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        ls_grove = {
            label = 'مرآب غروف ستريت (Grove Street)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(65.78, -1715.27, 29.30, 51.02), vec4(64.72, -1722.17, 29.03, 48.19), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        ls_mirror = {
            label = 'مرآب ميرور بارك (Mirror Park)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(1033.33, -762.33, 58.00, 43.4), vec4(1029.31, -764.15, 57.20, 56.69), GARAGE_BLIP) }, -- EX_Tii: Moe's car spot
        },
        ls_vespucci = {
            label = 'مرآب شاطئ فسبوتشي (Vespucci Beach)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(-1247.59, -1425.99, 4.30, 294.0), vec4(-1242.51, -1425.51, 3.55, 124.72), GARAGE_BLIP) }, -- EX_Tii: Moe's car spot
        },
        sandy_shores = {
            label = 'مرآب ساندي شورز (Sandy Shores)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(1874.81, 3752.73, 32.97, 297.64), vec4(1876.09, 3758.77, 32.19, 212.60), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        sandy_route68 = {
            label = 'مرآب طريق 68 (Route 68)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(1133.11, 2664.31, 38.20, 90.0), vec4(1127.53, 2647.77, 37.22, 0.00), GARAGE_BLIP) }, -- EX_Tii: Moe's car spot
        },
        sandy_grapeseed = {
            label = 'مرآب غريبسيد (Grapeseed)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(1696.04, 4785.14, 42.00, 82.20), vec4(1691.63, 4777.98, 41.14, 87.87), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        paleto_north = {
            label = 'مرآب باليتو الشمالي (Paleto North)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(140.68, 6614.06, 32.08, 184.25), vec4(140.84, 6607.27, 31.07, 181.42), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        paleto_east = {
            label = 'مرآب باليتو الشرقي (Paleto East)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(95.80, 6364.10, 31.37, 22.68), vec4(95.04, 6373.11, 30.44, 11.34), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },
        paleto_west = {
            label = 'مرآب باليتو الغربي (Paleto West)',
            vehicleType = VehicleType.CAR,
            skipGarageCheck = true, -- EX_Tii: a car parked in any garage can be taken out here, free
            attendant = VALET,
            accessPoints = { point(vec4(-332.55, 6158.61, 31.49, 121.89), vec4(-338.68, 6159.02, 30.71, 133.23), GARAGE_BLIP) }, -- EX_Tii: Moe's spots
        },

        -- Aircraft hangars and boat docks
        intairport = {
            label = 'حظيرة طائرات المطار',
            vehicleType = VehicleType.AIR,
            skipGarageCheck = true, -- EX_Tii: take it out at any hangar / dock, free
            attendant = HANGAR_CREW, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'حظيرة طائرات',
                        sprite = 359, -- EX_Tii: plane hangar icon
                        color = 46, -- EX_Tii: gold like the car garages
                        category = 'garage',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(-1025.90, -3018.06, 13.95, 331.99), -- EX_Tii: where the attendant stands
                    spawn = vec4(-979.2, -2995.51, 13.95, 52.19),
                    dropUseRadius = 4.0,
                    drawRadius = 100,
                    dropDrawRadius = 250,
                }
            },
        },
        higginsheli = {
            label = 'هيغينز للمروحيات (Higgins Helitours)',
            vehicleType = VehicleType.AIR,
            skipGarageCheck = true, -- EX_Tii: take it out at any hangar / dock, free
            attendant = HANGAR_CREW, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'حظيرة مروحيات',
                        sprite = 360, -- EX_Tii: helicopter hangar icon
                        color = 46, -- EX_Tii: gold like the car garages
                        category = 'garage',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(-721.35, -1471.82, 5.00, 140.00), -- EX_Tii: where the attendant stands
                    spawn = vec4(-724.83, -1443.89, 5.0, 140.0),
                    dropUseRadius = 4.0,
                    drawRadius = 100,
                    dropDrawRadius = 250,
                }
            },
        },
        airsshores = {
            label = 'حظيرة طائرات ساندي شورز (Sandy Shores)',
            vehicleType = VehicleType.AIR,
            skipGarageCheck = true, -- EX_Tii: take it out at any hangar / dock, free
            attendant = HANGAR_CREW, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'حظيرة طائرات',
                        sprite = 359, -- EX_Tii: plane hangar icon
                        color = 46, -- EX_Tii: gold like the car garages
                        category = 'garage',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(1758.47, 3297.08, 41.15, 142.60), -- EX_Tii: where the attendant stands
                    spawn = vec4(1740.88, 3278.99, 41.09, 189.46),
                    dropUseRadius = 4.0,
                    drawRadius = 100,
                    dropDrawRadius = 250,
                }
            },
        },
        lsymc = {
            label = 'مرسى نادي اليخوت (LSYMC)',
            vehicleType = VehicleType.SEA,
            skipGarageCheck = true, -- EX_Tii: take it out at any hangar / dock, free
            attendant = DOCK_CREW, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'مرسى القوارب',
                        sprite = 356,
                        color = 46, -- EX_Tii: gold like the car garages
                        category = 'garage',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(-795.08, -1509.77, 1.60, 201.55), -- EX_Tii: where the attendant stands
                    spawn = vec4(-793.58, -1501.4, 0.12, 111.5),
                    dropUseRadius = 3.0,
                    dropDrawRadius = 100,
                }
            },
        },
        paleto = {
            label = 'مرسى باليتو (Paleto)',
            vehicleType = VehicleType.SEA,
            skipGarageCheck = true, -- EX_Tii: take it out at any hangar / dock, free
            attendant = DOCK_CREW, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'مرسى القوارب',
                        sprite = 356,
                        color = 46, -- EX_Tii: gold like the car garages
                        category = 'garage',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(-276.62, 6636.10, 7.50, 40.51), -- EX_Tii: where the attendant stands
                    spawn = vec4(-289.2, 6637.96, 1.01, 45.5),
                    dropUseRadius = 3.0,
                    dropDrawRadius = 100,
                }
            },
        },
        millars = {
            label = 'مرسى ميلارز (Millars)',
            vehicleType = VehicleType.SEA,
            skipGarageCheck = true, -- EX_Tii: take it out at any hangar / dock, free
            attendant = DOCK_CREW, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'مرسى القوارب',
                        sprite = 356,
                        color = 46, -- EX_Tii: gold like the car garages
                        category = 'garage',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(1299.29, 4217.59, 33.91, 166.80), -- EX_Tii: where the attendant stands
                    spawn = vec4(1296.78, 4203.76, 30.12, 169.03),
                    dropUseRadius = 3.0,
                    dropDrawRadius = 100,
                }
            },
        },

        -- Job Garages
        -- EX_Tii: the police garage is exti_police now (the team's own cars). Cars someone stored
        -- here before still show up in every public garage. The old one was:
        --[[
        police = {
            label = 'الشرطة',
            vehicleType = VehicleType.CAR,
            groups = 'police',
            accessPoints = {
                {
                    coords = vec4(454.6, -1017.4, 28.4, 0),
                    spawn = vec4(438.4, -1018.3, 27.7, 90.0),
                }
            },
        },
        ]]

        -- Gang Garages
        ballas = {
            label = 'بالاس (Ballas)',
            vehicleType = VehicleType.CAR,
            groups = 'ballas',
            accessPoints = {
                {
                    coords = vec4(98.50, -1954.49, 20.84, 0),
                    spawn = vec4(98.50, -1954.49, 20.75, 335.73),
                }
            },
        },
        families = {
            label = 'لا فاميليا (La Familia)',
            vehicleType = VehicleType.CAR,
            groups = 'families',
            accessPoints = {
                {
                    coords = vec4(-811.65, 187.49, 72.48, 0),
                    spawn = vec4(-818.43, 184.97, 72.28, 107.85),
                }
            },
        },
        lostmc = {
            label = 'لوست (Lost MC)',
            vehicleType = VehicleType.CAR,
            groups = 'lostmc',
            accessPoints = {
                {
                    coords = vec4(957.25, -129.63, 74.39, 0),
                    spawn = vec4(957.25, -129.63, 74.39, 199.21),
                }
            },
        },
        cartel = {
            label = 'الكارتل (Cartel)',
            vehicleType = VehicleType.CAR,
            groups = 'cartel',
            accessPoints = {
                {
                    coords = vec4(1407.18, 1118.04, 114.84, 0),
                    spawn = vec4(1407.18, 1118.04, 114.84, 88.34),
                }
            },
        },

        -- Impound Lots
        impoundlot = {
            label = 'ساحة الحجز',
            type = GarageType.DEPOT,
            states = { VehicleState.OUT, VehicleState.IMPOUNDED },
            skipGarageCheck = true,
            vehicleType = VehicleType.CAR,
            attendant = IMPOUND_CLERK,
            -- EX_Tii: an impounded car can be picked up at any of these lots
            accessPoints = {
                point(vec4(407.96, -1624.48, 29.28, 218.27), vec4(417.26, -1627.71, 28.67, 138.90), IMPOUND_BLIP, 'ساحة حجز إنوسنس (Innocence Blvd)'), -- EX_Tii: Moe's spots
                point(vec4(-419.41, -1718.94, 19.52, 337.32), vec4(-424.17, -1715.24, 19.04, 252.28), IMPOUND_BLIP, 'ساحة حجز روجرز (Rogers Salvage)'), -- EX_Tii: Moe's spots
                point(vec4(-1069.07, -856.40, 4.90, 216.0), vec4(-1061.55, -853.98, 4.09, 218.27), IMPOUND_BLIP, 'ساحة حجز فسبوتشي (Vespucci)'), -- EX_Tii: Moe's car spot
                point(vec4(819.24, -1257.60, 26.35, 172.91), vec4(823.35, -1257.53, 25.64, 175.75), IMPOUND_BLIP, 'ساحة حجز لا ميسا (La Mesa)'), -- EX_Tii: Moe's spots
                point(vec4(-376.88, -150.55, 38.56, 294.80), vec4(-377.63, -147.13, 37.91, 297.64), IMPOUND_BLIP, 'ساحة حجز بيرتون (Burton)'), -- EX_Tii: Moe's spots
                point(vec4(1644.83, 3806.29, 35.11, 119.06), vec4(1637.34, 3805.00, 34.05, 218.27), IMPOUND_BLIP, 'ساحة حجز ساندي شورز (Sandy Shores)'), -- EX_Tii: Moe's spots
                point(vec4(2363.31, 3123.32, 48.20, 252.28), vec4(2365.60, 3127.36, 47.49, 257.95), IMPOUND_BLIP, 'ساحة حجز الخردة (Sandy Scrapyard)'), -- EX_Tii: Moe's spots
                point(vec4(574.95, 2742.22, 42.15, 192.76), vec4(577.27, 2736.21, 41.24, 184.25), IMPOUND_BLIP, 'ساحة حجز هارموني (Harmony)'), -- EX_Tii: Moe's spots
                point(vec4(-215.54, 6218.91, 31.49, 223.94), vec4(-208.13, 6219.94, 30.71, 226.77), IMPOUND_BLIP, 'ساحة حجز وسط باليتو (Paleto Center)'), -- EX_Tii: Moe's spots
                point(vec4(-445.73, 6023.50, 31.49, 314.65), vec4(-438.20, 6028.80, 30.56, 31.18), IMPOUND_BLIP, 'ساحة حجز شرطة باليتو (Paleto Sheriff)'), -- EX_Tii: Moe's spots
                point(vec4(32.20, 6542.16, 31.45, 119.06), vec4(24.67, 6531.35, 30.66, 39.69), IMPOUND_BLIP, 'ساحة حجز باليتو الشمالية (Paleto North)'), -- EX_Tii: Moe's spots
            },
        },
        airdepot = {
            label = 'حجز الطائرات',
            type = GarageType.DEPOT,
            states = { VehicleState.OUT, VehicleState.IMPOUNDED },
            skipGarageCheck = true,
            vehicleType = VehicleType.AIR,
            attendant = IMPOUND_CLERK, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'حجز الطائرات',
                        sprite = 359, -- EX_Tii: same icon as the plane hangars, in red
                        color = 1, -- EX_Tii: red like the car impound lots
                        category = 'impound',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(-1237.09, -3381.16, 13.93, 56.69), -- EX_Tii: where the attendant stands (Moe's spot)
                    spawn = vec4(-1269.03, -3376.7, 13.94, 330.32),
                }
            },
        },
        seadepot = {
            label = 'حجز القوارب (LSYMC)',
            type = GarageType.DEPOT,
            states = { VehicleState.OUT, VehicleState.IMPOUNDED },
            skipGarageCheck = true,
            vehicleType = VehicleType.SEA,
            attendant = IMPOUND_CLERK, -- EX_Tii
            accessPoints = {
                {
                    blip = {
                        name = 'حجز القوارب',
                        sprite = 356,
                        color = 1, -- EX_Tii: red like the car impound lots
                        category = 'impound',
                    },
                    useRadius = 0.65, -- EX_Tii: the small gold circle in front of the attendant
                    coords = vec4(-771.82, -1431.91, 1.60, 48.03), -- EX_Tii: where the attendant stands
                    spawn = vec4(-729.77, -1355.49, 1.19, 142.5),
                }
            },
        },
    },
}