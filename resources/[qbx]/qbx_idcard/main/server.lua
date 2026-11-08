local sharedConfig = require 'config.shared'

local ox_inventory = exports.ox_inventory
local MAX_MUGSHOT_LENGTH = 512 * 1024

---@param mugShot any
---@return boolean
local function isValidMugShot(mugShot)
    return type(mugShot) == 'string'
        and #mugShot <= MAX_MUGSHOT_LENGTH
        and mugShot:find('^data:image/[%w.+-]+;base64,') ~= nil
end

local sendData

---@param src number
---@param itemName string
---@param slot? number the card that was used (EX_Tii: before, the photo went on the first card of that type in the bag)
local function newMetaDataLicense(src, itemName, slot)
    local inventoryItem = slot and ox_inventory:GetSlot(src, slot)
    if not inventoryItem or inventoryItem.name ~= itemName then
        -- no slot: the first card of that type that isn't someone else's
        inventoryItem = nil
        local player = exports.qbx_core:GetPlayer(src)
        local cid = player and player.PlayerData.citizenid
        for _, it in pairs(ox_inventory:Search(src, 1, itemName) or {}) do
            local owner = it.metadata and it.metadata.citizenid
            if type(owner) ~= 'string' or owner == '' or owner == cid then
                if not inventoryItem or it.slot < inventoryItem.slot then inventoryItem = it end
            end
        end
    end
    if not inventoryItem then return end
    slot = inventoryItem.slot

    local mugShot = lib.callback.await('um-idcard:client:callBack:getMugShot', src)
    if not isValidMugShot(mugShot) then return end

    inventoryItem = ox_inventory:GetSlot(src, slot)
    if not inventoryItem or inventoryItem.name ~= itemName then return end

    local metadata = inventoryItem.metadata or {}
    metadata.mugShot = mugShot
    ox_inventory:SetMetadata(src, inventoryItem.slot, metadata)

    -- EX_Tii: the photo is taken the first time; show the card right away instead of needing a second use
    sendData(src, itemName, metadata)
end

---@param src number
---@param target number
---@return boolean
local function isNearbyPlayer(src, target)
    if math.type(target) ~= 'integer' or target <= 0 or target == src or not GetPlayerName(target) then return false end

    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target) then return false end

    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if playerPed <= 0 or targetPed <= 0 then return false end

    return #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed)) <= 3.0
end

-- EX_Tii: a card shows the details written on it when it was made, so someone else's card shows
-- THEIR name (before, it showed yours with their photo). Old cards without details show yours.
---@return table
local function cardDetails(player, metadata)
    local owner = metadata.citizenid
    if type(owner) ~= 'string' or owner == '' then
        local c = player.PlayerData.charinfo or {}
        return {
            citizenid = player.PlayerData.citizenid,
            firstname = c.firstname, lastname = c.lastname, birthdate = c.birthdate,
            sex = c.gender == 0 and 'ذكر' or 'أنثى', nationality = c.nationality,
        }
    end
    return {
        citizenid = owner,
        firstname = metadata.firstname, lastname = metadata.lastname, birthdate = metadata.birthdate,
        sex = metadata.sex == 'F' and 'أنثى' or 'ذكر', nationality = metadata.nationality,
    }
end

---@param src number
---@param item string
---@param metadata table
---@param slot? number
function sendData(src, item, metadata, slot)
    if type(src) ~= 'number' or not GetPlayerName(src) then return end
    if type(item) ~= 'string' or not sharedConfig.licenses[item] then return end
    if type(metadata) ~= 'table' then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    -- the photo is taken only for your own card (someone else's card without a photo is shown without one)
    local owner = metadata.citizenid
    local isMine = type(owner) ~= 'string' or owner == '' or owner == player.PlayerData.citizenid

    if isValidMugShot(metadata.mugShot) or not isMine then
        local details = cardDetails(player, metadata)

        lib.callback('um-idcard:client:callBack:getClosestPlayer', src, function(target)
            if not GetPlayerName(src) then return end

            target = tonumber(target)
            if target and isNearbyPlayer(src, target) then
                TriggerClientEvent('um-idcard:client:notifyOx', src, {
                    title = 'عرض البطاقة',
                    desc = ('عرضتَ %s على الشخص القريب منك'):format(sharedConfig.licenses[item].header),
                    icon = 'id-card',
                    iconColor = '#20c997'
                })
            else
                target = src
            end

            TriggerClientEvent('um-idcard:client:sendData', target, {
                citizenid = details.citizenid,
                firstname = details.firstname,
                lastname = details.lastname,
                birthdate = details.birthdate,
                sex = details.sex,
                nationality = details.nationality,
                cardtype = item,
                -- EX_Tii: the owner's level (exti_level)
                level = GetResourceState('exti_level') == 'started' and (function()
                    local ok, lv = pcall(function() return exports.exti_level:GetLevel(details.citizenid) end)
                    return ok and lv or nil
                end)() or nil,
                mugShot = isValidMugShot(metadata.mugShot) and metadata.mugShot or nil,
                badge = metadata.badge,
            })
        end)

        TriggerClientEvent('um-idcard:client:startAnim', src, item)
    else
        newMetaDataLicense(src, item, slot)
    end
end

-- This event is intentionally server-only. It is called by the usable item
-- handler and must not accept arbitrary card data from clients.
AddEventHandler('um-idcard:server:sendData', sendData)

for k,_ in pairs(sharedConfig.licenses) do
    CreateRegisterItem(k)
end
