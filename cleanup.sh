#!/usr/bin/env bash
# cleanup.sh - Disk reclaim for dev repositories
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
#   -g, --git-gc         Run git gc on all repos
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
FAILURES=0

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage: cleanup.sh [OPTIONS]

Disk reclaim: remove regenerable build artifacts from dev repositories.

Options:
  -n, --dry-run        Show what would be deleted without deleting
  -s, --system-caches  Also clean system caches (~/.cache/pip, etc.)
  -g, --git-gc         Run git gc on all repos
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

# Resolve symlinks: find(1) in default -P mode will not descend through a symlinked
# starting point, so `-d <symlink>` would silently scan nothing and exit 0.
TARGET_DIR="$(readlink -f -- "$TARGET_DIR")" || {
    printf '%sError: cannot resolve '\''%s'\''%s\n' "$RED" "$TARGET_DIR" "$NC" >&2
    exit 1
}

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

# Disk usage in bytes. `head -1` and the numeric guard are load-bearing: du prints
# `<size>\t<path>`, and a path containing a newline yields extra lines that cut passes
# through verbatim. That string reaches $(( )) below, where bash expands command
# substitutions inside array subscripts before reporting a syntax error — i.e. a
# directory *name* becomes arbitrary code. -B1 (not -b) so the total matches what the
# deletion actually reclaims.
get_size_bytes() {
    local out
    out="$(du -sB1 -- "$1" 2>/dev/null | head -1 | cut -f1)"
    [[ "$out" =~ ^[0-9]+$ ]] || out=0
    printf '%s' "$out"
}

human_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

get_size_human() {
    human_bytes "$(get_size_bytes "$1")"
}

# Remove a directory. One du traversal, not two. TOTAL_REMOVED is credited only after
# the delete actually succeeds, so the summary cannot claim space it did not reclaim.
safe_remove() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then return 0; fi

    local size_bytes rel_path
    size_bytes="$(get_size_bytes "$dir")"
    rel_path="${dir#"$TARGET_DIR"/}"

    log_remove "$(human_bytes "$size_bytes")" "$rel_path"

    if $DRY_RUN; then
        TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
        return 0
    fi

    # Rename first so a partially-deleted tree is never left under the original name,
    # where the next run's `find` would no longer match it. Same parent, so this is a
    # plain rename; ${dir}.cleanup.$$ is reaped below and by reap_orphans() on entry.
    local tmp_name="${dir}.cleanup.$$"
    if mv -- "$dir" "$tmp_name" 2>/dev/null; then
        if rm -rf -- "$tmp_name"; then
            TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
            return 0
        fi
    elif rm -rf -- "$dir"; then
        TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
        return 0
    fi

    printf '  %s[WARN]%s Failed to remove: %s\n' "$RED" "$NC" "$rel_path"
    FAILURES=$((FAILURES + 1))
    return 1
}

# Remove a single file.
safe_remove_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then return 0; fi

    local size_bytes rel_path
    size_bytes="$(stat --printf='%s' -- "$file" 2>/dev/null)" || size_bytes=0
    [[ "$size_bytes" =~ ^[0-9]+$ ]] || size_bytes=0
    rel_path="${file#"$TARGET_DIR"/}"

    log_remove "$(human_bytes "$size_bytes")" "$rel_path"

    if $DRY_RUN; then
        TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
        return 0
    fi

    if rm -f -- "$file"; then
        TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
        return 0
    fi

    printf '  %s[WARN]%s Failed to remove: %s\n' "$RED" "$NC" "$rel_path"
    FAILURES=$((FAILURES + 1))
    return 1
}

# Reap orphans left by a previous run that died between the rename and the delete.
# Nothing else ever matches these names again, so without this they persist forever
# and get backed up.
reap_orphans() {
    local n=0 d
    while IFS= read -r -d '' d; do
        if $DRY_RUN; then
            printf '  %s[DRY-RUN]%s orphan from an interrupted run: %s\n' \
                "$YELLOW" "$NC" "${d#"$TARGET_DIR"/}"
        else
            rm -rf -- "$d" 2>/dev/null || FAILURES=$((FAILURES + 1))
        fi
        n=$((n + 1))
    done < <(find "$TARGET_DIR" -depth -type d -name '*.cleanup.[0-9]*' -print0 2>/dev/null)
    [[ $n -gt 0 ]] && log "  Reaped $n orphaned .cleanup.* director$([[ $n -eq 1 ]] && echo y || echo ies)"
    return 0
}

