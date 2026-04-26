#!/bin/bash

# Release Preparation Script (gradle + npm)
# Validates push permissions, git status, version state, and runs project + gradle checks.
# Optimized for agent interpretation — emits short, parseable lines.
#
# Env vars:
#   SKIP_PERMISSION_CHECK=1  Skip GitHub permission probe
#   SKIP_NPM_CHECK=1         Skip `pnpm check` / `npm run check`
#   SKIP_GRADLE_CHECK=1      Skip `./gradlew <task>`
#   GRADLE_CHECK_TASK=check  Override gradle task (default: check)

set -e

# Git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: Not a git repository"
  exit 1
fi

# gradle.properties (required)
if [ ! -f "gradle.properties" ]; then
  echo "ERROR: No gradle.properties found in $(pwd)"
  echo "INFO: gradle-release is for gradle-based projects. Use a plain npm release flow for npm-only packages."
  exit 1
fi

# Read version
VERSION=$(grep -E '^version=' gradle.properties | head -1 | cut -d= -f2-)
if [[ -z "$VERSION" ]]; then
  echo "ERROR: No 'version=' line in gradle.properties"
  exit 1
fi
echo "Current version: $VERSION"

if [[ "$VERSION" != *-SNAPSHOT ]]; then
  echo "WARNING: Version $VERSION does not end in -SNAPSHOT"
  echo "INFO: Repo may be mid-release or in a non-standard state — investigate before bumping"
fi

# Branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Branch: $CURRENT_BRANCH"
if [[ "$CURRENT_BRANCH" != "master" ]] && [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "ERROR: Not on master or main branch"
  exit 1
fi

# === GitHub permission probe (fast — fail before doing real work) ===
if [[ "$SKIP_PERMISSION_CHECK" != "1" ]]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  REPO_SLUG=""
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    REPO_SLUG="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi

  if [[ -n "$REPO_SLUG" ]] && command -v gh > /dev/null 2>&1; then
    if gh auth status > /dev/null 2>&1; then
      PERM=$(gh repo view "$REPO_SLUG" --json viewerPermission --jq '.viewerPermission' 2>/dev/null || echo "")
      case "$PERM" in
        ADMIN|MAINTAIN|WRITE)
          echo "Push permission ($REPO_SLUG): $PERM"
          ;;
        TRIAGE|READ|NONE|"")
          echo "ERROR: Insufficient push permission on $REPO_SLUG (got: ${PERM:-unknown})"
          echo "INFO: Need WRITE, MAINTAIN, or ADMIN to push commits and tags"
          exit 1
          ;;
      esac

      # Branch rulesets / protection — warn if push would be blocked
      BRANCH_RULES=$(gh api "repos/$REPO_SLUG/rules/branches/$CURRENT_BRANCH" 2>/dev/null || echo "[]")
      if [[ "$BRANCH_RULES" != "[]" ]]; then
        BLOCKING=$(echo "$BRANCH_RULES" | grep -E '"type":"(pull_request|required_status_checks|required_signatures|non_fast_forward)"' || true)
        if [[ -n "$BLOCKING" ]]; then
          echo "WARNING: Branch $CURRENT_BRANCH has rulesets that may block direct push:"
          echo "$BLOCKING" | sed 's/^/  /'
        fi
      fi

      # Tag rulesets — probe with a typical v* tag name
      TAG_RULES=$(gh api "repos/$REPO_SLUG/rules/tags/v0.0.0" 2>/dev/null || echo "[]")
      if [[ "$TAG_RULES" != "[]" ]]; then
        echo "WARNING: Tag rulesets active for v* — push may require special permission"
      fi
    else
      echo "INFO: gh CLI not authenticated — skipping permission probe"
    fi
  else
    echo "INFO: Skipping permission probe (no GitHub remote or gh CLI not installed)"
  fi
fi

# Clean tree
if [[ -n $(git status --porcelain) ]]; then
  echo "ERROR: Uncommitted changes detected"
  git status --short
  exit 1
fi

# In sync with origin
if git remote get-url origin > /dev/null 2>&1; then
  git fetch --quiet origin "$CURRENT_BRANCH" 2>/dev/null || true
  LOCAL=$(git rev-parse HEAD)
  REMOTE_HEAD=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")
  if [[ -n "$REMOTE_HEAD" && "$LOCAL" != "$REMOTE_HEAD" ]]; then
    echo "ERROR: Local $CURRENT_BRANCH is not in sync with origin/$CURRENT_BRANCH"
    echo "INFO: Run: git pull --ff-only origin $CURRENT_BRANCH"
    exit 1
  fi
fi

# package.json (optional mirror)
if [ -f "package.json" ]; then
  PKG_VERSION=$(grep -E '"version"[[:space:]]*:' package.json | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
  echo "package.json: present, version=$PKG_VERSION"
  if [[ "$PKG_VERSION" != "$VERSION" ]]; then
    echo "WARNING: package.json version ($PKG_VERSION) differs from gradle.properties ($VERSION)"
    echo "INFO: Versions should match before tagging — investigate"
  fi
else
  echo "package.json: not present (gradle-only release)"
fi

# Release workflow detection
if [ -f ".github/workflows/release.yml" ]; then
  echo "Release workflow: .github/workflows/release.yml"
elif compgen -G ".github/workflows/release*.yml" > /dev/null; then
  echo "Release workflow: $(ls .github/workflows/release*.yml | head -1)"
else
  echo "WARNING: No .github/workflows/release*.yml found"
  echo "INFO: Pushing a tag may not trigger an automated release in this repo"
fi

# === npm-side check (fast — typecheck + lint) ===
if [[ "$SKIP_NPM_CHECK" != "1" ]] && [ -f "package.json" ] && grep -q '"check"[[:space:]]*:' package.json; then
  echo "Running project check..."
  if command -v pnpm > /dev/null 2>&1 && [ -f "pnpm-lock.yaml" ]; then
    if pnpm check; then
      echo "Project check: passed"
    else
      echo "ERROR: Project check failed"
      exit 1
    fi
  elif command -v npm > /dev/null 2>&1; then
    if npm run check; then
      echo "Project check: passed"
    else
      echo "ERROR: Project check failed"
      exit 1
    fi
  else
    echo "WARNING: Neither pnpm nor npm found — skipping project check"
  fi
fi

# === Gradle-side check (validates the actual release-time build path) ===
if [[ "$SKIP_GRADLE_CHECK" != "1" ]] && [ -x "./gradlew" ]; then
  TASK="${GRADLE_CHECK_TASK:-check}"
  echo "Running ./gradlew $TASK ..."
  if ./gradlew "$TASK" --quiet; then
    echo "Gradle $TASK: passed"
  else
    echo "ERROR: Gradle $TASK failed"
    exit 1
  fi
elif [[ "$SKIP_GRADLE_CHECK" != "1" ]]; then
  echo "INFO: No ./gradlew wrapper found — skipping gradle check"
fi

echo "SUCCESS: Pre-flight checks passed"
echo "Suggested release version: ${VERSION%-SNAPSHOT}"
