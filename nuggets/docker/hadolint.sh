#!/usr/bin/env sh

set -e

TEMP=/tmp/hadolint
(
  rm -fr "${TEMP}"
  mkdir "${TEMP}"
  git clone --depth=1 --branch "${HADOLINT}" git@github.com:hadolint/hadolint.git "${TEMP}"
  cd "${TEMP}" || exit 1
  stack install
  rm -fr "${TEMP}"
)
