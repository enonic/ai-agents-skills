# Enonic CI Workflow Conventions

The skill assumes the enonic-app convention for `.github/workflows/gradle.yml`:

```
publish_vars  →  build  →  selenium-test (matrix: suite)
```

`app-contentstudio` is the canonical example. Other apps (`app-inboundmedia`,
`app-contentstudio-templates`, etc.) follow the same shape with different
suite names.

## Job names

- `publish_vars` — release-tag detection. Failures here are unusual and
  should be reported verbatim; no special handling.
- `build` — runs `./gradlew build` (and `publish` on `master`/`6.x`).
  Uploads the JAR as artifact `contentstudio` (or app-specific name).
- `selenium-test (<suite>)` — matrix job per suite. Downloads the JAR,
  runs `./gradlew :testing:<suite>`, and on completion uploads
  `ui-test-report-<suite>` whether it passed or failed.

The `selenium-test` job's display name is `selenium-test (<suite>)`. The
suite name is the matrix key. Read `.github/workflows/<workflow>.yml` to
discover the active suite list — do not hardcode it.

## Build-failure log markers

Inside the build job's failed log:

- `FAILURE: Build failed with an exception.` — top of gradle's failure block
- `* What went wrong:` — followed by the human error
- `* Where:` — file/line of a script error (rare)
- `> Task :<module>:<task> FAILED` — the failing gradle task; useful for
  classifying compile/test/lint
- `error: ...` (lowercase) — typical Java/TS compile errors with a path

For typical compile breakage, the error block is small; print it verbatim.
For test failures, also include the failing test class.

## Selenium artifact contents

Each `ui-test-report-<suite>.zip` extracts to:

```
screenshots/   ~50 PNGs (cumulative — every screenshot taken, not just failures)
logs/          one .log per spec, named like <spec-name>.spec-0-N.log (large; ~1 MB)
allure-report/index.html  ~4 MB monolith — kept for the user, not parsed by the skill
```

## Selenium failure log markers

Inside `gh run view <id> --log-failed --job <selenium-job-id>`, failures are
marked with ANSI color codes. Strip ANSI before grepping. Useful patterns:

- `Error in "<spec> tests for ...GIVEN ... WHEN ... THEN ..."` — the failing
  test's full describe/it path
- `Error: <message> [Screenshot]: <screenshot-name>` — the assertion
  message plus the screenshot stem (no extension, no hash)
- `at <ClassName>.<method> (/home/runner/work/<repo>/<repo>/testing/<path>:<line>:<col>)`
  — stack frames; the first frame inside `testing/` is what to read
- `[chrome <version> linux #N-M] FAILED` — explicit failure marker per worker
- `Spec Files: N passed, M failed, T total` — final tally

## Screenshot resolution

The error references a screenshot by *stem* (e.g. `err_save_button_disabled`),
but the actual file in `screenshots/` has a numeric suffix
(`err_save_button_disabled386679.png`). Resolve with:

```
find .gh-actions/<run-id>/<suite>/screenshots -maxdepth 1 -name "<stem>*.png"
```

If multiple matches exist, use the most recently modified one (mtime in the
artifact reflects when the test took it).

## Source file resolution

Spec paths reported in stack traces are absolute Linux paths inside the
runner: `/home/runner/work/<repo>/<repo>/testing/specs/<area>/<spec>.spec.js`.
Strip `/home/runner/work/<repo>/<repo>/` to map to the local checkout's
relative path (`testing/specs/<area>/<spec>.spec.js`).

For non-spec frames (page objects), the relative path is similarly under
`testing/page_objects/...`.

## Breadth heuristic categories

| Category | Trigger | Behavior |
|---|---|---|
| 1. Few failures | total failing tests ≤ 5 across all failing suites | Full per-test analysis: error + screenshot view + spec source quote. Write `report.md` per suite. |
| 2. One full suite broken | a single suite has >50% specs failing OR all specs in one suite fail | Pick one representative spec; analyze it with screenshot + source. No `report.md`. Hypothesize: app feature missing, suite misconfigured, or shared fixture broken. |
| 3. All suites broken | every selenium-test matrix job failed | Skip screenshots. Diff the error messages across suites; the common failure usually points at test infra (page object base class, browser config, app boot). No `report.md`. |

When in doubt between 1 and 2, prefer 1 (more detail is cheaper than missing
detail).
