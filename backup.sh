#!/usr/bin/env bash
# backup.sh - Encrypted incremental backup using restic
#
# Backs up home directory and system configuration paths as separate
# tagged snapshots to any restic-compatible repository.
#
# Usage:
#   backup.sh <repository> [OPTIONS]
#
# Options:
#   -n, --dry-run    Show what would be backed up without running
#   -i, --init       Initialize the restic repository first
#   -c, --cleanup    Reclaim disk (cleanup.sh) AFTER a verified backup
#   -h, --help       Show help
#
# Environment:
#   RESTIC_PASSWORD or RESTIC_PASSWORD_FILE or RESTIC_PASSWORD_COMMAND

set -uo pipefail

# --- Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"
BACKUP_DIR="$HOME/.dot/backup"
LOG_DIR="$HOME/.dot/logs"
# $'...' so the escapes are real bytes: these are passed as printf %s arguments, not
# embedded in the format string, so \033 would otherwise print literally.
BOLD=$'\033[1m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

EXCLUDE_FILE="$SCRIPT_DIR/restic-excludes"
REPO_IDS_FILE="$BACKUP_DIR/repo-ids"   # "<location>\t<repository id>" per line
REPO_ID=""
LOCK_FILE="$LOG_DIR/.backup.lock"

# --- Defaults ---
DRY_RUN=false
INIT_REPO=false
RUN_CLEANUP=false
NO_PRUNE=false
ALLOW_SAME_DEVICE=false
REPO=""

# Retention. Grouped by host+tags, NOT the default host+paths: backup_system's path
# list is conditional, so any path appearing or disappearing would otherwise create a
# permanent new group whose snapshots nothing ever expires.
KEEP_LAST=3
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=12

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage: backup.sh <repository> [OPTIONS]

