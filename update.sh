#! /usr/bin/env bash

set -e

. ./lock.sh

# Python
. ./nuggets/python/pyenv.sh
. ./nuggets/python/python.sh

# Docker
. ./nuggets/docker/docker-machine.sh
. ./nuggets/docker/docker-compose.sh
. ./nuggets/docker/hadolint.sh

# Utilities
. ./nuggets/utilities/vagrant.sh
. ./nuggets/utilities/neovim.sh
. ./nuggets/utilities/keepassxc.sh
. ./nuggets/utilities/terraform.sh

# Rust
. ./nuggets/rust/rustup.sh
. ./nuggets/rust/sccache.sh
. ./nuggets/rust/ripgrep.sh
. ./nuggets/rust/rust-analyzer.sh

# JavaScript
. ./nuggets/javascript/nodejs.sh
. ./nuggets/javascript/packages.sh
. ./nuggets/javascript/eslint.sh
