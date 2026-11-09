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

-- the doors by the water: a fence gate fills each one; [E] opens it for this long (then it closes)
Config.doorOpenSeconds = 6
Config.doorModels = {
    'prop_fnclink_03gate1', 'prop_fnclink_03gate2', 'prop_fnclink_02gate1', 'prop_fnclink_02gate2', 'prop_fnclink_02gate3',
    'prop_fnclink_06gate2', 'prop_fnclink_06gate3', 'prop_fnclink_07gate1', 'prop_fnclink_09gate1', 'prop_fnclink_04gate1',
    'prop_facgate_04_l', 'prop_gate_farm_01a',
}
