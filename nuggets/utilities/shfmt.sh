#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/shfmt" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/shfmt" --version 2>/dev/null | sed 's/^v//')
  if [ "${CURRENT_VERSION}" != "${SHFMT_VERSION#v}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp "${HOME}/.local/bin/.shfmt.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    curl -fL "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64" \
      -o "$tmp"
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/shfmt"
  )
fi
