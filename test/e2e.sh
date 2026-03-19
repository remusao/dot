#!/usr/bin/env bash
set -euo pipefail
source ~/.dot/lock.sh
export PATH="${HOME}/.local/bin:${HOME}/.pyenv/bin:${PATH}"

SKIP_SNAP=${DOTFILES_SKIP_SNAP:-0}
SKIP_DOCKER=${DOTFILES_SKIP_DOCKER:-0}
SKIP_1PASSWORD=${DOTFILES_SKIP_1PASSWORD:-0}
SKIP_AI_TOOLS=${DOTFILES_SKIP_AI_TOOLS:-0}
SKIP_FIREJAIL=${DOTFILES_SKIP_FIREJAIL:-0}

PASS=0 FAIL=0 SKIP=0
check() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    printf "  \033[32m✓\033[0m %s\n" "$desc"; PASS=$((PASS + 1))
  else
    printf "  \033[31m✗\033[0m %s\n" "$desc"; FAIL=$((FAIL + 1))
  fi
}

skip() {
  local desc="$1"
  printf "  \033[33m⊘\033[0m %s (skipped)\n" "$desc"; SKIP=$((SKIP + 1))
}

section() { printf "\n\033[1;34m--- %s ---\033[0m\n" "$1"; }

echo ""
echo "=============================="
echo "  Dotfiles E2E Test Suite"
echo "=============================="

# ─── SYMLINKS ────────────────────────────────────────────
section "Symlinks"
for f in .zshrc .vimrc .vim .gitconfig .i3 .i3status.conf .Xresources; do
  check "~/$f is symlink" test -L "$HOME/$f"
  check "~/$f target exists" test -e "$HOME/$f"
done
check "~/.ssh/config is symlink" test -L "$HOME/.ssh/config"
check "~/.ssh/config perms" test "$(stat -c %a "$HOME/.dot/ssh_config")" = "600"
check "~/.ssh dir perms" test "$(stat -c %a "$HOME/.ssh")" = "700"
check "fontconfig symlink" test -L "$HOME/.config/fontconfig/fonts.conf"

check "no ~/.config symlink" test ! -L "$HOME/.config"
check "no ~/.hgrc symlink" test ! -L "$HOME/.hgrc"
check "no ~/.emacs symlink" test ! -L "$HOME/.emacs"

# ─── SHELL ───────────────────────────────────────────────
section "Shell"
check "zsh is default shell" test "$(getent passwd "$USER" | cut -d: -f7)" = "$(which zsh)"
check "powerlevel10k cloned" test -d "$HOME/.zsh/powerlevel10k"
check "powerlevel10k theme file" test -f "$HOME/.zsh/powerlevel10k/powerlevel10k.zsh-theme"
check "zsh-syntax-highlighting" test -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
check "virtualenvwrapper" test -f /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh

# ─── APT CORE PACKAGES ──────────────────────────────────
section "Apt packages: core tools"
for cmd in zsh git curl wget cmake ninja unzip; do
  check "$cmd" command -v "$cmd"
done
check "git-lfs" git lfs version
check "git-lfs hooks" bash -c "git lfs env | grep -q 'git config filter.lfs'"

section "Apt packages: desktop & i3"
for cmd in i3 i3lock i3status rofi feh; do
  check "$cmd" command -v "$cmd"
done
for cmd in pamixer brightnessctl maim playerctl xss-lock picom gammastep autorandr dunst; do
  check "$cmd" command -v "$cmd"
done
check "gnome-keyring" dpkg -s gnome-keyring
check "policykit-1-gnome" dpkg -s policykit-1-gnome
check "video group" bash -c "id -nG '$USER' | grep -qw video"

section "Apt packages: terminal & shell tools"
for cmd in fzf fdfind shellcheck keychain xclip; do
  check "$cmd" command -v "$cmd"
done

section "Apt packages: dev tools"
for cmd in python3 cmake gcc g++; do
  check "$cmd" command -v "$cmd"
