#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/restic" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/restic" version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${RESTIC}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp "${HOME}/.local/bin/.restic.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    curl -fL "https://github.com/restic/restic/releases/download/v${RESTIC}/restic_${RESTIC}_linux_amd64.bz2" \
      | bunzip2 > "$tmp"
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/restic"
  )
fi
