#!/bin/bash
# ci/upstream.sh [<id>...] checks apps that follow an upstream release for a newer one, from the repository's root. An app opts in with an update.sh in its recipe, which prints the newest release's version and the SHA-256 of what build.sh fetches, as "<version> <sha256>". Its shop.txt has that version= and its build.sh one SHA256= line, which this updates when the release is newer, leaving the change for upstream.yml to commit. Each update.sh runs in a throwaway i386 Debian Trixie container (Docker) with curl and jq, and only the recipe, read-only. Prints a line for each app it updated, as "<id> <old> <new>".
set -euo pipefail
[ -d apps ] || { echo "Run from the repository's root." >&2; exit 1; }
if [ $# -gt 0 ]; then ids=("$@"); else ids=(); for f in apps/*/update.sh; do [ -f "$f" ] && ids+=("$(basename "$(dirname "$f")")"); done; fi
fails=0
err=$(mktemp)
trap 'rm -f "$err"' EXIT
for id in "${ids[@]}"; do
	dir=apps/$id
	old=$(sed -n 's/^version=//p' "$dir/shop.txt" | tail -1 | tr -d '[:space:]')
	[ "$(grep -c '^SHA256=' "$dir/build.sh")" = 1 ] || { echo "$id: build.sh needs one SHA256= line to be updated" >&2; fails=$((fails + 1)); continue; }
	if ! out=$(docker run --rm --security-opt seccomp=unconfined --platform linux/386 -v "$PWD/$dir:/recipe:ro" i386/debian:trixie bash -c '
		apt-get -qq update && apt-get -qq install -y --no-install-recommends curl ca-certificates jq > /dev/null && cd "$(mktemp -d)" && bash -eu /recipe/update.sh' 2>"$err"); then
		echo "$id: update.sh failed" >&2; tail -5 "$err" >&2; fails=$((fails + 1)); continue
	fi
	read -r new sha extra <<< "$(echo "$out" | tail -1)"
	if ! [[ "$new" =~ ^[0-9][0-9A-Za-z.+~]*$ && "$sha" =~ ^[0-9a-f]{64}$ && -z "${extra:-}" ]]; then
		echo "$id: update.sh printed something other than a version and a SHA-256: $(echo "$out" | tail -1)" >&2; fails=$((fails + 1)); continue
	fi
	if [ "$new" != "$old" ] && [ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -1)" = "$new" ]; then
		sed -i.old "s/^version=.*/version=$new/" "$dir/shop.txt" && rm "$dir/shop.txt.old"
		sed -i.old "s/^SHA256=.*/SHA256=$sha/" "$dir/build.sh" && rm "$dir/build.sh.old"
		echo "$id $old $new"
	else
		echo "$id is up to date at $old (upstream has $new)" >&2
	fi
done
[ "$fails" -eq 0 ]
