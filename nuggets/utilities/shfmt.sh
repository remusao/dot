#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/shfmt" ]; then
  NEEDS_BUILD="1"
else
  # A binary that won't run should reinstall, not abort the run under set -e.
  CURRENT_VERSION=$("${HOME}/.local/bin/shfmt" --version 2>/dev/null | sed 's/^v//') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${SHFMT_VERSION#v}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp "${HOME}/.local/bin/.shfmt.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    # No upstream checksums or signatures: TLS integrity only, no provenance.
    curl_fetch \
      "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64" \
      "$tmp"
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/shfmt"
  )
fi
