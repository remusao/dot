# Migrating from i3/X11 to Sway/Wayland

Audit of the current dotfiles setup and what it takes to move to Sway on Wayland.
Ubuntu 24.04 ships Sway 1.9 in the universe repository.

---

## What Works As-Is on Sway

These require zero changes — they transfer verbatim from `i3/config`:

- All `bindsym` for focus, move, workspace switching, resize mode, layout changes (lines 46-202)
- `floating_modifier $mod`, `font pango:DejaVu Sans Mono 10`
- `pamixer`, `brightnessctl`, `playerctl`, `pactl` — these talk to PulseAudio/PipeWire and kernel interfaces, not X11. Ubuntu 24.04 uses PipeWire by default; all commands work via its PulseAudio compatibility layer.
- `loginctl lock-session` — systemd, not X11
- `dunstify` — Ubuntu 24.04 ships dunst 1.9.2 which has native Wayland support. All volume/brightness OSD notifications work unchanged.
- `i3status.conf` — works with Sway's built-in swaybar
- `--no-startup-id` — silently ignored by Sway (no startup notification on Wayland). Safe to keep or strip.
- `exec` runs on initial load only, `exec_always` runs on every config reload — same as i3

---

## What Doesn't Work — Tool Replacement Table

Every package listed below is in the Ubuntu 24.04 repos unless noted.

| Current (X11) | Replacement (Wayland) | Package | Notes |
|---|---|---|---|
| `i3` | `sway` | `sway` | Includes `swaynag`, `swaymsg`, `swaybg` |
| `i3lock` | `swaylock` | `swaylock` | Same CLI: `swaylock -c 475263` |
| `xss-lock` | `swayidle` | `swayidle` | Different paradigm — event-driven idle manager |
| `urxvt` (rxvt-unicode) | `foot` | `foot` | Wayland-native, GPU-rendered, fast |
| `scrot` | `grim` | `grim` | Full-screen screenshot |
| `gnome-screenshot -i -a` | `grim -g "$(slurp)"` | `grim`, `slurp` | Interactive region selection |
| `xclip` | `wl-copy` / `wl-paste` | `wl-clipboard` | |
| `redshift` | `gammastep` | `gammastep` | Direct fork, same CLI. v2.0.9 in repos |
| `feh` / `.fehbg` | `output * bg` directive | `swaybg` (dep of sway) | Built into sway config |
| `xrandr --dpi 96` | `output * scale 1` | built-in | DPI via output scaling |
| `xset b off` / `xset r rate` | `input type:keyboard` block | built-in | |
| `setxkbmap` | `input type:keyboard` block | built-in | |
| `xdotool` | `wtype` | `wtype` | `wtype -M ctrl -k minus` (auto-releases modifiers) |
| `rofi` (1.7.x) | `fuzzel` | `fuzzel` | rofi 1.7.x is X11-only. v2.0 has Wayland but isn't in 24.04 repos. `fuzzel` 1.9.2 is in repos. |
| `i3-nagbar` | `swaynag` | included with sway | Same flags |
| `i3-msg` | `swaymsg` | included with sway | Same IPC protocol |
| `lxrandr` | `wlr-randr` | `wlr-randr` | Optional, for scripting |
| `x11-xserver-utils` | not needed | — | |
| `x11-xkb-utils` | not needed | — | |
| `pasystray` | drop | — | Crashes on Wayland (X11 GDK calls). Use `pavucontrol` on-demand. |
| `libinput-gestures` | `bindgesture` | built-in | Sway 1.8+ has native gesture support |
| `Xresources` | `foot/foot.ini` + `fontconfig/fonts.conf` | — | Still useful for XWayland apps via `xrdb -merge` |
| `xinitrc` | not needed | — | Sway launches from TTY directly |
| Xorg touchpad conf | `input type:touchpad` block | built-in | |
| `assign [class="..."]` | `assign [app_id="..."]` | built-in | Wayland apps use `app_id`, not X11 `class` |

