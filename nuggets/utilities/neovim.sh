#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/nvim" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(nvim --version | head -n 1)
  if [ "${CURRENT_VERSION}" != "NVIM ${NEOVIM}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  sudo apt-get install --yes ninja-build gettext cmake curl build-essential

  (
    TEMP=$(mktemp -d)
    trap 'rm -rf "$TEMP"' EXIT
    git clone --depth=1 --branch "${NEOVIM}" https://github.com/neovim/neovim.git "${TEMP}"
    cd "${TEMP}"
    make CMAKE_INSTALL_PREFIX="${HOME}/.local" CMAKE_BUILD_TYPE=RelWithDebInfo
    make install
  )
fi
