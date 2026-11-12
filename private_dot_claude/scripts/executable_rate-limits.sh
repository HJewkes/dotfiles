#!/bin/bash
# Usage figures for the ACTIVE Claude profile, from a shared cache.
#
# Line 1: 5HR|WEEKLY|5HR_RESET|WEEKLY_RESET|SCOPED_PCT|SCOPED_MODEL|WEEKLY_SEV|SCOPED_SEV|AGE
# Then one line per other cached profile: other|NAME|5HR|WEEKLY|AGE|WEEKLY_SEV
# On failure: "unknown" (other-profile lines may still follow)
#
# The status line renders on every prompt and many terminals run at once, so a
# render only reads the cache. `rate-limits.sh --refresh`, run by the
# com.claude.usage-refresh LaunchAgent, is the one caller that fetches.

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
BACKOFF_FILE="$CACHE_DIR/backoff-$(printf '%s' "$CONFIG_DIR" | shasum -a 256 | cut -c1-8)"
BACKOFF_BASE=120
BACKOFF_MAX=1800
FALLBACK_HOST="${USAGE_FALLBACK_HOST:-basement}"

# Emit every cached record in one jq pass: "self|...|AGE|LABEL" for this
# profile, then "other|NAME|5HR|WEEKLY|AGE|WEEKLY_SEV" per other account. Ages
# are seconds since the record was fetched. Other profiles are read from cache
# only; they are refreshed by their own sessions or the refresh LaunchAgent.
#
# Usage is per login, and several config dirs can share one login. Records
# carrying the same account hash (taken from the token at fetch time, not from
# .claude.json, which can disagree with the token) collapse into one account,
# served from the newest record and named after its newest non-default member.
read_cache() {
    [[ -f "$CACHE_FILE" ]] || return 1
    jq -r --arg k "$CONFIG_DIR" --arg def "$DEFAULT_DIR" --argjson now "$(date +%s)" '
        def age: $now - (.fetched_at // 0);
        def name: sub(".*/"; "") | if . == ".claude" then "default" else . end;
        (to_entries
            | group_by(.value.account // .key)
            | map({members: ., best: (max_by(.value.fetched_at // 0)),
                   label: (((map(select(.key != $def)) | max_by(.value.fetched_at // 0) | .key) // $def) | name)})) as $accounts
        | ($accounts | map(select(any(.members[]; .key == $k)))[0] // empty
            | .label as $label | .best.value
            | ["self"
              , (.five_hour_pct   // "unknown")
              , (.weekly_pct      // "unknown")
              , (.five_hour_reset // 0)
              , (.weekly_reset    // 0)
              , (.scoped_pct      // "")
              , (.scoped_model    // "")
              , (.weekly_sev      // "")
              , (.scoped_sev      // "")
              , age
              , $label
              ] | join("|")),
          ($accounts[] | select(any(.members[]; .key == $k) | not) | .label as $label | .best
            | [ "other", $label
              , (.value.five_hour_pct // "unknown")
              , (.value.weekly_pct    // "unknown")
              , (.value | age)
              , (.value.weekly_sev    // "")
              ] | join("|"))
    ' "$CACHE_FILE" 2>/dev/null
}

# Seconds since this config dir's own record was fetched. Freshness is judged
# per dir: a sibling sharing the login must not suppress this dir's fetch.
own_record_age() {
    jq -r --arg k "$CONFIG_DIR" --argjson now "$(date +%s)" \
        'if .[$k] then $now - (.[$k].fetched_at // 0) else 999999 end' "$CACHE_FILE" 2>/dev/null
}

# Output contract: the own record (without its tag) first, then the others.
emit() {
    local all="$1"
    sed -n 's/^self|//p' <<<"$all"
    sed -n '/^other|/p' <<<"$all"
}

# GET an OAuth endpoint ("usage" or "profile") with this profile's token.
fetch_local() {
    local token
    token=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
    [[ -n "$token" ]] || return 1
    curl -s --max-time 8 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/$1"
}

# A profile whose sessions run on another host keeps its live token there, so
# the fetch runs on that host and only the response JSON crosses the wire.
# usage-remote holds "HOST CONFIG_DIR_RELATIVE_TO_REMOTE_HOME".
fetch_remote() {
    local host remote_dir
    read -r host remote_dir < "$CONFIG_DIR/usage-remote" || return 1
    [[ -n "$host" && "$remote_dir" =~ ^[A-Za-z0-9._/-]+$ && "$1" =~ ^[a-z]+$ ]] || return 1
    ssh -o BatchMode=yes -o ConnectTimeout=4 "$host" \
        "t=\$(jq -r '.claudeAiOauth.accessToken // empty' \"\$HOME/$remote_dir/.credentials.json\") && [ -n \"\$t\" ] && curl -s --max-time 8 -H \"Authorization: Bearer \$t\" -H 'Accept: application/json' -H 'anthropic-beta: oauth-2025-04-20' https://api.anthropic.com/api/oauth/$1"
}

fetch_api() {
    if [[ -f "$CONFIG_DIR/usage-remote" ]]; then fetch_remote "$1"; else fetch_local "$1"; fi
}

# Short hash of the account id the token belongs to, so dirs sharing a login
# group together without the id itself landing in the cache.
token_account_hash() {
    local uuid
    uuid=$(fetch_api profile | jq -r '.account.uuid // empty' 2>/dev/null)
    [[ -n "$uuid" ]] && printf '%s' "$uuid" | shasum -a 256 | cut -c1-12
}

# Turn a usage API response on stdin into a cache record; fail without a weekly
# figure. five_hour is null when the account was idle for the whole window.
usage_to_record() {
    jq -ce --argjson now "$(date +%s)" '
        def epoch: if . == null then 0
            else sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601 end;
        def pct: floor | tostring;
        def scoped: [.limits[]? | select(.kind == "weekly_scoped")][0];
        select(.error == null and .seven_day.utilization != null)
        | { fetched_at: $now,
            five_hour_pct: ((.five_hour.utilization // 0) | pct),
            weekly_pct: (.seven_day.utilization | pct),
            five_hour_reset: (.five_hour.resets_at | epoch),
            weekly_reset: (.seven_day.resets_at | epoch),
            scoped_pct: (scoped.percent | if . == null then "" else pct end),
            scoped_model: (scoped.scope.model.display_name // ""),
            weekly_sev: ([.limits[]? | select(.kind == "weekly_all")][0].severity // ""),
            scoped_sev: (scoped.severity // "") }' 2>/dev/null
}

# Merge one record into the shared file, keyed by config dir so profiles share
# one cache without clobbering. A record without an account keeps the old one.
store_record() {
    local tmp
    tmp=$(mktemp "$CACHE_DIR/usage.XXXXXX") || return 1
    jq -n \
        --slurpfile old <(cat "$CACHE_FILE" 2>/dev/null || echo '{}') \
        --arg k "$CONFIG_DIR" \
        --argjson rec "$1" \
        '($old[0] // {}) as $o
         | $o + { ($k): ($rec + { account: ($rec.account // $o[$k].account // null) }) }' \
        > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$CACHE_FILE" || { rm -f "$tmp"; return 1; }
}

refresh() {
    local record account
    record=$(fetch_api usage | usage_to_record) || return 1
    account=$(token_account_hash)
    [[ -n "$account" ]] && record=$(jq -c --arg a "$account" '. + { account: $a }' <<<"$record")
    store_record "$record"
}

own_fetched_at() {
    jq -r --arg k "$CONFIG_DIR" '.[$k].fetched_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0
}

# The fallback host's anthropic-account poller writes the same profile's reading
# under the same home-relative dir. Used only when it is newer than ours.
fallback_record() {
    local rel="${CONFIG_DIR#"$HOME"/}" poll
    [[ "$rel" != "$CONFIG_DIR" && "$rel" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
    poll=$(ssh -o BatchMode=yes -o ConnectTimeout=4 "$FALLBACK_HOST" \
        "cat \"\$HOME/$rel/status-cache/sessions/usage-poll.json\"" 2>/dev/null) || return 1
    jq -ce --argjson have "$(own_fetched_at)" '
        .rate_limits as $r
        | select($r.seven_day.used_percentage != null and .written_at > $have)
        | { fetched_at: .written_at, source: "fallback-poll",
            five_hour_pct: (($r.five_hour.used_percentage // 0) | floor | tostring),
            weekly_pct: ($r.seven_day.used_percentage | floor | tostring),
            five_hour_reset: ($r.five_hour.resets_at // 0),
            weekly_reset: ($r.seven_day.resets_at // 0),
            scoped_pct: "", scoped_model: "", weekly_sev: "", scoped_sev: "" }' \
        <<<"$poll" 2>/dev/null
}

# A failed fetch leaves the record stale, which would refetch on every render.
# Wait BACKOFF_BASE, doubling per consecutive failure up to BACKOFF_MAX.
backing_off() {
    local count next
    read -r count next 2>/dev/null < "$BACKOFF_FILE" || return 1
    [[ "$next" =~ ^[0-9]+$ ]] && (( $(date +%s) < next ))
}

record_failure() {
    local count next delay
    read -r count next 2>/dev/null < "$BACKOFF_FILE"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    count=$((count + 1))
    delay=$(( BACKOFF_BASE << (count > 5 ? 4 : count - 1) ))
    (( delay > BACKOFF_MAX )) && delay=$BACKOFF_MAX
    printf '%s %s\n' "$count" "$(( $(date +%s) + delay ))" > "$BACKOFF_FILE"
}

update_usage() {
    local record
    backing_off && return 1
    if refresh; then
        rm -f "$BACKOFF_FILE"
        return 0
    fi
    record_failure
    record=$(fallback_record) && store_record "$record"
}

# A refresh killed between mktemp and mv leaves its temp file behind.
sweep_stale_temps() {
    find "$CACHE_DIR" -maxdepth 1 -type f -name 'usage.??????' -mmin +10 -delete 2>/dev/null
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

if [[ "$1" == "--refresh" ]]; then
    acquire_lock || exit 0
    sweep_stale_temps
    age=$(own_record_age)
    [[ "$age" =~ ^[0-9]+$ ]] || age=999999
    (( age < CACHE_TTL )) || update_usage >/dev/null 2>&1
    release_lock
    exit 0
fi

all=$(read_cache)
if grep -q '^self|' <<<"$all"; then emit "$all"; exit 0; fi
echo "unknown"
[[ -n "$all" ]] && emit "$all"
exit 0
