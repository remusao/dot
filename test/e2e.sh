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
for cmd in fzf shellcheck xclip; do
  check "$cmd" command -v "$cmd"
done
check "ssh-agent.service enabled" systemctl --user is-enabled ssh-agent.service

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
for cmd in tldr rsync whois zstd tree editorconfig; do
  check "$cmd" command -v "$cmd"
done

# ─── PPA PACKAGES ────────────────────────────────────────
section "PPA packages"
if [ "$SKIP_SNAP" != "1" ]; then
  check "firefox (not snap)" bash -c '! snap list firefox'
  check "thunderbird (not snap)" bash -c '! snap list thunderbird'
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
# No black: nothing installs or references it (ruff_format formats).
check "ruff installed" test -x "$HOME/.virtualenvs/neovim3/bin/ruff"
check "mypy installed" test -x "$HOME/.virtualenvs/neovim3/bin/mypy"
check "pyright installed" test -x "$HOME/.virtualenvs/neovim3/bin/pyright"
check "neovim3 venv on pinned python" bash -c "'$HOME/.virtualenvs/neovim3/bin/python' -V | grep -q '${PYTHON_VERSION}'"

# ─── VERSION MANAGERS ────────────────────────────────────
section "pyenv + Python"
check "pyenv dir" test -d "$HOME/.pyenv"
check "pyenv ${PYENV_RELEASE}" bash -c "'${HOME}/.pyenv/bin/pyenv' --version | grep -q '${PYENV_RELEASE#v}'"
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
check "~/.config/sccache/config is symlink" test -L "$HOME/.config/sccache/config"
check "~/.cargo/config.toml is symlink" test -L "$HOME/.cargo/config.toml"
# Server honours the config file rather than the stock 10G default. Size is
# read back out of the config so the two cannot drift.
check "sccache cache size from config" bash -c '
  want=$(sed -n "s/^size = \"\([0-9]*\)G\"$/\1 GiB/p" "$HOME/.config/sccache/config")
  [ -n "$want" ] && "$HOME/.cargo/bin/sccache" --show-stats | grep -q "Max cache size *$want"'
check "mold ${MOLD_VERSION}" bash -c "'${HOME}/.local/bin/mold' --version | grep -q '${MOLD_VERSION}'"
# cc-mold selects mold with -B<dir>, which needs a program named exactly `ld`.
check "mold ld alias" test -x "$HOME/.local/libexec/mold/ld"
check "~/.local/bin/cc-mold is symlink" test -L "$HOME/.local/bin/cc-mold"
# One throwaway crate proves both halves of the config at once: a bad relative
# program path in build.rustc-wrapper or linker fails at *runtime*, on every
# cargo command. `cargo config get` would answer that but is nightly-only. Env
# is stripped so this tests the config file, not an inherited RUSTC_WRAPPER.
# It needs both targets: a bin alone is `cannot_cache!("crate-type")`, so only
# the lib moves the sccache counter, and only the bin exercises the linker.
check "cargo routes rustc through sccache + mold" bash -c '
  executed() { "$HOME/.cargo/bin/sccache" --show-stats --stats-format=json |
    grep -o "\"requests_executed\":[0-9]*" | head -1; }
  d=$(mktemp -d) || exit 1
  trap "rm -rf \"$d\"" EXIT
  mkdir -p "$d/src"
  printf "[package]\nname=\"scccheck\"\nversion=\"0.0.0\"\nedition=\"2021\"\n" > "$d/Cargo.toml"
  printf "pub fn f() -> u8 { 1 }\n" > "$d/src/lib.rs"
  printf "fn main() { println!(\"{}\", scccheck::f()); }\n" > "$d/src/main.rs"
  before=$(executed)
  (cd "$d" && env -u RUSTC_WRAPPER CARGO_INCREMENTAL=0 "$HOME/.cargo/bin/cargo" build -q) || exit 1
  [ "$before" != "$(executed)" ] || exit 1
  "$d/target/debug/scccheck" >/dev/null || exit 1
  readelf -p .comment "$d/target/debug/scccheck" | grep -qi "mold"'
