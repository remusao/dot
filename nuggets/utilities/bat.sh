#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/bat" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/bat" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${BAT_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      -o "${tmp}/bat.tar.gz"
    tar -xzf "${tmp}/bat.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/bat-v${BAT_VERSION}-x86_64-unknown-linux-musl/bat"
    mv "${tmp}/bat-v${BAT_VERSION}-x86_64-unknown-linux-musl/bat" "${HOME}/.local/bin/bat"
  )
fi
