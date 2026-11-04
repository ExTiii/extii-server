fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_characters'
author 'EX_Tii Roleplay'
description 'Choose / create your character, design the look, arrive in the city (one spawn for new players)'
version '1.2.0'

dependencies {
    'ox_lib',
    'qbx_core',
}

shared_script '@ox_lib/init.lua'

-- Arabic letters in GTA built-in text (must load before the other client scripts)
client_script '@support-arabic/escaping.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'config.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/kit.css',
    'html/logo.png',
    'html/fonts/*.woff2',
}
