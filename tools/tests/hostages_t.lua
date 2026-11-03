dofile('hostages_sim.lua')
local fails = 0
local function ok(c, m) if c then print('  ok   ' .. m) else print('  FAIL ' .. m); fails = fails + 1 end end
local function reset()
    events, texts, logs, jailed = {}, {}, {}, {}
end
clientCb['exti_heists:client:dropSpot'] = function(src, o, a, b) return { x = o.x + 600, y = o.y, z = o.z, street = 'Vespucci' } end
run(2000)
-- A: rob a bank, tie an NPC, standoff, drop deal, head start, chase
print('A drop deal')
players[1] = { pos = vec3(0, 0, 0), bucket = 0, hp = 200, cid = 'R1', name = 'Robber', state = {}, items = { zip_ties = 3, blindfold = 1 }, mask = 0 }
players[9] = { pos = vec3(5000, 0, 0), bucket = 0, hp = 200, cid = 'A9', name = 'Admin', state = {}, items = {}, admin = true }
npcs[77] = { pos = vec3(1, 1, 0), hp = 200, state = {} }
H.npcRespond({ 1 }, vec3(0, 0, 0), 'bank')
local okb, tok = call('exti_heists:server:tieBegin', 1, 'npc', 77)
ok(okb, 'tieBegin npc')
run(T + 4200)
local okE, n = call('exti_heists:server:tieEnd', 1, tok, true)
ok(okE and n == 1, 'tieEnd npc -> 1 hostage')
ok(players[1].items.zip_ties == 2, 'one zip tie used')
run(T + 125000)
ok(has('exti_heists:client:npcSpawn', 1), 'units spawned')
local h = has('exti_heists:client:npcHold', 1)
ok(h and h.args[2] == 900 and h.args[3] == 'hostages', 'standoff hold 15 min')
run(T + 25000)
ok(#warrants == 1, 'no mask -> warrant')
ok(lastText('P1') and lastText('P1'):find('1 = '), 'negotiator texted the menu')
-- blindfold, escort, car in/out
ok(call('exti_heists:server:hostageAct', 1, 'blind', 'npc', 77), 'blindfold on')
ok(players[1].items.blindfold == 0, 'blindfold used')
ok(call('exti_heists:server:hostageAct', 1, 'escort', 'npc', 77), 'escort')
ok(GlobalState['exti_heists:hostages']['77'].escort == 1, 'escort published')
say(1, '1'); run(T + 4000)
ok(has('exti_heists:client:dropSpotShow', 1), 'drop spot shown')
ok(lastText('P1'):find('Vespucci'), 'drop text has the street')
-- releasing at the wrong place breaks it? (test the good path: go there)
players[1].pos = vec3(598, 0, 0); npcs[77].pos = vec3(599, 0, 0)
run(T + 60000)
ok(not has('exti_heists:client:npcChase'), 'no chase while driving to the spot')
local fr = call('exti_heists:server:hostageAct', 1, 'free', 'npc', 77)
ok(fr, 'released at the spot')
local hs = nil
for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcHold' and e.args[3] == 'headstart' then hs = e end end
ok(hs and hs.args[2] == 10, 'head start 10 s')
run(T + 11000)
ok(has('exti_heists:client:npcChase', 1), 'chase started')
local m; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcMode' and e.args[2].chase then m = e end end
ok(m and m.args[2].lost == 120, 'lose them in 2 min during the chase')
run(T + 15 * 60000 + 4000)
local ended; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcEnd' then ended = e.args[2] end end
ok(ended == 'time', 'chase over after 15 min')

-- B: player hostage, rules, then the time runs out -> storm with SWAT
print('B player hostage, storm on time')
reset()
players[2] = { pos = vec3(1, 0, 0), bucket = 0, hp = 200, cid = 'H2', name = 'Hostage', state = {}, items = {} }
players[1].pos = vec3(0, 0, 0); players[1].items.zip_ties = 3; players[1].mask = 1
local r1 = call('exti_heists:server:tieBegin', 1, 'player', 2)
ok(not r1, 'no hands up -> refused')
players[2].state.handsup = true; players[2].state['qbx_medical:deathState'] = 2
r1 = call('exti_heists:server:tieBegin', 1, 'player', 2)
ok(not r1, 'downed -> refused')
players[2].state['qbx_medical:deathState'] = 1
local okb2, tok2 = call('exti_heists:server:tieBegin', 1, 'player', 2)
ok(okb2, 'hands up -> tie begins')
run(T + 1000)
ok(not call('exti_heists:server:tieEnd', 1, tok2, true), 'too fast -> refused')
okb2, tok2 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200)
ok(call('exti_heists:server:tieEnd', 1, tok2, true), 'tied the player')
ok(players[2].state.exti_tied == 1, 'state bag set')
ok(not call('exti_heists:server:hostageAct', 2, 'free', 'player', 2), 'the hostage can not free himself')
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store')
run(T + 95000)
ok(has('exti_heists:client:npcHold', 1), 'standoff with a player hostage')
run(T + 25000)
ok(#warrants == 1, 'mask on -> no new warrant')
say(1, '3'); run(T + 4000)
ok(lastText('P1'):find('20'), 'more time: 20 min left')
say(1, '3'); run(T + 4000)
ok(lastText('P1'):find('مرة'), 'more time only once')
run(T + 21 * 60000)
ok(has('exti_heists:client:npcSwat', 1), 'storm: SWAT sent')
ok(has('exti_heists:client:npcRage', 1), 'storm: rage')

-- C: hurt the hostage -> storm
print('C hurt')
reset()
-- new response with a fresh hostage
for k in pairs(handlers) do end
local nr = H.npcOf(1); if nr then H.npcEnd(nr.id, 'test') end
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store'); run(T + 95000)
ok(has('exti_heists:client:npcHold', 1), 'standoff again')
players[2].hp = 150
GetPedSourceOfDamage = function() return 1001 end
fire('exti_heists:server:captiveHurt', 2, 1)
ok(has('exti_heists:client:npcSwat', 1), 'hurt -> SWAT')
GetPedSourceOfDamage = function() return 0 end

-- D: walks into a house holding him -> admins told, free, prison when he comes out
print('D leave with a hostage')
reset()
nr = H.npcOf(1); if nr then H.npcEnd(nr.id, 'test') end
players[1].bucket = 7
run(T + 3000)
ok(players[2].state.exti_tied == nil, 'hostage freed')
local adm = false; for _, t in ipairs(texts) do if t.targetNumber == 'P9' and t.message:find('Robber') then adm = true end end
ok(adm, 'admin texted')
players[1].bucket = 0
run(T + 3000)
ok(jailed[1] and jailed[1][2] == 15, 'jailed 15 min on the way out')
ok(H.rec(1).loot.black_money == nil, 'loot gone')

-- E: logout holding a hostage -> prison on login
print('E logout')
reset()
players[2].state.handsup = true
local b3, t3 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200); call('exti_heists:server:tieEnd', 1, t3, true)
fire('playerDropped', 1)
local p1 = players[1]; players[1] = nil
ok(players[2].state.exti_tied == nil, 'hostage freed on logout')
players[1] = p1
fire('QBCore:Server:OnPlayerLoaded', 1); run(T + 16000)
ok(jailed[1] and jailed[1][2] == 15, 'jailed on return')

