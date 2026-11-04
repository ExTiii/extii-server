newplayer_guide — for Qbox servers
==================================

What it does
- Welcome popup (Arabic) the first time a new character spawns
- Starter kit: 3 water + 3 burgers, once per character
- /guide menu in Arabic: first steps, first jobs, keys, short rules, help
- "Mark City Hall on my map" button
- Safe zones: no shooting or fighting at City Services, Legion Square
  and Pillbox Hospital (police and EMS are not blocked)
- "NEW" tag above new players' heads for their first 5 hours
- /newplayers for staff: list of new players online, so you can help them

Needs: ox_lib, qbx_core, ox_inventory (all come with the Qbox recipe)

Install
1. Upload the whole "newplayer_guide" folder into your server's
   "resources" folder (NOT inside [qbx] or [standalone]).
2. Open config.lua and change Config.serverName and Config.discord.
3. Add this line at the bottom of server.cfg:   ensure newplayer_guide
4. Restart the server.

Test it
- Make a NEW character: the welcome popup should show after you spawn.
- Type /guide in chat (T).
- Walk into City Services and try to punch: it should be blocked.
- Staff: type /newplayers.

Everything players read is in config.lua, so you can change any text there.
