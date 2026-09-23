#!/usr/bin/env bash
# archive.sh - Clean, compress, and archive a directory or re-compress an existing archive
#
# Usage:
#   archive.sh <directory>              Archive a directory to .tar.zst
#   archive.sh -x <file.tar.zst>       Extract archive to directory
#   archive.sh <file.tar.bz2|.tar.gz>  Re-compress to .tar.zst
#   archive.sh --recompress-all DIR     Batch re-compress all archives in DIR
#
# Options:
#   -n, --dry-run          Show what would happen
#   -k, --keep             Keep original after archiving/extracting
#   -x, --extract          Extract a .tar.zst archive to directory
#   -l, --level LEVEL      zstd compression level 1-19 (default: 9)
#   --no-cleanup           Skip artifact cleanup step (for directories)
#   --recompress-all DIR   Batch re-compress all .tar.bz2/.tar.gz in DIR
#   -h, --help             Show help

set -uo pipefail

# --- Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"
LOG_DIR="$HOME/.dot/logs"
BOLD=$'\033[1m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# --- Defaults ---
DRY_RUN=false
KEEP_ORIGINAL=false
COMPRESSION_LEVEL=9
DO_CLEANUP=true
RECOMPRESS_ALL=""
EXTRACT=false
PARTIAL_OUTPUT=""   # Tracked for signal-trap cleanup

# --- Signal trap: remove partial output on abort ---
cleanup_on_exit() {
    set +u
    if [[ -n "$PARTIAL_OUTPUT" ]]; then
        printf '\n%s[ABORT]%s Removing partial output: %s\n' "$RED" "$NC" "$PARTIAL_OUTPUT"
        rm -rf -- "$PARTIAL_OUTPUT"
    fi
    set -u
}
trap cleanup_on_exit EXIT

# --- Argument parsing ---
usage() {
    cat <<'EOF'
Usage:
  archive.sh <directory>              Archive a directory to .tar.zst
  archive.sh -x <file.tar.zst>       Extract archive to directory
  archive.sh <file.tar.bz2|.tar.gz>  Re-compress an existing archive to .tar.zst
  archive.sh --recompress-all DIR     Batch re-compress all archives in DIR

Options:
  -n, --dry-run          Show what would happen
  -k, --keep             Keep original after archiving/extracting
  -x, --extract          Extract a .tar.zst archive to directory
  -l, --level LEVEL      zstd compression level 1-19 (default: 9)
  --no-cleanup           Skip artifact cleanup step (for directories)
  --recompress-all DIR   Batch re-compress all .tar.bz2/.tar.gz in DIR
  -h, --help             Show this help

Output format: .tar.zst (zstd with xxhash integrity checksum)
EOF
    exit "${1:-0}"
}

TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)       DRY_RUN=true; shift ;;
        -k|--keep)          KEEP_ORIGINAL=true; shift ;;
        -x|--extract)       EXTRACT=true; shift ;;
        -l|--level)         COMPRESSION_LEVEL="${2:?--level requires an argument}"; shift 2 ;;
        --no-cleanup)       DO_CLEANUP=false; shift ;;
        --recompress-all)   RECOMPRESS_ALL="${2:?--recompress-all requires a directory}"; shift 2 ;;
        -h|--help)          usage ;;
        -*)                 printf '%sUnknown option: %s%s\n' "$RED" "$1" "$NC" >&2; exit 1 ;;
        *)
            if [[ -n "$TARGET" ]]; then
                printf '%sError: unexpected argument '\''%s'\''%s\n' "$RED" "$1" "$NC" >&2; exit 1
            fi
            TARGET="$1"; shift ;;
    esac
done

# Validate compression level. Matched explicitly rather than with (( )): a leading zero
# makes bash parse the value as octal, so `019` errored out of the arithmetic and then
# short-circuited past this check.
if [[ ! "$COMPRESSION_LEVEL" =~ ^([1-9]|1[0-9])$ ]]; then
    printf '%sError: compression level must be an integer 1-19 (got: %s)%s\n' "$RED" "$COMPRESSION_LEVEL" "$NC" >&2
    exit 1
