# Comprehensive Review Procedure

**When:** Before merging to main, finishing a development branch.

## 4-Pass Structure

1. **TDD Compliance** (Sonnet, read-only) — parallel with Pass 2
   - Every new behavior has test, tests before implementation (check commit order), edge cases, no skipped tests
2. **Code Quality: Diff-Only** (Sonnet, read-only) — parallel with Pass 1
   - Function length (>30 lines), naming, error handling, dead code, type safety, security
3. **Code Quality: With Context** (Sonnet, read-only) — after Pass 2 (dedup)
   - Pattern consistency, project abstraction reuse, CLAUDE.md compliance
4. **Browser Audit** (Playwright MCP, optional) — parallel with Pass 3
   - Visual regression, responsive layout, accessibility, console errors

## Pass Ordering

1+2 parallel → 3 after 2 → 4 parallel with 3 (if Playwright available)

## Output

Deduplicated findings: Critical → Important → Suggestions
