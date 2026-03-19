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
#   -c, --cleanup    Run cleanup.sh before backing up
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
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Defaults ---
DRY_RUN=false
INIT_REPO=false
RUN_CLEANUP=false
REPO=""

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
  -c, --cleanup    Run cleanup.sh before backing up
  -h, --help       Show this help

Environment:
  RESTIC_PASSWORD          Repository password
  RESTIC_PASSWORD_FILE     Path to file containing password
  RESTIC_PASSWORD_COMMAND  Command that prints password

Examples:
  backup.sh /mnt/external/repo -i       First run (init + backup)
  backup.sh /mnt/external/repo -c       Cleanup artifacts, then backup
  backup.sh sftp:user@host:/backup       Backup to remote via SFTP
  backup.sh /mnt/external/repo -n       Dry run
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=true; shift ;;
        -i|--init)     INIT_REPO=true; shift ;;
        -c|--cleanup)  RUN_CLEANUP=true; shift ;;
        -h|--help)     usage ;;
        -*)            printf "${RED}Unknown option: %s${NC}\n" "$1" >&2; exit 1 ;;
        *)
            if [[ -n "$REPO" ]]; then
                printf "${RED}Error: unexpected argument '%s'${NC}\n" "$1" >&2; exit 1
            fi
            REPO="$1"; shift ;;
    esac
done

if [[ -z "$REPO" ]]; then
    printf "${RED}Error: no repository specified${NC}\n" >&2
    usage
fi

# --- Logging setup ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup-$(date '+%Y-%m-%dT%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Signal trap ---
cleanup_on_exit() {
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        printf "\n${RED}Backup interrupted or failed (exit code %d). Check log: %s${NC}\n" "$rc" "$LOG_FILE" >&2
    fi
}
trap cleanup_on_exit EXIT

# --- Helper functions ---
log() {
    printf "${CYAN}[%s]${NC} %s\n" "$(date '+%H:%M:%S')" "$1"
}

check_restic() {
    if ! command -v restic >/dev/null 2>&1; then
        printf "${RED}Error: restic is not installed.${NC}\n" >&2
        printf "Install with: sudo apt install restic\n" >&2
        exit 1
    fi
}

