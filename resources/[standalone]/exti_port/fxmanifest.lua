fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_port'
author 'EX_Tii'
description 'The port terminal: a fence all around, one gate at the front, small doors by the water (marked in game by an admin with /port)'
version '1.0.0'

dependencies { 'ox_lib' }

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'client.lua', 'client_gate.lua' }
server_scripts { 'server.lua', 'npc.lua' }
