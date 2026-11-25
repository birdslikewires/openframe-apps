#!/bin/bash
# ci/app-version.sh <id>: prints the version of app <id>'s package, ofapp-<id>, from the repository's root with its full history. It's <upstream>-<year.month.N> when its shop.txt gives version= (what it's built from, e.g. 4.33-26.11.1), else <year.month.N>. N counts this month's commits that changed the recipe (apps/<id>/) or how every app is built (ci/build-app.sh), as for OpenBeak's other packages, so any change to what goes into the package gives it a new version.
set -eu
id=$1
dir=apps/$id
[ -f "$dir/shop.txt" ] || { echo "No app $id here (no $dir/shop.txt)." >&2; exit 1; }
paths=("$dir" ci/build-app.sh)
month=$(TZ=UTC git log -1 --format=%cd --date=format-local:%y.%m -- "${paths[@]}")
count=$(TZ=UTC git log --format=%cd --date=format-local:%y.%m -- "${paths[@]}" | grep -cx "${month}" || true)
[ -n "$month" ] && [ "$count" -gt 0 ] || { echo "Can't work out $id's version: not committed yet?" >&2; exit 1; }
upstream=$(sed -n 's/^version=//p' "$dir/shop.txt" | tail -1 | tr -d '[:space:]')
case "$upstream" in
	"") ;;
	[0-9]*) ;;
	*) echo "$dir/shop.txt: version=$upstream must start with a digit." >&2; exit 1 ;;
esac
[[ "$upstream" =~ ^[0-9A-Za-z.+~]*$ ]] || { echo "$dir/shop.txt: version=$upstream: letters, digits and . + ~ only." >&2; exit 1; }
echo "${upstream:+${upstream}-}${month%.*}.$((10#${month#*.})).${count}"
