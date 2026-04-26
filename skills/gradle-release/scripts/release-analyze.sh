#!/bin/bash

# Release Analysis Script (gradle + npm)
# Reads current version, shows commits since last tag, suggests bump options.
# Output is structured so the agent can parse it and present options to the user.
#
# Output keys (one per line, KEY=VALUE):
#   CURRENT_VERSION    Current version from gradle.properties
#   BASE_VERSION       Current with -SNAPSHOT stripped
#   LAST_TAG           Most recent v<X.Y.Z> tag (empty if none)
#   RECENT_TAGS        Up to 5 most recent v<X.Y.Z> tags, space-separated
#   STRIP_VERSION      Snapshot base — what the developer aimed for
#   PATCH_VERSION      Patch bump computed from LAST_TAG (empty if no tag)
#   MINOR_VERSION      Minor bump computed from LAST_TAG (empty if no tag)
#   MAJOR_VERSION      Major bump computed from LAST_TAG (empty if no tag)
#   SNAPSHOT_INTENT    How BASE relates to LAST_TAG: patch | minor | major | other | first
#   COMMIT_COUNT       Commits since last tag
#   RECOMMENDED        Always "strip" — release the snapshot as-is unless overridden

set -e

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: Not a git repository"
  exit 1
fi

if [ ! -f "gradle.properties" ]; then
  echo "ERROR: No gradle.properties found"
  exit 1
fi

CURRENT=$(grep -E '^version=' gradle.properties | head -1 | cut -d= -f2-)
if [[ -z "$CURRENT" ]]; then
  echo "ERROR: No 'version=' line in gradle.properties"
  exit 1
fi

BASE="${CURRENT%-SNAPSHOT}"
if [[ ! "$BASE" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "ERROR: Cannot parse base version from '$BASE' (expected X.Y.Z)"
  exit 1
fi

STRIP_VERSION="$BASE"

# Find recent semver tags. Filter to canonical vX.Y.Z (no prereleases) and
# version-sort so v1.0.10 ranks above v1.0.9.
ALL_SEMVER_TAGS=$(git for-each-ref --sort=-v:refname --format='%(refname:short)' 'refs/tags/v*' 2>/dev/null \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)
LAST_TAG=$(echo "$ALL_SEMVER_TAGS" | head -1)
RECENT_TAGS=$(echo "$ALL_SEMVER_TAGS" | head -5 | tr '\n' ' ' | sed 's/ *$//')

# Bump candidates are computed from LAST_TAG, not from the snapshot's BASE.
# X.Y.Z-SNAPSHOT can encode any bump type (major/minor/patch); BASE alone
# tells us nothing about which.
PATCH_VERSION=""
MINOR_VERSION=""
MAJOR_VERSION=""
if [[ -n "$LAST_TAG" ]]; then
  LAST_VER="${LAST_TAG#v}"
  if [[ "$LAST_VER" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    LMAJ="${BASH_REMATCH[1]}"
    LMIN="${BASH_REMATCH[2]}"
    LPCH="${BASH_REMATCH[3]}"
    PATCH_VERSION="$LMAJ.$LMIN.$((LPCH + 1))"
    MINOR_VERSION="$LMAJ.$((LMIN + 1)).0"
    MAJOR_VERSION="$((LMAJ + 1)).0.0"
  fi
fi

# Classify what the snapshot was intended as, by comparing BASE to bump candidates.
if [[ -z "$LAST_TAG" ]]; then
  SNAPSHOT_INTENT="first"
elif [[ "$BASE" == "$MAJOR_VERSION" ]]; then
  SNAPSHOT_INTENT="major"
elif [[ "$BASE" == "$MINOR_VERSION" ]]; then
  SNAPSHOT_INTENT="minor"
elif [[ "$BASE" == "$PATCH_VERSION" ]]; then
  SNAPSHOT_INTENT="patch"
else
  SNAPSHOT_INTENT="other"
fi

# Commits since last tag (or all commits if no tag)
if [[ -n "$LAST_TAG" ]]; then
  RANGE="$LAST_TAG..HEAD"
else
  RANGE="HEAD"
fi
COMMIT_COUNT=$(git log --oneline "$RANGE" 2>/dev/null | wc -l | tr -d ' ')

# Default recommendation: trust the snapshot. The developer already chose a
# version when bumping to -SNAPSHOT; releasing as-is matches their intent.
RECOMMENDED="strip"

echo "CURRENT_VERSION=$CURRENT"
echo "BASE_VERSION=$BASE"
echo "LAST_TAG=$LAST_TAG"
echo "RECENT_TAGS=$RECENT_TAGS"
echo "STRIP_VERSION=$STRIP_VERSION"
echo "PATCH_VERSION=$PATCH_VERSION"
echo "MINOR_VERSION=$MINOR_VERSION"
echo "MAJOR_VERSION=$MAJOR_VERSION"
echo "SNAPSHOT_INTENT=$SNAPSHOT_INTENT"
echo "COMMIT_COUNT=$COMMIT_COUNT"
echo "RECOMMENDED=$RECOMMENDED"
echo ""
echo "=== Recent tags (up to 5) ==="
if [[ -n "$RECENT_TAGS" ]]; then
  for t in $RECENT_TAGS; do echo "  $t"; done
else
  echo "  (none — first release)"
fi
echo ""
echo "=== Commits since ${LAST_TAG:-first commit} ($COMMIT_COUNT) ==="
git log --oneline "$RANGE" 2>/dev/null | head -30
if [[ "$COMMIT_COUNT" -gt 30 ]]; then
  echo "... and $((COMMIT_COUNT - 30)) more"
fi
