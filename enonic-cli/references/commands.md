# Enonic CLI — Full Command Reference

> Exhaustive flag tables for every command. Loaded on demand from `SKILL.md`.

## Standard Auth Flags

These flags apply to all **remote** commands (commands that talk to a running XP instance).

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--auth` | `-a` | Basic auth `user:password` (deprecated for XP 7.15+) | — |
| `--cred-file` | — | Service account key file (JSON, XP 7.15+) | — |
| `--client-key` | — | Private key for mTLS (must pair with `--client-cert`) | — |
| `--client-cert` | — | Client certificate for mTLS (must pair with `--client-key`) | — |

---

## Project Commands

### enonic project create

Create a new Enonic project from a starter.

```
enonic project create [name] [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--name` | `-n` | Project name (overrides positional arg) | — |
| `--repo` | `-r` | Starter repo (`<enonic>`, `<org>/<repo>`, or full URL) | — |
| `--branch` | `-b` | Starter repo branch | `master` |
| `--checkout` | `-c` | Specific commit hash (excludes `--branch`) | — |
| `--dest` | `-d` | Destination folder | last word of project name |
| `--ver` | `-v` | Version number | `1.0.0-SNAPSHOT` |
| `--sandbox` | `-s` | Link to existing sandbox | — |
| `--prod` | — | Run XP in non-development mode | `false` |
| `--skip-start` | — | Don't start sandbox after creation | `false` |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic project sandbox

Set or change the project's default sandbox.

```
enonic project sandbox [name] [-f]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic project build

Build project via Gradle.

```
enonic project build [-f]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--force` | `-f` | Non-interactive mode (uses system Java) | `false` |

### enonic project clean

Clean build artifacts (alias for `gradlew clean`).

```
enonic project clean [-f]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic project test

Run tests via Gradle.

```
enonic project test [-f]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic project deploy

Build and deploy project to associated sandbox.

```
enonic project deploy [sandbox-name] [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--prod` | — | Non-development mode | `false` |
| `--debug` | — | Enable debug on port 5005 | `false` |
| `--continuous` | `-c` | Watch for changes, redeploy continuously | `false` |
| `--skip-start` | — | Don't start sandbox | `false` |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic project install

Build and install project to a running XP instance via management API.

```
enonic project install [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic project shell

Open shell with project's `JAVA_HOME` and `XP_HOME` set.

```
enonic project shell
```

No additional flags. Exit with `quit`.

### enonic project gradle

Run arbitrary Gradle tasks with project context.

```
enonic project gradle [tasks / flags ...]
```

Everything after `gradle` is forwarded to `gradlew`.

### enonic project env

Export `JAVA_HOME` and `XP_HOME` for the current shell.

```
eval $(enonic project env)
```

Not available on Windows.

---

## Sandbox Commands

### enonic sandbox create

Create a new local XP sandbox.

```
enonic sandbox create [name] [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--template` | `-t` | Use specific template | — |
| `--skip-template` | — | No apps preinstalled | `false` |
| `--version` | `-v` | XP distribution version | latest stable |
| `--all` | `-a` | Include pre-release versions in selection | `false` |
| `--prod` | — | Non-development mode | `false` |
| `--skip-start` | — | Don't start after creation | `false` |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic sandbox list

List all sandboxes. Alias: `enonic sandbox ls`.

```
enonic sandbox list
```

No additional flags. Running sandbox is marked with `*`.

### enonic sandbox start

Start a sandbox (only one can run at a time).

```
enonic sandbox start [name] [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--prod` | — | Non-development mode | `false` |
| `--debug` | — | Enable debug on port 5005 | `false` |
| `--detach` | `-d` | Run in background | `false` |
| `--http.port` | — | Custom HTTP port | `8080` |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic sandbox stop

Stop the running sandbox.

```
enonic sandbox stop
```

No additional flags.

### enonic sandbox upgrade

Upgrade sandbox XP distribution version. Downgrades are not allowed.

```
enonic sandbox upgrade [name] [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--version` | `-v` | Target distribution version | — |
| `--all` | `-a` | Show all available versions | `false` |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic sandbox delete

Delete sandbox and all its data.

```
enonic sandbox delete [name] [-f]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic sandbox copy

Clone an existing sandbox to a new one.

```
enonic sandbox copy [source] [target] [-f]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--force` | `-f` | Non-interactive mode | `false` |

---

## Snapshot Commands

### enonic snapshot create

Create a snapshot of one or all repositories.

```
enonic snapshot create [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--repo` | `-r` | Repository name (omit for all) | — |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic snapshot list

List all snapshots. Alias: `enonic snapshot ls`.

```
enonic snapshot ls [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic snapshot restore

Restore a snapshot.

```
enonic snapshot restore [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--snap` | — | Snapshot name | — |
| `--repo` | — | Target repository | — |
| `--clean` | — | Delete indices before restoring | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic snapshot delete

Delete snapshots by name or date.

```
enonic snapshot delete [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--snap` | — | Snapshot name | — |
| `--before` | `-b` | Delete before date (format: `2 Jan 06`) | — |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## Dump Commands

### enonic dump create

Export all repositories to a dump.

```
enonic dump create [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--name` | `-d` | Dump name | — |
| `--skip-versions` | — | Don't include version history | `false` |
| `--max-version-age` | — | Max age of versions in days | — |
| `--max-versions` | — | Max number of versions per node | — |
| `--archive` | — | Create as ZIP archive | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic dump upgrade

Upgrade dump format for newer XP version.

```
enonic dump upgrade [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--name` | `-d` | Dump name | — |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

Output name: `<dump-name>_upgraded_<version>`.

### enonic dump list

List all dumps. Alias: `enonic dump ls`.

```
enonic dump ls [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic dump load

Import a dump. Deletes existing repos before loading.

```
enonic dump load [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--name` | `-d` | Dump name | — |
| `--upgrade` | — | Automatically upgrade dump before loading | `false` |
| `--archive` | — | Load from ZIP archive | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## Export / Import

### enonic export

Export repository branch data to the exports directory.

```
enonic export [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--target` | `-t` | Export name | — |
| `--path` | — | Source path (`repo:branch:path`) | — |
| `--skip-ids` | — | Don't export node IDs | `false` |
| `--skip-versions` | — | Don't export version history | `false` |
| `--dry` | — | Dry run — show what would be exported | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic import

Import data from the exports directory.

```
enonic import [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--target` | `-t` | Export name to import from | — |
| `--path` | — | Target path (`repo:branch:path`) | — |
| `--xsl-source` | — | XSL transformation file | — |
| `--xsl-param` | — | XSL parameters (`key=value`) | — |
| `--skip-ids` | — | Generate new node IDs | `false` |
| `--skip-permissions` | — | Use target node permissions | `false` |
| `--dry` | — | Dry run | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## App Commands

### enonic app install

Install an application on all cluster nodes.

```
enonic app install [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--url` | — | URL to application JAR | — |
| `--file` | — | Local path to JAR (takes precedence over `--url`) | — |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic app start

Start an installed application.

```
enonic app start <app-key> [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic app stop

Stop a running application.

```
enonic app stop <app-key> [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## Repository Commands

### enonic repo reindex

Rebuild search indices for a repository.

```
enonic repo reindex [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--branches` | `-b` | Comma-separated branch list | — |
| `--repo` | `-r` | Repository name | — |
| `--initialize` | `-i` | Recreate index data (delete + reindex) | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic repo readonly

Toggle read-only mode.

```
enonic repo readonly <true|false> [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--repo` | `-r` | Repository name (omit for all repos) | — |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic repo replicas

Set number of replicas for the cluster.

```
enonic repo replicas <1-99> [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic repo list

List all repositories. Alias: `enonic repo ls`.

```
enonic repo list [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## CMS Commands

### enonic cms reprocess

Reprocess content metadata (typically after migration).

```
enonic cms reprocess [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--path` | — | Content path (`branch:path`) | — |
| `--skip-children` | — | Don't process descendants | `false` |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## System Commands

### enonic system info

Show XP instance info (version, mode, build hash, branch, timestamp).

```
enonic system info
```

No auth required — uses the info port (2609).

---

## Audit Log Commands

### enonic auditlog cleanup

Remove audit log records older than threshold.

```
enonic auditlog cleanup [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--age` | — | ISO-8601 duration (`P30D`, `P1DT12H`) | — |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## Vacuum

### enonic vacuum

Purge old node versions and optionally unused blobs.

```
enonic vacuum [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--blob` | `-b` | Also remove unused binary blobs | `false` |
| `--threshold` | `-t` | Age threshold (ISO-8601 duration) | `P21D` (21 days) |
| + Standard auth flags | | | |
| `--force` | `-f` | Non-interactive mode | `false` |

---

## Cloud Commands

### enonic cloud login

Login to Enonic Cloud via browser-based OAuth.

```
enonic cloud login [-qr]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `-qr` | — | Display QR code for mobile auth | `false` |

**Note:** This is interactive (browser-based). `-f` does not apply.

### enonic cloud logout

Log out from Enonic Cloud.

```
enonic cloud logout
```

No additional flags.

### enonic cloud app install

Install project JAR to Enonic Cloud.

```
enonic cloud app install [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `-j` | — | JAR file path | `./build/libs/*.jar` |
| `-t` | — | Upload timeout in seconds | `300` |
| `-y` | — | Skip confirmation prompt | `false` |

---

## Global Commands

### enonic create

Simplified project creation with defaults.

```
enonic create [project-name] [flags]
```

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--repo` | `-r` | Starter repo path | — |
| `--sandbox` | `-s` | Link to sandbox | — |
| `--prod` | — | Non-development mode | `false` |
| `--skip-start` | — | Don't start sandbox | `false` |
| `--force` | `-f` | Non-interactive mode | `false` |

### enonic dev

Start hot-reload development mode.

```
enonic dev
```

Starts sandbox in detached mode, deploys app, watches for changes. Exit with Ctrl-C.

### enonic latest

Show the latest available CLI version.

```
enonic latest
```

### enonic upgrade

Upgrade CLI to the latest version.

```
enonic upgrade
```

### enonic uninstall

Remove CLI from the system.

```
enonic uninstall
```
