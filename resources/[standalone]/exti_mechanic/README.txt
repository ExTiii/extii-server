EX_Tii Mechanic (delivery A — the job)
======================================

The workshop (LS Customs, Burton)
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
- الطلبات, الفحص, متجر القطع, الداينو are placeholders until delivery B (wear, diagnostics, repairs, parts).

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
