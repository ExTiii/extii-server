fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_tools'
author 'EX_Tii'
description 'Tools: repair kits (normal = engine runs again, advanced = whole car fixed) and lockpicks'
version '1.0.0'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}

shared_script '@ox_lib/init.lua'

-- Arabic letters in GTA built-in text
client_script '@support-arabic/escaping.lua'
client_script 'client.lua'

server_script 'server.lua'
