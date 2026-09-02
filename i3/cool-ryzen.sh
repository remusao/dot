#!/bin/sh
# cool-ryzen.sh — Toggle power saver (i3 keybinding wrapper)
set -eu

# A keybinding has no stdout: without the OSD a failure looks like a dead key.
fail() {
    dunstify -u critical -h string:x-dunst-stack-tag:power-saver "Power Saver" "$1"
    exit 1
}

# Empty is not "low", so it would fall through to "on" forever; hence the -n
# guard below rather than trusting the case.
DPM=$(cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null | head -1)
[ -n "$DPM" ] || fail "no amdgpu DPM node found"

case "$DPM" in
    low) action=off ;;
    *)   action=on  ;;
esac

# -n: under i3's exec there is no tty to answer a password prompt.
sudo -n /usr/local/bin/cool-ryzen-apply "$action" --notify \
    || fail "sudo failed — run install.sh"
