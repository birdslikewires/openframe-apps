# HamClock for the OpenFrame's 800x480 screen, from openhamclock/hamclock's stable release (HC_RELEASE-stable.txt there). shop.txt's version= is the release; change SHA256 with it. It isn't setuid, unlike upstream's 'make install' as root, which only needs that for GPIO on a Raspberry Pi.
SHA256=90db9bb4384cda483c5fb7b8589fc24201894c77bc8d3a0870d7f51d4aa6253c
TAG=v$UPSTREAM.0
ZIP=ESPHamClock-V$UPSTREAM.zip

curl -fsSL -o "$ZIP" "https://github.com/openhamclock/hamclock/releases/download/$TAG/$ZIP"
echo "$SHA256  $ZIP" | sha256sum -c -
unzip -q "$ZIP"
# idle.patch: HamClock's main loop rests 20 ms after a pass that found nothing to do, unless the map is mid-sweep (app.txt runs it with -t 100, the loop it patches). Its own -t throttle times each pass with getrusage, which on a kernel that counts CPU time in 4 ms ticks reads most passes as free, so it polled about 800 times a second whatever -t said: 4 to 14% of a core on an OpenFrame 1, against 0.4% now. If a new release changes that loop, the patch fails and stops the build, to be looked at again.
patch -p1 < "$RECIPE/idle.patch"
# NO_UPGRADE leaves out HamClock's own updater, which fetches the source and builds it on the device. There's no compiler on an OpenFrame, and the sandbox can't write over the program, so it could only fail. Updates come as packages, from this recipe. NO_SYSTEM_CONTROLS leaves out its menu's "Reboot computer" and "Shutdown computer", which the sandbox can't do either.
make -C ESPHamClock -j"$(nproc)" CXX="g++ -DNO_UPGRADE -DNO_SYSTEM_CONTROLS" hamclock-800x480 > build.log 2>&1 || { tail -40 build.log; exit 1; }

install -m 755 ESPHamClock/hamclock-800x480 "$DESTDIR$APPDIR/hamclock"
strip --strip-unneeded "$DESTDIR$APPDIR/hamclock"
{
	cat "$RECIPE/copyright"
	printf '\nLicense: MIT\n'; sed 's/^/ /; s/^ $/ ./' ESPHamClock/LICENSE
	printf '\nLicense: GPL-3.0-or-later\n On Debian systems, the full text is in /usr/share/common-licenses/GPL-3.\n'
} > "$DESTDIR$DOCDIR/copyright"
install -m 644 ESPHamClock/wsServer/LICENSE "$DESTDIR$DOCDIR/wsServer-LICENSE"
# wsServer is GPL-3.0, so the source goes with it
cp "$ZIP" "$SOURCES/"
