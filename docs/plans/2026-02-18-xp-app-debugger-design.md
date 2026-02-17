# xp-app-debugger — Design

## Overview

A skill for debugging Enonic XP application errors. Covers build failures (Gradle, TypeScript) and server runtime errors (Nashorn/JS stack traces in `server.log`). Primarily user-invoked, with full-cycle capability (deploy, tail, analyze, fix, verify) gated by user approval at each phase.

## Decisions

- **Name**: `xp-app-debugger`
- **Scope**: Build errors + Java/Nashorn JS runtime errors
- **Workflow**: Phased with gates (Gather → Analyze → Fix → Verify)
- **Autonomy**: Conservative by default — each phase waits for user before advancing
- **Heuristics**: Growing `references/known-patterns.md`, kept concise (~5 lines per entry, max ~30 entries)
- **XP knowledge**: Cross-references `xp-app-creator` — no duplication
- **Approach**: Phased Debugger (Approach A)

## File Structure

```
xp-app-debugger/
├── SKILL.md
└── references/
    └── known-patterns.md
```

## Phased Workflow

### Phase 1: Gather

- **User pastes logs**: Parse directly, identify error type
- **User says "check the logs"**: Read `$XP_HOME/logs/server.log` — user already hit the error. Spawn haiku subagent for large logs to extract ERROR/WARN entries
- **User says "debug my app"**: Deploy first (using project-specific instructions from CLAUDE.md/README or `./gradlew deploy`), then tail logs
- Identify error type: build (Gradle/TS) or runtime (server.log)
- Locate files: source (`src/main/resources/`) and compiled (`build/resources/main/`)

**Gate**: Present findings — error type, location, relevant files. Ask to proceed.

### Phase 2: Analyze

- Trace error to exact source location (line numbers, file paths)
- For Nashorn errors: map compiled JS path back to TS source if applicable
- Check `references/known-patterns.md` for matching heuristics
- Cross-reference `xp-app-creator` for XP API/domain knowledge
- Check XP platform source at https://github.com/enonic/xp via `gh` if error points to XP internals
- Check sibling repos: list parent directory for related apps/libs
- Don't assume which value caused the error — understand full context first

**Gate**: Present analysis — cause, evidence, reasoning. Ask to proceed.

### Phase 3: Fix

- Propose specific fix with rationale
- Show exact code change (before/after)
- Get user approval, then apply

**Gate**: Fix applied. Ask to redeploy and verify.

### Phase 4: Verify

- Redeploy the app
- Tail logs, check for same error
- If error persists: back to Phase 2 with new information
- If resolved: report success, optionally suggest adding pattern to known heuristics

## Critical Rules

1. Never jump to a fix before completing Phase 2
2. Compiled JS (`build/resources/main/`) is source of truth for runtime errors
3. Use `log.info()`, `log.error()`, `log.warning()` for server-side logging (global `log` object)
4. Large logs get a haiku subagent — don't read full server.log in main context
5. Don't deploy unless asked
6. Check sibling repos in parent directory

## Cross-References

When XP domain knowledge is needed, load from `xp-app-creator`:
- Controller/API patterns → `xp-app-creator/references/controllers.md`
- Component structure → `xp-app-creator/references/components.md`
- Build system → `xp-app-creator/references/build-system.md`
- Content API → `xp-app-creator/references/content-api.md`

## Known Patterns Format

Each entry in `references/known-patterns.md`:

```markdown
## Pattern Name

**Symptom**: What the error looks like
**Cause**: Why it happens
**Fix**: What to do
**Applies to**: XP version or context
```

Max ~5 lines per entry. Prune when file exceeds ~30 entries.
