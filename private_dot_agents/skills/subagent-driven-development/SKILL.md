---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute plan by dispatching fresh subagent per task, with two-stage review after each: spec compliance review first, then code quality review.

**Core principle:** Fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration

## When to Use

```dot
digraph when_to_use {
    "Have implementation plan?" [shape=diamond];
    "Tasks mostly independent?" [shape=diamond];
    "Stay in this session?" [shape=diamond];
    "subagent-driven-development" [shape=box];
    "executing-plans" [shape=box];
    "Manual execution or brainstorm first" [shape=box];

    "Have implementation plan?" -> "Tasks mostly independent?" [label="yes"];
    "Have implementation plan?" -> "Manual execution or brainstorm first" [label="no"];
    "Tasks mostly independent?" -> "Stay in this session?" [label="yes"];
    "Tasks mostly independent?" -> "Manual execution or brainstorm first" [label="no - tightly coupled"];
    "Stay in this session?" -> "subagent-driven-development" [label="yes"];
    "Stay in this session?" -> "executing-plans" [label="no - parallel session"];
}
```

## The Process

```dot
digraph process {
    rankdir=TB;
    subgraph cluster_per_task {
        label="Per Task";
        impl [label="Dispatch implementer\n(./implementer-prompt.md)" shape=box];
        questions [label="Questions?" shape=diamond];
        answer [label="Answer, provide context" shape=box];
        work [label="Implement, test, commit" shape=box];
        spec [label="Spec reviewer\n(./spec-reviewer-prompt.md)" shape=box];
        spec_ok [label="Spec compliant?" shape=diamond];
        spec_fix [label="Fix spec gaps" shape=box];
        quality [label="Quality reviewer\n(./code-quality-reviewer-prompt.md)" shape=box];
        qual_ok [label="Quality approved?" shape=diamond];
        qual_fix [label="Fix quality issues" shape=box];
        done [label="Mark task complete" shape=box];
    }
    start [label="Extract all tasks from plan" shape=box];
    more [label="More tasks?" shape=diamond];
    final [label="Final code review" shape=box];
    finish [label="finishing-a-development-branch" shape=box style=filled fillcolor=lightgreen];

    start -> impl;
    impl -> questions;
    questions -> answer [label="yes"];
    answer -> impl;
    questions -> work [label="no"];
    work -> spec;
    spec -> spec_ok;
    spec_ok -> spec_fix [label="no"];
    spec_fix -> spec [label="re-review"];
    spec_ok -> quality [label="yes"];
    quality -> qual_ok;
    qual_ok -> qual_fix [label="no"];
    qual_fix -> quality [label="re-review"];
    qual_ok -> done [label="yes"];
    done -> more;
    more -> impl [label="yes"];
    more -> final [label="no"];
    final -> finish;
}
```

## Prompt Templates

- `./implementer-prompt.md` — `./spec-reviewer-prompt.md` — `./code-quality-reviewer-prompt.md`

## Red Flags

**Never:** skip reviews, proceed with unfixed issues, dispatch parallel implementers, make subagent read plan file (provide full text), start code quality review before spec compliance passes.

- Dispatch prompts missing key sections (see skill-conventions/references/dispatch-prompt-template.md for the canonical 6-section structure)

**If subagent asks questions:** Answer before proceeding.
**If reviewer finds issues:** Implementer fixes, re-review until approved.

## References

- [references/workflow-example.md](references/workflow-example.md) — full walkthrough
- [references/advantages-and-costs.md](references/advantages-and-costs.md) — comparison vs manual/executing plans

**Required skills:** using-git-worktrees, writing-plans, code-review, finishing-a-development-branch, test-driven-development
