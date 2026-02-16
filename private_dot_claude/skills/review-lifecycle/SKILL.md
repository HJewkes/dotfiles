---
name: review-lifecycle
description: Use when completing a feature, fixing a bug, or before merging a branch — when thorough multi-pass review is needed to catch issues across TDD compliance, code quality, project standards, and UI correctness
---

# Review Lifecycle

## Overview

Multi-pass review process using parallel subagents. Each pass focuses on a different quality dimension to catch issues that single-pass reviews miss.

## Passes

### Pass 1: TDD Compliance
**Agent**: Read-only, Sonnet model
**Checks**:
- Every new behavior has a corresponding test
- Tests were written before implementation (check commit order if possible)
- Tests cover edge cases, not just happy path
- Bug fixes include regression tests
- No skipped or disabled tests without tracking issue

### Pass 2: Code Quality (Diff-Only)
**Agent**: Read-only, Sonnet model
**Context**: Only the changed files/diffs, no project context
**Checks**:
- Function length (flag >30 lines)
- Clear naming (no abbreviations, no generic names)
- Error handling at boundaries
- No dead code, no commented-out code
- No TODO without tracking issue
- Type safety (no untyped `any`, no type assertions without justification)
- Security: no hardcoded secrets, no SQL injection, no XSS vectors

### Pass 3: Code Quality (With Context)
**Agent**: Read-only, Sonnet model
**Context**: Changed files + project CLAUDE.md + surrounding code
**Checks**:
- Consistency with existing patterns and conventions
- Proper use of project abstractions (not reinventing)
- Integration correctness (API contracts, data flow)
- Import organization follows project convention
- Follows project-specific rules from CLAUDE.md

### Pass 4: Browser Audit (Optional)
**Agent**: Uses Playwright MCP, Sonnet model
**Prerequisite**: Playwright MCP available + running dev server/Storybook
**Checks**:
- Visual regression (screenshot comparison if baseline exists)
- Responsive layout at key breakpoints (mobile, tablet, desktop)
- Accessibility: keyboard navigation, focus management, ARIA attributes
- Console errors during interaction
- Loading states and error states render correctly

## Execution

```
1. Identify changed files (git diff against base branch)
2. Launch Pass 1 + Pass 2 in parallel (independent)
3. Launch Pass 3 (needs Pass 2 context for deduplication)
4. Launch Pass 4 if Playwright available (independent)
5. Merge all findings, deduplicate, categorize by severity
6. Present: Critical (must fix) → Important (should fix) → Suggestions
```

### Spawning Pattern
```
Pass 1 + 2: parallel (no shared context)
Pass 3: after Pass 2 (to avoid duplicate findings)
Pass 4: parallel with Pass 3 (independent)
```

## Quick Reference

| Severity | Action | Examples |
|----------|--------|----------|
| Critical | Must fix before merge | Security vuln, data loss, broken test, missing error handling |
| Important | Should fix, may defer with tracking issue | Naming, pattern inconsistency, missing edge case test |
| Suggestion | Nice to have | Style preference, minor refactor opportunity |

## Common Mistakes
- Running all passes sequentially (Passes 1+2 are independent, parallelize)
- Skipping Pass 3 (context-aware review catches pattern violations)
- Treating all findings as equal severity
- Not deduplicating between Pass 2 and Pass 3
