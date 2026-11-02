fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_level'
author 'EX_Tii'
description 'EX_Tii Level: the player level 1-300 (XP only from real work), the XP card, the level in the radial menu'
version '1.0.0'

dependencies { 'ox_lib', 'qbx_core', 'oxmysql' }

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared.lua',
}

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/level.css',
    'html/level.js',
    'html/fonts/*.woff2',
}
