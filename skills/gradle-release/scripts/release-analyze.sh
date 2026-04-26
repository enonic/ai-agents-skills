#!/bin/bash

# Release Analysis Script (gradle + npm)
# Reads current version, shows commits since last tag, suggests bump options.
# Output is structured so the agent can parse it and present options to the user.
#
# Output keys (one per line, KEY=VALUE):
#   CURRENT_VERSION    Current version from gradle.properties
#   BASE_VERSION       Version with -SNAPSHOT stripped
#   LAST_TAG           Last v* tag (empty if none)
#   STRIP_VERSION      Candidate: strip -SNAPSHOT
#   PATCH_VERSION      Candidate: patch bump from base
#   MINOR_VERSION      Candidate: minor bump from base
#   MAJOR_VERSION      Candidate: major bump from base
#   RECOMMENDED        One of: strip, patch, minor, major
#   COMMIT_COUNT       Commits since last tag

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
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

STRIP_VERSION="$BASE"
PATCH_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
MINOR_VERSION="$MAJOR.$((MINOR + 1)).0"
MAJOR_VERSION="$((MAJOR + 1)).0.0"

LAST_TAG=$(git for-each-ref --sort=-creatordate --format='%(refname:short)' refs/tags/v\* 2>/dev/null | head -1 || echo "")

# Commits since last tag (or all commits if no tag)
if [[ -n "$LAST_TAG" ]]; then
  RANGE="$LAST_TAG..HEAD"
else
  RANGE="HEAD"
fi
COMMIT_COUNT=$(git log --oneline "$RANGE" 2>/dev/null | wc -l | tr -d ' ')

# Heuristic: scan commit subjects for breaking / feat / fix patterns.
# Works for Conventional Commits AND keyword-flavored plain-English logs.
SUBJECTS=$(git log --pretty=format:'%s' "$RANGE" 2>/dev/null || echo "")

RECOMMENDED="strip"
if echo "$SUBJECTS" | grep -qiE '(BREAKING CHANGE|^[a-z]+!:|^breaking|major bump)'; then
  RECOMMENDED="major"
elif echo "$SUBJECTS" | grep -qiE '(^feat(\(.+\))?:|^add |new feature|minor bump)'; then
  RECOMMENDED="minor"
elif [[ "$COMMIT_COUNT" -gt 0 ]]; then
  RECOMMENDED="strip"
fi

# When the current version is already 0.0.x, conservative default is "strip"
# unless commits clearly signal a bump.

echo "CURRENT_VERSION=$CURRENT"
echo "BASE_VERSION=$BASE"
echo "LAST_TAG=$LAST_TAG"
echo "STRIP_VERSION=$STRIP_VERSION"
echo "PATCH_VERSION=$PATCH_VERSION"
echo "MINOR_VERSION=$MINOR_VERSION"
echo "MAJOR_VERSION=$MAJOR_VERSION"
echo "COMMIT_COUNT=$COMMIT_COUNT"
echo "RECOMMENDED=$RECOMMENDED"
echo ""
echo "=== Commits since ${LAST_TAG:-first commit} ($COMMIT_COUNT) ==="
git log --oneline "$RANGE" 2>/dev/null | head -30
if [[ "$COMMIT_COUNT" -gt 30 ]]; then
  echo "... and $((COMMIT_COUNT - 30)) more"
fi
