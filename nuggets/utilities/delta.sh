#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/delta" ]; then
  NEEDS_BUILD="1"
# Version alone cannot detect the musl -> gnu asset switch below: an installed
# musl binary reports the same version. musl's is static-pie, gnu links libc.
elif ! ldd "${HOME}/.local/bin/delta" 2>/dev/null | grep -q 'libc\.so\.6'; then
  NEEDS_BUILD="1"
else
  # Present but unrunnable should reinstall, not abort the whole update run.
  CURRENT_VERSION=$("${HOME}/.local/bin/delta" --version 2>/dev/null | awk '{print $2}') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${DELTA_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # gnu rather than musl: delta is git's pager, so it runs on every diff and
    # musl's allocator is the slower one. Upstream publishes no checksums or
    # signatures for any asset, so TLS is the ceiling here. Releases are also
    # routinely incomplete (0.19.0 shipped no gnu tarball), so lock.sh must
    # constrain bump.sh to releases carrying this exact asset.
    pkg="delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu"
    curl_fetch \
      "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${pkg}.tar.gz" \
      "${tmp}/delta.tar.gz"
    tar -xzf "${tmp}/delta.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/${pkg}/delta"
    mv "${tmp}/${pkg}/delta" "${HOME}/.local/bin/delta"
  )
fi
