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
LOG_DIR="$HOME/.dot/logs"
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Defaults ---
DRY_RUN=false
SNAPSHOT=""
HOME_ONLY=false
SYSTEM_ONLY=false
LIST_ONLY=false
INSTALL_PACKAGES=false
TARGET="$HOME/.dot/restore"
REPO=""

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage: restore.sh <repository> [OPTIONS]

Restore from encrypted restic backup. Restores tagged snapshots:
  - "home"   : home directory
  - "system" : system configuration paths (requires sudo)

Options:
  -n, --dry-run       Show what would be restored without restoring
  -s, --snapshot ID   Snapshot to restore (default: latest)
  --home-only         Only restore home snapshot
  --system-only       Only restore system snapshot (requires sudo)
  --list              List available snapshots and exit
  --packages          Reinstall packages from saved lists
  -t, --target DIR    Restore root directory (default: ~/.dot/restore)
  -h, --help          Show this help

Restores to a staging directory by default. Use -t / to restore in-place.

Environment:
  RESTIC_PASSWORD          Repository password
  RESTIC_PASSWORD_FILE     Path to file containing password
  RESTIC_PASSWORD_COMMAND  Command that prints password

Examples:
  restore.sh /mnt/external/repo --list                List snapshots
  restore.sh /mnt/external/repo                       Restore to ~/.dot/restore/
  restore.sh /mnt/external/repo -t /                  Restore in-place (overwrites)
  restore.sh /mnt/external/repo --home-only           Restore home only
  restore.sh /mnt/external/repo --packages            Restore + reinstall pkgs
  restore.sh /mnt/external/repo -n                    Dry run
EOF
    exit 0
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
        -h|--help)        usage ;;
        -*)               printf "${RED}Unknown option: %s${NC}\n" "$1" >&2; exit 1 ;;
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

if $HOME_ONLY && $SYSTEM_ONLY; then
    printf "${RED}Error: --home-only and --system-only are mutually exclusive${NC}\n" >&2
    exit 1
fi

