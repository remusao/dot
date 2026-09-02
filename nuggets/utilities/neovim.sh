#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/nvim" ]; then
  NEEDS_BUILD="1"
else
  # Ask the binary we just tested for, not whatever `nvim` PATH resolves to.
  CURRENT_VERSION=$("${HOME}/.local/bin/nvim" --version 2>/dev/null | head -n 1) ||
    CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "NVIM ${NEOVIM_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
  # An interrupted install leaves the right version with no $VIMRUNTIME, which
  # the version check on its own would call up to date forever.
  if ! [ -d "${HOME}/.local/share/nvim/runtime" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  sudo apt-get install --yes ninja-build gettext cmake curl build-essential

  (
    TEMP=$(mktemp -d)
    trap 'rm -rf "$TEMP"' EXIT
    git clone --depth=1 --branch "${NEOVIM_VERSION}" https://github.com/neovim/neovim.git "${TEMP}"
    cd "${TEMP}"
    # RelWithDebInfo is what upstream BUILD.md prescribes for stable tags.
    make CMAKE_INSTALL_PREFIX="${HOME}/.local" CMAKE_BUILD_TYPE=RelWithDebInfo
    # `make install` copies files forward but never purges runtime files removed
    # upstream between versions; the stale copies break :checkhealth and can feed
    # vim.loader a stale bytecode cache. lib/nvim (bundled tree-sitter parsers)
    # goes stale the same way. Clear all three before installing.
    rm -rf "${HOME}/.local/share/nvim/runtime" "${HOME}/.local/lib/nvim" \
      "${HOME}/.cache/nvim/luac"
    make install
  )
fi
