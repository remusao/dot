#!/usr/bin/env bash

set -e

if [ ! -d "${HOME}/.nvm" ]; then
  curl -fo- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export TMPDIR="${TMPDIR:-/tmp}"
. "${HOME}/.nvm/nvm.sh"
# --reinstall-packages-from carries global CLIs (npm + language servers) across a
# Node bump; falls back to a plain install on first run (no "current" version yet).
nvm install "${NODEJS_VERSION}" --reinstall-packages-from=current || nvm install "${NODEJS_VERSION}"
