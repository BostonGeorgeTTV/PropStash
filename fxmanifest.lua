fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'propstash'
author 'BostonGeorgeTTV'
description 'Config-driven prop stashes with native ox_inventory UI, access hooks, item whitelist via swapItems, and ESX/QBCore/Qbox bridges.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

escrow_ignore {
    'config.lua',
    'shared/utils.lua',
    'server/bridge.lua',
}