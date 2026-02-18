#!/bin/bash
# Starship custom module: git-group pill (branch + worktree + dirty)
# Outputs pre-formatted ANSI text for a grouped powerline pill.
# Only outputs if inside a git repository.
# Uses \x hex escapes for compatibility with macOS system bash (3.2).

# Catppuccin Mocha ANSI colors
RST="\033[0m"
FG_CRUST="\033[38;2;17;17;27m"
FG_GREEN="\033[38;2;166;227;161m"
FG_YELLOW="\033[38;2;249;226;175m"
FG_SKY="\033[38;2;137;220;235m"
BG_GREEN="\033[48;2;166;227;161m"
BG_YELLOW="\033[48;2;249;226;175m"
BG_SKY="\033[48;2;137;220;235m"

# Icons via hex escapes (compatible with bash 3.2+)
# U+E0B6 (left round cap)
LROUND='\xEE\x82\xB6'
# U+E0B4 (right round cap)
RROUND='\xEE\x82\xB4'
# U+E0A0 (branch icon)
BRANCH_ICON='\xEE\x82\xA0'
# U+271A (plus icon)
PLUS_ICON='\xE2\x9C\x9A'
# U+25CF (dot icon)
DOT_ICON='\xE2\x97\x8F'

# Branch: exit if not in a git repo
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ -z "$branch" ]]; then
    exit 0
fi

# Collect segments: each entry is "color_name|content"
segments=()

# Branch segment (always present in git repo)
segments+=("green| ${BRANCH_ICON} ${branch} ")

# Worktree: check if in a worktree
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
git_dir=$(git rev-parse --git-dir 2>/dev/null)
if [[ -n "$git_common_dir" && -n "$git_dir" && "$git_common_dir" != "$git_dir" ]]; then
    # Extract worktree name from the working directory
    wt_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
    segments+=("sky| wt:${wt_name} ")
fi

# Dirty status: use --untracked-files=no for monorepo performance
porcelain=$(git status --porcelain --untracked-files=no 2>/dev/null)
if [[ -n "$porcelain" ]]; then
    staged=0
    modified=0
    while IFS= read -r line; do
        # First char: staged status (index)
        x="${line:0:1}"
        # Second char: worktree status
        y="${line:1:1}"
        case "$x" in
            [MADRC]) staged=$((staged + 1)) ;;
        esac
        case "$y" in
            [MADRC]) modified=$((modified + 1)) ;;
        esac
    done <<< "$porcelain"

    dirty_content=""
    if [[ $staged -gt 0 ]]; then
        dirty_content+="${PLUS_ICON}${staged}"
    fi
    if [[ $modified -gt 0 ]]; then
        [[ -n "$dirty_content" ]] && dirty_content+=" "
        dirty_content+="${DOT_ICON}${modified}"
    fi
    if [[ -n "$dirty_content" ]]; then
        segments+=("yellow| ${dirty_content} ")
    fi
fi

# Map color names to ANSI codes
get_fg() {
    case "$1" in
        green)  printf '%s' "$FG_GREEN" ;;
        sky)    printf '%s' "$FG_SKY" ;;
        yellow) printf '%s' "$FG_YELLOW" ;;
    esac
}
get_bg() {
    case "$1" in
        green)  printf '%s' "$BG_GREEN" ;;
        sky)    printf '%s' "$BG_SKY" ;;
        yellow) printf '%s' "$BG_YELLOW" ;;
    esac
}

# Build output
output=""
for i in "${!segments[@]}"; do
    IFS='|' read -r color content <<< "${segments[$i]}"
    fg=$(get_fg "$color")
    bg=$(get_bg "$color")

    if [[ $i -eq 0 ]]; then
        # First segment: left round cap
        output+="${fg}${LROUND}${bg}${FG_CRUST}${content}"
    else
        # Transition from previous segment
        IFS='|' read -r prev_color _ <<< "${segments[$((i-1))]}"
        prev_fg=$(get_fg "$prev_color")
        output+="${prev_fg}${bg}${RROUND}${FG_CRUST}${content}"
    fi
done

# Final right round cap
last_idx=$(( ${#segments[@]} - 1 ))
IFS='|' read -r last_color _ <<< "${segments[$last_idx]}"
last_fg=$(get_fg "$last_color")
output+="${RST}${last_fg}${RROUND}${RST}"

printf '%b' "$output"
