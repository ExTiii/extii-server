fx_version "cerulean"
game "gta5"

author "snakewiz & iLLeniumStudios"
description "A flexible player customization script for FiveM servers."
repository "https://github.com/iLLeniumStudios/illenium-appearance"
version "v5.7.0"

lua54 "yes"

client_scripts {
  "@support-arabic/escaping.lua",
  "game/constants.lua",
  "game/util.lua",
  "game/linked.lua",
  "game/customization.lua",
  "game/nui.lua",
  "client/outfits.lua",
  "client/common.lua",
  "client/zones.lua",
  "client/framework/framework.lua",
  "client/framework/qb/compatibility.lua",
  "client/framework/qb/main.lua",
  "client/framework/qb/migrate.lua",
  "client/framework/esx/compatibility.lua",
  "client/framework/esx/main.lua",
  "client/framework/ox/main.lua",
  "client/target/target.lua",
  "client/target/qb.lua",
  "client/target/ox.lua",
  "client/management/management.lua",
  "client/management/common.lua",
  "client/management/qb.lua",
  "client/management/qbx.lua",
  "client/management/esx.lua",
  "client/radial/radial.lua",
  "client/radial/qb.lua",
  "client/radial/ox.lua",
  "client/stats.lua",
  "client/defaults.lua",
  "client/blips.lua",
  "client/props.lua",
  "client/client.lua",
  "client/exti.lua",
  "client/photo.lua",
}

server_scripts {
  "@oxmysql/lib/MySQL.lua",
  "server/database/database.lua",
  "server/database/jobgrades.lua",
  "server/database/managementoutfits.lua",
  "server/database/playeroutfitcodes.lua",
  "server/database/playeroutfits.lua",
  "server/database/players.lua",
  "server/database/playerskins.lua",
  "server/database/users.lua",
  "server/framework/qb/main.lua",
  "server/framework/qb/migrate.lua",
  "server/framework/esx/main.lua",
  "server/framework/esx/migrate.lua",
  "server/framework/esx/callbacks.lua",
  "server/framework/esx/management.lua",
  "server/framework/ox/main.lua",
  "server/util.lua",
  "server/server.lua",
  "server/permissions.lua",
  "server/photo.lua"
}

shared_scripts {
  "shared/config.lua",
  "shared/blacklist.lua",
  "shared/peds.lua",
  "shared/tattoos.lua",
  "shared/theme.lua",
  "shared/framework/framework.lua",
  "shared/framework/esx/util.lua",
  "locales/locales.lua",
  "locales/ar.lua",
  "locales/bg.lua",
  "locales/cs.lua",
  "locales/de.lua",
  "locales/en.lua",
  "locales/es-ES.lua",
  "locales/fr.lua",
  "locales/hu.lua",
  "locales/it.lua",
  "locales/nl.lua",
  "locales/pt-BR.lua",
  "locales/ro-RO.lua",
  "locales/id.lua",
  "@ox_lib/init.lua"
}

files {
  "web/ex/index.html",
  "web/ex/*.js",
  "web/ex/*.css",
  "web/ex/fonts/*.woff2"
  -- (the pictures are in the exti_appearance_img resource)
}

-- EX_Tii: the new black & gold screen (web/ex). The old one is still in web/dist if ever needed.
ui_page "web/ex/index.html"
