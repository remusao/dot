#!/usr/bin/env bash

set -e

# LuaLS ships as a self-contained tree (bin/ + libexec/ + locale/), not a single
# binary, so extract it under ~/.local/share and symlink the launcher onto PATH.
INSTALL_DIR="${HOME}/.local/share/lua-language-server"

NEEDS_BUILD="0"
if ! [ -x "${INSTALL_DIR}/bin/lua-language-server" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${INSTALL_DIR}/bin/lua-language-server" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ "${CURRENT_VERSION}" != "${LUA_LANGUAGE_SERVER_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-x64.tar.gz" \
      -o "${tmp}/lua-language-server.tar.gz"
    rm -rf "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    tar -xzf "${tmp}/lua-language-server.tar.gz" -C "${INSTALL_DIR}"
    ln -sf "${INSTALL_DIR}/bin/lua-language-server" "${HOME}/.local/bin/lua-language-server"
  )
fi
