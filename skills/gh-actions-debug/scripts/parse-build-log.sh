#!/usr/bin/env bash
# parse-build-log.sh — Extract structured build-failure summary from a cleaned
# gradle job log.
#
# Usage:
#   parse-build-log.sh <log-file>
#
# Output: JSON to stdout with:
#   {
#     failed_tasks: [":module:task", ...],
#     failure_block: "...everything from FAILURE: through (but not incl) * Try:...",
#     task_output_range: { start_line: N, end_line: M } | null,
#     compile_or_lint_locations: [
#        { file: "modules/lib/.../File.ts", line: 80, column: 1,
#          severity: "error", message: "..." },
#        ...
#     ],
#     totals: { failed_tasks: N, error_locations: M }
#   }
#
# Portable across BSD awk (macOS) and GNU awk — no gawk-only features.

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }

if [[ $# -ne 1 ]]; then
  err "usage: parse-build-log.sh <log-file>"
  exit 2
fi

LOG="$1"
[[ -r "$LOG" ]] || { err "cannot read $LOG"; exit 2; }

# 1. Failed tasks: lines like `> Task :module:task FAILED`
FAILED_TASKS_JSON=$(grep -E '^> Task :[A-Za-z0-9_:.-]+ FAILED' "$LOG" \
  | sed -E 's/^> Task (:[A-Za-z0-9_:.-]+) FAILED.*/\1/' \
  | jq -R -s 'split("\n") | map(select(length > 0))')

# 2. Failure block: from `FAILURE: Build failed with an exception.` up to (but
#    not including) the line that starts with `* Try:`.
FAILURE_BLOCK=$(awk '
  /^FAILURE: Build failed with an exception\./ { in_block=1 }
  in_block && /^\* Try:/ { exit }
  in_block { print }
' "$LOG")

# 3. Task output range: between the start of the failing task and its FAILED
#    line. Uses the first failed task as the anchor.
FIRST_FAILED_TASK=$(jq -r '.[0] // empty' <<<"$FAILED_TASKS_JSON")
TASK_RANGE_JSON="null"
if [[ -n "$FIRST_FAILED_TASK" ]]; then
  TASK_RANGE_JSON=$(awk -v task="$FIRST_FAILED_TASK" '
    BEGIN { start=0 }
    # Match lines that begin the failing task: `> Task :foo:bar` or
    # `> Task :foo:bar <suffix>` (e.g. UP-TO-DATE, FROM-CACHE) but NOT FAILED.
    $1 == ">" && $2 == "Task" && $3 == task && $0 !~ / FAILED$/ {
      if (!start) start = NR
    }
    $1 == ">" && $2 == "Task" && $3 == task && $0 ~ / FAILED$/ {
      print "{\"start_line\":" (start ? start : NR) ",\"end_line\":" NR "}"
      exit
    }
  ' "$LOG")
  [[ -z "$TASK_RANGE_JSON" ]] && TASK_RANGE_JSON="null"
fi

# 4. Compile / lint error locations.
#    ESLint output looks like:
#       /abs/path/File.ts
#         80:1  error  message text  rule-id
#    javac:  /abs/.../File.java:42: error: message
#    tsc:    /abs/.../File.ts(42,5): error TSxxxx: message
#
#    We emit one JSON object per error to stdout, then jq -s wraps to array.
COMPILE_LOCATIONS_JSON=$(awk '
  function jescape(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    return s
  }
  function rel(p,    out) {
    out = p
    sub(/^.*\/modules\//, "modules/", out)
    return out
  }

  # Track latest file path for ESLint blocks. The line may have an arbitrary
  # prefix (e.g. pnpm "  . check:lint:" or gradle module label) but ends with
  # a modules/-rooted path. Treat any line that *ends* with such a path as a
  # file marker.
  {
    line_no_trailing = $0
    sub(/[[:space:]]+$/, "", line_no_trailing)
    if (match(line_no_trailing, /\/modules\/[^[:space:]]+\.(tsx?|jsx?|java)$/)) {
      current_file = substr(line_no_trailing, RSTART, RLENGTH)
      next
    }
  }

  # ESLint error/warning lines: split by whitespace, find a `N:N` field
  # immediately followed by `error` or `warning`. Robust to any prefix.
  current_file != "" {
    nf = split($0, F)
    for (i = 1; i <= nf - 1; i++) {
      if (F[i] ~ /^[0-9]+:[0-9]+$/ && (F[i+1] == "error" || F[i+1] == "warning")) {
        pos = F[i]; sev = F[i+1]
        n_pos = index(pos, ":")
        line = substr(pos, 1, n_pos - 1)
        col  = substr(pos, n_pos + 1)
        msg = ""
        # Message is fields i+2 .. nf-1; last field is the rule id.
        for (j = i + 2; j < nf; j++) { msg = (msg == "" ? F[j] : msg " " F[j]) }
        rule = (nf > i + 2) ? F[nf] : ""
        printf "{\"file\":\"%s\",\"line\":%s,\"column\":%s,\"severity\":\"%s\",\"message\":\"%s\",\"rule\":\"%s\"}\n", \
          jescape(rel(current_file)), line, col, sev, jescape(msg), jescape(rule)
        break
      }
    }
    # Do NOT `next` here — fall through to javac/tsc patterns in case the
    # line happens to match a different format.
  }

  # javac: <file>.java:<line>: <severity>: <message>
  /\.java:[0-9]+:[[:space:]]+(error|warning):/ {
    line = $0
    # Split on first colon-line-colon-space to get file, line, severity, msg.
    if (match(line, /\.java:[0-9]+: (error|warning): /)) {
      head = substr(line, 1, RSTART + RLENGTH - 1)
      tail = substr(line, RSTART + RLENGTH)
      n1 = index(head, ".java:")
      file_name = substr(head, 1, n1 + 4)        # /abs/.../File.java
      rest1 = substr(head, n1 + 6)                # 42: error:
      n2 = index(rest1, ":")
      line_no = substr(rest1, 1, n2 - 1)
      sev_part = rest1; sub(/^[0-9]+: /, "", sev_part)
      sev = sev_part; sub(/: *$/, "", sev)
      printf "{\"file\":\"%s\",\"line\":%s,\"column\":1,\"severity\":\"%s\",\"message\":\"%s\",\"rule\":\"javac\"}\n", \
        jescape(rel(file_name)), line_no, sev, jescape(tail)
    }
    next
  }

  # tsc: <file>.tsx?(<line>,<col>): <severity> TSxxxx: <message>
  /\.(ts|tsx)\([0-9]+,[0-9]+\):[[:space:]]+(error|warning)[[:space:]]+TS[0-9]+:/ {
    line = $0
    if (match(line, /\.(ts|tsx)\([0-9]+,[0-9]+\): (error|warning) TS[0-9]+: /)) {
      head = substr(line, 1, RSTART + RLENGTH - 1)
      tail = substr(line, RSTART + RLENGTH)
      n_paren = index(head, "(")
      file_name = substr(head, 1, n_paren - 1)
      coords = substr(head, n_paren + 1)
      sub(/\).*$/, "", coords)
      n_comma = index(coords, ",")
      line_no = substr(coords, 1, n_comma - 1)
      col_no  = substr(coords, n_comma + 1)
      sev_part = head
      if (match(sev_part, /(error|warning) TS[0-9]+:/)) {
        sev = substr(sev_part, RSTART, RLENGTH)
        sub(/ TS[0-9]+:.*$/, "", sev)
      } else {
        sev = "error"
      }
      printf "{\"file\":\"%s\",\"line\":%s,\"column\":%s,\"severity\":\"%s\",\"message\":\"%s\",\"rule\":\"tsc\"}\n", \
        jescape(rel(file_name)), line_no, col_no, sev, jescape(tail)
    }
    next
  }
' "$LOG" | jq -s '.')

# Final JSON.
jq -n \
  --argjson failed "$FAILED_TASKS_JSON" \
  --arg failure_block "$FAILURE_BLOCK" \
  --argjson range "$TASK_RANGE_JSON" \
  --argjson locations "$COMPILE_LOCATIONS_JSON" \
  '{
    failed_tasks: $failed,
    failure_block: $failure_block,
    task_output_range: $range,
    compile_or_lint_locations: $locations,
    totals: { failed_tasks: ($failed | length), error_locations: ($locations | length) }
  }'
