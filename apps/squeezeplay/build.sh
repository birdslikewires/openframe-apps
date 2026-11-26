# SqueezePlay for the OpenFrame: JiveLite, the Squeezebox interface, and squeezelite, the player, from Ralph Irving's repositories. Neither has releases, so each is pinned to a commit, fetched as GitHub's archive of it and checked against its SHA-256. To update, change a commit and its SHA-256 together.
JIVELITE=d43a20b1a0248925296e387e016b320b9785e7c4
JIVELITE_SHA256=44a5ccf7d11d64ce7ff435ddcc0cf19c8631bfe2b4f47f6fb10c0650a8e75b48
SQUEEZELITE=b02a9ac77794c9914fa2b70caa98010e9f23cc2d
SQUEEZELITE_SHA256=aaba1edae29a5ac2722fd71945aaa97d4406b424d4e710a6eaae0e99ef7c3f33

fetch() { # name commit sha256
	curl -fsSL -o "$1.tar.gz" "https://github.com/ralph-irving/$1/archive/$2.tar.gz"
	echo "$3  $1.tar.gz" | sha256sum -c - > /dev/null
	tar -xzf "$1.tar.gz" && mv "$1-$2" "$1"
}
fetch jivelite "$JIVELITE" "$JIVELITE_SHA256"
fetch squeezelite "$SQUEEZELITE" "$SQUEEZELITE_SHA256"

# The upstream Makefiles run without this build's own settings in their environment (JiveLite's would take SOURCES, which is where the source goes here, as its list of files).
umake() { env -u SOURCES -u DESTDIR -u APPDIR -u SHAREDIR -u DOCDIR make "$@"; }

# JiveLite. SDL_ttf, SDL_image and SDL_gfx are built into it from Debian's static libraries, as Debian's shared ones depend on Debian's SDL, which brings Mesa. SDL itself is the interface's, sdl12-compat built without Mesa, which every app is given. It's on LuaJIT 2.1, Debian's, which upstream's Makefile only expects on aarch64, so LUAJIT_VERSION=21 is set here, for the program and its Lua modules alike. (Settings given to make replace the Makefiles' own, so these are complete.)
umake -C jivelite/src -j"$(nproc)" \
	CFLAGS="-O2 -Wall -fPIC -DLUAJIT_VERSION=21 -I. -I/usr/include/luajit-2.1 $(sdl-config --cflags)" \
	LDFLAGS="-lrt -Wl,-Bstatic -lSDL_ttf -lSDL_image -lSDL_gfx -Wl,-Bdynamic -lfreetype -lpng16 -ljpeg -ltiff -lwebp -lz -lSDL -lluajit-5.1 -lm -lpthread" \
	> jivelite.log 2>&1 || { tail -40 jivelite.log; exit 1; }
CFLAGS="-O2 -fPIC -DLUAJIT_VERSION=21" LUAJIT_VERSION=2.1 PREFIX=/usr umake -C jivelite/lib-src > lua.log 2>&1 || { tail -40 lua.log; exit 1; }

# squeezelite, linked to the libraries for each format it plays (FLAC, Ogg Vorbis, Opus, MP3, AAC, DSD), rather than loading them as it finds them, so the package depends on them. It shares its sound for JiveLite's visualisers (VISEXPORT), resamples when asked to (RESAMPLE), and plays https streams (USE_SSL). There's no ffmpeg, for ALAC and WMA: Lyrion converts those for players that can't play them.
umake -C squeezelite -j"$(nproc)" \
	CFLAGS="-O2 -Wall -fPIC -fcommon -std=gnu99 $(pkg-config --cflags opusfile)" \
	OPTS="-DLINKALL -DRESAMPLE -DDSD -DOPUS -DVISEXPORT -DUSE_SSL -DNO_SSLSYM" \
	> squeezelite.log 2>&1 || { tail -40 squeezelite.log; exit 1; }

# JiveLite looks for its Lua beside its program, in ../share and ../lib, so share/ points to the package's data.
install -d "$DESTDIR$APPDIR/bin" "$DESTDIR$APPDIR/lib"
install -m 755 jivelite/bin/jivelite squeezelite/squeezelite "$DESTDIR$APPDIR/bin/"
cp -r jivelite/lib/lua "$DESTDIR$APPDIR/lib/"
cp -r jivelite/share/jive jivelite/share/lua "$DESTDIR$SHAREDIR/"
ln -s "../../share/$PKG" "$DESTDIR$APPDIR/share"
install -m 755 "$RECIPE/squeezeplay" "$DESTDIR$APPDIR/squeezeplay"
find "$DESTDIR$APPDIR" -type f \( -name '*.so' -o -path '*/bin/*' \) -exec strip --strip-unneeded {} +

{
	cat "$RECIPE/copyright"
	printf '\nLicense: BSD-3-Clause\n'; sed 's/^/ /; s/^ $/ ./' jivelite/LICENSE
	printf '\nLicense: GPL-3.0-or-later\n'; sed 's/^/ /; s/^ $/ ./' squeezelite/LICENSE.txt
	printf ' .\n On Debian systems, the full text of the GPL is in /usr/share/common-licenses/GPL-3.\n'
} > "$DESTDIR$DOCDIR/copyright"
# squeezelite is GPL-3.0, so its source goes with it, and JiveLite's too, as they're one app
cp jivelite.tar.gz squeezelite.tar.gz "$SOURCES/"
