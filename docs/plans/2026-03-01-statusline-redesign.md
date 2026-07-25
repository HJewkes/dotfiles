# Statusline Redesign: Health-First with Git Context + Rate Limits

## Problem

The current statusline was designed around "what is the agent doing / when will it compact / how much has it cost." On a Max subscription, cost is meaningless. The model name pill is broken most of the time. Tool state (Read, Edit, etc.) isn't useful beyond "waiting for input." The biggest missing signals are:

1. **Git context** — which repo/branch/worktree am I in?
2. **Agent health** — is the agent stuck in a bad git state (LOCK, REBASE, MERGE, DETACHED)?
3. **Rate limits** — am I about to hit my 5hr or weekly usage cap?

Multi-agent workflows in a production monolith make health checks critical — agents step on each other's toes and leave broken git state behind.

## Design

### Pill Layout (left to right)

```
 repo:branch [wt:name]   ▓▓▓▓░░░░ 42%   opus ▃▆   1h23m +47   abc123
 ╰─── Pill 1: Git ────╯  ╰ Pill 2 ─╯    ╰─ P3 ─╯  ╰─ P4 ──╯  ╰ P5 ─╯
                                                     + P4a: Auth (conditional)
```

### Pill 1: Git (replaces model/tool-state pill)

**Always visible.** Shows orientation + health in a single combined pill.

#### Normal state
- Format: `icon repo:branch` (e.g., ` myapp:feat/auth`)
- When in a worktree: `icon repo:branch [wt:name]` (e.g., ` myapp:main [wt:fix-login]`)
- Color: mauve background (matches current model pill aesthetic)
- Icon: git branch icon (nf-dev-git_branch `\ue0a0`)

#### How repo/branch are detected
```bash
# Repo name: basename of git root
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")

# Branch: symbolic ref or detached
branch=$(git symbolic-ref --short HEAD 2>/dev/null)

# Worktree: detect if in a worktree (git-dir != git-common-dir)
git_dir=$(git rev-parse --git-dir 2>/dev/null)
common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ "$git_dir" != "$common_dir" ]]; then
    wt_name=$(basename "$(git rev-parse --show-toplevel)")
fi
```

#### Warning states (priority order — highest wins)

| Priority | State | Label | Color | Detection |
|----------|-------|-------|-------|-----------|
| 1 | Index lock | `LOCK repo:branch` | Red (BG_RED) | `test -f "$GIT_DIR/index.lock"` |
| 2 | Unresolved conflicts | `CONFLICT repo:branch` | Red | `git ls-files --unmerged \| head -1` |
| 3 | Rebase in progress | `repo:branch REBASE 3/7` | Orange (BG_PEACH) | `test -d "$GIT_DIR/rebase-merge"` |
| 4 | Merge in progress | `repo:branch MERGE` | Yellow (BG_YELLOW) | `test -f "$GIT_DIR/MERGE_HEAD"` |
| 5 | Detached HEAD | `repo:sha DETACHED` | Orange | `$GIT_DIR/HEAD` has no `ref:` prefix |
| 6 | Cherry-pick | `repo:branch CHERRY-PICK` | Yellow | `test -f "$GIT_DIR/CHERRY_PICK_HEAD"` |
| 7 | Bisect | `repo:branch BISECT` | Yellow | `test -f "$GIT_DIR/BISECT_LOG"` |
| 8 | Revert | `repo:branch REVERT` | Yellow | `test -f "$GIT_DIR/REVERT_HEAD"` |
| 9 | Diverged | `repo:branch DIVERGED` | Orange | `git status --porcelain=v2 --branch` ab line |
| 10 | No upstream | `repo:branch NO-UPSTREAM` | Yellow | Missing upstream line |

Performance: States 1-8 are sub-millisecond filesystem checks. States 9-10 come from a single `git status --porcelain=v2 --branch` call (5-20ms).

#### Not in a git repo
- Format: `icon dirname` with muted color (surface1 bg, subtext fg)
- Just shows the working directory basename

