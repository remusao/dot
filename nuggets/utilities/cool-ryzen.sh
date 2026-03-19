#!/bin/sh
# cool-ryzen.sh — Toggle power saver (i3 keybinding wrapper)
DPM=$(cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null | head -1)
case "$DPM" in
    low) sudo /usr/local/bin/cool-ryzen-apply off --notify ;;
    *)   sudo /usr/local/bin/cool-ryzen-apply on  --notify ;;
esac