**Additional packages to install:**
- `xdg-desktop-portal-wlr`, `xdg-desktop-portal-gtk` — screen sharing, file dialogs
- `wl-clip-persist` — Wayland clipboard content dies when source app closes (check repos, may need build)

---

## File-by-File Migration Guide

### `i3/config` -> `sway/config`

Copy `i3/config` and apply the following changes. ~70% of lines transfer verbatim.

**Lines to change:**

| Line(s) | Current | Replacement | Reason |
|---|---|---|---|
| 16-22 | `assign [class="(?i)firefox"] 2` | `assign [app_id="(?i)firefox"] 2` | Wayland apps use `app_id`. Verified values: `firefox`, `chromium-browser`, `thunderbird`. Keep `class` lines as comments for XWayland fallback. |
| 26-35 | `workspace 1 output HDMI-A-0` / `eDP` | `workspace 1 output HDMI-A-1` / `eDP-1` | DRM connector names are 1-indexed. **Verify with `swaymsg -t get_outputs` on actual hardware.** |
| 40 | `new_window pixel 1` | `default_border pixel 1` | `new_window` is deprecated in Sway, triggers swaynag warning. |
| 56 | `exec --no-startup-id redshift -l 48.8:11.34` | `exec gammastep -l 48.8:11.34` | redshift has no Wayland support. |
| 62 | `bindsym $mod+Return exec urxvt` | `bindsym $mod+Return exec foot` | urxvt is X11-only. |
| 90 | `rofi -combi-modi window,run -show combi ...` | `fuzzel` | rofi 1.7.x is X11-only. |
| 174 | `bindsym $mod+Shift+r restart` | `bindsym $mod+Shift+r reload` | **`restart` does not exist in Sway** (hard error). Sway IS the compositor and cannot restart in-place. |
| 176 | `i3-nagbar -t warning -m '...' -b 'Yes, exit i3' 'i3-msg exit'` | `swaynag -t warning -m '...' -b 'Yes, exit sway' 'swaymsg exit'` | |
| 205 | `bindsym Print exec scrot -e 'mv $f /tmp/'` | `bindsym Print exec grim /tmp/screenshot-$(date +%Y%m%d-%H%M%S).png` | scrot is X11-only. |
| 206 | `bindsym $mod+Print exec gnome-screenshot -i -a` | `bindsym $mod+Print exec grim -g "$(slurp)" /tmp/screenshot-$(date +%Y%m%d-%H%M%S).png` | |
| 220 | `exec --no-startup-id nm-applet` | `exec nm-applet --indicator` | `--indicator` required for Wayland StatusNotifierItem tray. |

**Lines to remove entirely:**

| Line | Content | Why |
|---|---|---|
| 209 | `xss-lock --transfer-sleep-lock -- i3lock --nofork --color 475263` | Replaced by swayidle block |
| 211 | `xrandr --dpi 96` | Replaced by `output` scale directive |
| 214 | `xset b off` | Replaced by input keyboard block |
| 215 | `xset r rate 300 100` | Replaced by input keyboard block |
| 216 | `setxkbmap -layout us -option ctrl:nocaps,compose:ralt,terminate:ctrl_alt_bksp` | Replaced by input keyboard block. Note: `terminate:ctrl_alt_bksp` is meaningless on Wayland (no X server to kill). |
| 218 | `libinput-gestures-setup start` | Replaced by `bindgesture` |
| 221 | `pasystray` | Crashes on Wayland |
| 222 | `/home/remi/.fehbg` | Replaced by `output * bg` directive |

**New blocks to add to `sway/config`:**

