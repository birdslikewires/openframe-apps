#!/bin/bash
# ci/test-app.sh <deb> <id> [<recipe>]: installs an app's package on a clean i386 Debian Trixie (as root in a throwaway container, which ci/build-apps.sh starts), with only Debian's own suites, as an OpenFrame would take its dependencies, and checks
#   - apt finds everything it needs in Debian (an app can't need a package of ours)
#   - nothing it pulls in is Mesa (the OpenFrame has no use for it, and it's hundreds of MB)
#   - its programs are i386, as the OpenFrame is, and have every library they link against, but the SDL the interface brings
#   - what its manifest's exec= runs is there, and can be run
#   - the recipe's own test.sh passes, if it has one (run with PKG, ID and VERSION set)
#   - removing it leaves nothing behind
set -euo pipefail
DEB=$1 ID=$2 RECIPE=${3:-}
PKG=ofapp-$ID
export DEBIAN_FRONTEND=noninteractive
apt-get -qq --error-on=any update
apt-get -qq install -y --no-install-recommends file > /dev/null
before=$(dpkg-query -W -f '${Package}\n' | sort)
if ! apt-get -qq install -y "$DEB" > /tmp/install.txt 2>&1; then
	echo "$PKG doesn't install from Debian's suites:"; cat /tmp/install.txt; exit 1
fi
added=$(comm -13 <(echo "$before") <(dpkg-query -W -f '${Package}\n' | sort) | grep -vx "$PKG" || true)
echo "$PKG installs, bringing $(echo "$added" | grep -c . || true) package(s) with it"
mesa=$(echo "$added" | grep -E '^(libgbm1|mesa-.*|libllvm.*|libgl1|libgl1-.*|libegl1|libegl-mesa0|libglx-mesa0|libgles2)$' || true)
[ -z "$mesa" ] || { echo "$PKG pulls in Mesa: $(echo $mesa)"; exit 1; }

for f in $(dpkg -L "$PKG"); do
	[ -f "$f" ] && [ ! -L "$f" ] || continue
	desc=$(file -b "$f")
	case "$desc" in ELF*) [[ "$desc" == *"Intel 80386"* || "$desc" == *"Intel i386"* ]] || { echo "$f isn't i386: $desc"; exit 1; } ;; esac
	# everything it links against is installed, but SDL, which the interface brings (see ci/build-app.sh)
	case "$desc" in ELF*dynamically*|ELF*shared\ object*)
		missing=$(ldd "$f" 2>/dev/null | awk '/not found/ { print $1 }' | grep -vxE 'libSDL-1\.2\.so\.0|libSDL2-2\.0\.so\.0' || true)
		[ -z "$missing" ] || { echo "$f links against what isn't installed: $(echo $missing)"; exit 1; } ;;
	esac
done

exec_line=$(sed -n 's/^exec=//p' "/usr/share/sprite/apps/$ID.app" | tail -1)
prog=${exec_line%% *}
if [ "${prog:0:1}" = / ]; then
	[ -f "$prog" ] && [ -x "$prog" ] || { echo "exec=$exec_line: $prog isn't there, or can't be run"; exit 1; }
else
	command -v "$prog" > /dev/null || { echo "exec=$exec_line: no $prog on the PATH"; exit 1; }
fi
echo "exec= runs $prog, which is there"

if [ -n "$RECIPE" ] && [ -f "$RECIPE/test.sh" ]; then
	(cd "$(mktemp -d)" && PKG=$PKG ID=$ID VERSION=$(dpkg-query -W -f '${Version}' "$PKG") bash -eu "$RECIPE/test.sh") ||
		{ echo "$PKG: the recipe's test.sh failed"; exit 1; }
	echo "the recipe's test.sh passes"
fi

files=$(dpkg -L "$PKG")
apt-get -qq purge -y "$PKG" > /dev/null
left=$(for f in $files; do [ -e "$f" ] && [ ! -d "$f" ] && echo "$f"; done || true)
[ -z "$left" ] || { echo "$PKG left files behind: $left"; exit 1; }
for d in "/usr/lib/$PKG" "/usr/share/$PKG" "/usr/share/doc/$PKG"; do
	[ ! -e "$d" ] || { echo "$PKG left $d behind"; exit 1; }
done
echo "$PKG: install test passes"
