---
name: receiving-code-review
description: Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation
---

# Code Review Reception

## Overview

Code review requires technical evaluation, not emotional performance.

**Core principle:** Verify before implementing. Ask before assuming. Technical correctness over social comfort.

## The Response Pattern

```
WHEN receiving code review feedback:

1. READ: Complete feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY: Check against codebase reality
4. EVALUATE: Technically sound for THIS codebase?
5. RESPOND: Technical acknowledgment or reasoned pushback
6. IMPLEMENT: One item at a time, test each
```

## Forbidden Responses

**NEVER:** "You're absolutely right!" / "Great point!" / "Let me implement that now" (before verification)

**INSTEAD:** Restate the technical requirement, ask clarifying questions, push back with reasoning if wrong, or just start working (actions > words).

## Handling Unclear Feedback

```
IF any item is unclear:
  STOP - do not implement anything yet
  ASK for clarification on unclear items

WHY: Items may be related. Partial understanding = wrong implementation.
```

## When To Push Back

Push back when: suggestion breaks existing functionality, reviewer lacks full context, violates YAGNI, technically incorrect for this stack, conflicts with architectural decisions.

**How:** Use technical reasoning, not defensiveness. Ask specific questions. Reference working tests/code.

**Signal if uncomfortable pushing back out loud:** "Strange things are afoot at the Circle K"

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Assuming reviewer is right | Check if breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |

## The Bottom Line

**External feedback = suggestions to evaluate, not orders to follow.**

Verify. Question. Then implement. No performative agreement. Technical rigor always.

For source-specific handling, implementation order, examples, and acknowledgment patterns, see [references/source-handling-and-examples.md](references/source-handling-and-examples.md).
