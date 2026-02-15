---
name: local-issue-creator
description: >
  Full issue lifecycle for this repository. Creates GitHub issues with
  conventional commit-style titles, manages issue branches, commits, PRs,
  project board status, and PR merging. Use when asked to create issues,
  start work on issues, create PRs, or merge PRs for this repo.
license: MIT
compatibility: Claude Code
allowed-tools: Bash(gh:*) Bash(git:*) Bash(bash:*) Read AskUserQuestion
metadata:
  author: edloidas
---

# Issue Lifecycle Skill

Manages the full lifecycle: issue → branch → commits → PR → merge → close.

## Bundled Scripts

Run from the skill directory:

```bash
bash scripts/repo-context.sh                          # labels, assignees, projects
bash scripts/add-to-project.sh <number> [project] [status]  # add issue to project
bash scripts/project-status.sh <number> <status>       # change project status
```

---

## 1. Create Issue

### Title

Must follow conventional commit format — short, imperative:

- `feat: add enonic-cli skill`
- `fix: correct export path format`
- `docs: update README installation section`
- `chore: add validation script`
- `refactor: simplify auth flag handling`

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `style`, `ci`

### Body

Keep it simple. Describe what needs to be implemented as if it doesn't exist yet. Even when creating an issue for current changes, describe the desired outcome in plain words. Don't over-detail.

Template:

```markdown
<Brief description of what needs to be done — 2-4 sentences max.>

<sub>*Drafted with AI assistance*</sub>
```

No section headers, no acceptance criteria, no implementation notes. Just the what and why in plain language.

### Labels

Use from this stable set:

| Label | When |
|-------|------|
| `bug` | Something is broken |
| `feature` | New functionality |
| `improvement` | Enhancement to existing functionality |

These are the primary three. Use `refactoring`, `docs`, `R&D`, `performance`, `critical` only when clearly applicable.

### Assignee

Always ask who to assign. Use `AskUserQuestion`:

```
question: "Who should be assigned?"
header: "Assignee"
options:
  - label: "@me (Recommended)"
    description: "Self-assign"
  - label: "edloidas"
    description: "Top contributor"
  - label: "alansemenov"
    description: "Contributor"
  - label: "No assignee"
    description: "Leave unassigned"
```

If the user explicitly names someone else, use that person directly without asking.

### Project

Default: **Misc (Current Sprint)**. If unavailable, ask user.

### Creating the Issue

```bash
gh issue create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)" \
  --label "<label>" \
  --assignee "<assignee>"
```

After creation, add to project:

```bash
bash scripts/add-to-project.sh <number> "Misc (Current Sprint)"
```

Always show the issue URL after creation.

### Creating Issue for Current Changes

When the user asks to create an issue for work already done:

1. Run `git diff main...HEAD --stat` and `git log main...HEAD --oneline` to understand changes
2. Read key changed files to understand what was implemented
3. Write the title and body as if describing what *needs to be done* (past work framed as a requirement)
4. Create the issue normally
5. If already on a feature branch, offer to rename it to `issue-<number>`

---

## 2. Start Work on Issue

When the user says to work on an issue or start an issue:

1. Fetch issue details: `gh issue view <number>`
2. Create branch from current main:

```bash
git checkout main
git pull
git checkout -b issue-<number>
```

3. Update project status:

```bash
bash scripts/project-status.sh <number> "In Progress"
```

### Commit Format

All commits on an issue branch must follow:

```
<Issue Title> #<number>
```

Examples:
- `feat: add enonic-cli skill #1`
- `fix: correct export path format #5`
- `docs: update README #12`

The title is taken directly from the issue — it already follows conventional commit format.

---

## 3. Create PR

When the user asks to create a PR:

1. Push the branch:

```bash
git push -u origin issue-<number>
```

2. Gather commit summaries:

```bash
git log main..HEAD --oneline
```

3. Ask who to assign and review using `AskUserQuestion`:

```
question: "Who should be assigned and review the PR?"
header: "PR people"
options:
  - label: "edloidas (Recommended)"
    description: "Top contributor"
  - label: "alansemenov"
    description: "Contributor"
```

If the user explicitly names someone, use that person directly without asking.

Set both `--assignee` and `--reviewer` on the PR. If the reviewer is the same person who created the PR (i.e. the current `gh` user), skip `--reviewer` — GitHub doesn't allow self-review.

To check the current user: `gh api user --jq .login`

4. Create PR with title matching the issue title + number:

```bash
gh pr create \
  --title "<Issue Title> #<number>" \
  --assignee "<assignee>" \
  --reviewer "<reviewer>" \
  --body "$(cat <<'EOF'
- <human-readable summary of each logical change>
- <derived from commit messages, not copy-pasted>
- <concise, no fluff>

Closes #<number>

<sub>*Drafted with AI assistance*</sub>
EOF
)"
```

No section headers — just the change list, `Closes` link, and the AI note.

5. Update project status:

```bash
bash scripts/project-status.sh <number> "Review"
```

5. Show the PR URL.

---

## 4. Merge PR

When the user asks to merge:

1. Check PR status:

```bash
gh pr view <pr-number-or-branch> --json state,mergeable,statusCheckRollup
```

2. If checks pass and mergeable, rebase merge:

```bash
gh pr merge <pr-number-or-branch> --rebase --delete-branch
```

3. If there are conflicts:

```bash
git checkout issue-<number>
git fetch origin main
git rebase origin/main
# resolve conflicts if needed
git push --force-with-lease
# wait for checks, then retry merge
```

4. After successful merge, close the issue:

```bash
gh issue close <number>
```

5. Update project status:

```bash
bash scripts/project-status.sh <number> "Done"
```

**Never use regular merge.** Always `--rebase`. If rebase fails after conflict resolution, report to user.

---

## Error Handling

- If Projects V2 API fails (missing `read:project` scope), warn user and skip project operations. Everything else still works.
- If `gh` CLI is not authenticated, stop and tell user to run `gh auth login`.
- If branch `issue-<number>` already exists, ask user whether to switch to it or create a fresh one.
- If issue has no project, skip project status updates silently.

## Keywords

issue, create issue, new issue, start issue, work on issue, branch, PR, pull request, merge, rebase, close issue
