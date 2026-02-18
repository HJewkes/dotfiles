#!/bin/bash
# Claude Code TUI statusline — renders floating pills for the footer
# Called by Claude Code on every statusline refresh, receives JSON via stdin
# Renders: model pill, context bar pill, metrics pill, auth pill

# ── ANSI colors (Catppuccin Mocha) ──────────────────────────
RST="\033[0m"
BOLD="\033[1m"

BG_SURFACE1="\033[48;2;69;71;90m"
BG_MAUVE="\033[48;2;203;166;247m"
BG_YELLOW="\033[48;2;249;226;175m"
BG_PEACH="\033[48;2;250;179;135m"
BG_RED="\033[48;2;243;139;168m"

FG_CRUST="\033[38;2;17;17;27m"
FG_SURFACE1="\033[38;2;69;71;90m"
FG_BLUE="\033[38;2;137;180;250m"
FG_GREEN="\033[38;2;166;227;161m"
FG_YELLOW="\033[38;2;249;226;175m"
FG_PEACH="\033[38;2;250;179;135m"
FG_TEAL="\033[38;2;148;226;213m"
FG_MAUVE="\033[38;2;203;166;247m"
FG_RED="\033[38;2;243;139;168m"
FG_SUBTEXT="\033[38;2;166;173;200m"
FG_OVERLAY="\033[38;2;108;112;134m"

# ── Icons via printf ────────────────────────────────────────
ICON_ROBOT=$(printf '\uf498')
ICON_ZAP=$(printf '\u26a1')
ICON_LOCK=$(printf '\uf023')
ICON_LROUND=$(printf '\ue0b6')
ICON_RROUND=$(printf '\ue0b4')

# ── Read stdin ──────────────────────────────────────────────
input=$(cat)

# ── Parse all JSON fields in a single jq call ───────────────
read -r model_id used_pct cache_read cache_create ctx_size cost_usd duration_ms lines_add lines_rm exceeds_200k <<< \
  $(echo "$input" | jq -r '[
    .model.id // "unknown",
    .context_window.used_percentage // 0,
    .context_window.current_usage.cache_read_input_tokens // 0,
    .context_window.current_usage.cache_creation_input_tokens // 0,
    .context_window.context_window_size // 200000,
    .cost.total_cost_usd // 0,
    .cost.total_duration_ms // 0,
    .cost.total_lines_added // 0,
    .cost.total_lines_removed // 0,
    .exceeds_200k_tokens // false
  ] | @tsv' 2>/dev/null)

# ── Fallbacks for empty/malformed input ─────────────────────
[[ -z "$model_id" ]] && model_id="unknown"
[[ -z "$used_pct" || "$used_pct" == "null" ]] && used_pct=0
[[ -z "$cache_read" || "$cache_read" == "null" ]] && cache_read=0
[[ -z "$cache_create" || "$cache_create" == "null" ]] && cache_create=0
[[ -z "$ctx_size" || "$ctx_size" == "null" || "$ctx_size" == "0" ]] && ctx_size=200000
[[ -z "$cost_usd" || "$cost_usd" == "null" ]] && cost_usd=0
[[ -z "$duration_ms" || "$duration_ms" == "null" ]] && duration_ms=0
[[ -z "$lines_add" || "$lines_add" == "null" ]] && lines_add=0
[[ -z "$lines_rm" || "$lines_rm" == "null" ]] && lines_rm=0
[[ -z "$exceeds_200k" || "$exceeds_200k" == "null" ]] && exceeds_200k="false"

# ── HOOK BRIDGE STATE ─────────────────────────────────────────
# Read tool state from hook bridge (Task 04). Format: STATE|TOOL_NAME|TIMESTAMP
STATE_FILE="$HOME/.claude/status-cache/tool_state"
tool_state="idle"
tool_name=""
if [[ -f "$STATE_FILE" ]]; then
    IFS='|' read -r tool_state tool_name tool_ts < "$STATE_FILE" 2>/dev/null
    # Validate fields — treat malformed data as idle
    if [[ -z "$tool_state" ]]; then
        tool_state="idle"
    fi
    # Stale check: if working state is >30s old, treat as idle
    if [[ "$tool_state" == "working" ]]; then
        now=$(date +%s)
        if [[ -z "$tool_ts" || ! "$tool_ts" =~ ^[0-9]+$ ]] || (( now - tool_ts > 30 )); then
            tool_state="idle"
        fi
    fi
