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
#   -s, --system-caches  Also clean system caches (~/.cache/pip, etc.) and repo .cache/ dirs
#   -D, --docker         Also prune unused Docker images, build cache and cache volumes
#   -g, --git-gc         Run git gc on all repos
#   -a, --all            Enable --system-caches + --git-gc (not --docker)
#   -d, --dir DIR        Target a specific directory (default: ~/dev/repositories)
#   -h, --help           Show help

# shellcheck disable=SC2317  # handlers are invoked indirectly, by scan()
set -uo pipefail

# --- Constants ---
DEFAULT_ROOT="$HOME/dev/repositories"
LOG_DIR="$HOME/.dot/logs"
LOG_KEEP=30
BOLD=$'\033[1m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# Directories are renamed to <name>.$TRASH_SUFFIX.<pid> before deletion; leftovers of an
# interrupted run are deleted on sight, so the suffix must never collide with a real name.
TRASH_SUFFIX="cleanup-sh-trash"
TRASH_GLOB="*.$TRASH_SUFFIX.[0-9]*"

# Phase 1 directory names (fd globs). Phase 1 never descends into them and Phase 2 never
# looks inside them. .cache is only removed by -s (Phase 3).
P1_DIRS=(
    target node_modules venv .venv deploy-venv
    __pycache__ .mypy_cache .pytest_cache .ruff_cache .tox .nox .eggs .hypothesis htmlcov
    '*.egg-info' '.aider.tags.cache.*'
    .nx .next .nuxt .svelte-kit .turbo .parcel-cache .angular .sass-cache
    .terraform .direnv .stack-work dist-newstyle .dart_tool zig-cache .zig-cache zig-out
    .cache
)
P1_FILES=(pyvenv.cfg '*.pyc' .coverage '.coverage.*')
# Never walked: git internals (a branch vendor/x is a .git/refs/heads/vendor/ dir) and
# installed packages or crate sources, where generic names belong to dependencies.
WALK_EXCLUDES=(--exclude .git --exclude site-packages --exclude dist-packages --exclude .cargo)

# --- Defaults ---
DRY_RUN=false
SYSTEM_CACHES=false
DOCKER=false
GIT_GC=false
TARGET_DIR="$DEFAULT_ROOT"
TOTAL_REMOVED=0
FAILURES=0
declare -A GONE=()      # paths removed this run (or that would be, in dry-run)
REPO_CACHES=()          # repo-local .cache/ dirs, for Phase 3

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage: cleanup.sh [OPTIONS]

Disk reclaim: remove regenerable build artifacts from dev repositories.

Options:
  -n, --dry-run        Show what would be deleted without deleting
  -s, --system-caches  Also clean system caches (~/.cache/pip, etc.) and repo .cache/ dirs
  -D, --docker         Also prune unused Docker images, build cache and cache volumes
  -g, --git-gc         Run git gc on all repos
  -a, --all            Enable --system-caches + --git-gc (not --docker)
  -d, --dir DIR        Target a specific directory (default: ~/dev/repositories)
  -h, --help           Show this help
EOF
    exit 0
}

die() {
    printf '%sError: %s%s\n' "$RED" "$1" "$NC" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=true; shift ;;
        -s|--system-caches) SYSTEM_CACHES=true; shift ;;
        -D|--docker)   DOCKER=true; shift ;;
        -g|--git-gc)   GIT_GC=true; shift ;;
        -a|--all)      SYSTEM_CACHES=true; GIT_GC=true; shift ;;
        -d|--dir)      TARGET_DIR="${2:?--dir requires an argument}"; shift 2 ;;
        -h|--help)     usage ;;
        *)             die "unknown option: $1" ;;
    esac
done

# fd, not find: one pruned walk of ~/dev/repositories takes 1.7 s vs 45 s.
for cmd in fd git; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

# Git must answer about the repository on disk: not one inherited from the caller (a
# hook's GIT_DIR), and with pathspec magic enabled (GIT_LITERAL_PATHSPECS would make
# every ":(literal)" lookup miss, so tracked directories would read as untracked).
# shellcheck disable=SC2046  # word splitting intended
unset $(git rev-parse --local-env-vars) GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS \
    GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS GIT_CEILING_DIRECTORIES

