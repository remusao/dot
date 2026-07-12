#!/usr/bin/env bash
# One-shot: move dead Firefox profile data to a timestamped backup for review.
# Reversible — verify Firefox still works, then delete the backup dir yourself later.
# Run with Firefox CLOSED. See ~/.claude/plans (Firefox audit) for rationale.
set -euo pipefail

FF="$HOME/.mozilla/firefox"
ACTIVE="72aryn1i.remi-esr-1773931113272"          # never touched — the live profile

if pgrep -x firefox >/dev/null; then
  echo "Firefox is running — close it first." >&2
  exit 1
fi

BAK="$HOME/.mozilla/_firefox-cleanup-$(date +%Y%m%d-%H%M%S)"   # outside the profiles dir
mkdir -p "$BAK"

# ── Back up profile registries first (so any breakage is trivially reversible) ──
cp -a "$FF/profiles.ini" "$BAK/profiles.ini.bak" 2>/dev/null || true
cp -a "$FF/installs.ini" "$BAK/installs.ini.bak" 2>/dev/null || true

# ── Stale profiles (explicit list — the active profile is deliberately absent) ──
for prof in \
  v4xpp5fw.default-release \
  4367de5d.default 6n4ce9mt.ublock fpwg4duf.search l50fjev6.ghostery \
  x9gzdm2k.matrix i7pqhm5l.remi-esr; do
  if [ -d "$FF/$prof" ]; then
    mv -v "$FF/$prof" "$BAK/$prof"
  fi
done

# ── Crash reports (283 minidumps ≈ 71 MB). Glance at them before deleting the backup. ──
if [ -d "$FF/Crash Reports/pending" ]; then
  mkdir -p "$BAK/Crash-Reports-pending"
  find "$FF/Crash Reports/pending" -mindepth 1 -maxdepth 1 -exec mv -t "$BAK/Crash-Reports-pending" {} + 2>/dev/null || true
fi

# ── Legacy saved logins in the ACTIVE profile (Proton Pass is the manager now).
#    key4.db / cert9.db are KEPT — they are also used for certificates/PKCS11. ──
for f in logins.json logins-backup.json logins.db; do
  if [ -e "$FF/$ACTIVE/$f" ]; then
    mv -v "$FF/$ACTIVE/$f" "$BAK/$f"
  fi
done

echo
echo "Moved dead data to $BAK ($(du -sh "$BAK" | cut -f1)). Delete it once Firefox checks out."
echo
echo "Left for you to do by hand (safer than filesystem edits):"
echo "  • about:addons → remove the 3 disabled Arc themes."
echo "  • The stale [Profile0]/[Install3B60…] entries in profiles.ini/installs.ini are now"
echo "    dangling but harmless (the live profile is pinned via [Install4F96…]). Prune them"
echo "    only if you want a tidy profile manager; originals are backed up in $BAK."
