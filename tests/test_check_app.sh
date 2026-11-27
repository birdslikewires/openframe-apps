#!/bin/bash
# test_check_app.sh tests ci/check-app.sh, which stands between a recipe and every OpenFrame. A plain app's package passes, and each way a package could do more than an app should is refused. Packages made by hand here (not by ci/build-app.sh, which wouldn't make them), in an i386 Debian Trixie container (Docker) unless it's root in one already:
#   bash tests/test_check_app.sh
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
if [ "$(id -u)" -ne 0 ] || [ ! -e /.dockerenv ]; then
	exec docker run --rm --network none --platform linux/386 -v "$HERE:/src:ro" \
		i386/debian:trixie bash /src/tests/test_check_app.sh
fi
FAILS=0
W=$(mktemp -d)
printf 'clock radio\nhome = house\n' > "$W/icons.txt"

# A plain app, "demo", in $W/pkg; each case changes a copy of it
mkdir -p "$W/pkg/DEBIAN" "$W/pkg/usr/lib/ofapp-demo" "$W/pkg/usr/share/sprite/apps" "$W/pkg/usr/share/doc/ofapp-demo"
printf '#!/bin/sh\necho hi\n' > "$W/pkg/usr/lib/ofapp-demo/run"; chmod 755 "$W/pkg/usr/lib/ofapp-demo/run"
printf 'name=Demo\nexec=/usr/lib/ofapp-demo/run\nicon=clock\ncolor=2a6f97\nallow=network\n' > "$W/pkg/usr/share/sprite/apps/demo.app"
echo copyright > "$W/pkg/usr/share/doc/ofapp-demo/copyright"
cat > "$W/pkg/DEBIAN/control" <<'EOF'
Package: ofapp-demo
Version: 26.11.1
Architecture: all
Maintainer: OpenFrame Project <noreply@openbeak.net>
Description: A demo
X-Sprite-Name: Demo
X-Sprite-Kind: app
X-Sprite-Allow: network
X-Sprite-Community: https://example.org/demo
EOF
touch "$W/pkg/DEBIAN/md5sums"

# case <name> <expect pass|fail> <shell to change the copy, run in it>
case_() {
	local name=$1 want=$2 change=$3 d="$W/case" got
	rm -rf "$d"; cp -a "$W/pkg" "$d"
	(cd "$d" && eval "$change")
	owner=--root-owner-group; [[ "$change" == *chown* ]] && owner=""
	dpkg-deb $owner --build "$d" "$W/t.deb" > /dev/null 2>&1 || { echo "FAIL $name: couldn't build the test package"; FAILS=$((FAILS + 1)); return; }
	if out=$(bash "$HERE/ci/check-app.sh" "$W/t.deb" demo "$W/icons.txt" 2>&1); then got=pass; else got=fail; fi
	if [ "$got" = "$want" ]; then echo "ok   $name ($want)"; else
		echo "FAIL $name: expected $want, got $got"; sed 's/^/       /' <<< "$out"; FAILS=$((FAILS + 1)); fi
}

