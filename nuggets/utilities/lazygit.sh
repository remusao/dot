#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/lazygit" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/lazygit" --version | grep -oP 'version=\K[^,]+')
  if [ "${CURRENT_VERSION}" != "${LAZYGIT_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
      -o "${tmp}/lazygit.tar.gz"
    tar -xzf "${tmp}/lazygit.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/lazygit"
    mv "${tmp}/lazygit" "${HOME}/.local/bin/lazygit"
  )
fi
