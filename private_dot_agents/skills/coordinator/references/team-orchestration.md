# Agent Team Orchestration

## Coordination Pattern

1. **DECOMPOSE**: Break task into independent units with clear file ownership
2. **WAVE PLAN**: Group units into waves — independent tasks in same wave, dependent tasks in later waves
3. **DISPATCH WAVE**: Spawn agents for current wave in parallel
4. **GATE**: Wait for all agents in wave to complete, verify results, resolve conflicts
5. **NEXT WAVE**: Feed outputs from completed wave into next wave's context
6. **VERIFY**: Run full test suite on final merged result

**When a plan manifest exists:** Use its `waves` array directly instead of manually grouping tasks. The manifest was designed by the planner with dependency analysis already done. Override only if runtime discoveries invalidate the grouping (e.g., unexpected file conflicts).

## Agent Spawn Rules

- Each agent gets explicit file ownership (which files it may modify)
- Spawn prompt includes ALL context — agents don't inherit conversation
- Follow the [dispatch prompt template](../../skill-conventions/references/dispatch-prompt-template.md) for prompt structure (Role, Context, Scope, Success Criteria, Return Format, Anti-patterns)
- Model selection:
  | Tier | Model | Use For |
  |------|-------|---------|
  | Heavy | Opus | Implementation, complex debugging, architecture |
  | Medium | Sonnet | Code review, analysis, planning |
  | Light | Haiku | Formatting, simple lookups, validation checks |
- Max 4 concurrent agents to avoid resource contention
- Name agents by role: `impl-auth`, `test-api`, `review-security`
- Include return format constraint in every spawn prompt (token budget + structure)

## Context Budget Management

- Estimate prompt size before spawning: system prompt + task context + expected file reads
- If task context exceeds ~30K tokens, split into sub-tasks or summarize inputs
- Return format constraints prevent output bloat from consuming coordinator context
- Monitor agent count — each active agent consumes coordinator context for tracking
- Briefing files stay on disk — never paste full briefing content into coordinator context. Include only task-id + 1-line summary + briefing path
- Re-read manifest from disk at wave boundaries to recover from context compaction

## Conflict Resolution

- If two agents need the same file, serialize those tasks
- Coordinator (main thread) owns integration and final verification
- When merging, run tests after each agent's changes are integrated
- For high-conflict scenarios, use git worktrees for isolated working directories (see using-git-worktrees skill)
