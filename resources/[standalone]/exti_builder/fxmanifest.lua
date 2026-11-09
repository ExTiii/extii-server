fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_builder'
author 'EX_Tii'
description 'In-game builder for admins: place any GTA object where you look (/build), shared with everyone and kept after restarts'
version '1.0.0'

dependencies { 'ox_lib' }

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'

-- the names of the game's objects, to search in the menu (a list of names only)
files { 'data/objects.txt' }
