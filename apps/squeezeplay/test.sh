# squeezelite runs, and was built with the formats and features the recipe asks for.
D=/usr/lib/ofapp-squeezeplay
set +e; "$D/bin/squeezelite" -? > usage.txt 2>&1; set -e
grep -q '^Squeezelite 2\.' usage.txt
for o in LINKALL RESAMPLE DSD OPUS VISEXPORT; do grep -q "^Build options:.* $o\b" usage.txt || { echo "squeezelite isn't built with $o"; exit 1; }; done
# JiveLite has everything it links against but SDL, which the interface brings (it isn't installed here, so JiveLite can't start).
missing=$(ldd "$D/bin/jivelite" | awk '/not found/ { print $1 }')
[ "$missing" = libSDL-1.2.so.0 ] || { echo "jivelite is missing: $missing"; exit 1; }
# Its Lua modules, its Lua and the Joggler skin are where it looks for them, beside its program.
for m in cjson lfs lxp md5 mime sha1 socket zipfilter; do [ -f "$D/lib/lua/5.1/$m.so" ] || { echo "no Lua module $m"; exit 1; }; done
[ -f "$D/share/jive/jive/JiveMain.lua" ] && [ -f "$D/share/lua/5.1/loop/simple.lua" ]
[ -f "$D/share/jive/applets/JogglerSkin/JogglerSkinApplet.lua" ]
