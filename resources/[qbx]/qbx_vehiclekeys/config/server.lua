return {
    runClearCronMinutes = 5,
    distanceToHandKeys = 3,
    distanceToVehicle = 7.5,             -- Max distance (m) between a player and a vehicle for server-side key-grant events to be honored. Prevents granting keys to vehicles the player isn't actually next to.
    ---@type table<WeaponTypeGroup, number>
    carjackChance = {                    -- Probability of successful carjacking based on weapon used
        [WeaponTypeGroup.MELEE] = 0.0,
        -- EX_Tii (Moe): any gun on the driver: he always gives up the car and the keys
        [WeaponTypeGroup.HANDGUN] = 1.0,
        [WeaponTypeGroup.SMG] = 1.0,
        [WeaponTypeGroup.SHOTGUN] = 1.0,
        [WeaponTypeGroup.RIFLE] = 1.0,
        [WeaponTypeGroup.LMG] = 0.99,
        [WeaponTypeGroup.SNIPER] = 0.99,
        [WeaponTypeGroup.HEAVY] = 0.99,
        [WeaponTypeGroup.THROWABLE] = 0.0,
        [WeaponTypeGroup.MISC] = 0.0,
    },
}
