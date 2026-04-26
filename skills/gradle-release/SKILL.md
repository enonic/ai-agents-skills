---
name: gradle-release
description: >
  Release workflow for Enonic XP applications and gradle+npm hybrid packages
  where the version lives in `gradle.properties` and is mirrored in
  `package.json`. Probes GitHub push/tag permissions, runs project + gradle
  checks, suggests a target version from commits since the last tag, syncs
  both files, creates a `Release v<version>` commit and `v<version>` tag,
  then pushes commit and tag atomically to trigger the tag-driven GitHub
  release workflow. Use when the user asks to release, ship, publish, or
  cut a new version of an Enonic XP app or a gradle-built npm package.
  Skip when the project has no `gradle.properties` (npm-only packages).
license: MIT
compatibility: Claude Code, Codex
allowed-tools: Bash Read AskUserQuestion
argument-hint: "optional: strip, patch, minor, major, or explicit version like 0.1.0"
metadata:
  author: enonic
---

# Gradle + npm Release Workflow (Enonic)

Releases for projects where:

- Version lives in `gradle.properties` as `version=X.Y.Z-SNAPSHOT`
- Same value is mirrored in `package.json` (if the project also publishes to npm)
- A `v*` tag pushed to GitHub triggers `.github/workflows/release.yml` which builds, publishes, creates a GitHub release, and pushes a `Updated to next SNAPSHOT version` commit back to the default branch

This skill prepares the release locally (probe permissions, run checks, bump, commit, tag) and pushes commit + tag atomically. CI does the rest.

## Critical Rules

1. **Tag must point to HEAD of the default branch.** The release workflow rejects tags placed elsewhere.
2. **Two version files stay in sync** — `gradle.properties` `version=` and `package.json` `version`. Both must hold the same value at the tagged commit.
3. **Push commit + tag atomically** with `git push --follow-tags`. If the bare commit lands first, the regular build workflow may run before `release.yml`.
4. **Do not release a dirty tree.** Uncommitted changes will not be in the released artifact.
5. **Do not skip user approval.** Always pause for explicit user confirmation before pushing.
6. **Fail fast on permissions.** If the user can't push to the default branch or push tags, stop before doing any version-bumping work.

## Asking the User

User prompts occur at **Step 3** (target version) and **Step 5** (push approval). At each prompt site, in order:

1. Try `AskUserQuestion`. If its schema is deferred, load it first via `ToolSearch` with query `select:AskUserQuestion`, then call it.
2. If the tool is unavailable or the call errors, fall back to chat: post a short numbered list (2–5 options, recommended first) and wait for the reply.

Do not proceed past either prompt without a user reply. Never push without approval.

## When to Use

Use when the user wants to release / ship / publish / cut a new version AND the repo has both:

- `gradle.properties` with a `version=` line
- `.github/workflows/release.yml` (or similar) triggered by `v*` tags

For pure-gradle projects without npm publishing, this skill still applies — the `package.json` sync step is skipped automatically.

## Prerequisites

- Clean working tree on the default branch (`master` or `main`)
- `git`, `sed`
- Optional but recommended: `gh` CLI (authenticated) for permission probing
- Optional: `pnpm`/`npm` for `package.json` sync, `./gradlew` for gradle check

## Workflow

Follow these steps in order. Pause at Step 5 for explicit user approval.

### Step 0: Read project conventions

Read `CLAUDE.md` and `AGENTS.md` from the repo root (whichever exist) and extract:

- **Release commit message format** — default `Release v<version>`. If the project specifies a different format (e.g. `chore: release v<version>`), use that.
- **Branch policy** — default `master`. Some projects release from `main` or version branches.
- **Pre-release validation command** — defaults: `pnpm check` + `./gradlew check`. Override via env vars (see Step 1).

If neither file exists, or neither says anything about releases, proceed with the defaults above. Do not invent project-specific conventions.

### Step 1: Pre-flight — permissions, sync, checks

```bash
bash scripts/release-prepare.sh
```

The script runs in this order, exiting on the first failure:

