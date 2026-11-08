-- EX_Tii Fuel: every gas station, its pumps, prices and how fast vehicles use fuel / battery.
-- The fuel level lives on the vehicle (state "fuel", 0-100 %), the same value the HUD,
-- garages, impound lots, job vehicles and the mechanic already read. Nothing else to change.

Config = {}

-- prices (same at every station)
Config.pricePerLiter = 2        -- $ for 1 liter of fuel
Config.pricePerKWh = 1          -- $ for 1 kWh of electric charge
Config.minPrice = 1             -- the smallest bill

-- how fast the pump works
Config.litersPerSecond = 2.5    -- fuel pump
Config.kWhPerSecond = 3.0       -- electric charger
Config.minSeconds = 4           -- even a little top-up takes this long
Config.maxSeconds = 45          -- and a full big tank never takes longer than this

-- distances (meters)
Config.pumpRadius = 1.6         -- stand this close to the pump spot to press E
Config.pumpCircles = false      -- EX_Tii: no gold circle at the pumps (true = show it again)
Config.vehicleReach = 6.0       -- the vehicle must be parked this close to the pump
Config.stopDistance = 7.0       -- walking further from the pump than this stops the pump

-- jerry can: bought at any pump (the pump screen offers it; with no vehicle at the pump, E sells it
-- straight away), filled at any pump, poured into a vehicle anywhere
Config.canItem = 'WEAPON_PETROLCAN'
Config.canPrice = 120           -- the only place that sells it (removed from the exti_shops station stores)
Config.canLiters = 20           -- a full can holds this much
Config.canPourLitersPerSecond = 2.0
Config.canReach = 3.0           -- stand this close to the vehicle to pour

-- stations that also have a store (exti_shops, type "fuel"): only changes the name on the map
Config.storeStations = { [1] = true, [5] = true, [9] = true, [11] = true, [14] = true, [20] = true, [21] = true, [22] = true, [25] = true }

-- the look
Config.hose = true              -- a hose from the pump to the nozzle in your hand (false = nozzle only)

-- how fast vehicles use fuel
Config.fuelUseMultiplier = 10.0 -- GTA's own fuel use x this (the old fuel script used 10.0 too)
Config.leakWhenTankBelow = 700  -- a damaged fuel tank leaks a little
Config.reportEvery = 15         -- seconds between telling the server the new level while driving

-- electric vehicles: battery % goes down with the distance driven
Config.evRangeKm = 45           -- km on a full battery (GTA distances: the map is about 10 km tall)
Config.evIdlePerMinute = 0.25   -- % used per minute with the motor on and standing still

-- tank / battery size by vehicle category (qbx_core vehicle list). Liters for fuel, kWh for electric.
Config.tankLiters = {
    compacts = 45, sedans = 60, coupes = 55, muscle = 70, sportsclassics = 65, sports = 65, super = 70,
    suvs = 80, offroad = 80, vans = 90, motorcycles = 15, industrial = 200, utility = 120,
    commercial = 300, service = 150, emergency = 90, military = 200, boats = 150,
    helicopters = 300, planes = 400,
}
Config.defaultTankLiters = 60
Config.batteryKWh = { motorcycles = 15, utility = 40, industrial = 40 }
Config.defaultBatteryKWh = 75

-- electric vehicles (charge at the same pumps; no jerry can)
Config.electric = {
    'voltic', 'voltic2', 'raiden', 'neon', 'cyclone', 'cyclone2', 'tezeract', 'imorgon', 'khamelion',
    'surge', 'dilettante', 'dilettante2', 'omnisegt', 'virtue', 'iwagen', 'buffalo5', 'powersurge',
    'caddy', 'caddy2', 'caddy3', 'airtug',
}

-- the map icon of every station (fuel + its store)
Config.blip = { sprite = 361, colour = 47, scale = 0.675, label = 'محطة وقود ومتجر', labelNoStore = 'محطة وقود' }

-- pump models (to find the pump object for the hose)
Config.pumpModels = {
    `prop_gas_pump_old2`, `prop_gas_pump_1a`, `prop_vintage_pump`, `prop_gas_pump_old3`,
    `prop_gas_pump_1c`, `prop_gas_pump_1b`, `prop_gas_pump_1d`,
}

