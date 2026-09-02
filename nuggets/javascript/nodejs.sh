#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# install.sh checks the pinned tag out as a git working copy, so `git describe`
# is the installed version. A `[ ! -d ~/.nvm ]` guard leaves NVM_VERSION inert.
NEEDS_BUILD="0"
if [ "$(git -C "${HOME}/.nvm" describe --tags --abbrev=0 2>/dev/null || true)" != "${NVM_VERSION}" ]; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # A git blob, not a release asset: no checksum manifest exists to verify
    # against, so TLS plus the pinned tag is the ceiling.
    curl_fetch "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
      "${tmp}/install.sh"
    # PROFILE=/dev/null: else it appends loader lines to .zshrc (a repo symlink).
    PROFILE=/dev/null bash "${tmp}/install.sh"
  )
fi

# --no-use: a bare `. nvm.sh` runs `nvm use default`, which drifts stale.
. "${HOME}/.nvm/nvm.sh" --no-use

# No --reinstall-packages-from: packages.sh owns the global CLIs via `npm ci`,
# and zshrc ranks nvm's bin dir above ~/.local/bin, so carried-over unpinned
# copies shadow the locked ones. nvm writes `default` only when absent.
# nvm checks the tarball against nodejs.org's own SHASUMS256.txt -- integrity,
# not provenance (same origin as the download).
nvm install "${NODEJS_VERSION}"
nvm alias default "${NODEJS_VERSION}"
nvm use "${NODEJS_VERSION}"

nvm cache clear
