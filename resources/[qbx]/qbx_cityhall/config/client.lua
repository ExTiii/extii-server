return {
    useTarget = false,
    debugPoly = false,

    peds = {
        { -- Cityhall Ped
            model = 'a_m_m_hasjew_01',
            coords = vec4(-232.44, -915.57, 31.32, 334.49),
            scenario = 'WORLD_HUMAN_STAND_MOBILE',
            cityhall = true,
            groundFix = true, -- EX_Tii: stand on the real floor height once you are near
            zoneOptions = { -- Used for when UseTarget is false
                length = 3.0,
                width = 3.0,
                debugPoly = false,
            },
            -- EX_Tii: the spot in front of the employee: walk up and press E (no circle on the floor)
            circle = {
                show = false,        -- true = smooth gold circle on the floor again
                reach = 1.4,         -- how close you must be to press E (meters)
                distance = 1.15,     -- how far in front of the employee (meters)
                radius = 0.8,        -- size of the circle (meters, only when show = true)
                drawDistance = 90.0, -- you see it from this far away
                colour = { 232, 181, 71 },
            },
        },
    },
}