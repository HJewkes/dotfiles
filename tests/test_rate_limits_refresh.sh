#!/bin/bash
# Behaviour tests for rate-limits.sh refresh: idle windows, backoff, fallback poll.
# Usage: test_rate_limits_refresh.sh <path to rate-limits.sh>
SCRIPT="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
WORK="$(mktemp -d)"; WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
fails=0

check() {
    if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: expected [$3] got [$2]"; fails=$((fails + 1)); fi
}

make_shims() {
    mkdir -p "$WORK/bin"
    cat > "$WORK/bin/security" <<'EOF'
#!/bin/bash
echo '{"claudeAiOauth":{"accessToken":"test-token","expiresAt":9999999999999}}'
EOF
    cat > "$WORK/bin/curl" <<'EOF'
#!/bin/bash
echo "${@: -1}" >> "$MOCK_DIR/curl.log"
case "${@: -1}" in
    */profile) echo '{"account":{"uuid":"acct-1"}}' ;;
    */usage) cat "$MOCK_DIR/usage.json" ;;
esac
EOF
    cat > "$WORK/bin/ssh" <<'EOF'
#!/bin/bash
echo "${@: -1}" >> "$MOCK_DIR/ssh.log"
[[ -f "$MOCK_DIR/poll.json" ]] && cat "$MOCK_DIR/poll.json" || exit 1
EOF
    chmod +x "$WORK/bin/"*
}

# Fresh sandbox home with the script's functions loaded, main body excluded.
setup() {
    rm -rf "$WORK/home" "$WORK/mock"; mkdir -p "$WORK/home/.claude/status-cache" "$WORK/mock"
    export HOME="$WORK/home" MOCK_DIR="$WORK/mock" CLAUDE_CONFIG_DIR="$WORK/home/.claude"
    sed -n '1,/^mkdir -p "\$CACHE_DIR"/p' "$SCRIPT" | sed '$d' > "$WORK/funcs.sh"
    source "$WORK/funcs.sh"
}

record() { jq -r --arg k "$CONFIG_DIR" ".[\$k].$1" "$CACHE_FILE"; }
# Seconds until the backoff ends, rounded up to absorb a clock tick since it was written.
backoff_wait() { local w=$(( $(cut -d" " -f2 "$BACKOFF_FILE") - $(date +%s) )); echo $(( (w + 59) / 60 * 60 )); }
usage_calls() { grep -c '/usage$' "$MOCK_DIR/curl.log" 2>/dev/null || echo 0; }

make_shims
export PATH="$WORK/bin:/usr/bin:/bin:/opt/homebrew/bin"

# An idle five-hour window still stores the weekly reading.
setup
echo '{"five_hour":null,"seven_day":{"utilization":33.0,"resets_at":"2026-11-15T08:59:59.951425+00:00"},
 "limits":[{"kind":"weekly_all","severity":"normal"},{"kind":"weekly_scoped","percent":7,"severity":"normal","scope":{"model":{"display_name":"Fable"}}}]}' > "$MOCK_DIR/usage.json"
update_usage
check "idle window stores weekly" "$(record weekly_pct)" "33"
check "idle window reads five-hour as 0" "$(record five_hour_pct)" "0"
check "weekly reset parsed as UTC" "$(record weekly_reset)" "1794733199"
check "scoped cap kept" "$(record scoped_model)/$(record scoped_pct)" "Fable/7"
check "account hash stored" "$(record account | wc -c | tr -d ' ')" "13"
check "success leaves no backoff" "$([[ -f $BACKOFF_FILE ]] && echo yes || echo no)" "no"

# A 429 starts a backoff and serves the fallback host's newer poll.
setup
echo '{"error":{"type":"rate_limit_error"}}' > "$MOCK_DIR/usage.json"
echo "{\"written_at\":$(( $(date +%s) - 30 )),\"rate_limits\":{\"seven_day\":{\"used_percentage\":41,\"resets_at\":1795165199}}}" > "$MOCK_DIR/poll.json"
update_usage
check "rate limit records first failure" "$(cut -d' ' -f1 "$BACKOFF_FILE")" "1"
check "first backoff waits BACKOFF_BASE" "$(backoff_wait)" "120"
check "fallback poll stored" "$(record source)/$(record weekly_pct)" "fallback-poll/41"
check "fallback reads the profile's own dir" "$(cat "$MOCK_DIR/ssh.log")" "cat \"\$HOME/.claude/status-cache/sessions/usage-poll.json\""

# While backing off, no fetch is attempted.
update_usage
check "backoff skips the API" "$(usage_calls)" "1"

# Consecutive failures double the wait, capped at BACKOFF_MAX.
printf '2 0\n' > "$BACKOFF_FILE"; update_usage
check "third failure waits 4 x base" "$(backoff_wait)" "480"
printf '9 0\n' > "$BACKOFF_FILE"; update_usage
check "wait is capped" "$(backoff_wait)" "1800"

# An older fallback poll never replaces a newer record.
setup
echo '{"error":{"type":"rate_limit_error"}}' > "$MOCK_DIR/usage.json"
echo "{\"$CONFIG_DIR\":{\"fetched_at\":$(date +%s),\"weekly_pct\":\"50\"}}" > "$CACHE_FILE"
echo '{"written_at":100,"rate_limits":{"seven_day":{"used_percentage":41}}}' > "$MOCK_DIR/poll.json"
update_usage
check "older fallback ignored" "$(record weekly_pct)" "50"

# Success after a failure clears the backoff.
setup
printf '3 0\n' > "$BACKOFF_FILE"
echo '{"five_hour":{"utilization":12.5,"resets_at":"2026-11-12T15:00:00+00:00"},"seven_day":{"utilization":20}}' > "$MOCK_DIR/usage.json"
update_usage
check "recovery clears backoff" "$([[ -f $BACKOFF_FILE ]] && echo yes || echo no)" "no"
check "recovery stores five-hour" "$(record five_hour_pct)" "12"

# A status line render with a stale record only reads; it never fetches.
setup
echo '{"seven_day":{"utilization":20}}' > "$MOCK_DIR/usage.json"
echo "{\"$CONFIG_DIR\":{\"fetched_at\":100,\"five_hour_pct\":\"5\",\"weekly_pct\":\"9\"}}" > "$CACHE_FILE"
out=$(bash "$SCRIPT"); sleep 1
check "render serves the cached figures" "$(cut -d'|' -f1,2 <<<"$out")" "5|9"
check "render makes no API call" "$(usage_calls)" "0"

# A render with nothing cached prints unknown rather than fetching.
rm -f "$CACHE_FILE"
check "empty cache renders unknown" "$(bash "$SCRIPT")" "unknown"
check "empty cache makes no API call" "$(usage_calls)" "0"

# --refresh is the one path that fetches.
bash "$SCRIPT" --refresh
check "refresh fetches once" "$(usage_calls)" "1"
check "refresh stores the reading" "$(record weekly_pct)" "20"
bash "$SCRIPT" --refresh
check "refresh skips a fresh record" "$(usage_calls)" "1"

echo "$fails failure(s)"
exit $(( fails > 0 ))
