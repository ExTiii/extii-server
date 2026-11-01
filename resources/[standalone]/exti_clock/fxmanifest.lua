fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'exti_clock'
author 'EX_Tii'
description 'Small gold clock (top-left): in-game time, day / night, weather'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_script '@ox_lib/init.lua'
client_script 'client.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/kit.css',
    'html/app.js',
    'html/fonts/*.woff2',
}
