fx_version "cerulean"
game "common"

name "httpmanager"
author "kibukj"
description "HTTP handler library for FiveM and RedM"
repository "https://github.com/kibook/httpmanager"

server_only "yes"

server_scripts {
	"url.lua",
	"mime.lua",
	"httphandler.lua",
	"main.lua"
}
