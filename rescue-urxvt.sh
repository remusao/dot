#!/usr/bin/env bash
# rescue-urxvt.sh — re-attach surviving urxvt sessions into kitty via `reptyr -T`,
# verify each, then optionally kill urxvtc/urxvtd.
#
# The target sessions are non-dumpable, so reptyr must run as ROOT (matches the
# manual `sudo reptyr -T` that worked). To avoid one password prompt per window,
# this installs a TEMPORARY, validated, reptyr-only sudoers drop-in (one prompt
# total) and removes it on ANY exit. No global ptrace_scope changes.
#
# Safety: idempotent (sessions already proxied by a live reptyr, and dead/zombie
# sessions, are skipped); every attach is verified; urxvtd is killed ONLY after
# every live window is confirmed rescued AND you type y. A failed attach never
# loses anything — reptyr fails before it touches the pty, and the script exits
# without killing urxvtd.
set -uo pipefail

KITTY="${KITTY:-$HOME/.local/bin/kitty}"
REPTYR="$(command -v reptyr || echo "$HOME/.local/bin/reptyr")"
WORKSPACE="${WORKSPACE:-4}"
SETTLE_TRIES="${SETTLE_TRIES:-12}"               # poll up to SETTLE_TRIES x 0.5s per attach
DROPIN=/etc/sudoers.d/zzz-reptyr-rescue

die() { echo "ERROR: $*" >&2; exit 1; }
[ -x "$REPTYR" ] || die "reptyr not executable at '$REPTYR' (sudo apt install reptyr)"
[ -x "$KITTY"  ] || die "kitty not executable at '$KITTY'"

