fx_version "cerulean"
game { "gta5" }

author 'nyx-development'
description 'elevator script.'
version '1.0.0'
lua54 "yes"
use_experimental_fxv2_oal "yes"
client_scripts {
  'Client.lua',
}
shared_scripts {
  "@ox_lib/init.lua",
  "@qbx_core/modules/playerdata.lua",
  'Config.lua',
}
server_scripts {
  "@oxmysql/lib/MySQL.lua",
  'Server.lua',
}
files {
  'web/index.html',
  'web/asset-manifest.json',
  'web/static/js/*.js',
  'web/static/css/*.css',
}

ui_page 'web/index.html'
