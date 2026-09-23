#!/usr/bin/env bash
# restore.sh - Restore from encrypted restic backup
#
# Restores home directory and system configuration from tagged restic
# snapshots. Optionally reinstalls packages from saved lists.
#
# Usage:
#   restore.sh <repository> [OPTIONS]
#
# Options:
#   -n, --dry-run       Show what would be restored without restoring
#   -s, --snapshot ID   Snapshot to restore (default: latest)
#   --home-only         Only restore home snapshot
#   --system-only       Only restore system snapshot (requires sudo)
#   --list              List available snapshots and exit
#   --packages          Reinstall packages from saved lists
#   -t, --target DIR    Restore root directory (default: ~/.dot/restore)
#   -h, --help          Show help
#
# Environment:
#   RESTIC_PASSWORD or RESTIC_PASSWORD_FILE or RESTIC_PASSWORD_COMMAND

set -uo pipefail

# --- Constants ---
BACKUP_DIR="$HOME/.dot/backup"
SELF="$(realpath -- "${BASH_SOURCE[0]}")"
LOG_DIR="$HOME/.dot/logs"
# $'...' so the escapes are real bytes: these are passed as printf %s arguments.
BOLD=$'\033[1m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# Restoring these over a running system replaces machine identity with the backed-up
# machine's. /etc/crypttab is the dangerous one: it names the OLD LUKS UUID, and the
# very next initramfs rebuild (which `--packages` itself triggers) bakes that in and
# leaves the machine unbootable.
INPLACE_EXCLUDES=(
    /etc/crypttab
    /etc/fstab
    /etc/machine-id
    /var/lib/tailscale
    /boot                # older snapshots captured it: an old initramfs has the old UUID baked in
    /etc/lvm/backup      # the OLD volume group's metadata; a later vgcfgrestore would use it
    /etc/lvm/archive
)

# --- Defaults ---
DRY_RUN=false
SNAPSHOT=""
HOME_ONLY=false
SYSTEM_ONLY=false
LIST_ONLY=false
INSTALL_PACKAGES=false
ASSUME_YES=false
TARGET="$HOME/.dot/restore"
REPO=""
IN_PLACE=false
NEED_SUDO=false
SNAP_HOST=""

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage: restore.sh <repository> [OPTIONS]

Restore from encrypted restic backup. Restores tagged snapshots:
  - "home"   : home directory
  - "system" : system configuration paths (requires sudo)

Options:
  -n, --dry-run       Show what would be restored without restoring
  -s, --snapshot ID   Snapshot to restore. Requires --home-only or --system-only,
                      because one ID cannot denote both snapshots.
  --home-only         Only restore home snapshot
  --system-only       Only restore system snapshot (requires sudo)
  --list              List available snapshots and exit
  --packages          Reinstall packages. Only valid with -t / (it changes the
                      RUNNING system's packages, whatever --target says).
  -t, --target DIR    Restore root directory (default: ~/.dot/restore)
  -H, --host NAME     Restore snapshots taken on NAME (default: this machine's
                      hostname, or the only host in the repository)
  -y, --yes           Skip the confirmation prompt (for non-interactive use)
  -h, --help          Show this help

DEFAULT: restores into a staging directory (~/.dot/restore) so you can inspect and
copy across by hand. Nothing on the live system is touched.

  -t /  restores IN PLACE, overwriting the running system. In that mode these are
        never restored, because they carry the old machine's identity:
          /etc/crypttab  /etc/fstab  /etc/machine-id  /var/lib/tailscale
          /boot  /etc/lvm/backup  /etc/lvm/archive  (and this script itself)

Environment:
  RESTIC_PASSWORD          Repository password
  RESTIC_PASSWORD_FILE     Path to file containing password
  RESTIC_PASSWORD_COMMAND  Command that prints password

Examples:
  restore.sh /mnt/external/repo --list                List snapshots
  restore.sh /mnt/external/repo                       Stage to ~/.dot/restore/  (default)
  restore.sh /mnt/external/repo --home-only           Stage home only
  restore.sh /mnt/external/repo -s abc123 --home-only Stage one specific snapshot
  restore.sh /mnt/external/repo -n                    Dry run
  restore.sh /mnt/external/repo -t /                  Restore IN PLACE (overwrites)
  restore.sh /mnt/external/repo -t / --packages       ... and reinstall packages
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)     DRY_RUN=true; shift ;;
        -s|--snapshot)    SNAPSHOT="${2:?--snapshot requires an argument}"; shift 2 ;;
        --home-only)      HOME_ONLY=true; shift ;;
        --system-only)    SYSTEM_ONLY=true; shift ;;
        --list)           LIST_ONLY=true; shift ;;
        --packages)       INSTALL_PACKAGES=true; shift ;;
        -t|--target)      TARGET="${2:?--target requires an argument}"; shift 2 ;;
        -H|--host)        SNAP_HOST="${2:?--host requires an argument}"; shift 2 ;;
        -y|--yes)         ASSUME_YES=true; shift ;;
        -h|--help)        usage 0 ;;
        --)               shift; break ;;
        -*)               printf '%sUnknown option: %s%s\n' "$RED" "$1" "$NC" >&2; exit 1 ;;
        *)
            if [[ -n "$REPO" ]]; then
                printf '%sError: unexpected argument %s%s\n' "$RED" "$1" "$NC" >&2; exit 1
            fi
            REPO="$1"; shift ;;
    esac
