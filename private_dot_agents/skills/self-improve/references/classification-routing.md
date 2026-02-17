# Learning Classification & Routing

## Routing Table

Route each learning to the **most focused destination possible.** Work down this priority list — stop at the first level that fits:

| Priority | Destination | When to use | Example |
|----------|-------------|-------------|---------|
| **1. Update existing skill** | Edit SKILL.md or prompt template | Learning improves/corrects an existing skill's behavior | "Agents place code between imports" → add to implementer-prompt.md checklist |
| **2. Create new skill** | `~/.claude/skills/` | Reusable multi-step technique that doesn't fit an existing skill | New debugging workflow for a specific framework |
| **3. Project CLAUDE.md** | Repo's `CLAUDE.md` | Stable project convention that all future sessions should know | "Vitest uses RN mock alias" → project architecture notes |
| **4. Auto memory** | `~/.claude/projects/*/memory/` | Ephemeral project state that changes between sessions | Branch status, test counts, in-progress work |
| **5. Global CLAUDE.md** | `~/CLAUDE.md` | Truly universal rule that applies to every project and no skill covers it | New workflow contract rule |

**The instinct to put things in ~/CLAUDE.md is usually wrong.** Ask: "Is there an existing skill or prompt template where the relevant agent would actually see this?" If yes, put it there — it's more focused and adds zero noise to other contexts.

## Draft Changes Format

For each learning, draft the specific change:
- **Project CLAUDE.md**: Specific section and content to add/modify
- **Global CLAUDE.md**: New rule or refinement with reasoning
- **New skill**: Follow superpowers:writing-skills format (YAML frontmatter, sections)
- **Skill update**: Show diff of proposed change
- **Auto memory**: Key-value style notes for MEMORY.md

## When NOT to Self-Improve

- Session was routine with no new insights
- Learning is too specific to one situation (not reusable)
- Pattern is already documented somewhere
- User didn't ask and session wasn't notably productive
