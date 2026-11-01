fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_hospital'
author 'EX_Tii'
description 'EX_Tii hospitals: reception panel (free treatment, check-up with a medical report, call a medic)'
version '1.0.0'

-- the receptionist and the pharmacist stand in the hospitals thanks to exti_shops;
-- the beds, the treatment and waking up after dying are qbx_ambulancejob's
dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'qbx_ambulancejob',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua',
}

server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/kit.css',
    'html/fonts/*.woff2',
}
