# AI Agents Skills

Enonic's collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and Codex agent skills following the [Agent Skills specification](https://agentskills.io/specification).

## Installation

### Claude Code

Add the marketplace and install the skills plugin:

```
/plugin marketplace add enonic/ai-agents-skills
/plugin install enonic@skills
```

This makes all skills available in your Claude Code sessions.

### Scopes

| Scope          | Command                                       | Use case                |
| -------------- | --------------------------------------------- | ----------------------- |
| User (default) | `/plugin install enonic@skills`                | Personal — all projects |
| Project        | `/plugin install enonic@skills --scope project` | Team — shared via Git   |
| Local          | `/plugin install enonic@skills --scope local`   | Project — gitignored    |

### Codex

Install directly from this GitHub repo into `~/.codex/skills`:

```bash
python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo enonic/ai-agents-skills \
  --path <skill-name>
```

No `.curated` folder is required for this repo; installs use explicit `--path` values.

## Skill Structure

Each skill is a top-level directory containing at minimum a `SKILL.md` file:

```
<skill-name>/
├── SKILL.md              # Required — frontmatter + instructions
├── agents/               # Optional — agent-specific configs (e.g. openai.yaml)
├── scripts/              # Optional — executable code
├── references/           # Optional — additional documentation
└── assets/               # Optional — templates, images, data files
```

The `SKILL.md` file contains YAML frontmatter (`name`, `description`) followed by Markdown instructions:

```markdown
---
name: example-skill
description: Does X when the user asks for Y.
---

## Steps

1. First, do this.
2. Then, do that.
```

See the full [Agent Skills specification](https://agentskills.io/specification) for all available frontmatter fields and conventions.

## Available Skills

| Skill | Description | Agent | Category |
| ----- | ----------- | ----- | -------- |
| [enonic-cli](enonic-cli/) | Reference for the Enonic CLI. Covers project, sandbox, data, and server commands. | Claude Code, Codex | CLI |

## Creating a Skill

1. Create a directory at the repo root matching the skill name
2. Add a `SKILL.md` with required `name` and `description` frontmatter
3. Write Markdown instructions in the body (keep under 500 lines)
4. Optionally add `scripts/`, `references/`, or `assets/` directories
5. Update the table above
6. Add the skill path to `.claude-plugin/marketplace.json` under `plugins[0].skills`

## Releasing

Use the `/skills-release` skill (local) to automate the full release workflow, or do it manually:

1. Ensure you're on `master` with a clean working tree
2. Update version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
3. Commit: `git commit -m "Release vX.Y.Z"`
4. Tag: `git tag vX.Y.Z`
5. Push: `git push && git push --tags`

## License

[MIT](LICENSE)
