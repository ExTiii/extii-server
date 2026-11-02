fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'exti_gangs'
author 'EX_Tii Roleplay'
description 'EX_Tii gangs: ranks, gang bank, HQ, rep, the shared collection point and the Chop Shop'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/chop.lua',
    'client/theft.lua',
    'client/door.lua',
    'client/wash.lua',
    'client/turf.lua',
    'client/craft.lua',
    'client/weed.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/spots.lua',
    'server/collect.lua',
    'server/chop.lua',
    'server/theft.lua',
    'server/door.lua',
    'server/wash.lua',
    'server/turf.lua',
    'server/craft.lua',
    'server/weed.lua',
}

ui_page 'html/index.html'

files {
    'config.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/chop.js',
    'html/games.js',
    'html/games.css',
    'html/mg/*.webp',
    'html/mg/sfx/*.ogg',
    'html/fonts/*.woff2',
    'html/tag.html',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}
