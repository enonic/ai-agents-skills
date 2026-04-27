#!/usr/bin/env bash
# fetch-artifact.sh — Download a GitHub Actions artifact into the per-run
# cache, idempotently.
#
# Usage:
#   fetch-artifact.sh <repo> <run_id> <artifact_name> <dest_dir>
#
# The artifact is downloaded via `gh run download --name`, which extracts the
# zip in place. Cache check: if <dest_dir> already exists and contains files,
# the download is skipped.
#
# Exit codes:
#   0  success (or cache hit)
#   1  download failed
#   2  bad arguments

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }

if [[ $# -ne 4 ]]; then
  err "usage: fetch-artifact.sh <repo> <run_id> <artifact_name> <dest_dir>"
  exit 2
fi

REPO="$1"
RUN_ID="$2"
NAME="$3"
DEST="$4"

# Cache hit: directory exists and has at least one file inside.
if [[ -d "$DEST" ]] && [[ -n "$(ls -A "$DEST" 2>/dev/null || true)" ]]; then
  exit 0
fi

mkdir -p "$DEST"

# `gh run download` writes into the directory directly. If the artifact does
# not exist, gh exits non-zero with a helpful message we want to surface.
if ! gh run download "$RUN_ID" --repo "$REPO" --name "$NAME" --dir "$DEST"; then
  err "gh run download failed for run=$RUN_ID artifact=$NAME"
  # Don't leave an empty cache dir behind — clean up so retry is clean.
  rmdir "$DEST" 2>/dev/null || true
  exit 1
fi
