fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'exti_usedcars'
author 'EX_Tii Roleplay'
description 'EX_Tii: the used-car lot. A player puts his own car up for sale (75% - 125% of the dealership price), the car stands on the lot, any other player can walk up and buy it.'

shared_scripts { '@ox_lib/init.lua', '@qbx_core/modules/lib.lua', 'config.lua' }
client_scripts { '@support-arabic/escaping.lua', 'client.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

-- (qbx_vehicles is server-only: listing it here stopped the game from starting this resource)
dependencies { 'ox_lib', 'oxmysql', 'qbx_core' }
