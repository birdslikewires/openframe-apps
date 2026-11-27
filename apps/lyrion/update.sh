# Prints Lyrion's newest release and its tarball's SHA-256, for ci/upstream.sh, from the versions its downloads page links to. The tarball is over 100 MB, so it's fetched only for a release newer than the recipe's.
v=$(curl -fsSL https://lyrion.org/getting-started/ | grep -oE 'LyrionMusicServer_v[0-9]+\.[0-9]+\.[0-9]+/' | sed 's/LyrionMusicServer_v//; s|/$||' | sort -V | tail -1)
[ -n "$v" ] || { echo "No release found" >&2; exit 1; }
if [ "$v" = "$(sed -n 's/^version=//p' /recipe/shop.txt | tail -1)" ]; then
	echo "$v $(sed -n 's/^SHA256=//p' /recipe/build.sh)"
	exit 0
fi
curl -fsSL -o lyrion.tgz "https://downloads.lms-community.org/LyrionMusicServer_v$v/lyrionmusicserver-$v.tgz"
echo "$v $(sha256sum lyrion.tgz | cut -d' ' -f1)"