# cmake-rs drops the wrapper, so these are what cache aws-lc-sys/kenlm/keyvi/
# rdkafka-sys/sentencepiece-sys. Read from a real zsh: e2e.sh may run from a
# shell that never sourced zshrc.
check "zshrc exports cmake launchers" bash -c '
  zsh -ic "print -r -- \$CMAKE_C_COMPILER_LAUNCHER \$CMAKE_CXX_COMPILER_LAUNCHER" 2>/dev/null |
    grep -q "/\.cargo/bin/sccache /.*/\.cargo/bin/sccache$"'
check "ripgrep ${RIPGREP_VERSION}" bash -c "'${HOME}/.cargo/bin/rg' --version | head -1 | grep -q '${RIPGREP_VERSION}'"
check "ripgrep pcre2" "$HOME/.cargo/bin/rg" --pcre2-version

# ─── CLI TOOLS (binary downloads) ────────────────────────
section "CLI tools"
check "fd ${FD_VERSION}" bash -c "'${HOME}/.local/bin/fd' --version | grep -q '${FD_VERSION}'"
check "bat ${BAT_VERSION}" bash -c "'${HOME}/.local/bin/bat' --version | grep -q '${BAT_VERSION}'"
check "delta ${DELTA_VERSION}" bash -c "'${HOME}/.local/bin/delta' --version | grep -q '${DELTA_VERSION}'"
check "stylua ${STYLUA_VERSION}" bash -c "'${HOME}/.local/bin/stylua' --version | grep -q '${STYLUA_VERSION#v}'"
check "shfmt ${SHFMT_VERSION}" bash -c "'${HOME}/.local/bin/shfmt' --version | grep -q '${SHFMT_VERSION}'"
check "lazygit ${LAZYGIT_VERSION}" bash -c "'${HOME}/.local/bin/lazygit' --version | grep -q 'version=${LAZYGIT_VERSION},'"
check "git-lfs ${GIT_LFS_VERSION}" bash -c "'${HOME}/.local/bin/git-lfs' --version | grep -q '^git-lfs/${GIT_LFS_VERSION#v} '"
check "sops ${SOPS_VERSION}" bash -c "'${HOME}/.local/bin/sops' --version | head -1 | grep -q '${SOPS_VERSION#v}'"
check "aws-vault ${AWS_VAULT_VERSION}" bash -c "'${HOME}/.local/bin/aws-vault' --version 2>&1 | grep -qF '${AWS_VAULT_VERSION}'"
check "hyperfine ${HYPERFINE_VERSION}" bash -c "'${HOME}/.local/bin/hyperfine' --version | grep -q '${HYPERFINE_VERSION}'"
check "rclone ${DOTFILES_RCLONE_VERSION}" bash -c "'${HOME}/.local/bin/rclone' version | head -1 | grep -q '${DOTFILES_RCLONE_VERSION}'"
check "restic ${RESTIC_VERSION}" bash -c "'${HOME}/.local/bin/restic' version | grep -q '${RESTIC_VERSION}'"
check "cosign ${COSIGN_VERSION}" bash -c "'${HOME}/.local/bin/cosign' version --json | grep -q '${COSIGN_VERSION}'"
check "lua-language-server ${LUA_LANGUAGE_SERVER_VERSION}" bash -c "'${HOME}/.local/share/lua-language-server/bin/lua-language-server' --version | grep -q '${LUA_LANGUAGE_SERVER_VERSION}'"
# musl and glibc builds report the same version; only linkage tells them apart,
# and fd/bat have no ldd guard in their nugget to self-heal.
for b in fd bat delta stylua; do
  check "$b is glibc-linked" bash -c "ldd '${HOME}/.local/bin/$b' | grep -q 'libc\.so\.6'"
done

