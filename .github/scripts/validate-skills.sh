#!/usr/bin/env bash
set -euo pipefail

# Validate that all skill directories have a valid SKILL.md with required frontmatter.

PLUGIN=".claude-plugin/plugin.json"

if [ ! -f "$PLUGIN" ]; then
  echo "::error::$PLUGIN not found"
  exit 1
fi

# Resolve skills root from plugin.json (e.g. "./" -> ".")
skills_root=$(jq -r '.skills // empty' "$PLUGIN" | sed 's|/$||; s|^\.$||; s|^$|.|')

if [ -z "$skills_root" ] || [ "$skills_root" = "null" ]; then
  echo "::error::No 'skills' field in $PLUGIN"
  exit 1
fi

# Find skill directories containing SKILL.md (exclude hidden dirs)
skills=$(find "$skills_root" -maxdepth 2 -name SKILL.md -not -path '*/.*' \
  | sed 's|/SKILL.md$||; s|^\./||' | sort)

if [ -z "$skills" ]; then
  echo "::error::No skills found under '$skills_root'"
  exit 1
fi

errors=0

while IFS= read -r skill; do
  skill_file="$skill/SKILL.md"

  # Check required frontmatter: name
  name=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
  if [ -z "$name" ]; then
    echo "::error::$skill_file missing required 'name' frontmatter"
    errors=1
  elif [ "$name" != "$skill" ]; then
    echo "::error::$skill_file 'name: $name' does not match directory '$skill'"
    errors=1
  fi

  # Check required frontmatter: description
  desc=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep -E '^description:' | head -1)
  if [ -z "$desc" ]; then
    echo "::error::$skill_file missing required 'description' frontmatter"
    errors=1
  fi
done <<< "$skills"

if [ "$errors" -eq 1 ]; then
  exit 1
fi

echo "Validated $(echo "$skills" | wc -l | tr -d ' ') skill(s): $(echo "$skills" | tr '\n' ' ')"
