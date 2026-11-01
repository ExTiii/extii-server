-- EX_Tii radial menu (server): giving car keys, saving the walk style

local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

-- the walk style is saved on the character (comes back after a relog)
local walkIds = {}
for _, s in ipairs(Config.walkStyles) do walkIds[s.id] = true end

RegisterNetEvent('exti_radial:server:walkStyle', function(id)
    local src = source
    local player = getPlayer(src)
    if not player or type(id) ~= 'string' or not walkIds[id] then return end
    player.Functions.SetMetaData('walkstyle', id ~= 'default' and id or nil)
end)

-- give the keys of the car next to you to the closest player (qbx_vehiclekeys does the real work)
lib.callback.register('exti_radial:server:giveKeys', function(source)
    local player = getPlayer(source)
    if not player then return false end
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return false, 'nokeys' end
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, Config.vehicleReach)
    if not vehicle then return false, 'vehicle' end
    local hasKeys = true
    pcall(function() hasKeys = exports.qbx_vehiclekeys:HasKeys(source, vehicle) end)
    if not hasKeys then return false, 'keys' end
    -- in a car: everyone inside gets a key; outside: the closest person within 3 m
    local given = false
    if GetVehiclePedIsIn(ped, false) == vehicle then
        for seat = -1, 7 do
            local p = GetPedInVehicleSeat(vehicle, seat)
            local id = p ~= 0 and NetworkGetEntityOwner(p) or 0
            if id ~= 0 and id ~= source and GetPlayerPed(id) == p then
                exports.qbx_vehiclekeys:GiveKeys(id, vehicle)
                given = true
            end
        end
    else
        local closest, best = nil, 3.0
        for _, p in ipairs(lib.getNearbyPlayers(coords, 3.0, false)) do
            local d = #(p.coords - coords)
            if p.id ~= source and d <= best then closest, best = p.id, d end
        end
        if closest then
            exports.qbx_vehiclekeys:GiveKeys(closest, vehicle)
            given = true
        end
    end
    if not given then return false, 'nobody' end
    return true
end)