# --- Logging setup ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/restore-$(date '+%Y-%m-%dT%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Signal trap ---
cleanup_on_exit() {
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        printf "\n${RED}Restore interrupted or failed (exit code %d). Check log: %s${NC}\n" "$rc" "$LOG_FILE" >&2
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

confirm() {
    local msg="$1"
    printf "${YELLOW}%s${NC} [y/N] " "$msg" > /dev/tty
    local answer
    read -r answer < /dev/tty
    [[ "$answer" =~ ^[Yy]$ ]]
}

show_snapshot_contents() {
    local tag="$1"
    local snap_id="${SNAPSHOT:-latest}"

    log "Preview of $tag snapshot ($snap_id):"

    # Verify snapshot exists (no pipe, no SIGPIPE risk)
    if ! restic snapshots --repo "$REPO" --tag "$tag" --latest 1 --quiet 2>/dev/null | grep -q .; then
        printf "  ${YELLOW}[WARN] No %s snapshot found${NC}\n" "$tag"
        return 1
    fi

    # Preview (|| true avoids SIGPIPE exit code from head closing pipe early)
    local ls_args=(ls "$snap_id" --repo "$REPO")
    if [[ "$snap_id" == "latest" ]]; then
        ls_args+=(--tag "$tag")
    fi
    restic "${ls_args[@]}" 2>/dev/null | head -20 || true
    printf "  ... (use 'restic ls --repo %s latest --tag %s' for full listing)\n" "$REPO" "$tag"
}

restore_home() {
    log "Restoring home snapshot..."

    local snap_id="${SNAPSHOT:-latest}"
    local restic_args=(
        restore "$snap_id"
        --repo "$REPO"
        --target "$TARGET"
        --verbose
    )

    if [[ "$snap_id" == "latest" ]]; then
        restic_args+=(--tag home)
    fi

    if $DRY_RUN; then
        restic_args+=(--dry-run)
    fi

    restic "${restic_args[@]}"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        printf "${RED}Error: home restore failed (exit code %d)${NC}\n" "$rc" >&2
        return 1
    fi
    log "Home restore complete"
}

restore_system() {
    log "Restoring system snapshot (requires sudo)..."

    local snap_id="${SNAPSHOT:-latest}"
    local restic_args=(
        restore "$snap_id"
        --repo "$REPO"
        --target "$TARGET"
        --verbose
    )

    if [[ "$snap_id" == "latest" ]]; then
        restic_args+=(--tag system)
    fi

    if $DRY_RUN; then
        restic_args+=(--dry-run)
    fi

    sudo_restic "${restic_args[@]}"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        printf "${RED}Error: system restore failed (exit code %d)${NC}\n" "$rc" >&2
        return 1
    fi
    log "System restore complete"
}

install_packages() {
    local backup_dir
    if [[ "$TARGET" == "/" ]]; then
        backup_dir="$BACKUP_DIR"
    else
        backup_dir="$TARGET$HOME/.dot/backup"
    fi

    if [[ ! -f "$backup_dir/apt-manual.txt" ]]; then
        printf "${RED}Error: package lists not found at %s${NC}\n" "$backup_dir" >&2
        printf "Restore the home snapshot first, or check the target directory.\n" >&2
        return 1
    fi

    log "Reinstalling packages from $backup_dir/"

    # Refresh APT index (restored sources need their package lists fetched)
    log "  Running apt update..."
    if ! $DRY_RUN; then
        sudo apt-get update -qq
    else
        log "  [DRY-RUN] Would run: sudo apt-get update"
    fi

    # APT packages
    if [[ -f "$backup_dir/apt-manual.txt" ]]; then
        local count
        count=$(wc -l < "$backup_dir/apt-manual.txt")
        log "  Installing $count apt packages..."
        if ! $DRY_RUN; then
            xargs sudo apt-get install -y < "$backup_dir/apt-manual.txt" || \
                printf "  ${YELLOW}[WARN]${NC} Some apt packages failed to install. Check output above.\n"
        else
            log "  [DRY-RUN] Would install $count apt packages"
        fi
    else
        log "  Warning: $backup_dir/apt-manual.txt not found"
    fi

    # Snap packages (install one at a time — some need --classic)
    if [[ -f "$backup_dir/snap-packages.txt" ]] && command -v snap >/dev/null 2>&1; then
        local snap_count snap_failed=()
        snap_count=$(wc -l < "$backup_dir/snap-packages.txt")
        log "  Installing $snap_count snap packages..."
        if ! $DRY_RUN; then
            while IFS= read -r pkg; do
                [[ -z "$pkg" ]] && continue
                if ! sudo snap install "$pkg" 2>/dev/null; then
                    if ! sudo snap install --classic "$pkg" 2>/dev/null; then
                        snap_failed+=("$pkg")
                    fi
                fi
            done < "$backup_dir/snap-packages.txt"
            if [[ ${#snap_failed[@]} -gt 0 ]]; then
                printf "  ${YELLOW}[WARN]${NC} Failed snap packages: %s\n" "${snap_failed[*]}"
            fi
        else
            log "  [DRY-RUN] Would install $snap_count snap packages"
        fi
    fi

    # Flatpak apps
    if [[ -f "$backup_dir/flatpak-apps.txt" ]] && command -v flatpak >/dev/null 2>&1; then
        local flatpak_count
        flatpak_count=$(wc -l < "$backup_dir/flatpak-apps.txt")
        log "  Installing $flatpak_count flatpak apps..."
        if ! $DRY_RUN; then
            xargs flatpak install -y < "$backup_dir/flatpak-apps.txt" || \
                printf "  ${YELLOW}[WARN]${NC} Some flatpak apps failed to install. Check output above.\n"
        else
            log "  [DRY-RUN] Would install $flatpak_count flatpak apps"
        fi
    fi
}

print_reminders() {
    printf "\n${BOLD}Post-restore reminders:${NC}\n"
    if ! $HOME_ONLY; then
        printf "  - Run ${CYAN}sudo update-grub${NC} to apply restored GRUB config\n"
        printf "  - Run ${CYAN}sudo netplan apply${NC} to activate restored WiFi connections\n"
        printf "  - Enable WiFi suspend services if restored:\n"
        printf "    ${CYAN}sudo systemctl enable wifi-suspend-fix.service wifi-pre-suspend.service${NC}\n"
        printf "  - Re-bind Clevis TPM2 if using FDE: ${CYAN}sudo clevis luks bind -d /dev/<part> tpm2 '{...}'${NC}\n"
    fi
    printf "  - Verify SSH key permissions: ~/.ssh/ (700), private keys (600)\n"
    printf "  - Re-establish GPG trust if needed: ${CYAN}gpg --edit-key <ID>${NC} → trust\n"
    printf "  - Run ${CYAN}./install.sh${NC} to symlink dotfiles\n"
    printf "  - Run ${CYAN}./update.sh${NC} to build dev tools\n"
}

# --- Main ---
main() {
    local start_time
    start_time=$(date +%s)

    printf "\n${BOLD}============================================================${NC}\n"
    printf "${BOLD} Restic Restore${NC}\n"
    printf " %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf " Repository: %s\n" "$REPO"
    printf " Target: %s\n" "$TARGET"
    printf " Snapshot: %s\n" "${SNAPSHOT:-latest}"
    if $DRY_RUN; then
        printf " ${YELLOW}DRY-RUN MODE — nothing will be written${NC}\n"
    fi
    printf " Log: %s\n" "$LOG_FILE"
    printf "${BOLD}============================================================${NC}\n\n"

    check_restic
    check_password

    # List mode
    if $LIST_ONLY; then
        log "Listing snapshots..."
        restic snapshots --repo "$REPO"
        exit 0
    fi

    # Preview
    local do_home=false do_system=false
    if ! $SYSTEM_ONLY; then
        if show_snapshot_contents "home"; then
            do_home=true
        fi
        echo
    fi
    if ! $HOME_ONLY; then
        if show_snapshot_contents "system"; then
            do_system=true
        fi
        echo
    fi

    if ! $do_home && ! $do_system; then
        printf "${RED}Error: no snapshots found to restore${NC}\n" >&2
        exit 1
    fi

    # Confirmation (skip in dry-run)
    if ! $DRY_RUN; then
        if ! confirm "Proceed with restore to $TARGET?"; then
            log "Restore cancelled by user"
            exit 0
        fi
        echo
        mkdir -p "$TARGET"
    fi

    # Step 1: Restore home
    if $do_home; then
        log "Step 1: Restoring home..."
        if ! restore_home; then exit 1; fi
        echo
    fi

    # Step 2: Restore system
    if $do_system; then
        log "Step 2: Restoring system..."
        if ! restore_system; then exit 1; fi
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

    printf "\n${BOLD}============================================================${NC}\n"
    printf "${BOLD} Restore Summary${NC}\n"
    if $do_home; then printf "  Home:     ${GREEN}restored${NC}\n"; fi
    if $do_system; then printf "  System:   ${GREEN}restored${NC}\n"; fi
    if $INSTALL_PACKAGES; then printf "  Packages: ${GREEN}reinstalled${NC}\n"; fi
    printf "  Target:   %s\n" "$TARGET"
    printf "  Duration: %dm %ds\n" "$((duration / 60))" "$((duration % 60))"
    printf "  Log: %s\n" "$LOG_FILE"
    printf "${BOLD}============================================================${NC}\n"
}

main
