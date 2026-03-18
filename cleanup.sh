#!/usr/bin/env bash
# cleanup.sh - Pre-backup dev repository cleanup
#
# Removes regenerable build artifacts from dev repositories
# and optionally cleans system-level caches.
#
# Usage:
#   cleanup.sh [OPTIONS]
#
# Options:
#   -n, --dry-run        Show what would be deleted without deleting
#   -s, --system-caches  Also clean system caches (~/.cache/pip, etc.)
#   -g, --git-gc         Run git gc --prune=now on all repos
#   -a, --all            Enable --system-caches + --git-gc
#   -d, --dir DIR        Target a specific directory (default: ~/dev/repositories)
#   -h, --help           Show help

set -uo pipefail

# --- Constants ---
DEFAULT_ROOT="$HOME/dev/repositories"
LOG_DIR="$HOME/.dot/logs"
BOLD=$'\033[1m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# --- Defaults ---
DRY_RUN=false
SYSTEM_CACHES=false
GIT_GC=false
TARGET_DIR="$DEFAULT_ROOT"
TOTAL_REMOVED=0

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage: cleanup.sh [OPTIONS]

Pre-backup cleanup: remove regenerable build artifacts from dev repositories.

Options:
  -n, --dry-run        Show what would be deleted without deleting
  -s, --system-caches  Also clean system caches (~/.cache/pip, etc.)
  -g, --git-gc         Run git gc --prune=now on all repos
  -a, --all            Enable --system-caches + --git-gc
  -d, --dir DIR        Target a specific directory (default: ~/dev/repositories)
  -h, --help           Show this help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=true; shift ;;
        -s|--system-caches) SYSTEM_CACHES=true; shift ;;
        -g|--git-gc)   GIT_GC=true; shift ;;
        -a|--all)      SYSTEM_CACHES=true; GIT_GC=true; shift ;;
        -d|--dir)      TARGET_DIR="${2:?--dir requires an argument}"; shift 2 ;;
        -h|--help)     usage ;;
        *)             printf '%sUnknown option: %s%s\n' "$RED" "$1" "$NC" >&2; exit 1 ;;
    esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
    printf '%sError: '\''%s'\'' is not a directory%s\n' "$RED" "$TARGET_DIR" "$NC" >&2
    exit 1
fi

# --- Logging setup ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cleanup-$(date '+%Y-%m-%dT%H%M%S').log"

# Tee all output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Helper functions ---
log() {
    printf '%s[%s]%s %s\n' "$CYAN" "$(date '+%H:%M:%S')" "$NC" "$1"
}

log_remove() {
    local size="$1" path="$2"
    if $DRY_RUN; then
        printf '  %s[DRY-RUN]%s %6s  %s\n' "$YELLOW" "$NC" "$size" "$path"
    else
        printf '  %s[REMOVE]%s  %6s  %s\n' "$RED" "$NC" "$size" "$path"
    fi
}

log_skip() {
    local path="$1" reason="$2"
    printf '  %s[SKIP]%s          %s  (%s)\n' "$GREEN" "$NC" "$path" "$reason"
}

get_size_bytes() {
    du -sb "$1" 2>/dev/null | cut -f1
}

get_size_human() {
    du -sh "$1" 2>/dev/null | cut -f1
}

human_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

# Remove a directory safely. Measures size first, then renames and deletes.
# Uses rename-then-delete for atomicity on large dirs.
safe_remove() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then return; fi

    local size_bytes size_human rel_path
    size_bytes="$(get_size_bytes "$dir")" || size_bytes=0
    size_human="$(get_size_human "$dir")" || size_human="?"
    rel_path="${dir#"$TARGET_DIR"/}"

    log_remove "$size_human" "$rel_path"
    TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))

    if ! $DRY_RUN; then
        # Rename-then-delete: atomic rename prevents race conditions
        local tmp_name="${dir}.cleanup.$$"
        if mv -- "$dir" "$tmp_name" 2>/dev/null; then
            rm -rf -- "$tmp_name"
        else
            # Fallback: direct delete if rename fails (cross-device, permissions)
            rm -rf -- "$dir" || printf '  %s[WARN]%s Failed to remove: %s\n' "$RED" "$NC" "$rel_path"
        fi
    fi
}

# Remove a single file safely.
safe_remove_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then return; fi

    local size_bytes size_human rel_path
    size_bytes="$(stat --printf='%s' "$file" 2>/dev/null)" || size_bytes=0
    size_human="$(get_size_human "$file")" || size_human="?"
    rel_path="${file#"$TARGET_DIR"/}"

    log_remove "$size_human" "$rel_path"
    TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))

    if ! $DRY_RUN; then
        rm -f -- "$file" || printf '  %s[WARN]%s Failed to remove: %s\n' "$RED" "$NC" "$rel_path"
    fi
}

