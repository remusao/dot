#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/fonts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

if ! font_up_to_date font-awesome "${FONT_AWESOME_VERSION}"; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # The release publishes the two zips and nothing else: no checksums, no
    # signatures, and a lightweight tag. TLS plus the pinned version is the
    # ceiling upstream offers.
    curl_fetch \
      "https://github.com/FortAwesome/Font-Awesome/releases/download/${FONT_AWESOME_VERSION}/fontawesome-free-${FONT_AWESOME_VERSION}-desktop.zip" \
      "$tmp/fa.zip"
    # Only the three desktop faces are wanted; the rest of the archive is 5.8k
    # SVG and metadata files we would write and immediately throw away.
    unzip -q -j "$tmp/fa.zip" 'fontawesome-free-*/otfs/*.otf' -d "$tmp/otfs"

    # Every family name carries the major, so a bump installs new files rather
    # than replacing the old ones and both sets then answer the same private-use
    # lookups. Unlink instead of overwrite: the inode survives for clients that
    # already have it mmap'd, which is the hazard lib/fonts.sh exists to avoid.
    if [ -d "${FONT_DIR}" ]; then
      find "${FONT_DIR}" -maxdepth 1 -name 'Font Awesome *.otf' \
        ! -name "Font Awesome ${FONT_AWESOME_VERSION%%.*} *" -delete
    fi

    font_install "$tmp"/otfs/*.otf
  )
  font_stamp font-awesome "${FONT_AWESOME_VERSION}"
fi
