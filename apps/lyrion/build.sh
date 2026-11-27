# Lyrion Music Server for the OpenFrame, from Lyrion's release, checked against its SHA-256 (update.sh finds the newest, and ci/upstream.sh changes the version and this together).
SHA256=ca59ea5c8aad106ae88a1dbfd13c7903e71942eafbed5aee4c8a61d4dad4bd4d
curl -fsSL -o lyrion.tgz "https://downloads.lms-community.org/LyrionMusicServer_v$UPSTREAM/lyrionmusicserver-$UPSTREAM.tgz"
echo "$SHA256  lyrion.tgz" | sha256sum -c - > /dev/null
tar -xzf lyrion.tgz
L="lyrionmusicserver-$UPSTREAM"

# None of the programs and compiled modules it ships for each system: its compiled modules are Debian's (build-depends.txt) but for two built here (below), and the programs it converts with (flac, faad, sox...) Debian's too (depends.txt), which it finds on the path. So everything here is Perl, its own source. The big-endian ICU data isn't needed either.
rm -rf "$L/CPAN/arch" "$L/Bin" "$L"/icudt*b.dat
# Its own copies of the modules Debian's packages bring, found from the packages themselves: Perl would load its copy and then Debian's compiled half, and a copy of another version fails Perl's check that both halves match. The modules only Lyrion has stay.
# (the Perl module packages in build-depends.txt, which are the ones in depends.txt too, not the compiler's)
words() { sed 's/#.*//' "$1" | tr -s ' \t\n' '\n' | grep -v '^$' | sort -u; }
comm -12 <(words "$RECIPE/build-depends.txt") <(words "$RECIPE/depends.txt") | grep -- '-perl$' | xargs dpkg -L |
	sed -nE 's#^/usr/(lib/i386-linux-gnu/perl5/5\.[0-9]+|share/perl5|lib/i386-linux-gnu/perl/5\.[0-9.]+)/(.*\.pm)$#\2#p' | sort -u |
	while read -r f; do rm -f "$L/CPAN/$f"; done
# and its own loader for Audio::Scan, which only takes the compiled part at the versions it once built (0.93 to 0.99), as ours is 1.14 (below)
rm -f "$L/lib/Audio/Scan.pm"
find "$L/CPAN" -type d -empty -delete

# Two compiled modules built here rather than Debian's, from Lyrion's own sources (its slimserver-vendor repository, pinned to a commit, each checked against its SHA-256), with their tests. Audio::Scan, which reads every track's tags, is Lyrion's 1.14: Debian's is 1.01, and Lyrion only plays Opus from 1.02, and has had MP4, ID3 and large-file fixes since. MP3::Cut::Gapless, for MP3 tracks cut from a CUE sheet, Debian doesn't have; Lyrion ships its Perl half (CPAN/MP3/Cut, the same 0.03), so only the compiled half goes in. Its cue.t needs Audio::Cuefile::Parser, which Lyrion doesn't use (it cuts by time, which mp3cut.t tests), so only that runs. They go where Lyrion looks first for compiled modules, CPAN/arch/<Perl's version>/<its name for the system>, as Slim/bootstrap.pm names them. Their source goes with the package (GPL).
VENDOR=c12fae087ccf423b2e68c866388cfefe3d8d983d
AUDIO_SCAN=1.14 AUDIO_SCAN_SHA256=21ef75024a9814a806529886130eff5fd2b41598cfc14013f258a88f55a884f5
GAPLESS=0.03 GAPLESS_SHA256=3e84b739d1f1e3dd3616f851dc6575e165d328467f03248607950e5951fea4f3
ARCH="$PWD/$L/CPAN/arch/$(perl -MConfig -e '($v = $Config{version}) =~ s/\.\d+$//; ($a = $Config{archname}) =~ s/^i[3456]86-/i386-/; $a =~ s/gnu-//; print "$v/$a"')"
# (built for this Perl, which depends.txt has to name)
grep -qw "perlapi-$(perl -MConfig -e 'print $Config{version}')" "$RECIPE/depends.txt" || { echo "depends.txt doesn't name this Perl's perlapi-$(perl -MConfig -e 'print $Config{version}')"; exit 1; }
xs() { # dist sha256 tests
	curl -fsSL -o "$1.tar.gz" "https://raw.githubusercontent.com/LMS-Community/slimserver-vendor/$VENDOR/CPAN/$1.tar.gz"
	echo "$2  $1.tar.gz" | sha256sum -c - > /dev/null
	tar -xzf "$1.tar.gz"
	( cd "$1" && perl Makefile.PL && make && make test TEST_FILES="$3" ) > "$1.log" 2>&1 || { tail -40 "$1.log"; exit 1; }
	install -d "$ARCH"
	( cd "$1/blib/arch" && find auto -name '*.so' -exec install -D -m 644 {} "$ARCH/{}" \; )
	cp "$1.tar.gz" "$SOURCES/"
}
xs "Audio-Scan-$AUDIO_SCAN" "$AUDIO_SCAN_SHA256" 't/*.t'
install -D -m 644 "Audio-Scan-$AUDIO_SCAN/blib/lib/Audio/Scan.pm" "$ARCH/Audio/Scan.pm"
xs "MP3-Cut-Gapless-$GAPLESS" "$GAPLESS_SHA256" t/mp3cut.t
cmp -s "MP3-Cut-Gapless-$GAPLESS/lib/MP3/Cut/Gapless.pm" "$L/CPAN/MP3/Cut/Gapless.pm" || { echo "Lyrion's MP3::Cut::Gapless isn't $GAPLESS"; exit 1; }
# Digest::SHA1, which Debian doesn't package, over Perl's own Digest::SHA
install -m 644 "$RECIPE/SHA1.pm" "$L/CPAN/Digest/SHA1.pm"

install -d "$DESTDIR$APPDIR/server"
cp -r "$L"/. "$DESTDIR$APPDIR/server/"
chmod -R u+rwX,go+rX,go-w "$DESTDIR$APPDIR/server"
install -m 755 "$RECIPE/lyrion" "$DESTDIR$APPDIR/lyrion"
{
	cat "$RECIPE/copyright"
	printf '\nLicense: GPL-2.0\n'; sed 's/^/ /; s/^ $/ ./' "$L/License.txt"
	for f in "Audio-Scan-$AUDIO_SCAN"/COPYING.*; do
		printf '\nAudio::Scan, %s:\n' "${f##*/}"; sed 's/^/ /; s/^ $/ ./' "$f"
	done
} > "$DESTDIR$DOCDIR/copyright"
