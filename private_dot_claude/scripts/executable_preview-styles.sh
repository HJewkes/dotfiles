#!/bin/bash
# Preview: Hybrid Pills + Grouped Powerline prompt design
# Uses printf for all special characters to avoid encoding issues

RST="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Catppuccin Mocha palette
BG_SURFACE0="\033[48;2;49;50;68m"
BG_SURFACE1="\033[48;2;69;71;90m"
BG_BLUE="\033[48;2;137;180;250m"
BG_GREEN="\033[48;2;166;227;161m"
BG_YELLOW="\033[48;2;249;226;175m"
BG_PEACH="\033[48;2;250;179;135m"
BG_TEAL="\033[48;2;148;226;213m"
BG_MAUVE="\033[48;2;203;166;247m"
BG_RED="\033[48;2;243;139;168m"
BG_SKY="\033[48;2;137;220;235m"

FG_CRUST="\033[38;2;17;17;27m"
FG_SURFACE0="\033[38;2;49;50;68m"
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
FG_SKY="\033[38;2;137;220;235m"
FG_LAVENDER="\033[38;2;180;190;254m"

# Icons via printf (avoids encoding issues)
ICON_BRANCH=$(printf '\ue0a0')
ICON_LOCK=$(printf '\uf023')
ICON_ROBOT=$(printf '\uf498')
ICON_PL_RROUND=$(printf '\ue0b4')
ICON_PL_LROUND=$(printf '\ue0b6')
ICON_CHEVRON=$(printf '\u276f')
ICON_PLUS=$(printf '\u271a')
ICON_DOT=$(printf '\u25cf')
ICON_K8S=$(printf '\u2638')
ICON_GEAR=$(printf '\u2699')
ICON_TIMER=$(printf '\uf252')

clear
echo ""
printf "${BOLD}${FG_MAUVE}  %s${RST}\n" "╭──────────────────────────────────────────────────────────────╮"
printf "${BOLD}${FG_MAUVE}  %s${RST}\n" "│            HYBRID: PILLS + GROUPED POWERLINE                 │"
printf "${BOLD}${FG_MAUVE}  %s${RST}\n" "╰──────────────────────────────────────────────────────────────╯"
echo ""

# ── SEGMENT REFERENCE ────────────────────────────────────────
printf "${BOLD}${FG_LAVENDER}  %s${RST}\n" "SEGMENT ORDER & GROUPING"
echo ""
printf "${FG_OVERLAY}  %s${RST}\n" "  #  Segment              Group          Visibility"
printf "${FG_OVERLAY}  %s${RST}\n" "  ── ──────────────────── ────────────── ──────────────────────────"
printf "${FG_SUBTEXT}  %s${RST}\n" "  1  Time                 solo           always"
printf "${FG_SUBTEXT}  %s${RST}\n" "  2  K8s context          ctx-group      contextual (not dev-core-0)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  3  Remote hostname      ctx-group      contextual (\$SSH_CONNECTION)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  4  Background jobs      ctx-group      contextual (>0 jobs)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  5  Directory            solo           always"
printf "${FG_SUBTEXT}  %s${RST}\n" "  6  Git branch           git-group      always (in git repo)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  7  Worktree             git-group      contextual (in worktree)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  8  Git dirty status     git-group      contextual (when dirty)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  9  Auth countdown       solo           contextual (<60m remaining)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  10 Error code           cmd-group      contextual (exit != 0)"
printf "${FG_SUBTEXT}  %s${RST}\n" "  11 Command duration     cmd-group      contextual (>2s)"
echo ""

# ── TERMINAL PROMPT ──────────────────────────────────────────
printf "${BOLD}${FG_LAVENDER}  %s${RST}\n" "┌ TERMINAL PROMPT (Starship)"
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# Minimal: time, dir, git - all solo
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Minimal (clean repo, local, no warnings):"
printf "${FG_OVERLAY}  │  "
printf "  ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} 14:32 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_BLUE}${ICON_PL_LROUND}${BG_BLUE}${FG_CRUST} ~/projects/app ${RST}${FG_BLUE}${ICON_PL_RROUND}${RST}"
printf " ${FG_GREEN}${ICON_PL_LROUND}${BG_GREEN}${FG_CRUST} ${ICON_BRANCH} stable ${RST}${FG_GREEN}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${FG_MAUVE}${ICON_CHEVRON}${RST}\n"

