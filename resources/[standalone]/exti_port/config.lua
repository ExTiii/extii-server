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

-- the doors by the water: a panel of the fence itself that swings open on its own when someone on foot
-- comes this close, and closes again once nobody has been next to it for this long
Config.doorReach = 1.8
Config.doorCloseMs = 1500