fi

# tar honours TAR_OPTIONS from the environment, so a stray --exclude there would omit
# files from an archive whose source this script then deletes. Refuse to guess.
if [[ -n "${TAR_OPTIONS:-}" ]]; then
    printf '%sError: TAR_OPTIONS is set (%s). Unset it — it silently changes what gets archived.%s\n' \
        "$RED" "$TAR_OPTIONS" "$NC" >&2
    exit 1
fi

# --- Logging setup ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/archive-$(date '+%Y-%m-%dT%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Helper functions ---
log() {
    printf '%s[%s]%s %s\n' "$CYAN" "$(date '+%H:%M:%S')" "$NC" "$1"
}

# Disk usage in bytes. `head -1` and the numeric guard are load-bearing: du prints
# `<size>\t<path>`, and a path containing a newline yields extra lines that cut passes
# through verbatim. That string reaches the arithmetic comparisons below, where bash
# expands command substitutions inside array subscripts before reporting a syntax
# error — i.e. a directory *name* becomes arbitrary code.
get_size_bytes() {
    local out
    if [[ -d "$1" ]]; then
        out="$(du -sB1 -- "$1" 2>/dev/null | head -1 | cut -f1)"
    elif [[ -f "$1" ]]; then
        out="$(stat --printf='%s' -- "$1" 2>/dev/null)"
    else
        out=0
    fi
    [[ "$out" =~ ^[0-9]+$ ]] || out=0
    printf '%s' "$out"
}

human_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

get_size_human() {
    human_bytes "$(get_size_bytes "$1")"
}

# Check available disk space in bytes for the filesystem containing a path
available_space() {
    local out
    out="$(df --output=avail -B1 -- "$(dirname -- "$1")" 2>/dev/null | tail -1 | tr -d ' ')"
    [[ "$out" =~ ^[0-9]+$ ]] || out=""
    printf '%s' "$out"
}

# Decompress every byte through both layers. Catches zstd frame damage and mid-member
# tar truncation — but NOT truncation landing on a member boundary, which tar accepts
# as a clean end-of-archive. count_members() below is what closes that gap.
verify_archive() {
    local archive="$1"
    tar -I zstd -xOf "$archive" > /dev/null 2>&1
}

# Number of entries tar sees in an archive.
count_members() {
    tar -I zstd -tf "$1" 2>/dev/null | wc -l
}

# Number of filesystem entries under a directory, counted the way tar counts them
# (the directory itself plus everything below it). Sockets are left out because tar
# skips them ("socket ignored") — counting them made any tree holding a stale socket
# fail the comparison and refuse to archive.
count_tree_entries() {
    find "$1" -mindepth 0 ! -type s -printf '.' 2>/dev/null | wc -c
}

