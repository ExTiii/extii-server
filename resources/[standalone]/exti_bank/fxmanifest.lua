fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_bank'
author 'EX_Tii'
description 'EX_Tii Bank: tablet at the bank teller, ATM screen, safe deposit / withdraw / transfer, clear history, bills (fines) paid at the bank'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/kit.css',
    'html/app.js',
    'html/fonts/*.woff2',
}
