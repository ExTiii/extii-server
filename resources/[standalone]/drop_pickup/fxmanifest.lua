fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'drop_pickup'
description 'التقاط الأغراض من الأرض بزر E بدون فتح الحقيبة (Pick up dropped items with E)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'ox_lib',
    'ox_inventory',
}