# --- Mode 1: Archive a directory ---
archive_directory() {
    local target="$1"
    target="${target%/}"    # Strip trailing slash

    if [[ ! -d "$target" ]]; then
        printf '%sError: '\''%s'\'' is not a directory%s\n' "$RED" "$target" "$NC" >&2
        return 1
    fi

    local parent_dir dir_name archive
    parent_dir="$(cd "$(dirname "$target")" && pwd)"
    dir_name="$(basename "$target")"
    archive="$parent_dir/$dir_name.tar.zst"

    if [[ -f "$archive" ]]; then
        printf '%sError: '\''%s'\'' already exists%s\n' "$RED" "$archive" "$NC" >&2
        return 1
    fi

    local before_size before_human
    before_size="$(get_size_bytes "$target")"
    before_human="$(get_size_human "$target")"

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Archive: %s%s\n' "$BOLD" "$dir_name" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"

    # Cleanup is deliberately NOT run before the archive exists. It deletes
    # irreversibly, and every failure path below says "keeping original" — which was a
    # lie if cleanup had already mutated the tree. It now runs in Step 5, after the
    # archive is written and verified, and only when the source is about to go anyway.
    local clean_size
    clean_size="$before_size"

    # Check disk space
    local avail
    avail="$(available_space "$archive")"
    if [[ -n "$avail" && "$avail" -lt "$clean_size" ]]; then
        printf '%sError: Not enough disk space. Need ~%s, have %s%s\n' \
            "$RED" "$(human_bytes "$clean_size")" "$(human_bytes "$avail")" "$NC" >&2
        return 1
    fi

    # Step 1: Create archive
    log "Step 1: Creating archive (zstd level $COMPRESSION_LEVEL, $(nproc) threads)..."

    local src_entries
    src_entries="$(count_tree_entries "$target")"

    if $DRY_RUN; then
        log "  [DRY-RUN] Would create: $archive"
    else
        PARTIAL_OUTPUT="$archive"

        # --acls/--xattrs/--sparse are all opt-in in GNU tar; without them a round trip
        # silently drops ACLs, extended attributes and sparseness, and the source is
        # deleted below. --format=posix is implied by those flags; stated for clarity.
        tar -C "$parent_dir" --format=posix --acls --xattrs --sparse -cf - -- "$dir_name" \
            | zstd "-$COMPRESSION_LEVEL" -T0 --check -o "$archive" --quiet
        local pipe_status=("${PIPESTATUS[@]}")

        local tar_exit="${pipe_status[0]}"
        local zstd_exit="${pipe_status[1]}"

        if [[ "$tar_exit" -ne 0 ]]; then
            printf '%sError: tar failed (exit %s)%s\n' "$RED" "$tar_exit" "$NC" >&2
            rm -f -- "$archive"
            PARTIAL_OUTPUT=""
            return 1
        fi

        if [[ "$zstd_exit" -ne 0 && "$zstd_exit" -ne 141 ]]; then
            printf '%sError: zstd compression failed (exit %s)%s\n' "$RED" "$zstd_exit" "$NC" >&2
            rm -f -- "$archive"
            PARTIAL_OUTPUT=""
            return 1
        fi

        if [[ ! -f "$archive" ]]; then
            printf '%sError: Archive creation failed%s\n' "$RED" "$NC" >&2
            PARTIAL_OUTPUT=""
            return 1
        fi

        # Step 2: Verify
        log "Step 2: Verifying archive integrity (full decompression)..."
        if ! verify_archive "$archive"; then
            printf '%sError: Archive verification FAILED! Removing corrupt archive, keeping original.%s\n' "$RED" "$NC" >&2
            rm -f -- "$archive"
            PARTIAL_OUTPUT=""
            return 1
        fi

        # Decompression alone cannot detect truncation on a member boundary — tar reads
        # that as a clean end-of-archive and exits 0. Compare counts before deleting.
        local arc_entries
        arc_entries="$(count_members "$archive")"
        if [[ "$arc_entries" -ne "$src_entries" ]]; then
            printf '%sError: Archive holds %s entries but the source has %s. Keeping both.%s\n' \
                "$RED" "$arc_entries" "$src_entries" "$NC" >&2
            rm -f -- "$archive"
            PARTIAL_OUTPUT=""
            return 1
        fi
        log "  Verification passed ($arc_entries entries)"

        # Get the archive onto stable storage before the only other copy is destroyed.
        sync -f -- "$archive" 2>/dev/null || sync

        # Mark archive as complete — trap will no longer delete it
        PARTIAL_OUTPUT=""

        local archive_size archive_human ratio
        archive_size="$(get_size_bytes "$archive")"
        archive_human="$(get_size_human "$archive")"
        if [[ "$clean_size" -gt 0 ]]; then
            ratio="$(awk "BEGIN { printf \"%.1f\", ($archive_size / $clean_size) * 100 }")"
        else
            ratio="N/A"
        fi

        # Step 3: Remove original. Cleanup only runs here, on the way out, when the
        # source is being discarded anyway and the archive is already verified.
        if $KEEP_ORIGINAL; then
            log "Step 3: Keeping original (--keep); cleanup skipped so the kept tree matches the archive"
        else
            if $DO_CLEANUP && [[ -x "$CLEANUP_SCRIPT" ]]; then
                log "Step 3: Cleaning build artifacts before removal..."
                "$CLEANUP_SCRIPT" --dir "$target" || \
                    log "  Warning: cleanup.sh reported failures; continuing"
            fi
            log "Step 3: Removing original directory..."
            rm -rf --one-file-system -- "$target"
            log "  Original removed"
        fi

        # Summary
        printf '\n%s============================================================%s\n' "$BOLD" "$NC"
        printf '%s Summary%s\n' "$BOLD" "$NC"
        printf '  Original:   %s\n' "$before_human"
        printf '  Archived:   %s (%s%% of original)\n' "$archive_human" "$ratio"
        printf '  Saved:      %s\n' "$(human_bytes $((before_size - archive_size)))"
        printf '  Output:     %s\n' "$archive"
        printf '%s============================================================%s\n' "$BOLD" "$NC"
    fi
}

