#!/bin/sh
# cool-ryzen-auto-toggle.sh — Toggle auto power switching on AC plug/unplug.
# Bound to $mod+Shift+p. The flag lives in /run/user/<uid> so it dies with the
# session and auto switching re-arms on reboot; i3/cool-ryzen-apply.sh (root,
# via udev) rebuilds the same path from `who` — move one, move both.
set -u

FLAG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/cool-ryzen-no-auto"

# No `set -e`: a failed write must still reach the OSD, not exit in silence.
if [ -f "$FLAG" ]; then
    rm -f "$FLAG" || true
else
    touch "$FLAG" || true
fi

# Label read back from the flag, not intent: a failed write must not read as success.
if [ -f "$FLAG" ]; then label="OFF"; else label="ON"; fi
dunstify -h string:x-dunst-stack-tag:power-auto "Auto Power Switch: $label"

# Re-enabling auto rides no udev event, so the profile is still whatever the
# suppressed transition left behind — AC profile, on battery. Reconcile the
# power-saving direction only, so a deliberate power-saver on AC survives; -n
# because nothing can answer a password prompt under i3's exec.
if [ "$label" = "ON" ] && [ -x /usr/local/bin/cool-ryzen-apply ] \
   && [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null)" = "0" ]; then
    sudo -n /usr/local/bin/cool-ryzen-apply on \
        || dunstify -u critical -h string:x-dunst-stack-tag:power-auto \
            "Auto Power Switch: $label" "battery resync failed — run install.sh"
fi