Encrypted incremental backup using restic. Creates two tagged snapshots:
  - "home"   : home directory (excluding caches, trash, Steam, etc.)
  - "system" : system configuration paths (/etc/*, /usr/local/bin/)

Options:
  -n, --dry-run    Show what would be backed up without running
  -i, --init       Initialize the restic repository first
  -c, --cleanup    Reclaim disk in ~/dev/repositories AFTER a verified backup
  --no-prune       Skip the forget/prune retention step
  --allow-same-device
                   Permit -i onto the same device as $HOME (not a real backup)
  -h, --help       Show this help

Environment:
  RESTIC_PASSWORD_FILE     Path to file containing password  (preferred)
  RESTIC_PASSWORD_COMMAND  Command that prints password
  RESTIC_PASSWORD          Repository password

  Prefer RESTIC_PASSWORD_FILE. Passing the passphrase inline
  (RESTIC_PASSWORD=... ./backup.sh) records it in your shell history AND in
  sudo's journal entry for the system snapshot.

Examples:
  backup.sh /mnt/external/repo -i       First run (init + backup)
  backup.sh /mnt/external/repo          Backup + verify + retention
  backup.sh /mnt/external/repo -c       ... and reclaim disk afterwards
  backup.sh sftp:user@host:/backup       Backup to remote via SFTP
  backup.sh /mnt/external/repo -n       Dry run
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=true; shift ;;
        -i|--init)     INIT_REPO=true; shift ;;
        -c|--cleanup)  RUN_CLEANUP=true; shift ;;
        --no-prune)    NO_PRUNE=true; shift ;;
        --allow-same-device) ALLOW_SAME_DEVICE=true; shift ;;
        -h|--help)     usage 0 ;;
        --)            shift; break ;;
        -*)            printf '%sUnknown option: %s%s\n' "$RED" "$1" "$NC" >&2; exit 1 ;;
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

# --- Logging setup ---
mkdir -p "$LOG_DIR"
# $$ in the name: a plain second-resolution timestamp made two runs started in the
# same second share one log inode and interleave into something unparseable.
LOG_FILE="$LOG_DIR/backup-$(date '+%Y-%m-%dT%H%M%S')-$$.log"
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
        msg="$(printf '%sBackup interrupted or failed (exit code %d). Check log: %s%s' \
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

# --- Mutex ---
# Two concurrent runs corrupt the log and make one of them fail its verification on
# the other's repository lock.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    printf '%sError: another backup.sh is already running (lock: %s)%s\n' "$RED" "$LOCK_FILE" "$NC" >&2
    exit 1
fi

# --- Helper functions ---
log() {
    printf '%s[%s]%s %s\n' "$CYAN" "$(date '+%H:%M:%S')" "$NC" "$1"
}

check_restic() {
    if ! command -v restic >/dev/null 2>&1; then
        printf '%sError: restic is not installed.%s\n' "$RED" "$NC" >&2
        printf 'Install with: ./update.sh (nuggets/utilities/restic.sh pins the version)\n' >&2
        exit 1
    fi
}

check_password() {
    if [[ -z "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD_COMMAND:-}" ]]; then
        printf '%sError: no restic password configured.%s\n' "$RED" "$NC" >&2
        printf 'Set RESTIC_PASSWORD_FILE (preferred), RESTIC_PASSWORD_COMMAND, or RESTIC_PASSWORD.\n' >&2
        exit 1
    fi
    # sudo writes its ENV= list into the journal verbatim, so an inline
    # RESTIC_PASSWORD ends up in a log readable by anyone in group adm — a copy that
    # outlives any shell-history scrub.
    if [[ -n "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" ]]; then
        printf '%sWarning: RESTIC_PASSWORD is set. sudo records it in the systemd journal for the\n' "$YELLOW"
        printf '         system snapshot, and an inline assignment also lands in shell history.\n'
        printf '         Prefer RESTIC_PASSWORD_FILE (mode 0400).%s\n\n' "$NC"
    fi
}

# Run restic under sudo, forwarding only the active password env var.
# NOTE: --preserve-env keeps the value out of `ps`, but sudo still logs it to the
# journal. RESTIC_PASSWORD_FILE forwards a path instead of a secret; prefer it.
sudo_restic() {
    local preserve=()
    [[ -n "${RESTIC_PASSWORD_FILE:-}" ]] && preserve+=(--preserve-env=RESTIC_PASSWORD_FILE)
    [[ -n "${RESTIC_PASSWORD_COMMAND:-}" ]] && preserve+=(--preserve-env=RESTIC_PASSWORD_COMMAND)
    [[ ${#preserve[@]} -eq 0 && -n "${RESTIC_PASSWORD:-}" ]] && preserve+=(--preserve-env=RESTIC_PASSWORD)
    sudo "${preserve[@]}" "$(command -v restic)" "$@"
}

# Write via a temp file and rename. `cmd > file` truncates before cmd runs, so a
# failing apt-mark used to leave an empty manifest behind — and that empty file is
# what the next snapshot captured.
write_list() {
    local dest="$1"; shift
    local tmp
    tmp="$(mktemp "${dest}.XXXXXX")" || return 1
    if "$@" >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        mv -- "$tmp" "$dest"
        return 0
    fi
    rm -f -- "$tmp"
    printf '  %s[WARN]%s %s failed; keeping the previous %s\n' \
        "$YELLOW" "$NC" "$1" "$(basename "$dest")" >&2
    return 1
}

snap_list_exportable() {
    # Record name + channel. Filtering on exact base/bare names, not a prefix: the old
    # /^(core|bare|snapd)/ also dropped snapd-desktop-integration.
    snap list 2>/dev/null | awk 'NR>1 {
        if ($1=="core" || $1=="bare" || $1=="snapd" || $1 ~ /^core[0-9]+$/) next
        print $1 "\t" $4
    }'
}

export_package_lists() {
    log "Exporting package lists to $BACKUP_DIR/"
    mkdir -p "$BACKUP_DIR"

    write_list "$BACKUP_DIR/apt-manual.txt" apt-mark showmanual \
        && log "  apt: $(wc -l < "$BACKUP_DIR/apt-manual.txt") packages"

    if command -v snap >/dev/null 2>&1; then
        write_list "$BACKUP_DIR/snap-packages.txt" snap_list_exportable \
            && log "  snap: $(wc -l < "$BACKUP_DIR/snap-packages.txt") packages (name + channel)"
    fi

    if command -v flatpak >/dev/null 2>&1; then
        write_list "$BACKUP_DIR/flatpak-apps.txt" flatpak list --app --columns=application,origin \
            && log "  flatpak: $(wc -l < "$BACKUP_DIR/flatpak-apps.txt") apps"
    fi
}

# Machine topology needed to rebuild the disk before any of this can be restored.
export_system_state() {
    log "Recording disk topology to $BACKUP_DIR/"
    mkdir -p "$BACKUP_DIR"
    {
        printf '# Generated by backup.sh on %s\n\n' "$(date -Is)"
        printf '## lsblk\n';      lsblk -o NAME,FSTYPE,LABEL,UUID,SIZE,MOUNTPOINT 2>/dev/null
        printf '\n## blkid\n';    blkid 2>/dev/null
        printf '\n## findmnt\n';  findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null
        printf '\n## efibootmgr\n'; efibootmgr -v 2>/dev/null
        printf '\n## enabled units\n'; systemctl list-unit-files --state=enabled --no-pager 2>/dev/null
    } > "$BACKUP_DIR/system-topology.txt" 2>/dev/null
    log "  topology recorded (partition table, LUKS header and LVM metadata need root — see README)"
}

backup_home() {
    log "Backing up home directory..."

    local restic_args=(
        backup "$HOME"
        --repo "$REPO"
        --tag home
        --one-file-system
        --exclude-caches
        --exclude-if-present .nobackup
        --exclude "$HOME/.cache"
        --exclude "$HOME/.local/share/Trash"
        --exclude "$HOME/snap/*/common/.cache"
        --exclude "$HOME/.local/share/Steam"
        --exclude "$HOME/.local/share/flatpak"
        --exclude "$HOME/.vagrant.d/boxes"
        --compression auto
        --verbose
    )

    # Additive: these supplement the inline excludes above, they do not replace them.
    # ~/.cache in particular carries no CACHEDIR.TAG, so it is excluded ONLY by the
    # inline --exclude and would come straight back if that line were removed.
    if [[ -f "$EXCLUDE_FILE" ]]; then
        restic_args+=(--exclude-file "$EXCLUDE_FILE")
    fi

    if $DRY_RUN; then
        restic_args+=(--dry-run)
    fi

    restic "${restic_args[@]}"
    local rc=$?
    # restic catches Ctrl-C itself and exits 130; pass that on as an interruption.
    [[ $rc -eq 130 ]] && exit 130
    if [[ $rc -eq 3 ]]; then
        # Tolerated: files racing the read legitimately produce this. (backup_system
        # pre-flights its path list, so there exit 3 can only mean an unreadable file.)
        printf '%sWarning: some files could not be read (exit code 3). Snapshot was created.%s\n' "$YELLOW" "$NC" >&2
    elif [[ $rc -ne 0 ]]; then
        printf '%sError: home backup failed (exit code %d)%s\n' "$RED" "$rc" "$NC" >&2
        return 1
    fi
    log "Home backup complete"
}

