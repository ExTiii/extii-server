fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'npwd_city'
description 'تطبيقات الهاتف: البنك والأماكن والطوارئ (Bank, Places, 911 for NPWD)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    -- Arabic letters in GTA built-in text (must load before the other client scripts)
    '@support-arabic/escaping.lua',
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
