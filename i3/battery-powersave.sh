#!/bin/sh
# battery-powersave.sh — Enable power saver if on battery at login
# Called from i3 config: exec --no-startup-id ~/.i3/battery-powersave.sh
set -eu

if [ -x /usr/local/bin/cool-ryzen-apply ] \
   && [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null)" = "0" ]; then
    sudo /usr/local/bin/cool-ryzen-apply on
fi
