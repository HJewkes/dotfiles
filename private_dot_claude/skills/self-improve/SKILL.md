---
name: self-improve
description: Use when a session produced reusable insights, when the user says "learn from this", "remember this", or "improve yourself", or after completing a complex task where patterns were discovered
---

# Self-Improve

## Overview

Session learning loop that captures reusable knowledge and routes it to the right place: project memory, global CLAUDE.md, or a new skill. Builds on superpowers:writing-skills methodology for skill creation.

## Process

### 1. Identify Learnings
After a productive session, review what was learned:
- Patterns that worked well
- Mistakes that were caught and corrected
- Techniques that could be reused
- Debugging insights
- Tool usage patterns
- Project-specific conventions discovered

### 2. Classify Each Learning

| Type | Destination | Criteria |
|------|-------------|----------|
| **Project pattern** | Project CLAUDE.md or memory | Specific to one project's conventions, architecture, or toolchain |
| **Global standard** | ~/CLAUDE.md | Applies across all projects, language-agnostic workflow improvement |
| **Reusable technique** | New skill in ~/.claude/skills/ | Technique others would benefit from, not project-specific |
| **Existing skill update** | Edit existing SKILL.md | Improves or corrects an existing skill |
| **Auto memory** | ~/.claude/projects/*/memory/ | Session-specific insights for this project context |

### 3. Draft Changes
For each learning, draft the specific change:
- **Project CLAUDE.md**: Specific section and content to add/modify
- **Global CLAUDE.md**: New rule or refinement with reasoning
- **New skill**: Follow superpowers:writing-skills format (YAML frontmatter, sections)
- **Skill update**: Show diff of proposed change
- **Auto memory**: Key-value style notes for MEMORY.md

### 4. Confirm with User
Present all proposed changes grouped by destination. For each:
- What was learned (1 sentence)
- Where it goes and why
- Exact content to add/modify

**Never auto-apply changes.** Always get explicit approval.

### 5. Apply Approved Changes
Write changes to the approved destinations. For new skills, note that full TDD testing (per superpowers:writing-skills) should happen in a dedicated session.

## When NOT to Self-Improve
- Session was routine with no new insights
- Learning is too specific to one situation (not reusable)
- Pattern is already documented somewhere
- User didn't ask and session wasn't notably productive

## Common Mistakes
- Auto-applying changes without user confirmation
- Saving session-specific context as permanent knowledge
- Creating skills for one-off solutions
- Duplicating what's already in CLAUDE.md or existing skills
