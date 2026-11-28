# shairport-sync from the package is this version, with AirPlay 2 and metadata over UDP; the run script's settings (written to a throwaway home by its --config, for a name with all that needs escaping in it: a quote, a backslash, ${ and %h) are ones shairport-sync reads and doesn't stop at; and nqptp from it starts and opens AirPlay 2's clock ports, as root here (on the OpenFrame, with lowports).
export HOME=$(mktemp -d)
P=/usr/lib/ofapp-shairport-sync
# ... built with metadata over UDP (metadata-multicast), which the interface's Now Playing reads: without it, metadata= is quietly ignored
grep -qa 'Could not malloc metadata multicast socket buffer' "$P/shairport-sync" || { echo "shairport-sync was built without metadata over UDP (--with-metadata-multicast)"; exit 1; }
"$P/shairport-sync" -V | grep -q "^${VERSION%%-*}-AirPlay2-" || { echo "shairport-sync isn't ${VERSION%%-*} with AirPlay 2: $("$P/shairport-sync" -V)"; exit 1; }
# (as openframe-scripts' name-settings writes it: in double quotes, with \, ", $ and ` escaped)
printf '%s\n' 'PRETTY_HOSTNAME="Andy\"s \\ \${den} %h Kitchen"' > "$HOME/machine-info"
OF_MACHINE_INFO="$HOME/machine-info" "$P/shairport-sync-service" --config
grep -qF 'name = "Andy\"s \\ $${den} %' "$HOME/shairport-sync.conf" || { echo "name not as expected:"; cat "$HOME/shairport-sync.conf"; exit 1; }
# (--displayConfig shows the settings, then carries on till there's no avahi to announce it: so the timeout)
out=$(timeout 10 "$P/shairport-sync" -c "$HOME/shairport-sync.conf" --displayConfig 2>&1) || true # (it stops for want of avahi, or the timeout)
if ! grep -q 'Kitchen' <<< "$out" || grep -qi 'environment-variable\|is not set\|configuration file.*error' <<< "$out"; then
	echo "shairport-sync didn't read its settings:"
	head -40 <<< "$out"
	exit 1
fi
"$P/nqptp" & pid=$!
open=no
for _ in $(seq 40); do
	grep -qiE '^ *[0-9]+: [0-9A-F:]+:013F ' /proc/net/udp /proc/net/udp6 2>/dev/null && { open=yes; break; }
	sleep 0.25
done
kill "$pid" 2>/dev/null
[ "$open" = yes ] || { echo "nqptp didn't open port 319"; exit 1; }