-- F: release on the spot, then surrender
print('F release here / surrender')
reset()
players[2].state.handsup = true
b3, t3 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200); call('exti_heists:server:tieEnd', 1, t3, true)
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store'); run(T + 95000)
say(1, '2'); run(T + 4000)
ok(players[2].state.exti_tied == nil, 'release here frees him')
local hs2; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcHold' and e.args[3] == 'headstart' then hs2 = e end end
ok(hs2 and hs2.args[2] == 10, 'head start 10 s (release here)')
run(T + 16000)
ok(has('exti_heists:client:npcChase', 1), 'chase after release')
say(1, '4'); run(T + 9000)
ok(jailed[1] and jailed[1][2] == 10, 'surrender -> 10 min prison')

print('G deal broken')
reset()
local nr2 = H.npcOf(1); if nr2 then H.npcEnd(nr2.id, 'test') end
players[1].pos = vec3(0, 0, 0); players[2].pos = vec3(1, 0, 0); players[2].state.handsup = true; players[1].items.zip_ties = 3
b3, t3 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200); ok(call('exti_heists:server:tieEnd', 1, t3, true), 'tied')
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store'); run(T + 95000)
say(1, '1'); run(T + 4000)
ok(has('exti_heists:client:dropSpotShow', 1), 'spot shown')
players[1].pos = vec3(200, 0, 0); players[2].pos = vec3(201, 0, 0)
call('exti_heists:server:hostageAct', 1, 'free', 'player', 2)
local hs3; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcHold' and e.args[3] == 'headstart' then hs3 = e end end
ok(not hs3, 'no head start when released at the wrong place')
ok(has('exti_heists:client:npcChase', 1), 'deal broken -> chase now')
ok(lastText('P1'):find('اتفقنا عليه'), 'told the deal is off')
print('H review fixes')
nr2 = H.npcOf(1); if nr2 then H.npcEnd(nr2.id, 'test') end
reset()
-- the storm keeps going past the 12 min mark
players[2].state.handsup = true; players[1].pos = vec3(0, 0, 0); players[2].pos = vec3(1, 0, 0); players[1].items.zip_ties = 5
b3, t3 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200); ok(call('exti_heists:server:tieEnd', 1, t3, true), 'tied')
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store'); run(T + 95000)
run(T + 15 * 60000 + 4000)
ok(has('exti_heists:client:npcSwat', 1), 'storm at 15 min')
run(T + 60000)
local endedEarly = false; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcEnd' then endedEarly = true end end
ok(not endedEarly and H.npcOf(1) ~= nil, 'the storm is not cancelled right after')
H.npcEnd(H.npcOf(1).id, 'test')
-- a stranger can't walk someone else's hostage
players[3] = { pos = vec3(1.5, 0, 0), bucket = 0, hp = 200, cid = 'S3', name = 'Stranger', state = {}, items = {} }
ok(not call('exti_heists:server:hostageAct', 3, 'escort', 'player', 2), 'stranger cannot escort')
ok(not call('exti_heists:server:hostageAct', 3, 'carOut', 'player', 2), 'stranger cannot take him out of a car')
ok(call('exti_heists:server:hostageAct', 3, 'prone', 'player', 2) == false, 'stranger cannot put him down')
-- far "aim" only works for lying him down
players[1].pos = vec3(9, 0, 0)
ok(not call('exti_heists:server:hostageAct', 1, 'blind', 'player', 2, 'aim'), 'no blindfold from 9 m')
ok(call('exti_heists:server:hostageAct', 1, 'prone', 'player', 2, 'aim'), 'aim again from 9 m -> down')
players[1].pos = vec3(0, 0, 0)
-- a crewmate can't be the hostage
crews.R1, crews.C4 = 1, 1
players[4] = { pos = vec3(1, 1, 0), bucket = 0, hp = 200, cid = 'C4', name = 'Crew', state = { handsup = true }, items = {} }
ok(not call('exti_heists:server:tieBegin', 1, 'player', 4), 'crewmate cannot be tied as a hostage')
-- release and tie again: the standoff clock doesn't start over
call('exti_heists:server:hostageAct', 1, 'free', 'player', 2)
reset()
players[2].state.handsup = true
b3, t3 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200); call('exti_heists:server:tieEnd', 1, t3, true)
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store'); run(T + 95000)
local first; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcHold' and e.args[3] == 'hostages' then first = e.args[2] end end
call('exti_heists:server:hostageAct', 1, 'free', 'player', 2); run(T + 4000)
run(T + 60000)
players[2].state.handsup = true
b3, t3 = call('exti_heists:server:tieBegin', 1, 'player', 2); run(T + 4200); call('exti_heists:server:tieEnd', 1, t3, true)
local second; for _, e in ipairs(events) do if e.name == 'exti_heists:client:npcHold' and e.args[3] == 'hostages' then second = e.args[2] end end
ok(first and second and second < first - 50, 'second standoff keeps the first clock')
H.npcEnd(H.npcOf(1).id, 'test')
-- hurt before they arrive: they come with the SWAT team
reset()
H.npcRespond({ 1 }, vec3(0, 0, 0), 'store'); run(T + 10000)
players[2].hp = 120; GetPedSourceOfDamage = function() return 1001 end
fire('exti_heists:server:captiveHurt', 2, 1); GetPedSourceOfDamage = function() return 0 end
run(T + 90000)
ok(has('exti_heists:client:npcSwat', 1), 'hurt before arrival -> SWAT on arrival')
-- a player is never stuck tied: his robber down 3 min
H.npcEnd(H.npcOf(1).id, 'test')
players[2].hp = 200
players[1].state['qbx_medical:deathState'] = 2
run(T + 4 * 60000)
ok(players[2].state.exti_tied == nil, 'robber down 3 min -> player hostage free')
players[1].state['qbx_medical:deathState'] = 1
print(fails == 0 and 'ALL OK' or ('FAILS: ' .. fails))
