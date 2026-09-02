#!/bin/sh
# cool-ryzen-apply — Toggle iGPU low-power mode + CPU min frequency + power profile
# Runs as root. Called by udev (AC plug/unplug) and i3 toggle (via sudo).
# Usage: cool-ryzen-apply on|off [--notify] [--auto]
set -eu

auto=false notify=false
for arg in "$@"; do
    case "$arg" in
        --auto)   auto=true ;;
        --notify) notify=true ;;
    esac
done

# Root from udev, so no session to inherit: find the X user for the flag dir and OSD.
XUSER=$(who | awk '/\(:/{print $1; exit}') || XUSER=""
XRUNTIME=""
if [ -n "$XUSER" ]; then
    XRUNTIME="/run/user/$(id -u "$XUSER")"
fi

# Auto-switch disable flag (mod+Shift+p). In /run/user/<uid>, not /tmp: 0700 and
# per-user, so no other uid can plant it; dies with the session, so auto re-arms.
if $auto && [ -n "$XRUNTIME" ] && [ -f "${XRUNTIME}/cool-ryzen-no-auto" ]; then
    exit 0
fi

POLICY=/sys/devices/system/cpu/cpufreq/policy0

case "${1:-}" in
    on)  dpm=low;  ppd=power-saver
         min_khz=$(cat "$POLICY/cpuinfo_min_freq" 2>/dev/null) || min_khz=1000000
         label="ON"  ;;
    off) dpm=auto; ppd=balanced
         min_khz=$(cat "$POLICY/amd_pstate_lowest_nonlinear_freq" 2>/dev/null) || min_khz=2000000
         label="OFF" ;;
    *)   echo "Usage: cool-ryzen-apply on|off [--notify]" >&2; exit 1 ;;
esac

# `|| true` here and below: -w only says writable, not that the node accepts this
# value, and under set -e a rejected write would abort before the CPU floor is set.
for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
    [ -w "$f" ] && echo "$dpm" > "$f" || true
done

for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
    [ -w "$f" ] && echo "$min_khz" > "$f" || true
done

# PPD ≥0.22 drives DPM itself with this same mapping, so the loop above becomes
# redundant rather than conflicting.
if command -v powerprofilesctl >/dev/null 2>&1; then
    timeout 3 powerprofilesctl set "$ppd" 2>/dev/null || true
fi

# Disable ABM (PPD enables it on power-saver; causes color shift on eDP).
# Writing this does emit a DRM uevent, but udev/40-monitor-hotplug.rules already
# requires ENV{HOTPLUG}=="1", which the kernel sets only for real connector
# hotplug -- so it does not restart autorandr. `|| true` as above: writable does
# not mean the value is accepted.
for f in /sys/class/drm/card*-eDP-*/amdgpu/panel_power_savings; do
    [ -w "$f" ] && echo 0 > "$f" || true
done

if $notify && [ -n "$XUSER" ]; then
    runuser -u "$XUSER" -- env DISPLAY=:0 \
        DBUS_SESSION_BUS_ADDRESS="unix:path=${XRUNTIME}/bus" \
        /usr/bin/dunstify -h string:x-dunst-stack-tag:power-saver \
        "Power Saver: $label" 2>/dev/null || true
fi
