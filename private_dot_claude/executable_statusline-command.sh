#!/bin/zsh
# Claude Code TUI statusline — renders floating pills for the footer
# Called by Claude Code on every statusline refresh, receives JSON via stdin
# Renders: git pill, context bar pill, rate limit pill, metrics pill, auth pill, session pill

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
ICON_GIT=$(printf '\ue0a0')
ICON_WARN=$(printf '\uf071')
ICON_FOLDER=$(printf '\uf07b')

# ── Read stdin ──────────────────────────────────────────────
input=$(cat)

# ── Parse all JSON fields in a single jq call ───────────────
read -r model_id used_pct cache_read cache_create ctx_size duration_ms lines_add lines_rm exceeds_200k session_id <<< \
  $(echo "$input" | jq -r '[
    (if (.model.id // "" | length) > 0 then .model.id else "unknown" end),
    .context_window.used_percentage // 0,
    .context_window.current_usage.cache_read_input_tokens // 0,
    .context_window.current_usage.cache_creation_input_tokens // 0,
    .context_window.context_window_size // 200000,
    .cost.total_duration_ms // 0,
    .cost.total_lines_added // 0,
    .cost.total_lines_removed // 0,
    .exceeds_200k_tokens // false,
    .session_id // "unknown"
  ] | @tsv' 2>/dev/null)

# ── Fallbacks for empty/malformed input ─────────────────────
[[ -z "$model_id" ]] && model_id="unknown"
[[ -z "$used_pct" || "$used_pct" == "null" ]] && used_pct=0
[[ -z "$cache_read" || "$cache_read" == "null" ]] && cache_read=0
[[ -z "$cache_create" || "$cache_create" == "null" ]] && cache_create=0
[[ -z "$ctx_size" || "$ctx_size" == "null" || "$ctx_size" == "0" ]] && ctx_size=200000
[[ -z "$duration_ms" || "$duration_ms" == "null" ]] && duration_ms=0
[[ -z "$lines_add" || "$lines_add" == "null" ]] && lines_add=0
[[ -z "$lines_rm" || "$lines_rm" == "null" ]] && lines_rm=0
[[ -z "$exceeds_200k" || "$exceeds_200k" == "null" ]] && exceeds_200k="false"
[[ -z "$session_id" || "$session_id" == "null" ]] && session_id="unknown"

# ── MODEL NAME PARSING ──────────────────────────────────────
parse_model_name() {
    local id="$1"
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

    if ((count >= 2)); then
        echo "${parts[$((count-2))]} ${parts[$((count-1))]}"
    elif ((count == 1)); then
        echo "${parts[0]}"
    else
        echo "unknown"
    fi
}

model_name=$(parse_model_name "$model_id")

# ── GIT STATE DETECTION ────────────────────────────────────
detect_git_state() {
    local git_dir
    git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || { echo "||||"; return; }

    local repo branch worktree="" state="ok" state_detail=""

    repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    local common_dir
    common_dir=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd -P)
    if [[ "$git_dir" != "$common_dir" ]]; then
        worktree=$(basename "$(pwd)")
    fi

    # Tier A: filesystem checks (sub-millisecond)
    if [[ -f "$git_dir/index.lock" ]]; then
        state="LOCK"
    elif [[ -d "$git_dir/rebase-merge" ]]; then
        state="REBASE"
        local cur total
        cur=$(cat "$git_dir/rebase-merge/msgnum" 2>/dev/null)
        total=$(cat "$git_dir/rebase-merge/end" 2>/dev/null)
        [[ -n "$cur" && -n "$total" ]] && state_detail="${cur}/${total}"
    elif [[ -d "$git_dir/rebase-apply" ]]; then
        if [[ -f "$git_dir/rebase-apply/applying" ]]; then
            state="AM"
        else
            state="REBASE"
        fi
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        state="MERGE"
    elif [[ -z "$branch" ]]; then
        state="DETACHED"
        branch=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        state="CHERRY-PICK"
    elif [[ -f "$git_dir/BISECT_LOG" ]]; then
        state="BISECT"
    elif [[ -f "$git_dir/REVERT_HEAD" ]]; then
        state="REVERT"
    fi

    # Tier B: git status for conflicts + upstream
    local status_output
    status_output=$(git status --porcelain=v2 --branch 2>/dev/null)

    local conflict_count=0
    conflict_count=$(grep -c "^u " <<< "$status_output" 2>/dev/null) || conflict_count=0
    if (( conflict_count > 0 )) && [[ "$state" != "LOCK" ]]; then
        state="CONFLICT"
        state_detail="$conflict_count"
    fi

    if [[ "$state" == "ok" ]]; then
        local ab_line upstream_line
        ab_line=$(grep "^# branch.ab" <<< "$status_output")
        upstream_line=$(grep "^# branch.upstream" <<< "$status_output")

        if [[ -z "$upstream_line" && "$branch" != "main" && "$branch" != "master" ]]; then
            state="NO-UPSTREAM"
        elif [[ -n "$ab_line" ]]; then
            local ahead behind
            ahead=$(awk '{print $3}' <<< "$ab_line" | tr -d '+')
            behind=$(awk '{print $4}' <<< "$ab_line" | tr -d '-')
            if (( ahead > 0 && behind > 0 )); then
                state="DIVERGED"
                state_detail="+${ahead}/-${behind}"
            fi
        fi
    fi

    echo "${repo}|${branch}|${worktree}|${state}|${state_detail}"
}

# ── RATE LIMIT DATA ────────────────────────────────────────
rate_data=$("$HOME/.claude/scripts/rate-limits.sh" 2>/dev/null)
IFS='|' read -r rate_5hr rate_weekly rate_5hr_reset rate_weekly_reset <<< "$rate_data"
[[ -z "$rate_5hr" ]] && rate_5hr="unknown"
[[ -z "$rate_weekly" ]] && rate_weekly="unknown"

pct_to_bar() {
    local pct="$1"
    if [[ "$pct" == "unknown" || -z "$pct" ]]; then printf '\u2500'; return; fi
    if (( pct >= 95 )); then printf '\u2588'
    elif (( pct >= 85 )); then printf '\u2587'
    elif (( pct >= 75 )); then printf '\u2586'
    elif (( pct >= 60 )); then printf '\u2585'
    elif (( pct >= 45 )); then printf '\u2584'
    elif (( pct >= 30 )); then printf '\u2583'
    elif (( pct >= 15 )); then printf '\u2582'
    else printf '\u2581'
    fi
}

pct_to_color() {
    local pct="$1"
    if [[ "$pct" == "unknown" || -z "$pct" ]]; then echo "$FG_OVERLAY"; return; fi
    if (( pct >= 90 )); then echo "${BOLD}${FG_RED}"
    elif (( pct >= 80 )); then echo "$FG_PEACH"
    elif (( pct >= 60 )); then echo "$FG_YELLOW"
    else echo "$FG_GREEN"
    fi
}

# ── CONTEXT BAR ─────────────────────────────────────────────
BAR_WIDTH=20
total_used=$((cache_read + cache_create))

if ((total_used > 0)); then
    blue_blocks=$((cache_read * BAR_WIDTH / ctx_size))
    teal_blocks=$((cache_create * BAR_WIDTH / ctx_size))
else
    blue_blocks=$((used_pct * BAR_WIDTH / 100))
    teal_blocks=0
fi

if ((cache_read > 0 && blue_blocks == 0)); then
    blue_blocks=1
fi
if ((cache_create > 0 && teal_blocks == 0)); then
    teal_blocks=1
fi

if ((blue_blocks + teal_blocks > BAR_WIDTH)); then
    teal_blocks=$((BAR_WIDTH - blue_blocks))
    if ((teal_blocks < 0)); then
        teal_blocks=0
        blue_blocks=$BAR_WIDTH
    fi
fi

gray_blocks=$((BAR_WIDTH - blue_blocks - teal_blocks))
if ((gray_blocks < 0)); then gray_blocks=0; fi

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

pct_int=${used_pct%.*}
if ((pct_int > 85)); then
    pct_color="${BOLD}${FG_PEACH}"
elif ((pct_int >= 70)); then
    pct_color="${FG_YELLOW}"
else
    pct_color="${FG_BLUE}"
fi

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

# ── AUTH PILL ───────────────────────────────────────────────
auth_pill=""
auth_remaining=$("$HOME/.claude/scripts/auth-remaining.sh" 2>/dev/null)

if [[ "$auth_remaining" == "expired" ]]; then
    auth_pill=$(printf " ${FG_RED}${ICON_LROUND}${BG_RED}${FG_CRUST}${BOLD} ${ICON_LOCK} EXPIRED ${RST}${FG_RED}${ICON_RROUND}${RST}")
elif [[ "$auth_remaining" =~ ^[0-9]+$ ]] && ((auth_remaining <= 60)); then
    if ((auth_remaining <= 10)); then
        auth_pill=$(printf " ${FG_PEACH}${ICON_LROUND}${BG_PEACH}${FG_CRUST}${BOLD} ${ICON_LOCK} ${auth_remaining}m ${RST}${FG_PEACH}${ICON_RROUND}${RST}")
    elif ((auth_remaining <= 30)); then
        auth_pill=$(printf " ${FG_YELLOW}${ICON_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_LOCK} ${auth_remaining}m ${RST}${FG_YELLOW}${ICON_RROUND}${RST}")
    else
        auth_pill=$(printf " ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_SUBTEXT} ${ICON_LOCK} ${auth_remaining}m ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}")
    fi
fi

# ── VISIBLE LENGTH HELPER ──────────────────────────────────────
visible_len() {
    local stripped
    stripped=$(echo -n "$1" | sed $'s/\033\[[0-9;]*m//g')
    echo ${#stripped}
}

# ── TERMINAL WIDTH ────────────────────────────────────────────
term_width=""
_pid=$$
for _i in 1 2 3 4 5; do
    _pid=$(ps -o ppid= -p $_pid 2>/dev/null | tr -d ' ')
    [[ -z "$_pid" || "$_pid" == "0" || "$_pid" == "1" ]] && break
    _tty=$(ps -o tty= -p $_pid 2>/dev/null | tr -d ' ')
    if [[ -n "$_tty" && "$_tty" != "??" && -e "/dev/$_tty" ]]; then
        term_width=$(stty size < "/dev/$_tty" 2>/dev/null | awk '{print $2}')
        break
    fi
done
[[ -z "$term_width" || "$term_width" == "0" ]] && term_width=120
[[ -n "$STATUSLINE_TEST_WIDTH" ]] && term_width="$STATUSLINE_TEST_WIDTH"

# ── BUILD PILLS ─────────────────────────────────────────────

# Pill 1: Git
IFS='|' read -r git_repo git_branch git_worktree git_state git_state_detail <<< "$(detect_git_state)"

if [[ -z "$git_repo" ]]; then
    dir_name=$(basename "$(pwd)")
    pill1=" ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_SUBTEXT} ${ICON_FOLDER} ${dir_name} ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"
else
    git_label="${git_repo}:${git_branch}"
    git_wt_suffix=""
    [[ -n "$git_worktree" ]] && git_wt_suffix=" [wt:${git_worktree}]"

    case "$git_state" in
        LOCK)
            pill1=" ${FG_RED}${ICON_LROUND}${BG_RED}${FG_CRUST}${BOLD} ${ICON_WARN} LOCK ${git_label} ${RST}${FG_RED}${ICON_RROUND}${RST}"
            ;;
        CONFLICT)
            pill1=" ${FG_RED}${ICON_LROUND}${BG_RED}${FG_CRUST}${BOLD} ${ICON_WARN} CONFLICT ${git_label} ${RST}${FG_RED}${ICON_RROUND}${RST}"
            ;;
        REBASE)
            rebase_info="REBASE"
            [[ -n "$git_state_detail" ]] && rebase_info="REBASE ${git_state_detail}"
            pill1=" ${FG_PEACH}${ICON_LROUND}${BG_PEACH}${FG_CRUST} ${ICON_GIT} ${git_label} ${rebase_info} ${RST}${FG_PEACH}${ICON_RROUND}${RST}"
            ;;
        MERGE)
            pill1=" ${FG_YELLOW}${ICON_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_GIT} ${git_label} MERGE ${RST}${FG_YELLOW}${ICON_RROUND}${RST}"
            ;;
        DETACHED)
            pill1=" ${FG_PEACH}${ICON_LROUND}${BG_PEACH}${FG_CRUST} ${ICON_GIT} ${git_repo}:${git_branch} DETACHED ${RST}${FG_PEACH}${ICON_RROUND}${RST}"
            ;;
        CHERRY-PICK|BISECT|REVERT|AM)
            pill1=" ${FG_YELLOW}${ICON_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_GIT} ${git_label} ${git_state} ${RST}${FG_YELLOW}${ICON_RROUND}${RST}"
            ;;
        DIVERGED)
            pill1=" ${FG_PEACH}${ICON_LROUND}${BG_PEACH}${FG_CRUST} ${ICON_GIT} ${git_label} DIVERGED ${RST}${FG_PEACH}${ICON_RROUND}${RST}"
            ;;
        NO-UPSTREAM)
            pill1=" ${FG_YELLOW}${ICON_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_GIT} ${git_label} NO-UPSTREAM ${RST}${FG_YELLOW}${ICON_RROUND}${RST}"
            ;;
        *)
            pill1=" ${FG_MAUVE}${ICON_LROUND}${BG_MAUVE}${FG_CRUST} ${ICON_GIT} ${git_label}${git_wt_suffix} ${RST}${FG_MAUVE}${ICON_RROUND}${RST}"
            ;;
    esac
