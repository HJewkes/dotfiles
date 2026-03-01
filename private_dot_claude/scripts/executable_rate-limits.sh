#!/bin/bash
# Fetch 5hr and weekly usage from Anthropic OAuth API with 60s cache
# Output: 5HR_PCT|WEEKLY_PCT|5HR_RESET_EPOCH|WEEKLY_RESET_EPOCH
# On failure: "unknown"

CACHE_FILE="$HOME/.claude/status-cache/rate_limits"
CACHE_TTL=60

read_cache() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi
    local age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if (( age < CACHE_TTL )); then
        cat "$CACHE_FILE"
        return 0
    fi
    return 1
}

iso_to_epoch() {
    local ts="$1"
    if [[ -z "$ts" || "$ts" == "null" ]]; then
        echo "0"
        return
    fi
    date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" "+%s" 2>/dev/null || echo "0"
}

fetch_usage() {
    local cred_json token response
    cred_json=$(security find-generic-password -s "claude-cli" -w 2>/dev/null) || return 1
    token=$(echo "$cred_json" | jq -r '.accessToken // .claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [[ -z "$token" ]]; then
        return 1
    fi

    response=$(curl -s --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage") || return 1

    local five_hr weekly five_hr_reset weekly_reset
    five_hr=$(echo "$response" | jq -r '.five_hour.utilization // empty' 2>/dev/null) || return 1
    weekly=$(echo "$response" | jq -r '.seven_day.utilization // empty' 2>/dev/null) || return 1
    five_hr_reset=$(echo "$response" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    weekly_reset=$(echo "$response" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

    if [[ -z "$five_hr" || -z "$weekly" ]]; then
        return 1
    fi

    local five_hr_pct=${five_hr%.*}
    local weekly_pct=${weekly%.*}
    local five_hr_epoch weekly_epoch
    five_hr_epoch=$(iso_to_epoch "$five_hr_reset")
    weekly_epoch=$(iso_to_epoch "$weekly_reset")

    echo "${five_hr_pct}|${weekly_pct}|${five_hr_epoch}|${weekly_epoch}"
}

cached=$(read_cache) && { echo "$cached"; exit 0; }

mkdir -p "$(dirname "$CACHE_FILE")"

result=$(fetch_usage) || { echo "unknown"; exit 0; }

echo "$result" > "$CACHE_FILE"
echo "$result"
