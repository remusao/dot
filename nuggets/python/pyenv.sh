#!/usr/bin/env bash

set -e

# Pinned to a tag, not master: python-build's CPython recipes ship in this tree,
# so a floating pyenv floats the recipe python.sh builds PYTHON_VERSION from.
# No upstream signatures or release assets: integrity is the tag and git's
# content addressing, provenance is TLS alone.
NEEDS_BUILD="0"
if [ ! -d "${HOME}/.pyenv/.git" ]; then
  NEEDS_BUILD="1"
else
  # `pyenv --version` is git-describe derived: bare "2.8.5" only when on the tag.
  CURRENT_VERSION=$("${HOME}/.pyenv/bin/pyenv" --version 2>/dev/null | awk '{print $2}') ||
    CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${PYENV_RELEASE#v}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  if [ ! -d "${HOME}/.pyenv/.git" ]; then
    git clone --depth=1 --branch "${PYENV_RELEASE}" \
      https://github.com/pyenv/pyenv.git "${HOME}/.pyenv"
  else
    # Name the tag explicitly: an explicit refspec disables tag auto-following,
    # so `git pull origin master` leaves the tree tagless and its version stale.
    (cd "${HOME}/.pyenv" \
      && git fetch --depth=1 origin tag "${PYENV_RELEASE}" \
      && git checkout --detach --force "${PYENV_RELEASE}")
  fi
fi

# Optional C realpath builtin; keyed on the artifact too so a failed or wiped
# build self-heals. Upstream says failure is fine, so never abort.
if [ "${NEEDS_BUILD}" = "1" ] || [ ! -f "${HOME}/.pyenv/libexec/pyenv-realpath.dylib" ]; then
  (cd "${HOME}/.pyenv" && src/configure && make -C src) >/dev/null 2>&1 || true
fi

# PYTHON_VERSION and PYENV_RELEASE move together: a bumped Python may have no
# recipe in the pinned tree, and python-build's own "git pull" hint is wrong here.
if [ ! -f "${HOME}/.pyenv/plugins/python-build/share/python-build/${PYTHON_VERSION}" ]; then
  printf 'pyenv %s ships no python-build recipe for Python %s -- bump PYENV_RELEASE too\n' \
    "${PYENV_RELEASE}" "${PYTHON_VERSION}" >&2
  # `return`, not `exit`: sourced file, so `exit` would kill update.sh silently
  # past its ERR trap. A non-zero return makes the `.` fail normally.
  return 1
fi