done
check "python3-dev" dpkg -s python3-dev
check "python3-venv" dpkg -s python3-venv
check "libboost-dev" dpkg -s libboost-all-dev

section "Apt packages: pyenv build deps"
for pkg in libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
           libncurses-dev libffi-dev liblzma-dev libxml2-dev libxmlsec1-dev \
           tk-dev xz-utils; do
  check "$pkg" dpkg -s "$pkg"
done

section "Apt packages: CLI tools"
for cmd in tldr rsync whois zstd tree editorconfig restic; do
  check "$cmd" command -v "$cmd"
done

# ─── PPA PACKAGES ────────────────────────────────────────
section "PPA packages"
if [ "$SKIP_SNAP" != "1" ]; then
  check "firefox (not snap)" ! snap list firefox
  check "thunderbird (not snap)" ! snap list thunderbird
else
  skip "firefox (not snap)"
  skip "thunderbird (not snap)"
fi
check "firefox (deb)" dpkg -s firefox
check "firefox binary" command -v firefox
check "firefox pin exists" test -f /etc/apt/preferences.d/mozilla
check "firefox snap pin" test -f /etc/apt/preferences.d/firefox-no-snap

check "brave-browser" dpkg -s brave-browser
check "thunderbird" dpkg -s thunderbird
check "tailscale" dpkg -s tailscale

if [ "$SKIP_DOCKER" != "1" ]; then
  check "docker-ce" dpkg -s docker-ce
  check "docker compose plugin" docker compose version
  check "docker group" bash -c "id -nG '$USER' | grep -qw docker"
else
  skip "docker-ce"
  skip "docker compose plugin"
  skip "docker group"
fi

if [ "$SKIP_1PASSWORD" != "1" ]; then
  check "1password" dpkg -s 1password
else
  skip "1password"
fi

# ─── NEOVIM ──────────────────────────────────────────────
section "Neovim"
check "nvim installed" command -v nvim
check "nvim version ${NEOVIM_VERSION}" bash -c "nvim --version | head -1 | grep -q '${NEOVIM_VERSION}'"
check "nvim from ~/.local/bin" test -x "$HOME/.local/bin/nvim"
check "vim-plug installed" test -f "$HOME/.local/share/nvim/site/autoload/plug.vim"
check "nvim undo dir" test -d "$HOME/.config/nvim/backups"
check "nvim init.vim" test -L "$HOME/.config/nvim/init.vim"

section "Neovim Python provider"
check "neovim3 venv exists" test -d "$HOME/.virtualenvs/neovim3"
check "neovim3 python" test -x "$HOME/.virtualenvs/neovim3/bin/python"
check "pynvim installed" "$HOME/.virtualenvs/neovim3/bin/python" -c "import pynvim"
check "ruff installed" test -x "$HOME/.virtualenvs/neovim3/bin/ruff"
check "black installed" test -x "$HOME/.virtualenvs/neovim3/bin/black"
check "pyright installed" test -x "$HOME/.virtualenvs/neovim3/bin/pyright"

# ─── VERSION MANAGERS ────────────────────────────────────
section "pyenv + Python"
check "pyenv dir" test -d "$HOME/.pyenv"
check "pyenv binary" "$HOME/.pyenv/bin/pyenv" --version
check "python ${PYTHON_VERSION}" test -d "$HOME/.pyenv/versions/${PYTHON_VERSION}"
check "python binary" "$HOME/.pyenv/versions/${PYTHON_VERSION}/bin/python3" --version

section "nvm + Node.js"
check "nvm dir" test -d "$HOME/.nvm"
check "nvm script" test -f "$HOME/.nvm/nvm.sh"
check "node ${NODEJS_VERSION}" test -x "$HOME/.nvm/versions/node/v${NODEJS_VERSION}/bin/node"
check "npm" test -x "$HOME/.nvm/versions/node/v${NODEJS_VERSION}/bin/npm"

