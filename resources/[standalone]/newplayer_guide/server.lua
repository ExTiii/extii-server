-- newplayer_guide / server.lua

local WELCOMED_KEY = 'npg_welcomed'  -- saved on the character once they've had the welcome + kit
local PLAYTIME_KEY = 'npg_playtime'  -- minutes played, only counted until the NEW tag ends
local TICK_MINUTES = 5

local tagLimit = Config.newPlayerTag.hours * 60

local function setTag(src, minutes)
    if not Config.newPlayerTag.enabled then return end
    Player(src).state:set('npg_new', minutes < tagLimit, true)
end

local function giveStarterKit(src)
    if not Config.starterKit.enabled then return end

    for _, item in ipairs(Config.starterKit.items) do
        if exports.ox_inventory:CanCarryItem(src, item.name, item.count) then
            local ok = exports.ox_inventory:AddItem(src, item.name, item.count)
            if not ok then
                lib.print.warn(('starter kit: could not give %s to %s (does the item exist?)'):format(item.name, src))
            end
        end
    end
end

-- Called by the client right after the character spawns
lib.callback.register('newplayer_guide:server:loaded', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { firstTime = false } end

    local meta = player.PlayerData.metadata
    setTag(source, meta[PLAYTIME_KEY] or 0)

    if meta[WELCOMED_KEY] then
        return { firstTime = false }
    end

    -- mark first, so the kit can never be given twice
    exports.qbx_core:SetMetadata(source, WELCOMED_KEY, true)
    giveStarterKit(source)

    return { firstTime = true }
end)

-- Count playtime for new players only (stops writing once the tag ends)
CreateThread(function()
    while true do
        Wait(TICK_MINUTES * 60000)

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local player = src and exports.qbx_core:GetPlayer(src)

            if player then
                local minutes = player.PlayerData.metadata[PLAYTIME_KEY] or 0
                if minutes < tagLimit then
                    minutes = minutes + TICK_MINUTES
                    exports.qbx_core:SetMetadata(src, PLAYTIME_KEY, minutes)
                    setTag(src, minutes)
                end
            end
        end
    end
end)

-- If this resource restarts while people are online, put their tags back
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = src and exports.qbx_core:GetPlayer(src)
        if player then
            setTag(src, player.PlayerData.metadata[PLAYTIME_KEY] or 0)
        end
    end
end)

-- /newplayers — staff see who is new so they can help them
lib.addCommand(Config.staffCommand, {
    help = 'Show new players who are online',
    restricted = Config.staffGroup,
}, function(source)
    local list = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = src and exports.qbx_core:GetPlayer(src)

        if player then
            local minutes = player.PlayerData.metadata[PLAYTIME_KEY] or 0
            if minutes < tagLimit then
                local info = player.PlayerData.charinfo or {}
                local charName = ('%s %s'):format(info.firstname or '', info.lastname or '')
                list[#list + 1] = {
                    id = src,
                    name = ('%s (%s)'):format(charName, GetPlayerName(src) or '?'),
                    minutes = minutes,
                }
            end
        end
    end

    table.sort(list, function(a, b) return a.minutes < b.minutes end)
    TriggerClientEvent('newplayer_guide:client:staffList', source, list)
end)
