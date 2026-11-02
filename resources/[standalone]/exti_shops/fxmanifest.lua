fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_shops'
author 'EX_Tii'
description '24/7, liquor, tool and gun shops: shopkeeper + gold circle + E, own shop panel'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

-- Arabic letters in GTA built-in text (map icon names)
client_script '@support-arabic/escaping.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua',
    'sign.lua',
}

server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/kit.css',
    'html/app.js',
    'html/sign.html',
    'html/fonts/*.woff2',
}
