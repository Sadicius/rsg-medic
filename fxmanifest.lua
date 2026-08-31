fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-medic'
version '2.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

ui_page 'html/index.html'

client_scripts {
    'client/client.lua',
    'client/job.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhook.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'rsg-core',
    'rsg-bossmenu',
    'ox_lib'
}

lua54 'yes'
