#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# Guard covers rclone.1 too: a version-only check would never install it.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/rclone" ] ||
  ! [ -f "${HOME}/.local/share/man/man1/rclone.1" ]; then
  NEEDS_BUILD="1"
else
  # set -e: an unrunnable binary must reinstall, not kill the update run.
  CURRENT_VERSION=$("${HOME}/.local/bin/rclone" version 2>/dev/null | awk 'NR==1{print $2}') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${DOTFILES_RCLONE_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # Verify before unpacking. SHA256SUMS is PGP clearsigned: checking it against
    # the key pinned here (fingerprint: rclone.org/release_signing) proves
    # provenance, not just integrity -- unchecked hashes prove only the latter.
    base="https://github.com/rclone/rclone/releases/download/${DOTFILES_RCLONE_VERSION}"
    zip="rclone-${DOTFILES_RCLONE_VERSION}-linux-amd64.zip"

    curl_fetch "${base}/SHA256SUMS" "${tmp}/SHA256SUMS.asc"
    verify_pgp_clearsigned "${tmp}/SHA256SUMS.asc" \
      "$(dirname "${BASH_SOURCE[0]}")/../lib/keys/rclone.asc" \
      FBF737ECE9F8AB18604BD2AC93935E02FF3B54FA "${tmp}/SHA256SUMS"

    curl_fetch "${base}/${zip}" "${tmp}/${zip}"
    verify_sha256 "${tmp}/${zip}" "${tmp}/SHA256SUMS" "$zip"

    unzip -q "${tmp}/${zip}" -d "$tmp"
    src="${tmp}/rclone-${DOTFILES_RCLONE_VERSION}-linux-amd64"
    chmod 755 "${src}/rclone"
    mv "${src}/rclone" "${HOME}/.local/bin/rclone"

    install -Dm644 "${src}/rclone.1" "${HOME}/.local/share/man/man1/rclone.1"
  )
fi
