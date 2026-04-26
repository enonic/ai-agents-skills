#!/bin/bash

# Release Bump Script (gradle + npm)
# Updates version in gradle.properties and package.json, commits, tags.
#
# Usage: release-bump.sh [version|keyword]
#   No arg / "strip" : strip -SNAPSHOT from current version
#   "patch"          : next patch from latest v* tag (e.g. v0.0.6 -> 0.0.7)
#   "minor"          : next minor from latest v* tag (e.g. v0.0.6 -> 0.1.0)
#   "major"          : next major from latest v* tag (e.g. v0.0.6 -> 1.0.0)
#   X.Y.Z            : explicit version
#
# Bump keywords are computed from the latest semver tag in the repo, NOT from
# the snapshot's base version. The snapshot's base alone tells you nothing
# about which bump type was intended (3.0.0-SNAPSHOT could be major/minor/patch
# depending on what was previously released).
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

# Resolve bump keywords from the latest canonical v<X.Y.Z> tag.
LAST_TAG=$(git for-each-ref --sort=-v:refname --format='%(refname:short)' 'refs/tags/v*' 2>/dev/null \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
if [[ -n "$LAST_TAG" ]]; then
  LAST_VER="${LAST_TAG#v}"
  if [[ "$LAST_VER" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    LMAJ="${BASH_REMATCH[1]}"
    LMIN="${BASH_REMATCH[2]}"
    LPCH="${BASH_REMATCH[3]}"
  fi
fi

bump_requires_tag() {
  if [[ -z "$LAST_TAG" ]]; then
    echo "ERROR: No prior v<X.Y.Z> tag found — '$1' bump has no reference point"
    echo "INFO: Use 'strip' or pass an explicit version (e.g. 0.0.7)"
    exit 1
  fi
}

# Resolve target version from arg or keyword
ARG="${1:-strip}"
case "$ARG" in
  strip)
    VERSION="$BASE"
    ;;
  patch)
    bump_requires_tag patch
    VERSION="$LMAJ.$LMIN.$((LPCH + 1))"
    ;;
  minor)
    bump_requires_tag minor
    VERSION="$LMAJ.$((LMIN + 1)).0"
    ;;
  major)
    bump_requires_tag major
    VERSION="$((LMAJ + 1)).0.0"
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
