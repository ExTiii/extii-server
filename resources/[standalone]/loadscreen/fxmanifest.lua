fx_version 'cerulean'
game 'gta5'

version '2.2.1'
description 'Clean and fully configurable loading screen for FiveM'
author 'David Malchin <malchin459@gmail.com>'
repository 'https://github.com/D4isDAVID/loadscreen'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

client_scripts {
    'client/shutdown.lua',
}

server_scripts {
    'server/handover.js',
}

-- EX_Tii: only what the loading screen really uses is downloaded (the old template's pictures, music
-- and videos stay on the disk but nobody downloads them any more: 7 MB instead of 21 MB)
files {
    'html/index.html',
    'html/kit.css',
    'html/fonts/*.woff2',
    'html/assets/logo.png',
    'html/ex/city.webm',
}

loadscreen 'html/index.html'
loadscreen_cursor 'yes'
loadscreen_manual_shutdown 'yes'
