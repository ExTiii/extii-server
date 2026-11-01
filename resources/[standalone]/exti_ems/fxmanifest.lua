fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_ems'
author 'EX_Tii'
description 'EX_Tii EMS: the clock in terminal, the cloakroom (uniforms), team storage and personal locker, the garages with the team vehicles and their trunks, supply cabinet, the rugged tablet (calls, team, patient exam), the step by step treatment (paid per patient), stretcher and wheelchair'
version '1.0.0'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'qbx_medical',
    'qbx_ambulancejob',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
    'shared/spots.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/equipment.lua',
    'client/tablet.lua',
    'client/treat.lua',
    'client/shift.lua',
    'client/fleet.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/shift.lua',
    'server/fleet.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/locked.html',
    'html/app.js',
    'html/style.css',
    'html/treat.js',
    'html/treat.css',
    'html/kit.css',
    'html/duty.js',
    'html/duty.css',
    'html/cloak.js',
    'html/cloak.css',
    'html/garage.js',
    'html/garage.css',
    'html/fonts/*.woff2',
}