1. **Repo sanity** — git repo, `gradle.properties` present, version readable
2. **Branch** — must be `master` or `main`
3. **GitHub permission probe** (if `gh` CLI is authed and remote is GitHub):
   - `viewerPermission` must be `WRITE`, `MAINTAIN`, or `ADMIN`
   - Branch rulesets/protection on the default branch — warns if direct push is restricted
   - Tag rulesets — warns if `v*` tags are protected
4. **Clean tree** — no uncommitted or staged changes
5. **In sync with origin** — `git fetch` + verify HEAD matches `origin/<branch>`
6. **Version sanity** — `gradle.properties` and `package.json` versions match (warns if not)
7. **Release workflow detection** — finds `.github/workflows/release*.yml` (warns if none)
8. **`pnpm check`** — typecheck + lint, if `package.json` declares a `check` script
9. **`./gradlew check`** — gradle-side validation (overridable to `build`/`assemble`)

Skip flags (env vars):

- `SKIP_PERMISSION_CHECK=1` — skip the gh probe
- `SKIP_NPM_CHECK=1` — skip `pnpm check`
- `SKIP_GRADLE_CHECK=1` — skip `./gradlew check`
- `GRADLE_CHECK_TASK=build` — run a different gradle task instead of `check`

If the script reports `ERROR:` at any step, stop and surface the message to the user. Don't try to bypass.

### Step 2: Analyze commits and suggest a version

```bash
bash scripts/release-analyze.sh
```

Output is `KEY=VALUE` lines plus a commit list. Key fields:

- `CURRENT_VERSION` — what's in `gradle.properties` now
- `STRIP_VERSION` — current with `-SNAPSHOT` removed (most common pick)
- `PATCH_VERSION` / `MINOR_VERSION` / `MAJOR_VERSION` — bump candidates
- `RECOMMENDED` — `strip` / `patch` / `minor` / `major`, based on commit-message heuristics (`BREAKING`, `feat:`, `fix:`)

The heuristic is conservative — it defaults to `strip` (releasing the current dev version as-is) unless commit messages explicitly signal a bigger bump. For Enonic projects with plain-English commits, `strip` is almost always right.

### Step 3: Confirm target version with user

If the user passed an explicit version or keyword to the skill, use it and skip the prompt.

