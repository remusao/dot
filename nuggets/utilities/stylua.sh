#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/stylua" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION="v$("${HOME}/.local/bin/stylua" --version | awk '{print $2}')"
  if [ "${CURRENT_VERSION}" != "${STYLUA_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/stylua-linux-x86_64-musl.zip" \
      -o "${tmp}/stylua.zip"
    unzip -q "${tmp}/stylua.zip" -d "${tmp}"
    chmod 755 "${tmp}/stylua"
    mv "${tmp}/stylua" "${HOME}/.local/bin/stylua"
  )
fi
