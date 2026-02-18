#!/bin/bash
# Starship custom module: ctx-group pill (k8s + hostname + jobs)
# Outputs pre-formatted ANSI text for a grouped powerline pill.
# Only outputs if at least one segment is active.
# Uses \x hex escapes for compatibility with macOS system bash (3.2).

# Catppuccin Mocha ANSI colors
RST="\033[0m"
FG_CRUST="\033[38;2;17;17;27m"
FG_SUBTEXT="\033[38;2;166;173;200m"
FG_MAUVE="\033[38;2;203;166;247m"
FG_SURFACE1="\033[38;2;69;71;90m"
FG_TEAL="\033[38;2;148;226;213m"
BG_MAUVE="\033[48;2;203;166;247m"
BG_SURFACE1="\033[48;2;69;71;90m"
BG_TEAL="\033[48;2;148;226;213m"

# Icons via hex escapes (compatible with bash 3.2+)
# U+E0B6 (left round cap)
LROUND='\xEE\x82\xB6'
# U+E0B4 (right round cap)
RROUND='\xEE\x82\xB4'
# U+2638 (k8s wheel)
K8S_ICON='\xE2\x98\xB8'
# U+2699 (gear)
GEAR_ICON='\xE2\x9A\x99'

# Collect segments: each entry is "color_name|content"
segments=()

# K8s context
if command -v kubectl >/dev/null 2>&1; then
    k8s_ctx=$(kubectl config current-context 2>/dev/null)
    if [[ -n "$k8s_ctx" && "$k8s_ctx" != "dev-core-0" ]]; then
        segments+=("mauve| ${K8S_ICON} ${k8s_ctx} ")
    fi
fi

# Remote hostname (only via SSH)
if [[ -n "$SSH_CONNECTION" ]]; then
    host=$(hostname -s 2>/dev/null || echo "$HOSTNAME")
    segments+=("surface1| ${host} ")
fi

# Background jobs
job_count="${STARSHIP_JOBS_COUNT:-0}"
if [[ "$job_count" -gt 0 ]]; then
    segments+=("teal| ${GEAR_ICON}${job_count} ")
fi

# Exit if nothing to show
if [[ ${#segments[@]} -eq 0 ]]; then
    exit 0
fi

# Map color names to ANSI codes
get_fg() {
    case "$1" in
        mauve)    printf '%s' "$FG_MAUVE" ;;
        surface1) printf '%s' "$FG_SURFACE1" ;;
        teal)     printf '%s' "$FG_TEAL" ;;
    esac
}
get_bg() {
    case "$1" in
        mauve)    printf '%s' "$BG_MAUVE" ;;
        surface1) printf '%s' "$BG_SURFACE1" ;;
        teal)     printf '%s' "$BG_TEAL" ;;
    esac
}
get_text_fg() {
    case "$1" in
        surface1) printf '%s' "$FG_SUBTEXT" ;;
        *)        printf '%s' "$FG_CRUST" ;;
    esac
}

# Build output
output=""
for i in "${!segments[@]}"; do
    IFS='|' read -r color content <<< "${segments[$i]}"
    fg=$(get_fg "$color")
    bg=$(get_bg "$color")
    text_fg=$(get_text_fg "$color")

    if [[ $i -eq 0 ]]; then
        # First segment: left round cap
        output+="${fg}${LROUND}${bg}${text_fg}${content}"
    else
        # Transition from previous segment
        IFS='|' read -r prev_color _ <<< "${segments[$((i-1))]}"
        prev_fg=$(get_fg "$prev_color")
        output+="${prev_fg}${bg}${RROUND}${text_fg}${content}"
    fi
done

# Final right round cap
last_idx=$(( ${#segments[@]} - 1 ))
IFS='|' read -r last_color _ <<< "${segments[$last_idx]}"
last_fg=$(get_fg "$last_color")
output+="${RST}${last_fg}${RROUND}${RST}"

printf '%b' "$output"