fi

# Pill 2: Context bar
pill2=" ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1} ${blue_part}${teal_part}${gray_part} ${pct_color}${pct_int}%% ${RST}${BG_SURFACE1}${compact_label}${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"

# Pill 3: Rate limit
bar_5hr=$(pct_to_bar "$rate_5hr")
bar_weekly=$(pct_to_bar "$rate_weekly")
color_5hr=$(pct_to_color "$rate_5hr")
color_weekly=$(pct_to_color "$rate_weekly")

rate_pct_display=""
if [[ "$rate_5hr" != "unknown" ]] && (( rate_5hr >= 80 )); then
    rate_pct_display=" ${rate_5hr}%%"
fi

pill3=" ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_SUBTEXT} ${model_name} ${color_5hr}${bar_5hr}${color_weekly}${bar_weekly}${rate_pct_display} ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"

# Pill 4: Session metrics
lines_color="$FG_GREEN"
(( net_lines < 0 )) && lines_color="$FG_RED"

pill4=" ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_OVERLAY} ${session_time} ${lines_color}${lines_display} ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"

# Pill 5: Session ID
ICON_HASH=$(printf '\uf489')
pill5=" ${FG_SURFACE1}${ICON_LROUND}${BG_SURFACE1}${FG_OVERLAY} ${ICON_HASH} ${FG_SUBTEXT}${session_id} ${RST}${FG_SURFACE1}${ICON_RROUND}${RST}"

# ── ASSEMBLE ─────────────────────────────────────────────────
left="${pill1}${pill2}${pill3}${pill4}${auth_pill}${pill5}"

# ── BUILD RIGHT PILL ──────────────────────────────────────────
right=""

# ── PAD AND RENDER ────────────────────────────────────────────
left_len=$(visible_len "$left")
right_len=$(visible_len "$right")
RIGHT_MARGIN=4
gap=$((term_width - left_len - right_len - RIGHT_MARGIN))

if ((gap < 2)); then
    printf '%b %b\n' "$left" "$right"
else
    padding=$(printf '%*s' "$gap" '')
    printf '%b%s%b\n' "$left" "$padding" "$right"
fi
