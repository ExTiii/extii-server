EX_Tii Driving School (exti_driveschool)
========================================
Nobody starts with a driving licence. Four licences, each with its own theory test and practical test.

The licences (config.lua -> Config.licences)
- car   رخصة قيادة السيارات   $250   12 questions (10 right), the city route in the school car, 70 km/h limit
- truck رخصة قيادة الشاحنات   $500   10 questions (8 right), a longer route in a box truck, 60 km/h — needs the car licence
- boat  رخصة قيادة القوارب    $400   10 questions (8 right), a course along the coast in a dinghy, no speed limit
- heli  رخصة الطيران          $2000  10 questions (8 right), checkpoints in the air, then land and stop on the pad

The schools (Config.schools): the city school (car + truck) at Rockford Plaza, the boat school at
Puerto del Sol marina, the flight school at the Vespucci helipad. Each has an instructor, a map icon
and a vehicle spot per licence.

How it works for a player
- Go to an instructor, press E, pick the licence, pay (cash or bank).
- Theory: random questions, the answers shuffled, 5 minutes. Fail = wait 2 minutes and pay again.
- Practical: the school vehicle appears with you inside. Follow the yellow points (road route for
  car / truck, markers on the water / in the air for boat / heli). A real crash fails you, leaving the
  vehicle for 8 s fails you, speeding (car / truck) 3 times fails you, time runs out = fail.
  /giveup to stop.
- Pass: the licence in your record (the police tablet sees it) and the card in your bag
  (driver_license / truck_license / boat_license / heli_license).

Police
- Tablet -> citizen record -> each licence has a "سحب" / "إرجاع" button. A suspended licence
  cannot be retaken at the school; the police have to give it back.

Admin
- /driveschoolspot <city|marina|heli> ped        moves that instructor to where you stand
- /driveschoolspot <school> <car|truck|boat|heli> moves that vehicle spot to where you stand (sit in a
                                                 boat on the water to place the boat spot)
- /driveschoolspot <school> reset                back to config.lua
- /dsroute <licence> add                         adds a route point where you are (drive / sail / fly the
                                                 route you want and type it at each point)
- /dsroute <licence> undo | clear | show         remove the last point / back to config / how many
  Saved in data/spots.json and data/routes.json.

First start
- The first time the resource starts it takes the car licence away from EVERY character in the
  database (once; remembered in the resource KVP "licences_wiped"). New characters never get one.
- qbx_core's starter items were trimmed to the phone only (config/shared.lua): the ID card is bought
  at city hall, the licences are earned here.
