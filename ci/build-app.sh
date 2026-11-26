#!/bin/bash
# ci/build-app.sh <recipe> <id> <version> <out>: builds an app's package, ofapp-<id>, from its recipe (apps/<id>/, read-only), into <out>. Run as root in a throwaway i386 Debian Trixie container (ci/build-apps.sh starts one), never on a runner with a signing key, because build.sh is the recipe's own code.
#
# The recipe's build.sh only puts files in place, under $DESTDIR, and only in the app's own places (APPDIR, SHAREDIR, DOCDIR). This script writes everything else, which is the manifest the interface reads (app.txt, as /usr/share/sprite/apps/<id>.app), the package's control file (what the Shop shows, from shop.txt and the manifest, as X-Sprite-* fields) and its dependencies (what its programs link against, and depends.txt). So a package has no maintainer scripts, no conffiles, and no say in its relations to other packages. ci/check-app.sh then checks the package as built, as if this script hadn't.
#
# build.sh runs with bash -eu, in a scratch directory ($WORK), with:
#   RECIPE    the recipe's folder (read-only)
#   DESTDIR   the package's root, so files go in $DESTDIR$APPDIR and so on
#   APPDIR    /usr/lib/ofapp-<id>      programs and libraries
#   SHAREDIR  /usr/share/ofapp-<id>    data
#   DOCDIR    /usr/share/doc/ofapp-<id>  copyright (from the recipe's copyright file, unless build.sh writes one) and any licences that go with it
#   SOURCES   where to put the source a licence says must go with it (a release's zip, say): published beside the package, at apps.openbeak.net/source/ofapp-<id>/<version>/
#   ID, PKG, VERSION (the package's), UPSTREAM (shop.txt's version=, if any)
# with build-depends.txt's packages installed and the network there to fetch the source. A recipe fetches a pinned release and checks it against its SHA-256.
set -euo pipefail
RECIPE=$1 ID=$2 VERSION=$3 OUT=$4
PKG=ofapp-$ID
APPDIR=/usr/lib/$PKG SHAREDIR=/usr/share/$PKG DOCDIR=/usr/share/doc/$PKG
UPSTREAM=$(sed -n 's/^version=//p' "$RECIPE/shop.txt" | tail -1 | tr -d '[:space:]')

export DEBIAN_FRONTEND=noninteractive
apt-get -qq --error-on=any update
# shellcheck disable=SC2046
apt-get -qq install -y --no-install-recommends dpkg-dev file ca-certificates curl \
	$( [ -f "$RECIPE/build-depends.txt" ] && sed 's/#.*//' "$RECIPE/build-depends.txt" ) > /dev/null

WORK=$(mktemp -d) DESTDIR=$(mktemp -d) SOURCES="$OUT/source"
mkdir -p "$SOURCES" "$DESTDIR$APPDIR" "$DESTDIR$SHAREDIR" "$DESTDIR$DOCDIR"
chmod 755 "$DESTDIR"
echo "Building $PKG $VERSION"
(
	cd "$WORK"
	export RECIPE DESTDIR APPDIR SHAREDIR DOCDIR SOURCES ID PKG VERSION UPSTREAM
	bash -eu "$RECIPE/build.sh"
) || { echo "$ID: build.sh failed"; exit 1; }

# The recipe may not write its own control files (ci/check-app.sh checks the package as well)
[ ! -e "$DESTDIR/DEBIAN" ] || { echo "$ID: build.sh made DEBIAN/: the package's control files aren't the recipe's"; exit 1; }

# The manifest, and the copyright
install -d "$DESTDIR/usr/share/sprite/apps"
install -m 644 "$RECIPE/app.txt" "$DESTDIR/usr/share/sprite/apps/$ID.app"
if [ ! -e "$DESTDIR$DOCDIR/copyright" ]; then
	[ -f "$RECIPE/copyright" ] || { echo "$ID: no copyright (the recipe's copyright file, or build.sh's)"; exit 1; }
	install -m 644 "$RECIPE/copyright" "$DESTDIR$DOCDIR/copyright"
fi
# empty places left out, and everything root's, readable, nobody else's to write
find "$DESTDIR" -mindepth 1 -type d -empty -delete
chown -R 0:0 "$DESTDIR"
chmod -R u+rwX,go+rX,go-w "$DESTDIR"

