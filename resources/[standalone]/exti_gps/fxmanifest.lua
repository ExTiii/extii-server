fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_gps'
author 'EX_Tii'
description 'Thin gold GPS line for job routes and the "take me there" buttons'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

-- Arabic letters in GTA built-in text (the destination icon name)
client_script '@support-arabic/escaping.lua'
client_script 'client.lua'

server_script 'server.lua'
