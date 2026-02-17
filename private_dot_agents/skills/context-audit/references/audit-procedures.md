# Context Audit — Detailed Procedures

## Static Inventory Procedure

> **Automation:** `~/.agents/bin/audit-context` automates Steps 1-4 below. Use `--json` for structured output. The manual steps remain here as reference.

### Step 1: Discover Skills

```
Glob: ~/.claude/skills/*/SKILL.md
```

For each skill directory found:
- Read `SKILL.md` — record byte size and word count
- Glob `rules/*.md` — record count and total size (these are always-on)
- Glob `references/*.md` — record count and total size (these are on-demand)

### Step 2: Measure CLAUDE.md Files

Read these files if they exist:
- `~/CLAUDE.md` (global)
- `{project-root}/CLAUDE.md` (project-level)
- `{project-root}/.claude/CLAUDE.md` (alternate location)

Record byte size and word count for each.

### Step 3: Count Plugins and MCP Servers

Read `~/.claude/settings.json` and extract:
- `plugins` array — count entries
- `mcpServers` object — count keys
- For each MCP server, note if it has custom tool descriptions

### Step 4: Build Inventory Table

Sort all entries by size descending. Format:

```
| Source | Size | Words | Loads | Flag |
|--------|------|-------|-------|------|
| skills/tailwind/SKILL.md | 2.1KB | 620 | on-trigger | LARGE |
| CLAUDE.md (global) | 3.4KB | 890 | always-on | LARGE |
| skills/research/rules/defaults.md | 450B | 95 | always-on | RULES |
| ... | ... | ... | ... | ... |
```

Flag column values:
- `LARGE` — SKILL.md > 500 words or CLAUDE.md > 2KB
- `RULES` — any file in a rules/ directory (always loaded)
- `MCP` — 5+ MCP servers configured
- `-` — within acceptable range

Compute totals:
- **Always-on context**: sum of all rules/ files + CLAUDE.md files + plugin/MCP overhead estimate (200 words per MCP server, 50 words per plugin for tool descriptions)
- **On-trigger context**: average SKILL.md size across all skills

## Session Token Analysis Procedure

### Step 1: Find the Active Session

The current session JSONL is at a path like:
```
~/.claude/projects/{project-hash}/{session-id}.jsonl
```

Use Bash to find the most recently modified JSONL:
```bash
ls -t ~/.claude/projects/*//*.jsonl 2>/dev/null | head -1
```

If the user is asking about a specific session or the path doesn't resolve, check `~/.claude/projects/` subdirectories.

### Step 2: Extract Token Usage

Each assistant message in the JSONL has a `usage` field. Use Bash with grep/jq:

```bash
grep -o '"usage":{[^}]*}' <session-file> | head -50
```

Or more precisely with jq if available:
```bash
cat <session-file> | jq -c 'select(.type == "assistant") | {turn: .turn, input: .usage.input_tokens, cache_read: .usage.cache_read_input_tokens, output: .usage.output_tokens}' 2>/dev/null
```

### Step 3: Calculate Deltas

For each consecutive pair of turns, compute:
- `delta = current.input_tokens - previous.input_tokens`
- Sort by delta descending
- Take top 5

### Step 4: Correlate with Tool Calls

For each spike, look at the tool_use blocks in the preceding messages:
- File reads (Read tool) — note file path and approximate size
- Skill invocations (Skill tool) — note which skill loaded
- MCP tool calls — note which server
- Grep/Glob results — note result count

### Step 5: Format Session Report

```
### Session Analysis
Total turns: N
Starting context: X tokens
Current context: Y tokens
Growth rate: ~Z tokens/turn

Top Context Spikes:
1. Turn 5 → 6: +15,200 tokens — Skill: tailwind loaded
2. Turn 8 → 9: +12,000 tokens — Read: src/components/Dashboard.tsx (480 lines)
3. Turn 12 → 13: +8,500 tokens — MCP: playwright snapshot
...
```

## Scoring Rubric

### Skills Health (30 points)

| Condition | Points |
|-----------|--------|
| All SKILL.md files < 500 words | +10 |
| No rules/ directories (nothing always-on) | +10 |
| References used for detailed content | +5 |
| No overlapping skill triggers | +5 |

Deductions:
- Each SKILL.md > 500 words: -3
- Each rules/ directory: -5
- Each skill > 1000 words without references: -3

### CLAUDE.md Health (25 points)

| Condition | Points |
|-----------|--------|
| Global CLAUDE.md < 2KB | +10 |
| Project-specific CLAUDE.md exists and is focused | +5 |
| No duplication between global and project | +5 |
| Clear, actionable instructions (not vague) | +5 |

Deductions:
- Global CLAUDE.md > 4KB: -10
- Duplicated content across CLAUDE.md files: -5

### Plugin/MCP Health (25 points)

| Condition | Points |
|-----------|--------|
| < 5 MCP servers | +10 |
| < 10 plugins | +5 |
| All MCP servers actively used in session | +5 |
| No redundant tool providers | +5 |

Deductions:
- Each MCP server beyond 5: -3
- Each plugin beyond 15: -2

### Session Efficiency (20 points)

| Condition | Points |
|-----------|--------|
| Average growth < 5K tokens/turn | +10 |
| No single spike > 20K tokens | +5 |
| Cache hit rate > 50% | +5 |

Deductions:
- Average growth > 10K tokens/turn: -5
- Any spike > 30K tokens: -5
- Cache hit rate < 30%: -5

If no session JSONL is available, score this component at 10/20 (neutral).

### Letter Grades

| Score | Grade |
|-------|-------|
| 90-100 | A |
| 80-89 | B+ |
| 70-79 | B |
| 60-69 | C+ |
| 50-59 | C |
| 40-49 | D |
| 0-39 | F |

## Recommendation Rules

Generate recommendations based on findings. Priority order:

1. **rules/ directories exist** → "Move `{skill}/rules/{file}` content into SKILL.md — rules/ files load every conversation regardless of skill use"
2. **SKILL.md > 500 words** → "Extract detailed procedures from `{skill}/SKILL.md` into `references/` — keeps trigger cost low"
3. **CLAUDE.md > 4KB** → "Split global CLAUDE.md — move project-specific instructions to per-project files"
4. **5+ MCP servers** → "Review MCP server list — each adds tool descriptions to every conversation. Disable unused servers."
5. **Session spike > 20K tokens** → "Large context spike from {source} — consider chunked reads or summarization"
6. **Overlapping skill triggers** → "Skills `{a}` and `{b}` may both trigger on similar inputs — consolidate or differentiate triggers"
7. **No references/ used** → "Skills with large SKILL.md files should use references/ for detailed content that's only read when needed"
8. **High plugin count (15+)** → "Each plugin adds tool descriptions to context. Disable plugins you rarely use."

Format each recommendation with:
- What was found (evidence)
- What to do (action)
- Expected impact (words/tokens saved estimate)
