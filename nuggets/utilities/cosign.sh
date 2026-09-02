#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# Here only to verify other artifacts: sops signs its checksum manifest with a
# sigstore bundle, not PGP, so cosign must be installed before sops.sh.
#
# cosign's own download is checked against its release checksums file only:
# integrity, not provenance. Verifying its own sigstore bundle needs a trusted
# cosign, so the chain stops here.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/cosign" ]; then
  NEEDS_BUILD="1"
else
  # `cosign version` prints ASCII art; --json's gitVersion includes the "v".
  CURRENT_VERSION=$("${HOME}/.local/bin/cosign" version --json 2>/dev/null |
    jq -r '.gitVersion' 2>/dev/null || true)
  if [ "${CURRENT_VERSION}" != "${COSIGN_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}"
    tmp=$(mktemp "${HOME}/.local/bin/.cosign.XXXXXX")
    trap 'rm -f "$tmp"' EXIT

    fetch_verified "${base}/cosign-linux-amd64" "$tmp" \
      "${base}/cosign_checksums.txt" cosign-linux-amd64

    chmod 755 "$tmp" # mktemp made it 0600
    mv "$tmp" "${HOME}/.local/bin/cosign"
  )
fi
