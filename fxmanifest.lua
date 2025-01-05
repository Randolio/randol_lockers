fx_version 'cerulean'
game 'gta5'

author 'Randolio'
description 'Storage Lockers'
ox_lib 'locale'

shared_scripts {
	'@ox_lib/init.lua',
	'shared.lua',
}

client_scripts {
	'bridge/client/**.lua',
	'client/*.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'bridge/server/**.lua',
	'server/*.lua'
}

files { 'locales/*.json' }

lua54 'yes'