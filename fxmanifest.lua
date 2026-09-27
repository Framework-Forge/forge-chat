fx_version 'cerulean'
game 'gta5'
lua54 'yes'
version '1.4.0'

author 'Mystic & Rainfalls / layout update'
description 'Chat FiveM em Svelte com visual personalizável, emojis, GIPHY e stickers administráveis'

ui_page 'html/index.html'

shared_scripts {
    '@pr_bridge/init.lua',
    'config.lua'
}

client_script 'cl_chat.lua'

server_scripts {
    'config_server.lua',
    'sv_chat.lua'
}

files {
    'html/index.html',
    'html/assets/*',
    'keyboard.mp3',
    'data/stickers.json',
    'data/chat_settings.json'
}

escrow_ignore {
    'config.lua',
    'config_server.lua',
    'sv_chat.lua',
    'cl_chat.lua',
    'data/stickers.json',
    'data/chat_settings.json'
}