# Dependencies, from what its programs and libraries link against and from depends.txt
elfs=$(find "$DESTDIR" -type f -exec sh -c 'file -b "$1" | grep -q "^ELF" && echo "$1"' _ {} \;)
arch=all deps=""
if [ -n "$elfs" ]; then
	arch=i386
	mkdir -p "$WORK/shlibs/debian"
	printf 'Source: %s\n\nPackage: %s\nArchitecture: i386\n' "$PKG" "$PKG" > "$WORK/shlibs/debian/control"
	# SDL 1.2 (sdl12-compat) and SDL2 come with the interface, built without Mesa, and every app is given them (openframe-sprite's /opt/sprite/lib). Debian's packages of them bring Mesa, so a program linked against them depends on no package for them.
	printf 'libSDL-1.2 0\nlibSDL2-2.0 0\n' > "$WORK/shlibs/debian/shlibs.local"
	# shellcheck disable=SC2086
	deps=$(cd "$WORK/shlibs" && dpkg-shlibdeps -O -l"$DESTDIR$APPDIR" $elfs 2>/dev/null | sed -n 's/^shlibs:Depends=//p')
fi
if [ -f "$RECIPE/depends.txt" ]; then
	more=$(sed 's/#.*//' "$RECIPE/depends.txt" | tr -s ' \t\n' '\n' | grep -v '^$' | paste -sd, - | sed 's/,/, /g')
	deps="${deps:+$deps${more:+, }}$more"
fi

# What the Shop shows comes from shop.txt (key=value lines, a blank line, then the description, a line to each paragraph) and the manifest's name, icon, colour, kind and what it may reach.
field() { sed -n "s/^$1=//p" "$2" | tail -1 | sed 's/[[:space:]]*$//'; }
summary=$(field summary "$RECIPE/shop.txt")
[ -n "$summary" ] || { echo "$ID: shop.txt has no summary="; exit 1; }
# (we don't support the apps ourselves, so each says where its own community answers questions)
community=$(field community "$RECIPE/shop.txt")
[[ "$community" =~ ^https://[^[:space:]]+$ ]] || { echo "$ID: shop.txt needs community=, an https:// address"; exit 1; }
# (in Debian's form, each line indented a space, with " ." between paragraphs; blank lines in shop.txt are only there to read it by)
description=$(awk '!f { if ($0 ~ /^[[:space:]]*$/) f = 1; next }
	/^[[:space:]]*$/ { next }
	{ if (n) print " ."; n = 1; print " " $0 }' "$RECIPE/shop.txt")
size=$(du -sk --apparent-size "$DESTDIR" | cut -f1)
{
	echo "Package: $PKG"
	echo "Version: $VERSION"
	echo "Architecture: $arch"
	echo "Section: misc"
	echo "Priority: optional"
	echo "Maintainer: OpenFrame Project <noreply@openbeak.net>"
	echo "Installed-Size: $size"
	[ -z "$deps" ] || echo "Depends: $deps"
	src=$(field source "$RECIPE/shop.txt"); [ -z "$src" ] || echo "Homepage: $src"
	echo "Description: $summary"
	[ -z "$description" ] || echo "$description"
	echo "X-Sprite-Name: $(field name "$RECIPE/app.txt")"
	echo "X-Sprite-Kind: $(k=$(field kind "$RECIPE/app.txt"); echo "${k:-app}")"
	v=$(field icon "$RECIPE/app.txt"); [ -z "$v" ] || echo "X-Sprite-Icon: $v"
	v=$(field color "$RECIPE/app.txt"); [ -z "$v" ] || echo "X-Sprite-Color: $v"
	v=$(field allow "$RECIPE/app.txt"); [ -z "$v" ] || echo "X-Sprite-Allow: $v"
	v=$(field author "$RECIPE/shop.txt"); [ -z "$v" ] || echo "X-Sprite-Author: $v"
	v=$(field licence "$RECIPE/shop.txt"); [ -z "$v" ] || echo "X-Sprite-Licence: $v"
	echo "X-Sprite-Community: $community"
} > "$WORK/control"
mkdir -p "$DESTDIR/DEBIAN"
cp "$WORK/control" "$DESTDIR/DEBIAN/control"
(cd "$DESTDIR" && find usr -type f -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums)
chmod 644 "$DESTDIR/DEBIAN/control" "$DESTDIR/DEBIAN/md5sums"

deb="$OUT/${PKG}_${VERSION}_${arch}.deb"
dpkg-deb --root-owner-group -Zxz --build "$DESTDIR" "$deb" > /dev/null
# its source, if the recipe left any, in a folder of its own
if [ -n "$(ls -A "$SOURCES")" ]; then
	mkdir -p "$OUT/source-$PKG"
	mv "$SOURCES"/* "$OUT/source-$PKG/"
fi
rmdir "$SOURCES" 2>/dev/null || true
dpkg-deb -I "$deb" | sed -n '/^ Package:/,$p'