# ─── DOCKER TOOLS ────────────────────────────────────────
section "Docker tools"
check "hadolint ${HADOLINT_VERSION}" bash -c "'${HOME}/.local/bin/hadolint' --version | grep -q '${HADOLINT_VERSION#v}'"

# ─── FONTS ───────────────────────────────────────────────
section "Fonts"
check "fonts dir" test -d "$HOME/.local/share/fonts"
check "Inconsolata Powerline" test -f "$HOME/.local/share/fonts/Inconsolata-dz-Powerline.otf"
check "font cache" bash -c "fc-list | grep -qi inconsolata"
check "MesloLGS NF" bash -c "fc-list | grep -qi 'MesloLGS NF'"

# ─── NODE TOOLS ─────────────────────────────────────────
# Lockfile-pinned in ~/.local/bin, not nvm globals. The nvm-absence half matters:
# zshrc ranks nvm's bin dir first, so a leftover `npm -g` copy shadows these.
section "node tools (lockfile-pinned)"
for b in bash-language-server prettier yaml-language-server svgo stylelint \
  tsc svelteserver docker-langserver vtsls; do
  check "node tool: $b" test -x "$HOME/.local/bin/$b"
  check "node tool: $b not an nvm global" \
    test ! -e "$HOME/.nvm/versions/node/v${NODEJS_VERSION}/bin/$b"
done
# pyright deliberately the venv one: config_plugins.vim runs the server from there.
check "pyright (venv, not npm)" test -x "$HOME/.virtualenvs/neovim3/bin/pyright-langserver"

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
  check "i3 power saver keybinding" grep -q '~/.i3/cool-ryzen.sh' "$HOME/.dot/i3/config"
check "i3 auto-toggle keybinding" grep -q '~/.i3/cool-ryzen-auto-toggle.sh' "$HOME/.dot/i3/config"
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
check "obsidian ${OBSIDIAN_VERSION}" test "$(dpkg-query -W -f='${db:Status-Status} ${Version}' obsidian 2>/dev/null || true)" = "installed ${OBSIDIAN_VERSION}"

# ─── CONFIG SANITY CHECKS ───────────────────────────────
section "Config sanity"
check "ssh_config: no UseRoaming" bash -c '! grep -q "UseRoaming" "$HOME/.dot/ssh_config"'
check "ssh_config: no ssh-rsa" bash -c '! grep -q "ssh-rsa" "$HOME/.dot/ssh_config"'
check "ssh_config: KbdInteractive" grep -q "KbdInteractiveAuthentication" "$HOME/.dot/ssh_config"
check "i3: brightnessctl" grep -q "brightnessctl" "$HOME/.dot/i3/media-keys.sh"
check "i3/config: no xbacklight" bash -c '! grep -q "xbacklight" "$HOME/.dot/i3/config"'
check "i3/config: playerctl" grep -q "playerctl" "$HOME/.dot/i3/config"
check "i3/config: xss-lock" grep -q "xss-lock" "$HOME/.dot/i3/config"
check "i3/config: mic mute" grep -q "XF86AudioMicMute" "$HOME/.dot/i3/config"
check "i3/config: no dbus-send spotify" bash -c '! grep -q "org.mpris.MediaPlayer2.spotify" "$HOME/.dot/i3/config"'
check "i3/config: AMD output names" bash -c '! grep -q "output HDMI2\|output eDP1" "$HOME/.dot/i3/config"'
check "i3/config: no deprecated new_window" bash -c '! grep -q "new_window" "$HOME/.dot/i3/config"'
check "i3/config: no redshift" bash -c '! grep -vE "^[[:space:]]*#" "$HOME/.dot/i3/config" | grep -q redshift'
check "i3/config: no scrot" bash -c '! grep -vE "^[[:space:]]*#" "$HOME/.dot/i3/config" | grep -q scrot'
check "i3/config: i3status-rs" grep -q "i3status-rs" "$HOME/.dot/i3/config"
check "i3/config: no pasystray" bash -c '! grep -q "pasystray" "$HOME/.dot/i3/config"'
check "i3status-rs" command -v i3status-rs
check "no copyq" bash -c '! command -v copyq'
check "no xsel" bash -c '! command -v xsel'
check "i3/config: no copyq" bash -c '! grep -q "copyq" "$HOME/.dot/i3/config"'
check "no greenclip" bash -c '! command -v greenclip'
check "i3/config: no greenclip" bash -c '! grep -q "greenclip" "$HOME/.dot/i3/config"'
check "Font Awesome ${FONT_AWESOME_VERSION}" bash -c "fc-list | grep -qi 'Font Awesome ${FONT_AWESOME_VERSION%%.*}'"
check "zshrc: no virtualenvwrapper" bash -c '! grep -q "VIRTUALENVWRAPPER" "$HOME/.dot/zshrc"'
check "zshrc: no spark PATH" bash -c '! grep -q "spark-1.6.1" "$HOME/.dot/zshrc"'
check "zshrc: no ruby 2.5 PATH" bash -c '! grep -q "ruby/2.5.0" "$HOME/.dot/zshrc"'
check "zshrc: no Nim PATH" bash -c '! grep -q "Nim/bin" "$HOME/.dot/zshrc"'
check "lock.sh: NVM_VERSION" grep -q "NVM_VERSION" "$HOME/.dot/lock.sh"
check "lock.sh: no KEEPASSXC" bash -c '! grep -q "^export KEEPASSXC" "$HOME/.dot/lock.sh"'
check "packages.sh: no tslint" bash -c '! grep -q "tslint" "$HOME/.dot/nuggets/javascript/packages.sh"'
check "no keepassxc.sh" test ! -f "$HOME/.dot/nuggets/utilities/keepassxc.sh"
check "no docker-compose.sh" test ! -f "$HOME/.dot/nuggets/docker/docker-compose.sh"

