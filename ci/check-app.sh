#!/bin/bash
# ci/check-app.sh <deb> <id> <icons.txt> [<version>]: checks an app's package, as built, can do no more than an app should, whatever its recipe did. Needs dpkg-deb; doesn't install it (ci/test-app.sh does that). <icons.txt> is the interface's list of tile glyphs (openframe-sprite's src/icons.txt), and <version> the version ci/build-apps.sh meant it to have. Prints each problem and exits 1 if there are any.
#
#   - files only, with no maintainer scripts, triggers or conffiles (control and md5sums only)
#   - only the control fields ci/build-app.sh writes, so no Pre-Depends, Conflicts, Breaks, Replaces, Provides, Essential and so on, and Depends only packages by name (and version)
#   - files only in the app's own places, /usr/lib/ofapp-<id>/, /usr/share/ofapp-<id>/, /usr/share/doc/ofapp-<id>/ and its manifest, /usr/share/sprite/apps/<id>.app
#   - only plain files, folders and symlinks that stay in those places (never by way of another of its symlinks); all root's, nothing setuid, setgid or sticky, nothing anyone else can write; plain names
#   - its manifest one the interface reads, with no builtin=, a glyph the interface has, and only network, sound, microphone and music to ask for (and lowports, a service's) (what the Shop shows, X-Sprite-Allow, the same)
set -uo pipefail
DEB=$1 ID=$2 ICONS=$3 VERSION=${4:-}
PKG=ofapp-$ID
FAILS=0
bad() { echo "$PKG: $*"; FAILS=$((FAILS + 1)); }

[[ "$ID" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]] || bad "id $ID: lower-case letters, digits and - only, at most 40"

# Control files
members=$(dpkg-deb --ctrl-tarfile "$DEB" | tar -t | sed 's|^\./||' | grep -v '^$' | sort | tr '\n' ' ')
[ "$members" = "control md5sums " ] || bad "control files other than control and md5sums: $members"

# Control fields
fields=$(dpkg-deb -f "$DEB" | sed -n 's/^\([A-Za-z0-9-]*\):.*/\1/p')
for f in $fields; do
	case "$f" in
		Package|Version|Architecture|Section|Priority|Maintainer|Installed-Size|Depends|Homepage|Description) ;;
		X-Sprite-Name|X-Sprite-Kind|X-Sprite-Icon|X-Sprite-Color|X-Sprite-Allow|X-Sprite-Author|X-Sprite-Licence|X-Sprite-Community) ;;
		*) bad "control field $f isn't one an app has" ;;
	esac
done
[ "$(dpkg-deb -f "$DEB" Package)" = "$PKG" ] || bad "Package is $(dpkg-deb -f "$DEB" Package), not $PKG"
case "$(dpkg-deb -f "$DEB" Architecture)" in i386|all) ;; *) bad "Architecture isn't i386 or all" ;; esac
[ -z "$VERSION" ] || [ "$(dpkg-deb -f "$DEB" Version)" = "$VERSION" ] || bad "Version is $(dpkg-deb -f "$DEB" Version), not $VERSION"
# Depends: packages by name, each perhaps with a version, or alternatives of them (whatever they are is Debian's, which test-app.sh installs from)
deps=$(dpkg-deb -f "$DEB" Depends | tr '\n' ' ')
if [ -n "${deps// }" ]; then
	IFS=, read -ra items <<< "$deps"
	for it in "${items[@]}"; do
		IFS='|' read -ra alts <<< "$it"
		for a in "${alts[@]}"; do
			a=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$a")
			[[ "$a" =~ ^[a-z0-9][a-z0-9+.-]+(:any)?( \((<<|<=|=|>=|>>) [A-Za-z0-9.+~:-]+\))?$ ]] || bad "Depends: $a isn't a package's name (and version)"
		done
	done
