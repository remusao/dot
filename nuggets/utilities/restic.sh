#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/restic" ]; then
  NEEDS_BUILD="1"
else
  # `|| true`: an unrunnable binary must reinstall below, not abort update.sh.
  CURRENT_VERSION=$("${HOME}/.local/bin/restic" version 2>/dev/null | awk '{print $2}' || true)
  if [ "${CURRENT_VERSION}" != "${RESTIC_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}"
    asset="restic_${RESTIC_VERSION}_linux_amd64.bz2"

    # Checked while still compressed: decompressing first changes the digest,
    # and would put an unverified binary in ~/.local/bin.
    work=$(mktemp -d)
    tmp=$(mktemp "${HOME}/.local/bin/.restic.XXXXXX")
    trap 'rm -rf "$work"; rm -f "$tmp"' EXIT

    # This binary is handed the backup repo password and the cloud storage keys.
    # The fingerprint below is published in restic's install docs: provenance,
    # not just integrity.
    curl_fetch "${base}/SHA256SUMS" "${work}/SHA256SUMS"
    curl_fetch "${base}/SHA256SUMS.asc" "${work}/SHA256SUMS.asc"
    verify_pgp_detached "${work}/SHA256SUMS" "${work}/SHA256SUMS.asc" \
      "$(dirname "${BASH_SOURCE[0]}")/../lib/keys/restic.asc" \
      CF8F18F2844575973F79D4E191A6868BD3F7A907

    curl_fetch "${base}/${asset}" "${work}/${asset}"
    verify_sha256 "${work}/${asset}" "${work}/SHA256SUMS" "$asset"

    bunzip2 -c "${work}/${asset}" >"$tmp"
    chmod 755 "$tmp" # mktemp made it 0600
    mv "$tmp" "${HOME}/.local/bin/restic"
  )
fi
