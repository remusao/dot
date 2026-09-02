#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/alacritty" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/alacritty" --version 2>/dev/null | awk '{print $2}') ||
    CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${ALACRITTY_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

# The binary version says nothing about the assets that come out of the source
# tree, so a missing terminfo/completion/desktop/icon/man file needs a re-clone.
NEEDS_ASSETS="0"
infocmp -A "${HOME}/.terminfo" alacritty >/dev/null 2>&1 || NEEDS_ASSETS="1"
for artifact in \
  "${HOME}/.zsh_functions/_alacritty" \
  "${HOME}/.local/share/applications/Alacritty.desktop" \
  "${HOME}/.local/share/icons/hicolor/scalable/apps/Alacritty.svg" \
  "${HOME}/.local/share/man/man1/alacritty.1.gz"; do
  [ -e "${artifact}" ] || NEEDS_ASSETS="1"
done

# One-time migration: previous installs left binaries at ~/.cargo/bin (cargo
# install) and/or /usr/bin (apt). ~/.cargo/bin is earlier in PATH than
# ~/.local/bin, so the stale binary would shadow the new one.
if [ -f "${HOME}/.cargo/bin/alacritty" ]; then
  rm -f "${HOME}/.cargo/bin/alacritty"
fi
if dpkg -s alacritty >/dev/null 2>&1; then
  sudo apt-get remove --yes alacritty
fi

if [ "${NEEDS_BUILD}" = "1" ] || [ "${NEEDS_ASSETS}" = "1" ]; then
  # Resolved before the subshell cds away from the repo-relative BASH_SOURCE path.
  ALACRITTY_KEY=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../lib/keys/alacritty.asc")

  (
    TEMP=$(mktemp -d)
    trap 'rm -rf "$TEMP"' EXIT
    git clone --depth=1 --branch "v${ALACRITTY_VERSION}" \
      https://github.com/alacritty/alacritty.git "${TEMP}"
    cd "${TEMP}"

    # TLS alone would let a hijacked account or a terminating proxy hand us
    # arbitrary Rust to compile. Key pinned locally, as in kitty.sh.
    verify_git_tag "v${ALACRITTY_VERSION}" "${ALACRITTY_KEY}" \
      4DAA67A9EA8B91FCC15B699C85CDAE3C164BA7B4

    if [ "${NEEDS_BUILD}" = "1" ]; then
      # Native CPU tuning. Upstream Cargo.toml release profile already sets
      # lto="thin", debug=1, incremental=false. X11-only feature set drops
      # Wayland deps (winit/wayland, glutin/wayland, copypasta/wayland, csd-adwaita).
      RUSTFLAGS="-C target-cpu=native" \
        cargo build --release --locked --no-default-features --features=x11
    fi

    # Terminfo (user-local at ~/.terminfo, takes precedence over /usr/share/terminfo).
    tic -xe alacritty,alacritty-direct -o "${HOME}/.terminfo" extra/alacritty.info

    # Zsh completion (fpath wired up in zshrc).
    install -Dm644 extra/completions/_alacritty \
      "${HOME}/.zsh_functions/_alacritty"

    # Desktop entry + scalable icon.
    install -Dm644 extra/linux/Alacritty.desktop \
      "${HOME}/.local/share/applications/Alacritty.desktop"
    install -Dm644 extra/logo/alacritty-term.svg \
      "${HOME}/.local/share/icons/hicolor/scalable/apps/Alacritty.svg"

    # Man pages (scdoc compiles .scd; section parsed from filename suffix).
    # No `command -v` guard: scdoc is an apt dep, and skipping would leave the
    # artifact probe re-cloning every run.
    for f in extra/man/*.scd; do
      name=$(basename "$f" .scd)
      section="${name##*.}"
      install -d "${HOME}/.local/share/man/man${section}"
      scdoc < "$f" | gzip -c \
        > "${HOME}/.local/share/man/man${section}/${name}.gz"
    done

    update-desktop-database "${HOME}/.local/share/applications/" 2>/dev/null || true

    # Binary last: it is the marker the version check reads, so a failure above
    # must not read as a completed install.
    if [ "${NEEDS_BUILD}" = "1" ]; then
      install -Dm755 target/release/alacritty "${HOME}/.local/bin/alacritty"
    fi
  )
fi
