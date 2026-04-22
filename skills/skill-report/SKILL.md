---
name: skill-report
description: >
  Records skill execution failures for author review and skill improvement.
  Use when a skill produces incorrect results, misinterprets its own instructions,
  or when the user corrects skill-driven behavior. Writes structured reports to
  $TMPDIR for later analysis. Never interrupt the user's current task — only
  suggest recording after the task completes.
license: MIT
compatibility: Claude Code, Codex
allowed-tools: Bash(mkdir:*) Read Write Glob
metadata:
  author: enonic
---

## Critical Rules

1. **NEVER interrupt the user's current task** to suggest reporting. Only suggest recording AFTER the current task is complete.
2. Only record **skill-related issues** — bad instructions, missing edge cases, wrong examples, outdated patterns. NOT environmental failures (network, permissions, missing tools), user typos, or out-of-scope requests.
3. Reports must be **portable**: no absolute paths from the user's project, no machine-specific details. Focus on the skill's instructions and what they got wrong.
4. One report per distinct issue. Combine related issues within a single session into one report.

## When to Record

- Skill instructions led to incorrect output
- User had to correct behavior that the skill should have handled
- A skill's example or pattern was wrong or outdated
- Skill missed an edge case that caused failure
- Skill's description triggered activation in the wrong context

Do NOT record: user typos, environment issues, tool unavailability, out-of-scope requests, or problems unrelated to skill instructions.

## Semi-Automatic Flow

This is the primary mode — Claude detects an issue during normal work.

1. While working on a task, notice a skill instruction issue
2. **Continue the task** — do NOT interrupt or mention it yet
3. After task completion, suggest: _"I noticed [skill] had an instruction issue: [brief description]. Want me to record it for improvement?"_
4. If user agrees, read the skill's SKILL.md to identify the relevant instructions
5. Write the report using the template below
6. Show the report file path

## Manual Flow

User invokes `/skill-report` directly.

1. If `$ARGUMENTS` provided, use it as `<skill-name>`
2. If no arguments, ask which skill to report on
3. Ask user to describe the issue (or use conversation context if the issue was just discussed)
4. Read the skill's SKILL.md to identify relevant instructions
5. Write the report using the template below
6. Show the report file path

## Report Storage

**Path pattern:** `$TMPDIR/skill-reports/<skill-name>/YYYY-MM-DD_<session-id-short>.md`

- `$TMPDIR` — OS-managed temporary directory (falls back to `/tmp` if unset)
- `<skill-name>` — subdirectory per skill for easy browsing
- `YYYY-MM-DD` — date prefix for sorting
- `<session-id-short>` — first 8 characters of `$CLAUDE_SESSION_ID` (use `unknown` if unavailable)
- Create the directory with `mkdir -p` before writing
- If a report already exists for this session, append a counter suffix (`_2`, `_3`, etc.)

## Report Template

```markdown
# Skill Report: <skill-name>

Date: YYYY-MM-DD
Session: <full CLAUDE_SESSION_ID or "unknown">

## Context
What the skill was trying to accomplish and what task triggered it.

## Issue
What went wrong — the observable incorrect behavior.

## Root Cause
Which specific section, rule, or example in the skill's instructions
led to the incorrect behavior. Quote the relevant instruction.

## Expected Behavior
What the correct outcome should have been.

## Suggested Improvement
Concrete change to the skill's SKILL.md or references that would
prevent this issue. Be specific — name the section and describe the fix.
```

Fill every section. Quote the actual skill instruction that caused the issue in **Root Cause**. Be specific in **Suggested Improvement** — name the section and describe the exact change.

## Reading Reports (for Skill Improvement)

When the user asks to review reports or improve a skill based on reports:

1. List reports: `ls $TMPDIR/skill-reports/<skill-name>/`
2. Read each report
3. Cross-reference with the skill's current SKILL.md
4. Propose specific changes to the skill's instructions
5. Group related issues if multiple reports point to the same root cause

## Edge Cases

- `$TMPDIR` not set → fall back to `/tmp`
- `$CLAUDE_SESSION_ID` not available → use `unknown` as session ID
- Skill directory not found in repo → still write the report with available context, note the skill wasn't found
- Multiple distinct issues in one session → write separate reports, append counter suffix
- Report file already exists → append counter suffix (`_2`, `_3`, etc.)
