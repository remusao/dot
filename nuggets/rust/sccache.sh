#!/usr/bin/env bash

set -e

# Probe inside the `if` rather than assigning a command substitution: under
# update.sh's `set -e`, a binary that exists but cannot run (soname-bumped
# libssl, a truncated install) would abort the whole run before reaching the
# rebuild that fixes it. Here a broken binary just means NEEDS_BUILD=1.
NEEDS_BUILD="0"
if ! "${HOME}/.cargo/bin/sccache" --version 2>/dev/null | grep -qFx "sccache ${SCCACHE_VERSION}"; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  # Without --version cargo resolves crates.io latest and the lock pin is
  # decorative; worse, once installed > pin the check above never passes again
  # and cargo answers "already installed" with exit 0 on every run.
  cargo install sccache --version "${SCCACHE_VERSION}" --locked
  # The server is a long-lived daemon and the protocol carries no version
  # handshake, so one left running keeps serving the old binary's code until it
  # idles out. Stop it after the swap; the next invocation starts the new one.
  "${HOME}/.cargo/bin/sccache" --stop-server >/dev/null 2>&1 || true
fi
