# Prints Shairport Sync's newest release and its source tarball's SHA-256, for ci/upstream.sh. Releases are tagged X.Y, X.Y.Z or (a hotfix) X.Y.Z.W on mikebrady/shairport-sync, and development ones carry a suffix (-dev, -rc), so only plain versions count. The tags come from git rather than GitHub's API, which refuses an unauthenticated runner after 60 requests in the hour.
v=$(git ls-remote --tags --refs https://github.com/mikebrady/shairport-sync.git | sed -n 's|^.*refs/tags/\([0-9][0-9]*\.[0-9][0-9]*\(\.[0-9][0-9]*\)\{0,2\}\)$|\1|p' | sort -V | tail -1)
[ -n "$v" ] || { echo "No release found" >&2; exit 1; }
curl -fsSL -o s.tar.gz "https://github.com/mikebrady/shairport-sync/archive/refs/tags/$v.tar.gz"
echo "$v $(sha256sum s.tar.gz | cut -d' ' -f1)"
