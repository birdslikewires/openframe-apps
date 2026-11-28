# shairport-sync from the package is this version, with AirPlay 2, and reads the settings its run script writes (it shows them, then stops: there is no avahi here to announce it) (to a throwaway home, with a name that needs escaping); nqptp from it starts and opens AirPlay 2's clock ports, as root here (on the OpenFrame, with lowports).
export HOME=$(mktemp -d)
# ... built with metadata over UDP (metadata-multicast), which the interface's Now Playing reads: without it, metadata= is quietly ignored
grep -qa 'Could not malloc metadata multicast socket buffer' /usr/lib/ofapp-shairport-sync/shairport-sync || { echo "shairport-sync was built without metadata over UDP (--with-metadata-multicast)"; exit 1; }
/usr/lib/ofapp-shairport-sync/shairport-sync -V | grep -q "^${VERSION%%-*}-AirPlay2-" || { echo "shairport-sync isn't ${VERSION%%-*} with AirPlay 2: $(/usr/lib/ofapp-shairport-sync/shairport-sync -V)"; exit 1; }
printf 'PRETTY_HOSTNAME="Andy\\"s \\\\ Kitchen"\n' > "$HOME/machine-info"
sed "s|/etc/machine-info|$HOME/machine-info|; /^\"\$D\/nqptp\" &$/,\$d" /usr/lib/ofapp-shairport-sync/shairport-sync-service > "$HOME/conf.sh"
bash "$HOME/conf.sh"
grep -qF 'name = "Andy\"s \\ Kitchen";' "$HOME/shairport-sync.conf" || { echo "name not as expected:"; cat "$HOME/shairport-sync.conf"; exit 1; }
timeout 10 /usr/lib/ofapp-shairport-sync/shairport-sync -c "$HOME/shairport-sync.conf" --displayConfig 2>&1 | grep -qF 'name = "Andy\"s \\ Kitchen";' || { echo "shairport-sync didn't read its settings"; exit 1; }
/usr/lib/ofapp-shairport-sync/nqptp & pid=$!
open=no
for _ in $(seq 40); do
	grep -qiE '^ *[0-9]+: [0-9A-F:]+:013F ' /proc/net/udp /proc/net/udp6 2>/dev/null && { open=yes; break; }
	sleep 0.25
done
kill "$pid" 2>/dev/null
[ "$open" = yes ] || { echo "nqptp didn't open port 319"; exit 1; }