[[ -d "$TARGET_DIR" ]] || die "'$TARGET_DIR' is not a directory"
# $(readlink) would drop a trailing newline and silently target a sibling directory.
[[ "$TARGET_DIR" != *$'\n'* ]] || die "refusing a directory name containing a newline"

# Resolve symlinks: fd does not descend through a symlinked starting point.
TARGET_DIR="$(readlink -f -- "$TARGET_DIR")" || die "cannot resolve '$TARGET_DIR'"

# /, $HOME and its dot-dirs hold installed tools the rules below would match (pipx/uv
# tool venvs, global npm packages, editor plugins), not repositories.
home_real="$(readlink -f -- "$HOME")"
if [[ "$TARGET_DIR" == / || "$home_real" == "$TARGET_DIR" || "$home_real" == "$TARGET_DIR"/* \
      || "$TARGET_DIR" == "$home_real"/.* ]]; then
    die "refusing to clean '$TARGET_DIR' (/, \$HOME, a parent of it, or a dot-dir in it)"
fi

# Every mount point (findmnt -r escapes them as \xNN). rm --one-file-system only compares
# device numbers, so it would delete through a same-device bind mount inside a candidate.
mapfile -t MOUNTS < <(findmnt -rn -o TARGET | while IFS= read -r m; do printf '%b\n' "$m"; done)

# --- Logging setup ---
mkdir -p "$LOG_DIR"

# One run at a time: two runs would rename and delete the same trees.
exec {LOCK_FD}>"$LOG_DIR/cleanup.lock"
flock -n "$LOCK_FD" || die "another cleanup.sh is running"

# Keep the newest LOG_KEEP logs, this run's included. Timestamped names sort by age.
printf '%s\0' "$LOG_DIR"/cleanup-*.log | sort -zr | tail -zn +"$LOG_KEEP" | xargs -0r rm -f --
LOG_FILE="$LOG_DIR/cleanup-$(date '+%Y-%m-%dT%H%M%S').log"

# Tee all output to both terminal and log file; tee is waited for at exit.
exec > >(tee -a "$LOG_FILE") 2>&1
TEE_PID=$!

# --- Helper functions ---
log() {
    printf '%s[%s]%s %s\n' "$CYAN" "$(date '+%H:%M:%S')" "$NC" "$1"
}

warn() {
    printf '  %s[WARN]%s %s\n' "$RED" "$NC" "$1"
    FAILURES=$((FAILURES + 1))
}

rel() {
    printf '%s' "${1#"$TARGET_DIR"/}"
}

log_remove() {
    if $DRY_RUN; then
        printf '  %s[DRY-RUN]%s %9s  %s\n' "$YELLOW" "$NC" "$1" "$2"
    else
        printf '  %s[REMOVE]%s  %9s  %s\n' "$RED" "$NC" "$1" "$2"
    fi
}

log_skip() {
    printf '  %s[SKIP]%s               %s  (%s)\n' "$GREEN" "$NC" "$1" "$2"
}

# Disk usage in bytes. head -1 and the numeric guard are load-bearing: a path with a
# newline makes du print extra lines, and a non-number reaching $(( )) can execute code
# embedded in a directory name. -B1 so the total matches what deletion reclaims.
get_size_bytes() {
    local out
    out="$(du -sB1 -- "$1" 2>/dev/null | head -1 | cut -f1)"
    [[ "$out" =~ ^[0-9]+$ ]] || out=0
    printf '%s' "$out"
}

human_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

# True if $1, or a directory above it, was removed this run.
already_removed() {
    local p="$1"
    while [[ "$p" == "$TARGET_DIR"/* ]]; do
        [[ -n "${GONE[$p]+x}" ]] && return 0
        p="${p%/*}"
    done
    return 1
}

# True if $1 is, or contains, a mount point.
holds_mount() {
    local m
    for m in "${MOUNTS[@]}"; do
        [[ "$m" == "$1" || "$m" == "$1"/* ]] && return 0
    done
    return 1
}

# Delete a file or directory and credit its size. Symlinks are kept: a target/ symlink to
# a shared build dir is configuration. A directory under TARGET_DIR is renamed first, so
# a build started after the in-use check gets a fresh one; it is measured and deleted
# under the TRASH_GLOB name, which the next run removes if this delete is interrupted.
# If the rename fails, nothing is deleted in place.
remove() {
    local path="$1" victim="$1" size
    if [[ -L "$path" ]]; then
        log_skip "$(rel "$path")" "symlink"
        return 0
    fi
    [[ -e "$path" ]] || return 0
    if holds_mount "$path"; then
        log_skip "$(rel "$path")" "mount point inside"
        return 0
    fi

    # shellcheck disable=SC2053  # $TRASH_GLOB is a glob on purpose
    if ! $DRY_RUN && [[ -d "$path" && "$path" == "$TARGET_DIR"/* && "${path##*/}" != $TRASH_GLOB ]]; then
        victim="$path.$TRASH_SUFFIX.$$"
        if ! mv -T --no-copy -- "$path" "$victim"; then
            warn "Failed to remove: $(rel "$path")"
            return 1
        fi
    fi
    size="$(get_size_bytes "$victim")"
    log_remove "$(human_bytes "$size")" "$(rel "$path")"

    if ! $DRY_RUN && ! rm -rf --one-file-system -- "$victim"; then
        warn "Failed to remove: $(rel "$path")"
        return 1
    fi
    GONE["$path"]=1
    TOTAL_REMOVED=$((TOTAL_REMOVED + size))
}

