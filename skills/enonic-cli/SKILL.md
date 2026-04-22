---
name: enonic-cli
description: >
  Reference for the Enonic CLI (enonic command). Covers all commands including
  project creation, sandbox management, data export/import, snapshots, dumps,
  application lifecycle, cloud deployment, and server administration. Use when
  the user needs to run enonic commands, manage Enonic XP instances, deploy
  applications, or perform data operations with the Enonic CLI tool.
license: MIT
compatibility: Claude Code, Codex
allowed-tools: Bash(enonic:*) Read
metadata:
  author: enonic
  cli-version: "3.4.0"
---

## Critical Rules

1. **Always use `-f` (force) flag.** Every `enonic` command that accepts `-f` must include it. This prevents interactive prompts that block automation. The only exception is `enonic cloud login` (browser-based OAuth).

2. **Local vs remote commands:**
   - **Local commands** run against files on disk — no auth needed: `project *`, `sandbox *`, `create`, `dev`, `latest`, `upgrade`, `uninstall`.
   - **Remote commands** talk to a running XP instance via management API — auth required: `snapshot *`, `dump *`, `export`, `import`, `app *`, `repo *`, `cms *`, `auditlog *`, `vacuum`.
   - `system info` uses the info port (2609) — no auth.
   - `project install` is a local build + remote install hybrid — auth required.

3. **Management port is 4848, not 8080.** The CLI talks to the management API on port 4848. Port 8080 is the web/content API. Never use 8080 for CLI remote operations.

4. **`.enonic` file** — `project create` writes a `.enonic` file in the project root linking it to a sandbox. Commands like `project deploy` and `dev` use this automatically.

5. **Command aliases:**
   - `enonic create` = simplified `enonic project create`
   - `enonic dev` = `enonic project dev`
   - `sandbox ls` = `sandbox list`
   - `dump ls` = `dump list`
   - `snapshot ls` = `snapshot list`
   - `repo ls` = `repo list`

## Command Syntax

```
enonic <group> <action> [positional-args] [flags]
```

Groups: `project`, `sandbox`, `snapshot`, `dump`, `app`, `repo`, `cms`, `system`, `auditlog`, `cloud`.
Standalone: `create`, `dev`, `export`, `import`, `vacuum`, `latest`, `upgrade`, `uninstall`.

## Auth Flags (Remote Commands)

| Method | Flags | When to use |
|--------|-------|-------------|
| Basic auth | `-a user:password` | XP < 7.15 or quick local testing |
| Service account key | `--cred-file path/to/key.json` | XP 7.15+ / CI/CD (preferred) |
| Mutual TLS | `--client-cert cert.pem --client-key key.pem` | Zero-trust environments |

