#!/bin/bash
# Usage figures for every Claude account on this machine, plus Codex.
#
# Line 1: 5HR|WEEKLY|5HR_RESET|WEEKLY_RESET|SCOPED_PCT|SCOPED_MODEL|WEEKLY_SEV|SCOPED_SEV|AGE|ACCOUNT
#         for the active profile's account; ACCOUNT names it when the active dir
#         shares a login with a named profile (default -> personal), else empty.
# Then one line per other account: other|NAME|5HR|WEEKLY|AGE|WEEKLY_SEV
# Then, when Codex has run here: codex|5HR|WEEKLY|AGE
# On failure line 1 is "unknown" (the other lines may still follow).
#
# Each config dir's reading comes from the freshest of:
#   1. <dir>/status-cache/sessions/usage-poll.json, which the usage poller
#      (`anthropic-account poll --write`) writes every 150s. agent-chat's seat
#      watchdog reads the same file, so the two agree.
#   2. Its record in ~/.claude/status-cache/usage.json, written by refresh() on
#      macOS, where the LaunchAgent drives it.
# A status-line session file is the fallback only: its written_at moves on
# every redraw while its rate_limits are whatever the session last saw.
#
# Dirs that log in to the same Anthropic account are one account, read the way
# agent-chat does (accountUuid/organizationUuid in .claude.json). The id is only
# compared in memory, never emitted. This never blocks on the network once a
# reading exists: refresh runs in the background.

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CONFIG_DIR="$(cd "$CONFIG_DIR" 2>/dev/null && pwd -P)" || CONFIG_DIR="$HOME/.claude"
DEFAULT_DIR="$(cd "$HOME/.claude" 2>/dev/null && pwd -P)" || DEFAULT_DIR="$HOME/.claude"
PROFILE_ROOT="${CLAUDE_PROFILE_ROOT:-$HOME/.claude-profiles}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

CACHE_DIR="$DEFAULT_DIR/status-cache"
CACHE_FILE="$CACHE_DIR/usage.json"
LOCK_DIR="$CACHE_DIR/usage.lock"
CACHE_TTL=120
LOCK_STALE=60

# ~/.claude first, then every profile dir in name order, then the active dir
# when it lives elsewhere.
account_dirs() {
    local d
    {
        printf '%s\n' "$DEFAULT_DIR"
        for d in "$PROFILE_ROOT"/*/; do
            [[ -d "$d" ]] && (cd "$d" && pwd -P)
        done
        printf '%s\n' "$CONFIG_DIR"
    } | awk '!seen[$0]++'
}

# The newest session file under a dir that carries rate limits.
newest_session_file() {
    local f
    for f in $(ls -t "$1/status-cache/sessions"/*.json 2>/dev/null | head -5); do
        [[ "${f##*/}" == usage-poll.json ]] && continue
        grep -q '"five_hour"' "$f" 2>/dev/null && { printf '%s' "$f"; return; }
    done
}

add_raw() {
    [[ -n "$2" && -r "$2" ]] && jq_args+=(--rawfile "$1" "$2")
}

# jq arguments naming every dir with its candidate files, indexed 0..count-1.
collect_dirs() {
    local dir i=0
    while IFS= read -r dir; do
        jq_args+=(--arg "dir$i" "$dir")
        add_raw "poll$i" "$dir/status-cache/sessions/usage-poll.json"
        add_raw "sess$i" "$(newest_session_file "$dir")"
        [[ "$dir" == "$DEFAULT_DIR" ]] && add_raw "home$i" "$HOME/.claude.json"
        add_raw "id$i" "$dir/.claude.json"
        i=$((i + 1))
    done < <(account_dirs)
    jq_args+=(--argjson count "$i")
}

