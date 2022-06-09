#! /usr/bin/env bash

set -e

. ./lock.sh

# Haskell
# . ./nuggets/haskell/stack.sh
# . ./nuggets/haskell/hls.sh
# . ./nuggets/haskell/hls-wrapper.sh

# Docker
. ./nuggets/docker/docker-compose.sh
. ./nuggets/docker/hadolint.sh

# Go
. ./nuggets/go/go.sh

# Python
. ./nuggets/python/pyenv.sh
. ./nuggets/python/python.sh

# Utilities
. ./nuggets/utilities/vagrant.sh
. ./nuggets/utilities/neovim.sh
. ./nuggets/utilities/keepassxc.sh
# . ./nuggets/utilities/terraform.sh
. ./nuggets/utilities/shellcheck.sh

# Rust
. ./nuggets/rust/rustup.sh
. ./nuggets/rust/sccache.sh
. ./nuggets/rust/ripgrep.sh
. ./nuggets/rust/rust-analyzer.sh

# JavaScript
. ./nuggets/javascript/nodejs.sh
. ./nuggets/javascript/packages.sh
. ./nuggets/javascript/eslint.sh
