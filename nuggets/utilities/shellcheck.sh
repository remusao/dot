#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/shellcheck" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(shellcheck --version | grep 'version:')
  if [ "${CURRENT_VERSION}" != "version: ${SHELLCHECK}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  TEMP=/tmp/shellcheck
  (
    rm -fr "${TEMP}"
    mkdir "${TEMP}"
    git clone --depth=1 --branch "v${SHELLCHECK}" git@github.com:koalaman/shellcheck.git "${TEMP}"
    cd "${TEMP}" || exit 1
    stack install
    rm -fr "${TEMP}"
  )
fi
