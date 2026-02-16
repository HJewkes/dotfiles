---
name: coordinator
description: Use when the user says "vm", "voice mode", "team", "coordinate", or needs to orchestrate multiple agents working on related tasks in parallel
---

# Coordinator

## Overview

Manages two concerns: **output mode switching** (voice vs text) and **agent team orchestration** for parallel task execution.

## Voice/Text Mode Toggle

**Trigger words**: "vm", "voice mode" → switch to VOICE. "tm", "text mode" → switch to TEXT.

### VOICE Mode Rules
- Short sentences, max 2 lines each
- Bullet points for all lists
- No code blocks longer than 3 lines — summarize verbally instead
- Confirm before executing any tool: "I'll [action]. Go ahead?"
- Use plain language, avoid jargon
- When showing code changes, describe what changed rather than showing diffs

### TEXT Mode Rules (Default)
- Full detailed responses with code blocks
- Show diffs, full implementations, detailed explanations
- Execute tools without pre-confirmation (unless destructive)

## Agent Team Orchestration

### When to Use Teams
- Task has 3+ independent subtasks
- Different subtasks need different expertise (e.g., implementation + testing + review)
- Work can be parallelized without merge conflicts

### Coordination Pattern

```
1. DECOMPOSE: Break task into independent units with clear file ownership
2. ASSIGN: Spawn one agent per unit with full context in prompt
3. MONITOR: Track progress, resolve blockers
4. MERGE: Integrate results, resolve conflicts
5. VERIFY: Run full test suite on merged result
```

### Agent Spawn Rules
- Each agent gets explicit file ownership (which files it may modify)
- Spawn prompt includes ALL context — agents don't inherit conversation
- Use Sonnet for read-only tasks (review, analysis), Opus for implementation
- Max 4 concurrent agents to avoid resource contention
- Name agents by role: `impl-auth`, `test-api`, `review-security`

### Conflict Resolution
- If two agents need the same file, serialize those tasks
- Coordinator (main thread) owns integration and final verification
- When merging, run tests after each agent's changes are integrated

## Common Mistakes
- Spawning agents without full context in the prompt
- Letting multiple agents modify the same file
- Skipping verification after merging agent outputs
- Using teams for tasks that are naturally sequential
