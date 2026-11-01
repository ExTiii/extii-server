# EX_Tii Roleplay — server resources

Arabic FiveM roleplay server on Qbox (qbx_core + ox_lib + ox_inventory), built from scratch.
Everything in `resources/[standalone]/exti_*` is ours. The other folders hold only the files we
changed inside third-party resources (Qbox / ox) — copy them over a fresh install of that resource.

## What is here

| Resource | What it does |
|---|---|
| exti_characters | character selection / creation screen |
| exti_bank | bank, ATM, bills (fines land here), society accounts |
| exti_shops | 24/7, clothing and other shops |
| exti_fuel | fuel pumps, jerry can offer, EV charging |
| exti_gps | GPS / routes |
| exti_jobs | job center: tow, garbage, delivery (needs the car licence) |
| exti_ems / exti_medical / exti_hospital | EMS job, tablet, treatment, hospital |
| exti_police | police: station, tablet, street actions, charge sheet, prison, 911, CCTV, records |
| exti_driveschool | car / truck / boat / helicopter licences: theory + practical tests |
| exti_radial | the Z wheel (citizen, clothes, map, work, vehicle, police) |
| exti_world, exti_tools, exti_clock, exti_photo | small helpers |

Changed third-party files:
- `[qbx]/qbx_core/config/shared.lua` — starter items = phone only, notifications top-center
- `[qbx]/qbx_idcard/config/shared.lua` — card designs incl. truck / boat / heli licences
- `[ox]/ox_inventory/data/items.lua` — our items
- `[ox]/ox_lib/web/src/features/notifications/NotificationWrapper.tsx` + `resource/settings.lua` — notification look and place (rebuild `web` with `npm run build`)
- `[npwd-apps]/npwd_city/server.lua` — police calls from the phone go to the police tablet

`server.cfg.example` is the live config with the secrets removed. The real `server.cfg` is never committed.

## Deploying
Copy the folder into `txData/<profile>/resources/` on the server, make sure every `exti_*` is ensured in
`server.cfg` (`ensure [standalone]` covers them), restart from txAdmin.

## Before launch (checklist)
- regenerate the Cfx licence key, change the database password and the txAdmin password
- remove `exti_devcam`, remove `set sv_master1 ""`, delete the duplicate npwd folder
- `[qbx]/qbx_core/config/server.lua`: `checkDuplicateLicense = true`
- delete `C:\FXServer\_fulltest`