# Check if a path is tracked in git. Defaults to "tracked" (safe) on failure.
is_git_tracked() {
    local dir="$1"
    local repo_root dir_name
    repo_root="$(dirname "$dir")"
    dir_name="$(basename "$dir")"

    if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
        # Not in a git repo — assume tracked (safe: don't delete)
        return 0
    fi

    local tracked
    tracked="$(git -C "$repo_root" ls-files "$dir_name/" 2>/dev/null | head -1)"
    [[ -n "$tracked" ]]
}

# Check if parent dir has any of the given project marker files.
has_project_file() {
    local parent="$1"
    shift
    for f in "$@"; do
        if [[ -f "$parent/$f" ]]; then
            return 0
        fi
    done
    return 1
}

# --- Phase 1: Always-safe removals ---
clean_always_safe() {
    local root="$1"

    log "Phase 1: Always-safe build artifacts"

    # Rust target/ (only with sibling Cargo.toml)
    log "  Scanning Rust target/ directories..."
    while IFS= read -r -d '' cargo; do
        local parent="${cargo%/Cargo.toml}"
        if [[ -d "$parent/target" ]]; then
            safe_remove "$parent/target"
        fi
    done < <(find "$root" -type f -name 'Cargo.toml' -not -path '*/target/*' -print0 2>/dev/null)

    # Node node_modules/ (prune to skip nested)
    log "  Scanning node_modules/ directories..."
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d -name 'node_modules' -prune -print0 2>/dev/null)

    # Python venvs (venv, .venv, deploy-venv)
    log "  Scanning Python virtual environments..."
    while IFS= read -r -d '' dir; do
        if [[ -f "$dir/pyvenv.cfg" || -f "$dir/bin/activate" ]]; then
            safe_remove "$dir"
        else
            log_skip "${dir#"$root"/}" "not a Python venv"
        fi
    done < <(find "$root" -type d \( -name 'venv' -o -name '.venv' -o -name 'deploy-venv' \) -print0 2>/dev/null)

    # Python caches and tool caches (directories)
    log "  Scanning Python and tool caches..."
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d \( \
        -name '__pycache__' -o \
        -name '.mypy_cache' -o \
        -name '.pytest_cache' -o \
        -name '.ruff_cache' -o \
        -name '.tox' -o \
        -name '.nox' -o \
        -name '.eggs' -o \
        -name '.hypothesis' -o \
        -name 'htmlcov' -o \
        -name '.ipynb_checkpoints' \
    \) -print0 2>/dev/null)

    # *.egg-info directories
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d -name '*.egg-info' -print0 2>/dev/null)

    # .coverage files
    while IFS= read -r -d '' file; do
        safe_remove_file "$file"
    done < <(find "$root" -type f -name '.coverage' -print0 2>/dev/null)

    # Stray .pyc files (outside already-deleted __pycache__)
    local pyc_count=0
    while IFS= read -r -d '' file; do
        if ! $DRY_RUN; then
            rm -f -- "$file" 2>/dev/null
        fi
        pyc_count=$((pyc_count + 1))
    done < <(find "$root" -type f -name '*.pyc' -print0 2>/dev/null)
    if [[ $pyc_count -gt 0 ]]; then
        if $DRY_RUN; then
            log "  Found $pyc_count stray .pyc files"
        else
            log "  Removed $pyc_count stray .pyc files"
        fi
    fi

    # AI/IDE tool caches
    log "  Scanning tool and framework caches..."
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d -name '.aider.tags.cache.*' -print0 2>/dev/null)

    # Framework build caches
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d \( \
        -name '.nx' -o \
        -name '.next' -o \
        -name '.nuxt' -o \
        -name '.svelte-kit' -o \
        -name '.turbo' -o \
        -name '.parcel-cache' -o \
        -name '.angular' -o \
        -name '.sass-cache' \
    \) -print0 2>/dev/null)

    # IaC caches
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d -name '.terraform' -print0 2>/dev/null)

    # direnv
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d -name '.direnv' -print0 2>/dev/null)

    # Haskell
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d \( -name '.stack-work' -o -name 'dist-newstyle' \) -print0 2>/dev/null)

    # Dart, Zig
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d \( -name '.dart_tool' -o -name 'zig-cache' -o -name 'zig-out' \) -print0 2>/dev/null)
}

