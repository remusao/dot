#!/usr/bin/env sh

set -e

if ! [ -f "/usr/local/bin/stack" ]; then
  curl -sSL https://get.haskellstack.org/ | sh
else
  stack upgrade
  stack update
fi
