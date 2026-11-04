-- EX_Tii: admins can replay the character-screen camera moves to check them in game
--   /arrivaltest       the new-player arrival (you are moved to the new-player spawn)
--   /arrivaltest back  the "welcome back" flight down to where you stand now
lib.addCommand('arrivaltest', {
    help = 'معاينة كاميرا الوصول (للإدارة)',
    params = {
        { name = 'kind', type = 'string', help = 'back = كاميرا العودة', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('exti_characters:client:preview', source, args.kind == 'back' and 'back' or 'arrival')
end)

-- EX_Tii: a character was deleted: take it out of its gang and heist crew. Each script checks the
-- character is really gone from the database first, so this cannot remove anyone who still exists.
local deletedAsked = {}
RegisterNetEvent('exti_characters:server:deleted', function(citizenid)
    local src = source
    if type(citizenid) ~= 'string' or #citizenid > 60 then return end
    if (deletedAsked[src] or 0) > GetGameTimer() then return end
    deletedAsked[src] = GetGameTimer() + 2000
    for _, res in ipairs({ 'exti_gangs', 'exti_heists' }) do
        if GetResourceState(res) == 'started' then
            pcall(function() exports[res]:RemoveDeletedCharacter(citizenid) end)
        end
    end
end)
AddEventHandler('playerDropped', function() deletedAsked[source] = nil end)