# --- Mode 2: Re-compress a single archive ---
recompress_archive() {
    local source="$1"

    if [[ ! -f "$source" ]]; then
        printf '%sError: '\''%s'\'' not found%s\n' "$RED" "$source" "$NC" >&2
        return 1
    fi

    local base decompressor
    case "$source" in
        *.tar.bz2)
            base="${source%.tar.bz2}"
            decompressor="bzip2 -dc"
            ;;
        *.tar.gz|*.tgz)
            base="${source%.tar.gz}"
            [[ "$source" == *.tgz ]] && base="${source%.tgz}"
            if command -v pigz >/dev/null 2>&1; then
                decompressor="pigz -dc"
            else
                decompressor="gzip -dc"
            fi
            ;;
        *)
            printf '%sError: unsupported format '\''%s'\'' (expected .tar.bz2 or .tar.gz)%s\n' "$RED" "$source" "$NC" >&2
            return 1
            ;;
    esac

    local output="$base.tar.zst"

    # A pre-existing output is not evidence of a good conversion — it may be a partial
    # left by a SIGKILLed run. Verify it before letting it shadow the source, and
    # signal the skip distinctly (2) so batch_recompress can count it.
    if [[ -f "$output" ]]; then
        if verify_archive "$output"; then
            log "  Skipping (already exists, verified): $(basename "$output")"
            return 2
        fi
        printf '  %s[ERROR]%s Existing %s is corrupt — refusing to overwrite or skip. Remove it by hand.\n' \
            "$RED" "$NC" "$(basename "$output")"
        return 1
    fi

    local source_size source_human
    source_size="$(get_size_bytes "$source")"
    source_human="$(get_size_human "$source")"

    # Check disk space
    local avail
    avail="$(available_space "$output")"
    if [[ -n "$avail" && "$avail" -lt "$source_size" ]]; then
        printf '%sError: Not enough disk space for '\''%s'\''. Need ~%s, have %s%s\n' \
            "$RED" "$(basename "$source")" "$(human_bytes "$source_size")" "$(human_bytes "$avail")" "$NC" >&2
        return 1
    fi

    if $DRY_RUN; then
        printf '  %s[DRY-RUN]%s %6s  %s -> %s\n' "$YELLOW" "$NC" "$source_human" "$(basename "$source")" "$(basename "$output")"
        return 0
    fi

    printf '  %s[RECOMPRESS]%s %6s  %s\n' "$CYAN" "$NC" "$source_human" "$(basename "$source")"

    PARTIAL_OUTPUT="$output"

    $decompressor "$source" | zstd "-$COMPRESSION_LEVEL" -T0 --check -o "$output" --quiet
    local pipe_status=("${PIPESTATUS[@]}")

    # Check decompressor exit code (ignore SIGPIPE=141 from zstd)
    local decomp_exit="${pipe_status[0]}"
    local zstd_exit="${pipe_status[1]}"

    if [[ "$decomp_exit" -ne 0 ]]; then
        printf '  %s[ERROR]%s Decompression failed (exit %s): %s\n' "$RED" "$NC" "$decomp_exit" "$(basename "$source")"
        rm -f -- "$output"
        PARTIAL_OUTPUT=""
        return 1
    fi

    if [[ "$zstd_exit" -ne 0 && "$zstd_exit" -ne 141 ]]; then
        printf '  %s[ERROR]%s zstd compression failed (exit %s): %s\n' "$RED" "$NC" "$zstd_exit" "$(basename "$source")"
        rm -f -- "$output"
        PARTIAL_OUTPUT=""
        return 1
    fi

    # Verify
    if ! verify_archive "$output"; then
        printf '  %s[ERROR]%s Verification FAILED: %s (keeping original)\n' "$RED" "$NC" "$(basename "$output")"
        rm -f -- "$output"
        PARTIAL_OUTPUT=""
        return 1
    fi

    # Member-count parity between the two archives — the same boundary-truncation gap
    # verify_archive cannot see, and here the source is about to be deleted.
    local src_members dst_members
    src_members="$($decompressor "$source" 2>/dev/null | tar -tf - 2>/dev/null | wc -l)"
    dst_members="$(count_members "$output")"
    if [[ "$dst_members" -ne "$src_members" ]]; then
        printf '  %s[ERROR]%s Member mismatch (%s vs %s): %s (keeping original)\n' \
            "$RED" "$NC" "$dst_members" "$src_members" "$(basename "$output")"
        rm -f -- "$output"
        PARTIAL_OUTPUT=""
        return 1
    fi

    local output_size
    output_size="$(get_size_bytes "$output")"

    # Recompression that grows the file has failed at its only purpose. Keep both and
    # let the caller decide rather than deleting the source for a worse copy.
    if [[ "$output_size" -ge "$source_size" ]]; then
        printf '  %s[SKIP]%s     %9s  %s would be no smaller than the original (%s) — keeping the original\n' \
            "$YELLOW" "$NC" "$(human_bytes "$output_size")" "$(basename "$output")" "$source_human"
        rm -f -- "$output"
        PARTIAL_OUTPUT=""
        return 2
    fi

    sync -f -- "$output" 2>/dev/null || sync
    PARTIAL_OUTPUT=""

    local output_human
    output_human="$(human_bytes "$output_size")"

    if ! $KEEP_ORIGINAL; then
        rm -f -- "$source"
        printf '  %s[DONE]%s    %9s  %s (was %s)\n' "$GREEN" "$NC" "$output_human" "$(basename "$output")" "$source_human"
    else
        printf '  %s[DONE]%s    %9s  %s (was %s, kept original)\n' "$GREEN" "$NC" "$output_human" "$(basename "$output")" "$source_human"
    fi

    return 0
}

