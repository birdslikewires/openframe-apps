# Shairport Sync for the OpenFrame, built with AirPlay 2, from Mike Brady's release, checked against its SHA-256 (update.sh finds the newest, and ci/upstream.sh changes the version and this together). nqptp, AirPlay 2's clock, from its release, pinned too. All three sources go with the package ($SOURCES), FFmpeg's as its LGPL asks, being built in.
SHA256=670f9cefdb9c2d70f7df71890e63ab0a31d08a815dd0734245d935bfd01e766e
NQPTP=1.2.9 NQPTP_SHA256=6aa1d73b8ee760bf19378c319db0d0537a867ff961764b150e19f87d96a02210
FFMPEG=7.1.5 FFMPEG_SHA256=de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f
fetch() { # url file sha256
	curl -fsSL -o "$2" "$1"
	echo "$3  $2" | sha256sum -c - > /dev/null
	cp "$2" "$SOURCES/"
}
fetch "https://github.com/mikebrady/shairport-sync/archive/refs/tags/$UPSTREAM.tar.gz" "shairport-sync-$UPSTREAM.tar.gz" "$SHA256"
fetch "https://github.com/mikebrady/nqptp/archive/refs/tags/$NQPTP.tar.gz" "nqptp-$NQPTP.tar.gz" "$NQPTP_SHA256"
fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG.tar.xz" "ffmpeg-$FFMPEG.tar.xz" "$FFMPEG_SHA256"
log() { "$@" >> build.log 2>&1 || { tail -40 build.log; exit 1; }; }
# (the upstream Makefiles run without this build's own settings: FFmpeg's make install would put itself in the package, under DESTDIR)
umake() { env -u SOURCES -u DESTDIR -u APPDIR -u SHAREDIR -u DOCDIR make "$@"; }

# FFmpeg, which shairport-sync decodes AirPlay's AAC and ALAC with, and changes the rate with: only those two decoders and its resampler, built into shairport-sync, which then takes 1.8 MB, where Debian's libavcodec brings 150 MB of codecs with it. No GPL parts (LGPL-2.1 or later).
tar -xJf "ffmpeg-$FFMPEG.tar.xz"
FF="$PWD/ff"
( cd "ffmpeg-$FFMPEG" && log ./configure --prefix="$FF" --enable-static --disable-shared --enable-pic --disable-autodetect \
	--disable-everything --disable-programs --disable-doc --disable-network --disable-avdevice --disable-avfilter --disable-swscale \
	--enable-decoder=aac,alac --enable-swresample && log umake -j"$(nproc)" && log umake install )

tar -xzf "nqptp-$NQPTP.tar.gz"
( cd "nqptp-$NQPTP" && log autoreconf -fi && log ./configure && log umake -j"$(nproc)" )

# shairport-sync: ALSA out, announced through avahi, AirPlay 2, and its metadata (what's playing, and its artwork) for the OpenFrame's interface, over UDP (metadata-multicast, which sends to any address, 127.0.0.1 here)
tar -xzf "shairport-sync-$UPSTREAM.tar.gz"
( cd "shairport-sync-$UPSTREAM" && export PKG_CONFIG_PATH="$FF/lib/pkgconfig" && log autoreconf -fi &&
	log ./configure --sysconfdir=/etc --with-pkg-config --with-alsa --with-avahi --with-ssl=openssl --with-soxr --with-metadata --with-metadata-multicast --with-airplay-2 --with-ffmpeg &&
	log umake -j"$(nproc)" )
"shairport-sync-$UPSTREAM/shairport-sync" -V | grep -q "^$UPSTREAM-AirPlay2-" || { echo "shairport-sync isn't $UPSTREAM with AirPlay 2: $("shairport-sync-$UPSTREAM/shairport-sync" -V)"; exit 1; }

install -s -m 755 "shairport-sync-$UPSTREAM/shairport-sync" "nqptp-$NQPTP/nqptp" "$DESTDIR$APPDIR/"
install -m 755 "$RECIPE/shairport-sync-service" "$DESTDIR$APPDIR/"
{
	cat "$RECIPE/copyright"
	printf '\nShairport Sync, LICENSES:\n'; sed 's/^/ /; s/^ $/ ./' "shairport-sync-$UPSTREAM/LICENSES"
	printf '\nLicense: GPL-2.0\n'; sed 's/^/ /; s/^ $/ ./' "nqptp-$NQPTP/LICENSE"
	printf '\nLicense: LGPL-2.1+\n'; sed 's/^/ /; s/^ $/ ./' "ffmpeg-$FFMPEG/COPYING.LGPLv2.1"
} > "$DESTDIR$DOCDIR/copyright"
