---
name: writing-skills
description: Use when creating new skills, editing existing skills, or verifying skills work before deployment
---

# Writing Skills

## Overview

**Writing skills IS Test-Driven Development applied to process documentation.**

**Skills are managed by chezmoi via `skill-manager`.** To scaffold a new skill: `skill-manager create <name>`. It handles chezmoi source paths, symlinks, and convention enforcement automatically. See `skill-conventions` for the full directory layout.

You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes).

**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development before using this skill.

**Official guidance:** For Anthropic's official skill authoring best practices, see anthropic-best-practices.md.

## What is a Skill?

A **skill** is a reference guide for proven techniques, patterns, or tools.

**Skills are:** Reusable techniques, patterns, tools, reference guides
**Skills are NOT:** Narratives about how you solved a problem once

## Skill Types

- **Technique** — Concrete method with steps (condition-based-waiting, root-cause-tracing)
- **Pattern** — Way of thinking about problems (flatten-with-flags, test-invariants)
- **Reference** — API docs, syntax guides, tool documentation

## When to Create or Optimize a Skill

**Create when:** technique wasn't obvious, you'd reference it again, pattern applies broadly, others benefit.
**Optimize when:** SKILL.md exceeds ~500 words, or a plugin's always-on agent descriptions could be converted to on-demand skill wrappers.
**Don't create for:** one-off solutions, standard practices, project-specific conventions (use CLAUDE.md), mechanical constraints (automate instead).

## The Iron Law (Same as TDD)

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

This applies to NEW skills AND EDITS. Write skill before testing? Delete it. Start over.

**No exceptions:** Not for "simple additions", not for "just adding a section", not for "documentation updates". Delete means delete.

## RED-GREEN-REFACTOR for Skills

1. **RED:** Run pressure scenario WITHOUT skill. Document baseline rationalizations verbatim.
2. **GREEN:** Write minimal skill addressing those specific failures. Verify agents now comply.
3. **REFACTOR:** Agent found new rationalization? Add counter. Re-test until bulletproof.

**Testing methodology:** See @testing-skills-with-subagents.md for pressure scenarios, pressure types, and plugging holes.

## The Bottom Line

Same Iron Law: No skill without failing test first.
Same cycle: RED (baseline) -> GREEN (write skill) -> REFACTOR (close loopholes).

## Deep-Dive References

| Reference | Content |
|-----------|---------|
| [references/skill-structure.md](references/skill-structure.md) | SKILL.md structure, directory layout, file organization, code examples, flowcharts |
| [references/claude-search-optimization.md](references/claude-search-optimization.md) | CSO techniques, keyword coverage, token efficiency, cross-referencing |
| [references/testing-methodology.md](references/testing-methodology.md) | Testing all skill types, rationalizations table, bulletproofing, detailed RED-GREEN-REFACTOR |
| [references/skill-creation-checklist.md](references/skill-creation-checklist.md) | Complete checklist, quality checks, deployment steps |
| [references/anti-patterns.md](references/anti-patterns.md) | Anti-patterns with examples |
| [references/context-optimization-patterns.md](references/context-optimization-patterns.md) | Extracting oversized skills, converting plugins to wrapper skills |