fi
[[ "$(dpkg-deb -f "$DEB" X-Sprite-Community)" =~ ^https://[^[:space:]]+$ ]] || bad "X-Sprite-Community, where to ask about the app, isn't an https:// address"

# Its files, from tar's listing with numeric owners. An odd name (a space, a quote) comes quoted, so the check on names below refuses it, and anything after a name but a symlink's target is refused.
listing=$(dpkg-deb --fsys-tarfile "$DEB" | tar -tv --numeric-owner --quoting-style=shell-escape) ||
	bad "its files can't be listed"
ok_place() {   # a path (no leading ./ or /) in the app's own places
	case "$1" in
		usr/lib/$PKG|usr/lib/$PKG/*|usr/share/$PKG|usr/share/$PKG/*|usr/share/doc/$PKG|usr/share/doc/$PKG/*) return 0 ;;
		usr/share/sprite/apps/$ID.app) return 0 ;;
	esac
	return 1
}
# its symlinks, by name, so a symlink's target can't go by way of another of them (which the text of the target doesn't show: a/../.. through a link a goes wherever a does)
declare -A LINKS=()
while read -r perms _ _ _ _ name _; do
	[ "${perms:0:1}" = l ] || continue
	name=${name#./}; LINKS["${name%/}"]=1
done <<< "$listing"
manifest=no
while read -r perms owner _size _date _time name rest; do
	[ -n "$perms" ] || continue
	name=${name#./}; name=${name%/}
	type=${perms:0:1}
	[ -n "$name" ] || continue
	if [ "$type" = l ]; then
		[[ "$rest" =~ ^-\>\ [^\ ]+$ ]] || { bad "$name: an odd symlink ($rest)"; continue; }
	elif [ -n "$rest" ]; then
		bad "$name $rest: an odd name"; continue
	fi
	[[ "$name" =~ ^[A-Za-z0-9._+@,=/-]+$ ]] || { bad "$name: names letters, digits and ._+@,=- only"; continue; }
	[[ "/$name/" != */../* && "/$name/" != */./* ]] || { bad "$name: . or .. in its path"; continue; }
	[ "$owner" = 0/0 ] || bad "$name: owned by $owner, not root"
	[[ "$perms" =~ [sStT] ]] && bad "$name: setuid, setgid or sticky ($perms)"
	if [ "$type" != l ] && [[ "${perms:5:1}${perms:8:1}" == *w* ]]; then bad "$name: others can write it ($perms)"; fi
	if [ "$type" = d ]; then
		case "$name" in usr|usr/lib|usr/share|usr/share/doc|usr/share/sprite|usr/share/sprite/apps) continue ;; esac
	fi
	ok_place "$name" || { bad "$name: not in the app's own places"; continue; }
	case "$type" in
		d) ;;
		-) [ "$name" = "usr/share/sprite/apps/$ID.app" ] && manifest=yes ;;
		l)
			target=${rest#-> }
			[ "$name" != "usr/share/sprite/apps/$ID.app" ] || bad "$name: the manifest is a symlink"
			[[ "$target" =~ ^[A-Za-z0-9._+@,=/-]+$ ]] || { bad "$name: symlink to an odd name"; continue; }
			# where it points, resolved from the link's folder, must be in the app's places too
			if [ "${target:0:1}" = / ]; then path=${target#/}; else path="$(dirname "$name")/$target"; fi
			resolved=""
			IFS=/ read -ra parts <<< "$path"
			through=""
			for ((j = 0; j < ${#parts[@]}; j++)); do
				p=${parts[j]}
				case "$p" in
					""|.) ;;
					..) if [[ "$resolved" == */* ]]; then resolved=${resolved%/*}; else resolved=""; fi ;;
					*) resolved="${resolved:+$resolved/}$p" ;;
				esac
				# a folder on the way that's one of its symlinks (the last part may be one: that one's checked itself)
				(( j < ${#parts[@]} - 1 )) && [ -n "$resolved" ] && [ -n "${LINKS[$resolved]:-}" ] && through=$resolved
			done
			if [ -n "$through" ]; then bad "$name: symlink by way of another, $through"
			else ok_place "$resolved" || bad "$name: symlink out of the app's places, to $target"; fi
			;;
		h) bad "$name: a hard link" ;;
		*) bad "$name: not a plain file, folder or symlink ($perms)" ;;
	esac
done <<< "$listing"
[ "$manifest" = yes ] || bad "no manifest, usr/share/sprite/apps/$ID.app"

# The manifest, as the interface reads it (key=value, the last one for a key, # lines skipped)
if [ "$manifest" = yes ]; then
	m=$(dpkg-deb --fsys-tarfile "$DEB" | tar -xO "./usr/share/sprite/apps/$ID.app")
	# (the interface reads a line at a time into 768 bytes, so a longer one would be two lines to it and one here)
	awk 'length($0) > 500 { exit 1 }' <<< "$m" || bad "manifest: a line longer than 500 bytes"
	val() { sed -n "s/^$1=//p" <<< "$m" | tail -1 | sed 's/[[:space:]]*$//'; }
	keys=$(grep -v '^#' <<< "$m" | grep '=' | sed 's/=.*//' | sort -u)
	for k in $keys; do
		case "$k" in
			name|exec|icon|color|display|handle|bar|kind|allow|web|memory) ;;
			builtin) bad "manifest: builtin= is the interface's own" ;;
			*) bad "manifest: $k= isn't something the interface reads" ;;
		esac
	done
	name=$(val name) exec=$(val exec) icon=$(val icon)
	[ -n "$name" ] || bad "manifest: no name="
	[ "${#name}" -le 40 ] || bad "manifest: name= longer than 40"
	[ "$name" = "$(dpkg-deb -f "$DEB" X-Sprite-Name)" ] || bad "X-Sprite-Name isn't the manifest's name="
	[ -n "$exec" ] || bad "manifest: no exec="
	[ "${#exec}" -lt 500 ] || bad "manifest: exec= too long"
	# one command and its arguments, which the interface runs with exec: nothing a shell reads as more (no ; & | < > $ ` quotes, globs, ( ) { } ~ or #), and no VAR=value before it
	[[ "$exec" =~ ^[A-Za-z0-9_@%+=:,./-]+(\ [A-Za-z0-9_@%+=:,./-]+)*$ ]] && [[ "${exec%% *}" != *=* ]] || bad "manifest: exec= isn't one command and its arguments (put anything more in a script)"
	if [ -n "$icon" ]; then
		glyphs=$(sed 's/#.*//; s/=/ /' "$ICONS" | tr -s ' \t' '\n' | grep -v '^$')
		grep -qxF "$icon" <<< "$glyphs" || [[ "$icon" =~ ^[A-Za-z0-9]{1,2}$ ]] ||
			bad "manifest: icon=$icon isn't one of the interface's glyphs (src/icons.txt), or two letters"
	fi
	c=$(val color); [ -z "$c" ] || [[ "$c" =~ ^[0-9A-Fa-f]{6}$ ]] || bad "manifest: color=$c isn't RRGGBB"
	v=$(val display); case "$v" in ""|x11|wayland) ;; *) bad "manifest: display=$v (x11 or wayland)" ;; esac
	v=$(val handle); case "$v" in ""|normal|faint|hidden) ;; *) bad "manifest: handle=$v (normal, faint or hidden)" ;; esac
	v=$(val bar); case "$v" in ""|yes|no) ;; *) bad "manifest: bar=$v (yes or no)" ;; esac
	kind=$(val kind); case "$kind" in ""|app|screensaver|service) ;; *) bad "manifest: kind=$kind (app, screensaver or service)" ;; esac
	[ "${kind:-app}" = "$(dpkg-deb -f "$DEB" X-Sprite-Kind)" ] || bad "X-Sprite-Kind isn't the manifest's kind="
	# a service's own: the port of its web page, and the memory it needs (MB; the interface's sandbox allows 64 to 320)
	v=$(val web); [ -z "$v" ] || { [ "$kind" = service ] && [[ "$v" =~ ^[0-9]{1,5}$ ]] && [ "$v" -ge 1 ] && [ "$v" -le 65535 ]; } || bad "manifest: web=$v (a port, for a service)"
	v=$(val memory); [ -z "$v" ] || { [ "$kind" = service ] && [[ "$v" =~ ^[0-9]{2,3}$ ]] && [ "$v" -ge 64 ] && [ "$v" -le 320 ]; } || bad "manifest: memory=$v (64 to 320, for a service)"
	for a in $(val allow); do
		case "$a" in network|sound|microphone|music) ;; lowports) [ "$kind" = service ] || bad "manifest: allow=lowports is for a service" ;; *) bad "manifest: allow=$a (network, sound, microphone, music, or lowports for a service)" ;; esac
	done
	[ "$(echo $(val allow))" = "$(echo $(dpkg-deb -f "$DEB" X-Sprite-Allow))" ] || bad "X-Sprite-Allow, which the Shop shows, isn't the manifest's allow="
fi

[ "$FAILS" -eq 0 ] || { echo "$PKG: $FAILS problem(s)"; exit 1; }
echo "$PKG: package checks pass"
