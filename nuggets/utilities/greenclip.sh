#!/usr/bin/env bash
set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/greenclip" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/greenclip" version 2>&1 | grep -oP '[\d.]+' || echo "0")
  if [ "${CURRENT_VERSION}" != "${GREENCLIP_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -fsSL -o "${HOME}/.local/bin/greenclip" \
      "https://github.com/erebe/greenclip/releases/download/v${GREENCLIP_VERSION}/greenclip"
  chmod +x "${HOME}/.local/bin/greenclip"
fi
