#!/bin/bash

# Release Push Script (gradle + npm)
# Pushes the release commit and v* tag atomically.
# Verifies the latest local v* tag points to HEAD before pushing.

set -e

# Git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: Not a git repository"
  exit 1
fi

# Remote
if ! git remote get-url origin > /dev/null 2>&1; then
  echo "ERROR: No 'origin' remote configured"
  exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
echo "Branch: $CURRENT_BRANCH"

# Find latest v* tag
LATEST_TAG=$(git for-each-ref --sort=-creatordate --format='%(refname:short)' refs/tags/v\* | head -1)
if [[ -z "$LATEST_TAG" ]]; then
  echo "ERROR: No v* tag found locally"
  echo "INFO: Run release-bump.sh first to create the release commit and tag"
  exit 1
fi
echo "Tag: $LATEST_TAG"

# Tag must point to HEAD
HEAD_SHA=$(git rev-parse HEAD)
TAG_SHA=$(git rev-parse "$LATEST_TAG")
if [[ "$TAG_SHA" != "$HEAD_SHA" ]]; then
  echo "ERROR: Tag $LATEST_TAG does not point to HEAD"
  echo "INFO: Tag commit:  $(git rev-parse --short "$LATEST_TAG")"
  echo "INFO: HEAD commit: $(git rev-parse --short HEAD)"
  echo "INFO: The release workflow rejects tags not on HEAD of the default branch"
  exit 1
fi

# Push commit + tag atomically.
# --follow-tags: client-side, includes reachable annotated tags in the push.
# --atomic:      server-side, makes the multi-ref update transactional —
#                if the tag is rejected (protection rule, hook, race), the
#                branch update rolls back too. No partial state on origin.
echo "Pushing $CURRENT_BRANCH and $LATEST_TAG to origin..."
if git push --follow-tags --atomic origin "$CURRENT_BRANCH"; then
  echo "SUCCESS: Pushed $LATEST_TAG"
else
  echo "ERROR: Push failed"
  exit 1
fi

# Useful URLs
REMOTE_URL=$(git remote get-url origin | sed -E 's#\.git$##; s#git@github.com:#https://github.com/#')
echo ""
echo "=== Post-Release ==="
echo "Workflow: $REMOTE_URL/actions"
echo "Release:  $REMOTE_URL/releases/tag/$LATEST_TAG"
echo ""
echo "INFO: CI will push a 'Updated to next SNAPSHOT version' commit shortly."
echo "INFO: Pull before further local work: git pull --ff-only origin $CURRENT_BRANCH"
