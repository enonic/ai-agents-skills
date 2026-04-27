#!/usr/bin/env bash
# resolve-run.sh — Resolve flexible input to a single GitHub Actions run.
#
# Usage:
#   resolve-run.sh [INPUT]
#
# INPUT forms (probed in this order):
#   <empty>                   → latest run for current branch's HEAD commit
#   <number>                  → run ID, used as-is
#   <url>                     → run URL, run ID parsed from path (also sets repo)
#   <40-or-7+ hex>            → commit SHA, latest run that targets it
#   <anything else>           → branch name, latest run on that branch
#
# Repo selection:
#   1. owner/repo parsed from URL input (highest priority)
#   2. GH_ACTIONS_DEBUG_REPO env var if set
#   3. `git remote get-url origin` of cwd
#
# Output: single-line JSON to stdout with at least:
#   { run_id, repo, branch, head_sha, status, conclusion, event, name,
#     html_url, created_at, updated_at, source }
# `source` is one of: input-id, input-url, input-sha, input-branch, head-commit.
#
# Exit codes:
#   0  ok
#   1  no run found
#   2  bad input
#   3  no repo could be determined

set -euo pipefail

err() { printf '%s\n' "$*" >&2; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "missing required command: $1"; exit 2; }
}
require gh
require jq
require git

INPUT="${1:-}"
REPO="${GH_ACTIONS_DEBUG_REPO:-}"
SOURCE=""
BRANCH=""
SHA=""
RUN_ID=""

# --- Parse URL up front so it can also set REPO ---
if [[ "$INPUT" =~ ^https?://github\.com/([^/]+/[^/]+)/actions/runs/([0-9]+) ]]; then
  REPO="${BASH_REMATCH[1]}"
  RUN_ID="${BASH_REMATCH[2]}"
  SOURCE="input-url"
fi

# --- Determine repo if still unset ---
if [[ -z "$REPO" ]]; then
  if remote_url=$(git remote get-url origin 2>/dev/null); then
    # git@github.com:owner/repo(.git) OR https://github.com/owner/repo(.git)
    if [[ "$remote_url" =~ github\.com[:/]([^/]+/[^/]+)$ ]]; then
      REPO="${BASH_REMATCH[1]%.git}"
    fi
  fi
fi

if [[ -z "$REPO" ]]; then
  err "could not determine repo (no URL given, no GH_ACTIONS_DEBUG_REPO, no git origin)"
  exit 3
fi

# --- Resolve INPUT to a run ID if URL parsing didn't already ---
if [[ -z "$RUN_ID" ]]; then
  if [[ -z "$INPUT" ]]; then
    # Empty: use current branch's HEAD commit
    if ! SHA=$(git rev-parse HEAD 2>/dev/null); then
      err "no input given and cwd is not a git repo"
      exit 2
    fi
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    SOURCE="head-commit"
  elif [[ "$INPUT" =~ ^[0-9]+$ ]]; then
    RUN_ID="$INPUT"
    SOURCE="input-id"
  elif [[ "$INPUT" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    SHA="$INPUT"
    SOURCE="input-sha"
    # Expand short SHAs to full via local git, since `gh run list --commit`
    # requires the full 40-char SHA.
    if [[ "${#SHA}" -lt 40 ]]; then
      if full_sha=$(git rev-parse --verify --quiet "$SHA^{commit}" 2>/dev/null); then
        SHA="$full_sha"
      fi
    fi
  else
    BRANCH="$INPUT"
    SOURCE="input-branch"
  fi
fi

# --- Look up run by SHA or BRANCH if needed ---
if [[ -z "$RUN_ID" ]]; then
  query_args=(--repo "$REPO" --limit 5
              --json databaseId,headSha,conclusion,status,name,event,createdAt,updatedAt,headBranch,url)
  if [[ -n "$SHA" ]]; then
    runs_json=$(gh run list "${query_args[@]}" --commit "$SHA" 2>/dev/null || echo '[]')
  else
    runs_json=$(gh run list "${query_args[@]}" --branch "$BRANCH" 2>/dev/null || echo '[]')
  fi

  count=$(jq 'length' <<<"$runs_json")
  if [[ "$count" -eq 0 ]]; then
    err "no runs found for repo=$REPO source=$SOURCE ${SHA:+sha=$SHA} ${BRANCH:+branch=$BRANCH}"
    exit 1
  fi

  # Prefer a failed run (that's what the user is most likely asking about),
  # fall back to the most recent run.
  RUN_ID=$(jq -r '
    (map(select(.conclusion=="failure")) | .[0].databaseId)
    // .[0].databaseId
    // empty
  ' <<<"$runs_json")

  if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
    err "could not select a run from $count candidates"
    exit 1
  fi
fi

# --- Fetch full run metadata ---
run_json=$(gh run view "$RUN_ID" --repo "$REPO" \
  --json databaseId,headBranch,headSha,status,conclusion,event,name,url,createdAt,updatedAt \
  2>/dev/null) || {
    err "could not fetch run $RUN_ID from $REPO (does it exist?)"
    exit 1
  }

jq -n \
  --argjson run "$run_json" \
  --arg repo "$REPO" \
  --arg source "$SOURCE" \
  '{
    run_id: ($run.databaseId | tostring),
    repo: $repo,
    branch: $run.headBranch,
    head_sha: $run.headSha,
    status: $run.status,
    conclusion: $run.conclusion,
    event: $run.event,
    name: $run.name,
    html_url: $run.url,
    created_at: $run.createdAt,
    updated_at: $run.updatedAt,
    source: $source
  }'
