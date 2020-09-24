#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/hadolint" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(hadolint --version | cut -d'-' -f -1)
  if [ "${CURRENT_VERSION}" != "Haskell Dockerfile Linter ${HADOLINT}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  TEMP=/tmp/hadolint
  (
    rm -fr "${TEMP}"
    mkdir "${TEMP}"
    git clone --depth=1 --branch "${HADOLINT}" git@github.com:hadolint/hadolint.git "${TEMP}"
    cd "${TEMP}" || exit 1
    stack install
    rm -fr "${TEMP}"
  )
fi