# Answer "is this path precious?" — true means don't delete. Fails CLOSED: any git
# error (a corrupt .git/index still lets rev-parse succeed, then ls-files exits 128)
# is treated as tracked, because empty output from a *failed* command is
# indistinguishable from empty output meaning "untracked".
is_git_tracked() {
    local dir="$1"
    local repo_root dir_name
    repo_root="$(dirname "$dir")"
    dir_name="$(basename "$dir")"

    if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
        # Not in a git repo — assume precious, don't delete
        return 0
    fi

    # A nested checkout anywhere inside is its own history, unrecoverable from the
    # parent — e.g. a hand-cloned vendor/foo in a repo that gitignores vendor/.
    if [[ -n "$(find "$dir" -name '.git' -print -quit 2>/dev/null)" ]]; then
        return 0
    fi

    local tracked status
    tracked="$(git -C "$repo_root" ls-files -- "$dir_name/" 2>/dev/null)"
    status=$?
    if [[ $status -ne 0 ]]; then
        return 0    # git failed — fail closed
    fi
    [[ -n "$tracked" ]]
}

# True if any cargo profile lock under this target dir is currently held.
target_in_use() {
    local lock
    for lock in "$1"/*/.cargo-lock; do
        [[ -f "$lock" ]] || continue
        flock -n "$lock" true 2>/dev/null || return 0
    done
    return 1
}

# A directory that is a virtualenv and nothing else. `python -m venv .` in a project
# root puts pyvenv.cfg right next to the source, so a pyvenv.cfg alone is not enough:
# refuse anything that also looks like a project or a repository.
is_plain_venv() {
    local d="$1" m
    [[ -f "$d/pyvenv.cfg" || -f "$d/bin/activate" ]] || return 1
    [[ -e "$d/bin/python" || -e "$d/bin/activate" || -d "$d/lib" ]] || return 1
    for m in .git pyproject.toml setup.py setup.cfg package.json Cargo.toml requirements.txt src; do
        [[ -e "$d/$m" ]] && return 1
    done
    return 0
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

    # Rust target/ (only with sibling Cargo.toml), skipping any a build is using right
    # now: deleting under a running cargo just breaks that build. cargo holds an flock
    # on <profile>/.cargo-lock for the duration, so a failed non-blocking flock means
    # the directory is in use.
    log "  Scanning Rust target/ directories..."
    while IFS= read -r -d '' cargo; do
        local parent="${cargo%/Cargo.toml}"
        if [[ -d "$parent/target" ]]; then
            if target_in_use "$parent/target"; then
                log_skip "${parent#"$root"/}/target" "in use by a running cargo build"
            else
                safe_remove "$parent/target"
            fi
        fi
    done < <(find "$root" -type f -name 'Cargo.toml' -not -path '*/target/*' -print0 2>/dev/null)

    # Node node_modules/ (prune to skip nested)
    log "  Scanning node_modules/ directories..."
    while IFS= read -r -d '' dir; do
        safe_remove "$dir"
    done < <(find "$root" -type d -name 'node_modules' -prune -print0 2>/dev/null)

    # Python venvs: the conventional names, plus any directory holding a pyvenv.cfg
    # (venv-e2e, train_venv, ... — 16 GB of those were missed by name alone). One
    # traversal: named dirs are pruned so their own pyvenv.cfg isn't reported twice.
    log "  Scanning Python virtual environments..."
    while IFS= read -r -d '' hit; do
        local dir="$hit"
        [[ "$(basename "$hit")" == pyvenv.cfg ]] && dir="$(dirname "$hit")"
        if is_plain_venv "$dir"; then
            safe_remove "$dir"
        else
            log_skip "${dir#"$root"/}" "not a standalone Python venv"
        fi
    done < <(find "$root" \( -type d \( -name node_modules -o -name target \) -prune \) -o \
                          \( -type d \( -name 'venv' -o -name '.venv' -o -name 'deploy-venv' \) -prune -print0 \) -o \
                          \( -type f -name pyvenv.cfg -print0 \) 2>/dev/null)

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

    # Stray .pyc files — only those NOT under a __pycache__, which the sweep above has
    # already taken. Without the -path filter this is a full-tree traversal that finds
    # nothing in a real run, while in --dry-run it reports every .pyc in the tree as
    # "stray" (412k of them here, all of them inside __pycache__) and inflates the count.
    local pyc_count=0
    while IFS= read -r -d '' file; do
        if ! $DRY_RUN; then
            rm -f -- "$file" 2>/dev/null || FAILURES=$((FAILURES + 1))
        fi
        pyc_count=$((pyc_count + 1))
    done < <(find "$root" -type f -name '*.pyc' -not -path '*/__pycache__/*' -print0 2>/dev/null)
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

    # _site/ — static site generator output. The git gate is not optional here: this was
    # the one Phase-2 rule without it, and it deleted committed _site/ trees.
    log "  Scanning _site/ directories..."
    while IFS= read -r -d '' dir; do
        local parent
        parent="$(dirname "$dir")"
        if is_git_tracked "$dir"; then
            log_skip "${dir#"$root"/}" "git-tracked"
        elif has_project_file "$parent" _config.yml Gemfile package.json; then
            safe_remove "$dir"
        else
            log_skip "${dir#"$root"/}" "no site generator config"
        fi
    done < <(find "$root" -type d -name '_site' -not -path '*/node_modules/*' -print0 2>/dev/null)

    # vendor/ — only if not git-tracked. No -maxdepth: the old limit of 3 reached exactly
    # one directory here while ~1000 real vendor/ dirs sat deeper, so the rule was inert.
    # is_git_tracked() also refuses anything containing its own .git (nested checkout).
    log "  Scanning vendor/ directories..."
    while IFS= read -r -d '' dir; do
        if is_git_tracked "$dir"; then
            log_skip "${dir#"$root"/}" "git-tracked"
        else
            safe_remove "$dir"
        fi
    done < <(find "$root" -type d -name 'vendor' -not -path '*/node_modules/*' -print0 2>/dev/null)
}

# --- Phase 3: System caches ---
# NOTE: this reclaims DISK, not backup size. Every path below is already outside the
# snapshot — the ones under ~/.cache via backup.sh's --exclude, and ~/.npm/_cacache via
# its own CACHEDIR.TAG + --exclude-caches. Running this before a backup buys zero
# repository bytes and costs a full sccache/pip/HF re-download. backup.sh -c does not
# pass -s, and must not.
clean_system_caches() {
    log "Phase 3: System caches (disk reclaim only — saves no backup space)"

    if ! $SYSTEM_CACHES; then
        log "  Skipped (use --system-caches or --all to enable)"
        return
    fi

    local caches=(
        "$HOME/.cache/sccache"
        "$HOME/.cache/pip"
        "$HOME/.cache/pip-tools"
        "$HOME/.cache/uv"
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
            local size_bytes
            size_bytes="$(get_size_bytes "$cache")"

            if $DRY_RUN; then
                printf '  %s[DRY-RUN]%s %9s  %s\n' "$YELLOW" "$NC" "$(human_bytes "$size_bytes")" "$cache"
                TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
            else
                printf '  %s[REMOVE]%s  %9s  %s\n' "$RED" "$NC" "$(human_bytes "$size_bytes")" "$cache"
                if rm -rf -- "$cache"; then
                    TOTAL_REMOVED=$((TOTAL_REMOVED + size_bytes))
                else
                    printf '  %s[WARN]%s Failed to remove: %s\n' "$RED" "$NC" "$cache"
                    FAILURES=$((FAILURES + 1))
                fi
            fi
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

    # No --prune=now: git-gc(1) warns it "increases the risk of corruption if another
    # process is writing to the repository concurrently", and this runs unattended over
    # dozens of repos. The default two-week grace period still reclaims the space.
    # -type d only matches real repos; worktrees have a .git *file* and are gc'd via
    # their parent, which shares the object store.
    while IFS= read -r -d '' gitdir; do
        local repo
        repo="$(dirname "$gitdir")"
        local rel_path="${repo#"$TARGET_DIR"/}"
        if $DRY_RUN; then
            printf '  %s[DRY-RUN]%s git gc: %s\n' "$YELLOW" "$NC" "$rel_path"
        else
            printf '  %s[GC]%s      git gc: %s\n' "$CYAN" "$NC" "$rel_path"
            git -C "$repo" gc --quiet 2>/dev/null || {
                printf '  %s[WARN]%s git gc failed: %s\n' "$RED" "$NC" "$rel_path"
                FAILURES=$((FAILURES + 1))
            }
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

    reap_orphans
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
    if [[ $FAILURES -gt 0 ]]; then
        printf '  %sFailures: %d%s (see [WARN] lines above)\n' "$RED" "$FAILURES" "$NC"
    fi
    printf '  Duration: %dm %ds\n' "$((duration / 60))" "$((duration % 60))"
    printf '  Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n' "$BOLD" "$NC"

    # An exit status callers can act on. Without this the script could only ever
    # exit 0, so backup.sh checking it would be a no-op.
    [[ $FAILURES -eq 0 ]]
}

main
exit $?