```
# Idle and lock (replaces xss-lock + i3lock)
# The `lock` event fires on any `loginctl lock-session` — from keybind, timeout, or sleep.
exec swayidle -w \
    timeout 300 'loginctl lock-session' \
    lock 'swaylock -f -c 475263' \
    before-sleep 'loginctl lock-session'

# Touchpad (replaces /etc/X11/xorg.conf.d/30-touchpad.conf)
input type:touchpad {
    tap enabled
    tap_button_map lrm
    drag_lock enabled
    natural_scroll disabled
    click_method clickfinger
}

# Keyboard (replaces setxkbmap + xset)
# repeat_rate is characters per second (not milliseconds)
input type:keyboard {
    xkb_layout us
    xkb_options ctrl:nocaps,compose:ralt
    repeat_delay 300
    repeat_rate 100
}

# Gestures (replaces libinput-gestures)
# Syntax: bindgesture <type>:<fingers>:<direction> <command>
bindgesture swipe:3:left workspace prev
bindgesture swipe:3:right workspace next
bindgesture swipe:3:up fullscreen toggle
bindgesture swipe:3:down floating toggle
bindgesture swipe:4:left move container to workspace prev, workspace prev
bindgesture swipe:4:right move container to workspace next, workspace next
# Pinch-to-zoom: Firefox/Chromium handle this natively on Wayland — no need for wtype simulation.

# Output (replaces xrandr + feh)
# 2880x1800 OLED: scale 2 gives effective 1440x900. Tilde expands in sway config.
output eDP-1 scale 2
output * bg ~/path/to/wallpaper.jpg fill

# Cursor theme (replaces Xresources Xcursor.theme/Xcursor.size)
seat seat0 xcursor_theme Vanilla-DMZ-AA 32

# Clipboard persistence (Wayland clipboard dies with source app)
exec wl-clip-persist --clipboard regular

# XWayland compatibility (loads Xresources for legacy X11 apps)
exec xrdb -merge ~/.Xresources

# Portal and systemd environment propagation
# Required for xdg-desktop-portal-wlr to auto-start via dbus
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway

# System defaults — CRITICAL: includes 50-systemd-user.conf which propagates
# WAYLAND_DISPLAY, SWAYSOCK, XDG_CURRENT_DESKTOP to systemd/dbus.
# Required for portals, Flatpak, Snap apps.
include /etc/sway/config.d/*
```

### `zshrc`

| Line | Current | Change |
|---|---|---|
| 18 | `export TERM='rxvt-unicode-256color'` | Remove. foot sets `TERM=foot` automatically. |
| 25-26 | `xset b off` / `xset r rate 300 100` | Wrap in `XDG_SESSION_TYPE` guard (see below) |
| 103 | `alias lock='i3lock --color 475263'` | Wrap in guard |
| 115-116 | `alias pbcopy='xclip -selection clipboard'` / `alias pbpaste='xclip -selection clipboard -o'` | Wrap in guard |

Replace those scattered lines with a single block:

```zsh
# dircolors workaround: foot terminfo not in dircolors' built-in list
eval "$(TERM=xterm-256color dircolors)"

# Display-server-specific settings
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    alias lock='swaylock -c 475263'
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste'
elif [ "$XDG_SESSION_TYPE" = "x11" ]; then
    xset b off
    xset r rate 300 100
    alias lock='i3lock --color 475263'
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
fi
```

### `install.sh`

**Remove:**
- Lines 45-53: i3 PPA setup (sur5r-keyring). Sway is in Ubuntu universe repos.

**Package list changes (lines 58-87):**
- `rxvt-unicode` -> `foot`
- `i3 i3lock i3status rofi redshift feh` -> `sway swaylock swayidle i3status fuzzel gammastep`
- Remove: `xss-lock`, `scrot gnome-screenshot`, `x11-xserver-utils x11-xkb-utils lxrandr`, `xclip`
- Add: `grim slurp`, `wl-clipboard`, `wtype`, `xdg-desktop-portal-wlr xdg-desktop-portal-gtk`

**Symlinks (line 250):**
Update loop — remove `Xresources`, `i3`, `xinitrc`. Add XDG config dir symlinks:

