#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/sccache" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(sccache --version)
  if [ "${CURRENT_VERSION}" != "sccache ${SCCACHE}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  DIRECTORY="sccache-${SCCACHE}-x86_64-unknown-linux-musl"
  ARCHIVE="${DIRECTORY}.tar.gz"
  wget "https://github.com/mozilla/sccache/releases/download/${SCCACHE}/${ARCHIVE}"
  tar xvf "${ARCHIVE}"
  mv "${DIRECTORY}/sccache" /home/remi/.local/bin/
  rm -frv "${ARCHIVE}" "${DIRECTORY}"
fi
