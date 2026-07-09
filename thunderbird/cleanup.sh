#!/usr/bin/env bash
# One-shot: move dead Thunderbird profile files to a timestamped backup for review.
# Reversible — verify TB still works, then delete the backup dir yourself later.
# Run with Thunderbird CLOSED. See ~/.claude/plans (Thunderbird audit) for rationale.
set -euo pipefail

PROFILE="$HOME/.thunderbird/x830uo0l.default"
if pgrep -x thunderbird >/dev/null; then
  echo "Thunderbird is running — close it first." >&2
  exit 1
fi

BAK="$HOME/.thunderbird/_cleanup-$(date +%Y%m%d-%H%M%S)"   # sibling, not inside the profile
mkdir -p "$BAK"

# ACTIVE — never listed here: abook.sqlite, abook-1.sqlite, history.sqlite, global-messages-db.sqlite
# 'logs' + 'otr.private_key' are Matrix/chat leftovers — only after removing the Chat account in the UI.
for f in \
  global-messages-db.sqlite.bkp pepmda logs otr.private_key enigmail.sqlite kinto.sqlite \
  blocklist.xml webappsstore.sqlite storage.sdb pluginreg.dat folderTree-1.json directoryTree.json \
  abook.v2.sqlite abook.v3.sqlite abook-1.v2.sqlite abook-1.v3.sqlite history.v2.sqlite history.v3.sqlite \
  abook.mab.bak abook-1.mab.bak history.mab.bak calendar-data/cache.sqlite calendar-data/deleted.sqlite; do
  if [ -e "$PROFILE/$f" ]; then
    mkdir -p "$BAK/$(dirname "$f")"
    mv -v "$PROFILE/$f" "$BAK/$f"
  fi
done

echo "Moved dead files to $BAK ($(du -sh "$BAK" | cut -f1)). Delete it once TB checks out."
