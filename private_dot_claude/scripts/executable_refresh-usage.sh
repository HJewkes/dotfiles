#!/bin/bash
# The Mac's one usage poller. The com.claude.usage-refresh LaunchAgent runs it
# so status line renders never fetch: it refreshes the shared usage cache for
# the default ~/.claude and every profile under ~/.claude-profiles.
#
# `rate-limits.sh --refresh` fetches synchronously, backs off after failures and
# falls back to the fallback host's poll, so success is judged by the record's
# age afterwards. Failures append one line to the log, trimmed to LOG_MAX_LINES.

RATE_LIMITS="${REFRESH_RATE_LIMITS:-$HOME/.claude/scripts/rate-limits.sh}"
PROFILES_DIR="${REFRESH_PROFILES_DIR:-$HOME/.claude-profiles}"
CACHE_FILE="${REFRESH_CACHE_FILE:-$HOME/.claude/status-cache/usage.json}"
LOG_FILE="${REFRESH_LOG_FILE:-$HOME/Library/Logs/claude-usage-refresh.log}"
LOG_MAX_LINES=200
# A record older than this after a refresh run is logged as stale. It allows for
# a fallback poll, which carries the fallback host's own write time.
STALE_AFTER=600

log_failure() {
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s %s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" "$2" >> "$LOG_FILE"
    if (( $(wc -l < "$LOG_FILE") > LOG_MAX_LINES )); then
        tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv -f "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

record_age() {
    local fetched
    fetched=$(jq -r --arg k "$1" '.[$k].fetched_at // 0' "$CACHE_FILE" 2>/dev/null)
    [[ "$fetched" =~ ^[0-9]+$ ]] || fetched=0
    echo $(( $(date +%s) - fetched ))
}

# Must match rate-limits.sh: the default dir uses the bare Keychain service name.
keychain_service() {
    if [[ "$1" == "$DEFAULT_DIR" ]]; then
        echo "Claude Code-credentials"
    else
        echo "Claude Code-credentials-$(printf '%s' "$1" | shasum -a 256 | cut -c1-8)"
    fi
}

# Seconds before expiry at which a local login is renewed. Only a Claude Code request renews
# the token (`claude auth status` does not), so a profile no Mac session uses would go stale.
RENEW_MARGIN=1800
CLAUDE_BIN="${REFRESH_CLAUDE_BIN:-$HOME/.local/bin/claude}"
RENEW_DIR="$HOME/Library/Caches/claude-usage-renew"

renew_if_expiring() {
    local dir="$1" expires
    [[ -f "$dir/usage-remote" ]] && return 0
    expires=$(security find-generic-password -s "$(keychain_service "$dir")" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.expiresAt // 0' 2>/dev/null) || return 0
    [[ "$expires" =~ ^[0-9]+$ && "$expires" != 0 ]] || return 0
    (( expires / 1000 - $(date +%s) > RENEW_MARGIN )) && return 0
    mkdir -p "$RENEW_DIR"
    (cd "$RENEW_DIR" && CLAUDE_CONFIG_DIR="$dir" "$CLAUDE_BIN" -p "Reply with the single word ok" \
        --model claude-haiku-5-5 --max-turns 1 >/dev/null 2>&1) \
        || log_failure "$(basename "$dir")" "token renewal failed"
}

# Warns when a dir's .claude.json names a different account than its token, so
# Claude Code shows one login while usage is billed to another.
check_identity() {
    local dir="$1" id_file="$2" name="$3" claimed cached
    claimed=$(jq -r '.oauthAccount.accountUuid // empty' "$id_file" 2>/dev/null)
    cached=$(jq -r --arg k "$dir" '.[$k].account // empty' "$CACHE_FILE" 2>/dev/null)
    [[ -n "$claimed" && -n "$cached" ]] || return 0
    [[ "$(printf '%s' "$claimed" | shasum -a 256 | cut -c1-12)" == "$cached" ]] && return 0
    log_failure "$name" "identity mismatch: .claude.json names a different account than the token"
}

# A profile with neither a Mac login nor a remote source has nothing to poll.
has_usage_source() {
    [[ -f "$1/usage-remote" ]] || security find-generic-password -s "$(keychain_service "$1")" >/dev/null 2>&1
}

refresh_profile() {
    local dir="$1" id_file="$2" name="$3" rc age
    has_usage_source "$dir" || return 0
    renew_if_expiring "$dir"
    CLAUDE_CONFIG_DIR="$dir" "$RATE_LIMITS" --refresh >/dev/null 2>&1
    rc=$?
    age=$(record_age "$dir")
    if (( rc != 0 )); then
        log_failure "$name" "exit $rc"
    elif (( age > STALE_AFTER )); then
        log_failure "$name" "no fresh usage (${age}s old: no token, backing off or fetch failed)"
    fi
    check_identity "$dir" "$id_file" "$name"
}

main() {
    local dir
    DEFAULT_DIR="$(cd "${REFRESH_DEFAULT_DIR:-$HOME/.claude}" && pwd -P)"
    refresh_profile "$DEFAULT_DIR" "$HOME/.claude.json" default
    for dir in "$PROFILES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        dir="$(cd "$dir" && pwd -P)" || { log_failure "$(basename "$dir")" "unreadable"; continue; }
        refresh_profile "$dir" "$dir/.claude.json" "$(basename "$dir")"
    done
}

main
