fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'exti_jobs'
author 'EX_Tii Roleplay'
description 'EX_Tii jobs: job center tablet, HQs with supervisors, tow / garbage / delivery, level jobs (chicken, raisins)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

-- Arabic letters in GTA built-in text (the map icon names). Must load before the other client scripts.
client_script '@support-arabic/escaping.lua'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/uniforms.lua',
    'client/garbage.lua',
    'client/delivery.lua',
    'client/tow.lua',
    'client/chain.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'config/shared.lua',
    'config/spots.lua',
    'html/items/*.png',
    'html/index.html',
    'html/style.css',
    'html/kit.css',
    'html/app.js',
    'html/logo.png',
    'html/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}
