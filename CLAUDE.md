# Global Standards

## Workflow Contract

All non-trivial work follows: **Research → Plan → Implement → Verify**

- **Research**: Understand the problem. Read relevant code, docs, issues. No changes yet.
- **Plan**: Propose approach. For complex tasks, use plan mode. Get approval before proceeding.
- **Implement**: Make changes. One logical change at a time. Keep diffs small and reviewable.
- **Verify**: Run tests, linters, type checks. Confirm behavior matches intent. Never skip this.

Trivial tasks (typo fixes, single-line changes) can skip Research/Plan but never skip Verify.

## Output Mode

Default mode: **TEXT** — full detailed responses with code blocks.

Switch to **VOICE** mode by saying "vm" or "voice mode":
- Short sentences, no long code blocks
- Bullet points for lists
- Confirm before executing any tool
- Summarize code changes verbally instead of showing full diffs
- Say "text mode" or "tm" to switch back

## Agent Coordination

- Include FULL context in spawn prompts — agents don't inherit conversation history
- Model selection: Opus for implementation/debugging, Sonnet for review/analysis, Haiku for simple validation/formatting
- When agents share a branch, assign distinct file ownership to avoid merge conflicts
- Always verify agent output (run tests, check types) before committing
- Use built-in Task/Team tools — never file-based coordination (STATUS.md, HANDOFF.md)
- Clean up teams with TeamDelete when work is complete

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
