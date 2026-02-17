---
name: skill-conventions
description: Documents the canonical file layout for skills and agents — where they live, how they're discovered, and how to create new ones
---

# Skill & Agent Conventions

## Directory Structure

**Canonical location** (source of truth):
- Skills: `~/.agents/skills/<skill-name>/`
- Agents: `~/.agents/agents/<agent-name>.md`

**Discovery location** (symlinks only — never real files):
- Skills: `~/.claude/skills/<skill-name>` → `../../.agents/skills/<skill-name>`
- Agents: `~/.claude/agents/<agent-name>.md` → `../../.agents/agents/<agent-name>.md`

Claude Code discovers skills/agents via `~/.claude/`. The symlinks point back to `~/.agents/` where the real content lives. This keeps one canonical location while supporting tool discovery.

## Management

All files in `~/.agents/` are managed by **chezmoi**. The chezmoi source is at `~/.local/share/chezmoi/private_dot_agents/`.

Use `~/.agents/bin/skill-manager` for all skill lifecycle operations. It handles chezmoi source paths, symlink creation, and convention enforcement automatically.

To sync changes across machines: edit in chezmoi source → `chezmoi apply` → push the chezmoi repo.

## Creating a New Skill

```bash
skill-manager create <skill-name>
# Edit the SKILL.md at the printed path
# Add references/ files as needed
```

With a bin script: `skill-manager create <skill-name> --bin <script-name>`

## Installing a Skill from GitHub

```bash
skill-manager install <owner/repo>           # auto-detect skills in repo
skill-manager install <owner/repo> skills/x  # specific skill path
```

## Removing a Skill

```bash
skill-manager remove <skill-name>
```

## Validating & Syncing

```bash
skill-manager validate              # check all skills against conventions
skill-manager validate <skill-name> # check one skill
skill-manager sync                  # fix missing/orphaned symlinks
```

## Creating a New Agent

```bash
# 1. Create in chezmoi source
# Write ~/.local/share/chezmoi/private_dot_agents/agents/<agent-name>.md

# 2. Add symlink for Claude
echo -n "../../.agents/agents/<agent-name>.md" > ~/.local/share/chezmoi/private_dot_claude/agents/symlink_<agent-name>.md

# 3. Apply
chezmoi apply
```

## Skill Directory Layout

```
~/.agents/skills/<skill-name>/
  SKILL.md              # Required — frontmatter + skill content
  references/           # Optional — deep-dive docs, examples, templates
    *.md
```

## Naming Conventions

- **Skills**: lowercase kebab-case directories (`dispatching-parallel-agents`, `test-driven-development`)
- **Agents**: lowercase kebab-case files with `.md` extension (`security-reviewer.md`)
- **SKILL.md**: always uppercase filename, contains YAML frontmatter with `name` and `description`

## Agent Prompts

Agent prompts (system prompts for Task tool agents) live as reference files inside skills:

```
~/.agents/skills/<skill-name>/
  SKILL.md                       # Skill entry point
  references/
    <agent-name>.md              # Agent system prompt
```

**Principles:**
- The skill is the unit of composition — workflows reference skills, not agent files directly
- One canonical location per agent prompt — other skills cross-reference, never duplicate
- A skill wrapping a single agent prompt is the correct pattern, not a "thin wrapper"

## Migrating a Plugin to a Skill

1. Extract the plugin's command file(s) as reference material in the new skill
2. Move plugin frontmatter constraints (`allowed-tools`, etc.) into documented constraints in the prompt body
3. Delete the plugin install manifest from `~/.claude/plugins/.install-manifests/`
4. Create the skill + symlink per standard conventions

## Shell Scripts (bin/)

Scripts extract deterministic command sequences from skills into standalone executables.
Skills remain the "when and why"; scripts handle the "how".

**Canonical locations** (real files):
- Skill-specific: `~/.agents/skills/<skill-name>/bin/<script-name>`
- Shared utilities: `~/.agents/shared/bin/<script-name>`

**Discovery** (symlinks): `~/.agents/bin/<script-name>` — flat directory of symlinks pointing to canonical locations. All skill references use this path.

In chezmoi source:
- Real files use `executable_` prefix: `private_dot_agents/skills/<skill>/bin/executable_<name>`
- Symlinks use `symlink_` prefix: `private_dot_agents/bin/symlink_<name>`

**Conventions:**
- `#!/usr/bin/env bash`, POSIX-compatible
- Every script supports `--help`
- Output to stdout, progress/errors to stderr
- Exit codes: 0 success, 1 failure, 2 partial/warning
- Scripts may call sibling scripts via `~/.agents/bin/<name>`
- No interactive prompts — skills handle interaction, scripts are non-interactive

## Rules

1. **Never** put real files in `~/.claude/skills/` or `~/.claude/agents/` — symlinks only
2. All edits go through chezmoi source (`~/.local/share/chezmoi/private_dot_agents/`) then `chezmoi apply`
3. When deleting a skill, also remove its entry from `skill-lock.json` and its symlink files from `private_dot_claude/skills/` and `private_dot_cursor/skills/`
4. See the `writing-skills` skill for content guidelines, testing methodology, and quality standards
