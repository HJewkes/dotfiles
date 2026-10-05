#!/bin/bash
# Refresh the shared usage cache for every Claude profile under
# ~/.claude-profiles, driven by a LaunchAgent so the status line stays fresh
# when no session for that account is open. The default ~/.claude shares the
# personal login and is refreshed by its own sessions, so it is skipped.
#
# rate-limits.sh always exits 0 and refreshes stale records in the background,
# so success is judged by the profile's cache record becoming fresh. Failures
# append one line to the log, which is trimmed to the last LOG_MAX_LINES.

RATE_LIMITS="${REFRESH_RATE_LIMITS:-$HOME/.claude/scripts/rate-limits.sh}"
PROFILES_DIR="${REFRESH_PROFILES_DIR:-$HOME/.claude-profiles}"
CACHE_FILE="${REFRESH_CACHE_FILE:-$HOME/.claude/status-cache/usage.json}"
LOG_FILE="${REFRESH_LOG_FILE:-$HOME/Library/Logs/claude-usage-refresh.log}"
LOG_MAX_LINES=200
WAIT_SECONDS="${REFRESH_WAIT_SECONDS:-15}"
# Must match CACHE_TTL in rate-limits.sh: a record younger than this is served
# as is, so it counts as fresh even though this run did not fetch it.
CACHE_TTL=120

log_failure() {
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s %s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" "$2" >> "$LOG_FILE"
    if (( $(wc -l < "$LOG_FILE") > LOG_MAX_LINES )); then
        tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv -f "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

fetched_at() {
    jq -r --arg k "$1" '.[$k].fetched_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0
}

wait_for_fresh_record() {
    local dir="$1" started="$2" i
    for ((i = 0; i < WAIT_SECONDS; i++)); do
        (( $(fetched_at "$dir") >= started - CACHE_TTL )) && return 0
        sleep 1
    done
    return 1
}

refresh_profile() {
    local dir="$1" name started rc
    name="$(basename "$dir")"
    dir="$(cd "$dir" && pwd -P)" || { log_failure "$name" "unreadable"; return; }
    started=$(date +%s)
    CLAUDE_CONFIG_DIR="$dir" "$RATE_LIMITS" >/dev/null 2>&1
    rc=$?
    if (( rc != 0 )); then
        log_failure "$name" "exit $rc"
    elif ! wait_for_fresh_record "$dir" "$started"; then
        log_failure "$name" "no fresh usage (no token, lock busy or fetch failed)"
    fi
}

main() {
    local dir
    for dir in "$PROFILES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        refresh_profile "${dir%/}"
    done
}

main
