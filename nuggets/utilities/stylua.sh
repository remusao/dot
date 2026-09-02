#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/stylua" ]; then
  NEEDS_BUILD="1"
# Reinstall an already-current musl binary (static-pie, no libc.so.6): a version
# check alone would leave the musl->gnu switch unapplied until the next release.
elif ! ldd "${HOME}/.local/bin/stylua" 2>/dev/null | grep -q 'libc\.so\.6'; then
  NEEDS_BUILD="1"
else
  # update.sh sources this under errexit: without the fallback, a binary that
  # cannot run aborts every later nugget instead of reinstalling itself.
  CURRENT_VERSION="v$("${HOME}/.local/bin/stylua" --version | awk '{print $2}')" ||
    CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${STYLUA_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # gnu rather than musl: one pinned Ubuntu on glibc 2.39, gnu build needs at
    # most GLIBC_2.34, so the static artifact buys nothing. Upstream publishes no
    # checksums or signatures for any asset, so TLS is the only guarantee here.
    curl_fetch \
      "https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/stylua-linux-x86_64.zip" \
      "${tmp}/stylua.zip"
    unzip -q "${tmp}/stylua.zip" -d "${tmp}"
    chmod 755 "${tmp}/stylua"
    mv "${tmp}/stylua" "${HOME}/.local/bin/stylua"
  )
fi