# Dirty + auth + job
printf "${FG_OVERLAY}  %s${RST}\n" "│"
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Dirty repo + auth warning + background job:"
printf "${FG_OVERLAY}  │  "
printf "  ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} 14:32 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_TEAL}${ICON_PL_LROUND}${BG_TEAL}${FG_CRUST} ${ICON_GEAR}1 ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_BLUE}${ICON_PL_LROUND}${BG_BLUE}${FG_CRUST} ~/projects/app ${RST}${FG_BLUE}${ICON_PL_RROUND}${RST}"
printf " ${FG_GREEN}${ICON_PL_LROUND}${BG_GREEN}${FG_CRUST} ${ICON_BRANCH} stable ${FG_GREEN}${BG_YELLOW}${ICON_PL_RROUND}${BG_YELLOW}${FG_CRUST} ${ICON_PLUS}2 ${ICON_DOT}3 ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf " ${FG_PEACH}${ICON_PL_LROUND}${BG_PEACH}${FG_CRUST} ${ICON_LOCK} 8m ${RST}${FG_PEACH}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${FG_MAUVE}${ICON_CHEVRON}${RST}\n"

# Full: everything visible
printf "${FG_OVERLAY}  %s${RST}\n" "│"
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Full (all segments active):"
printf "${FG_OVERLAY}  │  "
printf "  ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} 14:32 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_MAUVE}${ICON_PL_LROUND}${BG_MAUVE}${FG_CRUST} ${ICON_K8S} prod/api ${FG_MAUVE}${BG_SURFACE1}${ICON_PL_RROUND}${BG_SURFACE1}${FG_SUBTEXT} dev-host ${FG_SURFACE1}${BG_TEAL}${ICON_PL_RROUND}${BG_TEAL}${FG_CRUST} ${ICON_GEAR}2 ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_BLUE}${ICON_PL_LROUND}${BG_BLUE}${FG_CRUST} ~/projects/app ${RST}${FG_BLUE}${ICON_PL_RROUND}${RST}"
printf " ${FG_GREEN}${ICON_PL_LROUND}${BG_GREEN}${FG_CRUST} ${ICON_BRANCH} stable ${FG_GREEN}${BG_SKY}${ICON_PL_RROUND}${BG_SKY}${FG_CRUST} wt:feat-auth ${FG_SKY}${BG_YELLOW}${ICON_PL_RROUND}${BG_YELLOW}${FG_CRUST} ${ICON_PLUS}2 ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf " ${FG_RED}${ICON_PL_LROUND}${BG_RED}${FG_CRUST} ${ICON_LOCK} EXPIRED ${RST}${FG_RED}${ICON_PL_RROUND}${RST}"
printf " ${FG_RED}${ICON_PL_LROUND}${BG_RED}${FG_CRUST} ✘ 127 ${FG_RED}${BG_YELLOW}${ICON_PL_RROUND}${BG_YELLOW}${FG_CRUST} 4.2s ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${FG_MAUVE}${ICON_CHEVRON}${RST}\n"

# Failed command: error code + duration grouped
printf "${FG_OVERLAY}  %s${RST}\n" "│"
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Failed slow command (error+duration grouped):"
printf "${FG_OVERLAY}  │  "
printf "  ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} 14:32 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_BLUE}${ICON_PL_LROUND}${BG_BLUE}${FG_CRUST} ~/projects/app ${RST}${FG_BLUE}${ICON_PL_RROUND}${RST}"
printf " ${FG_GREEN}${ICON_PL_LROUND}${BG_GREEN}${FG_CRUST} ${ICON_BRANCH} stable ${RST}${FG_GREEN}${ICON_PL_RROUND}${RST}"
printf " ${FG_RED}${ICON_PL_LROUND}${BG_RED}${FG_CRUST} ✘ 1 ${FG_RED}${BG_YELLOW}${ICON_PL_RROUND}${BG_YELLOW}${FG_CRUST} 12.3s ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${FG_MAUVE}${ICON_CHEVRON}${RST}\n"

