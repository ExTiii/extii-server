fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_fuel'
author 'EX_Tii'
description 'Gas stations: map icons, gold circle at every pump, E to fill up or charge, nozzle + hose, jerry can'
version '1.0.0'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

-- Arabic letters in GTA built-in text (map icon names)
client_script '@support-arabic/escaping.lua'
client_script 'client.lua'

server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/kit.css',
    'html/app.js',
    'html/fonts/*.woff2',
}
