EX_Tii GPS
==========

One thin gold route line instead of GTA's thick one.

GTA's route line has a fixed width, so GTA finds the way (hidden), this resource reads the points along it and
draws them as its own thin line. If that can't be done, GTA's own line is shown instead (nothing is ever left
without a line).

Who uses it
- exti_jobs: every pick-up and drop-off (delivery, garbage, tow) and "route to HQ".
- "Take me there" buttons: phone places and alerts (npwd_city), find my car (npwd_qbx_garages),
  nearest impound (qbx_garages), the new-player guide (city hall).
  These put a yellow pin named after the place. It goes away when you arrive (25 m) or put your own marker on the map.
- A marker you put on the map yourself keeps GTA's purple line (GTA doesn't let that one be thinner).
- Every caller falls back to the old way (GTA's line / map marker) when exti_gps isn't running.

Admin command (saved on the server, for everyone, live)
- /gpsline          show how it is now
- /gpsline 6        width 6 (2 to 16, smaller = thinner)
- /gpsline gta      back to GTA's old thick line
- /gpsline thin     the thin line again
- /gpsline reset    back to config.lua

Settings: config.lua (colour, default width, how far off the line before it finds a new way, the pin).

For other scripts (client):
  exports.exti_gps:Route(key, coords, { blip = myBlip })   -- line to your own map icon
  exports.exti_gps:ClearRoute(key)
  exports.exti_gps:GoTo(x, y, z, label)                    -- "take me there"
