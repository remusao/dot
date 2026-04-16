#!/bin/sh
# cool-ryzen-auto-toggle.sh — Toggle auto power switching on AC plug/unplug
FLAG=/tmp/cool-ryzen-no-auto
if [ -f "$FLAG" ]; then
    rm -f "$FLAG"
    label="ON"
else
    touch "$FLAG"
    label="OFF"
fi
dunstify -h string:x-dunst-stack-tag:power-auto "Auto Power Switch: $label"
