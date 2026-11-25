#!/bin/bash
# ci/build-apps.sh <out> [<id>...]: builds, checks and tests apps' packages, each in its own throwaway i386 Debian Trixie containers (Docker), from the repository's root with its full history, as versions count commits (ci/app-version.sh).
#
# With ids, those apps. Without, every app in apps/ whose version isn't in the apt repository yet (apt-repo/pool, either suite, when the repo branch is checked out there), so only what's changed since it was last published.
#
# For each, ci/build-app.sh builds it (the recipe's build.sh runs there, with the network, and nothing of the runner's), ci/check-app.sh checks the package as built (no network), and ci/test-app.sh installs it on a clean Trixie and runs the recipe's test.sh. What passes is left in <out>/<id>/ (its .deb, and source-ofapp-<id>/ if it has any) and listed in <out>/built.txt, a line each with its id and package file (from <out>). Any failure stops it, saying why.
#
# ICONS=<file> uses that list of the interface's glyphs instead of openframe-sprite's src/icons.txt on GitHub.
set -euo pipefail
OUT=$(mkdir -p "$1" && cd "$1" && pwd); shift
ROOT=$(pwd)
[ -d apps ] && [ -f ci/build-app.sh ] || { echo "Run from the repository's root."; exit 1; }
RUN=(docker run --rm --security-opt seccomp=unconfined --platform linux/386)
IMAGE=i386/debian:trixie

if [ $# -gt 0 ]; then
	ids=("$@")
else
	ids=()
	for d in apps/*/; do
		id=$(basename "$d")
		[ -f "$d/shop.txt" ] || continue
		v=$(bash ci/app-version.sh "$id")
		if compgen -G "apt-repo/pool/*/ofapp-${id}_${v}_*.deb" > /dev/null; then
			echo "ofapp-$id $v is published already"
		else
			ids+=("$id")
		fi
	done
fi
: > "$OUT/built.txt"
[ ${#ids[@]} -gt 0 ] || { echo "Nothing to build."; exit 0; }

if [ -z "${ICONS:-}" ]; then
	ICONS="$OUT/icons.txt"
	curl -fsSL -o "$ICONS" https://raw.githubusercontent.com/birdslikewires/openframe-sprite/main/src/icons.txt
fi
ICONS=$(cd "$(dirname "$ICONS")" && pwd)/$(basename "$ICONS")

for id in "${ids[@]}"; do
	[[ "$id" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]] || { echo "$id: an app's id is lower-case letters, digits and - (at most 40)"; exit 1; }
	for f in app.txt shop.txt build.sh; do
		[ -f "apps/$id/$f" ] || { echo "apps/$id has no $f"; exit 1; }
	done
	version=$(bash ci/app-version.sh "$id")
	o="$OUT/$id"
	rm -rf "$o"; mkdir -p "$o"
	echo "::group::Build ofapp-$id $version"
	"${RUN[@]}" -v "$ROOT/apps/$id:/recipe:ro" -v "$ROOT/ci:/ci:ro" -v "$o:/out" "$IMAGE" \
		bash /ci/build-app.sh /recipe "$id" "$version" /out
	echo "::endgroup::"
	deb=$(ls "$o"/ofapp-"$id"_"$version"_*.deb)
	echo "::group::Check ofapp-$id $version"
	"${RUN[@]}" --network none -v "$ROOT/ci:/ci:ro" -v "$o:/out:ro" -v "$ICONS:/icons.txt:ro" "$IMAGE" \
		bash /ci/check-app.sh "/out/$(basename "$deb")" "$id" /icons.txt
	"${RUN[@]}" -v "$ROOT/apps/$id:/recipe:ro" -v "$ROOT/ci:/ci:ro" -v "$o:/out:ro" "$IMAGE" \
		bash /ci/test-app.sh "/out/$(basename "$deb")" "$id" /recipe
	echo "::endgroup::"
	echo "$id $id/$(basename "$deb")" >> "$OUT/built.txt"
done
echo "Built: $(cut -d' ' -f1 "$OUT/built.txt" | tr '\n' ' ')"
