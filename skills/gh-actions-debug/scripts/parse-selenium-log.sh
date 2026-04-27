#!/usr/bin/env bash
# parse-selenium-log.sh — Extract failure records from a cleaned wdio selenium
# job log.
#
# Usage:
#   parse-selenium-log.sh <log-file>
#
# Output: JSON to stdout with:
#   {
#     failures: [
#       {
#         describe_path: "...",
#         test_path: "...",
#         error_message: "...",
#         screenshot_stem: "err_save_button_disabled" | null,
#         spec_file: "testing/specs/.../foo.spec.js",
#         spec_line: 77,
#         spec_column: 13,
#         stack_frames: [
#           { fn: "...", file: "testing/...", line: N, column: N }, ...
#         ]
#       }, ...
#     ],
#     totals: { specs_total, specs_passed, specs_failed }
#   }
#
# Pattern reference: see references/workflow-conventions.md.

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }

if [[ $# -ne 1 ]]; then
  err "usage: parse-selenium-log.sh <log-file>"
  exit 2
fi

LOG="$1"
[[ -r "$LOG" ]] || { err "cannot read $LOG"; exit 2; }

# Emit per-failure JSON via awk; each failure on its own line. Then jq -s
# wraps as array.
FAILURES_JSON=$(awk '
  function jescape(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    gsub(/\t/, "\\t", s)
    gsub(/\r/, "\\r", s)
    return s
  }
  function rel(p,    out, re) {
    out = p
    # Strip the runner prefix /home/runner/work/<repo>/<repo>/ → "".
    # Use a dynamic regex string so BSD awk does not misparse the / chars.
    re = "^/home/runner/work/[^/]+/[^/]+/"
    sub(re, "", out)
    return out
  }
  function flush(   sf_out, i) {
    if (have_block) {
      sf_out = ""
      for (i = 1; i <= sf_count; i++) {
        sf_out = (sf_out == "" ? sf_arr[i] : sf_out "," sf_arr[i])
      }
      printf "{\"describe_path\":\"%s\",\"test_path\":\"%s\",\"error_message\":\"%s\",\"screenshot_stem\":%s,\"spec_file\":%s,\"spec_line\":%s,\"spec_column\":%s,\"stack_frames\":[%s]}\n", \
        jescape(describe_path), jescape(test_path), jescape(error_message), \
        (screenshot_stem == "" ? "null" : "\"" jescape(screenshot_stem) "\""), \
        (spec_file == "" ? "null" : "\"" jescape(spec_file) "\""), \
        (spec_line == "" ? "null" : spec_line), \
        (spec_column == "" ? "null" : spec_column), \
        sf_out
    }
    have_block=0; describe_path=""; test_path=""; error_message=""
    screenshot_stem=""; spec_file=""; spec_line=""; spec_column=""
    sf_count=0
  }

  # `[0-4] Error in "<describe>.<test>"` — start of a failure block.
  # Strip optional worker prefix like `[0-4] ` or `[chrome ... #0-4] `.
  /Error in "/ {
    flush()
    have_block=1
    line=$0
    # Trim worker prefix (anything up to the first " ", but only if it looks
    # like `[...]`).
    sub(/^\[[^]]+\][[:space:]]*/, "", line)
    # Now line is: Error in "<full path>"
    if (match(line, /Error in "[^"]*"/)) {
      inner = substr(line, RSTART + 10, RLENGTH - 11)
      # The full describe/test path uses `.` to separate the spec stem from
      # the GIVEN/WHEN/THEN sentence.  Split on the first `.` after the
      # leading `<file>.spec`.
      n_split = index(inner, ".spec ")
      if (n_split > 0) {
        describe_path = substr(inner, 1, n_split + 4)
        test_path = substr(inner, n_split + 6)
      } else {
        describe_path = inner
        test_path = ""
      }
    }
    next
  }

  # `Error: <message> [Screenshot]: <stem>` — the assertion message.
  have_block && /^Error: / {
    msg=$0
    sub(/^Error: /, "", msg)
    # Extract optional `[Screenshot]: <stem>` trailer.
    if (match(msg, / \[Screenshot\]: [^[:space:]]+$/)) {
      stem=substr(msg, RSTART + 14)
      sub(/^[[:space:]]+/, "", stem)
      screenshot_stem = stem
      msg = substr(msg, 1, RSTART - 1)
    }
    error_message = msg
    next
  }

  # Stack frames: `    at <fn> (<file>:<line>:<col>)`
  have_block && /^[[:space:]]+at .* \(.*:[0-9]+:[0-9]+\)/ {
    line=$0
    sub(/^[[:space:]]+at /, "", line)
    # Split on the LAST " (" to separate fn from location.
    n_paren = 0
    L = length(line)
    for (i = L; i >= 1; i--) {
      if (substr(line, i, 2) == " (") { n_paren = i; break }
    }
    if (n_paren > 0) {
      fn = substr(line, 1, n_paren - 1)
      loc = substr(line, n_paren + 2)  # everything after " ("
      sub(/\)$/, "", loc)
      # loc is path:line:col
      n_last = 0
      LL = length(loc)
      for (i = LL; i >= 1; i--) {
        if (substr(loc, i, 1) == ":") { n_last = i; break }
      }
      col_part = substr(loc, n_last + 1)
      head_part = substr(loc, 1, n_last - 1)
      n_pen = 0
      LH = length(head_part)
      for (i = LH; i >= 1; i--) {
        if (substr(head_part, i, 1) == ":") { n_pen = i; break }
      }
      ln_part = substr(head_part, n_pen + 1)
      file_part = substr(head_part, 1, n_pen - 1)
      rel_file = rel(file_part)

      sf_count++
      sf_arr[sf_count] = sprintf("{\"fn\":\"%s\",\"file\":\"%s\",\"line\":%s,\"column\":%s}", \
        jescape(fn), jescape(rel_file), ln_part, col_part)

      # Promote the first /testing/specs/.../*.spec.* frame to spec_file.
      if (spec_file == "" && rel_file ~ /^testing\/specs\//) {
        spec_file = rel_file
        spec_line = ln_part
        spec_column = col_part
      }
    }
    next
  }

  # End of failure block: a blank line (or other unrecognized line) flushes.
  have_block && /^[[:space:]]*$/ {
    flush()
    next
  }

  END { flush() }
