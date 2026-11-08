return {
	-- 0	vehicle has no storage
	-- 1	vehicle has no trunk storage
	-- 2	vehicle has no glovebox storage
	-- 3	vehicle has trunk in the hood
	Storage = {
		[`jester`] = 3,
		[`adder`] = 3,
		[`osiris`] = 1,
		[`pfister811`] = 1,
		[`penetrator`] = 1,
		[`autarch`] = 1,
		[`bullet`] = 1,
		[`cheetah`] = 1,
		[`cyclone`] = 1,
		[`voltic`] = 1,
		[`reaper`] = 3,
		[`entityxf`] = 1,
		[`t20`] = 1,
		[`taipan`] = 1,
		[`tezeract`] = 1,
		[`torero`] = 3,
		[`turismor`] = 1,
		[`fmj`] = 1,
		[`infernus`] = 1,
		[`italigtb`] = 3,
		[`italigtb2`] = 3,
		[`nero2`] = 1,
		[`vacca`] = 3,
		[`vagner`] = 1,
		[`visione`] = 1,
		[`prototipo`] = 1,
		[`zentorno`] = 1,
		[`trophytruck`] = 0,
		[`trophytruck2`] = 0,
		-- EX_Tii: the EMS fleet keeps its own trunk (exti_ems: press E at the back of the vehicle)
		[`ambulance`] = 0,
		[`lguard`] = 0,
	},

	-- EX_Tii (Moe): sizes in grams. The player's bag is 40 kg (server.cfg: inventory:weight 40000, inventory:slots 40).
	-- Every vehicle: glove box 4 kg (a couple of things), trunk 20 kg (groceries, not a shift).
	-- Storage cars (the dealership's "سيارات التخزين" section) carry more: see trunk.models below — the same
	-- numbers as `storage` in qbx_vehicleshop/config/catalog.lua, one slot per 2 kg.
	glovebox = {
		[0] = {4, 4000},		-- Compact
		[1] = {4, 4000},		-- Sedan
		[2] = {4, 4000},		-- SUV
		[3] = {4, 4000},		-- Coupe
		[4] = {4, 4000},		-- Muscle
		[5] = {4, 4000},		-- Sports Classic
		[6] = {4, 4000},		-- Sports
		[7] = {4, 4000},		-- Super
		[8] = {1, 1000},		-- Motorcycle (a pocket under the seat)
		[9] = {4, 4000},		-- Offroad
		[10] = {4, 4000},		-- Industrial
		[11] = {4, 4000},		-- Utility
		[12] = {4, 4000},		-- Van
		[14] = {10, 20000},	-- Boat (no trunk: the glove box is the locker)
		[15] = {10, 20000},	-- Helicopter
		[16] = {10, 20000},	-- Plane
		[17] = {4, 4000},		-- Service
		[18] = {4, 4000},		-- Emergency
		[19] = {4, 4000},		-- Military
		[20] = {4, 4000},		-- Commercial (trucks)
		models = {
		}
	},

	trunk = {
		[0] = {10, 20000},		-- Compact
		[1] = {10, 20000},		-- Sedan
		[2] = {10, 20000},		-- SUV
		[3] = {10, 20000},		-- Coupe
		[4] = {10, 20000},		-- Muscle
		[5] = {10, 20000},		-- Sports Classic
		[6] = {10, 20000},		-- Sports
		[7] = {10, 20000},		-- Super
		[8] = {3, 5000},		-- Motorcycle (saddlebags)
		[9] = {10, 20000},		-- Offroad
		[10] = {10, 20000},	-- Industrial
		[11] = {10, 20000},	-- Utility
		[12] = {10, 20000},	-- Van
		-- [14] -- Boat
		-- [15] -- Helicopter
		-- [16] -- Plane
		[17] = {10, 20000},	-- Service
		[18] = {10, 20000},	-- Emergency
		[19] = {10, 20000},	-- Military
		[20] = {10, 20000},	-- Commercial
		-- the storage cars: slots, grams (40 kg ... 180 kg, one slot per 2 kg)
		models = {
			[`bobcatxl`] = {20, 40000},
			[`rebel`] = {20, 40000},
			[`bison`] = {20, 40000},
			[`riata`] = {30, 60000},
			[`sadler`] = {30, 60000},
			[`everon`] = {30, 60000},
			[`contender`] = {40, 80000},
			[`kamacho`] = {40, 80000},
			[`sandking`] = {40, 80000},
			[`caracara2`] = {50, 100000},
			[`rumpo`] = {50, 100000},
			[`speedo`] = {50, 100000},
			[`pony`] = {60, 120000},
			[`youga`] = {60, 120000},
			[`burrito`] = {60, 120000},
			[`guardian`] = {70, 140000},
			[`rumpo3`] = {70, 140000},
			[`youga3`] = {70, 140000},
			[`benson`] = {80, 160000},
			[`mule`] = {80, 160000},
			[`mule5`] = {80, 160000},
			[`pounder`] = {90, 180000},
			[`mule3`] = {90, 180000},
			[`speedo4`] = {90, 180000},
		},
	}
}
