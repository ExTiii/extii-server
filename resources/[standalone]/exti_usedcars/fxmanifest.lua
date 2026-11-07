fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'exti_usedcars'
author 'EX_Tii Roleplay'
description 'EX_Tii: the used-car buyer. Bring your own car, he buys it for half its dealership price (less if it is damaged).'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

dependencies { 'ox_lib', 'oxmysql', 'qbx_core', 'qbx_vehicles' }
