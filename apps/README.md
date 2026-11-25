# Recipes

Each app has a folder here named for its id, `apps/<id>/`, using lower-case letters, digits and `-`. The id becomes its package name, `ofapp-<id>`. [hamclock](hamclock/) is a full example.

| File | |
|---|---|
| `app.txt` | The manifest, which tells the OpenFrame's interface how to show and run the app. It's installed as `/usr/share/sprite/apps/<id>.app`. |
| `shop.txt` | What the Shop says about the app. |
| `build.sh` | Fetches and builds the app, and puts its files in place. |
| `copyright` | Who wrote it and its licence, in [Debian's format](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/), unless `build.sh` writes it. |
| `build-depends.txt` | Debian packages needed to build it (optional). |
| `depends.txt` | Debian packages it needs to run, beyond the libraries its programs link against, which are found automatically (optional). |
| `test.sh` | A check that it works once installed (optional). |

## app.txt

The manifest is made of `key=value` lines, and a line starting with `#` is a comment.

```
name=HamClock
exec=/usr/lib/ofapp-hamclock/hamclock -t 10
icon=radio
color=b8860b
display=x11
allow=network
```

- `name` goes on its tile, and can be up to 40 characters.
- `exec` is what to run, either a program in the package (in `/usr/lib/ofapp-<id>/`) or one from a Debian package listed in `depends.txt`.
- `icon` is one of the interface's glyphs, listed in its [src/icons.txt](https://github.com/birdslikewires/openframe-sprite/blob/main/src/icons.txt), or up to two letters. `color` is the tile's colour, as `RRGGBB`.
- `display=x11` is for an X11 or SDL program, which runs through Xwayland. Otherwise the app is expected to use Wayland.
- `kind=screensaver` makes it a screensaver, which has no tile and is chosen in Settings under Display.
- `allow` lists what it may reach beyond the screen, from `network`, `sound` (to play) and `microphone` (to record as well). It gets none of these unless it asks.
- `handle` (`normal`, `faint` or `hidden`) and `bar=yes` set how the home handle and the status bar show over it.

Every app runs in a sandbox, as a user of its own. It can't write to the system, can't see `/home` or OF-BOOT, and has one folder of its own to keep things in, its `$HOME` at `/var/lib/sprite-apps/<id>`. Its memory and processes are limited too.

## shop.txt

A few `key=value` lines, then a blank line, then a paragraph or two describing the app. Each paragraph goes on one line, however long, and the Shop wraps it to fit. Blank lines between paragraphs are fine, to make the file easier to read.

```
summary=Amateur radio clock and propagation maps
version=4.33
author=Elwood Downey and the openhamclock contributors
licence=MIT
source=https://github.com/openhamclock/hamclock
community=https://discord.gg/wb8ATjVn6M

HamClock shows the time where you are and in UTC, ...
```

- `summary` is a line the Shop shows under the app's name, and is required.
- `version` is the version of what it's built from, if it has one. The package's version is that followed by `-<year.month.N>`, where N counts the commits to the recipe that month.
- `author` and `licence` say who made it and on what terms.
- `source` is where its source code lives.
- `community` is where people can ask about the app and get help with it, as an `https://` address, and is required. We only bring apps to the OpenFrame and don't support them ourselves, so this should be the place the app's own makers and users answer questions, such as a forum, a chat server or the project's issues.

## build.sh

It runs with `bash -eu`, as root in a throwaway i386 Debian Trixie container, in an empty folder and with the network available. These are set for it.

| | |
|---|---|
| `$RECIPE` | the recipe's folder, read-only |
| `$DESTDIR` | the package's root, so files go in `$DESTDIR$APPDIR` and so on |
| `$APPDIR` | `/usr/lib/ofapp-<id>`, for programs and libraries |
| `$SHAREDIR` | `/usr/share/ofapp-<id>`, for data |
| `$DOCDIR` | `/usr/share/doc/ofapp-<id>`, for `copyright` and licences |
| `$SOURCES` | for source that a licence such as the GPL says must go with it, which is published beside the package at `apps.openbeak.net/source/ofapp-<id>/<version>/` |
| `$UPSTREAM` | `shop.txt`'s `version` |
| `$ID`, `$PKG`, `$VERSION` | the app's id, its package and the package's version |

Fetch a release rather than a branch, and check it against its SHA-256 in `build.sh`, so the recipe says exactly what's built. Files go only in the app's own places. The build writes the package's control file itself, so there are no maintainer scripts and nothing else to fill in.

## What every package is checked for

Before it's published, `ci/check-app.sh` and `ci/test-app.sh` make sure that

- it holds files only, with no maintainer scripts, triggers or conffiles, and no relations to other packages beyond its dependencies
- its files are only in `/usr/lib/ofapp-<id>/`, `/usr/share/ofapp-<id>/`, `/usr/share/doc/ofapp-<id>/` and its manifest, as plain files, folders and symlinks that stay inside them, with nothing setuid and nothing anyone else can write
- its manifest is one the interface reads, with a glyph it has, asking for nothing beyond network, sound and microphone
- it installs on a clean Trixie with only Debian's packages, pulls in no Mesa, has i386 programs, has what `exec` runs, passes its own `test.sh`, and leaves nothing behind when it's removed
