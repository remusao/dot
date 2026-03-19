#!/bin/bash
# media-keys.sh — Handle media key actions with OSD notifications (dunstify)
# Called from i3 config: exec --no-startup-id ~/.i3/media-keys.sh <action>
#
# i3's parser treats ; as a command separator, so compound shell commands
# cannot be inlined in bindsym — this script avoids that limitation.
set -eu

notify() {
    local tag=$1 text=$2
    shift 2
    dunstify -h "string:x-dunst-stack-tag:$tag" "$@" "$text"
}

case "${1:-}" in
    volume-up)
        pamixer -i 5
        v=$(pamixer --get-volume)
        notify volume "Volume: $v%" -h "int:value:$v"
        ;;
    volume-down)
        pamixer -d 5
        v=$(pamixer --get-volume)
        notify volume "Volume: $v%" -h "int:value:$v"
        ;;
    volume-mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        if pamixer --get-mute | grep -q true; then
            notify volume "Volume: muted"
        else
            v=$(pamixer --get-volume)
            notify volume "Volume: $v%" -h "int:value:$v"
        fi
        ;;
    mic-mute)
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes; then
            notify mic "Mic: muted"
        else
            notify mic "Mic: unmuted"
        fi
        ;;
    brightness-up)
        brightnessctl -c backlight set +5%
        b=$(brightnessctl -c backlight -m | cut -d, -f4 | tr -d %)
        notify brightness "Brightness: $b%" -h "int:value:$b"
        ;;
    brightness-down)
        brightnessctl -c backlight --min-value=1 set 5%-
        b=$(brightnessctl -c backlight -m | cut -d, -f4 | tr -d %)
        notify brightness "Brightness: $b%" -h "int:value:$b"
        ;;
    *)
        echo "Usage: media-keys.sh {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down}" >&2
        exit 1
        ;;
esac
