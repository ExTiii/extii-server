fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_world'
author 'EX_Tii'
description 'World rules: no wanted stars or GTA police, friendly street gangs, calmer traffic, GTA HUD bits hidden, no weapon wheel'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_script '@ox_lib/init.lua'
client_script 'client.lua'
server_script 'server.lua'