# ─── RUST ────────────────────────────────────────────────
section "Rust toolchain"
check "rustup" "$HOME/.cargo/bin/rustup" --version
check "cargo" "$HOME/.cargo/bin/cargo" --version
check "rust stable" bash -c "'${HOME}/.cargo/bin/rustup' toolchain list | grep -q stable"
check "rust-src" bash -c "'${HOME}/.cargo/bin/rustup' component list --installed | grep -q rust-src"
check "sccache ${SCCACHE_VERSION}" bash -c "'${HOME}/.cargo/bin/sccache' --version | grep -q '${SCCACHE_VERSION}'"
check "ripgrep ${RIPGREP_VERSION}" bash -c "'${HOME}/.cargo/bin/rg' --version | head -1 | grep -q '${RIPGREP_VERSION}'"
check "ripgrep pcre2" "$HOME/.cargo/bin/rg" --pcre2-version

# ─── DOCKER TOOLS ────────────────────────────────────────
section "Docker tools"
check "hadolint" "$HOME/.local/bin/hadolint" --version

# ─── FONTS ───────────────────────────────────────────────
section "Fonts"
check "fonts dir" test -d "$HOME/.local/share/fonts"
check "Inconsolata Powerline" test -f "$HOME/.local/share/fonts/Inconsolata-dz-Powerline.otf"
check "font cache" bash -c "fc-list | grep -qi inconsolata"
check "MesloLGS NF" bash -c "fc-list | grep -qi 'MesloLGS NF'"

# ─── NPM PACKAGES ───────────────────────────────────────
section "npm global packages"
NODE_BIN="$HOME/.nvm/versions/node/v${NODEJS_VERSION}/bin"
for pkg in bash-language-server prettier yaml-language-server svgo stylelint; do
  check "npm: $pkg" test -x "$NODE_BIN/$pkg" -o -f "$NODE_BIN/$pkg"
done
check "npm: typescript" test -x "$NODE_BIN/tsc"
check "npm: svelte-language-server" test -x "$NODE_BIN/svelteserver"
check "npm: dockerfile-language-server-nodejs" test -x "$NODE_BIN/docker-langserver"

# ─── CLAUDE & OPENCODE ──────────────────────────────────
section "AI tools"
if [ "$SKIP_AI_TOOLS" != "1" ]; then
  check "claude" command -v claude
  check "opencode" command -v opencode
else
  skip "claude"
  skip "opencode"
fi

# ─── HARDWARE & SECURITY ──────────────────────────────────
section "Hardware & security"
check "titan-key udev" test -f /etc/udev/rules.d/70-titan-key.rules
check "libfido2" dpkg -s libfido2-1
check "libu2f-udev" dpkg -s libu2f-udev

# ─── ZBOOK ULTRA G1A ─────────────────────────────────────
PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [[ "$PRODUCT_NAME" == *"ZBook Ultra G1a"* ]]; then
  section "ZBook Ultra G1a"
  check "cool-ryzen-apply installed" test -x /usr/local/bin/cool-ryzen-apply
  check "cool-ryzen sudoers" test -f /etc/sudoers.d/cool-ryzen
  check "cool-ryzen udev rule" test -f /etc/udev/rules.d/85-cool-ryzen-ac.rules
  check "i3 power saver keybinding" grep -q 'cool-ryzen' "$HOME/.dot/i3/config"
fi

# ─── FIREJAIL ─────────────────────────────────────────────
if [ "$SKIP_FIREJAIL" != "1" ]; then
  section "Firejail"
  check "firejail" command -v firejail
  check "firejail wrapper: chrome" test -x /usr/local/bin/chrome
  check "no stale firefox wrapper" test ! -f /usr/local/bin/firefox
  check "no stale thunderbird wrapper" test ! -f /usr/local/bin/thunderbird
  check "no stale brave wrapper" test ! -f /usr/local/bin/brave.bkp
else
  skip "firejail"
fi

