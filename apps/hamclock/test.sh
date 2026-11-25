# Without a display, -h prints HamClock's usage (with its version) and exits 1.
set +e; HOME=/tmp /usr/lib/ofapp-hamclock/hamclock -h > /dev/null 2> usage.txt; rc=$?; set -e
[ "$rc" -eq 1 ] && grep -q "^Version ${VERSION%%-*}$" usage.txt
# Built without its own updater or the system controls (it names the switches it was built with, so the names are in the program only when they're set), and with no "Reboot computer" left in its menu.
grep -aq NO_UPGRADE /usr/lib/ofapp-hamclock/hamclock
grep -aq NO_SYSTEM_CONTROLS /usr/lib/ofapp-hamclock/hamclock
if grep -aq "Reboot computer" /usr/lib/ofapp-hamclock/hamclock; then echo "Reboot computer is still in its menu"; exit 1; fi
