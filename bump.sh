#!/usr/bin/env bash
set -Eeuo pipefail

LOCK_FILE="$(cd "$(dirname "$0")" && pwd)/lock.sh"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

info()  { echo "${GREEN}${BOLD}  ✓${RESET} $*"; }
warn()  { echo "${YELLOW}${BOLD}  ⚠${RESET} $*"; }
err()   { echo "${RED}${BOLD}  ✗${RESET} $*" >&2; }
skip()  { echo "  - $*"; }

# Query GitHub API — uses `gh` if available (authenticated, 5000 req/hr),
# falls back to unauthenticated curl (60 req/hr).
gh_api() {
  local endpoint="$1"
  if command -v gh &>/dev/null; then
    gh api "$endpoint" 2>/dev/null
  else
    curl -fsSL "https://api.github.com${endpoint}" 2>/dev/null
  fi
}

# Extract the latest version from a GitHub releases/latest redirect or API.
# Handles monorepos where tags look like "cargo-audit/v0.22.1".
github_latest() {
  local owner="$1" repo="$2" hint="$3"
  local tag

  # Try /releases/latest first
  tag=$(gh_api "/repos/${owner}/${repo}/releases/latest" | jq -r '.tag_name // empty')

  if [[ -z "$tag" ]]; then
    return 1
  fi

  # If tag contains '/' it's a monorepo — search for a matching release
  if [[ "$tag" == */* ]]; then
    local prefix
    # Derive prefix from the hint (lowercased var name, e.g. CARGO_AUDIT -> cargo-audit)
    prefix=$(echo "$hint" | tr '[:upper:]_' '[:lower:]-')
    tag=$(gh_api "/repos/${owner}/${repo}/releases?per_page=50" \
      | jq -r --arg pfx "$prefix" \
        '[.[] | select(.tag_name | startswith($pfx + "/"))][0].tag_name // empty')
    if [[ -z "$tag" ]]; then
      return 1
    fi
    # Strip the prefix: "cargo-audit/v0.22.1" -> "v0.22.1"
    tag="${tag##*/}"
  fi

  echo "$tag"
}

# Strip or keep 'v' prefix to match the existing convention for this variable.
match_prefix() {
  local current="$1" new_tag="$2"

  if [[ "$current" == v* ]]; then
    # Current has v prefix — ensure new tag does too
    if [[ "$new_tag" != v* ]]; then
      echo "v${new_tag}"
    else
      echo "$new_tag"
    fi
  else
    # Current has no v prefix — strip it
    echo "${new_tag#v}"
  fi
}

# Compare semver-ish strings. Returns 0 if $1 < $2 (i.e. $2 is newer).
is_newer() {
  local current="${1#v}" candidate="${2#v}"
  if [[ "$current" == "$candidate" ]]; then
    return 1
  fi
  # sort -V puts the smaller version first
  local oldest
  oldest=$(printf '%s\n%s\n' "$current" "$candidate" | sort -V | head -n1)
  [[ "$oldest" == "$current" ]]
}

# Query crates.io for the latest version of a crate.
crates_latest() {
  local crate="$1"
  cargo search --limit 1 "$crate" 2>/dev/null \
    | awk -F'"' -v c="$crate" '$0 ~ "^"c" " {print $2}'
}

echo "${BOLD}Checking for version updates...${RESET}"
echo ""

UPDATES=0
WARNINGS=0
comment_url=""
source_type=""  # "github", "crates", or "unknown"

while IFS= read -r line; do
  # Capture comment: either a URL or "crates.io:<crate-name>"
  if [[ "$line" =~ ^#\ crates\.io:\ *(.+) ]]; then
    comment_url="crates.io"
    source_type="crates"
    crate_name="${BASH_REMATCH[1]}"
    continue
  elif [[ "$line" =~ ^#\ (https?://.+) ]]; then
    comment_url="${BASH_REMATCH[1]}"
    source_type=""
    continue
  fi

  # Process export lines
  if [[ "$line" =~ ^export\ ([A-Z_]+)=\"([^\"]*)\" ]]; then
    var="${BASH_REMATCH[1]}"
    current="${BASH_REMATCH[2]}"

    if [[ -z "$comment_url" ]]; then
      warn "${var}: no URL comment found, skipping"
      WARNINGS=$((WARNINGS + 1))
      continue
    fi

    latest=""

    if [[ "$source_type" == "crates" ]]; then
      # Cargo crate — query crates.io
      latest=$(crates_latest "$crate_name") || {
        err "${var}: failed to query crates.io for ${crate_name}"
        WARNINGS=$((WARNINGS + 1))
        comment_url=""; source_type=""
        continue
      }
      if [[ -z "$latest" ]]; then
        err "${var}: crate '${crate_name}' not found on crates.io"
        WARNINGS=$((WARNINGS + 1))
        comment_url=""; source_type=""
        continue
      fi
    elif [[ "$comment_url" =~ github\.com/([^/]+)/([^/]+) ]]; then
      # GitHub release
      owner="${BASH_REMATCH[1]}"
      repo="${BASH_REMATCH[2]}"

      latest_tag=$(github_latest "$owner" "$repo" "$var") || {
        err "${var}: failed to query GitHub (${owner}/${repo})"
        WARNINGS=$((WARNINGS + 1))
        comment_url=""; source_type=""
        continue
      }

      latest=$(match_prefix "$current" "$latest_tag")
    else
      warn "${var}=${current} — check manually: ${comment_url}"
      WARNINGS=$((WARNINGS + 1))
      comment_url=""; source_type=""
      continue
    fi

    if [[ "$latest" == "$current" ]]; then
      skip "${var}=${current} (up to date)"
    elif ! is_newer "$current" "$latest"; then
      warn "${var}: latest (${latest}) is older than current (${current}), skipping"
      WARNINGS=$((WARNINGS + 1))
    else
      info "${var}: ${current} → ${latest}"
      UPDATES=$((UPDATES + 1))
      if [[ "$DRY_RUN" == "0" ]]; then
        sed -i "s|^export ${var}=\"${current}\"|export ${var}=\"${latest}\"|" "$LOCK_FILE"
      fi
    fi

    comment_url=""; source_type=""
  fi
done < "$LOCK_FILE"

echo ""
if [[ "$DRY_RUN" == "1" ]]; then
  echo "${BOLD}Dry run: ${UPDATES} update(s) available, ${WARNINGS} warning(s). No changes made.${RESET}"
else
  echo "${BOLD}Done: ${UPDATES} update(s) applied, ${WARNINGS} warning(s).${RESET}"
  if [[ "$UPDATES" -gt 0 ]]; then
    echo "Run ${BOLD}git diff lock.sh${RESET} to review changes."
  fi
fi
