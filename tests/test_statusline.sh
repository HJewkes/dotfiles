#!/bin/zsh
# Renders the status line against a fixture usage cache in a throwaway HOME.
# Run: zsh tests/test_statusline.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/executable_statusline-command.sh"
export STATUSLINE_RATE_LIMITS="$ROOT/private_dot_claude/scripts/executable_rate-limits.sh"
export STATUSLINE_TEST_WIDTH=200
FAILS=0
DEFAULT=$'\uf007' AGENTS=$'\U000f06a9' PERSONAL=$'\uf015' WORKOUT=$'\U000f01e6' SERVER=$'\U000f048b'
CLOCK_1=$'\U000f143f' CLOCK_2=$'\U000f1440' CLOCK_5=$'\U000f1443' CLOCK_12=$'\U000f144a' CLOCK_ALERT=$'\U000f0955'
G_EMPTY=$'\U000f0873' G_LOW=$'\U000f0875' G_MID=$'\U000f029a' G_FULL=$'\U000f0874'

HOME_DIR=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$HOME_DIR"' EXIT
export HOME="$HOME_DIR"
mkdir -p "$HOME/.claude/status-cache" "$HOME/.claude-profiles/agents" "$HOME/.claude-profiles/personal"
NOW=$(date +%s)

write_cache() {
    jq -n --argjson now "$NOW" --arg h "$HOME" --argjson others "$1" --argjson personal_age "${PERSONAL_AGE:-7200}" '
        def rec($age): {fetched_at: ($now - $age), five_hour_pct: "10", weekly_pct: "50",
                        five_hour_reset: 0, weekly_reset: 0, scoped_pct: "", scoped_model: "",
                        weekly_sev: "normal", scoped_sev: ""};
        {($h + "/.claude-profiles/agents"): rec(30)}
        + (if $others then {($h + "/.claude"): rec(30), ($h + "/.claude-profiles/personal"): rec($personal_age)} else {} end)
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
check "shows the effort gauge after the model, ahead of the context bar" "$out" "opus 5.5 $G_FULL ▁▁▁▁" yes
check "starts the usage section with the current account" "$out" "200k*$AGENTS ▁▄" yes
check "keeps the model out of the usage section" "$out" "$AGENTS*opus" no
check "hides other-accounts pill when only one account has data" "$out" "$DEFAULT" no

out=$(render '')
check "omits effort when stdin has none" "$out" "opus 5.5 ▁▁▁▁" yes

write_cache true
out=$(render '"effort":{"level":"high"},')
check "lists other accounts' cached usage" "$out" "$DEFAULT ▁▄" yes
check "shows age for a stale other account" "$out" "$PERSONAL ▁▄ $CLOCK_2 " yes
check "does not repeat the current account among the others" "$out" "$AGENTS*$AGENTS" no

out=$(CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/other" render_with_dir '')
check "falls back to the short name for an unknown account" "$out" "other ▁▄" yes

out=$(CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/server" render_with_dir '')
check "shows the server glyph for the server account" "$out" "$SERVER ▁▄" yes

for pair in low:$G_EMPTY medium:$G_LOW high:$G_MID xhigh:$G_FULL max:$G_FULL; do
    out=$(render "\"effort\":{\"level\":\"${pair%%:*}\"},")
    check "maps ${pair%%:*} effort to its gauge glyph" "$out" "opus 5.5 ${pair#*:} ▁" yes
done
out=$(render '"effort":{"level":"turbo"},')
check "falls back to text for an unknown effort" "$out" "opus 5.5 turbo ▁" yes

raw=$(printf '{"model":{"id":"claude-opus-5-5"},"session_id":"s1","effort":{"level":"max"},"cost":{"total_duration_ms":1000}}' |
    CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/agents" zsh "$SCRIPT")
check_raw() {
    local name="$1" out="$2" literal="$3"
    if [[ "$out" == *"$literal"* ]]; then echo "ok   $name"; else echo "FAIL $name"; FAILS=$((FAILS + 1)); fi
}
check_raw "renders max effort in bold red" "$raw" $'\033[1m\033[38;2;243;139;168m'"$G_FULL"
check_raw "draws the account glyph in the pill text colour" "$raw" $'\033[38;2;40;110;95m '"$AGENTS"
if [[ "$raw" == *$'\033[38;2;20;100;45m'* ]]; then echo "FAIL leaves no green glyph colour"; FAILS=$((FAILS + 1)); else echo "ok   leaves no green glyph colour"; fi

# The stale marker is a clock whose hand shows the age in hours, from 1h up.
for pair in 3540:none 3600:$CLOCK_1 18000:$CLOCK_5 46800:$CLOCK_ALERT 259200:$CLOCK_ALERT 43200:$CLOCK_12; do
    age=${pair%%:*} want=${pair#*:}
    PERSONAL_AGE=$age write_cache true
    out=$(render '')
    if [[ "$want" == none ]]; then
        PERSONAL_AGE=60 write_cache true
        fresh=$(render '')
        if [[ "$out" == "$fresh" ]]; then echo "ok   shows no stale marker at ${age}s"; else echo "FAIL shows no stale marker at ${age}s"; echo "     $out"; FAILS=$((FAILS + 1)); fi
    else
        check "shows the clock for ${age}s" "$out" "$PERSONAL ▁▄ $want" yes
    fi
done
write_cache true

# Merged logins: default and personal share one account id (a made-up value).
# Like the live files, the fixtures have no trailing newline.
write_cache true
for f in "$HOME/.claude.json" "$HOME/.claude-profiles/personal/.claude.json"; do
    printf '{"oauthAccount":{"accountUuid":"fixture-shared"}}' > "$f"
done
printf '{"oauthAccount":{"accountUuid":"fixture-agents"}}' > "$HOME/.claude-profiles/agents/.claude.json"
out=$(render '"effort":{"level":"high"},')
check "shows a shared login once, from its newest record" "$out" "$DEFAULT ▁▄" yes
check "drops the older record of a shared login" "$out" "$PERSONAL" no
check "puts the current account first, then a separator, then the others" "$out" "$AGENTS ▁▄ │ $DEFAULT ▁▄" yes

out=$(CLAUDE_CONFIG_DIR="$HOME/.claude-profiles/personal" render_with_dir '')
check "treats the merged account as current when any member is the current dir" "$out" "$PERSONAL ▁▄ │ $AGENTS ▁▄" yes
check "does not list the current merged account among the others" "$out" "$DEFAULT" no

# A truncated identity file (caught mid-write) must not blank the usage section.
printf '{"oauthAccount":{"accountUu' > "$HOME/.claude.json"
out=$(render '"effort":{"level":"high"},')
check "still shows usage when an identity file is truncated" "$out" "$AGENTS ▁▄ │" yes
check "keeps a dir with a truncated identity file as its own account" "$out" "$DEFAULT ▁▄" yes
check "keeps the other dir of the shared login too" "$out" "$PERSONAL ▁▄" yes

exit $((FAILS > 0))
