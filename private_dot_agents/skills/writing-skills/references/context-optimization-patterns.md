# Context Optimization Patterns

Reference for how and why we restructure skills and plugins to reduce always-on context overhead.

## The Problem

Every SKILL.md file loads into context when its skill triggers. Plugin agent descriptions load into **every** conversation regardless of use. Both consume context tokens that could be used for actual work.

## Pattern 1: SKILL.md Extraction to References

**When:** A SKILL.md exceeds ~500 words.

**How:** Move detailed procedures, examples, and tables into `references/` files. Keep the SKILL.md as a concise overview with cross-reference links.

**What stays in SKILL.md:**
- Frontmatter + overview + core principle
- Decision flowcharts (if essential to the skill's function)
- Quick reference tables (condensed)
- Red flags / stop conditions
- Links to reference files

**What moves to references/:**
- Detailed step-by-step procedures
- Good/bad code examples
- Rationalization tables
- Checklists and deployment steps
- Anti-patterns with explanations

**Why it works:** SKILL.md loads on trigger. Reference files load only when Claude reads them for a specific task. The skill still functions — Claude sees the overview, knows the references exist, and reads them when needed.

**Example:** `writing-skills` went from 3,204w always-loaded to 406w always-loaded + 2,609w on-demand.

## Pattern 2: Plugin-to-Skill Wrapper Conversion

**When:** A plugin defines subagent types whose descriptions are always loaded but rarely used.

**How:** Create a skill with a lean SKILL.md (~100-200w) listing available agents, and store the full agent system prompts in `references/`. Disable the original plugin.

**Before (plugin):**
```
Plugin enabled → Agent descriptions (~500-1000w each) always in context
→ Claude spawns typed agent when needed
```

**After (skill wrapper):**
```
Skill description (~100-200w) in skill list → Skill triggers on relevant task
→ Reads reference file for agent prompt → Spawns general-purpose Task agent with that prompt
```

**Key difference:** The `general-purpose` Task agent type replaces the plugin's typed agent. The system prompt from the reference file gives it the same behavior.

**Example:** `pr-review-toolkit` had 6 agents totaling ~4,662w always-on. Replaced by `pr-review` skill: 163w always-on + 2,389w on-demand.

## Pattern 3: Flowchart Compression

**When:** Graphviz flowcharts use verbose node labels that inflate word count.

**How:** Shorten node labels to essential phrases. Use IDs with short labels instead of full sentences as IDs.

**Before:** `"Dispatch implementer subagent (./implementer-prompt.md)" [shape=box]`
**After:** `impl [label="Dispatch implementer\n(./implementer-prompt.md)" shape=box]`

## When NOT to Optimize

- Skills under 200 words — already lean
- Plugins with only 1-2 lightweight MCP tools (context7, playwright)
- Plugins that provide skills/hooks only, not agent types
- Content that must be in SKILL.md for the skill to function (decision flowcharts, stop conditions)

## Verification

After restructuring:
1. `wc -w` on new SKILL.md confirms < 500 words
2. `wc -w` on reference files confirms content preserved (total ≈ original)
3. Run `/context-audit` to measure actual context savings
