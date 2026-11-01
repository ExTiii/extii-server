fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_medical'
author 'EX_Tii'
description 'EX_Tii medical: quiet injury records (where you were hit, by what), vitals, the medic exam on the EMS tablet and the step by step treatment'
version '1.0.0'

dependencies {
    'ox_lib',
    'qbx_core',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/wounds.lua',
    'server/vitals.lua',
    'server/exam.lua',
    'server/treat.lua',
    'server/fake.lua',
}
