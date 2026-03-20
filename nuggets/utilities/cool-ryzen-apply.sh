#!/bin/sh
# cool-ryzen-apply — Toggle iGPU low-power mode + CPU min frequency + power profile
# Runs as root. Called by udev (AC plug/unplug) and i3 toggle (via sudo).
# Usage: cool-ryzen-apply on|off [--notify]
set -eu

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

# GPU DPM (find card dynamically)
for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
    [ -w "$f" ] && echo "$dpm" > "$f"
done

# CPU min frequency (skip offline CPUs)
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
    [ -w "$f" ] && echo "$min_khz" > "$f" || true
done

# Power profile (PPD: EPP + platform_profile; no conflict with DPM on PPD ≤0.21)
if command -v powerprofilesctl >/dev/null 2>&1; then
    timeout 3 powerprofilesctl set "$ppd" 2>/dev/null || true
fi

# Optional OSD notification
if [ "${2:-}" = "--notify" ]; then
    XUSER=$(who | awk '/\(:/{print $1; exit}')
    if [ -n "$XUSER" ]; then
        XUID=$(id -u "$XUSER")
        runuser -u "$XUSER" -- env DISPLAY=:0 \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$XUID/bus" \
            /usr/bin/dunstify -h string:x-dunst-stack-tag:power-saver \
            "Power Saver: $label" 2>/dev/null || true
    fi
fi