# Fast success (nothing extra shown)
printf "${FG_OVERLAY}  %s${RST}\n" "│"
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Fast success (cmd-group hidden, chevron stays green):"
printf "${FG_OVERLAY}  │  "
printf "  ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} 14:32 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_BLUE}${ICON_PL_LROUND}${BG_BLUE}${FG_CRUST} ~/projects/app ${RST}${FG_BLUE}${ICON_PL_RROUND}${RST}"
printf " ${FG_GREEN}${ICON_PL_LROUND}${BG_GREEN}${FG_CRUST} ${ICON_BRANCH} stable ${RST}${FG_GREEN}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${FG_MAUVE}${ICON_CHEVRON}${RST}\n"

# Slow success (only duration, no error)
printf "${FG_OVERLAY}  %s${RST}\n" "│"
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Slow success (duration only, no error code):"
printf "${FG_OVERLAY}  │  "
printf "  ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} 14:32 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_BLUE}${ICON_PL_LROUND}${BG_BLUE}${FG_CRUST} ~/projects/app ${RST}${FG_BLUE}${ICON_PL_RROUND}${RST}"
printf " ${FG_GREEN}${ICON_PL_LROUND}${BG_GREEN}${FG_CRUST} ${ICON_BRANCH} stable ${RST}${FG_GREEN}${ICON_PL_RROUND}${RST}"
printf " ${FG_YELLOW}${ICON_PL_LROUND}${BG_YELLOW}${FG_CRUST} 4.2s ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${FG_MAUVE}${ICON_CHEVRON}${RST}\n"

printf "${FG_OVERLAY}  %s${RST}\n" "└────"
echo ""

# ── CLAUDE CODE STATUSLINE ───────────────────────────────────
printf "${BOLD}${FG_MAUVE}  %s${RST}\n" "╭──────────────────────────────────────────────────────────────────────────────╮"
printf "${BOLD}${FG_MAUVE}  %s${RST}\n" "│                       CLAUDE CODE STATUSLINE                                │"
printf "${BOLD}${FG_MAUVE}  %s${RST}\n" "╰──────────────────────────────────────────────────────────────────────────────╯"
echo ""

ICON_ZAP=$(printf '\u26a1')
ICON_HOUR=$(printf '\u23f3')
ICON_CYCLE=$(printf '\u21bb')
ICON_PEOPLE=$(printf '\uf0c0')
ICON_PENCIL=$(printf '\uf040')
ICON_CODE=$(printf '\uf121')

# ── DESIGN PRINCIPLES ──────────────────────────────────────
printf "${BOLD}${FG_LAVENDER}  %s${RST}\n" "DESIGN PRINCIPLES"
echo ""
printf "${FG_OVERLAY}  %s${RST}\n" "  The statusline lives in the Claude TUI footer — a calm, persistent dashboard."
printf "${FG_OVERLAY}  %s${RST}\n" "  Same floating pill language as the terminal prompt for visual consistency."
echo ""
printf "${FG_OVERLAY}  %s${RST}\n" "  1. Floating pills — solo capsules for independent zones"
printf "${FG_OVERLAY}  %s${RST}\n" "     Each zone is a self-contained pill against the terminal background."
printf "${FG_OVERLAY}  %s${RST}\n" "  2. Grouped powerline — connected segments within a zone"
printf "${FG_OVERLAY}  %s${RST}\n" "     Related info (cost+time+lines) shares one pill via transitions."
printf "${FG_OVERLAY}  %s${RST}\n" "  3. Visual hierarchy through color intensity"
printf "${FG_OVERLAY}  %s${RST}\n" "     Bright = needs attention. Dim = reference info. Color = category."
printf "${FG_OVERLAY}  %s${RST}\n" "  4. Contextual density — pills appear/disappear as relevant"
printf "${FG_OVERLAY}  %s${RST}\n" "     A simple session shows 3 pills. A complex one shows 6."
echo ""