# Git's view of directory $1: tracked, ignored (untracked, all of it gitignored),
# unignored (untracked files git would show), outside (no repository) or error. Fails
# closed: when git refuses a repository that is there (dubious ownership, a worktree
# whose main repo moved), a .git above $1 makes the answer error, never outside.
git_status() {
    local parent="${1%/*}" inside d out
    inside="$(git -C "$parent" rev-parse --is-inside-work-tree 2>/dev/null)"
    if [[ -z "$inside" ]]; then
        d="$parent"
        while [[ -n "$d" ]]; do
            if [[ -e "$d/.git" ]]; then
                echo error
                return
            fi
            d="${d%/*}"
        done
        echo outside
    elif [[ "$inside" != true ]]; then
        echo error
    else
        git -C "$parent" ls-files --error-unmatch -- ":(literal)${1##*/}/" >/dev/null 2>&1
        case $? in
            0) echo tracked; return ;;
            1) ;;
            *) echo error; return ;;
        esac
        if ! out="$(git -C "$parent" ls-files --others --exclude-standard --directory \
                        --no-empty-directory -- ":(literal)${1##*/}/" 2>/dev/null)"; then
            echo error
        elif [[ -n "$out" ]]; then
            echo unignored
        else
            echo ignored
        fi
    fi
}

# Delete $1 unless git says it holds tracked or non-ignored files, or cannot say.
remove_untracked() {
    case "$(git_status "$1")" in
        outside|ignored)   remove "$1" ;;
        tracked)           log_skip "$(rel "$1")" "git-tracked files inside" ;;
        unignored)         log_skip "$(rel "$1")" "untracked files not gitignored" ;;
        *)                 log_skip "$(rel "$1")" "git error" ;;
    esac
}

# True if $1 holds a CACHEDIR.TAG with the spec's signature (bford.info/cachedir):
# a bare file of that name proves nothing.
is_cache_dir() {
    [[ -f "$1/CACHEDIR.TAG" && ! -L "$1/CACHEDIR.TAG" &&
       "$(head -c 43 "$1/CACHEDIR.TAG" 2>/dev/null)" == "Signature: 8a477f597d28d172789f06886806bc55" ]]
}

