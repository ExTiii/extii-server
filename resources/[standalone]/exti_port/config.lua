-- EX_Tii (Moe): the port terminal, fenced. The fence follows the corners an admin marks in game (/port corner),
-- in the order they were marked, and closes back to the first one. The gate and the doors are gaps in it.
Config = {}

Config.gateWidth = 12.0      -- metres: the opening at the front gate (two lanes)
Config.doorWidth = 2.2       -- metres: each little door by the water (one person)
Config.buildDistance = 350.0 -- the fence is there for you when you are this close to the terminal
Config.noClimb = 2.2         -- this close to the fence you can't jump or climb over it

-- the fence piece: the first of these that exists in the game is used (tall chain-link / security fence)
Config.fenceModels = {
    'prop_fncsec_03b', 'prop_fncsec_03a', 'prop_fncsec_03c', 'prop_fncsec_03d',
    'prop_fnclink_09a', 'prop_fnclink_10a', 'prop_fnclink_04a', 'prop_fnclink_03a', 'prop_fnclink_02a', 'prop_fnclink_01a',
}

-- the doors by the water: pushed open like GTA's house doors (as far as you walk into them), they swing
-- back shut by themselves
Config.doorPushSpeed = 420    -- degrees a second it can follow you at
Config.doorReturnSpeed = 110  -- degrees a second it swings back shut
Config.doorMaxAngle = 100     -- as far as it opens

-- small fence gates the door can be (the one closest to half a fence panel wide is used)
Config.doorModels = {
    'prop_fnclink_03gate1', 'prop_fnclink_03gate2', 'prop_fnclink_03gate3', 'prop_fnclink_03gate4', 'prop_fnclink_03gate5',
    'prop_fnclink_02gate1', 'prop_fnclink_02gate2', 'prop_fnclink_02gate3', 'prop_fnclink_02gate4', 'prop_fnclink_02gate5',
    'prop_fnclink_02gate6', 'prop_fnclink_02gate7', 'prop_fnclink_06gate2', 'prop_fnclink_06gate3', 'prop_fnclink_07gate1',
    'prop_fnclink_09gate1', 'prop_fnclink_04gate1', 'prop_fncsec_01gate', 'prop_facgate_04_l', 'prop_gate_farm_01a',
    'prop_facgate_04_r', 'prop_facgate_02_l', 'prop_facgate_02_r', 'prop_facgate_03_l', 'prop_facgate_03_r',
    'prop_gate_tep_01_l', 'prop_gate_tep_01_r', 'prop_gate_docks_ld', 'prop_fnclink_05gate1', 'prop_fnclink_08gate1',
    'prop_ld_fence_gate', 'prop_fncres_01gate1', 'prop_fncres_02gate1', 'prop_fnccorgm_05a',
}