# ── CONTEXT BAR LEGEND ──────────────────────────────────────
printf "${BOLD}${FG_LAVENDER}  %s${RST}\n" "CONTEXT BAR"
echo ""
printf "${FG_OVERLAY}  %s${RST}\n" "  Bar = cached vs new context.  %% color = urgency."
printf "  ${FG_BLUE}██${RST} ${DIM}${FG_OVERLAY}cached (prior turns)${RST}  "
printf "${FG_TEAL}██${RST} ${DIM}${FG_OVERLAY}new (this turn)${RST}  "
printf "${FG_OVERLAY}░░${RST} ${DIM}${FG_OVERLAY}free${RST}\n"
echo ""

# ── FINAL STATUSLINE EXAMPLES ───────────────────────────────
printf "${BOLD}${FG_LAVENDER}  %s${RST}\n" "┌ FINAL EXAMPLES"
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# ── 1. Minimal: idle, early session, nothing special ────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Minimal — idle, early session:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_MAUVE}${ICON_PL_LROUND}${BG_MAUVE}${FG_CRUST} ${ICON_ROBOT} opus 4 ${RST}${FG_MAUVE}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}██████${FG_TEAL}██${FG_OVERLAY}░░░░░░░░░░░░ ${FG_BLUE}38%% ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$1.84 ${FG_OVERLAY}12m ${FG_OVERLAY}+47 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  ${DIM}${FG_OVERLAY}%s${RST}\n" "  [model pill]  [context pill]  [metrics pill]"
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# ── 2. Active: working on task, mid-session ─────────────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Active — working on a task:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_YELLOW}${ICON_PL_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_ZAP} Editing 2 files ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf " ${FG_TEAL}${ICON_PL_LROUND}${BG_TEAL}${FG_CRUST} #3 Add auth ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}██████████${FG_TEAL}██${FG_OVERLAY}░░░░░░░░ ${FG_BLUE}58%% ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$4.52 ${FG_OVERLAY}38m ${FG_OVERLAY}+143 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_SUBTEXT} ${ICON_LOCK} 47m ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  ${DIM}${FG_OVERLAY}%s${RST}\n" "  [state]  [task]  [context]  [metrics]  [auth]"
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# ── 3. Waiting for input ────────────────────────────────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Blocked — waiting for user input:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_PEACH}${ICON_PL_LROUND}${BG_PEACH}${FG_CRUST}${BOLD} ${ICON_HOUR} Waiting for input ${RST}${FG_PEACH}${ICON_PL_RROUND}${RST}"
printf " ${FG_TEAL}${ICON_PL_LROUND}${BG_TEAL}${FG_CRUST} #3 Add auth ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}███████████${FG_TEAL}█${FG_OVERLAY}░░░░░░░░ ${FG_BLUE}60%% ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$4.88 ${FG_OVERLAY}42m ${FG_OVERLAY}+158 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  ${DIM}${FG_OVERLAY}%s${RST}\n" "  ^ peach pill catches your eye — \"Claude needs you\""
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# ── 4. Team with agents ─────────────────────────────────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Team — agents running:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_YELLOW}${ICON_PL_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_ZAP} Running tests ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf " ${FG_SKY}${ICON_PL_LROUND}${BG_SKY}${FG_CRUST} ${ICON_PEOPLE} explorer${FG_GREEN}${ICON_DOT}${FG_CRUST} builder${FG_GREEN}${ICON_DOT}${FG_CRUST} tester${FG_YELLOW}${ICON_DOT}${FG_CRUST} ${RST}${FG_SKY}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}█████████████${FG_TEAL}██${FG_OVERLAY}░░░░░ ${FG_YELLOW}74%% ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$12.41 ${FG_OVERLAY}1h 8m ${FG_OVERLAY}+323 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  ${DIM}${FG_OVERLAY}%s${RST}\n" "  dots: ${FG_GREEN}${ICON_DOT}${RST}${DIM}${FG_OVERLAY}=active  ${FG_YELLOW}${ICON_DOT}${RST}${DIM}${FG_OVERLAY}=idle  ${FG_RED}${ICON_DOT}${RST}${DIM}${FG_OVERLAY}=error"
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# ── 5. Long session, approaching compaction ─────────────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Deep session — compaction approaching:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_YELLOW}${ICON_PL_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_ZAP} Grep search ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf " ${FG_TEAL}${ICON_PL_LROUND}${BG_TEAL}${FG_CRUST} #7 Refactor handlers ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}████████████████${FG_TEAL}█${FG_OVERLAY}░░ ${BOLD}${FG_PEACH}91%% ${RST}${BG_SURFACE1}${FG_PEACH}compact ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$28.01 ${FG_OVERLAY}4h 26m ${FG_OVERLAY}+473 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_YELLOW}${ICON_PL_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_LOCK} 18m ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  ${DIM}${FG_OVERLAY}%s${RST}\n" "  ^ \"compact\" label in context pill when exceeds_200k_tokens"
printf "${FG_OVERLAY}  %s${RST}\n" "│"

