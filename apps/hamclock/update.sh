# Prints HamClock's newest stable release and its source zip's SHA-256, for ci/upstream.sh. Stable releases are tagged vX.Y.0 on openhamclock/hamclock, and betas vX.YbNN.0, which are published as ordinary releases too, so the newest is found by version rather than by date.
tags=$(curl -fsSL 'https://api.github.com/repos/openhamclock/hamclock/releases?per_page=100' | jq -r '.[] | select(.draft | not) | .tag_name')
v=$(echo "$tags" | sed -n 's/^v\([0-9][0-9]*\.[0-9][0-9]*\)\.0$/\1/p' | sort -V | tail -1)
[ -n "$v" ] || { echo "No stable release found" >&2; exit 1; }
curl -fsSL -o hamclock.zip "https://github.com/openhamclock/hamclock/releases/download/v$v.0/ESPHamClock-V$v.zip"
echo "$v $(sha256sum hamclock.zip | cut -d' ' -f1)"