```bash
for file in gitconfig i3status.conf vim vimrc zshrc; do
    # ... existing symlink logic ...
done

# XDG config symlinks
for d in sway foot fontconfig xdg-desktop-portal; do
    mkdir -p "${HOME}/.config/${d}"
done
ln -sf "${DOT_DIR}/sway/config" "${HOME}/.config/sway/config"
ln -sf "${DOT_DIR}/foot/foot.ini" "${HOME}/.config/foot/foot.ini"
ln -sf "${DOT_DIR}/fontconfig/fonts.conf" "${HOME}/.config/fontconfig/fonts.conf"
ln -sf "${DOT_DIR}/sway-portals.conf" "${HOME}/.config/xdg-desktop-portal/sway-portals.conf"
```

**ZBook input section (lines 278-318):**
- Remove Xorg touchpad conf block (lines 282-293) — config moves to `sway/config` `input type:touchpad` block.
- Keep `/etc/default/keyboard` XKB options (line 297) — still used by TTY console.
- Remove `libinput-gestures libinput-tools xdotool wmctrl` install. Replace with just `wtype`.
- Remove `libinput-gestures.conf` creation — gestures now via `bindgesture` in sway config.

### `test/e2e.sh`

- Line 36: Remove `.i3`, `.Xresources`, `.xinitrc` from symlink checks. Add `~/.config/sway/config`, `~/.config/foot/foot.ini`, `~/.config/fontconfig/fonts.conf`.
- Lines 64-67: Rename section to "desktop & sway". Check for `sway swaylock swayidle i3status fuzzel`.
- Lines 68-70: Replace `scrot xss-lock` with `grim slurp`.
- Line 76: `xclip` -> `wl-copy`. Add `foot` check.
- Lines 234-240: Reference `sway/config`. Check for `swayidle`, `input type:touchpad`, `input type:keyboard`, `bindgesture`. Negative checks for `xss-lock`, `xrandr`, `libinput-gestures`.

### `zbook-health-check.sh` (lower priority)

- Touchpad check: look for `input type:touchpad` in sway config instead of `/etc/X11/xorg.conf.d/`
- XKB check: `swaymsg -t get_inputs` instead of `setxkbmap`
- Display check: expand existing Wayland branch with swayidle/swaylock checks
- Remove X11 tearing fix checks (Wayland composites natively)

### Deprecated files: `xinitrc`, `Xresources`, `i3/config`

Keep in repo, add deprecation comment. `Xresources` remains useful for XWayland apps (loaded via `xrdb -merge` in sway config).

---

## New Files to Create

### `foot/foot.ini`

Port from `Xresources` (URxvt colors, font). Colors are bare hex (no `#` prefix).

```ini
[main]
font=Inconsolata for Powerline:size=12

[scrollback]
lines=65535

[cursor]
color=191919 ff8c00

[colors]
background=191919
foreground=c6c6c6
regular0=073642
regular1=dc322f
regular2=25b20f
regular3=b58900
regular4=268bd2
regular5=d33682
regular6=2aa198
regular7=eee8d5
bright0=002b36
bright1=cb4b16
bright2=586e75
bright3=657b83
bright4=839496
bright5=6c71c4
bright6=93a1a1
bright7=fdf6e3
```

### `fontconfig/fonts.conf`

Replaces `Xft.*` settings from `Xresources` (antialias, hinting, lcdfilter, rgba).

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
  </match>
