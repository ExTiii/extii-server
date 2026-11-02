fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'exti_gangs'
author 'EX_Tii Roleplay'
description 'EX_Tii gangs: ranks, gang bank, HQ, rep, the shared collection point and the Chop Shop'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/chop.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/spots.lua',
    'server/collect.lua',
    'server/chop.lua',
}

ui_page 'html/index.html'

files {
    'config.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/chop.js',
    'html/fonts/*.woff2',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}
