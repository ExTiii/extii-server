fx_version 'cerulean'
game 'gta5'

name 'qbx_vehicleshop'
description 'Vehicle shop system for Qbox (EX_Tii Roleplay dealership panel)'
repository 'https://github.com/Qbox-project/qbx_vehicleshop'
version '1.0.0'

ox_lib 'locale'

shared_script {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

-- Arabic letters in GTA built-in text (must load before the other client scripts)
client_script '@support-arabic/escaping.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/utils.lua',
    'server/finance.lua'
}

ui_page 'html/index.html'

files {
    'config/client.lua',
    'config/shared.lua',
    'config/catalog.lua',
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/kit.css',
    'html/fonts/*.woff2',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
