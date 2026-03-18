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
    exit 0
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

# Validate compression level
if [[ ! "$COMPRESSION_LEVEL" =~ ^[0-9]+$ ]] || (( COMPRESSION_LEVEL < 1 || COMPRESSION_LEVEL > 19 )); then
    printf '%sError: compression level must be an integer 1-19 (got: %s)%s\n' "$RED" "$COMPRESSION_LEVEL" "$NC" >&2
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

get_size_bytes() {
    if [[ -d "$1" ]]; then
        du -sb "$1" 2>/dev/null | cut -f1
    elif [[ -f "$1" ]]; then
        stat --printf='%s' "$1" 2>/dev/null
    else
        echo 0
    fi
}

get_size_human() {
    du -sh "$1" 2>/dev/null | cut -f1
}

human_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

# Check available disk space in bytes for the filesystem containing a path
available_space() {
    df --output=avail -B1 "$(dirname "$1")" 2>/dev/null | tail -1 | tr -d ' '
}

# Fully verify an archive by decompressing every byte through both zstd and tar layers
verify_archive() {
    local archive="$1"
    tar -I zstd -xOf "$archive" > /dev/null 2>&1
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

    # Step 1: Cleanup
    if $DO_CLEANUP; then
        log "Step 1: Cleaning build artifacts..."
        if [[ -x "$CLEANUP_SCRIPT" ]]; then
            local cleanup_args=("--dir" "$target")
            if $DRY_RUN; then
                cleanup_args+=("--dry-run")
            fi
            "$CLEANUP_SCRIPT" "${cleanup_args[@]}"
            echo
        else
            log "  Warning: cleanup.sh not found at $CLEANUP_SCRIPT, skipping"
        fi
    else
        log "Step 1: Cleanup skipped (--no-cleanup)"
    fi

    # Measure post-cleanup size
    local clean_size clean_human
    clean_size="$(get_size_bytes "$target")"
    clean_human="$(get_size_human "$target")"
    log "Size after cleanup: $clean_human (was $before_human)"

    # Check disk space
    local avail
    avail="$(available_space "$archive")"
    if [[ -n "$avail" && "$avail" -lt "$clean_size" ]]; then
        printf '%sError: Not enough disk space. Need ~%s, have %s%s\n' \
            "$RED" "$(human_bytes "$clean_size")" "$(human_bytes "$avail")" "$NC" >&2
        return 1
    fi

    # Step 2: Create archive
    log "Step 2: Creating archive (zstd level $COMPRESSION_LEVEL, $(nproc) threads)..."

    if $DRY_RUN; then
        log "  [DRY-RUN] Would create: $archive"
    else
        PARTIAL_OUTPUT="$archive"

        tar -C "$parent_dir" -cf - "$dir_name" \
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

        # Step 3: Verify
        log "Step 3: Verifying archive integrity (full decompression)..."
        if ! verify_archive "$archive"; then
            printf '%sError: Archive verification FAILED! Removing corrupt archive, keeping original.%s\n' "$RED" "$NC" >&2
            rm -f -- "$archive"
            PARTIAL_OUTPUT=""
            return 1
        fi
        log "  Verification passed"

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

        # Step 4: Remove original
        if $KEEP_ORIGINAL; then
            log "Step 4: Keeping original (--keep)"
        else
            log "Step 4: Removing original directory..."
            rm -rf -- "$target"
            log "  Original removed"
        fi

        # Summary
        printf '\n%s============================================================%s\n' "$BOLD" "$NC"
        printf '%s Summary%s\n' "$BOLD" "$NC"
        printf '  Original:   %s\n' "$before_human"
        printf '  Cleaned:    %s\n' "$clean_human"
        printf '  Archived:   %s (%s%% of cleaned)\n' "$archive_human" "$ratio"
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

    if [[ -f "$output" ]]; then
        log "  Skipping (already exists): $output"
        return 0
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

    PARTIAL_OUTPUT=""

    local output_human
    output_human="$(get_size_human "$output")"

    if ! $KEEP_ORIGINAL; then
        rm -f -- "$source"
        printf '  %s[DONE]%s    %6s  %s (was %s)\n' "$GREEN" "$NC" "$output_human" "$(basename "$output")" "$source_human"
    else
        printf '  %s[DONE]%s    %6s  %s (was %s, kept original)\n' "$GREEN" "$NC" "$output_human" "$(basename "$output")" "$source_human"
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

    local processed=0 skipped=0 failed=0 total_saved=0

    for file in "${files[@]}"; do
        processed=$((processed + 1))
        printf '%s[%d/%d]%s ' "$CYAN" "$processed" "$total" "$NC"

        local old_size
        old_size="$(get_size_bytes "$file")"

        if recompress_archive "$file"; then
            # Calculate savings
            local base
            case "$file" in
                *.tar.bz2) base="${file%.tar.bz2}" ;;
                *.tar.gz)  base="${file%.tar.gz}" ;;
                *.tgz)     base="${file%.tgz}" ;;
            esac
            local new_file="$base.tar.zst"
            if [[ -f "$new_file" ]]; then
                local new_size
                new_size="$(get_size_bytes "$new_file")"
                if [[ "$old_size" -gt "$new_size" ]]; then
                    total_saved=$((total_saved + old_size - new_size))
                fi
            fi
        else
            # Check if it was a skip (output already exists) or a real failure
            local base
            case "$file" in
                *.tar.bz2) base="${file%.tar.bz2}" ;;
                *.tar.gz)  base="${file%.tar.gz}" ;;
                *.tgz)     base="${file%.tgz}" ;;
            esac
            if [[ -f "$base.tar.zst" ]]; then
                skipped=$((skipped + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    printf '\n%s============================================================%s\n' "$BOLD" "$NC"
    printf '%s Batch Summary%s\n' "$BOLD" "$NC"
    printf '  Processed:  %d / %d\n' "$((processed - skipped - failed))" "$total"
    printf '  Skipped:    %d (already .tar.zst)\n' "$skipped"
    if [[ $failed -gt 0 ]]; then
        printf '  %sFailed:     %d%s\n' "$RED" "$failed" "$NC"
    fi
    if [[ $total_saved -gt 0 ]]; then
        printf '  Saved:      %s\n' "$(human_bytes "$total_saved")"
    fi
    printf '  Log:        %s\n' "$LOG_FILE"
    printf '%s============================================================%s\n' "$BOLD" "$NC"
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

    if [[ -d "$output_dir" ]]; then
        printf '%sError: '\''%s'\'' already exists%s\n' "$RED" "$output_dir" "$NC" >&2
        return 1
    fi

    local archive_human
    archive_human="$(get_size_human "$archive")"

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

    log "Extracting ($archive_human compressed)..."
    PARTIAL_OUTPUT="$output_dir"

    if ! tar -I zstd -xf "$archive" -C "$parent_dir"; then
        printf '%sError: extraction failed%s\n' "$RED" "$NC" >&2
        rm -rf -- "$output_dir"
        PARTIAL_OUTPUT=""
        return 1
    fi

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
if [[ -n "$RECOMPRESS_ALL" ]]; then
    batch_recompress "$RECOMPRESS_ALL"
elif $EXTRACT; then
    extract_archive "$TARGET"
elif [[ -z "${TARGET:-}" ]]; then
    printf '%sError: no target specified%s\n' "$RED" "$NC" >&2
    usage
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
