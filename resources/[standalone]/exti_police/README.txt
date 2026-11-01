EX_Tii Police
=============

The station
- Spots with a white circle: clock in terminal, cloakroom (uniforms the chief designs), personal locker, armory,
  public forms desk, the seized items room (غرفة المصادرات), garages, heli pad. Admins move them with /policespots.

The tablet (F6 while on duty)
- Map (officers, cars and the 911 calls live: take a call, route to it, close it), chat, calendar, camera +
  gallery, form inbox, offences list (المخالفات), prison (السجن: inmates, time left, escaped, release early,
  their locker), CCTV (الكاميرات: look through the city cameras), management for the chief (money, members,
  ranks, log, and قوالب الفواتير = the offences the officers pick from, with the fine and the jail minutes).
- The records: المواطنون (search by name / ID / phone: licences, job, vehicles, charges, prison, warrants,
  the officers' notes, the reports and cases he is in), المركبات (by plate / model: the owner, where it is,
  open BOLOs), التقارير (incident / arrest reports), أوامر القبض (open / closed), التعاميم (BOLOs on a vehicle
  or a person; everyone on duty is told), القضايا (cases: suspects, officers, notes, photos from the gallery).

911 (البلاغات)
- The phone's services app (الطوارئ → الشرطة) and /911 <text> in the chat: every officer on duty gets the
  phone alert (blip + notification) and the call shows on the tablet map. Calls go away after
  Config.dispatch.expireMinutes.

CCTV (الكاميرات)
- Config.cctv.cameras: banks, 24/7 stores, Vangelico, the PD and hospital entrances. Mouse turns the camera
  (within limits), wheel zooms, ← → switch, Esc back. Admins aim their own view and type /cctvspot <n>.

The street (Z wheel → الشرطة, on duty, next to a player)
- تقييد / فك القيد (needs the handcuffs item from the armory), اصطحاب (he walks attached to you),
  إدخال إلى المركبة / إخراج, تفتيش الحقيبة, مصادرة الأسلحة (guns + ammo go to the seized room with their serials),
  مخالفة (the charge sheet).
- A cuffed player: hands behind the back, no running / fighting / bag / phone / driving / Z wheel. The cuffs stay
  across relogs and restarts; waking up at the hospital takes them off.

The charge sheet (محضر مخالفة)
- Tick the offences, write a note, "تحرير الغرامة": the fine lands as a bill in his bank (exti_bank). He pays it at
  a teller or an ATM (الفواتير) and the money goes to the police account. Every sheet is kept (exti_police_charges).
- The offences start from Config.charges.defaults (config.lua) and then live in the database: the chief edits them
  on the tablet.

The prison (Bolingbroke)
- Drive the cuffed person to the gate (Config.prison.intake, a white circle). Press E there (or open the sheet
  next to him): the سجن buttons work only at the gate with the person cuffed. "سجن فقط" when the fine was written
  earlier in the street.
- He is uncuffed, his whole bag goes to a locker (ox_inventory stash exti_prison_<citizenid>), he appears in the cells
  in the prison uniform with a time card on screen. The time runs only while he is in the city.
- Yard jobs (gold circles, Config.prison.works) take minutes off. Leaving the grounds (Config.prison.radius) for
  Config.prison.escapeSeconds = escaped: his clock stops, every officer on duty is told, the tablet marks him هارب.
- Time over (or an officer releases him from the tablet): outside the gate, own clothes, bag back.
- Admins: /prisonspot intake | spawn | release | work <electric|clean|gym> <n> | reset (saved in data/prison.json).

Tables: exti_police_shifts, _outfits, _fleet, _forms, _logs, _chats, _chat_messages, _calendar, _roles,
_offences, _charges, _prison, _notes, _reports, _warrants, _bolos, _cases, _case_items. Settings: config.lua.
