#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/sops" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/sops" --version | awk '{print "v"$2}')
  if [ "${CURRENT_VERSION}" != "${SOPS}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp "${HOME}/.local/bin/.sops.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    curl -fL "https://github.com/getsops/sops/releases/download/${SOPS}/sops-${SOPS}.linux.amd64" \
      -o "$tmp"
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/sops"
  )
fi
