---
name: research
description: Use when the user asks to research a topic, investigate options, compare technologies, analyze a problem space, or gather information before making a decision — for both coding and non-coding work
---

# Research

## Overview

Structured research process that works for coding tasks (evaluating libraries, understanding APIs) and non-coding work (market research, content creation, learning new domains). Produces organized, actionable artifacts.

## Process

### 1. Scope
Define what we're researching and why:
- What question(s) need answering?
- What decisions will this inform?
- What's out of scope?
- What format should the output take?

Confirm scope with user before proceeding.

### 2. Gather
Collect information from available sources:
- **Code**: Read relevant files, grep for patterns, check dependencies
- **Web**: WebSearch for docs, articles, comparisons. WebFetch for specific pages
- **Context**: Check project CLAUDE.md, existing patterns, prior decisions
- **Docs**: Framework docs via context7 MCP if available

Use parallel subagents for independent research threads.

### 3. Organize
Structure findings:
- Group by theme, not by source
- Flag contradictions between sources
- Note confidence level (verified, likely, uncertain)
- Separate facts from opinions

### 4. Synthesize
Draw conclusions:
- Answer the original questions directly
- Provide recommendation with reasoning
- List trade-offs explicitly
- Note what remains unknown

### 5. Artifact
Deliver in the agreed format:
- **Decision**: Recommendation + alternatives + trade-offs table
- **Comparison**: Feature matrix with weighted criteria
- **Summary**: Key findings + action items
- **Brief**: Background + analysis + recommendation (for sharing with others)

## Quick Reference

| Research Type | Key Sources | Typical Output |
|--------------|-------------|----------------|
| Library eval | npm/pypi, GitHub stars/issues, docs | Comparison matrix |
| Bug investigation | Code, logs, issue trackers | Root cause + fix options |
| Architecture | Existing code, docs, web patterns | Decision document |
| Content/topic | Web search, articles, papers | Structured summary |
| API integration | API docs, examples, SDKs | Integration guide |

## Common Mistakes
- Starting to gather before defining scope (wastes time on irrelevant info)
- Presenting raw findings without synthesis (user wants answers, not data dumps)
- Not confirming scope with user (researching the wrong thing)
- Single-source conclusions (verify across multiple sources)
