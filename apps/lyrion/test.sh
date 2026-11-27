# Lyrion starts from the package, with Debian's modules, as the OpenFrame runs it (its run script, in a throwaway home, and as a user of its own, as Lyrion won't run as root), its web page answers, and it says it's this version.
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
