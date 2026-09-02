#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# LuaLS ships as a tree (bin/ plus script/, meta/, locale/, main.lua), not a
# single binary, so extract under ~/.local/share and symlink the launcher.
INSTALL_DIR="${HOME}/.local/share/lua-language-server"

NEEDS_BUILD="0"
if ! [ -x "${INSTALL_DIR}/bin/lua-language-server" ]; then
  NEEDS_BUILD="1"
else
  # A tree too broken to print a version makes grep exit 1; under update.sh's
  # pipefail that would abort the run instead of reinstalling.
  CURRENT_VERSION=$("${INSTALL_DIR}/bin/lua-language-server" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${LUA_LANGUAGE_SERVER_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    # Stage beside the target: same-filesystem rename, and nothing reaps
    # ~/.local/share (hence the sweep). Extracting into INSTALL_DIR directly --
    # the tarball has no top-level dir -- leaves a half tree the check accepts.
    mkdir -p "${HOME}/.local/share"
    rm -rf "${HOME}"/.local/share/.lua-language-server.*
    tmp=$(mktemp -d "${HOME}/.local/share/.lua-language-server.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT

    # Upstream publishes no checksums or signatures, so TLS is the ceiling. The
    # version check below proves the payload runs, not where it came from.
    curl_fetch \
      "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-x64.tar.gz" \
      "${tmp}/lua-language-server.tar.gz"
    mkdir -p "${tmp}/tree"
    tar -xzf "${tmp}/lua-language-server.tar.gz" -C "${tmp}/tree"
    [ "$("${tmp}/tree/bin/lua-language-server" --version)" = "${LUA_LANGUAGE_SERVER_VERSION}" ]

    rm -rf "${INSTALL_DIR}"
    mv "${tmp}/tree" "${INSTALL_DIR}"
  )
fi

# Unconditional: the checks above only inspect the tree, so a deleted symlink
# -- all nvim's lua_ls resolves -- would never be repaired.
ln -sf "${INSTALL_DIR}/bin/lua-language-server" "${HOME}/.local/bin/lua-language-server"
