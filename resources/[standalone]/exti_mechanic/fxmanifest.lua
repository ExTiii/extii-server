fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_mechanic'
author 'EX_Tii'
description 'EX_Tii Mechanic: the workshop (clock in terminal, cloakroom, personal locker, tool storage by rank, garages with the service trucks and cars, public forms), the mechanic tablet (map, chat, calendar, camera, gallery, form inbox, management, billing) and the bill sheet'
version '1.0.0'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
    'shared/spots.lua',
}

client_scripts {
    '@support-arabic/escaping.lua',   -- Arabic in the map names and the game's own text
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/shift.lua',
    'client/fleet.lua',
    'client/forms.lua',
    'client/tablet.lua',
    'client/charges.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/shift.lua',
    'server/armory.lua',
    'server/fleet.lua',
    'server/forms.lua',
    'server/tablet.lua',
    'server/charges.lua',
    'server/photos.js',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/kit.css',
    'html/duty.js',
    'html/duty.css',
    'html/cloak.js',
    'html/cloak.css',
    'html/garage.js',
    'html/garage.css',
    'html/forms.js',
    'html/forms.css',
    'html/charge.js',
    'html/charge.css',
    'html/fonts/*.woff2',
    'html/tablet.html',
    'html/pt/*.js',
    'html/pt/tablet.css',
    'html/pt/img/map.jpg',
}
