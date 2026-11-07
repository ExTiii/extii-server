fx_version 'cerulean'
game 'gta5'

description 'HUD for Qbox'
repository 'https://github.com/Qbox-project/qbx_hud'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

-- Arabic letters in GTA built-in text (must load before the other client scripts)
client_script '@support-arabic/escaping.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/custom_indicators.lua',
    'client/vehicle_extra.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/mileage.lua',
}

ui_page 'html/index.html'

files {
    'html/*',
    'html/index.html',
    'html/styles.css',
    'html/responsive.css',
    'html/app.js',
    'html/kit.css',
    'html/kit-hud.css',
    'html/fonts/*.woff2',
    'locales/*.json',
    'config/client.lua',
    'config/shared.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
