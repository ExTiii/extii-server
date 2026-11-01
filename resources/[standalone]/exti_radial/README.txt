EX_Tii radial menu (the Z wheel) - exti_radial
=============================================
Replaces qbx_radialmenu. To put the old one back: copy the manifest below over
[qbx]/qbx_radialmenu/fxmanifest.lua, then stop exti_radial (or remove this folder) and restart.

--- the original [qbx]/qbx_radialmenu/fxmanifest.lua ---
fx_version 'cerulean'
game 'gta5'

description 'qbx_radialmenu'
repository 'https://github.com/Qbox-project/qbx_radialmenu'
version '0.1.0'
ox_lib 'locale'


shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

-- Arabic letters in GTA built-in text (must load before the other client scripts)
client_script '@support-arabic/escaping.lua'
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

files {
    'config/client.lua',
    'locales/*.json',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
