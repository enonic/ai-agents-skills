#!/usr/bin/env bash
# classify-breadth.sh — Apply the failure-breadth heuristic to selenium results.
#
# Usage:
#   classify-breadth.sh <run.json> <suite-dir> [<suite-dir> ...]
#
# Inputs:
#   run.json     — output of `gh run view <run-id> --json jobs`. Used to count
#                  total vs. failed selenium-test matrix jobs.
#   suite-dir    — one directory per FAILING suite, each containing
#                  summary.json from parse-selenium-log.sh.
#
# Output: JSON to stdout with:
#   {
#     category: 1 | 2 | 3,
#     category_label: "few-failures" | "single-suite-broken" | "all-suites-broken",
#     total_failing_tests: N,
#     selenium_jobs_total: N,
#     selenium_jobs_failed: N,
#     suites: [
#       { suite, specs_total, specs_failed, all_failed: bool, mostly_failed: bool }, ...
#     ],
#     write_report: bool
#   }
#
# Heuristic (in priority order):
#   - all selenium-test jobs failed → category 3 (regardless of count)
#   - a single suite has all specs failing OR >50% specs failing AND
#     specs_failed > 5 → category 2
#   - total failing tests ≤ 5 → category 1
#   - otherwise (many failures spread across suites) → category 1 with
#     write_report=true and a note (handled by the caller)

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }

if [[ $# -lt 2 ]]; then
  err "usage: classify-breadth.sh <run.json> <suite-dir> [<suite-dir> ...]"
  exit 2
fi

RUN_JSON="$1"; shift
[[ -r "$RUN_JSON" ]] || { err "cannot read $RUN_JSON"; exit 2; }

# Count selenium-test jobs in the matrix.
SELENIUM_TOTAL=$(jq '[.jobs[] | select(.name | startswith("selenium-test"))] | length' "$RUN_JSON")
SELENIUM_FAILED=$(jq '[.jobs[] | select(.name | startswith("selenium-test")) | select(.conclusion == "failure")] | length' "$RUN_JSON")

# Build per-suite stats from each summary.json.
SUITES_JSON='[]'
TOTAL_FAILING=0
ANY_ALL_FAILED=0
ANY_MOSTLY_FAILED=0
for dir in "$@"; do
  summary="$dir/summary.json"
  if [[ ! -r "$summary" ]]; then
    err "skipping (no summary.json): $dir"
    continue
  fi
  suite_name=$(basename "$dir")
  specs_total=$(jq '.totals.specs_total // 0' "$summary")
  specs_failed=$(jq '.totals.specs_failed // 0' "$summary")
  TOTAL_FAILING=$(( TOTAL_FAILING + specs_failed ))

  all_failed="false"; mostly_failed="false"
  if [[ "$specs_total" -gt 0 && "$specs_failed" -ge "$specs_total" ]]; then
    all_failed="true"
    ANY_ALL_FAILED=1
  fi
  # mostly = >50% AND >5 absolute (a 3/5 split is small enough to be cat-1 territory)
  if [[ "$specs_total" -gt 0 ]]; then
    half=$(( (specs_total + 1) / 2 ))
    if [[ "$specs_failed" -gt "$half" && "$specs_failed" -gt 5 ]]; then
      mostly_failed="true"
      ANY_MOSTLY_FAILED=1
    fi
  fi

  SUITES_JSON=$(jq --arg s "$suite_name" \
                   --argjson st "$specs_total" \
                   --argjson sf "$specs_failed" \
                   --argjson af "$all_failed" \
                   --argjson mf "$mostly_failed" \
                   '. + [{suite:$s, specs_total:$st, specs_failed:$sf, all_failed:$af, mostly_failed:$mf}]' \
                   <<<"$SUITES_JSON")
done

# Decide category.
CATEGORY=1
LABEL="few-failures"
WRITE_REPORT="true"

if [[ "$SELENIUM_TOTAL" -gt 0 && "$SELENIUM_FAILED" -ge "$SELENIUM_TOTAL" ]]; then
  CATEGORY=3
  LABEL="all-suites-broken"
  WRITE_REPORT="false"
elif [[ "$ANY_ALL_FAILED" -eq 1 || "$ANY_MOSTLY_FAILED" -eq 1 ]]; then
  CATEGORY=2
  LABEL="single-suite-broken"
  WRITE_REPORT="false"
elif [[ "$TOTAL_FAILING" -le 5 ]]; then
  CATEGORY=1
  LABEL="few-failures"
  WRITE_REPORT="true"
else
  # Many small failures across suites — still cat 1 logic, but include note.
  CATEGORY=1
  LABEL="few-failures"
  WRITE_REPORT="true"
fi

jq -n \
  --argjson cat "$CATEGORY" \
  --arg label "$LABEL" \
  --argjson tf "$TOTAL_FAILING" \
  --argjson st "$SELENIUM_TOTAL" \
  --argjson sf "$SELENIUM_FAILED" \
  --argjson suites "$SUITES_JSON" \
  --argjson wr "$WRITE_REPORT" \
  '{
    category: $cat,
    category_label: $label,
    total_failing_tests: $tf,
    selenium_jobs_total: $st,
    selenium_jobs_failed: $sf,
    suites: $suites,
    write_report: $wr
  }'
