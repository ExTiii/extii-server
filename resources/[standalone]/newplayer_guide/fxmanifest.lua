fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'newplayer_guide'
description 'Arabic new-player guide, welcome, starter kit, safe zones and NEW tag for Qbox'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@support-arabic/escaping.lua',
    'client.lua',
}
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/guide.css',
    'html/guide.js',
    'html/kit.css',
    'html/logo.png',
    'html/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}