# ---- detection helpers (read-only) --------------------------------------------
declare -A RESCUED_PTS=()
refresh_rescued_pts() {                          # pts already proxied by a live `reptyr -T <pid>`
  RESCUED_PTS=()
  local pid args tgt t
  for pid in $(pgrep -x reptyr 2>/dev/null); do
    args=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
    tgt=$(awk '{for(i=1;i<=NF;i++) if($i=="-T") print $(i+1)}' <<<"$args")
    [ -n "$tgt" ] || continue
    t=$(ps -o tty= -p "$tgt" 2>/dev/null | tr -d ' ')
    case "$t" in pts/*) RESCUED_PTS[${t#pts/}]=1 ;; esac
  done
}
list_targets() {                                 # LIVE, non-zombie, not-yet-rescued urxvtd windows
  local d sl st tty ptsn fg desc
  for d in $(pgrep -x urxvtd 2>/dev/null); do
    for sl in $(pgrep -P "$d" 2>/dev/null); do
      st=$(ps -o stat= -p "$sl" 2>/dev/null)
      case "$st" in Z*|"") continue ;; esac
      tty=$(ps -o tty= -p "$sl" 2>/dev/null | tr -d ' ')
      case "$tty" in pts/*) ptsn=${tty#pts/} ;; *) continue ;; esac
      [ -n "${RESCUED_PTS[$ptsn]:-}" ] && continue
      fg=$(pgrep -P "$sl" 2>/dev/null | head -1)
      desc=$(tr '\0' ' ' < /proc/"${fg:-$sl}"/cmdline 2>/dev/null | cut -c1-45)
      [ -n "$desc" ] || desc="(idle shell)"
      printf '%s\t%s\t%s\n' "$sl" "$tty" "$desc"
    done
  done
}
attached() {                                     # is a real reptyr proxying pid $1?
  local pid args
  for pid in $(pgrep -x reptyr 2>/dev/null); do
    args=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
    case " $args " in *" -T $1 "*) return 0 ;; esac
  done
  return 1
}

# ---- temporary passwordless-reptyr authorization (removed on any exit) --------
installed=0 cleaned=0
cleanup() { [ "$cleaned" = 1 ] && return 0; cleaned=1
            [ "$installed" = 1 ] && sudo rm -f "$DROPIN" 2>/dev/null; return 0; }
trap 'cleanup; exit 130' INT TERM
trap cleanup EXIT

# ---- 1. survey ----------------------------------------------------------------
mapfile -t DAEMONS < <(pgrep -x urxvtd)
[ "${#DAEMONS[@]}" -gt 0 ] || { echo "No urxvtd running — nothing to do."; exit 0; }
refresh_rescued_pts
mapfile -t TARGETS < <(list_targets)

echo "urxvtd: ${DAEMONS[*]}    already rescued: ${#RESCUED_PTS[@]}    to rescue: ${#TARGETS[@]}"
if [ "${#TARGETS[@]}" -gt 0 ]; then
  for t in "${TARGETS[@]}"; do IFS=$'\t' read -r p pts d <<<"$t"; printf "   %-8s %-7s %s\n" "$p" "$pts" "$d"; done
  read -rp "Re-attach these into kitty (workspace $WORKSPACE)? [y/N] " a
  [ "$a" = y ] || die "aborted"

  # ---- 2. authorize passwordless reptyr (validate in a temp file FIRST) -------
  U=$(id -un)
  tmp=$(mktemp) || die "mktemp failed"
  printf '%s ALL=(root) NOPASSWD: %s\n' "$U" "$REPTYR" > "$tmp"
  echo "Authorizing passwordless reptyr for this run (one sudo prompt)..."
  sudo visudo -cf "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; die "generated sudoers rule failed validation"; }
  sudo install -m 0440 -o root -g root "$tmp" "$DROPIN" || { rm -f "$tmp"; die "could not install drop-in"; }
  rm -f "$tmp"; installed=1
  probe=$(sudo -n "$REPTYR" --help 2>&1 || true)
  case "$probe" in *"password is required"*|*"not allowed"*|*"may not run"*)
    die "passwordless reptyr not in effect: $probe" ;; esac

  command -v i3-msg >/dev/null && i3-msg -q "workspace --no-auto-back-and-forth $WORKSPACE" 2>/dev/null

  # ---- 3. attach + verify each (serialized) -----------------------------------
  declare -a FAIL=()
  for t in "${TARGETS[@]}"; do
    IFS=$'\t' read -r p pts d <<<"$t"
    printf "   %-8s %-7s %-42s ... " "$p" "$pts" "$d"
    if ! kill -0 "$p" 2>/dev/null; then echo "gone (exited)"; continue; fi
    "$KITTY" --class rescue-kitty --title "rescue:$p" --hold sudo -n "$REPTYR" -T "$p" >/dev/null 2>&1 &
    ok=0
    for ((i=0; i<SETTLE_TRIES; i++)); do sleep 0.5; if attached "$p"; then ok=1; break; fi; done
    [ "$ok" = 1 ] && { sleep 1; attached "$p" || ok=0; }     # re-confirm it didn't die mid-steal
    if [ "$ok" = 1 ]; then echo "OK"; else echo "FAILED"; FAIL+=("$p"$'\t'"$d"); fi
  done

  if [ "${#FAIL[@]}" -gt 0 ]; then
    echo
    echo "${#FAIL[@]} session(s) did NOT attach (their kitty windows show the error):"
    for f in "${FAIL[@]}"; do IFS=$'\t' read -r p d <<<"$f"; printf "   %-8s %s\n" "$p" "$d"; done
    echo "urxvtd left running so nothing is lost. Fix the cause and re-run (rescued ones are skipped)."
    exit 1
  fi
fi

# ---- 4. clean up urxvt (only when no live window remains unrescued) ------------
refresh_rescued_pts
mapfile -t LEFT < <(list_targets)
if [ "${#LEFT[@]}" -gt 0 ]; then
  echo
  echo "WARNING — these urxvt windows are still LIVE and NOT rescued:"
  for t in "${LEFT[@]}"; do IFS=$'\t' read -r p pts d <<<"$t"; printf "   %-8s %-7s %s\n" "$p" "$pts" "$d"; done
  read -rp "Killing urxvtd will lose them. Kill anyway? [y/N] " k
else
  read -rp "All live sessions are rescued. Kill urxvtc/urxvtd now? [y/N] " k
fi
[ "$k" = y ] || { echo "Left urxvtd running (rescued sessions are safe regardless)."; exit 0; }

echo "Killing urxvtc/urxvtd..."
pkill -x urxvtc 2>/dev/null || true
pkill -x urxvtd 2>/dev/null || true
sleep 0.5
pgrep -x urxvtd >/dev/null && { pkill -9 -x urxvtd 2>/dev/null || true; sleep 0.3; }
if pgrep -x urxvtd >/dev/null; then echo "urxvtd still present — check manually."
else echo "Done — urxvtd gone, fully on kitty."; fi
