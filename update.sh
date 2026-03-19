#!/usr/bin/env bash

set -Eeuo pipefail

. "$(dirname "$0")/lock.sh"

export PATH="${HOME}/.local/bin:${HOME}/.pyenv/bin:${PATH}"

# Neovim (from source)
. ./nuggets/utilities/neovim.sh

# Desktop apps
. ./nuggets/utilities/obsidian.sh
. ./nuggets/utilities/chrome.sh

# Sandboxing
if [ "${DOTFILES_SKIP_FIREJAIL:-0}" != "1" ]; then
  . ./nuggets/utilities/firejail.sh
fi

# Rust
. ./nuggets/rust/rustup.sh
. ./nuggets/rust/sccache.sh
. ./nuggets/rust/ripgrep.sh

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

# Backup
. ./nuggets/utilities/restic.sh
