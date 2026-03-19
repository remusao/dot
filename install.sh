#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run as root. Run as your normal user (sudo is used internally)." >&2
  exit 1
fi

USER="${USER:-$(whoami)}"
DOT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
SKIP_FIREJAIL=${DOTFILES_SKIP_FIREJAIL:-0}

# ── i3 (latest release) ──────────────────────────────────────────────────
info "Adding i3 official repo..."
curl -fsSL "https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2025.12.14_all.deb" \
  -o /tmp/sur5r-keyring.deb
sudo apt-get install "${APT_OPTS[@]}" /tmp/sur5r-keyring.deb
rm -f /tmp/sur5r-keyring.deb
echo "deb [signed-by=/usr/share/keyrings/sur5r-keyring.gpg] http://debian.sur5r.net/i3/ $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") universe" \
  | sudo tee /etc/apt/sources.list.d/sur5r-i3.list > /dev/null

# ── Core apt packages ──────────────────────────────────────────────────────
info "Installing system packages..."
sudo apt-get update
sudo apt-get install "${APT_OPTS[@]}" \
  ca-certificates curl gnupg lsb-release software-properties-common wget \
  zsh git git-lfs build-essential cmake ninja-build gettext unzip \
  python3-pip python3-venv python3-dev \
  rxvt-unicode \
  i3 i3lock i3status rofi redshift feh \
  pamixer pulseaudio-utils brightnessctl \
  scrot gnome-screenshot \
  network-manager-gnome pasystray gnome-keyring \
  x11-xserver-utils x11-xkb-utils \
  zsh-syntax-highlighting keychain fzf fd-find shellcheck \
  xclip \
  libboost-all-dev libzstd-dev \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev libncurses-dev libffi-dev liblzma-dev \
  libxml2-dev libxmlsec1-dev \
  tk-dev xz-utils \
  fonts-inconsolata fonts-powerline fonts-dejavu fontconfig \
  gimp evince libreoffice vlc \
  libfido2-1 libu2f-udev \
  virtualenvwrapper tree editorconfig xdg-utils \
  tldr rsync whois zstd apache2-utils \
  htop dfc earlyoom \
  screen tmux parallel
ok "System packages"

# ── Firefox snap → deb ─────────────────────────────────────────────────────
info "Replacing Firefox snap with deb..."

sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
  | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
  | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
printf 'Package: firefox*\nPin: release o=Ubuntu*\nPin-Priority: -1\n' \
  | sudo tee /etc/apt/preferences.d/firefox-no-snap > /dev/null

if [ "$SKIP_SNAP" != "1" ]; then
  sudo systemctl stop var-snap-firefox-common-host-hunspell.mount 2>/dev/null || true
  sudo systemctl disable var-snap-firefox-common-host-hunspell.mount 2>/dev/null || true

  if snap list firefox &>/dev/null; then
    sudo snap remove --purge firefox
  fi
  sudo apt-get purge -y firefox 2>/dev/null || true
  sudo rm -f /var/lib/snapd/seed/snaps/firefox_*.snap
  sudo rm -f /var/lib/snapd/seed/assertions/firefox_*.assert
fi

sudo apt-get update
sudo apt-get install "${APT_OPTS[@]}" firefox
ok "Firefox (deb)"

# ── Thunderbird PPA ────────────────────────────────────────────────────────
info "Adding Thunderbird PPA..."
sudo add-apt-repository -y ppa:mozillateam/ppa
printf 'Package: thunderbird*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
  | sudo tee /etc/apt/preferences.d/mozillateam-ppa > /dev/null

# ── Brave Browser ──────────────────────────────────────────────────────────
info "Adding Brave Browser repo..."
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

# ── Google Chrome ─────────────────────────────────────────────────────
info "Adding Google Chrome repo..."
wget -q -O- https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor --output /usr/share/keyrings/google-chrome.gpg --yes
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null

# ── OpenRazer ─────────────────────────────────────────────────────────
info "Adding OpenRazer PPA..."
sudo add-apt-repository -y ppa:openrazer/stable

