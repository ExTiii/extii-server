EX_Tii Fuel
===========

Gas stations for the whole map (27 stations, 122 pumps). Replaces ox_fuel (ox_fuel is switched off in its fxmanifest).

What it does
- One gold map icon per station ("محطة وقود ومتجر"). The station store (exti_shops, type "fuel") has no icon of its own.
- A gold circle around every pump. Park within 6 m, get out, stand in the circle, press E.
- The pump screen: how full the tank is, choose full / $20 / $50 / $100 or any % with the slider,
  pay cash or card. The money is taken first; stop early with E and the unused part comes back.
- Nozzle in your hand + a hose from the pump while it runs, and a live card with liters and money.
- Electric cars (Config.electric) charge at the same pumps, priced per kWh, and lose battery by distance driven.
- Jerry can (WEAPON_PETROLCAN): bought at the pump. The pump screen has a strip "تريد جالون وقود معك؟" with
  cash / card buttons (Config.canPrice, full, 20 L). Walk up to a pump with no car at it and E opens the
  jerry can card straight away. Hold the can at a pump, E = fill it; hold it next to a car's fuel cap,
  E = pour it in (not into electric cars). No tables, no extra circles: every pump sells it.
  (Removed from the station stores in exti_shops: the pump is the only place that sells it.)

How the level is kept
- Entity(vehicle).state.fuel (0-100), set by the server only. The driver's game reports lower levels while driving.
- The HUD, garages (park / take out), impound lots, job vehicles, the tow job, vehiclehandler (/setfuel, /fix)
  and qbx_vehiclepush all use this same value.

Settings: config.lua (prices, pump speed, distances, tank sizes, electric list, station list).
Exports (server): GetFuel(vehicle), SetFuel(vehicle, level). Client: GetFuel(vehicle).