# ─── ADDITIONAL PACKAGES ─────────────────────────────────
section "Additional packages"
check "gh" command -v gh
check "google-chrome" dpkg -s google-chrome-stable
check "obsidian" dpkg -s obsidian

# ─── CONFIG SANITY CHECKS ───────────────────────────────
section "Config sanity"
check "ssh_config: no UseRoaming" bash -c '! grep -q "UseRoaming" "$HOME/.dot/ssh_config"'
check "ssh_config: no ssh-rsa" bash -c '! grep -q "ssh-rsa" "$HOME/.dot/ssh_config"'
check "ssh_config: KbdInteractive" grep -q "KbdInteractiveAuthentication" "$HOME/.dot/ssh_config"
check "i3/config: brightnessctl" grep -q "brightnessctl" "$HOME/.dot/i3/config"
check "i3/config: no xbacklight" bash -c '! grep -q "xbacklight" "$HOME/.dot/i3/config"'
check "i3/config: playerctl" grep -q "playerctl" "$HOME/.dot/i3/config"
check "i3/config: xss-lock" grep -q "xss-lock" "$HOME/.dot/i3/config"
check "i3/config: mic mute" grep -q "XF86AudioMicMute" "$HOME/.dot/i3/config"
check "i3/config: no dbus-send spotify" bash -c '! grep -q "org.mpris.MediaPlayer2.spotify" "$HOME/.dot/i3/config"'
check "i3/config: AMD output names" bash -c '! grep -q "output HDMI2\|output eDP1" "$HOME/.dot/i3/config"'
check "i3/config: no deprecated new_window" bash -c '! grep -q "new_window" "$HOME/.dot/i3/config"'
check "i3/config: no redshift" bash -c '! grep -q "redshift" "$HOME/.dot/i3/config"'
check "i3/config: no scrot" bash -c '! grep -q "scrot" "$HOME/.dot/i3/config"'
check "i3/config: i3status-rs" grep -q "i3status-rs" "$HOME/.dot/i3/config"
check "i3/config: no pasystray" bash -c '! grep -q "pasystray" "$HOME/.dot/i3/config"'
check "i3status-rs" command -v i3status-rs
check "greenclip" command -v greenclip
check "Font Awesome 6" bash -c "fc-list | grep -qi 'Font Awesome 6'"
check "zshrc: python3 for venvwrapper" grep -q "VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3" "$HOME/.dot/zshrc"
check "zshrc: no spark PATH" bash -c '! grep -q "spark-1.6.1" "$HOME/.dot/zshrc"'
check "zshrc: no ruby 2.5 PATH" bash -c '! grep -q "ruby/2.5.0" "$HOME/.dot/zshrc"'
check "zshrc: no Nim PATH" bash -c '! grep -q "Nim/bin" "$HOME/.dot/zshrc"'
check "lock.sh: NVM_VERSION" grep -q "NVM_VERSION" "$HOME/.dot/lock.sh"
check "lock.sh: no KEEPASSXC" bash -c '! grep -q "^export KEEPASSXC" "$HOME/.dot/lock.sh"'
check "packages.sh: no tslint" bash -c '! grep -q "tslint" "$HOME/.dot/nuggets/javascript/packages.sh"'
check "no keepassxc.sh" test ! -f "$HOME/.dot/nuggets/utilities/keepassxc.sh"
check "no docker-compose.sh" test ! -f "$HOME/.dot/nuggets/docker/docker-compose.sh"

# ─── RESULTS ─────────────────────────────────────────────
echo ""
echo "=============================="
printf "  \033[1m%d passed, %d failed, %d skipped\033[0m\n" "$PASS" "$FAIL" "$SKIP"
echo "=============================="
if [ "$FAIL" -eq 0 ]; then
  printf "\n  \033[1;32mALL TESTS PASSED\033[0m\n\n"
else
  printf "\n  \033[1;31mSOME TESTS FAILED\033[0m\n\n"
  exit 1
fi
