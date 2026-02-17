# Verification Patterns and Rationalizations

## Key Patterns

**Tests:**
```
RUN: [test command]
SEE: 34/34 pass
CLAIM: "All tests pass"

NEVER: "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
Write test -> Run (pass) -> Revert fix -> Run (MUST FAIL) -> Restore -> Run (pass)

NEVER: "I've written a regression test" (without red-green verification)
```

**Build:**
```
RUN: [build command]
SEE: exit 0
CLAIM: "Build passes"

NEVER: "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
Re-read plan -> Create checklist -> Verify each -> Report gaps or completion

NEVER: "Tests pass, phase complete"
```

**Agent delegation:**
```
Agent reports success -> Check VCS diff -> Verify changes -> Report actual state

NEVER: Trust agent report
```

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Why This Matters

From 24 failure memories:
- Your human partner said "I don't believe you" — trust broken
- Undefined functions shipped — would crash
- Missing requirements shipped — incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases, paraphrases, synonyms
- Implications of success
- ANY communication suggesting completion/correctness