# Prints why $1 must be kept if it holds a VCS checkout outside a cache, or nothing.
# Checkouts under a directory tagged with CACHEDIR.TAG are tool-managed (cargo's
# git/checkouts, uv's git-v*/checkouts); any other is its own history, unrecoverable from
# the parent. Fails closed: find fails on an unreadable subtree, which may hide one.
checkout_reason() {
    local hits hit d
    mapfile -d '' hits < <(find "$1" \( -name .git -o -name .hg -o -name .svn -o -name .jj \) \
                               -prune -print0 2>/dev/null)
    if ! wait "$!"; then
        echo "unreadable inside"
        return
    fi
    for hit in "${hits[@]}"; do
        d="${hit%/*}"
        while [[ "$d" == "$1"/* ]] && ! is_cache_dir "$d"; do
            d="${d%/*}"
        done
        if ! is_cache_dir "$d"; then
            echo "contains a nested checkout"
            return
        fi
    done
}

# Rule for generic names (Phase 2, repo .cache): gitignored inside a work tree, holding
# no nested checkout (see checkout_reason).
remove_unless_kept() {
    local reason=""
    case "$(git_status "$1")" in
        outside)   reason="not in a git work tree" ;;
        tracked)   reason="git-tracked" ;;
        unignored) reason="untracked files not gitignored" ;;
        ignored)   reason="$(checkout_reason "$1")" ;;
        *)         reason="git error" ;;
    esac
    if [[ -n "$reason" ]]; then
        log_skip "$(rel "$1")" "$reason"
    else
        remove "$1"
    fi
}

# True if a cargo build holds a lock under target dir $1, or the locks cannot all be
# found (an unreadable subdirectory may hide one). cargo 1.99 locks
# <profile>/.cargo{,-build,-artifact}-lock; cross builds nest that under <triple>/.
target_in_use() {
    local locks lock
    mapfile -d '' locks < <(find "$1" -maxdepth 3 -type f -name '.cargo*lock' -print0 2>/dev/null)
    wait "$!" || return 0
    for lock in "${locks[@]}"; do
        flock -n "$lock" true 2>/dev/null || return 0
    done
    return 1
}

# A virtualenv and nothing else: every top-level entry is one that venv, virtualenv or uv
# creates. `python -m venv .` in a work directory puts pyvenv.cfg next to the user's files.
is_plain_venv() (
    shopt -s nullglob dotglob
    [[ -f "$1/pyvenv.cfg" ]] || exit 1
    for e in "$1"/*; do
        case "${e##*/}" in
            pyvenv.cfg|bin|lib|lib64|include|share|etc|Scripts|.gitignore|.lock|CACHEDIR.TAG|\
            LICENSE.txt|pip-selfcheck.json) ;;
            *) exit 1 ;;
        esac
    done
)

remove_venv() {
    if is_plain_venv "$1"; then
        remove_untracked "$1"
    else
        log_skip "$(rel "$1")" "not a standalone Python venv"
    fi
}

is_p1_dir() {
    local g
    for g in "${P1_DIRS[@]}"; do
        # shellcheck disable=SC2053  # $g is a glob on purpose
        [[ "$1" == $g ]] && return 0
    done
    return 1
}

has_project_file() {
    local parent="$1" f
    shift
    for f in "$@"; do
        [[ -f "$parent/$f" ]] && return 0
    done
    return 1
}

# fd glob matching any of the arguments.
any_of() {
    local IFS=,
    printf '{%s}' "$*"
}

# Call handler $1 on each path under TARGET_DIR matching fd options "${@:2}", parent-first
# and skipping anything already removed. -u: hidden and ignored files too; -s:
# case-sensitive. fd's trailing '/' on directories is stripped, and a pyvenv.cfg (only
# Phase 1 matches it) becomes its venv directory, sorting it ahead of its contents. A
# failed fd, or one that could not read part of the tree (it still exits 0), is a
# failure: an incomplete scan would otherwise report success.
scan() {
    local handler="$1" in pid p errors
    shift
    errors="$(mktemp)"
    exec {in}< <(fd -u -s -g -0 --one-file-system --show-errors "$@" "$TARGET_DIR" 2>"$errors" \
                 | sed -z -e 's#/$##' -e 's#/pyvenv\.cfg$##' | LC_ALL=C sort -z)
    pid=$!
    while IFS= read -r -d '' -u "$in" p; do
        already_removed "$p" || "$handler" "$p"
    done
    exec {in}<&-
    wait "$pid" || warn "scan failed: fd exited non-zero"
    if [[ -s "$errors" ]]; then
        sed 's/^/  /' "$errors"
        warn "scan incomplete: fd could not read the paths above"
    fi
    rm -f -- "$errors"
}

