#!/bin/zsh
# Regression test for the status line's usage sources: renders the
# real script against fixture status files in a throwaway HOME and asserts the
# rendered line. Covers the two regressions seen so far, a shared login shown
# twice and a stale reading shown as current, plus the server glyph, other
# accounts and the Codex pill.
# Run: zsh tests/test_statusline_sources.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/executable_statusline-command.sh"
export STATUSLINE_RATE_LIMITS="$ROOT/private_dot_claude/scripts/executable_rate-limits.sh"
export STATUSLINE_TEST_WIDTH=240
FAILS=0
DEFAULT=$'' AGENTS=$'\U000f06a9' PERSONAL=$'' WORKOUT=$'\U000f01e6' SERVER=$'\U000f048b'
CLOCK_2=$'\U000f1440'

HOME_DIR=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$HOME_DIR"' EXIT
export HOME="$HOME_DIR"
unset CODEX_HOME CLAUDE_PROFILE_ROOT
NOW=$(date +%s)
P="$HOME/.claude-profiles"

# identity <file> <account>: a .claude.json naming a made-up login.
identity() {
    mkdir -p "${1:h}"
    printf '{"oauthAccount":{"accountUuid":"fixture-%s","organizationUuid":"org-%s"}}' "$2" "$2" > "$1"
}

# reading <file> <age s> <5h pct> <weekly pct> [5h reset]: a status file in the
# shape the usage poller and the session writer share.
reading() {
    mkdir -p "${1:h}"
    jq -n --argjson at "$((NOW - $2))" --argjson five "$3" --argjson weekly "$4" \
        --argjson reset "${5:-$((NOW + 3600))}" '
        {session_id: "x", written_at: $at,
         rate_limits: {five_hour: {used_percentage: $five, resets_at: $reset},
                       seven_day: {used_percentage: $weekly, resets_at: ($at + 86400)}}}' > "$1"
}

poll() { reading "$1/status-cache/sessions/usage-poll.json" "${@:2}"; }

render_as() {
    printf '{"model":{"id":"claude-opus-5-5"},"session_id":"s1","cost":{"total_duration_ms":1000}}' |
        CLAUDE_CONFIG_DIR="$1" zsh "$SCRIPT" | sed -e $'s/\033\\[[0-9;]*m//g' -e $'s/\033]8;[^\a]*\a//g'
}

check() {
    local name="$1" out="$2" pattern="$3" want="$4" got
    if [[ "$out" == *${~pattern}* ]]; then got=yes; else got=no; fi
    if [[ "$got" == "$want" ]]; then echo "ok   $name"; else echo "FAIL $name"; echo "     $out"; FAILS=$((FAILS + 1)); fi
}

count() { local s="$1" n=0; while [[ "$s" == *"$2"* ]]; do s="${s#*$2}"; n=$((n + 1)); done; echo $n; }

# Like the live machine: ~/.claude and personal share one login; agents,
# server and workout each have their own. The poller writes every dir.
identity "$HOME/.claude.json" shared
identity "$P/personal/.claude.json" shared
for name in agents server workout; do identity "$P/$name/.claude.json" "$name"; done
poll "$HOME/.claude" 60 10 50
poll "$P/personal" 60 10 50
poll "$P/agents" 60 40 20
poll "$P/server" 60 95 3
poll "$P/workout" 60 30 50

out=$(render_as "$P/workout")
check "every pill is present: model, usage, session" "$out" "opus 5.5*$WORKOUT*│*s1" yes
check "starts the usage section with the current account" "$out" "$WORKOUT ▃▄ │" yes
check "shows a shared login once" "$(count "$out" "$PERSONAL")$(count "$out" "$DEFAULT")" "10" yes
check "lists every other account with its own figures" "$out" "│ $PERSONAL ▁▄ $AGENTS ▃▂ $SERVER █▁" yes
check "shows no age marker on fresh readings" "$out" "[0-9]m " no
check "draws no Codex pill when Codex has never run" "$out" "codex" no

out=$(render_as "$HOME/.claude")
check "pairs the default glyph with the login it shares" "$out" "$DEFAULT$PERSONAL ▁▄ │" yes
check "keeps the shared login out of the other accounts" "$(count "$out" "$PERSONAL")" "1" yes

# A session file rewritten on every redraw carries the numbers its session last
# saw. The poller's reading is the truth even when that file is newer.
reading "$P/workout/status-cache/sessions/live.json" 0 90 90
out=$(render_as "$P/workout")
check "prefers the poller over a newer session file" "$out" "$WORKOUT ▃▄ │" yes

# With no poller for a dir, its newest session file stands in.
rm "$P/agents/status-cache/sessions/usage-poll.json"
reading "$P/agents/status-cache/sessions/old.json" 120 0 0
reading "$P/agents/status-cache/sessions/new.json" 30 90 90
out=$(render_as "$P/workout")
check "falls back to the newest session file" "$out" "$AGENTS ▇▇" yes

# A poller that stopped shows how old its figures are.
poll "$P/server" 1500 95 3
out=$(render_as "$P/workout")
check "marks a reading 25 minutes old" "$out" "$SERVER █▁ 25m" yes
poll "$P/server" 7300 95 3
out=$(render_as "$P/workout")
check "marks a reading two hours old with the clock" "$out" "$SERVER █▁ $CLOCK_2" yes

# A five-hour window whose reset has passed reads 0, however old the reading.
poll "$P/server" 60 95 3 $((NOW - 10))
out=$(render_as "$P/workout")
check "reads a window past its reset as empty" "$out" "$SERVER ▁▁" yes

# A config dir outside the profile root still reads its own poller file.
identity "$HOME/elsewhere/.claude.json" elsewhere
poll "$HOME/elsewhere" 60 60 60
out=$(render_as "$HOME/elsewhere")
check "reads an active dir outside the profile root" "$out" "elsewhere ▅▅ │" yes

# Codex logs its own limits per session; the newest rollout is the reading.
rollout="$HOME/.codex/sessions/2026/10/18/rollout-x.jsonl"
mkdir -p "${rollout:h}"
ts=$(date -u -r "$((NOW - 120))" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d "@$((NOW - 120))" +%Y-%m-%dT%H:%M:%S.000Z)
jq -nc --arg ts "$ts" --argjson reset "$((NOW + 3600))" '
    {timestamp: $ts, type: "event_msg", payload: {type: "token_count", rate_limits: {
        primary: {used_percent: 50.0, window_minutes: 300, resets_at: $reset},
        secondary: {used_percent: 76.0, window_minutes: 10080, resets_at: ($reset + 86400)}}}}' > "$rollout"
out=$(render_as "$P/workout")
check "shows the Codex pill with its 5h and weekly bars" "$out" "codex ▄▆ *s1" yes

exit $((FAILS > 0))