# ─── BACKUP TOOLCHAIN ────────────────────────────────────
# Behavioural, not just "is it installed". Each of these pins a defect that shipped:
# see BACKUP_AUDIT.md. They run against throwaway trees and repos under /tmp; no real
# repository, no real $HOME, and cleanup.sh only ever runs with an explicit --dir.
section "Backup toolchain"

BK_TMP="$(mktemp -d)"
trap 'rm -rf "$BK_TMP"' EXIT

# A directory NAME used to be able to execute commands: du prints `<size>\t<path>`,
# a newline in the path survives `cut -f1`, and the result reached $(( )).
bk_no_code_exec_from_dirname() {
  local w="$BK_TMP/rce" d
  mkdir -p "$w"
  d="$(printf 'p\nTOTAL_REMOVED[$(touch %s/PWNED)]' "$w")"
  mkdir -p "$w/$d/node_modules"
  "$HOME/.dot/cleanup.sh" --dir "$w" --dry-run >/dev/null 2>&1 || true
  "$HOME/.dot/cleanup.sh" --dir "$w" >/dev/null 2>&1 || true
  [ ! -e "$w/PWNED" ]
}
check "cleanup.sh: a directory name cannot execute code" bk_no_code_exec_from_dirname

bk_archive_no_code_exec() {
  local w="$BK_TMP/rce2" d
  mkdir -p "$w"
  d="$(printf 'q\nCOMPRESSION_LEVEL[$(touch %s/PWNED)]' "$w")"
  mkdir -p "$w/$d"; echo x > "$w/$d/f"
  "$HOME/.dot/archive.sh" --no-cleanup "$w/$d" >/dev/null 2>&1 || true
  [ ! -e "$w/PWNED" ]
}
check "archive.sh: a directory name cannot execute code" bk_archive_no_code_exec