# --- Phase 1: Always-safe removals ---
clean_p1_path() {
    local p="$1" name="${1##*/}" sub
    if [[ -L "$p" ]]; then
        log_skip "$(rel "$p")" "symlink"
        return
    fi
    if [[ -f "$p" ]]; then
        case "$name" in
            *.pyc|.coverage|.coverage.*) remove "$p" ;;
        esac
        return
    fi

    # shellcheck disable=SC2254  # $TRASH_GLOB is a glob on purpose
    case "$name" in
        target)
            # Rust only, and not while a build is using it.
            [[ -f "${p%/*}/Cargo.toml" ]] || return
            if target_in_use "$p"; then
                log_skip "$(rel "$p")" "in use by a cargo build, or unreadable"
            else
                remove_untracked "$p"
            fi ;;
        venv|.venv|deploy-venv)
            remove_venv "$p" ;;
        .nx)
            # Caches only: an Nx standalone install commits .nx/installation and nxw.js.
            for sub in "$p"/{cache,workspace-data} "$p"/$TRASH_GLOB; do
                [[ -d "$sub" ]] && remove_untracked "$sub"
            done ;;
        .cache)
            REPO_CACHES+=("$p") ;;
        $TRASH_GLOB)
            remove "$p" ;;
        *)
            if is_p1_dir "$name"; then
                remove_untracked "$p"
            elif [[ -f "$p/pyvenv.cfg" && "$p" != "$TARGET_DIR" ]]; then
                remove_venv "$p"    # venv under another name (venv-e2e, train_venv, ...)
            fi ;;
    esac
}

clean_always_safe() {
    log "Phase 1: Always-safe build artifacts"
    scan clean_p1_path --prune "${WALK_EXCLUDES[@]}" \
        "$(any_of "${P1_DIRS[@]}" "${P1_FILES[@]}" "$TRASH_GLOB")"
}

# --- Phase 2: Conditional removals ---
# Generic names: each needs a project file beside it (except vendor/), then the
# remove_unless_kept rule.
clean_p2_path() {
    local dir="$1" parent="${1%/*}" reason=""
    case "$dir" in
        */registry/src/*|*/git/checkouts/*) return ;;   # crate sources (any CARGO_HOME)
    esac
    case "${dir##*/}" in
        dist)   has_project_file "$parent" package.json Cargo.toml \
                    || reason="no known project file" ;;
        build)  has_project_file "$parent" package.json Cargo.toml setup.py pyproject.toml \
                    CMakeLists.txt Makefile build.gradle || reason="no known build system" ;;
        _site)  has_project_file "$parent" _config.yml Gemfile package.json \
                    || reason="no site generator config" ;;
        vendor) ;;
        *)      return ;;
    esac
    if [[ -n "$reason" ]]; then
        log_skip "$(rel "$dir")" "$reason"
    else
        remove_unless_kept "$dir"
    fi
}

clean_conditional() {
    log "Phase 2: Conditional artifacts (checking git tracking)"
    local excludes=("${WALK_EXCLUDES[@]}") g
    for g in "${P1_DIRS[@]}" "$TRASH_GLOB"; do
        excludes+=(--exclude "$g")
    done
    scan clean_p2_path -t d "${excludes[@]}" '{dist,build,_site,vendor}'
}

# --- Phase 3: System caches ---
# Reclaims disk, not backup size: ~/.cache is excluded by backup.sh, and ~/.npm/_cacache
# and ~/.cargo/registry carry a CACHEDIR.TAG. Costs a full re-download, so backup.sh -c
# does not pass -s, and must not.
clean_system_caches() {
    log "Phase 3: System caches (disk reclaim only — saves no backup space)"

    if ! $SYSTEM_CACHES; then
        log "  Skipped (use --system-caches or --all to enable)"
        return
    fi

    # huggingface by subdir: `huggingface-cli login` keeps its token in the parent.
    local caches=(
        "$HOME/.cache/sccache"
        "$HOME/.cache/pip"
        "$HOME/.cache/pip-tools"
        "$HOME/.cache/uv"
        "$HOME/.npm/_cacache"
        "$HOME/.cache/huggingface/hub"
        "$HOME/.cache/huggingface/xet"
        "$HOME/.cache/huggingface/datasets"
        "$HOME/.cache/huggingface/modules"
        "$HOME/.cache/yarn"
        "$HOME/.cache/pnpm"
        "$HOME/.cache/ms-playwright"
        "$HOME/.cache/google-chrome-headless"
        "$HOME/.cache/puccinialin"
        "$HOME/.cache/node-gyp"
        "$HOME/.cache/node"
        "$HOME/.cache/go-build"
    )

    # Running builds read crate sources. Not git/db: it can hold the only copy of a
    # Cargo.lock-pinned commit that was force-pushed away upstream.
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    if pgrep -x cargo >/dev/null 2>&1; then
        log_skip "$cargo_home/{registry,git}" "cargo is running"
    else
        caches+=("$cargo_home"/registry/{cache,src} "$cargo_home/git/checkouts")
    fi

    local path
    for path in "${caches[@]}"; do
        remove "$path"
    done
    for path in "${REPO_CACHES[@]}"; do
        already_removed "$path" || remove_unless_kept "$path"
    done
}

