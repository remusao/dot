#!/usr/bin/env bash

set -Eeuo pipefail

. "$(dirname "$0")/lock.sh"

export PATH="${HOME}/.local/bin:${HOME}/.pyenv/bin:${PATH}"

# Neovim (from source)
. ./nuggets/utilities/neovim.sh

# Desktop apps
. ./nuggets/utilities/obsidian.sh

# Sandboxing
if [ "${DOTFILES_SKIP_FIREJAIL:-0}" != "1" ]; then
  . ./nuggets/utilities/firejail.sh
fi

# Rust
. ./nuggets/rust/rustup.sh
. ./nuggets/rust/sccache.sh
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

# Secrets
. ./nuggets/utilities/sops.sh

# Backup
. ./nuggets/utilities/restic.sh

# Git TUI
. ./nuggets/utilities/lazygit.sh

# Git performance (filesystem monitor)
. ./nuggets/utilities/watchman.sh

# Trackpad gestures
. ./nuggets/utilities/fusuma.sh

# i3 bar icons
. ./nuggets/utilities/font-awesome.sh

# Clipboard manager
. ./nuggets/utilities/greenclip.sh