# An error path that exits 0 makes every downstream check meaningless.
check "backup.sh: no args exits non-zero"  bash -c '! "$HOME/.dot/backup.sh" >/dev/null 2>&1'
check "restore.sh: no args exits non-zero" bash -c '! "$HOME/.dot/restore.sh" >/dev/null 2>&1'
check "archive.sh: no args exits non-zero" bash -c '! "$HOME/.dot/archive.sh" >/dev/null 2>&1'
check "backup.sh: --help exits 0"          bash -c '"$HOME/.dot/backup.sh" --help >/dev/null 2>&1'

# cleanup.sh could only ever exit 0, so checking its status from backup.sh was a no-op.
bk_cleanup_reports_failure() {
  local w="$BK_TMP/failexit"
  mkdir -p "$w/proj/node_modules/x"; echo y > "$w/proj/node_modules/x/f"
  chmod 500 "$w/proj"
  ! "$HOME/.dot/cleanup.sh" --dir "$w" >/dev/null 2>&1
  local rc=$?; chmod 700 "$w/proj"; return $rc
}
check "cleanup.sh: reports failure with a non-zero exit" bk_cleanup_reports_failure

# Precious things cleanup.sh must not touch.
bk_cleanup_preserves() {
  local w="$BK_TMP/preserve"
  mkdir -p "$w"; ( cd "$w"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
           GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    git init -q s1 && cd s1 && echo cfg > _config.yml && mkdir _site &&
      echo html > _site/index.html && git add -A && git commit -qm i && cd ..
    git init -q s2 && cd s2 && echo a > a.txt && printf 'vendor/\n' > .gitignore &&
      git add -A && git commit -qm i && mkdir vendor && cd vendor &&
      git init -q nested && cd nested && echo W > w.txt && git add -A && git commit -qm w
  ) >/dev/null 2>&1
  echo GARBAGE > "$w/s1/.git/index"
  "$HOME/.dot/cleanup.sh" --dir "$w" >/dev/null 2>&1 || true
  # git-tracked _site survives even with a corrupt index (is_git_tracked fails closed),
  # and a nested checkout inside an ignored vendor/ is never deleted.
  [ -f "$w/s1/_site/index.html" ] && [ -f "$w/s2/vendor/nested/w.txt" ]
}
check "cleanup.sh: keeps tracked _site and nested checkouts" bk_cleanup_preserves

# archive.sh -x used to trust the filename and merge over an unrelated live directory.
bk_extract_refuses_mismatch() {
  local w="$BK_TMP/xmis"
  mkdir -p "$w/important" "$w/src/important"
  echo PRECIOUS > "$w/important/data.txt"
  echo OTHER    > "$w/src/important/data.txt"
  tar -C "$w/src" -cf - important | zstd -9 -q -o "$w/other-name.tar.zst"
  ! "$HOME/.dot/archive.sh" -x "$w/other-name.tar.zst" >/dev/null 2>&1 &&
    [ "$(cat "$w/important/data.txt")" = "PRECIOUS" ] &&
    [ -f "$w/other-name.tar.zst" ]
}
check "archive.sh -x: refuses an archive whose top-level member differs" bk_extract_refuses_mismatch

# tar drops ACLs, xattrs, sparseness and setgid unless asked; archive.sh deletes the
# source, so anything lost here is lost for good.
bk_archive_roundtrip_fidelity() {
  local w="$BK_TMP/fid"
  mkdir -p "$w/proj/sub"; echo hi > "$w/proj/f.txt"
  chmod 2755 "$w/proj/sub"; truncate -s 20M "$w/proj/sparse.img"
  command -v setfacl >/dev/null 2>&1 && setfacl -m u:nobody:r "$w/proj/f.txt"
  ( cd "$w" && "$HOME/.dot/archive.sh" --no-cleanup proj >/dev/null 2>&1 &&
    "$HOME/.dot/archive.sh" -x proj.tar.zst >/dev/null 2>&1 ) || return 1
  [ "$(stat -c%a "$w/proj/sub")" = "2755" ] &&
  [ "$(stat -c%b "$w/proj/sparse.img")" -eq 0 ] &&
  { ! command -v getfacl >/dev/null 2>&1 || getfacl -p "$w/proj/f.txt" 2>/dev/null | grep -q nobody; }
}
check "archive.sh: round trip keeps setgid, ACLs and sparseness" bk_archive_roundtrip_fidelity

