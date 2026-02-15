#!/bin/bash

# Resolve a GitHub token with read:project scope for Projects V2 API.
#
# Discovery order:
#   1. Check secure cache (~/.cache/enonic-gh-project-token, 15 min TTL)
#   2. Search 1Password (enonic.1password.eu / Employee vault) for a GitHub PAT
#   3. Fall back to current gh auth token (may lack read:project scope)
#
# Usage:
#   TOKEN=$(bash scripts/resolve-project-token.sh)
#
# Token is printed to stdout. Diagnostics go to stderr.

set -e

# --- Configuration ---
OP_ACCOUNT="enonic.1password.eu"
OP_VAULT="Employee"
CACHE_DIR="$HOME/.cache/enonic-gh-project-token"
CACHE_FILE="$CACHE_DIR/token"
CACHE_TTL=900  # 15 minutes in seconds

# --- Helpers ---

# Validate that a string looks like a GitHub token (not a 1Password placeholder).
is_valid_token() {
  local t="$1"
  [[ -n "$t" && ${#t} -ge 30 && "${t:0:1}" != "[" ]]
}

# Return cached token if cache exists, is owned by current user, has mode 600,
# and was modified less than CACHE_TTL seconds ago.
read_cache() {
  [[ ! -f "$CACHE_FILE" ]] && return 1

  # Verify ownership and permissions (macOS stat syntax)
  local owner perms
  owner=$(stat -f '%u' "$CACHE_FILE" 2>/dev/null) || return 1
  perms=$(stat -f '%Lp' "$CACHE_FILE" 2>/dev/null) || return 1

  [[ "$owner" != "$(id -u)" ]] && return 1
  [[ "$perms" != "600" ]] && return 1

  # Check age
  local mtime now age
  mtime=$(stat -f '%m' "$CACHE_FILE" 2>/dev/null) || return 1
  now=$(date +%s)
  age=$((now - mtime))
  (( age >= CACHE_TTL )) && return 1

  local cached
  cached=$(cat "$CACHE_FILE" 2>/dev/null) || return 1
  is_valid_token "$cached" && echo "$cached" && return 0
  return 1
}

# Write token to cache with strict permissions.
write_cache() {
  local token="$1"
  mkdir -p "$CACHE_DIR" 2>/dev/null
  chmod 700 "$CACHE_DIR" 2>/dev/null

  # Write atomically via temp file
  local tmp="$CACHE_FILE.$$"
  printf '%s' "$token" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$CACHE_FILE"
}

# Remove cache on error or invalid token.
clear_cache() {
  rm -f "$CACHE_FILE" 2>/dev/null
}

# --- Main ---

# 1. Try cache
CACHED=$(read_cache 2>/dev/null) || true
if [[ -n "$CACHED" ]]; then
  echo "$CACHED"
  exit 0
fi

# 2. Try 1Password — search Employee vault for GitHub PAT items
TOKEN=""

if command -v op &>/dev/null; then
  # Find items in Employee vault with "GitHub" in the title that have
  # an Api Credential, Password, or Login category (covers PATs and tokens).
  # Each team member stores their own token — the name doesn't matter.
  # Note: --categories expects human-readable names, not JSON enum values.
  ITEM_ID=$(op item list \
    --account "$OP_ACCOUNT" \
    --vault "$OP_VAULT" \
    --categories "Api Credential,Password,Login" \
    --format json 2>/dev/null \
    | jq -r '[.[] | select(.title | test("github"; "i"))] | first | .id // empty' 2>/dev/null) || true

  if [[ -n "$ITEM_ID" ]]; then
    TOKEN=$(op item get "$ITEM_ID" \
      --account "$OP_ACCOUNT" \
      --vault "$OP_VAULT" \
      --fields label=token \
      --reveal 2>/dev/null) || true
  fi

  # Some items store the token under "credential" or "password" instead
  if ! is_valid_token "$TOKEN" && [[ -n "$ITEM_ID" ]]; then
    TOKEN=$(op item get "$ITEM_ID" \
      --account "$OP_ACCOUNT" \
      --vault "$OP_VAULT" \
      --fields type=CONCEALED \
      --reveal 2>/dev/null) || true
  fi
fi

if is_valid_token "$TOKEN"; then
  write_cache "$TOKEN"
  echo "$TOKEN"
  exit 0
fi

# 3. Fall back to current gh auth token
clear_cache
TOKEN=$(gh auth token 2>/dev/null) || true

if is_valid_token "$TOKEN"; then
  echo "WARNING: Using default gh token — may lack read:project scope" >&2
  # Don't cache fallback tokens — they're already instant to retrieve
  echo "$TOKEN"
  exit 0
fi

cat >&2 <<'MSG'
ERROR: No GitHub token found.

To fix this, create a Personal Access Token in 1Password:
  1. Go to https://github.com/settings/tokens?type=beta (fine-grained PAT)
  2. Set resource owner to "enonic", name it something with "GitHub" in the title
  3. Grant scopes: repo, read:org, read:project
  4. Save it in 1Password → Enonic account → Employee vault
     - Category: "Api Credential"
     - Store the token in a field labeled "token"
  5. Re-run this command — the token will be discovered automatically
MSG
exit 1
