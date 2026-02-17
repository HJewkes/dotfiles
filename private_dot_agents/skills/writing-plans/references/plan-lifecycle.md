# Plan Directory Lifecycle

Documents the lifecycle of plan directories created by `writing-plans` and consumed by execution skills.

## Directory Structure

```
.claude/plans/YYYY-MM-DD-<feature-name>/
  plan.md              # Orchestration plan (human-readable, <200 lines)
  manifest.json        # Machine-readable task/wave metadata
  briefings/
    task-01.md         # Per-task agent briefing
    task-02.md
    ...
  summary.md           # Optional — written after execution, before cleanup
```

## Creation

The `writing-plans` skill creates the plan directory with:
1. `plan.md` — high-level orchestration: goal, architecture, dependency graph, wave plan, task summary table
2. `manifest.json` — machine-readable: task IDs, wave grouping, file ownership, dependency edges, status tracking
3. `briefings/task-NN.md` — one per task, following the [briefing template](./briefing-template.md)

Plan directories live in `.claude/plans/`, never in `docs/plans/`.

## During Execution

- The executing skill (subagent-driven-development, executing-plans, or coordinator) reads `plan.md` and `manifest.json` at startup
- Agents read their own briefing file from `briefings/` — briefing content is never pasted inline into spawn prompts
- The coordinator re-reads `manifest.json` from disk at wave boundaries to recover from context compaction
- Task statuses in `manifest.json` are updated as tasks complete
- No other files in the directory are modified during execution

## Cleanup

After all tasks complete and final review passes:
1. Optionally write `summary.md` with execution notes (what was learned, deviations from plan)
2. Delete the entire plan directory: `rm -rf .claude/plans/<plan-id>/`
3. If deletion fails (permissions, etc.), warn the user but do not block completion

## Stale Detection

A plan directory is considered stale if:
- `manifest.json` has `createdAt` older than 7 days, AND
- Not all tasks have `status: "completed"` (execution was abandoned)

The executing skill checks for stale directories at startup and warns the user:
- Offer to clean up stale directories before proceeding
- Never auto-delete without confirmation

## Backward Compatibility

Legacy monolithic plans in `docs/plans/*.md` remain supported. Detection logic:
- Path points to a `.md` file directly → old monolithic format
- Path points to a directory containing `manifest.json` → new plan directory format
- No path given → check `.claude/plans/` for most recent directory, fall back to `docs/plans/` for most recent `.md`

## Rules

- Plan directories are ephemeral — they exist only for the duration of execution
- Agents must not modify CLAUDE.md or any persistent configuration files
- The coordinator is the only entity that updates `manifest.json` status fields
- Briefing files are immutable once created — if a task needs revision, the coordinator rewrites the briefing
