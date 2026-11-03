local NOW = 1000000
os.time = function() return NOW end
local vec = {}
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end
local function v3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vec) end
vehicles, players, owners, online, states, deleted, saved, handlers, notes = {}, {}, {}, {}, {}, {}, {}, {}, {}
VehicleType = setmetatable({}, { __index = function(_, k) return k end }); GarageType = VehicleType; VehicleState = { OUT = 0, GARAGED = 1, IMPOUNDED = 2 }; vec3 = function(x,y,z) return {x=x,y=y,z=z} end; vec4 = function(x,y,z,w) return {x=x,y=y,z=z,w=w} end; Config = dofile('server.lua')
Config = type(Config) == 'table' and Config or _G.Config
VEHICLES = {}; VehicleState = { IMPOUNDED = 2 }
lib = { print = { info = function(...) end, error = function(...) print('ERR', ...) end }, addCommand = function() end }
function CreateThread() end
function Wait() end
function AddEventHandler(n, f) handlers[n] = f end
function RegisterNetEvent(n, f) handlers[n] = f end
function GetAllVehicles() local o = {} for v in pairs(vehicles) do o[#o + 1] = v end return o end
function GetVehicleType() return 'automobile' end
function GetEntityRoutingBucket() return 0 end
function GetEntityAttachedTo() return 0 end
function Entity(v) return { state = states[v] or {} } end
function GetEntityCoords(v) return vehicles[v] or players[v] end
function GetPedInVehicleSeat() return 0 end
function DoesEntityExist(v) return vehicles[v] ~= nil end
function GetPlayers() local o = {} for p in pairs(players) do o[#o + 1] = p end return o end
function GetPlayerPed(p) return p end
function GetPlayerRoutingBucket() return 0 end
function GetVehicleNumberPlateText(v) return 'P' .. v end
function GetVehicleBodyHealth() return 1000 end
function GetVehicleEngineHealth() return 1000 end
function DeleteEntity(v) deleted[v] = true; vehicles[v] = nil end
exports = {
  qbx_vehicles = { GetVehicleIdByPlate = function(_, plate) return owners[tonumber(plate:sub(2))] and tonumber(plate:sub(2)) or nil end,
                   GetPlayerVehicle = function(_, id) return owners[id] and { citizenid = owners[id], modelName = 'sultan', props = {} } end,
                   SaveVehicle = function(_, v, d) saved[v] = d; return true end },
  qbx_core = { GetPlayerByCitizenId = function(_, cid) return online[cid] and { PlayerData = { source = online[cid] } } or nil end,
               DeleteVehicle = function(_, v) deleted[v] = true; vehicles[v] = nil end,
               Notify = function(_, src, msg) notes[#notes + 1] = msg end,
               GetPlayer = function(_, src) for cid, s in pairs(online) do if s == src then return { PlayerData = { citizenid = cid } } end end end },
}
setmetatable(exports, { __index = function() return {} end })
Config.calculateImpoundFee = function() return 500 end
-- grab check() by loading the file with a hook
local src = io.open('autoimpound.lua'):read('a')
src = src .. '\nreturn check'
local check = load(src, 'autoimpound', 't', _G)()
local function step(min) for i = 1, min * 2 do NOW = NOW + 30; check() end end

-- A: owner online, nobody near: towed at 30 min, not at 15
vehicles[1] = v3(0, 0, 0); owners[1] = 'A'; online.A = 101; players[101] = v3(500, 0, 0)
check(); step(16); assert(not deleted[1], 'A towed too early')
step(15); assert(deleted[1] and saved[1].depotPrice == 500, 'A not towed at 30')
-- B: owner online, someone 50 m away (outside 35): still towed at 30 min
vehicles[2] = v3(0, 0, 0); owners[2] = 'A'; players[102] = v3(50, 0, 0)
check(); step(31); assert(deleted[2], 'B blocked by a far player')
-- C: someone 20 m away blocks it
vehicles[3] = v3(0, 0, 0); owners[3] = 'A'; players[103] = v3(20, 0, 0)
check(); step(40); assert(not deleted[3], 'C towed with a player right next to it')
players[103] = nil; step(1); assert(deleted[3], 'C not towed after he left')
-- D: owner logs out: 10 min after
vehicles[4] = v3(0, 0, 0); owners[4] = 'B'; online.B = 104; players[104] = v3(500, 0, 0)
check(); step(5); handlers.playerDropped = handlers.playerDropped; source = 104; handlers.playerDropped(); online.B = nil; players[104] = nil
step(8); assert(not deleted[4], 'D towed before 10 min after logout')
step(3); assert(deleted[4], 'D not towed 10 min after logout')
-- E: stolen + dumped: fee 250
vehicles[5] = v3(0, 0, 0); owners[5] = 'A'; states[5] = { exti_thief = 'X' }
check(); step(31); assert(deleted[5] and saved[5].depotPrice == 250, 'E fee wrong')
-- F: NPC car: 15 min, 100 m
players[102] = nil; vehicles[6] = v3(0, 0, 0); players[105] = v3(80, 0, 0)
check(); step(20); assert(not deleted[6], 'F removed with a player 80 m away'); players[105] = nil; step(1); assert(deleted[6], 'F not removed')
-- G: kept by the chop shop
vehicles[7] = v3(0, 0, 0); owners[7] = 'A'; states[7] = { exti_chop = 'g' }
check(); step(60); assert(not deleted[7], 'G chop car towed')
print('ALL OK', #notes)
