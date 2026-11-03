fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_heists'
author 'EX_Tii'
description 'EX_Tii robberies and heists: criminal Rep and skills, police / no-police mode, store robberies (more tiers come milestone by milestone)'
version '0.1.0'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
    'exti_shops',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/stores.lua',
    'client/npc.lua',
    'client/houses.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/npc.lua',
    'server/stores.lua',
    'server/fence.lua',
    'server/houses.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/hgames.css',
    'html/hgames.js',
    'html/hmeta.js',
    'html/hhud.js',
    'html/hhud.css',
    'html/items/*.png',
    'html/kit.css',
    'html/fonts/*.woff2',
    'html/mg/*.webp',
    'html/mg/sfx/*.ogg',
}
