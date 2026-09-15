#!/bin/bash
# Usage figures for the ACTIVE Claude profile, from a shared cache.
#
# Output: 5HR|WEEKLY|5HR_RESET|WEEKLY_RESET|SCOPED_PCT|SCOPED_MODEL|WEEKLY_SEV|SCOPED_SEV
# On failure: "unknown"
#
# The status line renders on every prompt and many terminals run at once, so
# this never blocks on the network: it serves whatever is cached and refreshes
# in the background. One lock holder refreshes; everyone else reads the file.

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CONFIG_DIR="$(cd "$CONFIG_DIR" 2>/dev/null && pwd -P)" || CONFIG_DIR="$HOME/.claude"
DEFAULT_DIR="$(cd "$HOME/.claude" 2>/dev/null && pwd -P)"

# Claude Code namespaces the Keychain item per config directory: the default
# ~/.claude uses the bare service name, every other config dir appends the first
# eight hex of the SHA-256 of its absolute path.
if [[ "$CONFIG_DIR" == "$DEFAULT_DIR" ]]; then
    KEYCHAIN_SERVICE="Claude Code-credentials"
else
    KEYCHAIN_SERVICE="Claude Code-credentials-$(printf '%s' "$CONFIG_DIR" | shasum -a 256 | cut -c1-8)"
fi

CACHE_DIR="$DEFAULT_DIR/status-cache"
CACHE_FILE="$CACHE_DIR/usage.json"
LOCK_DIR="$CACHE_DIR/usage.lock"
CACHE_TTL=120
LOCK_STALE=60

iso_to_epoch() {
    local ts="$1"
    [[ -z "$ts" || "$ts" == "null" ]] && { echo 0; return; }
    date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" "+%s" 2>/dev/null || echo 0
}

# Emit the cached record for this profile, or nothing if absent.
read_entry() {
    [[ -f "$CACHE_FILE" ]] || return 1
    local line
    line=$(jq -r --arg k "$CONFIG_DIR" '
        .[$k] // empty
        | [ (.five_hour_pct   // "unknown")
          , (.weekly_pct      // "unknown")
          , (.five_hour_reset // 0)
          , (.weekly_reset    // 0)
          , (.scoped_pct      // "")
          , (.scoped_model    // "")
          , (.weekly_sev      // "")
          , (.scoped_sev      // "")
          ] | join("|")
    ' "$CACHE_FILE" 2>/dev/null) || return 1
    [[ -n "$line" ]] || return 1
    printf '%s\n' "$line"
}

entry_age() {
    [[ -f "$CACHE_FILE" ]] || { echo 999999; return; }
    local fetched now
    fetched=$(jq -r --arg k "$CONFIG_DIR" '.[$k].fetched_at // 0' "$CACHE_FILE" 2>/dev/null)
    [[ "$fetched" =~ ^[0-9]+$ ]] || fetched=0
    now=$(date +%s)
    echo $(( now - fetched ))
}

# Pull usage for this profile and merge it into the shared file. The file is
# keyed by config dir, so profiles share one cache without clobbering.
refresh() {
    local token response five weekly scoped_pct scoped_model weekly_sev scoped_sev tmp
    token=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
    [[ -n "$token" ]] || return 1

    response=$(curl -s --max-time 8 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage") || return 1

    jq -e '.error' >/dev/null 2>&1 <<<"$response" && return 1

    five=$(jq -r '.five_hour.utilization // empty' <<<"$response")
    weekly=$(jq -r '.seven_day.utilization // empty' <<<"$response")
    [[ -n "$five" && -n "$weekly" ]] || return 1

    # Per-model weekly cap, e.g. Fable on Max. Absent on plans without one.
    scoped_pct=$(jq -r '[.limits[]? | select(.kind=="weekly_scoped")][0].percent // empty' <<<"$response")
    scoped_model=$(jq -r '[.limits[]? | select(.kind=="weekly_scoped")][0].scope.model.display_name // empty' <<<"$response")
    scoped_sev=$(jq -r '[.limits[]? | select(.kind=="weekly_scoped")][0].severity // empty' <<<"$response")
    weekly_sev=$(jq -r '[.limits[]? | select(.kind=="weekly_all")][0].severity // empty' <<<"$response")

    tmp=$(mktemp "$CACHE_DIR/usage.XXXXXX") || return 1
    jq -n \
        --slurpfile old <(cat "$CACHE_FILE" 2>/dev/null || echo '{}') \
        --arg k "$CONFIG_DIR" \
        --argjson fetched_at "$(date +%s)" \
        --arg five "${five%.*}" \
        --arg weekly "${weekly%.*}" \
        --argjson five_reset "$(iso_to_epoch "$(jq -r '.five_hour.resets_at // empty' <<<"$response")")" \
        --argjson weekly_reset "$(iso_to_epoch "$(jq -r '.seven_day.resets_at // empty' <<<"$response")")" \
        --arg scoped_pct "${scoped_pct%.*}" \
        --arg scoped_model "$scoped_model" \
        --arg weekly_sev "$weekly_sev" \
        --arg scoped_sev "$scoped_sev" \
        '($old[0] // {}) + { ($k): {
            fetched_at: $fetched_at,
            five_hour_pct: $five,
            weekly_pct: $weekly,
            five_hour_reset: $five_reset,
            weekly_reset: $weekly_reset,
            scoped_pct: $scoped_pct,
            scoped_model: $scoped_model,
            weekly_sev: $weekly_sev,
            scoped_sev: $scoped_sev
        } }' > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }

    mv -f "$tmp" "$CACHE_FILE"
}

release_lock() { rmdir "$LOCK_DIR" 2>/dev/null; }

# Non-blocking. Returns 1 if someone else is already refreshing.
acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        return 0
    fi
    local age
    age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if (( age > LOCK_STALE )); then
        rmdir "$LOCK_DIR" 2>/dev/null
        mkdir "$LOCK_DIR" 2>/dev/null && return 0
    fi
    return 1
}

mkdir -p "$CACHE_DIR"

cached=$(read_entry)
age=$(entry_age)

if (( age < CACHE_TTL )) && [[ -n "$cached" ]]; then
    printf '%s\n' "$cached"
    exit 0
fi

if [[ -n "$cached" ]]; then
    # Stale but usable: serve it now, refresh out of band so the prompt stays fast.
    if acquire_lock; then
        ( refresh; release_lock ) >/dev/null 2>&1 &
        disown 2>/dev/null
    fi
    printf '%s\n' "$cached"
    exit 0
fi

# Nothing cached at all — fetch synchronously so the first render is not blank.
if acquire_lock; then
    refresh >/dev/null 2>&1
    release_lock
fi

cached=$(read_entry) && { printf '%s\n' "$cached"; exit 0; }
echo "unknown"