### Pill 2: Context Bar (unchanged)

Keep as-is. Blue = cached, teal = new, gray = free. Color-escalated percentage. Compact label when exceeds 200k.

### Pill 3: Rate Limit (replaces cost pill)

**Shows 5hr and weekly usage as two vertical bar characters with color coding.**

#### Vertical bar encoding
```
Character:  ▁  ▂  ▃  ▄  ▅  ▆  ▇  █
Threshold:  0  15 30 45 60 75 85 95+
```

#### Color escalation (per bar)
| Usage | Color | Meaning |
|-------|-------|---------|
| 0-59% | FG_GREEN | Plenty of room |
| 60-79% | FG_YELLOW | Getting warm |
| 80-89% | FG_PEACH | Caution |
| 90%+ | FG_RED + BOLD | At risk of hitting limit |

#### Layout
- Wide: `opus ▃▆` — model label + two bars (5hr first, weekly second)
- Narrow: `▃▆` — bars only

#### Smart % display
Show numeric percentage only when ALL of:
- Usage >= 80%
- Projected to exhaust within the remaining window time

Formula: `show_pct = (pct >= 80) && (estimated_remaining_usage_time < time_until_reset)`

When showing: `opus ▇87%▆` (% inline after the bar it applies to)

#### Data source
- OAuth API endpoint: `https://api.anthropic.com/api/oauth/usage`
- Credentials: `~/.claude/.credentials.json` or macOS keychain
- Cache: write to `~/.claude/status-cache/rate_limits` with 60s TTL
- Script: `~/.claude/scripts/rate-limits.sh` (new, similar pattern to auth-remaining.sh)
- Fallback: if API unavailable, show `--` in muted color

#### Model-aware display
The model label tells you which rate you're burning. Opus burns at 1x, Sonnet goes further. Parse model from the JSON stdin `model.id` field (same as current, but used as label not as primary pill).

### Pill 4: Session Metrics (simplified)

Drop cost. Keep duration + net lines.

- Format: `1h23m +47`
- Duration: FG_OVERLAY
- Net lines: FG_GREEN if positive, FG_RED if negative

### Pill 4a: Auth (conditional, unchanged)

Keep current behavior: hidden when >60m, muted at 31-60m, yellow at 11-30m, peach bold at 1-10m, red EXPIRED at 0.

### Pill 5: Session ID (unchanged)

Keep as rightmost regular pill.

## Adaptive Width

| Width | Adjustment |
|-------|------------|
| 250+ | Full: `repo:branch [wt:name] + context + opus ▃▆ + 1h23m +47 + auth + id` |
| 180+ | Drop worktree suffix |
| 140+ | Drop model label from rate pill, drop net lines |
| 120+ | Drop metrics pill entirely |
| <100 | Git pill + context bar + id only |

Implementation: compute `visible_len` of the full output, then progressively drop elements if it exceeds `term_width - RIGHT_MARGIN`.

## New Files

| File | Purpose |
|------|---------|
| `~/.claude/scripts/rate-limits.sh` | Fetch + cache 5hr/weekly usage from OAuth API |
| `~/.claude/status-cache/rate_limits` | Cached rate limit data (60s TTL) |

## Changes to Existing Files

| File | Change |
|------|--------|
| `~/.claude/statusline-command.sh` | Full rewrite of pill rendering logic |

## Performance Budget

Target: <50ms total for all statusline rendering.

| Component | Budget |
|-----------|--------|
| JSON parsing (jq) | 5ms |
| Git filesystem checks (states 1-8) | <1ms |
| `git status --porcelain=v2 --branch` | 5-20ms |
| `git rev-parse` calls (toplevel, git-dir, common-dir) | 3-5ms |
| Rate limit cache read | <1ms |
| Auth remaining (existing) | 5-10ms |
| Printf rendering | <1ms |
| **Total** | **~25-40ms** |

The rate-limits.sh script runs the API call only when cache is stale (>60s), so it doesn't add latency on most renders.