Otherwise ask via `AskUserQuestion` (see [Asking the User](#asking-the-user)):

- **question**: "Which version to release?"
- **Option 1** — header `Strip`, label `Strip -SNAPSHOT (e.g. {STRIP_VERSION})` — `Release the current dev version as-is.`
- **Option 2** — header `Patch`, label `Patch bump (e.g. {PATCH_VERSION})` — `Skip current and bump patch — bug fixes only.`
- **Option 3** — header `Minor`, label `Minor bump (e.g. {MINOR_VERSION})` — `New features, breaking changes pre-1.0.`
- **Option 4** — header `Major`, label `Major bump (e.g. {MAJOR_VERSION})` — `Breaking changes (post-1.0).`

Substitute the placeholders with the values from `release-analyze.sh`. Append ` (Recommended)` to the label of the option matching the analyzer's `RECOMMENDED` value (`strip` / `patch` / `minor` / `major`).

### Step 4: Bump, commit, tag

```bash
bash scripts/release-bump.sh <version|keyword>
```

Accepts:

- No arg or `strip` — strip `-SNAPSHOT` (e.g. `0.0.7-SNAPSHOT` → `0.0.7`)
- `patch` / `minor` / `major` — bump from current base
- `0.1.0` (or any explicit semver) — use as-is

The script:

- Validates target version (semver, not `-SNAPSHOT`)
- Verifies `v<version>` doesn't exist locally or on `origin`
- Updates `version=` in `gradle.properties`
- Runs `npm version <version> --no-git-tag-version --allow-same-version` if `package.json` exists
- Stages both files
- Commits as `Release v<version>` (override via `RELEASE_COMMIT_MSG=...`)
- Tags the commit `v<version>`

### Step 5: User review and approval

**Always pause here for explicit user approval.**

Show a summary (one row per line):

- **Version:** what's being released
- **Commit:** short SHA + message
- **Tag:** `v<version>`
- **What happens on push:** CI builds, publishes, creates GH release, then pushes a `Updated to next SNAPSHOT version` commit to the default branch

Then ask via `AskUserQuestion` (see [Asking the User](#asking-the-user)):

- **question**: "Ready to push v<version> and trigger the release?"
- **Option 1** — header `Push`, label `Push commit and tag` `(Recommended)` — `git push --follow-tags. CI builds and publishes.`
- **Option 2** — header `Hold`, label `Keep local for review` — `Local commit and tag remain. Nothing is pushed.`

### Step 6: Push

Only after the user approves:

```bash
bash scripts/release-push.sh
```

The script verifies the latest local `v*` tag points to HEAD, then runs `git push --follow-tags origin <branch>`.

### Step 7: Confirm completion

After push, tell the user:

- The Actions URL where the release workflow is running: `<repo>/actions`
- The eventual release URL: `<repo>/releases/tag/v<version>`
- Reminder: CI will push a `Updated to next SNAPSHOT version` commit shortly — pull before further local work to avoid divergence.

## Recovery

If the user picked `Hold` at Step 5 or push failed, the local commit and tag remain. Don't run cleanup automatically — confirm with the user first. Cleanup commands:

```bash
git tag -d v<version>          # remove local tag
git reset --hard HEAD~1        # undo the Release commit
```

If the tag was already pushed but the user wants to abort:

```bash
git push origin :refs/tags/v<version>   # delete remote tag
```

Deleting a remote tag after the workflow already published is destructive — verify the workflow hasn't already shipped the artifact before doing this.

## Common Issues

**Permission probe says insufficient permission:**
Either the gh CLI isn't authed as the right user, or the user really lacks WRITE on the repo. Run `gh auth status` to verify the active account, then ask the user how to proceed (different account, ask repo admin for access, or `SKIP_PERMISSION_CHECK=1` if the warning is a false positive).

**Branch ruleset warning:**
The branch has rules that may block direct push (e.g. requires PR). If the user has bypass permission (admin/maintain), push will still work. If not, releasing requires opening a PR first, which doesn't fit a tag-driven release flow — investigate the ruleset.

**Current version doesn't end in `-SNAPSHOT`:**
The repo is mid-release or in a non-standard state. Investigate before bumping. Often this means a previous release didn't complete its post-release snapshot bump.

**Tag already exists:**
That version was already released (or a previous attempt left a stray tag). Either bump to the next version, or delete the stale tag if you're sure it was never pushed.

**Tag pushed but workflow rejected with "tag does not point to HEAD of master":**
Another commit landed on master between the tag and the push. Delete the remote tag, fast-forward your local master, retry.

**`package.json` and `gradle.properties` versions disagree:**
Pre-flight surfaces this. Manually align them and commit before retrying.

**`./gradlew check` is too slow:**
Default is `check` (tests + linters, no full build). Set `GRADLE_CHECK_TASK=` to a lighter task, or `SKIP_GRADLE_CHECK=1` if `pnpm check` already covers what you need and CI will run the full build anyway.

## Scope

This skill is for gradle-based projects that publish via a tag-triggered GitHub Actions workflow. Defining traits:

- Authoritative version lives in `gradle.properties` (`version=X.Y.Z-SNAPSHOT`), optionally mirrored in `package.json`
- Releases strip `-SNAPSHOT` (or apply an explicit bump) and tag the result
- Pushing the tag drives the actual build, publish, and GitHub release via CI
- CI auto-commits an `Updated to next SNAPSHOT version` bump back to the default branch after publishing

If the project has no `gradle.properties`, this skill does not apply — use a plain npm/pnpm-oriented release flow instead.

## Keywords

release, ship, publish, version, bump, tag, gradle, gradle-properties, snapshot, enonic, xp, page-editor, deploy, cut release, new version
