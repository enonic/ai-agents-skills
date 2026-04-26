#!/bin/bash

# Release Bump Script (gradle + npm)
# Updates version in gradle.properties and package.json, commits, tags.
#
# Usage: release-bump.sh [version|keyword]
#   No arg / "strip" : strip -SNAPSHOT from current version
#   "patch"          : bump patch from current base (e.g. 0.0.7-SNAPSHOT -> 0.0.8)
#   "minor"          : bump minor from current base (e.g. 0.0.7-SNAPSHOT -> 0.1.0)
#   "major"          : bump major from current base (e.g. 0.0.7-SNAPSHOT -> 1.0.0)
#   X.Y.Z            : explicit version
#
# Env:
#   RELEASE_COMMIT_MSG: optional override for the commit message
#                      (default: "Release v<version>")

set -e

# gradle.properties required
if [ ! -f "gradle.properties" ]; then
  echo "ERROR: No gradle.properties found"
  exit 1
fi

# Read current version
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
MAJ="${BASH_REMATCH[1]}"
MIN="${BASH_REMATCH[2]}"
PCH="${BASH_REMATCH[3]}"

# Resolve target version from arg or keyword
ARG="${1:-strip}"
case "$ARG" in
  strip)
    VERSION="$BASE"
    ;;
  patch)
    VERSION="$MAJ.$MIN.$((PCH + 1))"
    ;;
  minor)
    VERSION="$MAJ.$((MIN + 1)).0"
    ;;
  major)
    VERSION="$((MAJ + 1)).0.0"
    ;;
  *)
    VERSION="$ARG"
    ;;
esac

TAG="v$VERSION"
COMMIT_MSG="${RELEASE_COMMIT_MSG:-Release $TAG}"

# Validate semver-ish, reject -SNAPSHOT
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-][0-9A-Za-z.-]+)?$ ]]; then
  echo "ERROR: Invalid version format: $VERSION"
  echo "INFO: Expected X.Y.Z or X.Y.Z-prerelease (e.g. 0.0.7, 1.0.0-rc.1)"
  exit 1
fi
if [[ "$VERSION" == *-SNAPSHOT ]]; then
  echo "ERROR: Cannot release a -SNAPSHOT version"
  exit 1
fi

echo "Current version: $CURRENT"
echo "Target version:  $VERSION"
echo "Tag:             $TAG"

# Tag must not already exist locally
if git tag -l | grep -qx "$TAG"; then
  echo "ERROR: Tag $TAG already exists locally"
  exit 1
fi
# Or on origin
if git remote get-url origin > /dev/null 2>&1; then
  if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/$TAG\$"; then
    echo "ERROR: Tag $TAG already exists on origin"
    exit 1
  fi
fi

# Update gradle.properties (portable across macOS/linux sed)
sed -i.bak -E "s/^version=.*/version=$VERSION/" gradle.properties
rm -f gradle.properties.bak
echo "gradle.properties: version=$VERSION"

# Update package.json if present
if [ -f "package.json" ]; then
  if command -v npm > /dev/null 2>&1; then
    npm version "$VERSION" --no-git-tag-version --allow-same-version > /dev/null
    echo "package.json: version=$VERSION"
  else
    echo "WARNING: npm not found — package.json not updated; sync manually before committing"
  fi
fi

# Stage
git add gradle.properties 2>/dev/null || true
[ -f "package.json" ] && git add package.json 2>/dev/null || true

# Commit
git commit -m "$COMMIT_MSG"
COMMIT_SHA=$(git rev-parse --short HEAD)
echo "Committed: $COMMIT_SHA $COMMIT_MSG"

# Tag
git tag "$TAG"
echo "Tagged: $TAG -> $COMMIT_SHA"

echo "SUCCESS: Local commit and tag created"
echo "INFO: Review with 'git show $TAG', then run release-push.sh to push"