done
if [[ -z "$REPO" && $# -gt 0 ]]; then REPO="$1"; shift; fi

if [[ -z "$REPO" ]]; then
    printf '%sError: no repository specified%s\n' "$RED" "$NC" >&2
    usage 1
fi

if $HOME_ONLY && $SYSTEM_ONLY; then
    printf '%sError: --home-only and --system-only are mutually exclusive%s\n' "$RED" "$NC" >&2
    exit 1
fi

# One snapshot ID cannot denote both of the two snapshots a backup produces. Without
# this, `-s <home-id>` restored the home tree twice — once as "home", once as
# "system", the second time through sudo — and reported both as restored.
if [[ -n "$SNAPSHOT" ]] && ! $HOME_ONLY && ! $SYSTEM_ONLY && ! $LIST_ONLY; then
    printf '%sError: -s/--snapshot needs --home-only or --system-only.%s\n' "$RED" "$NC" >&2
    printf 'A single snapshot ID is either the home snapshot or the system one, not both.\n' >&2
    exit 1
fi

# --packages changes the packages of the RUNNING system: there is no chroot and no
# apt --root here, so $TARGET has no effect on it.
if $INSTALL_PACKAGES && [[ "$(realpath -m -- "$TARGET")" != "/" ]]; then
    printf '%sError: --packages installs into the RUNNING system, not %s.%s\n' "$RED" "$TARGET" "$NC" >&2
    printf 'Use it only with -t /, or install by hand after inspecting the staged tree.\n' >&2
    exit 1
fi

# Is this an in-place restore? Everything dangerous keys off this.
[[ "$(realpath -m -- "$TARGET")" == "/" ]] && IN_PLACE=true

# --- Logging setup ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/restore-$(date '+%Y-%m-%dT%H%M%S')-$$.log"
exec 8>&2                              # the real terminal, for reporting past a dead tee
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Signal trap ---
cleanup_on_exit() {
    local rc="$1"
    # A signal to the process group (Ctrl-C, closing the terminal) can kill `tee`
    # first, and a write into that dead pipe would SIGPIPE us mid-report. So: ignore
    # PIPE, append to the log directly, and write to the terminal saved in fd 8
    # rather than through the pipe. Reported once, here, for every exit path.
    trap '' PIPE
    if [[ $rc -ne 0 ]]; then
        local msg
        msg="$(printf '%sRestore interrupted or failed (exit code %d). Check log: %s%s' \
            "$RED" "$rc" "$LOG_FILE" "$NC")"
        printf '\n%s\n' "$msg" >>"$LOG_FILE" 2>/dev/null
        printf '\n%s\n' "$msg" >&8 2>/dev/null
    fi
    exit "$rc"
}
# The EXIT trap does run on INT/TERM/HUP, but it sees $? == 0 there, so the signal
# handlers only record the conventional status and let the EXIT trap report it.
trap 'cleanup_on_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# --- Helper functions ---
log() {
    printf '%s[%s]%s %s\n' "$CYAN" "$(date '+%H:%M:%S')" "$NC" "$1"
}

check_restic() {
    if ! command -v restic >/dev/null 2>&1; then
        printf '%sError: restic is not installed.%s\n' "$RED" "$NC" >&2
        printf "Install with: sudo apt install restic\n" >&2
        exit 1
    fi
}

check_password() {
    if [[ -z "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD_COMMAND:-}" ]]; then
        printf '%sError: no restic password configured.%s\n' "$RED" "$NC" >&2
        printf "Set RESTIC_PASSWORD, RESTIC_PASSWORD_FILE, or RESTIC_PASSWORD_COMMAND.\n" >&2
        exit 1
    fi
}

# Run restic under sudo, forwarding only the active password env var.
# Uses --preserve-env to keep credentials out of the process list.
sudo_restic() {
    local preserve=()
    [[ -n "${RESTIC_PASSWORD:-}" ]] && preserve+=(--preserve-env=RESTIC_PASSWORD)
    [[ -n "${RESTIC_PASSWORD_FILE:-}" ]] && preserve+=(--preserve-env=RESTIC_PASSWORD_FILE)
    [[ -n "${RESTIC_PASSWORD_COMMAND:-}" ]] && preserve+=(--preserve-env=RESTIC_PASSWORD_COMMAND)
    sudo "${preserve[@]}" "$(command -v restic)" "$@"
}

confirm() {
    local msg="$1"
    if $ASSUME_YES; then
        printf '%s%s%s [auto-yes]\n' "$YELLOW" "$msg" "$NC"
        return 0
    fi
    # Without a controlling terminal the redirect fails and `read` never runs, so
    # `answer` must be pre-set or `set -u` kills the script with a bare bash error.
    local answer=""
    if ! { printf '%s%s%s [y/N] ' "$YELLOW" "$msg" "$NC" > /dev/tty; } 2>/dev/null; then
        printf '%sNo terminal available for confirmation. Re-run with --yes to proceed.%s\n' \
            "$RED" "$NC" >&2
        return 2    # distinct from a user saying "no"
    fi
    read -r answer < /dev/tty || true
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Resolve exactly one snapshot ID for a tag. --group-by host,tags is required:
# backup_system's path list is conditional, so with the default host,paths grouping
# `--latest 1` legitimately returns MORE than one snapshot and the first is not
# necessarily the newest.
# Which host's snapshots to restore. A bare-metal restore runs on a reinstalled
# machine whose hostname need not match the one that took the backup, so filtering on
# $(hostname) alone found nothing. Order: --host, else this hostname if the repository
# has it, else the only host present, else stop and list them.
resolve_host() {
    [[ -n "$SNAP_HOST" ]] && return 0
    local hosts
    hosts="$(restic snapshots --repo "$REPO" --json 2>/dev/null \
        | python3 -c 'import sys,json
for h in sorted({s["hostname"] for s in json.load(sys.stdin)}): print(h)' 2>/dev/null)"
    if [[ -z "$hosts" ]]; then
        return 0                      # empty or unreadable repo; resolve_snapshot reports it
    elif grep -qxF -- "$(hostname)" <<< "$hosts"; then
        SNAP_HOST="$(hostname)"
    elif [[ "$(wc -l <<< "$hosts")" -eq 1 ]]; then
        SNAP_HOST="$hosts"
        log "This machine is $(hostname); restoring snapshots from host $SNAP_HOST"
    else
        printf '%sError: the repository holds snapshots from several hosts; pick one with --host:%s\n' "$RED" "$NC" >&2
        sed 's/^/  /' <<< "$hosts" >&2
        exit 1
    fi
}

resolve_snapshot() {
    local tag="$1"
    if [[ -n "$SNAPSHOT" ]]; then
        printf '%s' "$SNAPSHOT"
        return 0
    fi
    restic snapshots --repo "$REPO" --tag "$tag" ${SNAP_HOST:+--host "$SNAP_HOST"} \
        --group-by host,tags --latest 1 --json 2>/dev/null \
        | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(1)
if isinstance(d,list) and d and isinstance(d[0],dict) and "snapshots" in d[0]:
    d=d[0]["snapshots"]
if not d: sys.exit(1)
print(sorted(d,key=lambda s:s["time"])[-1]["id"])' 2>/dev/null
}

# Confirm a resolved ID really carries the tag we think it does. With an explicit ID
# restic silently ignores --tag, so nothing else catches `-s <home-id> --system-only`.
snapshot_has_tag() {
    local id="$1" tag="$2"
    restic snapshots --repo "$REPO" "$id" --json 2>/dev/null \
        | python3 -c "import sys,json
d=json.load(sys.stdin)
sys.exit(0 if d and '$tag' in (d[0].get('tags') or []) else 1)" 2>/dev/null
}

show_snapshot_contents() {
    local tag="$1" id="$2"
    log "Preview of $tag snapshot (${id:0:8}):"
    restic ls "$id" --repo "$REPO" 2>/dev/null | head -20 || true
    printf "  ... (full listing: restic ls --repo %s %s)\n" "$REPO" "${id:0:8}"
}

# One implementation for both halves. They were duplicated, which is why the
# snapshot-selection bug existed in two places.
restore_tag() {
    local tag="$1" id="$2"
    # Root is needed to recreate root-owned files, but a dry run writes nothing, so it
    # reads the repository as the invoking user and never prompts for a password.
    local -a pre=()
    if $NEED_SUDO && ! $DRY_RUN; then pre=(sudo_restic); fi

    log "Restoring $tag snapshot ${id:0:8}$([[ ${#pre[@]} -gt 0 ]] && echo ' (requires sudo)')..."

    local restic_args=(
        restore "$id"
        --repo "$REPO"
        --target "$TARGET"
        --sparse
        --verbose
    )
    # --verbose=2 is what actually lists files in a dry run; plain --verbose gives a
    # summary only.
    $DRY_RUN && restic_args+=(--dry-run --verbose=2)

    # In-place only: keep the running machine's identity files.
    if $IN_PLACE; then
        local x
        for x in "${INPLACE_EXCLUDES[@]}"; do
            restic_args+=(--exclude "$x")
        done
        # Never rewrite this script out from under the running shell: restic
        # overwrites files in place (same inode), and bash reads scripts by byte
        # offset, so it would resume mid-command in freshly-written bytes. Only this
        # file — the rest of ~/.dot, including the backup/ manifests that --packages
        # reads, must be restored.
        restic_args+=(--exclude "$SELF")
    fi

    if [[ ${#pre[@]} -gt 0 ]]; then
        "${pre[@]}" "${restic_args[@]}"
    else
        restic "${restic_args[@]}"
    fi
    local rc=$?
    [[ $rc -eq 130 ]] && exit 130      # Ctrl-C: restic handled it and exited 130
    if [[ $rc -ne 0 ]]; then
        printf '%sError: %s restore failed (exit code %d)%s\n' "$RED" "$tag" "$rc" "$NC" >&2
        return 1
    fi
    log "${tag^} restore complete"
}

install_packages() {
    local backup_dir
    if [[ "$TARGET" == "/" ]]; then
        backup_dir="$BACKUP_DIR"
    else
        backup_dir="$TARGET$HOME/.dot/backup"
    fi

    if [[ ! -f "$backup_dir/apt-manual.txt" ]]; then
        printf '%sError: package lists not found at %s%s\n' "$RED" "$backup_dir" "$NC" >&2
        printf "Restore the home snapshot first, or check the target directory.\n" >&2
        return 1
    fi

    log "Reinstalling packages from $backup_dir/"

    # Refresh APT index (restored sources need their package lists fetched). Its
    # status matters: if this fails, every install below fails for the same reason.
    log "  Running apt update..."
    if ! $DRY_RUN; then
        if ! sudo apt-get update -qq; then
            printf '%sError: apt-get update failed — restored sources or keys are not usable yet.%s\n' \
                "$RED" "$NC" >&2
            return 1
        fi
    else
        log "  [DRY-RUN] Would run: sudo apt-get update"
    fi

    # APT packages. One unavailable name makes apt abort the whole transaction, so
    # filter the manifest against what the archive actually offers first, and keep a
    # single invocation so apt can still resolve dependencies jointly.
    if [[ -f "$backup_dir/apt-manual.txt" ]]; then
        local count avail_list missing_list
        count=$(wc -l < "$backup_dir/apt-manual.txt")
        avail_list="$(mktemp)"; missing_list="$(mktemp)"
        apt-cache --generate pkgnames 2>/dev/null | sort -u > "$avail_list.all"
        grep -Fxf "$avail_list.all" -- "$backup_dir/apt-manual.txt" | sort -u > "$avail_list" || true
        grep -Fxvf "$avail_list.all" -- "$backup_dir/apt-manual.txt" | sort -u > "$missing_list" || true

        if [[ -s "$missing_list" ]]; then
            printf '  %s[WARN]%s %d package(s) in the manifest are not in any configured archive:\n' \
                "$YELLOW" "$NC" "$(wc -l < "$missing_list")"
            sed 's/^/      /' "$missing_list"
        fi

        log "  Installing $(wc -l < "$avail_list") of $count apt packages..."
        if ! $DRY_RUN; then
            # One transaction first, so apt resolves dependencies jointly. If it fails —
            # one bad name or conflict aborts the whole batch, installing nothing —
            # fall back to one package at a time to salvage the rest, and name failures.
            if [[ -s "$avail_list" ]] && ! xargs -r -a "$avail_list" sudo apt-get install -y; then
                printf '  %s[WARN]%s batch install failed; retrying package by package...\n' "$YELLOW" "$NC"
                local pkg apt_failed=()
                while IFS= read -r pkg; do
                    sudo apt-get install -y -- "$pkg" >/dev/null 2>&1 || apt_failed+=("$pkg")
                done < "$avail_list"
                if [[ ${#apt_failed[@]} -gt 0 ]]; then
                    printf '  %s[WARN]%s %d apt package(s) failed: %s\n' \
                        "$YELLOW" "$NC" "${#apt_failed[@]}" "${apt_failed[*]}"
                fi
            fi
        else
            log "  [DRY-RUN] Would install $(wc -l < "$avail_list") apt packages"
        fi
        rm -f -- "$avail_list" "$avail_list.all" "$missing_list"
    else
        log "  Warning: $backup_dir/apt-manual.txt not found"
    fi

    # Snap packages. The manifest is "name<TAB>channel"; older two-column-less files
    # still work. --classic is retried only when snap actually asks for it, rather
    # than blindly, and stderr is kept so failures are diagnosable.
    if [[ -f "$backup_dir/snap-packages.txt" ]] && command -v snap >/dev/null 2>&1; then
        local snap_count snap_failed=()
        snap_count=$(wc -l < "$backup_dir/snap-packages.txt")
        log "  Installing $snap_count snap packages..."
        if ! $DRY_RUN; then
            local name channel err
            while IFS=$'\t' read -r name channel; do
                [[ -z "$name" ]] && continue
                local args=("$name")
                [[ -n "${channel:-}" && "$channel" != "-" ]] && args+=(--channel="$channel")
                if err="$(sudo snap install "${args[@]}" 2>&1)"; then
                    continue
                fi
                if [[ "$err" == *classic* ]] && sudo snap install --classic "${args[@]}"; then
                    continue
                fi
                printf '  %s[WARN]%s snap %s: %s\n' "$YELLOW" "$NC" "$name" "${err%%$'\n'*}"
                snap_failed+=("$name")
            done < "$backup_dir/snap-packages.txt"
            if [[ ${#snap_failed[@]} -gt 0 ]]; then
                printf '  %s[WARN]%s Failed snap packages: %s\n' "$YELLOW" "$NC" "${snap_failed[*]}"
            fi
        else
            log "  [DRY-RUN] Would install $snap_count snap packages"
        fi
    fi

    # Flatpak apps. The manifest is "app<TAB>origin"; without the remote, flatpak
    # cannot resolve an app that more than one remote provides.
    if [[ -f "$backup_dir/flatpak-apps.txt" ]] && command -v flatpak >/dev/null 2>&1; then
        local flatpak_count
        flatpak_count=$(wc -l < "$backup_dir/flatpak-apps.txt")
        log "  Installing $flatpak_count flatpak apps..."
        if ! $DRY_RUN; then
            local app origin
            while IFS=$'\t' read -r app origin; do
                [[ -z "$app" ]] && continue
                flatpak install -y ${origin:+"$origin"} "$app" || \
                    printf '  %s[WARN]%s flatpak %s failed\n' "$YELLOW" "$NC" "$app"
            done < "$backup_dir/flatpak-apps.txt"
        else
            log "  [DRY-RUN] Would install $flatpak_count flatpak apps"
        fi
    fi
}

print_reminders() {
    if ! $IN_PLACE; then
        printf '\n%sStaged, not applied.%s Nothing on this system was changed.\n' "$BOLD" "$NC"
        printf '  Inspect and copy across by hand:  %s%s%s\n' "$CYAN" "$TARGET" "$NC"
        printf '  The tree mirrors absolute paths, e.g. %s%s%s\n' "$CYAN" "$TARGET$HOME/..." "$NC"
        printf '  When you are done:  %srm -rf %s%s  (it is excluded from backups,\n' "$CYAN" "$TARGET" "$NC"
        printf '  but a stale copy of /etc here still holds old WiFi PSKs).\n'
        return
    fi

    printf '\n%sPost-restore reminders (in-place):%s\n' "$BOLD" "$NC"
    if ! $HOME_ONLY; then
        printf '  - %sNOT restored on purpose:%s /etc/crypttab, /etc/fstab, /etc/machine-id,\n' "$YELLOW" "$NC"
        printf '    /var/lib/tailscale — they name the OLD machine. Reconcile by hand if needed;\n'
        printf '    for crypttab prefer %ssudo cryptsetup luksUUID --uuid <old-uuid> <dev>%s over\n' "$CYAN" "$NC"
        printf '    editing it, and never %sluksHeaderRestore%s onto a freshly-encrypted disk —\n' "$CYAN" "$NC"
        printf '    that replaces the new volume key and makes the new filesystem unreadable.\n'
        printf '  - Bootloader, from inside a chroot with /dev /proc /sys /sys/firmware/efi/efivars\n'
        printf '    bind-mounted and /boot + /boot/efi mounted:\n'
        printf '      %ssudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu%s\n' "$CYAN" "$NC"
        printf '      %ssudo update-grub && sudo update-initramfs -u -k all%s\n' "$CYAN" "$NC"
        printf '    Requires shim-signed, cryptsetup-initramfs and lvm2 installed IN THE TARGET.\n'
        printf '  - Secure Boot is enabled: re-enrol the MOK (%s/var/lib/shim-signed/mok%s) or DKMS\n' "$CYAN" "$NC"
        printf '    modules will not load. Needs a physical console at MOK Manager.\n'
        printf '  - %ssudo netplan apply%s to activate restored WiFi connections\n' "$CYAN" "$NC"
        printf '  - %ssudo systemctl enable wifi-suspend-fix.service wifi-pre-suspend.service%s\n' "$CYAN" "$NC"
    fi
    printf '  - Verify SSH key permissions: ~/.ssh/ (700), private keys (600)\n'
    printf '  - Re-establish GPG trust if needed: %sgpg --edit-key <ID>%s -> trust\n' "$CYAN" "$NC"
    printf '  - Run %s./install.sh%s to symlink dotfiles, %s./update.sh%s to build dev tools\n' "$CYAN" "$NC" "$CYAN" "$NC"
}

# --- Main ---
main() {
    local start_time
    start_time=$(date +%s)

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Restic Restore%s\n' "$BOLD" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf ' Repository: %s\n' "$REPO"
    if $IN_PLACE; then
        printf ' Target: %s%s  (IN PLACE — overwrites the running system)%s\n' "$RED" "$TARGET" "$NC"
    else
        printf ' Target: %s  (staging — nothing on this system is touched)\n' "$TARGET"
    fi
    printf ' Snapshot: %s\n' "${SNAPSHOT:-latest}"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE — nothing will be written%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"

    check_restic
    check_password

    # List mode
    if $LIST_ONLY; then
        log "Listing snapshots..."
        restic snapshots --repo "$REPO"
        exit 0
    fi

    # Resolve one ID per half, up front, and verify each really carries its tag.
    resolve_host
    local home_id="" system_id=""
    if ! $SYSTEM_ONLY; then
        home_id="$(resolve_snapshot home)"
        if [[ -z "$home_id" ]]; then
            printf '  %s[WARN] No home snapshot found%s\n' "$YELLOW" "$NC"
        elif ! snapshot_has_tag "$home_id" home; then
            printf '%sError: snapshot %s is not tagged "home".%s\n' "$RED" "${home_id:0:8}" "$NC" >&2
            exit 1
        else
            show_snapshot_contents home "$home_id"; echo
        fi
    fi
    if ! $HOME_ONLY; then
        system_id="$(resolve_snapshot system)"
        if [[ -z "$system_id" ]]; then
            printf '  %s[WARN] No system snapshot found%s\n' "$YELLOW" "$NC"
        elif ! snapshot_has_tag "$system_id" system; then
            printf '%sError: snapshot %s is not tagged "system".%s\n' "$RED" "${system_id:0:8}" "$NC" >&2
            exit 1
        else
            show_snapshot_contents system "$system_id"; echo
        fi
    fi

    if [[ -z "$home_id" && -z "$system_id" ]]; then
        printf '%sError: no snapshots found to restore%s\n' "$RED" "$NC" >&2
        exit 1
    fi

    # Confirmation (skip in dry-run)
    if ! $DRY_RUN; then
        local prompt="Stage a copy into $TARGET?"
        $IN_PLACE && prompt="OVERWRITE THE RUNNING SYSTEM from this backup?"
        confirm "$prompt"; local crc=$?
        if [[ $crc -eq 2 ]]; then
            exit 1              # could not ask — that is a failure, not a decision
        elif [[ $crc -ne 0 ]]; then
            log "Restore cancelled by user"
            exit 0
        fi
        echo
        mkdir -p "$TARGET"
    fi

    # Step 1: Restore home (unprivileged — files land owned by the invoking user)
    if [[ -n "$home_id" ]]; then
        log "Step 1: Restoring home..."
        NEED_SUDO=false
        if ! restore_tag home "$home_id"; then exit 1; fi
        echo
    fi

    # Step 2: Restore system (needs root to recreate root-owned files)
    if [[ -n "$system_id" ]]; then
        log "Step 2: Restoring system..."
        NEED_SUDO=true
        if ! restore_tag system "$system_id"; then exit 1; fi
        echo
    fi

    # Step 3: Install packages
    if $INSTALL_PACKAGES; then
        log "Step 3: Reinstalling packages..."
        if ! install_packages; then exit 1; fi
        echo
    fi

    # Post-restore reminders
    print_reminders

    # Summary
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # The summary says what actually happened. It used to print "restored" in green
    # after a dry run that wrote nothing.
    local verb="restored" pverb="reinstalled"
    if $DRY_RUN; then verb="would be restored"; pverb="would be reinstalled"; fi

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Restore Summary%s\n' "$BOLD" "$NC"
    [[ -n "$home_id" ]]   && printf '  Home:     %s%s%s (%s)\n' "$GREEN" "$verb" "$NC" "${home_id:0:8}"
    [[ -n "$system_id" ]] && printf '  System:   %s%s%s (%s)\n' "$GREEN" "$verb" "$NC" "${system_id:0:8}"
    $INSTALL_PACKAGES     && printf '  Packages: %s%s%s\n' "$GREEN" "$pverb" "$NC"
    printf '  Mode:     %s\n' "$($IN_PLACE && echo 'in-place' || echo 'staging (nothing applied)')"
    printf '  Target:   %s\n' "$TARGET"
    printf '  Duration: %dm %ds\n' "$((duration / 60))" "$((duration % 60))"
    printf '  Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n' "$BOLD" "$NC"
    return 0
}

main
exit $?