check_password() {
    if [[ -z "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD_COMMAND:-}" ]]; then
        printf "${RED}Error: no restic password configured.${NC}\n" >&2
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

export_package_lists() {
    log "Exporting package lists to $BACKUP_DIR/"
    mkdir -p "$BACKUP_DIR"

    apt-mark showmanual > "$BACKUP_DIR/apt-manual.txt"
    log "  apt: $(wc -l < "$BACKUP_DIR/apt-manual.txt") packages"

    if command -v snap >/dev/null 2>&1; then
        snap list 2>/dev/null | awk 'NR>1 && !/^(core|bare|snapd)/ {print $1}' > "$BACKUP_DIR/snap-packages.txt"
        log "  snap: $(wc -l < "$BACKUP_DIR/snap-packages.txt") packages"
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak list --app --columns=application > "$BACKUP_DIR/flatpak-apps.txt" 2>/dev/null || true
        log "  flatpak: $(wc -l < "$BACKUP_DIR/flatpak-apps.txt") apps"
    fi
}

backup_home() {
    log "Backing up home directory..."

    local restic_args=(
        backup "$HOME"
        --repo "$REPO"
        --tag home
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

    if $DRY_RUN; then
        restic_args+=(--dry-run)
    fi

    restic "${restic_args[@]}"
    local rc=$?
    if [[ $rc -eq 3 ]]; then
        printf "${YELLOW}Warning: some files could not be read (exit code 3). Snapshot was created.${NC}\n" >&2
    elif [[ $rc -ne 0 ]]; then
        printf "${RED}Error: home backup failed (exit code %d)${NC}\n" "$rc" >&2
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
        /etc/default/grub
    )

    # Conditional paths (only if present on this machine)
    for p in /etc/tlp.conf /etc/crypttab \
             /etc/systemd/system/wifi-suspend-fix.service \
             /etc/systemd/system/wifi-pre-suspend.service; do
        [[ -e "$p" ]] && restic_args+=("$p")
    done
    for d in /boot/efi/EFI/HP /etc/X11/xorg.conf.d; do
        [[ -d "$d" ]] && restic_args+=("$d/")
    done

    if $DRY_RUN; then
        restic_args+=(--dry-run)
    fi

    sudo_restic "${restic_args[@]}"
    local rc=$?
    if [[ $rc -eq 3 ]]; then
        printf "${YELLOW}Warning: some files could not be read (exit code 3). Snapshot was created.${NC}\n" >&2
    elif [[ $rc -ne 0 ]]; then
        printf "${RED}Error: system backup failed (exit code %d)${NC}\n" "$rc" >&2
        return 1
    fi
    log "System backup complete"
}

verify_repo() {
    if $DRY_RUN; then
        log "[DRY-RUN] Would run: restic check --repo $REPO"
        return 0
    fi

    log "Verifying repository integrity..."
    restic check --repo "$REPO"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        printf "${RED}Warning: repository check reported issues (exit code %d)${NC}\n" "$rc" >&2
        return 1
    fi
    log "Repository integrity verified"
}

# --- Main ---
main() {
    local start_time
    start_time=$(date +%s)

    printf "\n${BOLD}============================================================${NC}\n"
    printf "${BOLD} Restic Backup${NC}\n"
    printf " %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf " Repository: %s\n" "$REPO"
    if $DRY_RUN; then
        printf " ${YELLOW}DRY-RUN MODE — nothing will be written${NC}\n"
    fi
    printf " Log: %s\n" "$LOG_FILE"
    printf "${BOLD}============================================================${NC}\n\n"

    check_restic
    check_password

    # Step 1: Optional cleanup
    if $RUN_CLEANUP; then
        log "Step 1: Running pre-backup cleanup..."
        if [[ -x "$CLEANUP_SCRIPT" ]]; then
            local cleanup_args=()
            if $DRY_RUN; then cleanup_args+=(--dry-run); fi
            "$CLEANUP_SCRIPT" "${cleanup_args[@]}"
            echo
        else
            log "  Warning: cleanup.sh not found at $CLEANUP_SCRIPT, skipping"
        fi
    else
        log "Step 1: Cleanup skipped (use -c to enable)"
    fi

    # Step 2: Export package lists
    log "Step 2: Exporting package lists..."
    export_package_lists
    echo

    # Step 3: Init repo (if requested)
    if $INIT_REPO; then
        log "Step 3: Initializing repository..."
        if $DRY_RUN; then
            log "  [DRY-RUN] Would run: restic init --repo $REPO"
        elif restic cat config --repo "$REPO" >/dev/null 2>&1; then
            log "  Repository already initialized, skipping"
        else
            restic init --repo "$REPO"
        fi
        echo
    else
        log "Step 3: Repository init skipped (use -i for first run)"
    fi

    # Verify repo exists before attempting backup
    if ! restic cat config --repo "$REPO" >/dev/null 2>&1; then
        if $DRY_RUN; then
            log "Repository does not exist yet. Dry-run of backup requires an initialized repo."
            log "Run without --dry-run first: backup.sh $REPO -i"
        else
            printf "${RED}Error: repository does not exist. Use -i to initialize.${NC}\n" >&2
        fi
        exit 1
    fi

    # Step 4: Back up home
    log "Step 4: Home backup..."
    if ! backup_home; then exit 1; fi
    echo

    # Step 5: Back up system
    log "Step 5: System backup..."
    if ! backup_system; then exit 1; fi
    echo

    # Step 6: Verify
    log "Step 6: Repository verification..."
    verify_repo
    echo

    # Summary
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    printf "\n${BOLD}============================================================${NC}\n"
    printf "${BOLD} Backup Summary${NC}\n"
    if ! $DRY_RUN; then
        restic snapshots --repo "$REPO" --compact
    fi
    printf "  Duration: %dm %ds\n" "$((duration / 60))" "$((duration % 60))"
    printf "  Log: %s\n" "$LOG_FILE"
    printf "${BOLD}============================================================${NC}\n"
}

main
