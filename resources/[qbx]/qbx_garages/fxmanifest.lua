fx_version 'cerulean'
game 'gta5'

name 'qbx_garages'
description 'Garage system for Qbox'
repository 'https://github.com/Qbox-project/qbx_garages'
version '1.1.4'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/*',
}

-- Arabic letters in GTA built-in text (must load before the other client scripts)
client_script '@support-arabic/escaping.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/photos.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/default-calculate-impound-fee.lua',
    'server/main.lua',
    'server/spawn-vehicle.lua',
    'server/garage_ui.lua',
    'server/savespot.lua',
    'server/photos.lua',
    'server/autoimpound.lua',
}

ui_page 'html/index.html'

files {
    'config/client.lua',
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/kit.css',
    'html/fonts/*.woff2',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
