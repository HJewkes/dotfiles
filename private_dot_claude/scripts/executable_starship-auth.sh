#!/bin/bash
# Starship custom module: auth countdown pill with color escalation
# Reads token_issued_at from status-cache and shows remaining time.
# Hidden when >60m remaining or when token file is missing.
# Uses \x hex escapes for compatibility with macOS system bash (3.2).

# Catppuccin Mocha ANSI colors
RST="\033[0m"
BOLD="\033[1m"
FG_CRUST="\033[38;2;17;17;27m"
FG_SUBTEXT="\033[38;2;166;173;200m"
FG_YELLOW="\033[38;2;249;226;175m"
FG_PEACH="\033[38;2;250;179;135m"
FG_RED="\033[38;2;243;139;168m"
BG_SUBTEXT="\033[48;2;166;173;200m"
BG_YELLOW="\033[48;2;249;226;175m"
BG_PEACH="\033[48;2;250;179;135m"
BG_RED="\033[48;2;243;139;168m"

# Icons via hex escapes (compatible with bash 3.2+)
# U+E0B6 (left round cap)
LROUND='\xEE\x82\xB6'
# U+E0B4 (right round cap)
RROUND='\xEE\x82\xB4'
# U+F023 (lock icon)
LOCK_ICON='\xEF\x80\xA3'

CACHE_FILE="$HOME/.claude/status-cache/token_issued_at"
TTL=7200

# Exit if no token file
if [[ ! -f "$CACHE_FILE" ]]; then
    exit 0
fi

issued_at=$(cat "$CACHE_FILE" 2>/dev/null)
if [[ -z "$issued_at" ]]; then
    exit 0
fi

now=$(date +%s)
expires_at=$((issued_at + TTL))
remaining_sec=$((expires_at - now))
remaining_min=$((remaining_sec / 60))

# Hidden when >60m remaining
if [[ $remaining_sec -gt 3600 ]]; then
    exit 0
fi

# Determine color and content based on escalation
if [[ $remaining_sec -le 0 ]]; then
    # Expired: red bold
    pill_fg="$FG_RED"
    pill_bg="$BG_RED"
    text_style="${BOLD}${FG_CRUST}"
    content=" ${LOCK_ICON} EXPIRED "
elif [[ $remaining_min -lt 10 ]]; then
    # 10m-0m: peach bold
    pill_fg="$FG_PEACH"
    pill_bg="$BG_PEACH"
    text_style="${BOLD}${FG_CRUST}"
    content=" ${LOCK_ICON} ${remaining_min}m "
elif [[ $remaining_min -lt 30 ]]; then
    # 30m-10m: yellow
    pill_fg="$FG_YELLOW"
    pill_bg="$BG_YELLOW"
    text_style="${FG_CRUST}"
    content=" ${LOCK_ICON} ${remaining_min}m "
else
    # 60m-30m: subtext (muted)
    pill_fg="$FG_SUBTEXT"
    pill_bg="$BG_SUBTEXT"
    text_style="${FG_CRUST}"
    content=" ${LOCK_ICON} ${remaining_min}m "
fi

printf '%b' "${pill_fg}${LROUND}${pill_bg}${text_style}${content}${RST}${pill_fg}${RROUND}${RST}"
