lib.versionCheck('Qbox-project/qbx_spawn')

local lastRequests = {}

local function isRateLimited(source, callbackName)
    local now = os.time()
    local requests = lastRequests[source]

    if not requests then
        requests = {}
        lastRequests[source] = requests
    elseif requests[callbackName] == now then
        return true
    end

    requests[callbackName] = now
    return false
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function decodeCoords(encodedCoords)
    if type(encodedCoords) ~= 'string' then return end

    local success, coords = pcall(json.decode, encodedCoords)
    if not success or type(coords) ~= 'table' then return end
    if not isFiniteNumber(coords.x) or not isFiniteNumber(coords.y) or not isFiniteNumber(coords.z) then return end
    if coords.w ~= nil and not isFiniteNumber(coords.w) then return end

    return coords
end

lib.callback.register('qbx_spawn:server:getLastLocation', function(source)
    if isRateLimited(source, 'lastLocation') then return end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local queryResult = MySQL.single.await('SELECT position FROM players WHERE citizenid = ?', { player.PlayerData.citizenid })
    if not queryResult then return end

    local position = decodeCoords(queryResult.position)
    if not position then return end

    local currentPropertyId = player.PlayerData.metadata.currentPropertyId

    -- EX_Tii: only back inside a home the character still owns or has keys to; otherwise
    -- start at that home's door (before, the player was stuck in the character room)
    if currentPropertyId then
        -- (with the housing script off nobody can go inside: everyone starts at the door)
        local housingOn = false -- EX_Tii: no housing script yet (qbx_properties is only a stub), so nobody goes back inside a home
        local okQuery, property = pcall(MySQL.single.await, 'SELECT owner, keyholders, coords FROM properties WHERE id = ?', { currentPropertyId })
        if not okQuery then property = nil end
        local cid = player.PlayerData.citizenid
        local allowed = false
        if housingOn and property then
            if property.owner == cid then
                allowed = true
            else
                local ok, keyholders = pcall(json.decode, property.keyholders or '[]')
                if ok and type(keyholders) == 'table' then
                    for i = 1, #keyholders do
                        if keyholders[i] == cid then allowed = true break end
                    end
                end
            end
        end
        if not allowed then
            player.Functions.SetMetaData('currentPropertyId', nil)
            local door = property and decodeCoords(property.coords)
            if door then return door, nil end
            -- the home itself is gone: the saved position is inside it, so use the one city spawn
            -- (EX_Tii: the new-player spawn next to the job center, same as exti_characters)
            return { x = -265.49, y = -962.85, z = 31.22, w = 201.26 }, nil
        end
    end

    return position, currentPropertyId
end)

lib.callback.register('qbx_spawn:server:getProperties', function(source)
    if not GetResourceState('qbx_properties'):find('start') then
        return {}
    end

    if isRateLimited(source, 'properties') then return {} end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local houseData = {}
    local properties = MySQL.query.await('SELECT id, property_name, coords FROM properties WHERE owner = ?', { player.PlayerData.citizenid }) or {}

    for i = 1, #properties do
        local property = properties[i]
        local coords = decodeCoords(property.coords)

        if coords then
            houseData[#houseData + 1] = {
                label = property.property_name,
                coords = coords,
                propertyId = property.id,
            }
        end
    end

    return houseData
end)

AddEventHandler('playerDropped', function()
    lastRequests[source] = nil
end)