# shellcheck disable=SC2016
ACCOUNTS_JQ='
def num: if type == "number" then . elif type == "string" then (tonumber? // null) else null end;
def parse($t): if $t == null then null else ($t | try fromjson catch null) end;
# A window whose reset has passed reads 0: nothing redraws at 3am to say so.
def window($w): if $w == null or ($w.used_percentage | num) == null then null
    elif (($w.resets_at // 0) > 0 and $w.resets_at <= $now) then {pct: 0, reset: 0}
    else {pct: ($w.used_percentage | num | floor), reset: ($w.resets_at // 0)} end;
def from_doc($t): parse($t) | select(type == "object" and (.rate_limits | type) == "object")
    | {at: (.written_at // 0), five: window(.rate_limits.five_hour), weekly: window(.rate_limits.seven_day)}
    | select(.five != null or .weekly != null);
def cached($dir): ($cache[0] // {})[$dir] // null | select(. != null)
    | {at: (.fetched_at // 0),
       five: {pct: (.five_hour_pct | num), reset: (.five_hour_reset // 0)},
       weekly: {pct: (.weekly_pct | num), reset: (.weekly_reset // 0)},
       scoped: (.scoped_pct // ""), scoped_model: (.scoped_model // ""),
       weekly_sev: (.weekly_sev // ""), scoped_sev: (.scoped_sev // "")};
def identity($t): parse($t) | .oauthAccount? // {}
    | if (.accountUuid // "") != "" and (.organizationUuid // "") != ""
      then "\(.accountUuid)/\(.organizationUuid)" else null end;
def row($i): $ARGS.named as $n | $n["dir\($i)"] as $dir
    | {dir: $dir, idx: $i,
       name: (if $dir == $def then "default" else ($dir | sub(".*/"; "")) end),
       account: (identity($n["home\($i)"]) // identity($n["id\($i)"]) // "dir:\($dir)"),
       reading: (([from_doc($n["poll\($i)"]), cached($dir)] | max_by(.at)) // from_doc($n["sess\($i)"]))};
def pct($w): $w.pct // "unknown";
def shown_name($members): ([$members[].name | select(. != "default")] + ["default"])[0];
[range(0; $count) | row(.)] | group_by(.account)
| map({members: ., shown: shown_name(.), self: any(.[]; .dir == $k),
       reading: ([.[].reading | select(. != null)] | max_by(.at))})
| (.[] | select(.self and .reading != null) | . as $a | .reading
    | ["self", pct(.five), pct(.weekly), (.five.reset // 0), (.weekly.reset // 0),
       (.scoped // ""), (.scoped_model // ""), (.weekly_sev // ""), (.scoped_sev // ""),
       ($now - .at), (if $a.shown == $own then "" else $a.shown end)] | join("|")),
  (sort_by(.members | map(.idx) | min) | .[] | select((.self | not) and .reading != null)
    | ["other", .shown, pct(.reading.five), pct(.reading.weekly), ($now - .reading.at),
       (.reading.weekly_sev // "")] | join("|"))
'

# Every account's line in one jq pass: "self|..." then "other|...".
read_accounts() {
    local jq_args=() own
    collect_dirs
    own=$([[ "$CONFIG_DIR" == "$DEFAULT_DIR" ]] && echo default || echo "${CONFIG_DIR##*/}")
    jq -n -r --slurpfile cache <(cat "$CACHE_FILE" 2>/dev/null || echo '{}') \
        --arg k "$CONFIG_DIR" --arg def "$DEFAULT_DIR" --arg own "$own" \
        --argjson now "$(date +%s)" "${jq_args[@]}" "$ACCOUNTS_JQ" 2>/dev/null
}

# Codex writes its rate limits into each session rollout; the newest one wins.
# Windows are told apart by length: 300 minutes is 5h, 10080 is weekly.
codex_line() {
    local f event
    for f in $(ls -t "$CODEX_DIR"/sessions/*/*/*/rollout-*.jsonl 2>/dev/null | head -5); do
        event=$(grep -F '"rate_limits":{' "$f" 2>/dev/null | tail -1)
        [[ -n "$event" ]] && break
    done
    [[ -n "$event" ]] || return 0
    jq -r --argjson now "$(date +%s)" '
        def window($m): [.payload.rate_limits.primary, .payload.rate_limits.secondary]
            | map(select(. != null and .window_minutes == $m))[0]
            | if . == null then "unknown"
              elif ((.resets_at // 0) > 0 and .resets_at <= $now) then 0
              else (.used_percent | floor) end;
        (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) as $at
        | ["codex", window(300), window(10080), ($now - $at)] | join("|")
    ' <<<"$event" 2>/dev/null
}

own_record_age() {
    local at
    at=$(jq -r --arg k "$CONFIG_DIR" '.[$k].fetched_at // 0' "$CACHE_FILE" 2>/dev/null)
    echo $(( $(date +%s) - ${at:-0} ))
}

# Only macOS keeps the login where refresh() can read it; elsewhere the
# usage poller is the source.
can_refresh() {
    command -v security >/dev/null 2>&1
}

keychain_service() {
    if [[ "$CONFIG_DIR" == "$DEFAULT_DIR" ]]; then
        echo "Claude Code-credentials"
    else
        echo "Claude Code-credentials-$(printf '%s' "$CONFIG_DIR" | shasum -a 256 | cut -c1-8)"
    fi
}

iso_to_epoch() {
    local ts="$1"
    [[ -z "$ts" || "$ts" == "null" ]] && { echo 0; return; }
    date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" "+%s" 2>/dev/null || echo 0
}

fetch_usage() {
    local token
    token=$(security find-generic-password -s "$(keychain_service)" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
    [[ -n "$token" ]] || return 1
    curl -s --max-time 8 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage"
}

# Pull usage for this profile and merge it into the shared file, keyed by
# config dir so profiles share one cache without clobbering.
refresh() {
    local response tmp
    response=$(fetch_usage) || return 1
    jq -e '.error' >/dev/null 2>&1 <<<"$response" && return 1
    jq -e '.five_hour.utilization and .seven_day.utilization' >/dev/null 2>&1 <<<"$response" || return 1
    tmp=$(mktemp "$CACHE_DIR/usage.XXXXXX") || return 1
    usage_record "$response" > "$tmp" 2>/dev/null && mv -f "$tmp" "$CACHE_FILE"
    rm -f "$tmp"
}

# The cache file with this dir's record replaced by the response in $1.
usage_record() {
    jq -n \
        --slurpfile old <(cat "$CACHE_FILE" 2>/dev/null || echo '{}') \
        --argjson r "$1" \
        --arg k "$CONFIG_DIR" \
        --argjson fetched_at "$(date +%s)" \
        --argjson five_reset "$(iso_to_epoch "$(jq -r '.five_hour.resets_at // empty' <<<"$1")")" \
        --argjson weekly_reset "$(iso_to_epoch "$(jq -r '.seven_day.resets_at // empty' <<<"$1")")" '
        def limit($kind): [$r.limits[]? | select(.kind == $kind)][0] // {};
        def whole: if type == "number" then (floor | tostring) else "" end;
        ($old[0] // {}) + { ($k): {
            fetched_at: $fetched_at,
            five_hour_pct: ($r.five_hour.utilization | whole),
            weekly_pct: ($r.seven_day.utilization | whole),
            five_hour_reset: $five_reset,
            weekly_reset: $weekly_reset,
            scoped_pct: (limit("weekly_scoped").percent | whole),
            scoped_model: (limit("weekly_scoped").scope.model.display_name // ""),
            weekly_sev: (limit("weekly_all").severity // ""),
            scoped_sev: (limit("weekly_scoped").severity // "")
        } }'
}

release_lock() { rmdir "$LOCK_DIR" 2>/dev/null; }

# Non-blocking. Returns 1 if someone else is already refreshing.
acquire_lock() {
    mkdir "$LOCK_DIR" 2>/dev/null && return 0
    local age
    age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if (( age > LOCK_STALE )); then
        rmdir "$LOCK_DIR" 2>/dev/null
        mkdir "$LOCK_DIR" 2>/dev/null && return 0
    fi
    return 1
}

# Each dir refreshes on its own record's age, so a fresh record on a shared
# login never stops another dir's fetch. Prints the accounts to show: with
# nothing for this dir yet it fetches in the foreground and reads again, so the
# first render is not blank.
refreshed_accounts() {
    local all="$1"
    if can_refresh && (( $(own_record_age) >= CACHE_TTL )) && acquire_lock; then
        if grep -q '^self|' <<<"$all"; then
            ( refresh; release_lock ) >/dev/null 2>&1 &
            disown 2>/dev/null
        else
            refresh >/dev/null 2>&1
            release_lock
            all=$(read_accounts)
        fi
    fi
    printf '%s\n' "$all"
}

emit() {
    local all="$1"
    if grep -q '^self|' <<<"$all"; then
        sed -n 's/^self|//p' <<<"$all"
    else
        echo "unknown"
    fi
    sed -n '/^other|/p' <<<"$all"
    codex_line
}

mkdir -p "$CACHE_DIR"
emit "$(refreshed_accounts "$(read_accounts)")"
exit 0
