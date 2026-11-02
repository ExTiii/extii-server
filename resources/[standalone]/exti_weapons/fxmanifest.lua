fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_weapons'
author 'EX_Tii Roleplay'
description 'EX_Tii gun rework: one fair damage table (no instant headshots, headshots x1.5), shots-fired calls to the police'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
