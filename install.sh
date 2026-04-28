#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run as root. Run as your normal user (sudo is used internally)." >&2
  exit 1
fi

USER="${USER:-$(whoami)}"
DOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${DOT_DIR}/lock.sh"

RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
BLUE=$(tput setaf 4 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

info()  { echo "${BLUE}${BOLD}==>${RESET}${BOLD} $*${RESET}"; }
ok()    { echo "${GREEN}${BOLD}  ✓${RESET} $*"; }
err()   { echo "${RED}${BOLD}  ✗${RESET} $*" >&2; }

# ── Sanity checks ──────────────────────────────────────────────────────────
# shellcheck source=/dev/null
source /etc/os-release
if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
  err "Requires Ubuntu 24.04 LTS (detected: $PRETTY_NAME)"; exit 1
fi

sudo -v
while true; do sudo -n true; sleep 55; kill -0 "$$" || exit; done 2>/dev/null &

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")

# Skip flags for Docker/CI environments
SKIP_SNAP=${DOTFILES_SKIP_SNAP:-0}
SKIP_DOCKER=${DOTFILES_SKIP_DOCKER:-0}
SKIP_1PASSWORD=${DOTFILES_SKIP_1PASSWORD:-0}
SKIP_AI_TOOLS=${DOTFILES_SKIP_AI_TOOLS:-0}
SKIP_ROCM=${DOTFILES_SKIP_ROCM:-0}

has_repo() { [ -f "$1" ]; }
REPOS_ADDED=0

# ══════════════════════════════════════════════════════════════════════════
# APT repositories (each guarded by source-file existence)
# ══════════════════════════════════════════════════════════════════════════

# ── i3 (latest release) ──────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/sur5r-i3.list; then
  info "Adding i3 official repo..."
  curl -fsSL "https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2025.12.14_all.deb" \
    -o /tmp/sur5r-keyring.deb
  sudo apt-get install "${APT_OPTS[@]}" /tmp/sur5r-keyring.deb
  rm -f /tmp/sur5r-keyring.deb
  echo "deb [signed-by=/usr/share/keyrings/sur5r-keyring.gpg] http://debian.sur5r.net/i3/ $(# shellcheck source=/dev/null
  . /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") universe" \
    | sudo tee /etc/apt/sources.list.d/sur5r-i3.list > /dev/null
  REPOS_ADDED=1
fi

# ── Firefox/Mozilla repo ─────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/mozilla.list; then
  info "Adding Mozilla apt repo..."
  sudo install -d -m 0755 /etc/apt/keyrings
  wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
  REPOS_ADDED=1
fi
# Pin files are fast + idempotent — always ensure they're correct
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
  | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
printf 'Package: firefox*\nPin: release o=Ubuntu*\nPin-Priority: -1\n' \
  | sudo tee /etc/apt/preferences.d/firefox-no-snap > /dev/null

# ── Thunderbird PPA ────────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/mozillateam-ubuntu-ppa-noble.sources; then
  info "Adding Thunderbird PPA..."
  sudo add-apt-repository -y ppa:mozillateam/ppa
  REPOS_ADDED=1
fi
printf 'Package: thunderbird*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
  | sudo tee /etc/apt/preferences.d/mozillateam-ppa > /dev/null

# ── Brave Browser ──────────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/brave-browser-release.sources; then
  info "Adding Brave Browser repo..."
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
  REPOS_ADDED=1
fi

# ── Google Chrome ─────────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/google-chrome.list; then
  info "Adding Google Chrome repo..."
  wget -q -O- https://dl.google.com/linux/linux_signing_key.pub \
    | sudo gpg --dearmor --output /usr/share/keyrings/google-chrome.gpg --yes
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
  REPOS_ADDED=1
fi

# ── OpenRazer ─────────────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/openrazer-ubuntu-stable-noble.sources; then
  info "Adding OpenRazer PPA..."
  sudo add-apt-repository -y ppa:openrazer/stable
  REPOS_ADDED=1
fi

# ── Docker Engine ──────────────────────────────────────────────────────────
if [ "$SKIP_DOCKER" != "1" ] && ! has_repo /etc/apt/sources.list.d/docker.sources; then
  info "Adding Docker repo..."
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<SRCS
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(# shellcheck source=/dev/null
. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
SRCS
  REPOS_ADDED=1
fi

# ── 1Password ──────────────────────────────────────────────────────────────
if [ "$SKIP_1PASSWORD" != "1" ] && ! has_repo /etc/apt/sources.list.d/1password.list; then
  info "Adding 1Password repo..."
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg --yes
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' \
    | sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol \
    | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol > /dev/null
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg --yes
  REPOS_ADDED=1
fi

# ── Tailscale ──────────────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/tailscale.list; then
  info "Adding Tailscale repo..."
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.noarmor.gpg" \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.tailscale-keyring.list" \
    | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null
  REPOS_ADDED=1
fi

# ── GitHub CLI ────────────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/github-cli.list; then
  info "Adding GitHub CLI repo..."
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  REPOS_ADDED=1
fi

# ── Git (latest stable) ───────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/git-core-ubuntu-ppa-noble.sources; then
  info "Adding git-core PPA..."
  sudo add-apt-repository -y ppa:git-core/ppa
  REPOS_ADDED=1
fi

# ── Pareto Security ──────────────────────────────────────────────────────
if ! has_repo /etc/apt/sources.list.d/pareto.list; then
  info "Adding Pareto Security repo..."
  curl -fsSL https://pkg.paretosecurity.com/debian/pubkey.gpg \
    | sudo gpg --dearmor --output /usr/share/keyrings/paretosecurity.gpg --yes
  echo "deb [signed-by=/usr/share/keyrings/paretosecurity.gpg] https://pkg.paretosecurity.com/debian stable main" \
    | sudo tee /etc/apt/sources.list.d/pareto.list > /dev/null
  REPOS_ADDED=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Firefox snap removal (before apt install replaces it with the deb)
# ══════════════════════════════════════════════════════════════════════════
if [ "$SKIP_SNAP" != "1" ] && snap list firefox &>/dev/null; then
  info "Removing Firefox snap..."
  sudo systemctl stop var-snap-firefox-common-host-hunspell.mount 2>/dev/null || true
  sudo systemctl disable var-snap-firefox-common-host-hunspell.mount 2>/dev/null || true
  sudo snap remove --purge firefox
  sudo apt-get purge -y firefox 2>/dev/null || true
  sudo rm -f /var/lib/snapd/seed/snaps/firefox_*.snap
  sudo rm -f /var/lib/snapd/seed/assertions/firefox_*.assert
fi

# ══════════════════════════════════════════════════════════════════════════
# Package installation (single apt-get update + single apt-get install)
# ══════════════════════════════════════════════════════════════════════════
info "Installing system packages..."
if [ "$REPOS_ADDED" = "1" ]; then
  sudo apt-get update
fi
ALL_PKGS=(
  ca-certificates curl gnupg lsb-release software-properties-common wget
  zsh git git-lfs build-essential clang g++ cmake ninja-build gettext unzip pkg-config
  python3-pip python3-venv python3-dev
  rxvt-unicode
  i3 i3lock i3status rofi gammastep feh
  pamixer pulseaudio-utils brightnessctl pavucontrol pulsemixer blueman playerctl dunst
  xss-lock policykit-1-gnome
  maim
  picom autorandr
  network-manager-gnome gnome-keyring
  libdbus-1-dev libsensors-dev
  x11-xserver-utils x11-xkb-utils lxrandr
  zsh-syntax-highlighting keychain shellcheck
  copyq xclip xsel
  jq sd hexyl entr just
  ffmpeg v4l-utils mitmproxy pandoc socat pv pigz 7zip ncdu
  zoxide duf btop nmap wireguard
  protobuf-compiler libsnappy-dev libboost-all-dev libzstd-dev
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev
  libsqlite3-dev libncurses-dev libffi-dev liblzma-dev
  libxml2-dev libxmlsec1-dev
  libclang-dev libopenblas-dev libsasl2-dev liburing-dev libzzip-dev
  libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev
  google-perftools
  tk-dev xz-utils
  fonts-inconsolata fonts-powerline fonts-dejavu fontconfig
  gimp evince libreoffice vlc
  libfido2-1 libu2f-udev
  virtualenvwrapper tree editorconfig xdg-utils
  tldr rsync whois zstd apache2-utils
  htop dfc earlyoom lm-sensors rasdaemon
  screen tmux parallel
  firefox
  thunderbird brave-browser google-chrome-stable openrazer-meta tailscale gh
  paretosecurity
)
if [ "$SKIP_DOCKER" != "1" ]; then
  ALL_PKGS+=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
fi
if [ "$SKIP_1PASSWORD" != "1" ]; then
  ALL_PKGS+=(1password)
fi
sudo apt-get install "${APT_OPTS[@]}" "${ALL_PKGS[@]}"
if [ "$SKIP_DOCKER" != "1" ]; then
  sudo usermod -aG docker "$USER"
fi
# video group: required for brightnessctl to write to /sys/class/backlight/*/brightness
# render group: required for GPU compute access (/dev/dri/renderD*)
for grp in video render; do
  if ! id -nG "$USER" | grep -qw "$grp"; then
    sudo usermod -aG "$grp" "$USER"
  fi
done
ok "System packages"

# ── Purge residual docker.io (triggers Pareto Security false positive) ──
if dpkg-query -W docker.io &>/dev/null; then
    sudo dpkg --purge docker.io 2>/dev/null || true
    ok "Purged residual docker.io from dpkg database"
fi

# ── Pareto Security service ──────────────────────────────────────────────
sudo systemctl enable paretosecurity.socket
ok "Pareto Security"

# ── UFW Firewall (Pareto compliance) ─────────────────────────────────────
info "Configuring UFW firewall..."
# UFW defaults: deny incoming, allow outgoing. Outgoing SSH to servers always works.
# Only uncomment the next line if others need to SSH INTO this laptop:
# sudo ufw allow OpenSSH
sudo ufw --force enable
ok "UFW firewall (deny incoming, allow outgoing)"

# ── Kernel hardening (sysctl) ────────────────────────────────────────────
info "Applying kernel hardening..."
for conf in "${DOT_DIR}/restore/etc/sysctl.d/"*.conf; do
    [[ -f "$conf" && ! -L "$conf" ]] || continue
    sudo install -m 644 "$conf" "/etc/sysctl.d/$(basename "$conf")"
done
sudo sysctl --system > /dev/null 2>&1
ok "Kernel hardening (sysctl)"

# ── Claude Code ────────────────────────────────────────────────────────────
if [ "$SKIP_AI_TOOLS" != "1" ]; then
  if ! command -v claude &>/dev/null; then
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code"
  fi

  if ! command -v opencode &>/dev/null; then
    info "Installing opencode..."
    curl -fsSL https://opencode.ai/install | bash
    ok "opencode"
  fi
fi

# ── Symlinks ───────────────────────────────────────────────────────────────
info "Creating symlinks..."
for file in Xresources gitconfig i3 i3status.conf vim vimrc zshrc; do
    target="${HOME}/.${file}"
    src="${DOT_DIR}/${file}"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        err "$target exists and is not a symlink, skipping"; continue
    fi
    ln -sf "$src" "$target"
    ok "$target"
done

mkdir -p ~/.ssh && chmod 700 ~/.ssh
ln -sf "${DOT_DIR}/ssh_config" ~/.ssh/config
chmod 600 "${DOT_DIR}/ssh_config"
ok "$HOME/.ssh/config"

mkdir -p ~/.config/alacritty
ln -sf "${DOT_DIR}/alacritty.toml" ~/.config/alacritty/alacritty.toml
ok "$HOME/.config/alacritty/alacritty.toml"

mkdir -p ~/.config/fontconfig
ln -sf "${DOT_DIR}/fontconfig/fonts.conf" ~/.config/fontconfig/fonts.conf
ok "$HOME/.config/fontconfig/fonts.conf"

mkdir -p ~/.config/rofi ~/.config/picom ~/.config/dunst ~/.config/i3status-rust
ln -sf "${DOT_DIR}/rofi/config.rasi" ~/.config/rofi/config.rasi
ln -sf "${DOT_DIR}/picom/picom.conf" ~/.config/picom/picom.conf
ln -sf "${DOT_DIR}/dunst/dunstrc" ~/.config/dunst/dunstrc
ln -sf "${DOT_DIR}/i3status-rust/config.toml" ~/.config/i3status-rust/config.toml
ok "rofi/picom/dunst/i3status-rust configs"

# ── Udev rules ────────────────────────────────────────────────────────────
info "Installing udev rules..."
UDEV_CHANGED=0
for rule in "${DOT_DIR}/udev/"*.rules; do
  dest="/etc/udev/rules.d/$(basename "$rule")"
  if ! sudo diff -q "$rule" "$dest" &>/dev/null; then
    sudo cp "$rule" "$dest"
    UDEV_CHANGED=1
  fi
done
if [ "$UDEV_CHANGED" = "1" ]; then
  sudo udevadm control --reload-rules 2>/dev/null || true
  sudo udevadm trigger --subsystem-match=hidraw 2>/dev/null || true
fi
ok "Udev rules"

# ── Input device configuration (ZBook Ultra G1a) ─────────────────────────
PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [[ "$PRODUCT_NAME" == *"ZBook Ultra G1a"* ]]; then
    info "Configuring input devices (ZBook Ultra G1a)..."

    # Touchpad: tap-to-click, clickfinger, drag lock
    sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null << 'XORG'
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "TappingDragLock" "on"
    Option "NaturalScrolling" "off"
    Option "ClickMethod" "clickfinger"
EndSection
XORG
    ok "Touchpad config (30-touchpad.conf)"

    # Keyboard: Caps Lock as Ctrl, Right Alt as Compose
    sudo sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS="ctrl:nocaps,compose:ralt"/' /etc/default/keyboard
    sudo dpkg-reconfigure -f noninteractive keyboard-configuration
    ok "Keyboard XKB options (ctrl:nocaps, compose:ralt)"

    # Trackpad gestures: fusuma (fires mid-gesture, snappier than libinput-gestures)
    sudo apt-get install "${APT_OPTS[@]}" libinput-tools ruby xdotool
    sudo gpasswd -a "$USER" input
    source "${DOT_DIR}/nuggets/utilities/fusuma.sh"
    mkdir -p "${HOME}/.config/fusuma"
    cat > "${HOME}/.config/fusuma/config.yml" << 'GESTURES'
swipe:
  3:
    left:
      command: 'i3-msg workspace prev'
    right:
      command: 'i3-msg workspace next'
    up:
      command: 'i3-msg fullscreen enable'
    down:
      command: 'i3-msg fullscreen disable'
  4:
    left:
      command: 'i3-msg move container to workspace prev, workspace prev'
    right:
      command: 'i3-msg move container to workspace next, workspace next'

pinch:
  in:
    command: 'xdotool key --delay 0 ctrl+minus'
  out:
    command: 'xdotool key --delay 0 ctrl+plus'

threshold:
  swipe: 0.3
  pinch: 0.1

interval:
  swipe: 0.7
  pinch: 0.5
GESTURES
    ok "Trackpad gestures (fusuma)"

    # Power saver: GPU low-power + CPU min freq toggle (AC/battery auto-switch)
    sudo install -m 755 "${DOT_DIR}/nuggets/utilities/cool-ryzen-apply.sh" /usr/local/bin/cool-ryzen-apply
    printf '%s ALL=(root) NOPASSWD: /usr/local/bin/cool-ryzen-apply *\n' "$USER" \
        > /tmp/cool-ryzen-sudoers
    if sudo visudo -cf /tmp/cool-ryzen-sudoers &>/dev/null; then
        sudo install -m 440 /tmp/cool-ryzen-sudoers /etc/sudoers.d/cool-ryzen
    fi
    rm -f /tmp/cool-ryzen-sudoers
    ok "Power saver toggle (cool-ryzen)"

    # PD cycling diagnostic (real-time power supply state monitor)
    ln -sf "${DOT_DIR}/power-monitor.py" "${HOME}/.local/bin/power-monitor"
    chmod +x "${DOT_DIR}/power-monitor.py"

    # Webcam: AMD ISP4 requires libcamera (media-controller pipeline, not raw V4L2).
    # USB cameras use V4L2. Per-device WirePlumber routing prevents:
    #   - V4L2 device probe crash with AMD ISP on PipeWire 1.0.5
    #   - libcamera duplicate of USB cameras
    # NOTE: PipeWire's SPA plugin links against libcamera 0.2, but the ISP4 handler
    # only matches kernel 6.17's driver in libcamera 0.3. Built-in camera won't appear
    # in PipeWire until HP OEM repo or AMD PPA ships a SPA plugin linked against 0.3.
    if ! has_repo /etc/apt/sources.list.d/amd-team-ubuntu-isp-noble.sources; then
        info "Adding AMD ISP PPA..."
        sudo add-apt-repository -y ppa:amd-team/isp
    fi
    sudo apt-get install "${APT_OPTS[@]}" libspa-0.2-libcamera libcamera-tools
    ok "Webcam (AMD ISP4 via libcamera + USB via V4L2)"

    # WirePlumber: per-device camera routing + mic priorities
    mkdir -p ~/.config/wireplumber/main.lua.d
    rm -f ~/.config/wireplumber/main.lua.d/51-disable-libcamera.lua
    cat > ~/.config/wireplumber/main.lua.d/51-camera-routing.lua << 'WPCONF'
-- Per-device camera routing for PipeWire 1.0.5 + WirePlumber 0.4.17
-- AMD ISP (built-in): libcamera only — V4L2 probe crashes PipeWire 1.0.5
-- USB cameras:        V4L2 only    — libcamera creates duplicates
-- TODO: revisit when PipeWire is updated past 1.0.5

table.insert(v4l2_monitor.rules, {
  matches = {
    {
      { "device.name", "matches", "v4l2_device.*amd_isp*" },
    },
  },
  apply_properties = {
    ["device.disabled"] = true,
  },
})

table.insert(libcamera_monitor.rules, {
  matches = {
    {
      { "node.name", "matches", "libcamera_input.*1532*" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  },
})
WPCONF
    ok "Camera routing (AMD ISP→libcamera, USB→V4L2)"
    cat > ~/.config/wireplumber/main.lua.d/52-mic-priorities.lua << 'WPCONF'
table.insert(alsa_monitor.rules, {
  matches = {
    {
      { "node.name", "equals", "alsa_input.pci-0000_c3_00.6.HiFi__Mic2__source" },
    },
  },
  apply_properties = {
    ["priority.driver"] = 3000,
    ["priority.session"] = 3000,
  },
})

table.insert(alsa_monitor.rules, {
  matches = {
    {
      { "node.name", "equals", "alsa_input.usb-Alpha_Imaging_Tech._Corp._Razer_Kiyo-02.analog-stereo" },
    },
  },
  apply_properties = {
    ["priority.driver"] = 2500,
    ["priority.session"] = 2500,
  },
})
WPCONF
    ok "Mic priorities (headphone jack > USB mic > built-in)"

    # Kernel parameters: amd_pstate pcie_aspm amd_iommu dcdebugmask + unified memory (TTM)
    # Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525
    # Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html
    info "Configuring kernel parameters (ZBook Ultra G1a)..."
    GRUB_CHANGED=0
    for kp in "amd_pstate=active" "pcie_aspm=off" "amd_iommu=off" "amdgpu.dcdebugmask=0x410" "amdgpu.cwsr_enable=0" "ttm.pages_limit=32505856" "ttm.page_pool_size=32505856"; do
        param_name="${kp%%=*}"
        normalized="${param_name//-/_}"
        if ! grep -qP "GRUB_CMDLINE_LINUX_DEFAULT=.*${normalized}[= \"]" /etc/default/grub 2>/dev/null &&
           ! grep -qP "GRUB_CMDLINE_LINUX_DEFAULT=.*${param_name}[= \"]" /etc/default/grub 2>/dev/null; then
            sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${kp}\"/" /etc/default/grub
            GRUB_CHANGED=1
        fi
    done
    sudo sed -i 's/  \+/ /g; s/" /"/; s/ "/"/g' /etc/default/grub
    if [[ "$GRUB_CHANGED" == "1" ]]; then
        sudo update-grub
    fi
    ok "Kernel parameters (amd_pstate pcie_aspm amd_iommu dcdebugmask cwsr_enable ttm.pages_limit ttm.page_pool_size)"

    # ROCm (Ryzen APU path — uses inbox kernel driver, no DKMS)
    # Ref: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-ryzen.html
    if [ "$SKIP_ROCM" != "1" ]; then
        info "Installing ROCm (Ryzen APU path)..."
        wget -q "https://repo.radeon.com/amdgpu-install/7.2.1/ubuntu/noble/amdgpu-install_7.2.1.70201-1_all.deb" \
            -O /tmp/amdgpu-install.deb
        sudo apt-get install "${APT_OPTS[@]}" /tmp/amdgpu-install.deb
        rm -f /tmp/amdgpu-install.deb
        sudo apt-get update
        amdgpu-install -y --usecase=rocm --no-dkms
        ok "ROCm (Ryzen APU)"

        # amd-debug-tools: provides amd-ttm for shared memory config
        # Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html
        if ! command -v pipx &>/dev/null; then
            sudo apt-get install "${APT_OPTS[@]}" pipx
        fi
        pipx install amd-debug-tools 2>/dev/null || pipx upgrade amd-debug-tools 2>/dev/null || true
        pipx ensurepath
        ok "amd-debug-tools (amd-ttm)"
    fi

    # WiFi suspend/resume: MT7925 driver timeout -110 after suspend (Ubuntu #2141198)
    info "Installing WiFi suspend services (MT7925)..."
    sudo tee /etc/systemd/system/wifi-pre-suspend.service > /dev/null << 'SVC'
[Unit]
Description=Unload MT7925 WiFi before suspend
Before=sleep.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r mt7925e
[Install]
WantedBy=sleep.target
SVC

    sudo tee /etc/systemd/system/wifi-suspend-fix.service > /dev/null << 'SVC'
[Unit]
Description=Reload MT7925 WiFi after suspend
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe mt7925e
[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
SVC

    sudo systemctl daemon-reload
    sudo systemctl enable wifi-pre-suspend.service wifi-suspend-fix.service
    ok "WiFi suspend services (mt7925e unload/reload)"
fi

# ── LUKS recovery reminder (interactive — cannot be automated) ────────────
if lsblk -rf 2>/dev/null | grep -q crypto_LUKS; then
    echo ""
    info "LUKS recovery setup (manual steps):"
    echo "  1. Add recovery keyslot:  sudo cryptsetup luksAddKey --key-slot 1 /dev/nvme0n1p3"
    echo "  2. Test recovery key:     sudo cryptsetup open --test-passphrase --key-slot 1 --verbose /dev/nvme0n1p3"
    echo "  3. Back up LUKS header:   sudo cryptsetup luksHeaderBackup /dev/nvme0n1p3 --header-backup-file luks-header.img"
    echo "  4. Encrypt backup:        gpg --symmetric --cipher-algo AES256 luks-header.img && shred -u luks-header.img"
    echo "  5. Store .gpg off-device  (USB drive, cloud, etc.)"
fi

# ── Shell setup ────────────────────────────────────────────────────────────
info "Setting up zsh..."
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
    sudo usermod --shell "$(command -v zsh)" "$USER"
fi

P10K_DIR="${HOME}/.zsh/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    mkdir -p "${HOME}/.zsh"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi
ok "Zsh + Powerlevel10k"

# ── IBus (hide tray icon — single layout, no need for indicator) ──────
gsettings set org.freedesktop.ibus.panel show-icon-on-systray false
ok "IBus tray icon hidden"

# ── Fonts ──────────────────────────────────────────────────────────────────
info "Installing fonts..."
FONTS_CHANGED=0
mkdir -p ~/.local/share/fonts

for f in "${DOT_DIR}/fonts/"*; do
  dest="${HOME}/.local/share/fonts/$(basename "$f")"
  if [ ! -f "$dest" ] || ! diff -q "$f" "$dest" &>/dev/null; then
    cp "$f" "$dest"
    FONTS_CHANGED=1
  fi
done

# Powerline-patched fonts (provides "Inconsolata for Powerline" etc.)
if [ ! -f "${HOME}/.local/share/fonts/Inconsolata for Powerline.otf" ]; then
  POWERLINE_FONTS_DIR=$(mktemp -d)
  git clone --depth=1 https://github.com/powerline/fonts.git "$POWERLINE_FONTS_DIR"
  "$POWERLINE_FONTS_DIR/install.sh"
  rm -rf "$POWERLINE_FONTS_DIR"
  FONTS_CHANGED=1
fi

# MesloLGS NF – recommended font for Powerlevel10k
MESLO_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
for variant in Regular Bold Italic "Bold Italic"; do
  file="MesloLGS NF ${variant}.ttf"
  if [ ! -f "${HOME}/.local/share/fonts/${file}" ]; then
    curl -fsSL -o "${HOME}/.local/share/fonts/${file}" \
      "${MESLO_URL}/$(printf '%s' "$file" | sed 's/ /%20/g')"
    FONTS_CHANGED=1
  fi
done

if [ "$FONTS_CHANGED" = "1" ]; then
  fc-cache -f
fi
ok "Fonts"

# ── Language toolchains ────────────────────────────────────────────────────
info "Installing language toolchains..."
mkdir -p ~/.local/bin ~/.config/nvim/backups ~/.virtualenvs
(cd "${DOT_DIR}" && bash ./update.sh)
ok "Toolchains"

# ── Neovim setup ───────────────────────────────────────────────────────────
info "Setting up Neovim..."
ln -sf "${DOT_DIR}/vimrc" "${HOME}/.config/nvim/init.vim"
PLUG_VIM="${HOME}/.local/share/nvim/site/autoload/plug.vim"
if [ ! -f "$PLUG_VIM" ]; then
  curl -fLo "$PLUG_VIM" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if [ ! -d ~/.virtualenvs/neovim3 ]; then
    python3 -m venv ~/.virtualenvs/neovim3
fi
~/.virtualenvs/neovim3/bin/pip install --quiet --upgrade pynvim ruff black pyright

nvim --headless +'PlugInstall --sync' +qa 2>/dev/null || true
nvim --headless '+TSInstallSync! svelte typescript html css javascript python rust yaml json bash make lua toml' +qa 2>/dev/null || true
ok "Neovim"

echo ""
info "Done! Log out and back in for zsh and docker group to take effect."
