#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# The pin bounds the .deb (the Electron shell) only: Obsidian self-updates its
# app payload into ~/.config/obsidian/obsidian-<ver>.asar and loads that in
# preference to the packaged one, outside dpkg. The status is part of the
# comparison because dpkg-query still answers for a removed-but-not-purged
# package, which otherwise reads as "installed" forever.
NEEDS_BUILD="0"
CURRENT_STATE=$(dpkg-query -W -f='${db:Status-Status} ${Version}' obsidian 2>/dev/null || true)
if [ "${CURRENT_STATE}" != "installed ${OBSIDIAN_VERSION}" ]; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    DEB=$(mktemp --suffix=.deb)
    trap 'rm -f "$DEB"' EXIT

    # Upstream publishes no checksum or signature for desktop assets, so TLS is
    # the ceiling -- and this .deb's postinst runs as root.
    curl_fetch \
      "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb" \
      "$DEB"

    chmod 644 "$DEB" # mktemp made it 0600, and apt reads it as _apt
    # lock.sh is the source of truth, so a pin moving backwards must install
    # rather than abort the update.sh run: plain `apt-get install -y` exits 100
    # on a downgrade. That rolls back the shell only -- also delete the newer
    # ~/.config/obsidian/obsidian-*.asar, with automatic updates turned off.
    sudo apt-get install -y --allow-downgrades "$DEB"
  )
fi