# --- Phase 2: Conditional removals ---
clean_conditional() {
    local root="$1"

    log "Phase 2: Conditional artifacts (checking git tracking)"

    # dist/ — only if not git-tracked and has project marker
    log "  Scanning dist/ directories..."
    while IFS= read -r -d '' dir; do
        local parent
        parent="$(dirname "$dir")"
        if is_git_tracked "$dir"; then
            log_skip "${dir#"$root"/}" "git-tracked"
        elif has_project_file "$parent" package.json Cargo.toml; then
            safe_remove "$dir"
        else
            log_skip "${dir#"$root"/}" "no known project file"
        fi
    done < <(find "$root" -type d -name 'dist' -not -path '*/node_modules/*' -print0 2>/dev/null)

    # build/ — only if not git-tracked and has build-system marker
    log "  Scanning build/ directories..."
    while IFS= read -r -d '' dir; do
        local parent
        parent="$(dirname "$dir")"
        if is_git_tracked "$dir"; then
            log_skip "${dir#"$root"/}" "git-tracked"
        elif has_project_file "$parent" package.json Cargo.toml setup.py pyproject.toml CMakeLists.txt Makefile build.gradle; then
            safe_remove "$dir"
        else
            log_skip "${dir#"$root"/}" "no known build system"
        fi
    done < <(find "$root" -type d -name 'build' -not -path '*/node_modules/*' -print0 2>/dev/null)

    # _site/ — static site generator output
    log "  Scanning _site/ directories..."
    while IFS= read -r -d '' dir; do
        local parent
        parent="$(dirname "$dir")"
        if has_project_file "$parent" _config.yml Gemfile package.json; then
            safe_remove "$dir"
        else
            log_skip "${dir#"$root"/}" "no site generator config"
        fi
    done < <(find "$root" -type d -name '_site' -not -path '*/node_modules/*' -print0 2>/dev/null)

    # vendor/ — only if not git-tracked
    log "  Scanning vendor/ directories..."
    while IFS= read -r -d '' dir; do
        if is_git_tracked "$dir"; then
            log_skip "${dir#"$root"/}" "git-tracked"
        else
            safe_remove "$dir"
        fi
    done < <(find "$root" -maxdepth 3 -type d -name 'vendor' -not -path '*/node_modules/*' -print0 2>/dev/null)
}

# --- Phase 3: System caches ---
clean_system_caches() {
    log "Phase 3: System caches"

    if ! $SYSTEM_CACHES; then
        log "  Skipped (use --system-caches or --all to enable)"
        return
    fi

    local caches=(
        "$HOME/.cache/sccache"
        "$HOME/.cache/pip"
        "$HOME/.cache/pip-tools"
        "$HOME/.npm/_cacache"
        "$HOME/.cache/huggingface"
        "$HOME/.cache/yarn"
        "$HOME/.cache/pnpm"
        "$HOME/.cache/ms-playwright"
        "$HOME/.cache/node-gyp"
        "$HOME/.cache/node"
        "$HOME/.cache/go-build"
    )

    for cache in "${caches[@]}"; do
        if [[ -d "$cache" ]]; then
            local size_human size_bytes
            size_human="$(get_size_human "$cache")" || size_human="?"
            size_bytes="$(get_size_bytes "$cache")" || size_bytes=0

            if $DRY_RUN; then
                printf '  %s[DRY-RUN]%s %6s  %s\n' "$YELLOW" "$NC" "$size_human" "$cache"
            else
                printf '  %s[REMOVE]%s  %6s  %s\n' "$RED" "$NC" "$size_human" "$cache"
                rm -rf -- "$cache" || printf '  %s[WARN]%s Failed to remove: %s\n' "$RED" "$NC" "$cache"
            fi
            TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
        fi
    done
}

# --- Phase 4: Git GC ---
run_git_gc() {
    log "Phase 4: Git GC"

    if ! $GIT_GC; then
        log "  Skipped (use --git-gc or --all to enable)"
        return
    fi

    while IFS= read -r -d '' gitdir; do
        local repo
        repo="$(dirname "$gitdir")"
        local rel_path="${repo#"$TARGET_DIR"/}"
        if $DRY_RUN; then
            printf '  %s[DRY-RUN]%s git gc --prune=now: %s\n' "$YELLOW" "$NC" "$rel_path"
        else
            printf '  %s[GC]%s      git gc --prune=now: %s\n' "$CYAN" "$NC" "$rel_path"
            git -C "$repo" gc --prune=now --quiet 2>/dev/null || printf '  %s[WARN]%s git gc failed: %s\n' "$RED" "$NC" "$rel_path"
        fi
    done < <(find "$TARGET_DIR" -maxdepth 4 -type d -name '.git' -print0 2>/dev/null)
}

# --- Main ---
main() {
    local start_time
    start_time=$(date +%s)

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Dev Repository Cleanup%s\n' "$BOLD" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf ' Target: %s\n' "$TARGET_DIR"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE — nothing will be deleted%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"

    clean_always_safe "$TARGET_DIR"
    echo
    clean_conditional "$TARGET_DIR"
    echo
    clean_system_caches
    echo
    run_git_gc

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Summary%s\n' "$BOLD" "$NC"
    if $DRY_RUN; then
        printf '  Would remove: %s\n' "$(human_bytes "$TOTAL_REMOVED")"
    else
        printf '  Removed: %s\n' "$(human_bytes "$TOTAL_REMOVED")"
    fi
    printf '  Duration: %dm %ds\n' "$((duration / 60))" "$((duration % 60))"
    printf '  Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n' "$BOLD" "$NC"
}

main
