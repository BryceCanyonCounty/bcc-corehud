fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'


author 'BCC Scripts'
description 'Redm, NUI, Vuejs boilerplate'

shared_scripts {
   'shared/config/config.lua',
   'shared/locale.lua',
   'shared/languages/*.lua',
   'shared/config/needitems/*.lua',
}

client_scripts {
    'client/utilities.lua',
    'client/functions.lua',
    'client/MenuSetup.lua',
    'client/smokes.lua',
    'client/client.lua'
}

server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/dbUpdater.lua',
    'server/controllers.lua',
    'server/functions.lua',
    'server/server.lua'
}

ui_page 'ui/index.html'

files {
    "ui/index.html",
    "ui/**/*"
}

version '1.9.0'
