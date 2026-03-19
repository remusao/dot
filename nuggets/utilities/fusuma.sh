#!/usr/bin/env bash

set -e

NEEDS_INSTALL="0"
CURRENT_VERSION=$(gem list fusuma --exact 2>/dev/null | grep -oP '\(\K[0-9.]+' || echo "")
if [ -z "${CURRENT_VERSION}" ]; then
  NEEDS_INSTALL="1"
elif [ "${CURRENT_VERSION}" != "${FUSUMA_VERSION}" ]; then
  NEEDS_INSTALL="1"
fi

if [ "${NEEDS_INSTALL}" = "1" ]; then
  sudo gem install fusuma -v "${FUSUMA_VERSION}"
fi