# --- Phase 4: Docker ---
# Unused images (re-pulled or rebuilt on demand), the build cache, and unused volumes that
# are anonymous or named like a cargo build cache (*-target, *-tgt). Other named volumes
# (redis, prometheus, ...) are never touched. Docker reports its own sizes, in its own
# units, so they are not part of the summary total.
removable_volume() {
    case "$1" in
        *-target|*-target-*|*-tgt) return 0 ;;
    esac
    [[ "$1" =~ ^[0-9a-f]{64}$ ]]
}

clean_docker() {
    log "Phase 4: Docker (sizes as reported by docker, not in the total)"
    if ! $DOCKER; then
        log "  Skipped (use --docker to enable)"
        return
    fi
    if ! docker info >/dev/null 2>&1; then
        log_skip "docker" "daemon not reachable"
        return
    fi

    local -A unused=()
    local name size type reclaimable out
    while IFS= read -r name; do
        unused["$name"]=1
    done < <(docker volume ls -q --filter dangling=true)
    while IFS='|' read -r name size; do
        if [[ -z "${unused[$name]+x}" ]] || ! removable_volume "$name"; then
            continue
        fi
        log_remove "$size" "docker volume $name"
        $DRY_RUN || docker volume rm "$name" >/dev/null || warn "Failed to remove docker volume: $name"
    done < <(docker system df -v --format '{{range .Volumes}}{{.Name}}|{{.Size}}{{println}}{{end}}')

    if $DRY_RUN; then
        while IFS='|' read -r type reclaimable; do
            case "$type" in
                Images|"Build Cache") log_remove "${reclaimable%% *}" "docker ${type,,} (unused)" ;;
            esac
        done < <(docker system df --format '{{.Type}}|{{.Reclaimable}}')
        return
    fi
    for type in image builder; do
        if out="$(docker "$type" prune -a -f 2>&1)"; then
            printf '  %s[REMOVE]%s  docker %s prune: %s\n' "$RED" "$NC" "$type" "$(tail -1 <<<"$out")"
        else
            warn "docker $type prune failed: $(tail -1 <<<"$out")"
        fi
    done
}

# --- Phase 5: Git GC ---
# No --prune=now: git-gc(1) warns it risks corruption under concurrent writers, and the
# default two-week grace period still reclaims the space. Matching .git directories
# skips worktrees (.git file); they share their parent's object store.
gc_repo() {
    local repo="${1%/*}"
    if $DRY_RUN; then
        printf '  %s[DRY-RUN]%s git gc: %s\n' "$YELLOW" "$NC" "$(rel "$repo")"
    else
        printf '  %s[GC]%s      git gc: %s\n' "$CYAN" "$NC" "$(rel "$repo")"
        git -C "$repo" gc --quiet || warn "git gc failed: $(rel "$repo")"
    fi
}

run_git_gc() {
    log "Phase 5: Git GC"
    if ! $GIT_GC; then
        log "  Skipped (use --git-gc or --all to enable)"
        return
    fi
    scan gc_repo -t d --prune --max-depth 4 --exclude node_modules --exclude target .git
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

    clean_always_safe
    echo
    clean_conditional
    echo
    clean_system_caches
    echo
    clean_docker
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

    # Non-zero on any failure; backup.sh checks it.
    [[ $FAILURES -eq 0 ]]
}

main
rc=$?
exec >&- 2>&-       # EOF to tee, then wait so the log is complete before we return
wait "$TEE_PID" 2>/dev/null
exit "$rc"