case_ "a plain app" pass ':'
case_ "an icon alias" pass 'sed -i s/icon=clock/icon=home/ usr/share/sprite/apps/demo.app'
case_ "two letters for an icon" pass 'sed -i s/icon=clock/icon=HC/ usr/share/sprite/apps/demo.app'
case_ "a symlink inside its places" pass 'mkdir -p usr/share/ofapp-demo && ln -s ../../lib/ofapp-demo/run usr/share/ofapp-demo/run'
case_ "a screensaver" pass 'echo kind=screensaver >> usr/share/sprite/apps/demo.app; sed -i s/X-Sprite-Kind:.app/X-Sprite-Kind:\ screensaver/ DEBIAN/control'
case_ "no community" fail 'sed -i /^X-Sprite-Community/d DEBIAN/control'
case_ "a community not https" fail 'sed -i s/https:/http:/ DEBIAN/control'
case_ "a postinst" fail 'printf "#!/bin/sh\n" > DEBIAN/postinst; chmod 755 DEBIAN/postinst'
case_ "a preinst" fail 'printf "#!/bin/sh\n" > DEBIAN/preinst; chmod 755 DEBIAN/preinst'
case_ "triggers" fail 'echo "interest /usr" > DEBIAN/triggers'
case_ "conffiles" fail 'mkdir -p usr/share/ofapp-demo && echo x > usr/share/ofapp-demo/x && echo /usr/share/ofapp-demo/x > DEBIAN/conffiles'
case_ "a file in /usr/bin" fail 'mkdir -p usr/bin && cp usr/lib/ofapp-demo/run usr/bin/demo'
case_ "a file in /etc" fail 'mkdir -p etc/sudoers.d && echo x > etc/sudoers.d/demo'
case_ "another app's manifest" fail 'cp usr/share/sprite/apps/demo.app usr/share/sprite/apps/settings.app'
case_ "another app's places" fail 'mkdir -p usr/lib/ofapp-demo2 && echo x > usr/lib/ofapp-demo2/x'
case_ "a prefix of its places" fail 'mkdir -p usr/lib/ofapp-demox && echo x > usr/lib/ofapp-demox/x'
case_ "setuid" fail 'chmod 4755 usr/lib/ofapp-demo/run'
case_ "setgid" fail 'chmod 2755 usr/lib/ofapp-demo/run'
case_ "world-writable" fail 'chmod 666 usr/share/doc/ofapp-demo/copyright'
case_ "a sticky folder" fail 'mkdir -p usr/share/ofapp-demo && chmod 1777 usr/share/ofapp-demo'
case_ "not root's" fail 'chown -R 1000:1000 usr/lib/ofapp-demo'
case_ "a symlink up and out" fail 'ln -s ../../../../etc/shadow usr/lib/ofapp-demo/shadow'
case_ "an absolute symlink out" fail 'ln -s /etc/shadow usr/lib/ofapp-demo/shadow'
case_ "a symlink to its sibling" fail 'ln -s ../ofapp-demo2 usr/lib/ofapp-demo/x'
case_ "a symlinked folder out" fail 'mkdir -p usr/share/ofapp-demo && ln -s /etc usr/share/ofapp-demo/etc'
case_ "the manifest a symlink" fail 'mv usr/share/sprite/apps/demo.app usr/lib/ofapp-demo/demo.app && ln -s ../../../lib/ofapp-demo/demo.app usr/share/sprite/apps/demo.app'
case_ "a device" fail 'mknod usr/lib/ofapp-demo/mem c 1 1'
case_ "a fifo" fail 'mkfifo usr/lib/ofapp-demo/fifo'
case_ "a name with a space" fail 'echo x > "usr/lib/ofapp-demo/a b"'
case_ "a name with a space, then a path" fail 'mkdir -p "usr/lib/ofapp-demo/a usr/lib/ofapp-demo" && echo x > "usr/lib/ofapp-demo/a usr/lib/ofapp-demo/b"'
case_ "a symlink with a space" fail 'ln -s "/etc/shadow x" usr/lib/ofapp-demo/l'
case_ "a name with a quote" fail "echo x > \"usr/lib/ofapp-demo/a'b\""
case_ "a name with a tab" fail 'echo x > "usr/lib/ofapp-demo/a	b"'
case_ "no manifest" fail 'rm usr/share/sprite/apps/demo.app'
case_ "Conflicts" fail 'echo "Conflicts: openframe-scripts" >> DEBIAN/control'
case_ "Breaks" fail 'echo "Breaks: openframe-sprite" >> DEBIAN/control'
case_ "Replaces" fail 'echo "Replaces: openframe-scripts" >> DEBIAN/control'
case_ "Provides" fail 'echo "Provides: openframe-scripts" >> DEBIAN/control'
case_ "Pre-Depends" fail 'echo "Pre-Depends: openframe-scripts" >> DEBIAN/control'
case_ "Essential" fail 'echo "Essential: yes" >> DEBIAN/control'
case_ "another package's name" fail 'sed -i s/^Package:.*/Package:\ openframe-scripts/ DEBIAN/control'
case_ "builtin=" fail 'echo builtin=settings >> usr/share/sprite/apps/demo.app'
case_ "an unknown manifest key" fail 'echo sudo=yes >> usr/share/sprite/apps/demo.app'
case_ "an icon it doesn't have" fail 'sed -i s/icon=clock/icon=skull/ usr/share/sprite/apps/demo.app'
case_ "allow= something else" fail 'sed -i "s/allow=network/allow=network root/" usr/share/sprite/apps/demo.app'
case_ "no exec=" fail 'sed -i /^exec=/d usr/share/sprite/apps/demo.app'
case_ "a name not the Shop's" fail 'sed -i s/X-Sprite-Name:.*/X-Sprite-Name:\ Other/ DEBIAN/control'
case_ "a kind not the Shop's" fail 'echo kind=screensaver >> usr/share/sprite/apps/demo.app'
case_ "a colour that isn't one" fail 'sed -i s/color=2a6f97/color=blue/ usr/share/sprite/apps/demo.app'
case_ "a symlink by way of another" fail 'mkdir -p usr/lib/ofapp-demo/d1/d2/d3/d4 && ln -s /usr/lib/ofapp-demo usr/lib/ofapp-demo/d1/d2/d3/d4/b && ln -s d1/d2/d3/d4/b/../../../../etc usr/lib/ofapp-demo/a'
case_ "a symlink to a symlink" pass 'ln -s run usr/lib/ofapp-demo/run2 && ln -s run2 usr/lib/ofapp-demo/run3'
case_ "a service" pass 'printf "kind=service\nweb=9000\nmemory=320\n" >> usr/share/sprite/apps/demo.app; sed -i s/X-Sprite-Kind:.app/X-Sprite-Kind:\ service/ DEBIAN/control'
case_ "web= for an app" fail 'echo web=9000 >> usr/share/sprite/apps/demo.app'
case_ "memory= past 320" fail 'printf "kind=service\nmemory=512\n" >> usr/share/sprite/apps/demo.app; sed -i s/X-Sprite-Kind:.app/X-Sprite-Kind:\ service/ DEBIAN/control'
case_ "allow=music" pass 'sed -i "s/allow=network/allow=network music/" usr/share/sprite/apps/demo.app; sed -i "s/X-Sprite-Allow:.*/X-Sprite-Allow: network music/" DEBIAN/control'
case_ "allow=lowports, an app's" fail 'sed -i "s/allow=network/allow=network lowports/" usr/share/sprite/apps/demo.app; sed -i "s/X-Sprite-Allow:.*/X-Sprite-Allow: network lowports/" DEBIAN/control'
case_ "allow=lowports, a service's" pass 'echo kind=service >> usr/share/sprite/apps/demo.app; sed -i "s/allow=network/allow=network lowports/" usr/share/sprite/apps/demo.app; sed -i "s/X-Sprite-Allow:.*/X-Sprite-Allow: network lowports/; s/X-Sprite-Kind:.app/X-Sprite-Kind: service/" DEBIAN/control'
case_ "an Allow not the manifest's" fail 'sed -i "s/X-Sprite-Allow:.*/X-Sprite-Allow: sound/" DEBIAN/control'
case_ "Depends on packages" pass 'echo "Depends: libc6 (>= 2.38), perl, zlib1g (>= 1:1.1.4) | libz-dev" >> DEBIAN/control'
case_ "an odd Depends" fail 'echo "Depends: libc6:amd64" >> DEBIAN/control'
case_ "a manifest line past 500" fail 'printf "#%0600d\nbuiltin=settings\n" 0 >> usr/share/sprite/apps/demo.app'

echo
[ "$FAILS" -eq 0 ] && echo "All passed." || { echo "$FAILS failed."; exit 1; }
