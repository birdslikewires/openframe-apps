# Prints HamClock's newest stable release and its source zip's SHA-256, for ci/upstream.sh. Stable releases are tagged vX.Y.0 on openhamclock/hamclock, and betas vX.YbNN.0, so the newest is found by version rather than by date. The tags come from git rather than GitHub's API, which refuses an unauthenticated runner once its shared address has used up 60 requests in the hour. A tag pushed a few minutes before its zip is uploaded fails this run, and the next run picks it up.
v=$(git ls-remote --tags --refs https://github.com/openhamclock/hamclock.git | sed -n 's|^.*refs/tags/v\([0-9][0-9]*\.[0-9][0-9]*\)\.0$|\1|p' | sort -V | tail -1)
[ -n "$v" ] || { echo "No stable release found" >&2; exit 1; }
curl -fsSL -o hamclock.zip "https://github.com/openhamclock/hamclock/releases/download/v$v.0/ESPHamClock-V$v.zip"
echo "$v $(sha256sum hamclock.zip | cut -d' ' -f1)"