# The full pipeline, against a throwaway repo. Covers snapshot-ID resolution, the
# staging default, and content fidelity — the restore path that had never been tested.
bk_backup_restore_roundtrip() {
  command -v restic >/dev/null 2>&1 || return 1
  local w="$BK_TMP/rt" h="$BK_TMP/rt/home"
  mkdir -p "$h/.dot" "$h/dev/repositories" "$w/bin" "$h/data/sub dir"
  printf '#!/usr/bin/env bash\nwhile [[ "${1:-}" == --preserve-env=* || "${1:-}" == -* ]]; do shift; done\nexec "$@"\n' > "$w/bin/sudo"
  chmod +x "$w/bin/sudo"
  cp -a "$HOME/.dot/backup.sh" "$HOME/.dot/restore.sh" "$HOME/.dot/cleanup.sh" "$h/.dot/"
  local i; for i in $(seq 1 1100); do echo "d$i" > "$h/data/f$i"; done
  echo spaces > "$h/data/sub dir/a b.txt"; ln "$h/data/f1" "$h/data/hard.txt"
  printf 'testpw\n' > "$w/pw"; chmod 400 "$w/pw"
  # -i asks for the word CREATE on the terminal; script(1) supplies one.
  ( cd "$h/.dot" && HOME="$h" PATH="$w/bin:$PATH" RESTIC_PASSWORD_FILE="$w/pw" \
      script -qec "./backup.sh $w/repo -i --allow-same-device --no-prune" /dev/null <<< "CREATE" >/dev/null 2>&1
  ) || return 1
  ( cd "$h/.dot" && HOME="$h" PATH="$w/bin:$PATH" RESTIC_PASSWORD_FILE="$w/pw" \
      ./restore.sh "$w/repo" --home-only -t "$w/out" -y >/dev/null 2>&1 ) || return 1
  diff -r --no-dereference "$h/data" "$w/out$h/data" >/dev/null 2>&1
}
check "backup.sh -> restore.sh: round trip preserves content" bk_backup_restore_roundtrip

# A bare-metal restore runs on a reinstalled machine whose hostname need not match
# the one that took the backup. Filtering on $(hostname) alone used to find nothing.
bk_restore_other_hostname() {
  command -v restic >/dev/null 2>&1 || return 1
  local w="$BK_TMP/host"; mkdir -p "$w/h"; echo x > "$w/h/f"
  export RESTIC_PASSWORD=testpw
  restic init --repo "$w/r" -q && restic backup "$w/h" --repo "$w/r" --tag home --host old-machine -q || return 1
  "$HOME/.dot/restore.sh" "$w/r" --home-only -t "$w/out" -y >/dev/null 2>&1 && [ -f "$w/out$w/h/f" ]
}
check "restore.sh: finds snapshots taken under another hostname" bk_restore_other_hostname

