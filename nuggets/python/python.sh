#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if [ ! -d "${HOME}/.pyenv/versions/${PYTHON_VERSION}/" ]; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  # `pyenv init` is deliberately not eval'd here. `pyenv install` needs nothing
  # but ~/.pyenv/bin, which update.sh already exports, and nuggets are *sourced*:
  # the eval would prepend ~/.pyenv/shims to update.sh's own PATH for every
  # nugget after this one. `pyenv global` is `system`, so a later `python3` would
  # then resolve through a shim to /usr/bin/python3, not the pin built below.
  PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto --enable-shared" \
  PYTHON_CFLAGS="-march=native" \
    "${HOME}/.pyenv/bin/pyenv" install --force "${PYTHON_VERSION}"
fi
