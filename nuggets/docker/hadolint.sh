#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/hadolint" ]; then
  NEEDS_BUILD="1"
else
  # Never fatal: a corrupt binary must trigger a reinstall, not abort update.sh.
  CURRENT_VERSION=$("${HOME}/.local/bin/hadolint" --version 2>/dev/null || true)
  if [ "${CURRENT_VERSION}" != "Haskell Dockerfile Linter ${HADOLINT_VERSION#v}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}"
    # Temp in the destination dir so the mv is a same-filesystem rename(2).
    tmp=$(mktemp "${HOME}/.local/bin/.hadolint.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    fetch_verified "${base}/hadolint-linux-x86_64" "$tmp" \
      "${base}/checksums.sha256" hadolint-linux-x86_64
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/hadolint"
  )
fi