# ── Docker Engine ──────────────────────────────────────────────────────────
if [ "$SKIP_DOCKER" != "1" ]; then
  info "Adding Docker repo..."
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<SRCS
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
SRCS
fi

# ── 1Password ──────────────────────────────────────────────────────────────
if [ "$SKIP_1PASSWORD" != "1" ]; then
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
fi

# ── Tailscale ──────────────────────────────────────────────────────────────
info "Adding Tailscale repo..."
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.noarmor.gpg" \
  | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.tailscale-keyring.list" \
  | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null

# ── GitHub CLI ────────────────────────────────────────────────────────────
info "Adding GitHub CLI repo..."
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# ── Install PPA packages ──────────────────────────────────────────────────
info "Installing PPA packages..."
sudo apt-get update
PPA_PKGS=(thunderbird brave-browser google-chrome-stable openrazer-meta tailscale gh)
if [ "$SKIP_DOCKER" != "1" ]; then
  PPA_PKGS+=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
fi
if [ "$SKIP_1PASSWORD" != "1" ]; then
  PPA_PKGS+=(1password)
fi
sudo apt-get install "${APT_OPTS[@]}" "${PPA_PKGS[@]}"
if [ "$SKIP_DOCKER" != "1" ]; then
  sudo usermod -aG docker "$USER"
fi
ok "PPA packages"

# ── Claude Code ────────────────────────────────────────────────────────────
if [ "$SKIP_AI_TOOLS" != "1" ]; then
  info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
  ok "Claude Code"

  # ── opencode ───────────────────────────────────────────────────────────
  info "Installing opencode..."
  curl -fsSL https://opencode.ai/install | bash
  ok "opencode"
fi

# ── Symlinks ───────────────────────────────────────────────────────────────
info "Creating symlinks..."
for file in Xresources gitconfig i3 i3status.conf vim vimrc xinitrc zshrc; do
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
ok "~/.ssh/config"

# ── Git LFS ────────────────────────────────────────────────────────────────
git lfs install
ok "Git LFS"

# ── Udev rules ────────────────────────────────────────────────────────────
info "Installing udev rules..."
sudo cp "${DOT_DIR}/udev/"*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules 2>/dev/null || true
sudo udevadm trigger --subsystem-match=hidraw 2>/dev/null || true
ok "Udev rules (Titan key)"

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

# ── Fonts ──────────────────────────────────────────────────────────────────
info "Installing fonts..."
mkdir -p ~/.local/share/fonts
cp "${DOT_DIR}/fonts/"* ~/.local/share/fonts/

# Powerline-patched fonts (provides "Inconsolata for Powerline" etc.)
POWERLINE_FONTS_DIR=$(mktemp -d)
git clone --depth=1 https://github.com/powerline/fonts.git "$POWERLINE_FONTS_DIR"
"$POWERLINE_FONTS_DIR/install.sh"
rm -rf "$POWERLINE_FONTS_DIR"

# MesloLGS NF – recommended font for Powerlevel10k
MESLO_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
for variant in Regular Bold Italic "Bold Italic"; do
  file="MesloLGS NF ${variant}.ttf"
  [ -f "${HOME}/.local/share/fonts/${file}" ] || \
    curl -fsSL -o "${HOME}/.local/share/fonts/${file}" \
      "${MESLO_URL}/$(printf '%s' "$file" | sed 's/ /%20/g')"
done

fc-cache -f
ok "Fonts"

# ── Language toolchains ────────────────────────────────────────────────────
info "Installing language toolchains..."
mkdir -p ~/.local/bin ~/.config/nvim/backups ~/.virtualenvs
(cd "${DOT_DIR}" && bash ./update.sh)
ok "Toolchains"

# ── Neovim setup ───────────────────────────────────────────────────────────
info "Setting up Neovim..."
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

if [ ! -d ~/.virtualenvs/neovim3 ]; then
    python3 -m venv ~/.virtualenvs/neovim3
fi
~/.virtualenvs/neovim3/bin/pip install --quiet --upgrade pynvim ruff black pyright

nvim --headless +PlugInstall +qall 2>/dev/null || true
ok "Neovim"

echo ""
info "Done! Log out and back in for zsh and docker group to take effect."
