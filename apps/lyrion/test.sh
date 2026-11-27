# The two compiled modules built with the package load from it (Audio::Scan at 1.02 or later, which Lyrion plays Opus with), then Lyrion starts from the package, with Debian's other modules, as the OpenFrame runs it (its run script, in a throwaway home, and as a user of its own, as Lyrion won't run as root), its web page answers, and it says it's this version.
arch=$(echo /usr/lib/ofapp-lyrion/server/CPAN/arch/*/*)
perl -I"$arch" -I/usr/lib/ofapp-lyrion/server/CPAN -e 'use Audio::Scan; use MP3::Cut::Gapless; die "Audio::Scan $Audio::Scan::VERSION from $INC{q(Audio/Scan.pm)}\n" unless $Audio::Scan::VERSION >= 1.02 && $INC{q(Audio/Scan.pm)} =~ m{^/usr/lib/ofapp-lyrion/}; print "Audio::Scan $Audio::Scan::VERSION, MP3::Cut::Gapless $MP3::Cut::Gapless::VERSION\n"'
export HOME=$(mktemp -d)
chmod 777 "$HOME"
setpriv --reuid=65534 --regid=65534 --clear-groups /usr/lib/ofapp-lyrion/lyrion > "$HOME/out.txt" 2>&1 &
pid=$!
answers() { (exec 3<>/dev/tcp/127.0.0.1/9000) 2>/dev/null; }
for _ in $(seq 120); do
	answers && break
	kill -0 "$pid" 2>/dev/null || { echo "Lyrion stopped:"; tail -20 "$HOME/out.txt" "$HOME/log/server.log" 2>/dev/null; exit 1; }
	sleep 1
done
body='{"id":1,"method":"slim.request","params":["",["version","?"]]}'
exec 3<>/dev/tcp/127.0.0.1/9000
printf 'POST /jsonrpc.js HTTP/1.0\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s' "${#body}" "$body" >&3
reply=$(cat <&3)
kill "$pid"; wait "$pid" 2>/dev/null || true
grep -q "\"_version\":\"${VERSION%%-*}\"" <<< "$reply" || { echo "Lyrion's version isn't ${VERSION%%-*}: $reply"; tail -20 "$HOME/log/server.log"; exit 1; }
# and nothing in its log says a module failed to load
! grep -qi 'failed to load\|Can.t locate' "$HOME/log/server.log"