</fontconfig>
```

### `sway-portals.conf`

Routes screen sharing to `wlr`, everything else to `gtk`. Symlink to `~/.config/xdg-desktop-portal/sway-portals.conf`.

```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
```

### `zprofile` (Sway auto-start from TTY)

```zsh
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    exec sway
fi
```

---

## Gotchas and Risks

### Sway-specific

- **`restart` command does not exist**: Sway IS the Wayland compositor — it cannot restart in-place. Use `reload` to re-read config. For binary upgrades, exit and restart Sway.
- **`sway -C` validation**: Always exits 0 (known bug sway#4976), but does print warnings/errors to stderr. Check output, don't trust the exit code.
- **Output names**: AMD DRM connector names are 1-indexed (`HDMI-A-1`, `eDP-1`), not 0-indexed like X11 (`HDMI-A-0`, `eDP`). Must verify on hardware with `swaymsg -t get_outputs`.
- **Window matching**: Wayland-native apps use `app_id`, not X11 `class`. Firefox, Chromium, Thunderbird all run natively on Wayland — use `assign [app_id="..."]`. XWayland apps still use `class`. Discover values with `swaymsg -t get_tree`.
- **HiDPI / fractional scaling**: The ZBook's 2880x1800 OLED needs `output eDP-1 scale 2` (effective 1440x900). Fractional scaling (e.g. 1.5) works but XWayland apps and apps without `wp_fractional_scale_v1` will be blurry.
- **`include /etc/sway/config.d/*`**: Must be in your sway config. It provides `50-systemd-user.conf` which propagates `WAYLAND_DISPLAY`, `SWAYSOCK`, `XDG_CURRENT_DESKTOP` to systemd/dbus — required for portals, Flatpak, and Snap.

### Clipboard

- **Wayland clipboard content dies when the source app closes.** This is a Wayland protocol design. Use `wl-clip-persist --clipboard regular` to keep clipboard content alive. Use `--clipboard regular` (not `both` — primary selection persistence causes GTK issues).

### Tray icons

- **`pasystray` crashes on Wayland** (X11-only GDK calls). Drop it. Use `pavucontrol` on demand.
- **`nm-applet` requires `--indicator`** flag for Wayland. Without it, uses X11 XEmbed protocol and won't appear. Known issue: clicking the tray icon may not work reliably in swaybar.
- **Swaybar tray**: Has StatusNotifierItem support since Sway 1.5, but clicking icons can be unreliable. If this is a problem, switch to `waybar` (`swaybar_command waybar`).

### Terminal (foot)

- foot sets `TERM=foot` by default. The `foot` terminfo ships with `ncurses-term` (auto-installed dependency).
- **`dircolors` gotcha**: `dircolors` has a hardcoded terminal list and `foot` isn't on it. Use `eval "$(TERM=xterm-256color dircolors)"` in zshrc.
- **SSH to remote hosts**: Remote hosts likely lack foot terminfo. Use `TERM=xterm-256color ssh ...` as workaround, or install `ncurses-term` / copy `~/.terminfo/f/foot` to remotes.
- **Cursor color syntax** (foot 1.16.2 on Ubuntu 24.04): `[cursor]` section, `color=RRGGBB RRGGBB` (text-on-cursor background-of-cursor). No `#` prefix.

### Screen sharing

- Requires `xdg-desktop-portal-wlr` and `xdg-desktop-portal-gtk` packages.
- Portals auto-start via dbus activation — no `exec` lines needed in sway config.
- `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway` IS needed (the portal's systemd service has `ConditionEnvironment=WAYLAND_DISPLAY`).
- Create portal routing config (`sway-portals.conf`) to direct Screenshot/ScreenCast to `wlr` and everything else to `gtk`.
- Limitation: only entire outputs can be shared, not individual windows.

### Applications

- **Firefox**: Auto-detects Wayland on Ubuntu 24.04 (Snap). `MOZ_ENABLE_WAYLAND=1` not needed. Verify via `about:support` (Window Protocol = "wayland").
- **Electron apps** (Slack, Obsidian, VS Code): Set `ELECTRON_OZONE_PLATFORM_HINT=auto` environment variable before launching Sway, or per-app via `~/.config/<app>-flags.conf`. Slack has known blank-window issues on Sway — test carefully.
- **Qt apps**: Set `QT_QPA_PLATFORM=wayland;xcb` (falls back to XWayland if Wayland fails).
- **XWayland**: Enabled by default in Sway (lazy-loaded on first X11 client). No explicit config needed. Spotify, Steam, and many Electron apps still need it.

### polkit agent

- `policykit-1-gnome` is archived upstream and has known Wayland crash bugs. It may work fine, or it may crash when authentication dialogs appear. Test it first; if it crashes, switch to `lxqt-policykit` (`/usr/bin/lxqt-policykit-agent`).

### keychain vs gnome-keyring

- Both are currently configured: `keychain` in zshrc (line 4), `gnome-keyring-daemon` in xinitrc.
- **They conflict**: both set `SSH_AUTH_SOCK` — whichever runs last wins.
- Recommendation: start gnome-keyring with `--components=pkcs11,secrets` only (drop `ssh` and `gpg`). Keep `keychain` for SSH/GPG agent.
- Note: `keychain` 2.9.0+ has deprecated the `--agents` flag. The current `keychain --agents 'ssh,gpg' --eval ...` will produce a deprecation warning.
- `keychain` itself is Wayland-compatible (it's a shell script, no display dependency).
- Caveat: `SSH_AUTH_SOCK` set in your shell only reaches terminals. For compositor-launched GUI apps to find it, propagate it with `dbus-update-activation-environment` or `systemctl --user set-environment`.

### Environment variables

- `~/.config/environment.d/*.conf` files are loaded by `systemd --user` but **only reach systemd user services**, NOT your shell or Sway process. They are not a replacement for shell profile files.
- For Sway-specific env vars (`QT_QPA_PLATFORM`, `ELECTRON_OZONE_PLATFORM_HINT`, `XCURSOR_THEME`, `XCURSOR_SIZE`), set them in a wrapper script before `exec sway`, or export them in `~/.zprofile`.
- The `include /etc/sway/config.d/*` + `dbus-update-activation-environment` pattern handles propagating `WAYLAND_DISPLAY` and `XDG_CURRENT_DESKTOP` to dbus/systemd.

### Starting Sway

- Launch from TTY with `exec sway` (add to `~/.zprofile` with a guard).
- `dbus-run-session` is not needed — systemd/logind provides the dbus session bus.
- Alternative: use `greetd` + `tuigreet` as a display manager.

---

## Decisions to Make Before Migrating

1. **App launcher**: `fuzzel` (in repos, simple, Wayland-native, icon support) vs building `rofi-wayland` from source (preserves existing rofi themes and scripting modes).
2. **HiDPI scale**: `scale 2` (pixel-perfect, effective 1440x900) vs `scale 1.5` (more screen space, but XWayland apps blur).
3. **polkit agent**: Keep `policykit-1-gnome` (test first) or preemptively switch to `lxqt-policykit`.
4. **SSH/GPG agent**: Resolve the keychain vs gnome-keyring conflict (recommended: gnome-keyring for secrets/pkcs11 only, keychain for SSH/GPG).
5. **Status bar**: Keep i3status + swaybar (minimal change) or switch to waybar (better tray support, more features).

---

## Verification Checklist

After migration:

- [ ] `sway -C` prints no errors (ignore exit code — always 0)
- [ ] `test/e2e.sh` passes
- [ ] `swaymsg -t get_outputs` — confirm output names match config
- [ ] `swaymsg -t get_tree` — verify app_id values for window assignments
- [ ] Lock/idle: `loginctl lock-session` triggers swaylock; idle timeout works; lock before suspend works
- [ ] Screenshots: Print key captures full screen; Mod+Print captures region
- [ ] Clipboard: copy text, close source app, paste still works (wl-clip-persist)
- [ ] Volume/brightness OSD: media keys show dunstify notifications
- [ ] Gestures: 3-finger swipe switches workspaces; 4-finger moves containers
- [ ] Screen sharing: Firefox WebRTC can share a screen
- [ ] nm-applet tray icon visible and functional
- [ ] Electron apps (Slack, Obsidian) launch without blank windows