Priority: flags → environment variables → no auth. See `references/auth-and-env.md` for details.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ENONIC_CLI_REMOTE_URL` | `localhost:4848` | Management API endpoint |
| `ENONIC_CLI_REMOTE_USER` | — | Basic auth user |
| `ENONIC_CLI_REMOTE_PASS` | — | Basic auth password |
| `ENONIC_CLI_CRED_FILE` | — | Service account key file path |
| `ENONIC_CLI_CLIENT_KEY` | — | mTLS private key path |
| `ENONIC_CLI_CLIENT_CERT` | — | mTLS client cert path |
| `ENONIC_CLI_HTTP_PROXY` | — | HTTP proxy URL |
| `ENONIC_CLI_HOME_PATH` | `~/.enonic` | CLI home directory |

## Project Commands

All run from the project root directory.

| Command | Description | Key flags |
|---------|-------------|-----------|
| `project create [name]` | Create project from starter | `-r <repo>`, `-s <sandbox>`, `-v <version>`, `--prod`, `--skip-start` |
| `project sandbox [name]` | Set project's default sandbox | — |
| `project build` | Build via Gradle | — |
| `project clean` | Clean build artifacts | — |
| `project test` | Run tests via Gradle | — |
| `project deploy [sandbox]` | Build + deploy to sandbox | `--prod`, `--debug`, `-c` (continuous), `--skip-start` |
| `project install` | Build + install to running XP | Auth flags required |
| `project shell` | Open shell with XP env vars set | No `-f` needed |
| `project gradle [args]` | Run arbitrary Gradle tasks | Forwards all args to gradlew |
| `project env` | Export JAVA_HOME + XP_HOME | Use with `eval $(...)` |

`enonic create [name]` is a shorthand for `project create` with sensible defaults.
`enonic dev` starts hot-reload mode (sandbox detached, watches source files, exit with Ctrl-C).

## Sandbox Commands

| Command | Description | Key flags |
|---------|-------------|-----------|
| `sandbox create [name]` | Create new sandbox | `-v <version>`, `-t <template>`, `--skip-template`, `--prod`, `--skip-start` |
| `sandbox list` | List all sandboxes | — |
| `sandbox start [name]` | Start sandbox | `--prod`, `--debug`, `-d` (detach), `--http.port <port>` |
| `sandbox stop` | Stop running sandbox | — |
| `sandbox upgrade [name]` | Upgrade XP version (no downgrade) | `-v <version>` |
| `sandbox delete [name]` | Delete sandbox and data | — |
| `sandbox copy [src] [dst]` | Clone sandbox | — |

Only one sandbox can run at a time. Default start mode is development.

## Data Commands

### Export / Import

```
enonic export -t <name> --path <repo:branch:path> -f
enonic import -t <name> --path <repo:branch:path> -f
```

**Path format:** `repo:branch:path` — e.g. `cms-repo:draft:/content/my-site`

| Command | Key flags | Notes |
|---------|-----------|-------|
| `export` | `-t <name>`, `--path`, `--skip-ids`, `--skip-versions`, `--dry` | Auth required. Output in `$XP_HOME/data/export/` |
| `import` | `-t <name>`, `--path`, `--xsl-source`, `--xsl-param key=val`, `--skip-ids`, `--skip-permissions`, `--dry` | Auth required |

### Snapshots

| Command | Key flags | Notes |
|---------|-----------|-------|
| `snapshot create` | `-r <repo>` (omit for all) | Online operation, no downtime |
| `snapshot ls` | — | Shows all snapshots with status |
| `snapshot restore` | `--snap <name>`, `--repo <name>`, `--clean` | `--clean` deletes indices first |
| `snapshot delete` | `--snap <name>`, `-b <date>` | Date format: `2 Jan 06` |

All snapshot commands require auth.

### Dumps

| Command | Key flags | Notes |
|---------|-----------|-------|
| `dump create` | `-d <name>`, `--skip-versions`, `--max-version-age <days>`, `--max-versions <n>`, `--archive` | Full system export |
| `dump upgrade` | `-d <name>` | Output: `<name>_upgraded_<version>` |
| `dump ls` | — | List all dumps |
| `dump load` | `-d <name>`, `--upgrade`, `--archive` | **Deletes existing repos** before loading |

All dump commands require auth. Dumps are stored in `$XP_HOME/data/dump/`.

**Warning:** `dump load` replaces all existing repositories. Always create a backup first.

## Server Commands

### App

| Command | Description | Key flags |
|---------|-------------|-----------|
| `app install` | Install app on all nodes | `--url <address>` or `--file <path>` (`--file` takes precedence) |
| `app start <key>` | Start installed app | App key, e.g. `com.enonic.myapp` |
| `app stop <key>` | Stop running app | App key |

### Repository

| Command | Description | Key flags |
|---------|-------------|-----------|
| `repo reindex` | Rebuild search indices | `-r <repo>`, `-b <branches>` (comma-separated), `-i` (recreate indices) |
| `repo readonly <bool>` | Toggle write protection | `-r <repo>` (omit for all) |
| `repo replicas <1-99>` | Set cluster replica count | — |
| `repo list` | List repositories | — |

### CMS

| Command | Description | Key flags |
|---------|-------------|-----------|
| `cms reprocess` | Reprocess content metadata | `--path <branch:path>`, `--skip-children` |

Typically used after content migration. Path format is `branch:path` (no repo prefix).

### System

| Command | Description | Notes |
|---------|-------------|-------|
| `system info` | Show XP instance info | Uses info port 2609, no auth needed |

### Audit Log

| Command | Description | Key flags |
|---------|-------------|-----------|
| `auditlog cleanup` | Remove old audit records | `--age <ISO-8601>` (e.g. `P30D`, `P1DT12H`) |

### Vacuum

```
enonic vacuum [-b] [-t <ISO-8601-duration>] -f
```

Purges node versions older than threshold (default `P21D` = 21 days). `-b` also removes unused binary blobs. Incompatible with snapshots older than the threshold.

## Cloud Commands

| Command | Description | Notes |
|---------|-------------|-------|
| `cloud login` | Login via browser OAuth | **Interactive — no `-f` flag.** Supports `-qr` for mobile. |
| `cloud logout` | Log out | — |
| `cloud app install` | Install JAR to cloud | `-j <jar-path>` (default: `./build/libs/*.jar`), `-t <timeout>`, `-y` (skip confirm) |

**Cloud login is the only interactive command.** It opens a browser for OAuth. Cannot be automated.

## CLI Maintenance

| Command | Description |
|---------|-------------|
| `enonic latest` | Show latest available CLI version |
| `enonic upgrade` | Upgrade CLI to latest version |
| `enonic uninstall` | Remove CLI from system |

## File Locations

| Item | Path |
|------|------|
| CLI home | `~/.enonic/` |
| Sandboxes | `~/.enonic/sandboxes/<name>/` |
| Cloud auth | `~/.enonic/cloud/` |
| Dumps | `$XP_HOME/data/dump/` |
| Exports | `$XP_HOME/data/export/` |
| Snapshots | `$XP_HOME/snapshots/` |
| Project config | `<project-root>/.enonic` |

## Common Patterns

```bash
# Create project with specific starter and sandbox
enonic project create my-app -r starter-vanilla -s my-sandbox -f

# Build and install to remote server
ENONIC_CLI_REMOTE_URL="server:4848" enonic project install -a su:password -f

# Export content tree
enonic export -t site-backup --path cms-repo:draft:/content/my-site -a su:password -f

# Full backup with dump
enonic dump create -d nightly --skip-versions -a su:password -f

# Reindex repository after schema changes
enonic repo reindex -r cms-repo -b draft,master -i -a su:password -f

# Vacuum + audit log cleanup (maintenance)
enonic vacuum -b -t P30D -a su:password -f
enonic auditlog cleanup --age P90D -a su:password -f
```

## Reference Files

| File | Content |
|------|---------|
| `references/commands.md` | Full flag tables for every command |
| `references/auth-and-env.md` | Auth methods, env vars, ports, CI/CD patterns |
| `references/workflows.md` | Multi-step recipes for common operations |
