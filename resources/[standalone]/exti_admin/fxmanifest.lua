fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_admin'
author 'EX_Tii'
description 'The F1 admin tablet: players, me & world, server, gangs, tests, logs, staff'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@qbx_core/modules/lib.lua',
    'server.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts/*.woff2',
}

dependencies { 'oxmysql', 'ox_lib', 'qbx_core', 'ox_inventory' }