# A killed check/forget/prune leaves an EXCLUSIVE lock that restic never expires; it
# blocked backup.sh at its very first step.
bk_backup_clears_stale_lock() {
  command -v restic >/dev/null 2>&1 || return 1
  local w="$BK_TMP/stale" h="$BK_TMP/stale/home" p i
  mkdir -p "$h/.dot" "$h/dev/repositories" "$w/bin" "$h/data" "$w/big"
  printf '#!/usr/bin/env bash\nwhile [[ "${1:-}" == --preserve-env=* || "${1:-}" == -* ]]; do shift; done\nexec "$@"\n' > "$w/bin/sudo"
  chmod +x "$w/bin/sudo"
  cp -a "$HOME/.dot/backup.sh" "$HOME/.dot/cleanup.sh" "$h/.dot/"
  for i in $(seq 1 1100); do echo "d$i" > "$h/data/f$i"; done
  printf 'testpw\n' > "$w/pw"; export RESTIC_PASSWORD=testpw
  ( cd "$h/.dot" && HOME="$h" PATH="$w/bin:$PATH" RESTIC_PASSWORD_FILE="$w/pw" \
      script -qec "./backup.sh $w/r -i --allow-same-device --no-prune" /dev/null <<< "CREATE" >/dev/null 2>&1 ) || return 1
  head -c 300M /dev/urandom > "$w/big/b"; restic backup "$w/big" --repo "$w/r" -q || return 1
  restic check --repo "$w/r" --read-data </dev/null >/dev/null 2>&1 & p=$!
  for i in $(seq 1 200); do ls "$w/r/locks" | grep -qE '^[0-9a-f]{64}$' && break; sleep 0.05; done
  kill -9 "$p"; wait "$p" 2>/dev/null
  ! restic cat config --repo "$w/r" >/dev/null 2>&1 || return 1        # really locked
  HOME="$h" PATH="$w/bin:$PATH" RESTIC_PASSWORD_FILE="$w/pw" \
    "$h/.dot/backup.sh" "$w/r" --no-prune >/dev/null 2>&1 </dev/null
}
check "backup.sh: recovers from a stale exclusive lock" bk_backup_clears_stale_lock

# Venvs are found by their pyvenv.cfg, not only by name — but never a project root that
# happens to hold one (`python -m venv .`).
bk_cleanup_venv_by_marker() {
  local w="$BK_TMP/venvs"
  mkv() { mkdir -p "$1/bin" "$1/lib"; printf 'home = /usr/bin\n' > "$1/pyvenv.cfg"; touch "$1/bin/activate"; }
  mkv "$w/a/train_venv"; mkv "$w/proj"; echo '[project]' > "$w/proj/pyproject.toml"; echo src > "$w/proj/main.py"
  "$HOME/.dot/cleanup.sh" --dir "$w" >/dev/null 2>&1
  [ ! -e "$w/a/train_venv" ] && [ -f "$w/proj/main.py" ]
}
check "cleanup.sh: removes odd-named venvs, keeps a project root" bk_cleanup_venv_by_marker

# tar skips sockets, so counting them made the member check refuse such trees.
bk_archive_tree_with_socket() {
  local w="$BK_TMP/sock"; mkdir -p "$w/d"; echo x > "$w/d/f"
  python3 -c "import socket,sys;socket.socket(socket.AF_UNIX).bind(sys.argv[1])" "$w/d/s.sock" || return 1
  ( cd "$w" && "$HOME/.dot/archive.sh" --no-cleanup -k d >/dev/null 2>&1 ) && [ -f "$w/d.tar.zst" ]
}
check "archive.sh: archives a tree containing a socket" bk_archive_tree_with_socket

# The exclude file once listed beru's authoritative archive, its Claude transcript
# mirror (the only copy of most sessions) and Firefox's backup profiles as "derived"
# or "dead", going by their names. Pin that none of them is excluded.
bk_excludes_keep_irreplaceable() {
  command -v restic >/dev/null 2>&1 || return 1
  local w="$BK_TMP/keep" h="$BK_TMP/keep/h" p out
  export RESTIC_PASSWORD=testpw
  local keep=(.beru/index/raw/2026/07/19/sess-a.ndjson .beru/claude-mirror/projects/x.jsonl
              .beru/beru.db Dropbox/keepass.kdbx .zsh_history
              .mozilla/_firefox-cleanup-20260712-175119/prefs.js "Desktop/Old Firefox Data/p")
  for p in "${keep[@]}" .beru/index/raw/tokens.db .rustup/x; do
    mkdir -p "$h/$(dirname "$p")"; echo x > "$h/$p"; done
  restic init --repo "$w/r" -q || return 1
  HOME="$h" restic backup "$h" --repo "$w/r" --exclude-file "$HOME/.dot/restic-excludes" -q || return 1
  out="$(restic ls latest --repo "$w/r" 2>/dev/null)"
  for p in "${keep[@]}"; do grep -qxF "$h/$p" <<< "$out" || return 1; done
  # ...while the provably-derivable entries are still excluded
  ! grep -qE '/(tokens\.db|\.rustup/x)$' <<< "$out"
}
check "restic-excludes: never drops the beru archive, transcripts, keepass, history" bk_excludes_keep_irreplaceable

