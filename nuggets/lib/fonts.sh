#!/usr/bin/env bash
#
# Font installation helpers.
#
# Fonts must never be installed with a plain `cp` over an existing file. `cp`
# opens the destination O_WRONLY|O_TRUNC, so the file keeps its inode and gets
# rewritten underneath anyone holding it mmap'd -- which is every long-running
# X client that draws text (i3, i3bar, dunst, urxvt) via freetype. Their
# mappings then point at a different font's tables and the next glyph lookup
# segfaults inside libharfbuzz. That killed i3 on 2026-09-02, when update.sh
# re-copied the two JetBrainsMono faces i3/config names while the session ran.
#
# font_install renames a temp file into place instead: rename(2) is atomic and
# allocates a fresh inode, so live processes keep reading the intact old file
# until they exit. Temp names are dot-prefixed because fontconfig skips hidden
# files, making a leftover from an interrupted run harmless.
#
# Versions are tracked with stamp files rather than by asking `fc-list` whether
# a font is present. fc-list is unreliable here (~/.cache/fontconfig is shared
# with snap-shipped fontconfig builds writing a cache format the system one
# ignores, so it can under-report) and a presence check never notices a version
# bump in lock.sh, which left pinned fonts silently frozen.

FONT_DIR="${HOME}/.local/share/fonts"
FONT_STAMP_DIR="${HOME}/.local/state/dotfiles/fonts"

# font_up_to_date <name> <version> -- true when <name> is already at <version>.
font_up_to_date() {
  [ "$(cat "${FONT_STAMP_DIR}/$1" 2>/dev/null)" = "$2" ]
}

# font_stamp <name> <version> -- record <name> as installed at <version>.
font_stamp() {
  mkdir -p "${FONT_STAMP_DIR}"
  printf '%s\n' "$2" >"${FONT_STAMP_DIR}/$1"
}

# font_install <file>... -- atomically install fonts, then refresh the cache.
# No-op when given nothing, so callers can pass a filtered list unconditionally.
font_install() {
  [ "$#" -gt 0 ] || return 0

  mkdir -p "${FONT_DIR}"
  local src base tmp
  for src in "$@"; do
    base=$(basename "$src")
    tmp=$(mktemp "${FONT_DIR}/.${base}.XXXXXX")
    cp "$src" "$tmp"
    chmod 644 "$tmp" # mktemp made it 0600
    mv -f "$tmp" "${FONT_DIR}/${base}"
  done

  fc-cache -f "${FONT_DIR}"
  # The one thing atomic replacement cannot do: a process that already has a
  # font open keeps rendering the old face until it restarts. Safe, but silent.
  printf 'Fonts changed -- i3/i3bar/dunst keep the old faces until restarted\n' >&2
}
