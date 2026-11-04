fx_version 'cerulean'
game 'gta5'

name 'qbx_spawn'
description 'Spawn selection for Qbox'
repository 'https://github.com/Qbox-project/qbx_spawn'
version '0.1.1'

ox_lib 'locale'

shared_script '@ox_lib/init.lua'

-- Arabic letters in GTA built-in text (must load before the other client scripts)
client_script '@support-arabic/escaping.lua'
client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'config/client.lua',
    'locales/*.json'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
