#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# The state dir is part of the guard, not just the binary: without it every
# watchman call dies with "failed to create <user>-state: Permission denied".
WATCHMAN_STAMP="/usr/local/lib/watchman-release"
NEEDS_BUILD="0"
if ! command -v watchman &>/dev/null ||
  ! [ -d /usr/local/var/run/watchman ]; then
  NEEDS_BUILD="1"
# `watchman version` reports a CI build stamp (20260727.012849.0), never the
# release tag, so it can't be compared against WATCHMAN_VERSION -- hence a stamp.
elif [ "$(cat "${WATCHMAN_STAMP}" 2>/dev/null)" != "${WATCHMAN_VERSION}" ]; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # Upstream publishes no checksums or signatures for the release assets, so
    # TLS is the ceiling: transport integrity only, no provenance.
    curl_fetch "https://github.com/facebook/watchman/releases/download/v${WATCHMAN_VERSION}/watchman-v${WATCHMAN_VERSION}-linux.zip" \
      "${tmp}/watchman.zip"
    unzip -q "${tmp}/watchman.zip" -d "${tmp}"

    # 2777 is what upstream's install.md prescribes: watchman creates its own
    # 0700 <user>-state leaf underneath, so the parent is just a rendezvous.
    sudo mkdir -p /usr/local/{bin,lib} /usr/local/var/run/watchman
    sudo chmod 2777 /usr/local/var/run/watchman

    # `install` unlinks before writing, unlike cp's O_TRUNC: the binary loads
    # these libs by absolute path, so they must never be rewritten under a live
    # process. Unguarded on purpose -- a failed lib copy must fail the run.
    sudo install -m 755 "${tmp}"/watchman-*/bin/* /usr/local/bin/
    sudo install -m 644 "${tmp}"/watchman-*/lib/* /usr/local/lib/

    printf '%s\n' "${WATCHMAN_VERSION}" | sudo tee "${WATCHMAN_STAMP}" >/dev/null
  )
fi
