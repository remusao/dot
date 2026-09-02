#!/usr/bin/env bash
#
# Download-integrity helpers.
#
# TLS authenticates the host, not the artifact, and nuggets drop artifacts
# straight onto PATH. A checksum manifest from the artifact's own origin proves
# integrity, not provenance; only a signature checked against a fingerprint
# pinned in this repo proves that. Some upstreams publish neither.
#
# Manifests are fetched at install time, not pinned in lock.sh: bump.sh rewrites
# only the *_VERSION line, so a pinned digest would go stale on the first bump.

# curl_fetch <url> <dest> -- hardened download. Not --retry-all-errors: that
# retries 4xx too, so a bad version pin would burn three backoffs before
# reporting the 404 that explains it.
curl_fetch() {
  curl -fL --proto '=https' --proto-redir '=https' --no-progress-meter \
    --retry 3 --retry-connrefused -o "$2" "$1"
}

# verify_sha256 <file> <manifest> <asset-name> -- check <file> against the
# <asset-name> line of <manifest>; an asset missing from the manifest is an
# error, not a pass. Name fields vary ("name", "*name", "./name").
verify_sha256() {
  local file="$1" manifest="$2" name="$3" want got

  want=$(awk -v n="$name" '
    { f = $2; sub(/^\*/, "", f); sub(/^\.\//, "", f)
      if (f == n) { print $1; exit } }
  ' "$manifest")

  if [ -z "$want" ]; then
    printf 'verify_sha256: %s is not listed in %s\n' "$name" "$manifest" >&2
    return 1
  fi

  # Read from stdin so sha256sum never prints a path.
  got=$(sha256sum <"$file" | cut -d' ' -f1)

  if [ "$want" != "$got" ]; then
    printf 'verify_sha256: %s failed\n  want %s\n  got  %s\n' "$name" "$want" "$got" >&2
    return 1
  fi
}

# fetch_verified <url> <dest> <manifest-url> <asset-name> -- download and verify.
# The manifest gets its own temp file: callers stage <dest> in its final
# directory to keep the mv a rename, and the manifest must not litter that.
fetch_verified() {
  local url="$1" dest="$2" manifest_url="$3" name="$4"

  (
    manifest=$(mktemp)
    trap 'rm -f "$manifest"' EXIT
    curl_fetch "$manifest_url" "$manifest"
    curl_fetch "$url" "$dest"
    verify_sha256 "$dest" "$manifest" "$name"
  )
}

# _verify_pgp <key.asc> <fpr> <what> <gpg-arg>... -- internal.
#
# Throwaway keyring holding only <key.asc>, plus a VALIDSIG line naming <fpr>.
# Both halves matter: gpg exits 0 for a good signature from ANY key it holds, so
# the fingerprint bind is what makes this provenance rather than syntax.
#
# gpg's stderr is replayed only on failure -- "BAD signature" is reported
# nowhere else, but a run where nothing changed must stay quiet.
_verify_pgp() {
  local key="$1" fpr="$2" what="$3"
  shift 3

  (
    home=$(mktemp -d)
    trap 'rm -rf "$home"' EXIT

    # --no-autostart: never leave an agent daemon pointing at a deleted dir.
    if ! GNUPGHOME="$home" gpg --no-autostart --batch --quiet \
      --import "$key" 2>"${home}/err"; then
      cat "${home}/err" >&2
      printf '_verify_pgp: cannot import %s\n' "$key" >&2
      exit 1
    fi

    # --yes so a re-run can overwrite --output; without it gpg exits 2.
    if ! GNUPGHOME="$home" gpg --no-autostart --batch --quiet --yes \
      --status-file "${home}/status" "$@" 2>"${home}/err"; then
      cat "${home}/err" >&2
      printf '_verify_pgp: gpg rejected %s\n' "$what" >&2
      exit 1
    fi

    if ! grep -q "^\[GNUPG:\] VALIDSIG ${fpr} " "${home}/status"; then
      cat "${home}/err" >&2
      printf '_verify_pgp: %s is not signed by %s\n' "$what" "$fpr" >&2
      exit 1
    fi
  )
}

# verify_pgp_clearsigned <file.asc> <key.asc> <fpr> <payload-out> -- verify an
# inline-signed manifest and write its payload out. Used for firejail and rclone.
verify_pgp_clearsigned() {
  _verify_pgp "$2" "$3" "$1" --output "$4" --decrypt "$1"
}

# verify_pgp_detached <file> <file.asc> <key.asc> <fpr> -- verify a detached
# signature over <file>. Used for restic.
verify_pgp_detached() {
  _verify_pgp "$3" "$4" "$1" --verify "$2" "$1"
}

# verify_git_tag <tag> <key.asc> <fpr> -- verify a signed tag in the CWD repo,
# for kitty and alacritty, which build from a clone rather than an asset. git
# drives gpg itself, so this cannot go through _verify_pgp; same pinned keyring,
# same VALIDSIG bind.
verify_git_tag() {
  local tag="$1" key="$2" fpr="$3"

  (
    home=$(mktemp -d)
    trap 'rm -rf "$home"' EXIT
    GNUPGHOME="$home" gpg --no-autostart --batch --quiet --import "$key" 2>/dev/null

    # git verify-tag --raw writes the status lines to stderr, mixed with gpg's.
    status=$(GNUPGHOME="$home" git verify-tag --raw "$tag" 2>&1) || true
    case "$status" in
      *"VALIDSIG ${fpr} "*) ;;
      *)
        printf 'verify_git_tag: %s is not signed by %s\n' "$tag" "$fpr" >&2
        exit 1
        ;;
    esac
  )
}
