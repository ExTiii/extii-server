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
