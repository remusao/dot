#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -d "/home/remi/.go" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(go version)
  if [ "${CURRENT_VERSION}" != "go version go${GO} linux/amd64" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -LO "https://get.golang.org/$(uname)/go_installer" && chmod +x go_installer && ./go_installer && rm go_installer
fi
