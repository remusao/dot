#!/usr/bin/env sh

set -e

export PKG=eslint-config-airbnb
npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest"
npm install -g eslint_d@latest