backup_system() {
    log "Backing up system paths (requires sudo)..."

    local restic_args=(
        backup
        --repo "$REPO"
        --tag system
        --compression auto
        --verbose
        /usr/local/bin/
        /etc/apt/sources.list.d/
        /etc/apt/keyrings/
        /etc/sysctl.d/
        /etc/udev/rules.d/
        /etc/modprobe.d/
        /etc/netplan/
        /etc/hosts
        /etc/hostname
        /etc/fstab
        /etc/default/grub
        /etc/grub.d/
        /etc/initramfs-tools/
        /etc/sudoers.d/
        /etc/ssh/
        /etc/lvm/
        /etc/systemd/system/
        /etc/apt/apt.conf.d/
        /etc/apt/preferences.d/
        /etc/apt/trusted.gpg.d/
        /usr/local/
        /var/lib/tailscale/
    )
    # Kept out of restic_args so the path pre-flight below doesn't mistake these
    # patterns for sources. Mount units are regenerated by snapd per installed
    # revision (stale ones only yield failed units); runtime state is never worth
    # restoring.
    local sys_excludes=(
        --exclude '/etc/systemd/system/snap-*'
        --exclude '/etc/systemd/system/snap.*'
        --exclude '/etc/systemd/system/*.wants/snap-*'
        --exclude '/etc/systemd/system/*.wants/snap.*'
        --exclude /usr/local/var/run
    )
    # /boot is deliberately absent. Kernels, initramfs and the ESP are regenerated by
    # packages, and restoring them is actively harmful: the initramfs bakes in
    # /etc/crypttab (the OLD LUKS UUID) and grub.cfg names the old /boot by UUID, so
    # an in-place restore onto a fresh install would not boot.

    # Secure Boot: without the MOK keypair, DKMS modules stop loading after a restore
    # and re-enrolment needs a physical console at MOK Manager.
    for d in /var/lib/shim-signed/mok /var/lib/dkms /etc/cryptsetup-initramfs; do
        [[ -d "$d" ]] && restic_args+=("$d/")
    done

    # Conditional paths (only if present on this machine)
    for p in /etc/tlp.conf /etc/crypttab; do
        [[ -e "$p" ]] && restic_args+=("$p")
    done
    [[ -d /etc/X11/xorg.conf.d ]] && restic_args+=(/etc/X11/xorg.conf.d/)

    # Pre-flight the unconditional paths. Since restic 0.19.0 a missing source path
    # also yields exit 3, indistinguishable at the exit-code level from a file that
    # merely could not be read — and the old code downgraded both to a yellow warning.
    # Checking here means a genuinely missing path is a hard, named failure, and exit 3
    # afterwards can only mean an unreadable file.
    local missing=()
    for p in "${restic_args[@]}"; do
        [[ "$p" == /* ]] || continue
        [[ -e "$p" ]] || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        printf '%sError: these system paths do not exist:%s\n' "$RED" "$NC" >&2
        printf '  %s\n' "${missing[@]}" >&2
        printf 'Fix the path list in backup.sh, or make them exist.\n' >&2
        return 1
    fi

    restic_args+=("${sys_excludes[@]}")
    if $DRY_RUN; then
        restic_args+=(--dry-run)
    fi

    sudo_restic "${restic_args[@]}"
    local rc=$?
    # restic catches Ctrl-C itself and exits 130; pass that on as an interruption.
    [[ $rc -eq 130 ]] && exit 130
    if [[ $rc -eq 3 ]]; then
        printf '%sWarning: some system files could not be read (exit 3). Snapshot was created.%s\n' "$YELLOW" "$NC" >&2
    elif [[ $rc -ne 0 ]]; then
        printf '%sError: system backup failed (exit code %d)%s\n' "$RED" "$rc" "$NC" >&2
        return 1
    fi
    log "System backup complete"
}

# Fail closed if a snapshot suddenly holds almost nothing — absolutely, or relative to
# the previous snapshot of the same tag. Reads the summary restic (0.17+) stores in
# each snapshot rather than `restic stats`, which walks every tree of a ~10M-file
# snapshot to produce the same number. Catches a stray .nobackup or CACHEDIR.TAG at
# $HOME, a bad exclude, and a half-empty source. The snapshot itself is kept either
# way; the non-zero exit is the signal.
check_snapshot_floor() {
    local tag="$1" min_files="$2"
    $DRY_RUN && return 0

    local cur="" prev=""
    read -r cur prev < <(restic snapshots --repo "$REPO" --tag "$tag" --host "$(hostname)" \
            --group-by host,tags --latest 2 --json 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
snaps = d[0]["snapshots"] if d and isinstance(d[0], dict) and "snapshots" in d[0] else d
snaps = sorted(snaps or [], key=lambda s: s["time"])
n = lambda s: (s.get("summary") or {}).get("total_files_processed", "")
print(n(snaps[-1]) if snaps else "", n(snaps[-2]) if len(snaps) > 1 else "")
' 2>/dev/null)

    if [[ ! "$cur" =~ ^[0-9]+$ ]]; then
        printf '%sError: could not read the file count of the new %s snapshot%s\n' "$RED" "$tag" "$NC" >&2
        return 1
    fi
    if [[ "$cur" -lt "$min_files" ]]; then
        printf '%sError: %s snapshot holds only %s files (floor %s). Refusing to call this a backup.%s\n' \
            "$RED" "$tag" "$cur" "$min_files" "$NC" >&2
        return 1
    fi
    if [[ "$prev" =~ ^[0-9]+$ ]] && (( cur * 2 < prev )); then
        printf '%sError: %s snapshot holds %s files, under half of the previous one (%s).%s\n' \
            "$RED" "$tag" "$cur" "$prev" "$NC" >&2
        printf 'The snapshot is kept. If the drop is intended (new excludes), the next run will pass.\n' >&2
        return 1
    fi
    log "  $tag snapshot: $cur files${prev:+ (previous: $prev)}"
}

# Structural check every run, plus 1/12 of the pack data on a rotation, so the whole
# repository is actually read back every twelve runs. A structural check alone never
# looks at file contents. No --with-cache: check deliberately uses a fresh cache so it
# reads the repository rather than the copies this run just wrote — with it, a
# corrupt tree pack verifies clean even under --read-data.
verify_repo() {
    local state="$BACKUP_DIR/check-subset.${REPO_ID:0:16}" n=1
    [[ -f "$state" && "$(cat "$state")" =~ ^([1-9]|1[0-2])$ ]] && n=$(( $(cat "$state") % 12 + 1 ))

    if $DRY_RUN; then
        log "[DRY-RUN] Would run: restic check --read-data-subset=$n/12"
        return 0
    fi

    log "Verifying repository integrity (structure + data subset $n/12)..."
    if ! restic check --repo "$REPO" --read-data-subset="$n/12" --retry-lock 5m; then
        printf '%sError: repository check failed%s\n' "$RED" "$NC" >&2
        return 1
    fi
    printf '%s\n' "$n" > "$state"
    log "Repository integrity verified"
}

# Stable key for a repository location in the pin file.
repo_key() {
    case "$REPO" in
        /*) realpath -m -- "$REPO" ;;
        *)  printf '%s' "${REPO%/}" ;;
    esac
}

# Creating a repository is irreversible in the sense that matters: a typo produces a
# brand-new empty repo that then reports success forever while the real one goes stale.
# restic init also creates missing parents, so a wrong path needs no existing directory.
confirm_new_repo() {
    # Local destination on the same filesystem as the data is not a backup.
    if ! $ALLOW_SAME_DEVICE; then
        case "$REPO" in
            /*)
                local repo_dev home_dev
                repo_dev="$(findmnt -no SOURCE -T "$(dirname "$REPO")" 2>/dev/null)"
                home_dev="$(findmnt -no SOURCE -T "$HOME" 2>/dev/null)"
                if [[ -n "$repo_dev" && "$repo_dev" == "$home_dev" ]]; then
                    printf '%sRefusing to init: %s is on the same device as $HOME (%s).%s\n' \
                        "$RED" "$REPO" "$repo_dev" "$NC" >&2
                    printf 'Is the backup drive mounted? Override with --allow-same-device.\n' >&2
                    return 1
                fi ;;
        esac
    fi
    if [[ -s "$REPO_IDS_FILE" ]]; then
        printf 'Repositories this machine already backs up to:\n'
        awk -F'\t' '{printf "  %s  (%s)\n", $1, substr($2,1,12)}' "$REPO_IDS_FILE"
    fi
    printf '%sAbout to create a NEW repository at: %s%s\n' "$YELLOW" "$REPO" "$NC"
    printf 'Type the word CREATE to confirm: '
    local answer=""
    read -r answer < /dev/tty 2>/dev/null || {
        printf '\n%sNo terminal available; refusing to create a repository unattended.%s\n' "$RED" "$NC" >&2
        return 1
    }
    [[ "$answer" == "CREATE" ]] || { printf 'Aborted.\n' >&2; return 1; }
}

# Compare the repository's own ID against the one recorded for this location on first
# use. Keyed by location so a second repository (an off-site copy) can be pinned too.
# A correct password against the *wrong* repository — a reformatted drive, a different
# repo mounted at the same path — is otherwise indistinguishable from success.
check_repo_id() {
    REPO_ID="$(restic cat config --repo "$REPO" 2>/dev/null \
          | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])' 2>/dev/null)"
    if [[ ! "$REPO_ID" =~ ^[0-9a-f]{64}$ ]]; then
        printf '%sError: could not read the repository ID%s\n' "$RED" "$NC" >&2
        return 1
    fi

    local key pinned
    key="$(repo_key)"
    mkdir -p "$BACKUP_DIR"
    pinned="$(awk -F'\t' -v k="$key" '$1==k {print $2}' "$REPO_IDS_FILE" 2>/dev/null | tail -1)"

    if [[ -z "$pinned" ]]; then
        $DRY_RUN || printf '%s\t%s\n' "$key" "$REPO_ID" >> "$REPO_IDS_FILE"
        log "  First use of this location: pinned repository ID ${REPO_ID:0:12}"
        return 0
    fi
    if [[ "$REPO_ID" != "$pinned" ]]; then
        printf '%sError: repository ID mismatch at %s%s\n' "$RED" "$key" "$NC" >&2
        printf '  expected %s\n  found    %s\n' "${pinned:0:12}" "${REPO_ID:0:12}" >&2
        printf 'This is not the repository this machine has been backing up to here.\n' >&2
        printf 'If it is meant to replace it, remove its line from %s.\n' "$REPO_IDS_FILE" >&2
        return 1
    fi
    log "  Repository ID ${REPO_ID:0:12} matches"
}

# Warn early if a local destination is nearly full: a fresh snapshot of this $HOME is
# hundreds of GiB, and prune needs headroom to repack.
check_free_space() {
    [[ "$REPO" == /* ]] || return 0
    local avail size
    read -r avail size < <(df --output=avail,size -B1 -- "$REPO" 2>/dev/null | tail -1)
    [[ "$avail" =~ ^[0-9]+$ && "$size" =~ ^[0-9]+$ ]] || return 0
    log "  Free space on destination: $(numfmt --to=iec-i --suffix=B "$avail") of $(numfmt --to=iec-i --suffix=B "$size")"
    if (( avail * 10 < size )); then
        printf '%sWarning: under 10%% free on the destination. Backups may fail and prune needs room to repack.%s\n' \
            "$YELLOW" "$NC" >&2
    fi
}

# One forget covers both tags: repeated --tag flags match either, and
# --group-by host,tags still keeps home and system as separate groups. One exclusive
# lock, and --prune only prunes if a snapshot was actually forgotten.
apply_retention() {
    if $DRY_RUN; then
        restic forget --repo "$REPO" --tag home --tag system \
            --group-by host,tags --host "$(hostname)" \
            --keep-last "$KEEP_LAST" --keep-daily "$KEEP_DAILY" \
            --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --dry-run
        return $?
    fi
    restic forget --repo "$REPO" --tag home --tag system \
        --group-by host,tags --host "$(hostname)" \
        --keep-last "$KEEP_LAST" --keep-daily "$KEEP_DAILY" \
        --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" \
        --prune --retry-lock 5m
}

# --- Main ---
main() {
    local start_time
    start_time=$(date +%s)

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Restic Backup%s\n' "$BOLD" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf ' Repository: %s\n' "$REPO"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE — nothing will be written%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"

    check_restic
    check_password

    # Step 1: Reach the repository FIRST. Nothing destructive, and nothing that takes
    # minutes, happens before we know the destination is real and openable. This
    # ordering is the whole point: cleanup used to run here and delete ~300 GiB before
    # discovering the repository path was mistyped.
    log "Step 1: Opening repository..."
    local cat_rc=0
    restic cat config --repo "$REPO" >/dev/null 2>&1 || cat_rc=$?

    # Exit 11 here means an EXCLUSIVE lock — e.g. left by a check/forget/prune that was
    # killed — which blocks even this read. restic never expires such locks on its own.
    # `restic unlock` only removes locks whose same-host process is gone or that have
    # not been refreshed for 30 minutes (a live restic refreshes every few minutes), so
    # running it is safe; flock above rules out a concurrent backup.sh. A live lock
    # survives it and we stop below.
    if [[ $cat_rc -eq 11 ]] && ! $DRY_RUN; then
        log "  Repository is locked; clearing stale locks..."
        restic unlock --repo "$REPO" 2>&1 | sed 's/^/  /'
        cat_rc=0
        restic cat config --repo "$REPO" >/dev/null 2>&1 || cat_rc=$?
    fi

    if [[ $cat_rc -ne 0 ]]; then
        case $cat_rc in
            12)
                printf '%sError: wrong password for %s%s\n' "$RED" "$REPO" "$NC" >&2
                exit 1 ;;
            11)
                printf '%sError: repository is locked by a live process (restic list locks --repo %s --no-lock)%s\n' \
                    "$RED" "$REPO" "$NC" >&2
                exit 1 ;;
            10|*)
                if ! $INIT_REPO; then
                    printf '%sError: no repository at %s (exit %d). Use -i to create one there.%s\n' \
                        "$RED" "$REPO" "$cat_rc" "$NC" >&2
                    exit 1
                fi
                if $DRY_RUN; then
                    log "  [DRY-RUN] Would run: restic init --repo $REPO"
                    log "  Dry-run of a backup needs an initialised repo; stopping here."
                    exit 0
                fi
                # Guard rails for -i: creating a repository is how a typo turns into a
                # silent, permanently-green backup of nothing.
                if ! confirm_new_repo; then exit 1; fi
                restic init --repo "$REPO" || exit 1 ;;
        esac
    elif $INIT_REPO; then
        log "  Repository already initialized, skipping init"
    fi

    # Also clear stale NON-exclusive locks (a killed backup). Those don't block the read
    # above, but they block the exclusive check/forget/prune later in this run.
    if ! $DRY_RUN; then
        restic unlock --repo "$REPO" 2>&1 | sed 's/^/  /'
    fi
    check_free_space

    # Step 2: Pin the repository identity. A correct password against the *wrong*
    # repository is otherwise indistinguishable from success.
    if ! check_repo_id; then exit 1; fi
    echo

    # Step 3: Export package lists and topology
    log "Step 3: Exporting package lists and disk topology..."
    export_package_lists
    export_system_state
    echo

    # Step 4: Back up home
    log "Step 4: Home backup..."
    if ! backup_home; then exit 1; fi
    echo

    # Step 5: Back up system
    log "Step 5: System backup..."
    if ! backup_system; then exit 1; fi
    echo

    # Step 6: Verify. Its status is honoured — this used to be discarded, so a failed
    # check still exited 0.
    log "Step 6: Repository verification..."
    if ! verify_repo; then exit 1; fi
    if ! check_snapshot_floor home 1000; then exit 1; fi
    if ! check_snapshot_floor system 20; then exit 1; fi
    echo

    # Step 7: Retention
    if $NO_PRUNE; then
        log "Step 7: Retention skipped (--no-prune)"
    else
        log "Step 7: Applying retention..."
        apply_retention || printf '%sWarning: retention step reported problems%s\n' "$YELLOW" "$NC" >&2
    fi
    echo

    # Step 8: Optional disk reclaim — AFTER a verified backup, never before.
    if $RUN_CLEANUP; then
        log "Step 8: Reclaiming disk in ~/dev/repositories..."
        if [[ -x "$CLEANUP_SCRIPT" ]]; then
            local cleanup_args=()
            if $DRY_RUN; then cleanup_args+=(--dry-run); fi
            if ! "$CLEANUP_SCRIPT" "${cleanup_args[@]}"; then
                printf '%sWarning: cleanup.sh reported failures (see above)%s\n' "$YELLOW" "$NC" >&2
            fi
            echo
        else
            log "  Warning: cleanup.sh not found at $CLEANUP_SCRIPT, skipping"
        fi
    else
        log "Step 8: Disk reclaim skipped (use -c, or run ./cleanup.sh -a directly)"
    fi

    # Summary
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Backup Summary%s\n' "$BOLD" "$NC"
    if ! $DRY_RUN; then
        restic snapshots --repo "$REPO" --compact
    fi
    printf '  Duration: %dm %ds\n' "$((duration / 60))" "$((duration % 60))"
    printf '  Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n' "$BOLD" "$NC"
    return 0
}

# `exit $?`: without it the script's status is whatever the last printf returned, so
# every failure above that only `return`ed would still have exited 0.
main
exit $?