# --- Mode 3: Batch re-compress ---
batch_recompress() {
    local dir="$1"
    dir="${dir%/}"

    if [[ ! -d "$dir" ]]; then
        printf '%sError: '\''%s'\'' is not a directory%s\n' "$RED" "$dir" "$NC" >&2
        return 1
    fi

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Batch Re-compress: %s%s\n' "$BOLD" "$dir" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf ' Compression: zstd level %s\n' "$COMPRESSION_LEVEL"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"

    # Collect all candidate files
    local files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(find "$dir" -maxdepth 1 -type f \( -name '*.tar.bz2' -o -name '*.tar.gz' -o -name '*.tgz' \) -print0 2>/dev/null | sort -z)

    local total=${#files[@]}
    if [[ $total -eq 0 ]]; then
        log "No .tar.bz2 or .tar.gz files found in $dir"
        return 0
    fi

    log "Found $total archive(s) to process"
    echo

    local seen=0 converted=0 skipped=0 failed=0 total_saved=0

    # recompress_archive returns 0 = converted, 2 = skipped, 1 = failed. Inferring the
    # skip from "does the output exist" was wrong in both directions: a skip returned 0
    # and landed in the success branch, so Skipped was always 0 and the savings figure
    # was computed against a file this run never wrote.
    for file in "${files[@]}"; do
        seen=$((seen + 1))
        printf '%s[%d/%d]%s ' "$CYAN" "$seen" "$total" "$NC"

        local old_size rc
        old_size="$(get_size_bytes "$file")"

        recompress_archive "$file"; rc=$?

        case $rc in
            0)
                converted=$((converted + 1))
                local base
                case "$file" in
                    *.tar.bz2) base="${file%.tar.bz2}" ;;
                    *.tar.gz)  base="${file%.tar.gz}" ;;
                    *.tgz)     base="${file%.tgz}" ;;
                esac
                if [[ -f "$base.tar.zst" ]]; then
                    local new_size
                    new_size="$(get_size_bytes "$base.tar.zst")"
                    [[ "$old_size" -gt "$new_size" ]] && total_saved=$((total_saved + old_size - new_size))
                fi
                ;;
            2) skipped=$((skipped + 1)) ;;
            *) failed=$((failed + 1)) ;;
        esac
    done
    local processed=$converted

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Batch Summary%s\n' "$BOLD" "$NC"
    printf '  Converted:  %d / %d\n' "$processed" "$total"
    printf '  Skipped:    %d (already .tar.zst, or no smaller)\n' "$skipped"
    if [[ $failed -gt 0 ]]; then
        printf '  %sFailed:     %d%s\n' "$RED" "$failed" "$NC"
    fi
    if [[ $total_saved -gt 0 ]]; then
        printf '  Saved:      %s\n' "$(human_bytes "$total_saved")"
    fi
    printf '  Log:        %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n' "$BOLD" "$NC"

    [[ $failed -eq 0 ]]
}

