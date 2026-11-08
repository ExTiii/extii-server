-- EX_Tii Roleplay — real photos of each player's own car (their colour, their parts).
-- The photo is taken on the player's game (client/photos.lua), cleaned in the garage screen,
-- and stored here. Everything coming from the player is checked before it is saved.

local MAX_PHOTO_CHARS = 160000 -- about 120 KB of picture
local MAX_FETCH = 40
local SAVE_EVERY_MS = 4000

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS garage_vehicle_photos (
            vehicle_id INT NOT NULL,
            look VARCHAR(64) NOT NULL DEFAULT '',
            photo MEDIUMTEXT NOT NULL,
            updated_at INT NOT NULL DEFAULT 0,
            PRIMARY KEY (vehicle_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        -- forget photos of cars that no longer exist
        MySQL.query.await('DELETE p FROM garage_vehicle_photos p LEFT JOIN player_vehicles v ON v.id = p.vehicle_id WHERE v.id IS NULL')
    end)
    if not ok then lib.print.error('[car photos] could not prepare the database table: ' .. tostring(err)) end
end)

local function isInt(v)
    return type(v) == 'number' and v % 1 == 0 and v > 0
end

local function citizenOf(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid
end

--- Photo version (last update time) for each car id, used by the garage list
---@param ids integer[]
---@return table<integer, integer>
function PhotoVersions(ids)
    local map = {}
    if #ids == 0 then return map end
    local ok, rows = pcall(MySQL.query.await, ('SELECT vehicle_id, updated_at FROM garage_vehicle_photos WHERE vehicle_id IN (%s)'):format(string.rep('?', #ids, ',')), ids)
    if not ok or not rows then return map end
    for i = 1, #rows do
        map[rows[i].vehicle_id] = math.floor(tonumber(rows[i].updated_at) or 0)
    end
    return map
end

--- The photos a player may see: their own cars and cars shared with them
lib.callback.register('qbx_garages:server:getPhotos', function(source, ids)
    local citizenid = citizenOf(source)
    if not citizenid or type(ids) ~= 'table' then return {} end

    local clean, seen = {}, {}
    for i = 1, math.min(#ids, MAX_FETCH) do
        local id = ids[i]
        if isInt(id) and not seen[id] then
            seen[id] = true
            clean[#clean + 1] = id
        end
    end
    if #clean == 0 then return {} end

    local params = { citizenid }
    for i = 1, #clean do params[#params + 1] = clean[i] end
    params[#params + 1] = citizenid

    local ok, rows = pcall(MySQL.query.await, ([[SELECT p.vehicle_id, p.photo, p.updated_at FROM garage_vehicle_photos p
        INNER JOIN player_vehicles v ON v.id = p.vehicle_id
        LEFT JOIN garage_shared_keys s ON s.vehicle_id = v.id AND s.owner = v.citizenid AND s.citizenid = ?
        WHERE p.vehicle_id IN (%s) AND (v.citizenid = ? OR s.citizenid IS NOT NULL)]]):format(string.rep('?', #clean, ',')), params)
    if not ok or not rows then return {} end

    local result = {}
    for i = 1, #rows do
        local r = rows[i]
        result[#result + 1] = { id = r.vehicle_id, version = math.floor(tonumber(r.updated_at) or 0), photo = r.photo }
    end
    return result
end)

--- Which look the stored photo shows (so the game only takes a new photo when the car changed)
lib.callback.register('qbx_garages:server:getPhotoLook', function(source, vehicleId)
    local citizenid = citizenOf(source)
    if not citizenid or not isInt(vehicleId) then return false end
    local ok, row = pcall(MySQL.single.await, 'SELECT v.citizenid, p.look FROM player_vehicles v LEFT JOIN garage_vehicle_photos p ON p.vehicle_id = v.id WHERE v.id = ?', { vehicleId })
    if not ok or not row or row.citizenid ~= citizenid then return false end
    return true, row.look or ''
end)

local lastSave = {}

RegisterNetEvent('qbx_garages:server:savePhoto', function(vehicleId, look, photo)
    local src = source
    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < SAVE_EVERY_MS then return end
    lastSave[src] = now

    if not isInt(vehicleId) or type(look) ~= 'string' or #look == 0 or #look > 64 or not look:match('^[%w%-]+$') then return end
    if type(photo) ~= 'string' or #photo > MAX_PHOTO_CHARS then return end
    local prefix = 'data:image/webp;base64,'
    if photo:sub(1, #prefix) ~= prefix then return end
    if photo:find('[^%w%+/=]', #prefix + 1) then return end

    local citizenid = citizenOf(src)
    if not citizenid then return end
    local okOwner, owner = pcall(MySQL.scalar.await, 'SELECT citizenid FROM player_vehicles WHERE id = ?', { vehicleId })
    if not okOwner or owner ~= citizenid then return end

    local ok, err = pcall(MySQL.query.await, [[INSERT INTO garage_vehicle_photos (vehicle_id, look, photo, updated_at) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE look = VALUES(look), photo = VALUES(photo), updated_at = VALUES(updated_at)]], { vehicleId, look, photo, os.time() })
    if not ok then lib.print.error('[car photos] could not save photo: ' .. tostring(err)) end
end)

AddEventHandler('playerDropped', function()
    lastSave[source] = nil
end)

--- /carphoto: the id of the car the player is sitting in, only if it is theirs
lib.callback.register('qbx_garages:server:ownedVehicleId', function(source, netId)
    if type(netId) ~= 'number' or netId % 1 ~= 0 then return false end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local ped = GetPlayerPed(source)
    if ped <= 0 or GetVehiclePedIsIn(ped, false) ~= vehicle then return false end
    local citizenid = citizenOf(source)
    if not citizenid then return false end
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    if not isInt(vehicleId) then return false end
    local ok, owner = pcall(MySQL.scalar.await, 'SELECT citizenid FROM player_vehicles WHERE id = ?', { vehicleId })
    if not ok or owner ~= citizenid then return false end
    return vehicleId
end)

---------------------------------------------------------------------------
-- EX_Tii: the stock picture of a model, fetched once from FiveM's gallery and kept here (base64), so the
-- garage screen can repaint the car body in the owner's colour (a picture from another site can't be
-- touched by the screen's code; one that comes through us can).
---------------------------------------------------------------------------
local stockCache = {}      -- [model] = base64 string | false (not found)
local stockWaiting = {}    -- [model] = { cb, cb, ... } while a fetch is running
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return B64:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function fetchStock(model, cb)
    if stockCache[model] ~= nil then return cb(stockCache[model]) end
    if stockWaiting[model] then stockWaiting[model][#stockWaiting[model] + 1] = cb return end
    stockWaiting[model] = { cb }
    PerformHttpRequest(('https://docs.fivem.net/vehicles/%s.webp'):format(model), function(code, body)
        local result = false
        if code == 200 and type(body) == 'string' and #body > 0 and #body < 600000 then result = base64(body) end
        stockCache[model] = result
        local list = stockWaiting[model]; stockWaiting[model] = nil
        for _, f in ipairs(list) do f(result) end
    end, 'GET', '', {})
end

local stockAsked = {}   -- [src] = count this minute
lib.callback.register('qbx_garages:server:stockImage', function(source, model)
    if type(model) ~= 'string' or not model:match('^[%w_]+$') or #model > 32 then return false end
    model = model:lower()
    stockAsked[source] = (stockAsked[source] or 0) + 1
    if stockAsked[source] > 120 then return false end
    local p = promise.new()
    fetchStock(model, function(data) p:resolve(data) end)
    return Citizen.Await(p)
end)
CreateThread(function() while true do Wait(60000); stockAsked = {} end end)
