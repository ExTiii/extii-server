EX_Tii Mechanic (A: the job · B: service · C1: tuning)
======================================

The workshop (Benny's Original Motor Works, Strawberry — like the video)
- Spots with a white circle: clock in terminal, cloakroom (overalls the manager designs), personal locker,
  the tool cabinet (الأدوات: repair kits, cleaning kits, wrench, flashlight — per rank, from Config.armory),
  the public forms desk, the parts shelf (رفّ القطع: a shared stash for the whole workshop), the garage
  (the tow trucks and vans from Config.fleet, plate MECH).
- Admins move the spots in game: /mechspots → pick the spot → it is saved where you stand (data/spots.json).

The job
- /setjob <id> mechanic <grade>. Grades (shared/jobs.lua): 0 متدرب, 1 ميكانيكي, 2 فني, 3 مشرف, 4 مدير (boss).
- The blip (446, orange) shows the workshop on the map; "في الخدمة" from the clock in terminal.

The tablet (F6 while on duty, /mechtablet)
- Map (the mechanics and the fleet live), chat, calendar, camera + gallery, the form inbox (the public
  forms: application / complaint / repair request REQ with the plate and what is wrong), قوالب الفواتير
  (the price list, read only), management for the manager (money, members, ranks, log, and the price list editor).
- الداينو is a placeholder until tuning step C2.

The bill (Z wheel → الورشة → فاتورة, on duty, next to the customer)
- Tick the services, write a note (the car, the plate, what was done), "إرسال الفاتورة": the bill lands in the
  customer's bank (exti_bank, society "mechanic"). He pays it from the branch, an ATM or the phone and the money
  goes to the workshop account (Renewed-Banking "mechanic"). Every bill is kept (exti_mechanic_charges).
- The services start from Config.charges.defaults (config.lua) and then live in the database: the manager edits
  them from the tablet (Management → قوالب الفواتير). No jail, ever — Config.charges.jail = false.

Money
- The manager's Management → الأموال: deposit / withdraw to the workshop account; the roster, salaries per rank
  (paid every Config.salaryInterval minutes to who is on duty), the hours log.

Tables: exti_mechanic_shifts, _outfits, _fleet, _forms, _logs, _chats, _chat_members, _chat_messages, _calendar,
_roles, _offences (the services), _charges (the bills), _gallery, _settings. Settings: config.lua.

Needs: exti_bank (Config.societies.mechanic), exti_radial (provider exti_mechanic:RadialMenu),
qbx_core shared/jobs.lua (job "mechanic"), support-arabic, ox_lib, ox_inventory, ox_target, Renewed-Banking.

SERVICE (part B)
- Wear: every car wears while driven (oil, air filter, coolant, spark plugs, brake pads, brake fluid, clutch,
  gearbox oil, tires; electric cars: battery, motor, coolant, brakes, tires). Owned cars and job fleets are
  saved by plate (exti_mechanic_wear); street cars live in memory. Life of each part: Config.service.components.
- What the driver feels: weak brakes, slipping clutch / stuck in first gear at 30 km/h, misfires, smoke, a dead
  engine (oil or coolant at 0), tires bursting, slower EVs. A warning when getting into a worn car.
- Repairs: on duty, next to any car: "[E] صيانة المركبة" -> every part with its %, the part item you need and how
  many you carry -> each repair is a set of mini-games (hold, keys, torque, pour, skill check, scrub) with the right
  animation. The part is used up only when it succeeds; the repair goes into the car's history (exti_mechanic_service).
- Wash (car_soap) and wax (car_wax: the car stays clean for Config.service.waxHours).
- Tablet → الفحص: stand next to a car (6 m): picture, plate, km, every part, engine/body, wax, service history.
- Tablet → متجر القطع: order parts with the workshop account (rank ميكانيكي+), ETA Config.parts.etaMinutes; the box
  appears at the delivery spot near the workshop (blip + box); "[E] استلام طلبيات القطع" puts it on the parts shelf.
- Repair kits (exti_tools: repairkit / advancedrepairkit) work for on-duty mechanics only; removed from public shops.
- Items: engine_oil, air_filter, coolant, spark_plugs, brake_pads, brake_fluid, clutch_kit, transmission_fluid,
  car_tire, ev_battery, ev_motor, car_soap, car_wax (pictures in html/items).
- Admin test: /carwear all 5  ·  /carwear engine_oil 0  (the car you sit in)

TUNING (part C, step 1: performance and looks)
- Two tuning bays at the workshop (big circles; admins move them: /mechspots → منصة التعديل 1 / 2).
- The customer drives HIS OWN car (in player_vehicles under his name) onto a bay, as the driver: "[E] قائمة التعديل".
  Only while at least one mechanic is on duty (Config.tuning.needMechanic).
- The menu: الأداء (engine / brakes / gearbox / suspension levels, turbo), الصبغ (primary / secondary with 6 finishes and any
  colour, pearl, wheel colour), الجنوط (every wheel type and wheel), الهيكل (every body part the car has, horn, liveries),
  الإضاءة (neon on/off + colour, xenon + colour), أخرى (window tint, plate style). Every pick shows on the car; the camera
  moves to the part (arrows / buttons turn it, mouse wheel zooms). Review → pay (bank, or cash if the bank is short): the
  money goes to the workshop account. The car goes back to how it was.
- A car with an open order: the bay shows the order; the customer can cancel (full refund) until the first change is installed.
- Tablet → الطلبات: open orders (who ordered, the car, every change, the parts still needed and how many you carry),
  استلم الطلب, إلغاء وإرجاع (the mechanic who took it or the manager: pays back what is not installed), finished orders,
  and الأسعار (the manager sets what the customer pays for each change).
- Installing: on duty, inside the workshop (Config.tuning.area), next to the car: "[E] الصيانة وتركيب التعديل" → the order's
  changes are at the top of the service menu → each one is mini-games with an animation (spray for paint). The parts are used
  up only on success; the change is put on the car and saved in player_vehicles.mods (stays after parking). The first install
  takes the order. When all are installed: the order is done, the car's history gets it, the customer is told.
- Parts (parts shop, category أداء / مظهر): engine_kit, brake_kit, trans_kit, susp_kit (one per level step up; going down
  needs none), turbo_kit, paint_can (paint, pearl, wheel colour, livery), wheel_set, body_kit (body parts, horn, plate),
  tint_film, neon_kit, xenon_kit.
- Tables: exti_mechanic_tune_orders, exti_mechanic_tune_prices. Settings: Config.tuning in config.lua.
