#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/git-lfs" ]; then
  NEEDS_BUILD="1"
else
  # `git-lfs/3.8.0 (GitHub; linux amd64; go 1.25.0)` -- anchor to the leading
  # field so the Go version can never satisfy the match. Never fatal: a bad
  # binary must reinstall, not abort the run under set -e.
  CURRENT_VERSION=$("${HOME}/.local/bin/git-lfs" --version 2>/dev/null |
    grep -oP '^git-lfs/\K[0-9.]+') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${GIT_LFS_VERSION#v}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/git-lfs/git-lfs/releases/download/${GIT_LFS_VERSION}"
    asset="git-lfs-linux-amd64-${GIT_LFS_VERSION}.tar.gz"

    tmp=$(mktemp -d)
    # Staged inside the destination directory so the final swap is a rename:
    # git would otherwise be able to exec a half-copied filter binary
    # mid-checkout. Trapped too, or a failed verify leaves it behind on PATH.
    mkdir -p "${HOME}/.local/bin"
    stage=$(mktemp "${HOME}/.local/bin/.git-lfs.XXXXXX")
    trap 'rm -rf "$tmp"; rm -f "$stage"' EXIT

    # gitconfig wires this binary into filter.lfs.process, so it runs on every
    # checkout in every repo -- a swapped artifact executes against all of them.
    # sha256sums.asc is clearsigned, so verify provenance against a pinned
    # fingerprint rather than trusting the manifest's own origin.
    #
    # Fingerprint is published in git-lfs's README.md (core team table); the key
    # in lib/keys comes from their in-repo `core-gpg-keys` tag, not a keyserver.
    # Releases are currently signed by chrisd8088. If a future release is signed
    # by another core maintainer this fails loudly rather than downgrading to
    # transport integrity -- re-export the key from that tag and bump the pin.
    curl_fetch "${base}/sha256sums.asc" "${tmp}/manifest.asc"
    verify_pgp_clearsigned "${tmp}/manifest.asc" \
      "$(dirname "${BASH_SOURCE[0]}")/../lib/keys/git-lfs.asc" \
      86CD3297749375BCF8206715F54FE648088335A9 "${tmp}/manifest"

    curl_fetch "${base}/${asset}" "${tmp}/${asset}"
    verify_sha256 "${tmp}/${asset}" "${tmp}/manifest" "$asset"

    tar -xzf "${tmp}/${asset}" -C "$tmp"
    cat "${tmp}/git-lfs-${GIT_LFS_VERSION#v}/git-lfs" >"$stage"
    chmod 755 "$stage"
    mv "$stage" "${HOME}/.local/bin/git-lfs"
  )
fi
