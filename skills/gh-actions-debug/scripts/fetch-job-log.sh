#!/usr/bin/env bash
# fetch-job-log.sh — Fetch + clean a failing job's log into the per-run cache.
#
# Usage:
#   fetch-job-log.sh <repo> <run_id> <job_id> <output_path>
#
# Behavior:
#   - Skips fetch if <output_path> already exists and is non-empty (cache reuse).
#   - Streams the failing-step lines via `gh run view --log-failed --job`.
#   - Strips ANSI escape codes.
#   - Strips the GH-Actions log prefix `<job>\tUNKNOWN STEP\t<timestamp> ` so
#     the cleaned file reads like a plain console transcript.
#
# Exit codes:
#   0  success (or cache hit)
#   1  gh fetch failed
#   2  bad arguments

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }

if [[ $# -ne 4 ]]; then
  err "usage: fetch-job-log.sh <repo> <run_id> <job_id> <output_path>"
  exit 2
fi

REPO="$1"
RUN_ID="$2"
JOB_ID="$3"
OUT="$4"

if [[ -s "$OUT" ]]; then
  # Cache hit — leave existing file in place.
  exit 0
fi

mkdir -p "$(dirname "$OUT")"

# Use a tmp file so a partial failure leaves no half-baked cache entry.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh run view "$RUN_ID" --repo "$REPO" --log-failed --job "$JOB_ID" >"$TMP" 2>/dev/null; then
  err "gh run view failed for run=$RUN_ID job=$JOB_ID"
  exit 1
fi

# Strip ANSI escapes, drop the GH-Actions log prefix
# (`<job-name><TAB>UNKNOWN STEP<TAB><timestamp>Z `), and strip stray BOM
# bytes that gh emits at the very start of the stream and just after the
# second TAB on the first line.
#
# Notes for portability:
#   - macOS BSD sed does not expand \t inside character classes ([^\t]),
#     so we use awk for the prefix strip — awk handles tabs reliably.
#   - The BOM is the 3-byte UTF-8 sequence EF BB BF.
sed -E $'s/\x1b\\[[0-9;]*[mK]//g' "$TMP" \
  | awk -v BOM=$'\xef\xbb\xbf' '
      BEGIN { FS = "\t" }
      {
        # On the very first record, strip a leading BOM if present.
        if (NR == 1) { sub("^" BOM, "", $0) }
        # Re-split with current $0.
        n = split($0, F, "\t")
        if (n >= 3 && F[2] == "UNKNOWN STEP") {
          # F[3] is "<BOM?><timestamp>Z <rest of line>"
          rest = F[3]
          sub("^" BOM, "", rest)
          # Strip the timestamp + single trailing space.
          sub(/^[0-9T:.+-]+Z /, "", rest)
          # Re-emit any further fields that were tab-separated within $3+.
          for (i = 4; i <= n; i++) rest = rest "\t" F[i]
          print rest
        } else {
          print
        }
      }
    ' >"$OUT"
