# openframe-apps

Apps and screensavers for the OpenFrame's [interface](https://github.com/birdslikewires/openframe-sprite), and the apt repository they're installed from: [apps.openbeak.net](https://apps.openbeak.net). OpenFrames find them in the Shop.

Every OpenFrame running [openframe-linux](https://github.com/birdslikewires/openframe-linux) knows this repository already: openframe-scripts adds it, with its own signing key, and pins it so it can only ever supply packages named `ofapp-*`, never anything of the system's. Apps a unit has installed are updated overnight with the rest of its updates.

## How it works

- **Recipes, not packages.** Each app is a folder in `apps/`: its manifest, what the Shop says about it, and how to build it. CI builds it into an `ofapp-<id>` package, checks it, signs the repository and publishes it. Nobody uploads a package.
- **Two suites,** as OpenBeak's other repositories have: what's published goes to `trixie-testing` first, which test units take (OF-BOOT/settings/test.txt), and reaches `trixie`, every OpenFrame, when it's promoted by "ok" on the repository's testing issue.
- **Signed with a key of its own** (OpenFrame Apps, `B17C E4B9 D466 6458 FFFB AD99 C0A0 A443 333D C2F6`; `ci/openframe-apps.gpg`), which signs nothing else.
- **Apps can't touch the system.** A package may install files only (no maintainer scripts), only in its own places, and it runs in a sandbox with only what its manifest asks for.

The plan in full is in the interface's [docs/shop.md](https://github.com/birdslikewires/openframe-sprite/blob/main/docs/shop.md). The recipe format, and what every package is checked for before it's published, are in [apps/README.md](apps/README.md).

## Contributing an app

By pull request, adding a folder to `apps/` ([apps/README.md](apps/README.md) says what goes in it). Each pull request's apps are built, checked and tested before it's reviewed, and every recipe is reviewed before it's merged.

## The apps

- [HamClock](apps/hamclock/): amateur radio clock and propagation maps.
- [SqueezePlay](apps/squeezeplay/): music from Lyrion Music Server, with JiveLite and squeezelite.

## Licence

This repository's own work is under the GNU General Public License, version 3 or (at your option) any later version (see [LICENSE](LICENSE)). Copyright 2026 Andrew Davison. Each app keeps its own licence, given in its recipe.
