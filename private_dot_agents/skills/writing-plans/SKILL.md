---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write implementation plans as a **plan directory** — a tight orchestration plan for the coordinator plus per-task briefing files for agents. Assume agents have zero codebase context. Document everything they need: which files to touch, complete code, testing, validation criteria. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `.claude/plans/YYYY-MM-DD-<feature-name>/`

See [references/plan-lifecycle.md](references/plan-lifecycle.md) for directory lifecycle (creation, execution, cleanup, stale detection).

## Plan Directory Structure

```
.claude/plans/YYYY-MM-DD-<feature-name>/
  plan.md              # Orchestration plan (<200 lines)
  manifest.json        # Machine-readable task/wave metadata
  briefings/
    task-01.md         # Per-task agent briefing
    task-02.md
    ...
```

## Orchestration Plan Format (plan.md)

The orchestration plan is what the coordinator reads. It contains NO inline code and NO step-by-step instructions — those live in briefing files. Target: under 200 lines.

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Dependency Graph

[Which tasks depend on which — text or ascii diagram]

## Wave Plan

- **Wave 1** (parallel): Task 1, Task 2
- **Wave 2** (depends on Wave 1): Task 3

## Tasks

| # | Name | Files | Wave | Depends On |
|---|------|-------|------|------------|
| 1 | [name] | `src/a.ts`, `tests/a.test.ts` | 1 | — |
| 2 | [name] | `src/b.ts` | 1 | — |
| 3 | [name] | `src/c.ts` | 2 | Task 1 |

Detailed task specs: `./briefings/task-NN.md`
```

## Manifest Format (manifest.json)

Machine-readable metadata the coordinator reads at wave boundaries to recover from context compaction.

```json
{
  "planId": "YYYY-MM-DD-feature-name",
  "createdAt": "ISO-8601",
  "goal": "One sentence",
  "tasks": [
    {
      "id": "task-01",
      "name": "Component Name",
      "briefing": "briefings/task-01.md",
      "wave": 1,
      "dependsOn": [],
      "fileOwnership": ["src/path/a.ts", "tests/path/a.test.ts"],
      "status": "pending"
    }
  ],
  "waves": [
    { "id": 1, "tasks": ["task-01", "task-02"], "gate": "tests pass + lint clean" },
    { "id": 2, "tasks": ["task-03"], "gate": "tests pass + lint clean" }
  ]
}
```

## Briefing File Format (briefings/task-NN.md)

Each task gets its own briefing file — the agent's complete, self-contained specification. Follow the canonical template at [references/briefing-template.md](references/briefing-template.md).

### Bite-Sized Task Granularity

**Each step within a briefing is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

### Authoring Rules

- Exact file paths always
- Complete code in briefing (not "add validation")
- Exact commands with expected output
- File ownership: explicit allowlist per task
- Success criteria: every criterion maps to a runnable command
- Anti-patterns: include universal 3 (file ownership, no CLAUDE.md edits, no scope creep) + task-specific
- Target: under 50 lines of meaningful content per briefing (excluding code blocks)

## Execution Handoff

After saving the plan directory, offer execution choice:

**"Plan complete and saved to `.claude/plans/<plan-id>/`. Structure: `plan.md` (orchestration), `manifest.json` (metadata), `briefings/task-NN.md` (per-task specs). Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Stay in this session
- Fresh subagent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session in worktree
- **REQUIRED SUB-SKILL:** New session uses superpowers:executing-plans
