# Lyrion Music Server for the OpenFrame, from Lyrion's release, checked against its SHA-256 (update.sh finds the newest, and ci/upstream.sh changes the version and this together).
SHA256=ca59ea5c8aad106ae88a1dbfd13c7903e71942eafbed5aee4c8a61d4dad4bd4d
curl -fsSL -o lyrion.tgz "https://downloads.lms-community.org/LyrionMusicServer_v$UPSTREAM/lyrionmusicserver-$UPSTREAM.tgz"
echo "$SHA256  lyrion.tgz" | sha256sum -c - > /dev/null
tar -xzf lyrion.tgz
L="lyrionmusicserver-$UPSTREAM"

# None of the programs and compiled modules it ships for each system: its compiled modules are Debian's (build-depends.txt), and the programs it converts with (flac, faad, sox...) Debian's too (depends.txt), which it finds on the path. So everything here is Perl, its own source. The big-endian ICU data isn't needed either.
rm -rf "$L/CPAN/arch" "$L/Bin" "$L"/icudt*b.dat
# Its own copies of the modules Debian's packages bring, found from the packages themselves: Perl would load its copy and then Debian's compiled half, and a copy of another version fails Perl's check that both halves match. The modules only Lyrion has stay.
sed 's/#.*//' "$RECIPE/build-depends.txt" | tr -s ' \t\n' '\n' | grep -v '^$' | xargs dpkg -L |
	sed -nE 's#^/usr/(lib/i386-linux-gnu/perl5/5\.[0-9]+|share/perl5|lib/i386-linux-gnu/perl/5\.[0-9.]+)/(.*\.pm)$#\2#p' | sort -u |
	while read -r f; do rm -f "$L/CPAN/$f"; done
# and its own loader for Audio::Scan, which only takes the compiled part at the versions Lyrion builds (0.93 to 0.99): Debian's module, 1.01, brings its own
rm -f "$L/lib/Audio/Scan.pm"
find "$L/CPAN" -type d -empty -delete
# Digest::SHA1, which Debian doesn't package, over Perl's own Digest::SHA
install -m 644 "$RECIPE/SHA1.pm" "$L/CPAN/Digest/SHA1.pm"

install -d "$DESTDIR$APPDIR/server"
cp -r "$L"/. "$DESTDIR$APPDIR/server/"
chmod -R u+rwX,go+rX,go-w "$DESTDIR$APPDIR/server"
install -m 755 "$RECIPE/lyrion" "$DESTDIR$APPDIR/lyrion"
{
	cat "$RECIPE/copyright"
	printf '\nLicense: GPL-2.0\n'; sed 's/^/ /; s/^ $/ ./' "$L/License.txt"
} > "$DESTDIR$DOCDIR/copyright"