# --- Mode 4: Extract a .tar.zst archive ---
extract_archive() {
    local archive="$1"

    if [[ ! -f "$archive" ]]; then
        printf '%sError: '\''%s'\'' not found%s\n' "$RED" "$archive" "$NC" >&2
        return 1
    fi

    case "$archive" in
        *.tar.zst) ;;
        *) printf '%sError: expected .tar.zst file (got '\''%s'\'')%s\n' "$RED" "$archive" "$NC" >&2; return 1 ;;
    esac

    local parent_dir dir_name output_dir
    parent_dir="$(cd "$(dirname "$archive")" && pwd)"
    archive="$parent_dir/$(basename "$archive")"
    dir_name="$(basename "$archive" .tar.zst)"
    output_dir="$parent_dir/$dir_name"

    # The filename does not constrain the archive's contents. Extracting straight into
    # $parent_dir on the assumption that it does let an archive named foo.tar.zst
    # holding bar/ merge over a live bar/ — and then deleted the archive. Read the real
    # top-level member and refuse anything that doesn't match.
    local members top
    members="$(tar -I zstd -tf "$archive" 2>/dev/null | sed 's|/.*||' | sort -u)"
    if [[ -z "$members" ]]; then
        printf '%sError: cannot list '\''%s'\'' — corrupt or not a tar.zst%s\n' "$RED" "$archive" "$NC" >&2
        return 1
    fi
    if [[ "$(printf '%s\n' "$members" | wc -l)" -ne 1 ]]; then
        printf '%sError: archive has multiple top-level entries; refusing to extract into %s%s\n' \
            "$RED" "$parent_dir" "$NC" >&2
        printf '%s\n' "$members" | sed 's/^/    /' >&2
        return 1
    fi
    top="$members"
    if [[ "$top" != "$dir_name" ]]; then
        printf '%sError: '\''%s'\'' contains '\''%s'\'', not '\''%s'\''. Refusing — extracting would write outside the expected path.%s\n' \
            "$RED" "$(basename "$archive")" "$top" "$dir_name" "$NC" >&2
        return 1
    fi

    if [[ -e "$output_dir" ]]; then
        printf '%sError: '\''%s'\'' already exists%s\n' "$RED" "$output_dir" "$NC" >&2
        return 1
    fi

    local archive_human archive_size
    archive_size="$(get_size_bytes "$archive")"
    archive_human="$(human_bytes "$archive_size")"

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Extract: %s%s\n' "$BOLD" "$dir_name" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"

    if $DRY_RUN; then
        log "[DRY-RUN] Would extract: $archive -> $output_dir"
        return 0
    fi

    # Space check: the uncompressed size, which for a sparse-heavy archive can be
    # thousands of times the compressed size.
    local avail
    avail="$(available_space "$output_dir")"
    if [[ -n "$avail" && "$avail" -lt "$archive_size" ]]; then
        printf '%sError: Not enough disk space to extract (have %s)%s\n' \
            "$RED" "$(human_bytes "$avail")" "$NC" >&2
        return 1
    fi

    log "Extracting ($archive_human compressed)..."

    # Extract into a private staging dir, then publish with a rename. A failure leaves
    # an obviously-partial name instead of a plausible one, and never touches
    # $output_dir until the extraction has fully succeeded.
    local stage
    stage="$(mktemp -d "$parent_dir/.extract.XXXXXX")" || return 1
    PARTIAL_OUTPUT="$stage"

    # --acls --xattrs -p on extract too: without them tar restores the archive's
    # metadata into nothing, and setuid/setgid bits and the umask silently alter modes.
    if ! tar -I zstd -xpf "$archive" --acls --xattrs -C "$stage"; then
        printf '%sError: extraction failed%s\n' "$RED" "$NC" >&2
        rm -rf -- "$stage"
        PARTIAL_OUTPUT=""
        return 1
    fi

    if ! mv -- "$stage/$top" "$output_dir"; then
        printf '%sError: could not publish '\''%s'\''%s\n' "$RED" "$output_dir" "$NC" >&2
        rm -rf -- "$stage"
        PARTIAL_OUTPUT=""
        return 1
    fi
    rmdir -- "$stage" 2>/dev/null
    PARTIAL_OUTPUT=""

    local output_human
    output_human="$(get_size_human "$output_dir")"

    if $KEEP_ORIGINAL; then
        log "Keeping archive (--keep)"
    else
        log "Removing archive..."
        rm -f -- "$archive"
    fi

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Summary%s\n' "$BOLD" "$NC"
    printf '  Archive:    %s\n' "$archive_human"
    printf '  Extracted:  %s\n' "$output_human"
    printf '  Output:     %s\n' "$output_dir"
    printf '%s============================================================%s\n' "$BOLD" "$NC"
}

# --- Main dispatch ---
# `exit $?` at the end: without it the script's status is whichever printf ran last.
if [[ -n "$RECOMPRESS_ALL" ]]; then
    batch_recompress "$RECOMPRESS_ALL"
elif $EXTRACT; then
    extract_archive "$TARGET"
elif [[ -z "${TARGET:-}" ]]; then
    printf '%sError: no target specified%s\n' "$RED" "$NC" >&2
    usage 1
elif [[ -d "$TARGET" ]]; then
    archive_directory "$TARGET"
elif [[ -f "$TARGET" ]]; then
    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Re-compress: %s%s\n' "$BOLD" "$(basename "$TARGET")" "$NC"
    printf ' %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf ' Compression: zstd level %s\n' "$COMPRESSION_LEVEL"
    if $DRY_RUN; then
        printf ' %sDRY-RUN MODE%s\n' "$YELLOW" "$NC"
    fi
    printf ' Log: %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n\n' "$BOLD" "$NC"
    recompress_archive "$TARGET"
else
    printf '%sError: '\''%s'\'' not found%s\n' "$RED" "$TARGET" "$NC" >&2
    exit 1
fi
exit $?
