# Dispatch Prompt Template

Every agent dispatch prompt should include these 6 sections. Omit sections only when genuinely not applicable.

## The Template

### 1. Role & Task
One sentence: who the agent is and what it must accomplish.
> "You are a code reviewer analyzing the auth module for security vulnerabilities."

### 2. Full Context
Everything the agent needs to understand the problem. Paste relevant content directly — agents don't inherit conversation history.
- Task description from plan (full text, not file references)
- Relevant code snippets or file paths
- Architecture context and constraints
- Prior agent outputs this task depends on

### 3. Scope Constraints
Explicit boundaries on what the agent may and may not do.
- Files it may modify (allowlist)
- Files it must not touch
- Approaches to avoid
- Time/complexity budget

### 4. Success Criteria
What "done" looks like. Be specific enough that a reviewer could verify.
- Acceptance criteria from the task spec
- Tests that must pass
- Quality bar (e.g., "no new linter warnings")

### 5. Return Format
How to structure the response. Prevents output bloat and ensures usable results.
- Token budget (e.g., "under 1000 tokens")
- Structure (e.g., "verdict first, then supporting details")
- Required sections (e.g., "Files Changed, Test Results, Issues Found")

### 6. Anti-patterns
Common mistakes to avoid for this specific task.
- "Do NOT just increase timeouts — find the real issue"
- "Do NOT refactor surrounding code"
- "Do NOT add features not in the spec"

## Usage

Reference this template when writing dispatch prompts in any orchestration skill. Not every prompt needs all 6 sections at full length — but skipping a section should be a conscious choice, not an oversight.
