fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'exti_postals'
author 'EX_Tii Roleplay'
description 'EX_Tii: the postal code map (numbers on the big map and the minimap), the nearest postal above the minimap, /postal 123 sets a waypoint'

-- the map textures: "Postal Code Map & Minimap - New & Improved" by Virus_City (cfx.re community release, free with credit)
-- the postal list: nearest-postal by BlockBa5her / DevBlocky (MIT), new-postals.json
client_scripts { '@ox_lib/init.lua', '@support-arabic/escaping.lua', 'client.lua' }
files { 'data/postals.json' }
