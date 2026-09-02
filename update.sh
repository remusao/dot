#!/usr/bin/env bash

set -Eeuo pipefail

# Nuggets are sourced: without this a nugget dying under `set -e` aborts the
# whole run with no output at all. set -E propagates the trap into subshells.
trap 'printf "update.sh: FAILED at %s:%s (exit %s)\n  %s\n" \
  "${BASH_SOURCE[0]}" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR

. "$(dirname "$0")/lock.sh"

export PATH="${HOME}/.local/bin:${HOME}/.pyenv/bin:${PATH}"

# Neovim (from source)
. ./nuggets/utilities/neovim.sh

# Symbols Nerd Font (required by kitty's source build at package time)
. ./nuggets/utilities/nerd-fonts-symbols.sh

# Terminal (from source, native CPU optimization)
. ./nuggets/utilities/kitty.sh

# Desktop apps
. ./nuggets/utilities/obsidian.sh

# Sandboxing
if [ "${DOTFILES_SKIP_FIREJAIL:-0}" != "1" ]; then
  . ./nuggets/utilities/firejail.sh
fi

# Rust
. ./nuggets/rust/rustup.sh
. ./nuggets/rust/sccache.sh

# Nothing else points cargo at sccache (no ~/.cargo/config.toml) and each
# `cargo install` below builds in its own throwaway target dir, so the shared
# dependency tree was recompiled every time. Must come after sccache.sh (cannot
# wrap its own build); guarded so a clean machine gets no missing wrapper path.
# `sccache --show-stats` proves nothing: stats live in the server's memory, and
# it exits after 600s idle.
if [ -x "${HOME}/.cargo/bin/sccache" ]; then
  export RUSTC_WRAPPER="${HOME}/.cargo/bin/sccache"
fi

. ./nuggets/rust/ripgrep.sh
. ./nuggets/rust/alacritty.sh
. ./nuggets/rust/i3status-rust.sh
. ./nuggets/rust/cargo-tools.sh

# Python
. ./nuggets/python/pyenv.sh
. ./nuggets/python/python.sh

# JavaScript
. ./nuggets/javascript/nodejs.sh
. ./nuggets/javascript/packages.sh

# Docker tools
. ./nuggets/docker/hadolint.sh

# AWS
. ./nuggets/utilities/aws-vault.sh

# Secrets -- cosign first, it verifies sops' manifest
. ./nuggets/utilities/cosign.sh
. ./nuggets/utilities/sops.sh

# Backup
. ./nuggets/utilities/restic.sh

# Cloud sync
. ./nuggets/utilities/rclone.sh

# Git TUI
. ./nuggets/utilities/lazygit.sh

# Git performance (filesystem monitor)
. ./nuggets/utilities/watchman.sh

# Trackpad gestures
. ./nuggets/utilities/fusuma.sh

# i3 bar fonts
. ./nuggets/utilities/jetbrains-mono-nf.sh
. ./nuggets/utilities/font-awesome.sh

# SNI→XEmbed bridge for i3bar system tray
. ./nuggets/utilities/snixembed.sh

# CLI tools (binary downloads)
. ./nuggets/utilities/fzf.sh
. ./nuggets/utilities/fd.sh
. ./nuggets/utilities/bat.sh
. ./nuggets/utilities/delta.sh
. ./nuggets/utilities/hyperfine.sh

# Neovim language tooling (binary downloads)
. ./nuggets/utilities/lua-language-server.sh
. ./nuggets/utilities/shfmt.sh
. ./nuggets/utilities/stylua.sh
