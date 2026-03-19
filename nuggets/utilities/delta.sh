#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/delta" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/delta" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${DELTA_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      -o "${tmp}/delta.tar.gz"
    tar -xzf "${tmp}/delta.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/delta-${DELTA_VERSION}-x86_64-unknown-linux-musl/delta"
    mv "${tmp}/delta-${DELTA_VERSION}-x86_64-unknown-linux-musl/delta" "${HOME}/.local/bin/delta"
  )
fi
