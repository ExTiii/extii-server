Config = {}

-- true  = our thin gold line
-- false = GTA's own thick line (the old look)
-- An admin can also switch it in game, saved for everyone:  /gpsline gta   /gpsline thin
Config.enabled = true

-- The line: our server gold, and how wide it is (smaller = thinner).
-- /gpsline 2-16 changes the width live and saves it for everyone.
Config.colour = { 232, 181, 71 }
Config.width = 8
Config.minWidth, Config.maxWidth = 2, 16

-- GTA has two colour slots made for scripts. We paint the 1st gold and draw the line with it,
-- and make the 2nd see-through for the hidden route GTA uses to find the way.
Config.hudSlot = 128          -- HUD_COLOUR_SCRIPT_VARIABLE
Config.hiddenSlot = 165       -- HUD_COLOUR_SCRIPT_VARIABLE_2

-- GTA's own line (used when the thin line is off, or can't be drawn): blip colour 5 = yellow
Config.gtaColour = 5

-- How the line follows you
Config.offRoute = 30          -- metres away from the line, in a vehicle, before it finds the new way
Config.offRouteOnFoot = 60    -- the same on foot (walking to a bin or a car is fine)
Config.recomputeCooldown = 6000 -- ms: at least this long between two new ways
Config.wrongWay = 250         -- a way read from GTA must end this close to the place (else it's someone else's)
Config.nearEnd = 80           -- this close to the place, no new way is looked for
Config.sampleStep = 8         -- metres between the points read from GTA's way
Config.maxPoints = 120        -- points in one line (a very long trip is drawn in parts)
Config.maxLength = 12000      -- metres
Config.findTimeout = 2500     -- ms to wait for GTA to find the way
Config.lastBit = 60           -- the line also goes the last bit from the road to the place, when it is this close
Config.trimStep = 15          -- metres: the part of the line behind you is cut away every this many metres
Config.trimWindow = 500       -- metres of line ahead of you that are checked to find where you are on it

-- "Take me there" buttons (phone places and alerts, nearest impound, find my car, job HQ, new-player guide)
Config.arrive = 25            -- the route ends when you are this close
Config.pin = { sprite = 162, colour = 5, scale = 0.75, name = 'وجهتك' } -- yellow map pin, named after the place
