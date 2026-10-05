#!/bin/zsh
# Renders the status line against a fixture usage cache in a throwaway HOME.
# Run: zsh tests/test_statusline.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/executable_statusline-command.sh"
export STATUSLINE_RATE_LIMITS="$ROOT/private_dot_claude/scripts/executable_rate-limits.sh"
export STATUSLINE_TEST_WIDTH=200
FAILS=0
DEFAULT=$'\uf007' AGENTS=$'\U000f06a9' PERSONAL=$'\uf015' WORKOUT=$'\U000f01e6'
G_EMPTY=$'\U000f0873' G_LOW=$'\U000f0875' G_MID=$'\U000f029a' G_FULL=$'\U000f0874'

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
check "shows account and effort next to the model" "$out" "opus 5.5 $AGENTS $G_FULL" yes
check "hides other-accounts pill when only one account has data" "$out" "$DEFAULT" no

out=$(render '')
check "omits effort when stdin has none" "$out" "opus 5.5 $AGENTS ▁▄" yes

write_cache true
out=$(render '"effort":{"level":"high"},')
check "lists other accounts' cached usage" "$out" "$DEFAULT ▁▄" yes
check "shows age for a stale other account" "$out" "$PERSONAL ▁▄*2h old" yes
check "does not repeat the current account among the others" "$out" "$AGENTS*$AGENTS" no

out=$(CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/other" render_with_dir '')
check "falls back to the short name for an unknown account" "$out" "opus 5.5 other" yes

for pair in low:$G_EMPTY medium:$G_LOW high:$G_MID xhigh:$G_FULL max:$G_FULL; do
    out=$(render "\"effort\":{\"level\":\"${pair%%:*}\"},")
    check "maps ${pair%%:*} effort to its gauge glyph" "$out" "$AGENTS ${pair#*:} " yes
done
out=$(render '"effort":{"level":"turbo"},')
check "falls back to text for an unknown effort" "$out" "$AGENTS turbo" yes

raw=$(printf '{"model":{"id":"claude-opus-5-5"},"session_id":"s1","effort":{"level":"max"},"cost":{"total_duration_ms":1000}}' |
    CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/agents" zsh "$SCRIPT")
check_raw() {
    local name="$1" out="$2" literal="$3"
    if [[ "$out" == *"$literal"* ]]; then echo "ok   $name"; else echo "FAIL $name"; FAILS=$((FAILS + 1)); fi
}
check_raw "renders max effort in bold red" "$raw" $'\033[1m\033[38;2;243;139;168m'"$G_FULL"
check_raw "renders account glyph in dark green on the model pill" "$raw" $'\033[38;2;20;100;45m'"$AGENTS"

# Merged logins: default and personal share one account id (a made-up value).
write_cache true
for f in "$HOME/.claude.json" "$HOME/.claude-profiles/personal/.claude.json"; do
    echo '{"oauthAccount":{"accountUuid":"fixture-shared"}}' > "$f"
done
echo '{"oauthAccount":{"accountUuid":"fixture-agents"}}' > "$HOME/.claude-profiles/agents/.claude.json"
out=$(render '"effort":{"level":"high"},')
check "shows a shared login once, from its newest record" "$out" "$DEFAULT ▁▄" yes
check "drops the older record of a shared login" "$out" "$PERSONAL" no
check "puts the current account first, then a separator, then the others" "$out" "$AGENTS $G_MID ▁▄ │ $DEFAULT ▁▄" yes

out=$(CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/personal" render_with_dir '')
check "treats the merged account as current when any member is the current dir" "$out" "opus 5.5 $PERSONAL ▁▄ │ $AGENTS ▁▄" yes
check "does not list the current merged account among the others" "$out" "$DEFAULT" no

# A truncated identity file (caught mid-write) must not blank the usage section.
printf '{"oauthAccount":{"accountUu' > "$HOME/.claude.json"
out=$(render '"effort":{"level":"high"},')
check "still shows usage when an identity file is truncated" "$out" "$AGENTS $G_MID ▁▄ │" yes
check "keeps a dir with a truncated identity file as its own account" "$out" "$DEFAULT ▁▄" yes
check "keeps the other dir of the shared login too" "$out" "$PERSONAL ▁▄" yes

exit $((FAILS > 0))
