#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/alacritty" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/alacritty" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${ALACRITTY_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

# One-time migration: previous installs left binaries at ~/.cargo/bin (cargo
# install) and/or /usr/bin (apt). ~/.cargo/bin is earlier in PATH than
# ~/.local/bin, so the stale binary would shadow the new one.
if [ -f "${HOME}/.cargo/bin/alacritty" ]; then
  rm -f "${HOME}/.cargo/bin/alacritty"
fi
if dpkg -s alacritty >/dev/null 2>&1; then
  sudo apt-get remove --yes alacritty
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    TEMP=$(mktemp -d)
    trap 'rm -rf "$TEMP"' EXIT
    git clone --depth=1 --branch "v${ALACRITTY_VERSION}" \
      https://github.com/alacritty/alacritty.git "${TEMP}"
    cd "${TEMP}"

    # Native CPU tuning. Upstream Cargo.toml release profile already sets
    # lto="thin", debug=1, incremental=false. X11-only feature set drops
    # Wayland deps (winit/wayland, glutin/wayland, copypasta/wayland, csd-adwaita).
    RUSTFLAGS="-C target-cpu=native" \
      cargo build --release --locked --no-default-features --features=x11

    install -Dm755 target/release/alacritty "${HOME}/.local/bin/alacritty"

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
    if command -v scdoc >/dev/null 2>&1; then
      for f in extra/man/*.scd; do
        name=$(basename "$f" .scd)
        section="${name##*.}"
        install -d "${HOME}/.local/share/man/man${section}"
        scdoc < "$f" | gzip -c \
          > "${HOME}/.local/share/man/man${section}/${name}.gz"
      done
    fi

    update-desktop-database "${HOME}/.local/share/applications/" 2>/dev/null || true
  )
fi
