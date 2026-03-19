#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/fd" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/fd" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${FD_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      -o "${tmp}/fd.tar.gz"
    tar -xzf "${tmp}/fd.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/fd-v${FD_VERSION}-x86_64-unknown-linux-musl/fd"
    mv "${tmp}/fd-v${FD_VERSION}-x86_64-unknown-linux-musl/fd" "${HOME}/.local/bin/fd"
  )
fi
