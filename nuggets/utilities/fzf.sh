#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# The man page is in the guard too: it started being installed here long after
# the binary reached the pinned version, so a version check alone never adds it.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/fzf" ] ||
  ! [ -f "${HOME}/.local/share/man/man1/fzf.1" ]; then
  NEEDS_BUILD="1"
else
  # A binary that cannot run should reinstall, not fail the whole update run.
  CURRENT_VERSION=$("${HOME}/.local/bin/fzf" --version 2>/dev/null | awk '{print $1}') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${FZF_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

# The distro fzf (noble: 0.44.1) stays reachable through any sanitized PATH
# (sudo, systemd, cron) and owns /usr/share/man/man1/fzf.1.gz, so drop it.
if dpkg -s fzf >/dev/null 2>&1; then
  sudo apt-get remove --yes fzf
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # The .deb, not the linux_amd64 tarball: the tarball is the bare binary,
    # the .deb also carries the man page. Both sit in the same checksums.txt,
    # which is unsigned for Linux assets -- integrity, not provenance.
    pkg="fzf_${FZF_VERSION}_amd64.deb"
    base="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}"
    fetch_verified "${base}/${pkg}" "${tmp}/${pkg}" \
      "${base}/fzf_${FZF_VERSION}_checksums.txt" "${pkg}"

    # Unpacked, never handed to dpkg: everything lands under ~/.local, no sudo.
    dpkg-deb -x "${tmp}/${pkg}" "${tmp}/deb"
    chmod 755 "${tmp}/deb/usr/bin/fzf"
    mv "${tmp}/deb/usr/bin/fzf" "${HOME}/.local/bin/fzf"

    # ~/.local/share/man precedes /usr/share/man in MANPATH.
    install -Dm644 "${tmp}/deb/usr/share/man/man1/fzf.1" \
      "${HOME}/.local/share/man/man1/fzf.1"

    # zshrc caches `fzf --zsh` keyed on the lock.sh pin, not on the binary, so a
    # shell opened between `git pull` and this nugget caches the OLD script
    # under the NEW version's name forever. Install is the only chance to fix.
    rm -f "${XDG_CACHE_HOME:-${HOME}/.cache}"/zsh/fzf-*.zsh
  )
fi
