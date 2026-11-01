fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_police'
author 'EX_Tii'
description 'EX_Tii Police: the station (clock in terminal, cloakroom, personal locker, armory, garages with the team vehicles, public forms, seized items room), the police tablet (F6: map, chat, calendar, camera, gallery, form inbox, management) and the street (Z wheel: cuff, escort, vehicle, search, seize, charge sheet with fines as bank bills, the prison at Bolingbroke, 911 calls on the tablet map, CCTV)'
version '1.1.0'

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
    'client/street.lua',
    'client/charges.lua',
    'client/prison.lua',
    'client/cctv.lua',
    'client/doors.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/shift.lua',
    'server/armory.lua',
    'server/fleet.lua',
    'server/forms.lua',
    'server/tablet.lua',
    'server/street.lua',
    'server/charges.lua',
    'server/prison.lua',
    'server/dispatch.lua',
    'server/cctv.lua',
    'server/doors.lua',
    'server/records.lua',
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
    'html/prison.js',
    'html/prison.css',
    'html/cctv.js',
    'html/cctv.css',
    'html/fonts/*.woff2',
    'html/tablet.html',
    'html/locked.html',
    'html/pt/*.js',
    'html/pt/tablet.css',
    'html/pt/img/map.jpg',
}
