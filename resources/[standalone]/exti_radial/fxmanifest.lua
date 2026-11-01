fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_radial'
description 'EX_Tii: the radial menu (Z wheel)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/vehicle.lua',
    'client/clothing.lua',
    'client/walk.lua',
    'client/blips.lua',
    'client/actions.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/radial.css',
    'html/radial.js',
    'html/icons.js',
    'html/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