Config.stations = {
    { id = 1, label = 'غروف ستريت (Grove Street)', center = vec3(-71.28, -1761.16, 29.48),
      pumps = { vec3(-63.61, -1767.94, 28.26), vec3(-61.03, -1760.85, 28.30), vec3(-69.45, -1758.02, 28.54), vec3(-72.03, -1765.11, 28.53), vec3(-80.17, -1762.14, 28.80), vec3(-77.59, -1755.06, 28.81) } },
    { id = 2, label = 'ستروبيري (Strawberry)', center = vec3(264.74, -1260.98, 29.18),
      pumps = { vec3(256.43, -1253.46, 28.29), vec3(256.43, -1261.30, 28.29), vec3(256.43, -1268.64, 28.29), vec3(265.06, -1268.64, 28.29), vec3(265.06, -1261.30, 28.29), vec3(265.06, -1253.46, 28.29), vec3(273.84, -1253.46, 28.29), vec3(273.84, -1261.30, 28.29), vec3(273.84, -1268.64, 28.29) } },
    { id = 3, label = 'إل بورو (El Burro Heights)', center = vec3(1208.66, -1402.64, 35.22),
      pumps = { vec3(1212.94, -1404.03, 34.38), vec3(1210.06, -1406.90, 34.38), vec3(1204.20, -1401.03, 34.38), vec3(1207.07, -1398.16, 34.38) } },
    { id = 4, label = 'لا ميسا (La Mesa)', center = vec3(818.83, -1029.89, 26.17),
      pumps = { vec3(810.70, -1026.25, 25.44), vec3(810.70, -1030.94, 25.44), vec3(818.99, -1030.94, 25.44), vec3(818.99, -1026.25, 25.44), vec3(827.29, -1026.25, 25.64), vec3(827.29, -1030.94, 25.64) } },
    { id = 5, label = 'ميرور بارك (Mirror Park)', center = vec3(1181.27, -329.57, 69.18),
      pumps = { vec3(1186.39, -338.23, 68.36), vec3(1178.96, -339.54, 68.37), vec3(1177.46, -331.01, 68.32), vec3(1184.89, -329.70, 68.31), vec3(1183.13, -321.00, 68.35), vec3(1175.70, -322.31, 68.36) } },
    { id = 6, label = 'فاينوود (Vinewood)', center = vec3(621.07, 269.52, 103.04),
      pumps = { vec3(612.42, 273.96, 102.27), vec3(612.43, 263.84, 102.27), vec3(620.99, 263.84, 102.27), vec3(620.99, 273.97, 102.27), vec3(629.63, 273.97, 102.27), vec3(629.63, 263.84, 102.27) } },
    { id = 7, label = 'مورنينغوود (Morningwood)', center = vec3(-1437.58, -276.38, 46.21),
      pumps = { vec3(-1429.08, -279.15, 45.40), vec3(-1438.07, -268.70, 45.40), vec3(-1444.50, -274.23, 45.40), vec3(-1435.51, -284.69, 45.40) } },
    { id = 8, label = 'باسيفيك بلافس (Pacific Bluffs)', center = vec3(-2096.60, -318.15, 13.02),
      pumps = { vec3(-2088.76, -327.40, 12.16), vec3(-2088.09, -321.04, 12.16), vec3(-2087.22, -312.82, 12.16), vec3(-2096.10, -311.91, 12.16), vec3(-2096.81, -320.12, 12.16), vec3(-2097.48, -326.48, 12.16), vec3(-2106.07, -325.58, 12.16), vec3(-2105.40, -319.22, 12.16), vec3(-2104.54, -311.02, 12.16) } },
    { id = 9, label = 'ريتشمان غلين (Richman Glen)', center = vec3(-1799.03, 803.11, 138.40),
      pumps = { vec3(-1795.93, 811.96, 137.69), vec3(-1790.84, 806.40, 137.70), vec3(-1797.22, 800.55, 137.65), vec3(-1802.32, 806.11, 137.65), vec3(-1808.72, 799.95, 137.69), vec3(-1803.62, 794.39, 137.69) } },
    { id = 10, label = 'ليتل سيول الجنوبية (Little Seoul South)', center = vec3(-524.84, -1211.02, 18.18),
      pumps = { vec3(-522.23, -1217.42, 17.33), vec3(-524.93, -1216.15, 17.33), vec3(-529.52, -1213.96, 17.33), vec3(-532.29, -1212.72, 17.33), vec3(-528.58, -1204.80, 17.33), vec3(-525.81, -1206.04, 17.33), vec3(-521.22, -1208.23, 17.33), vec3(-518.53, -1209.50, 17.33) } },
    { id = 11, label = 'تاتافيام (Tataviam)', center = vec3(2581.56, 361.65, 108.46),
      pumps = { vec3(2588.41, 358.56, 107.65), vec3(2588.65, 364.06, 107.65), vec3(2581.17, 364.38, 107.65), vec3(2580.93, 358.89, 107.65), vec3(2573.54, 359.21, 107.65), vec3(2573.78, 364.71, 107.65) } },
    { id = 12, label = 'لا بويرتا (La Puerta)', center = vec3(-319.84, -1471.77, 30.55),
      pumps = { vec3(-329.82, -1471.64, 29.73), vec3(-324.75, -1480.41, 29.73), vec3(-317.26, -1476.09, 29.73), vec3(-322.33, -1467.32, 29.72), vec3(-314.92, -1463.04, 29.73), vec3(-309.85, -1471.80, 29.72) } },
    { id = 13, label = 'ديفيس (Davis)', center = vec3(175.31, -1561.73, 29.26),
      pumps = { vec3(181.81, -1561.97, 28.33), vec3(174.98, -1568.44, 28.33), vec3(169.30, -1562.27, 28.33), vec3(176.02, -1555.91, 28.33) } },
    { id = 14, label = 'ليتل سيول (Little Seoul)', center = vec3(-723.72, -935.51, 19.21),
      pumps = { vec3(-732.65, -932.52, 18.21), vec3(-732.65, -939.32, 18.21), vec3(-724.01, -939.32, 18.21), vec3(-724.01, -932.52, 18.21), vec3(-715.44, -932.52, 18.21), vec3(-715.44, -939.32, 18.21) } },
    { id = 15, label = 'زانكودو (Lago Zancudo)', center = vec3(-2555.31, 2334.01, 33.06),
      pumps = { vec3(-2551.40, 2327.12, 32.25), vec3(-2558.02, 2326.70, 32.26), vec3(-2558.48, 2334.13, 32.26), vec3(-2552.61, 2334.47, 32.25), vec3(-2552.40, 2341.89, 32.22), vec3(-2558.77, 2341.49, 32.23) } },
    { id = 16, label = 'طريق 68 الغربي (Route 68 West)', center = vec3(49.69, 2778.33, 57.88),
      pumps = { vec3(50.31, 2778.53, 57.04), vec3(48.91, 2779.59, 57.04) } },
    { id = 17, label = 'هارموني (Harmony)', center = vec3(264.15, 2607.05, 44.95),
      pumps = { vec3(264.98, 2607.18, 43.98), vec3(263.08, 2606.79, 43.98) } },
    { id = 18, label = 'هارموني الشرقية (Harmony East)', center = vec3(1207.56, 2660.20, 37.81),
      pumps = { vec3(1208.51, 2659.43, 36.90), vec3(1209.58, 2658.35, 36.90), vec3(1205.90, 2662.05, 36.90) } },
    { id = 19, label = 'صحراء سينورا (Grand Senora)', center = vec3(2538.00, 2593.83, 37.94),
      pumps = { vec3(2539.79, 2594.81, 36.96) } },
    { id = 20, label = 'طريق سينورا السريع (Senora Freeway)', center = vec3(2680.01, 3265.00, 55.24),
      pumps = { vec3(2680.90, 3266.41, 54.39), vec3(2678.51, 3262.34, 54.39) } },
    { id = 21, label = 'ساندي شورز (Sandy Shores)', center = vec3(2005.07, 3774.33, 32.18),
      pumps = { vec3(2009.25, 3776.77, 31.40), vec3(2006.21, 3774.96, 31.40), vec3(2003.91, 3773.48, 31.40), vec3(2001.55, 3772.20, 31.40) } },
    { id = 22, label = 'غريبسيد (Grapeseed)', center = vec3(1688.42, 4930.85, 42.08),
      pumps = { vec3(1684.59, 4931.66, 41.23), vec3(1690.09, 4927.80, 41.23) } },
    { id = 23, label = 'طريق 68 (Route 68)', center = vec3(1039.34, 2671.78, 39.55),
      pumps = { vec3(1043.22, 2674.45, 38.70), vec3(1035.44, 2674.44, 38.70), vec3(1035.44, 2667.90, 38.70), vec3(1043.22, 2667.91, 38.70) } },
    { id = 24, label = 'ساندي شورز الغربية (Sandy Shores West)', center = vec3(1785.58, 3330.47, 41.38),
      pumps = { vec3(1785.03, 3331.48, 40.34), vec3(1786.08, 3329.85, 40.41) } },
    { id = 25, label = 'طريق باليتو (Paleto Highway)', center = vec3(1702.79, 6416.86, 33.64),
      pumps = { vec3(1697.76, 6418.34, 31.76), vec3(1701.72, 6416.48, 31.76), vec3(1705.74, 6414.60, 31.76) } },
    { id = 26, label = 'باليتو باي (Paleto Bay)', center = vec3(179.94, 6602.60, 31.85),
      pumps = { vec3(186.97, 6606.22, 31.06), vec3(179.67, 6604.93, 31.06), vec3(172.33, 6603.64, 31.06) } },
    { id = 27, label = 'باليتو الغربية (Paleto West)', center = vec3(-93.98, 6420.10, 31.48),
      pumps = { vec3(-97.06, 6416.77, 30.64), vec3(-91.29, 6422.54, 30.64) } },
}

-- quick look-ups
Config.isElectric = {}
for _, name in ipairs(Config.electric) do Config.isElectric[joaat(name) & 0xFFFFFFFF] = true end

function Config.electricModel(model)
    return Config.isElectric[(tonumber(model) or 0) & 0xFFFFFFFF] == true
end
