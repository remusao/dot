#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.cargo/bin/rg" ]; then
  NEEDS_BUILD="1"
else
  # An rg that exists but cannot run (soname bump, truncated binary) must mean
  # "rebuild"; unguarded it would abort update.sh's whole run instead.
  CURRENT_VERSION=$("${HOME}/.cargo/bin/rg" --version 2>/dev/null | head -n 1 || true)
  if [ "${CURRENT_VERSION}" != "ripgrep ${RIPGREP_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
  # The version pin cannot see a flavour change: an rg at the right version may
  # still be an old build dynamically linked against Ubuntu's libpcre2.
  if ldd "${HOME}/.cargo/bin/rg" 2>/dev/null | grep -q 'libpcre2-8'; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  # --version is what makes the pin real: without it cargo installs crates.io's
  # newest and the guard above never converges. release-lto is upstream's own
  # profile (plain release keeps debug = 1, i.e. tens of MB of DWARF), and
  # PCRE2_SYS_STATIC vendors PCRE2 so distro libpcre2 churn cannot break rg -P.
  PCRE2_SYS_STATIC="1" RUSTFLAGS="-C target-cpu=native" \
    cargo install ripgrep --version "${RIPGREP_VERSION}" --locked \
    --features pcre2 --profile release-lto
fi

# cargo install places only the binary. Outside the guard so a missing page
# converges on the next run, not the next version bump.
install -d "${HOME}/.local/share/man/man1" "${HOME}/.zsh_functions"
"${HOME}/.cargo/bin/rg" --generate man | gzip -c \
  > "${HOME}/.local/share/man/man1/rg.1.gz"
"${HOME}/.cargo/bin/rg" --generate complete-zsh > "${HOME}/.zsh_functions/_rg"