fi

# Format tool name for display
format_tool_name() {
    case "$1" in
        Read)       echo "Reading" ;;
        Edit)       echo "Editing" ;;
        Bash)       echo "Running cmd" ;;
        Grep)       echo "Searching" ;;
        Write)      echo "Writing" ;;
        Glob)       echo "Searching" ;;
        *)
            # Show raw name, truncate to 15 chars if needed
            local name="$1"
            if (( ${#name} > 15 )); then
                name="${name:0:15}"
            fi
            echo "$name"
            ;;
    esac
}

formatted_tool_name=$(format_tool_name "$tool_name")

# ── MODEL NAME PARSING ──────────────────────────────────────
# Input: "us.anthropic.claude-opus-4-6" → "opus 4"
# Strategy: split on '-', find opus/sonnet/haiku, take that + next segment
parse_model_name() {
    local id="$1"
    # Replace dots with dashes for uniform splitting, then process
    local normalized="${id//./-}"
    local IFS='-'
    local parts=($normalized)
    local count=${#parts[@]}

    for ((i=0; i<count; i++)); do
        case "${parts[$i]}" in
            opus|sonnet|haiku)
                if ((i + 1 < count)); then
                    echo "${parts[$i]} ${parts[$((i+1))]}"
                else
                    echo "${parts[$i]}"
                fi
                return
                ;;
        esac
    done

    # Fallback: last 2 segments
    if ((count >= 2)); then
        echo "${parts[$((count-2))]} ${parts[$((count-1))]}"
    elif ((count == 1)); then
        echo "${parts[0]}"
    else
        echo "unknown"
    fi
}

model_name=$(parse_model_name "$model_id")

# ── CONTEXT BAR ─────────────────────────────────────────────
# 20 chars wide. Blue=cached, Teal=new, Gray=free
BAR_WIDTH=20
total_used=$((cache_read + cache_create))

if ((total_used > 0)); then
    blue_blocks=$((cache_read * BAR_WIDTH / ctx_size))
    teal_blocks=$((cache_create * BAR_WIDTH / ctx_size))
else
    # Use used_pct as fallback when token breakdown is 0
    blue_blocks=$((used_pct * BAR_WIDTH / 100))
    teal_blocks=0
fi

# Ensure at least 1 block for each non-zero component
if ((cache_read > 0 && blue_blocks == 0)); then
    blue_blocks=1
fi
if ((cache_create > 0 && teal_blocks == 0)); then
    teal_blocks=1
fi

# Cap total used blocks at BAR_WIDTH
if ((blue_blocks + teal_blocks > BAR_WIDTH)); then
    teal_blocks=$((BAR_WIDTH - blue_blocks))
    if ((teal_blocks < 0)); then
        teal_blocks=0
        blue_blocks=$BAR_WIDTH
    fi
fi

gray_blocks=$((BAR_WIDTH - blue_blocks - teal_blocks))
if ((gray_blocks < 0)); then gray_blocks=0; fi

# Build bar string — pre-compute block characters once, then repeat via printf
BLOCK_FULL=$(printf '\u2588')
BLOCK_LIGHT=$(printf '\u2591')

build_repeat() {
    local char="$1" count="$2" result=""
    for ((i=0; i<count; i++)); do result+="$char"; done
    echo "$result"
}

blue_part="${FG_BLUE}$(build_repeat "$BLOCK_FULL" "$blue_blocks")"
teal_part="${FG_TEAL}$(build_repeat "$BLOCK_FULL" "$teal_blocks")"
gray_part="${FG_OVERLAY}$(build_repeat "$BLOCK_LIGHT" "$gray_blocks")"

# % color escalation
pct_int=${used_pct%.*}  # truncate any decimal
if ((pct_int > 85)); then
    pct_color="${BOLD}${FG_PEACH}"
elif ((pct_int >= 70)); then
    pct_color="${FG_YELLOW}"
else
    pct_color="${FG_BLUE}"
fi

# Compaction label
compact_label=""
if [[ "$exceeds_200k" == "true" ]]; then
    compact_label="${FG_PEACH}compact "
fi

# ── TIME FORMATTING ─────────────────────────────────────────
format_time() {
    local ms="$1"
    local total_sec=$((ms / 1000))

    if ((total_sec < 60)); then
        echo "${total_sec}s"
    elif ((total_sec < 3600)); then
        echo "$((total_sec / 60))m"
    elif ((total_sec < 86400)); then
        local h=$((total_sec / 3600))
        local m=$(( (total_sec % 3600) / 60 ))
        echo "${h}h ${m}m"
    else
        local d=$((total_sec / 86400))
        local h=$(( (total_sec % 86400) / 3600 ))
        echo "${d}d ${h}h"
    fi
}

session_time=$(format_time "$duration_ms")

# ── NET LINES ───────────────────────────────────────────────
net_lines=$((lines_add - lines_rm))
if ((net_lines >= 0)); then
    lines_display="+${net_lines}"
else
    lines_display="${net_lines}"
fi

# ── COST FORMATTING ─────────────────────────────────────────
# Format with 2 decimal places
cost_display=$(printf '$%.2f' "$cost_usd" 2>/dev/null || echo '$0.00')

# ── AUTH PILL ───────────────────────────────────────────────
auth_pill=""
auth_remaining=$("$HOME/.claude/scripts/auth-remaining.sh" 2>/dev/null)

if [[ "$auth_remaining" == "expired" ]]; then
    auth_pill=$(printf " ${FG_RED}${ICON_LROUND}${BG_RED}${FG_CRUST}${BOLD} ${ICON_LOCK} EXPIRED ${RST}${FG_RED}${ICON_RROUND}${RST}")
elif [[ "$auth_remaining" =~ ^[0-9]+$ ]] && ((auth_remaining <= 60)); then
    if ((auth_remaining <= 10)); then
        # Peach bold — urgent
        auth_pill=$(printf " ${FG_PEACH}${ICON_LROUND}${BG_PEACH}${FG_CRUST}${BOLD} ${ICON_LOCK} ${auth_remaining}m ${RST}${FG_PEACH}${ICON_RROUND}${RST}")
    elif ((auth_remaining <= 30)); then
        # Yellow — attention
        auth_pill=$(printf " ${FG_YELLOW}${ICON_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_LOCK} ${auth_remaining}m ${RST}${FG_YELLOW}${ICON_RROUND}${RST}")
    else
        # Subtext on surface1 — muted informational
        auth_pill=$(printf " ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_SUBTEXT} ${ICON_LOCK} ${auth_remaining}m ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}")
    fi
fi
# If >60m or unknown, auth_pill stays empty (hidden)

# ── RENDER PILLS ────────────────────────────────────────────

# Pill 1: State/Model (conditional — yellow state pill when working, mauve model pill when idle)
if [[ "$tool_state" == "working" ]]; then
    printf " ${FG_YELLOW}${ICON_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_ZAP} ${formatted_tool_name} ${RST}${FG_YELLOW}${ICON_RROUND}${RST}"
else
    printf " ${FG_MAUVE}${ICON_LROUND}${BG_MAUVE}${FG_CRUST} ${ICON_ROBOT} ${model_name} ${RST}${FG_MAUVE}${ICON_RROUND}${RST}"
fi

# Pill 2: Context bar (surface1 bg)
printf " ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1} ${blue_part}${teal_part}${gray_part} ${pct_color}${pct_int}%% ${RST}${BG_SURFACE1}${compact_label}${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"

# Pill 3: Metrics (surface1 bg)
printf " ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_GREEN} ${cost_display} ${FG_OVERLAY}${session_time} ${FG_OVERLAY}${lines_display} ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"

# Pill 4: Auth (conditional)
printf "${auth_pill}"

printf "\n"
