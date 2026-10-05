#!/bin/zsh
# Renders the status line against a fixture usage cache in a throwaway HOME.
# Run: zsh tests/test_statusline.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/executable_statusline-command.sh"
export STATUSLINE_RATE_LIMITS="$ROOT/private_dot_claude/scripts/executable_rate-limits.sh"
export STATUSLINE_TEST_WIDTH=200
FAILS=0
DEFAULT=$'\uf007' AGENTS=$'\U000f06a9' PERSONAL=$'\uf015' WORKOUT=$'\U000f01e6'

HOME_DIR=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$HOME_DIR"' EXIT
export HOME="$HOME_DIR"
mkdir -p "$HOME/.claude/status-cache" "$HOME/.claude-profiles/agents" "$HOME/.claude-profiles/personal"
NOW=$(date +%s)

write_cache() {
    jq -n --argjson now "$NOW" --arg h "$HOME" --argjson others "$1" '
        def rec($age): {fetched_at: ($now - $age), five_hour_pct: "10", weekly_pct: "50",
                        five_hour_reset: 0, weekly_reset: 0, scoped_pct: "", scoped_model: "",
                        weekly_sev: "normal", scoped_sev: ""};
        {($h + "/.claude-profiles/agents"): rec(30)}
        + (if $others then {($h + "/.claude"): rec(30), ($h + "/.claude-profiles/personal"): rec(7200)} else {} end)
    ' > "$HOME/.claude/status-cache/usage.json"
}

render() {
    local effort_json="$1"
    printf '{"model":{"id":"claude-opus-5-5"},"session_id":"s1",%s"cost":{"total_duration_ms":1000}}' "$effort_json" |
        CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/agents" zsh "$SCRIPT" | sed $'s/\033\\[[0-9;]*m//g'
}

render_with_dir() {
    printf '{"model":{"id":"claude-opus-5-5"},"session_id":"s1","cost":{"total_duration_ms":1000}}' |
        zsh "$SCRIPT" | sed $'s/\033\\[[0-9;]*m//g'
}

check() {
    local name="$1" out="$2" pattern="$3" want="$4"
    if [[ "$out" == *${~pattern}* ]]; then got=yes; else got=no; fi
    if [[ "$got" == "$want" ]]; then echo "ok   $name"; else echo "FAIL $name"; echo "     $out"; FAILS=$((FAILS + 1)); fi
}

write_cache false
out=$(render '"effort":{"level":"xhigh"},')
check "shows account and effort next to the model" "$out" "opus 5.5 $AGENTS xhigh" yes
check "hides other-accounts pill when only one account has data" "$out" "$DEFAULT" no

out=$(render '')
check "omits effort when stdin has none" "$out" "opus 5.5 $AGENTS ▁▄" yes

write_cache true
out=$(render '"effort":{"level":"high"},')
check "lists other accounts' cached usage" "$out" "$DEFAULT ▁▄" yes
check "shows age for a stale other account" "$out" "$PERSONAL ▁▄*2h" yes
check "does not repeat the current account among the others" "$out" "$AGENTS*$AGENTS" no

out=$(CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/other" render_with_dir '')
check "falls back to the short name for an unknown account" "$out" "opus 5.5 other" yes

exit $((FAILS > 0))