' "$LOG" | jq -s '.')

# De-duplicate failures: the log emits each failure twice — once per test
# announcement, once in the bottom-of-run summary with `[chrome ...]` prefix.
# Both produce the same record post-prefix-strip; collapse on
# (describe_path, test_path).
FAILURES_JSON=$(jq '
  group_by([.describe_path, .test_path])
  | map(
      reduce .[] as $f ({};
        . * (
          $f
          | with_entries(select(.value != null and (.value|tostring) != ""))
        )
      )
    )
' <<<"$FAILURES_JSON")

# Totals from the wdio summary line:
#   `Spec Files:\t 8 passed, 1 failed, 9 total ...`
TOTALS_JSON=$(awk '
  /^Spec Files:/ {
    line = $0
    passed = 0; failed = 0; total = 0
    if (match(line, /[0-9]+ passed/)) { s = substr(line, RSTART, RLENGTH); sub(/ passed/, "", s); passed = s }
    if (match(line, /[0-9]+ failed/)) { s = substr(line, RSTART, RLENGTH); sub(/ failed/, "", s); failed = s }
    if (match(line, /[0-9]+ total/))  { s = substr(line, RSTART, RLENGTH); sub(/ total/, "", s);  total = s }
    printf "{\"specs_total\":%d,\"specs_passed\":%d,\"specs_failed\":%d}", total, passed, failed
    found=1
    exit
  }
  END { if (!found) print "null" }
' "$LOG")

jq -n \
  --argjson failures "$FAILURES_JSON" \
  --argjson totals "$TOTALS_JSON" \
  '{ failures: $failures, totals: $totals }'