# cleanup.sh must not delete a target/ a cargo build is writing into.
bk_cleanup_skips_busy_target() {
  local w="$BK_TMP/busy" p
  mkdir -p "$w/busy/target/debug" "$w/idle/target/debug"
  for p in busy idle; do echo '[package]' > "$w/$p/Cargo.toml"; : > "$w/$p/target/debug/.cargo-lock"; done
  ( flock "$w/busy/target/debug/.cargo-lock" sleep 15 ) </dev/null >/dev/null 2>&1 &
  sleep 0.5
  "$HOME/.dot/cleanup.sh" --dir "$w" >/dev/null 2>&1
  [ -d "$w/busy/target" ] && [ ! -e "$w/idle/target" ]
}
check "cleanup.sh: skips a target/ held by a running cargo build" bk_cleanup_skips_busy_target

# In-place restore must not overwrite the running restore.sh, but must still restore
# the rest of ~/.dot (--packages reads its manifests from there). Checked as a dry run.
bk_inplace_excludes_only_self() {
  command -v restic >/dev/null 2>&1 || return 1
  local w="$BK_TMP/inplace" out
  mkdir -p "$w/h/.dot/backup"; cp "$HOME/.dot/restore.sh" "$w/h/.dot/"; echo pkg > "$w/h/.dot/backup/apt-manual.txt"
  export RESTIC_PASSWORD=testpw
  restic init --repo "$w/r" -q && restic backup "$w/h" --repo "$w/r" --tag home -q || return 1
  out="$(HOME="$w/h" "$w/h/.dot/restore.sh" "$w/r" --home-only -t / -n 2>&1)" || return 1
  grep -qE "(unchanged|restored|updated) +$w/h/.dot/backup/apt-manual.txt" <<< "$out" &&
    ! grep -qE "(unchanged|restored|updated) +$w/h/.dot/restore.sh" <<< "$out"
}
check "restore.sh -t /: excludes only itself, keeps the manifests" bk_inplace_excludes_only_self

# One snapshot ID cannot mean both snapshots; -s without a half used to restore the
# same tree twice, the second time as root, and report both as restored.
bk_snapshot_id_requires_half() {
  bash -c '! "$HOME/.dot/restore.sh" /nonexistent-repo -s deadbeef -y >/dev/null 2>&1'
}
check "restore.sh: -s requires --home-only or --system-only" bk_snapshot_id_requires_half

# --packages has no chroot: it changes the RUNNING system whatever --target says.
bk_packages_requires_root_target() {
  bash -c '! "$HOME/.dot/restore.sh" /nonexistent-repo --packages -t /tmp/nope -y >/dev/null 2>&1'
}
check "restore.sh: --packages refused unless target is /" bk_packages_requires_root_target

# The exclude file must not remove the inline --exclude flags: ~/.cache carries no
# CACHEDIR.TAG, so those flags are the only thing keeping ~128 GiB out of the snapshot.
check "backup.sh: still excludes ~/.cache inline" \
  bash -c 'grep -q -- "--exclude \"\$HOME/.cache\"" "$HOME/.dot/backup.sh"'
check "restic-excludes: no trailing-comment patterns" \
  bash -c '! grep -nE "^[^#].*[^ ] +#" "$HOME/.dot/restic-excludes"'

# install.sh must not take input from restore.sh's staging directory.
check "install.sh: does not read from restore/ staging" \
  bash -c '! grep -vE "^\s*#" "$HOME/.dot/install.sh" | grep -q "DOT_DIR}/restore/"'

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
