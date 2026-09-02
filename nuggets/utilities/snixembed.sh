#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! command -v snixembed &>/dev/null; then
  NEEDS_BUILD="1"
else
  # A binary that no longer execs must rebuild, not abort the run via pipefail.
  CURRENT_VERSION=$(snixembed --version 2>/dev/null | awk '{print $2}' || true)
  if [ "${CURRENT_VERSION}" != "${SNIXEMBED_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  sudo apt-get install --yes valac libgtk-3-dev libdbusmenu-gtk3-dev

  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # Clone the tag, not the commit: the makefile builds version.vala from `git
    # describe --tags`, so a bare hash here means every run rebuilds.
    git clone --depth=1 --branch "${SNIXEMBED_VERSION}" \
      https://git.sr.ht/~steef/snixembed "${tmp}"
    cd "${tmp}"

    # Lightweight unsigned tag, no published checksums: the pinned commit is the
    # only integrity check available -- it proves the tree, never the author.
    head_sha=$(git rev-parse HEAD)
    if [ "${head_sha}" != "${SNIXEMBED_COMMIT}" ]; then
      printf 'snixembed: tag %s is %s, expected %s\n' \
        "${SNIXEMBED_VERSION}" "${head_sha}" "${SNIXEMBED_COMMIT}" >&2
      exit 1
    fi

    make
    # Not `sudo make install`: version.vala is .PHONY and a prerequisite of the
    # binary, so that target relinks -- running valac as root over /tmp.
    sudo install -Dm755 snixembed /usr/local/bin/snixembed
    sudo install -Dm644 snixembed.1 /usr/local/share/man/man1/snixembed.1
  )
fi
