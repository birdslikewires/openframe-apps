#!/bin/bash
# ci/sources.sh puts the source that goes with apps' packages (a release's zip, where a licence such as the GPL says it must) beside them, at apps.openbeak.net/source/<package>/<version>/, for as long as that version is in either suite. Run from the repository's root with the repo branch in apt-repo/.
#   sources.sh add <out>   copy what ci/build-apps.sh left in <out>/<id>/source-<package>/, for the version it built, then prune
#   sources.sh prune       remove the source of versions in neither suite now
set -euo pipefail
REPO=apt-repo

prune() {
	shopt -s nullglob
	for d in "$REPO"/source/*/*/; do
		d=${d%/}; ver=${d##*/}; pkg=$(basename "$(dirname "$d")")
		compgen -G "$REPO/pool/*/${pkg}_${ver}_*.deb" > /dev/null && continue
		echo "source: removing $pkg $ver (in neither suite now)"
		rm -rf "$d"
	done
	for d in "$REPO"/source/*/; do rmdir "$d" 2>/dev/null || true; done
}

case "${1:-}" in
add)
	out=$2
	while read -r id deb; do
		[ -n "$id" ] || continue
		src="$out/$id/source-ofapp-$id"
		[ -d "$src" ] || continue
		ver=$(dpkg-deb -f "$out/$deb" Version)
		dest="$REPO/source/ofapp-$id/$ver"
		rm -rf "$dest"; mkdir -p "$dest"
		cp "$src"/* "$dest/"
		(cd "$dest" && sha256sum -- * > SHA256SUMS)
		echo "source: ofapp-$id $ver ($(ls "$src" | tr '\n' ' '))"
	done < "$out/built.txt"
	prune
	;;
prune) prune ;;
*) awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 2 ;;
esac
