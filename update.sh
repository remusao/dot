#! /usr/bin/env bash

set -e

. ./lock.sh

. ./nuggets/rust/rust-analyzer.sh
exit 0

# Utilities
. ./nuggets/utilities/neovim.sh
. ./nuggets/utilities/keepassxc.sh

# Rust
. ./nuggets/rust/rustup.sh
. ./nuggets/rust/ripgrep.sh
. ./nuggets/rust/sccache.sh
. ./nuggets/rust/rust-analyzer.sh

# JavaScript
. ./nuggets/javascript/nodejs.sh
. ./nuggets/javascript/packages.sh
. ./nuggets/javascript/eslint.sh

# Docker
. ./nuggets/docker/hadolint.sh
