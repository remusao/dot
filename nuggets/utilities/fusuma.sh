#!/usr/bin/env bash

set -e

# ruby comes from install.sh's ZBook block, but update.sh sources this nugget
# unconditionally: without ruby it must no-op, not abort the update run.
if command -v gem &>/dev/null; then
  NEEDS_INSTALL="0"
  CURRENT_VERSION=$(gem list fusuma --exact 2>/dev/null | grep -oP '\(\K[0-9.]+' || echo "")
  if [ -z "${CURRENT_VERSION}" ]; then
    NEEDS_INSTALL="1"
  elif [ "${CURRENT_VERSION}" != "${FUSUMA_VERSION}" ]; then
    NEEDS_INSTALL="1"
  fi

  if [ "${NEEDS_INSTALL}" = "1" ]; then
    # gem install keeps older versions and the binstub activates the newest, so
    # lowering the pin would not roll back, and gem list would keep reporting the
    # higher version -- reinstalling every run. `gem cleanup` keeps the newest.
    if [ -n "${CURRENT_VERSION}" ]; then
      sudo gem uninstall fusuma --all --executables --ignore-dependencies
    fi
    # No fetch_verified: rubygems' sha256 shares the gem's origin and `gem
    # install` already checks checksums.yaml.gz -- integrity, never provenance
    # (the gem is unsigned). --no-document skips root-owned ri data.
    sudo gem install fusuma -v "${FUSUMA_VERSION}" --no-document
  fi
fi
