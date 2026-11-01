fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_driveschool'
author 'EX_Tii'
description 'EX_Tii Driving School: nobody starts with a licence; car / truck / boat / helicopter, each with a theory test and a practical test; the police can suspend them'
version '2.0.0'

dependencies { 'ox_lib', 'qbx_core', 'qbx_idcard', 'oxmysql', 'support-arabic' }

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    '@support-arabic/escaping.lua',   -- Arabic in the map names
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/kit.css',
    'html/app.js',
    'html/fonts/*.woff2',
}
