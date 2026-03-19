#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/hyperfine" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/hyperfine" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${HYPERFINE_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/sharkdp/hyperfine/releases/download/v${HYPERFINE_VERSION}/hyperfine-v${HYPERFINE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      -o "${tmp}/hyperfine.tar.gz"
    tar -xzf "${tmp}/hyperfine.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/hyperfine-v${HYPERFINE_VERSION}-x86_64-unknown-linux-musl/hyperfine"
    mv "${tmp}/hyperfine-v${HYPERFINE_VERSION}-x86_64-unknown-linux-musl/hyperfine" "${HOME}/.local/bin/hyperfine"
  )
fi
