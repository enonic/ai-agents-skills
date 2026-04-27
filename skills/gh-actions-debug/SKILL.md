---
name: gh-actions-debug
description: >
  Debug failing GitHub Actions runs for Enonic apps. Resolves a run from a URL,
  numeric run ID, commit SHA, branch name, or the current branch's HEAD;
  classifies the failure (gradle build vs Selenium test); for Selenium
  failures, downloads the `ui-test-report-*` artifacts, identifies failing
  specs, views the referenced screenshots, cross-references the local spec
  source, and writes a per-run report. Use when the user asks to check actions,
  diagnose a failing build or Selenium run, look at the latest CI failure on a
  branch or PR, or find out why a commit's checks are red.
license: MIT
compatibility: Claude Code
allowed-tools: Bash(gh:*) Bash(git:*) Bash(jq:*) Bash(unzip:*) Bash(grep:*) Bash(sed:*) Bash(find:*) Bash(mkdir:*) Bash(ls:*) Bash(cat:*) Bash(cp:*) Bash(rm:*) Bash(./skills/gh-actions-debug/scripts/*) Read Edit Glob Grep
argument-hint: "optional: run URL, run ID, commit SHA, branch name, or empty for current branch"
metadata:
  author: enonic
---

# Debugging Failing GitHub Actions Runs

Diagnose CI failures for Enonic apps that follow the standard workflow shape:
a `build` job followed by a `selenium-test` matrix that uploads
`ui-test-report-<suite>` artifacts containing `screenshots/`, `logs/`, and
`allure-report/index.html`.

## Critical Rules

1. **Resolve before reporting.** Always run `scripts/resolve-run.sh` first.
   Never guess a run ID from the user's wording.
2. **Three checkpoints.** Surface findings progressively:
   - Checkpoint 1 (after resolve): run link + which jobs failed + one-line headline
   - Checkpoint 2 (after artifact download + parse): failing spec(s), error message, screenshot paths
   - Checkpoint 3 (after analysis): compact summary in chat; full `report.md` only when the breadth heuristic permits it
3. **Read screenshots, don't just link them.** For category-1 failures
   (≤5 failing tests, see Breadth heuristic) the primary screenshot for each
   failing test MUST be viewed via Read so the analysis is grounded in the
   visual.
4. **Cross-reference local source when available.** If `git rev-parse HEAD`
   in the local checkout matches the run's `head_sha`, read the failing spec
   file and the top stack frame's source line. If they diverge, warn that
   line numbers may be off.
5. **Cache, don't re-download.** Artifacts go to
   `.gh-actions/<run-id>/<suite>/`. If the directory exists and is non-empty,
   reuse it.
6. **Auto-gitignore.** Before the first cache write to `.gh-actions/`,
   ensure the directory is gitignored. Use the exact command:
   ```bash
   grep -qxF '.gh-actions/' .gitignore 2>/dev/null || printf '\n.gh-actions/\n' >> .gitignore
   ```
   If the repo has no `.gitignore`, create one. Do not modify any other
   gitignore entries.

## Inputs

The skill accepts any of:

- **Run URL** — `https://github.com/<owner>/<repo>/actions/runs/<run-id>` (with or without `/job/<id>` suffix)
- **Run ID** — bare number
- **Commit SHA** — full or short hex (≥7 chars); short SHAs are expanded via `git rev-parse`
- **Branch name** — anything else
- **No argument** — uses current branch's HEAD commit

Repo is detected from cwd's `git remote get-url origin` unless the input is a
full URL (which carries its own `owner/repo`). To override, set
`GH_ACTIONS_DEBUG_REPO=owner/repo` in the environment.

## Phase 1 — Resolve & detect

Run `scripts/resolve-run.sh "$ARGUMENTS"`. It prints a single JSON line
with: `run_id, repo, branch, head_sha, status, conclusion, event, name,
html_url, source`.

If the run's `conclusion` is not `failure` (e.g. `success`, `cancelled`,
`in_progress`), tell the user and stop — there's nothing to debug.

Then fetch the job tree:

```bash
gh run view <run_id> --repo <repo> --json jobs > .gh-actions/<run_id>/run.json
```

Identify failing jobs by name + conclusion. Two cases matter:

- a job named `build` with `conclusion: "failure"` → **build-failure path** (Phase 2)
- jobs whose name starts with `selenium-test` (or matches the matrix in `.github/workflows/`) with `conclusion: "failure"` → **selenium-failure path** (Phase 3)

If both are present, the build job blocks selenium — handle build only.

### Checkpoint 1 — emit immediately after Phase 1

```
**Run:** [Gradle Build #<run_id>](<html_url>)
**Branch / commit:** <branch> @ <head_sha-short>
**Triggered by:** <event>
**Conclusion:** failure

**Failing jobs:**
- <job-name> — <one-line annotation if any>

_Reading logs next..._
```

Then proceed to Phase 2 or Phase 3.

### Worked example (selenium failure)

```
User: /gh-actions-debug 24983604721

→ resolve-run.sh 24983604721 →
  { run_id: "24983604721", repo: "enonic/app-contentstudio",
    branch: "master", head_sha: "f437d4d…", conclusion: "failure" }

→ gh run view 24983604721 --json jobs →
  failing job: "selenium-test (testInputTypes)" (id 73151774512)

Checkpoint 1:
**Run:** [Gradle Build #24983604721](…/runs/24983604721)
**Branch / commit:** master @ f437d4d
**Triggered by:** workflow_dispatch
**Conclusion:** failure

**Failing jobs:**
- selenium-test (testInputTypes) — Process completed with exit code 1

_Downloading ui-test-report-testInputTypes…_

(Phase 3 then parses the log, identifies the failing spec
 image.selector0_1.spec, locates screenshot
 err_save_button_disabled386679.png, views it, reads the spec source,
 and emits Checkpoint 2 + Checkpoint 3.)
```

## Phase 2 — Build-failure analysis

When the `build` job is the failing one, do not download artifacts. Run:

```bash
scripts/fetch-job-log.sh <repo> <run_id> <build_job_id> .gh-actions/<run_id>/build/job.log
scripts/parse-build-log.sh .gh-actions/<run_id>/build/job.log > .gh-actions/<run_id>/build/summary.json
```

`fetch-job-log.sh` is idempotent: it skips the network round-trip if the
target log is already cached.

`parse-build-log.sh` emits:

- `failed_tasks` — array of `:module:task` strings that gradle marked FAILED
- `failure_block` — the human-readable `FAILURE:` paragraph from the gradle output
- `task_output_range` — `{start_line, end_line}` inside `job.log` for the
  failing task's own console output. Use `Read` with `offset`/`limit` to
  load the slice for context, not the whole log.
- `compile_or_lint_locations` — array of `{file, line, column, severity,
  message, rule}` extracted from ESLint, javac, and tsc output. `file` is
  rooted at `modules/...` so it maps directly onto the local checkout.
- `totals` — counts.

### Build-failure analysis steps

1. Read `summary.json`.
2. If `compile_or_lint_locations` is non-empty: read the corresponding
   local source files (typically a few lines around each error) so the
   summary explains the failure, not just lists it.
3. If `compile_or_lint_locations` is empty (e.g. a test failure or a
   gradle plugin error): use `task_output_range` to read the failing task's
   slice of the log — that's where the assertion / stack trace lives.
4. Cross-reference the local checkout's HEAD with the run's `head_sha`. If
   they differ, warn that source line numbers may have shifted.

### Checkpoint 2 (build path) — emit before any analysis

```
**Failed gradle task(s):** :module:task
**Symptom:** <one-line gist from failure_block>
**Locations:** N (eslint/tsc/javac)

_Reading <local-files>…_
```

### Final output (build path)

In chat: a compact summary — failing task, root-cause one-liner, and a
short bullet per error location with the failing source line quoted. No
`report.md` for build failures (the gradle output is already canonical;
the user will look at the run page for full context).

## Phase 3 — Selenium artifact analysis

For each failing `selenium-test (<suite>)` job, run:

```bash
# 1. Download the suite's artifact (idempotent — cache reused on rerun).
scripts/fetch-artifact.sh <repo> <run_id> ui-test-report-<suite> .gh-actions/<run_id>/<suite>

# 2. Fetch + clean the failing job's log into the same suite directory.
scripts/fetch-job-log.sh <repo> <run_id> <selenium_job_id> .gh-actions/<run_id>/<suite>/job.log

# 3. Parse the log into structured failure records.
scripts/parse-selenium-log.sh .gh-actions/<run_id>/<suite>/job.log \
  > .gh-actions/<run_id>/<suite>/summary.json
```

`summary.json` contains:

- `failures[]` — one record per failing test, with:
  - `describe_path` — spec stem (e.g. `image.selector0_1.spec`)
  - `test_path` — `GIVEN ... WHEN ... THEN ...` description
  - `error_message` — assertion message minus the screenshot trailer
  - `screenshot_stem` — bare name to resolve under `screenshots/`
  - `spec_file`, `spec_line`, `spec_column` — relative path into the local
    checkout (already stripped of the runner's `/home/runner/work/...`)
  - `stack_frames[]` — full stack with `{fn, file, line, column}`
- `totals` — `{specs_total, specs_passed, specs_failed}` from wdio's summary
  line.

### Resolving artifact references

- **Screenshot from stem:** the file in `screenshots/` has a numeric suffix:
  ```bash
  find .gh-actions/<run_id>/<suite>/screenshots -maxdepth 1 -name '<stem>*.png'
  ```
  If multiple matches exist, use the most recently modified.
- **Per-spec log:** `logs/` contains `<spec-stem>*.log` files. They are
  large (~1 MB); only read with `Read` + `offset`/`limit` if Phase 3 logic
  needs deeper context than the parser already extracted.
- **Local spec source:** the relative path `testing/specs/...spec.js`
  maps directly into the local checkout (e.g. `~/repo/app-contentstudio/`).
  Use `Read` to open the file at `spec_line` (a few lines of context).

### Phase 3.1 — Failure breadth classification

After every failing suite has its own `summary.json`, run the classifier:

```bash
scripts/classify-breadth.sh \
  .gh-actions/<run_id>/run.json \
  .gh-actions/<run_id>/<suite-1> \
  .gh-actions/<run_id>/<suite-2> ...
```

Output (`breadth.json`) has:

- `category`: `1` few-failures, `2` single-suite-broken, `3` all-suites-broken
- `category_label`: human-readable name
- `total_failing_tests`, `selenium_jobs_total`, `selenium_jobs_failed`
- `suites[]` with `{suite, specs_total, specs_failed, all_failed, mostly_failed}`
- `write_report`: `true` only for category 1

Decision priority: all-suites failed → category 3 wins (regardless of count);
else any single suite with all-failed or >50%-and->5-failed → category 2;
else category 1.

### Phase 3.2 — Checkpoint 2 (after parse + classify)

Emit one of these depending on category, BEFORE viewing screenshots / source.

**Category 1:**
```
**Failing suite(s):** <suite> (<N> spec(s) failing of <total>)
**Failing specs:**
- `<spec_file>:<spec_line>` — <describe_path>
  Error: <error_message-trimmed-to-160-chars>
  Screenshot: [<screenshot-stem>](file://<absolute-screenshot-path>)
  Spec source: [<spec_file>](file://<absolute-spec-path>)

_Viewing screenshots and reading source…_
```

**Category 2:** name the suite, total specs vs failed, pick one representative
spec to anchor the analysis, link only that one. Note: "Whole suite is
broken — analyzing one representative spec to understand the root cause."

**Category 3:** list all suites with their failure counts, no per-spec links.
Note: "Every selenium-test job failed — likely a test-infra regression.
Diffing error messages across suites…"

### Phase 3.3 — Per-category analysis

#### Category 1: few failures (≤ 5 across all suites)

For EACH failure record:

1. Resolve the screenshot:
   ```bash
   find .gh-actions/<run_id>/<suite>/screenshots -maxdepth 1 -name '<screenshot_stem>*.png' \
     | head -1
   ```
2. **Read the screenshot via the `Read` tool** (multimodal — surfaces the
   visual state at failure time). Describe what is visible *relative to the
   assertion message*: the screenshot is most useful when it confirms or
   contradicts the failure text.
3. Cross-reference local source:
   - Compare `git rev-parse HEAD` (local) to the run's `head_sha`. If they
     differ, prepend a `> [!warning] Local checkout is at <sha>; run was at
     <sha>. Line numbers may be off.` note and use `grep -n` to relocate
     symbols if the line is off.
   - Read the spec at `spec_file` around `spec_line` (about ±10 lines) using
     `Read` with `offset`/`limit`.
   - For each non-spec stack frame whose file exists locally and looks
     load-bearing (e.g. a page object), read ±5 lines around the frame's
     line number.
4. Form a hypothesis: "test expects X; screenshot/log shows Y; likely
   cause is Z." Be specific — name the assertion, the visual evidence, and
   the suspected source-of-truth.

#### Category 2: single suite broken

Pick one representative failing spec (the first or alphabetically smallest
is fine). Run steps 1–4 above for that spec only. Then frame the conclusion
as a system-level hypothesis:

- App feature missing or renamed (e.g. selector no longer exists)
- Test fixture / setup broken (every `before` hook fails the same way)
- Suite-specific config (e.g. data not seeded, browser flag missing)

Do not deep-dive every failing spec; the user is hunting the common cause,
not 30 individual bugs.

#### Category 3: all suites broken

Skip screenshots entirely. Read each suite's `summary.json` and look for the
common pattern across `failures[].error_message`. Typical signals:

- Same error in every suite → test-infra regression (page object base, browser
  setup, app boot)
- Different errors but same first stack frame → broken shared helper
- All suites timed out → app server didn't start

Read at most ONE spec source plus its failing page-object frame as
evidence. Output is a short note, not a long report.

### Phase 3.4 — Final output

#### Category 1 only — write `report.md` per suite

Path: `.gh-actions/<run_id>/<suite>/report.md`. Structure:

```markdown
# Selenium failure report — <suite> @ <run_id>

**Run:** [<name> #<run_id>](<html_url>) · branch `<branch>` · commit `<sha-short>`
**Triggered:** <event> · **Conclusion:** failure
**Local checkout:** `<local-sha>` <(matches | DIVERGES from run)>
**Specs:** <passed>/<total> passed · <failed> failed

## Failure 1 — <describe_path>

**Test:** <test_path>

**Error:** <error_message>

**Screenshot:** ![<screenshot-stem>](screenshots/<screenshot-file>)

**Failing assertion:** `<spec_file>:<spec_line>`

```js
// (quote ±10 lines around spec_line)
```

**Stack:**
- `<fn>` — `<file>:<line>:<column>`
- ...

**Hypothesis:** <one paragraph: what the test wants, what the screenshot/log
show, what's likely broken>

---

## Failure 2 …
```

In chat: print a compact summary — failing suite, failing test, one-line
hypothesis, and the local file path of `report.md`.

#### Categories 2 and 3 — chat-only

No `report.md`. Print:

- Suite breakage map (`<suite>: <failed>/<total>`)
- Common-cause hypothesis (cat 2: feature/fixture; cat 3: infra)
- One next step (cat 2: open the representative spec; cat 3: check the most
  recent infra change in `testing/page_objects/` or app boot config)

## Output structure

Per-run cache directory inside the local repo:

```
.gh-actions/
  <run-id>/
    run.json
    <suite>/
      screenshots/
      logs/
      allure-report/   # not parsed; kept for the user
      report.md        # written only for ≤5-failure category
```

Always print Checkpoint output in chat. Write `report.md` only when the
breadth heuristic places the failure in category 1 (see Phase 3).

## References

- `references/workflow-conventions.md` — enonic CI workflow shape, log format markers, screenshot reference convention
- `scripts/resolve-run.sh` — input → run-id resolver