# ── 6. Compacting ───────────────────────────────────────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Compacting — context being summarized:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_SKY}${ICON_PL_LROUND}${BG_SKY}${FG_CRUST} ${ICON_CYCLE} Compacting... ${RST}${FG_SKY}${ICON_PL_RROUND}${RST}"
printf " ${FG_TEAL}${ICON_PL_LROUND}${BG_TEAL}${FG_CRUST} #7 Refactor handlers ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}█████████████████${FG_TEAL}██░ ${FG_SKY}96%% ${ICON_CYCLE} ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$29.50 ${FG_OVERLAY}4h 30m ${FG_OVERLAY}+480 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │\n"

# ── 7. Heavy turn ───────────────────────────────────────────
printf "${FG_OVERLAY}  │  ${FG_SUBTEXT}%s${RST}\n" "Heavy turn — big file read spiked context:"
printf "${FG_OVERLAY}  │\n"
printf "${FG_OVERLAY}  │  "
printf " ${FG_YELLOW}${ICON_PL_LROUND}${BG_YELLOW}${FG_CRUST} ${ICON_ZAP} Reading file ${RST}${FG_YELLOW}${ICON_PL_RROUND}${RST}"
printf " ${FG_TEAL}${ICON_PL_LROUND}${BG_TEAL}${FG_CRUST} #5 Debug auth flow ${RST}${FG_TEAL}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1} ${FG_BLUE}█████████${FG_TEAL}█████████${FG_OVERLAY}░░ ${BOLD}${FG_PEACH}88%% ${RST}${BG_SURFACE1}${FG_PEACH}compact ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf " ${FG_SURFACE1}${ICON_PL_LROUND}${BG_SURFACE1}${FG_GREEN} \$6.30 ${FG_OVERLAY}52m ${FG_OVERLAY}+83 ${RST}${FG_SURFACE1}${ICON_PL_RROUND}${RST}"
printf "\n"
printf "${FG_OVERLAY}  │  ${DIM}${FG_OVERLAY}%s${RST}\n" "  ^ large teal in bar = this turn ate a lot of context"

printf "${FG_OVERLAY}  %s${RST}\n" "│"
printf "${FG_OVERLAY}  %s${RST}\n" "└────"
echo ""

# ── AUTH COUNTDOWN (shared with terminal prompt) ─────────────
printf "${BOLD}${FG_LAVENDER}  %s${RST}\n" "AUTH COUNTDOWN (both surfaces)"
echo ""
printf "${FG_OVERLAY}  %s${RST}\n" "  Same escalation in terminal prompt and Claude statusline:"
echo ""
printf "  ${FG_OVERLAY}%-18s${RST} ${DIM}${FG_OVERLAY}%s${RST}\n" "hidden" "hidden when >60m remaining"
printf "  ${FG_SUBTEXT}${ICON_LOCK} 47m${RST}            ${DIM}${FG_OVERLAY}%s${RST}\n" "muted at 60m"
printf "  ${FG_YELLOW}${ICON_LOCK} 18m${RST}            ${DIM}${FG_OVERLAY}%s${RST}\n" "yellow at 30m"
printf "  ${BOLD}${FG_PEACH}${ICON_LOCK} 4m${RST}             ${DIM}${FG_OVERLAY}%s${RST}\n" "peach bold at 10m"
printf "  ${BOLD}${FG_RED}${ICON_LOCK} EXPIRED${RST}        ${DIM}${FG_OVERLAY}%s${RST}\n" "red when expired"
echo ""
