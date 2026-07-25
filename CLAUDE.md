# Global Standards

## Workflow Contract

All non-trivial work follows: **Research -> Plan -> Implement -> Verify**

- **Research**: Understand the problem. Read relevant code, docs, issues. No changes yet.
- **Plan**: Propose approach. For multi-step features, use the brain planning workflow (`/spec` or `brain_workflow_start`). For smaller tasks, discuss the approach and get approval before proceeding.
- **Implement**: Make changes. One logical change at a time. Keep diffs small and reviewable.
- **Verify**: Run tests, linters, type checks. Confirm behavior matches intent. Never skip this.

Trivial tasks (typo fixes, single-line changes) can skip Research/Plan but never skip Verify.

## Output Mode

Default mode: **TEXT** -- full detailed responses with code blocks.

Switch to **VOICE** mode by saying "vm" or "voice mode":
- Short sentences, no long code blocks
- Bullet points for lists
- Confirm before executing any tool
- Summarize code changes verbally instead of showing full diffs
- Say "text mode" or "tm" to switch back

## Agent Coordination

- Include FULL context in spawn prompts -- agents don't inherit conversation history
- Model selection: Opus for implementation/debugging, Sonnet for review/analysis, Haiku for simple validation/formatting
- When agents share a branch, assign distinct file ownership to avoid merge conflicts
- Always verify agent output (run tests, check types) before committing
- Use built-in Task/Team tools -- never file-based coordination (STATUS.md, HANDOFF.md)
- Clean up teams with TeamDelete when work is complete

## Tool Usage

- Never issue the same tool call twice consecutively. If a command fails or returns unexpected output, analyze the result and try a different approach.
- After two failed attempts at the same goal, stop and reassess the strategy rather than continuing to retry variations.

## Code Quality

- Functions: max ~30 lines. Extract if longer.
- Zero linter/type warnings in modified files
- Self-documenting: clear names over comments. Add comments only for "why", never "what"
- No dead code, no commented-out code, no TODO without a tracking issue
- Prefer composition over inheritance, pure functions over side effects
- Handle errors at boundaries, not everywhere

## Testing

- Test behavior, not implementation details
- Every bug fix gets a regression test
- Mock only external dependencies (network, filesystem, time)
- Arrange-Act-Assert structure
- Test names describe the scenario, not the method

## Git Workflow

- Imperative mood commits: "Add feature" not "Added feature"
- One logical change per commit
- Feature branches for all work: `feat/`, `fix/`, `refactor/`, `docs/`
- Commit messages: short subject (<72 chars), blank line, body if needed

## Harness Commands

- `/goal <condition>` is a **real built-in command** (docs: code.claude.com/docs/en/goal) — it runs a long-horizon autonomous loop that works toward the goal condition across many iterations. It may NOT appear in the harness skill/command list; do not tell the user it doesn't exist — it's real, just unlisted.
- The goal condition caps at **4000 chars** — for anything larger, write the full spec to a file and make the condition a short pointer to it (the loop re-reads the file each iteration).
