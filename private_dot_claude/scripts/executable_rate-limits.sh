#!/bin/bash
# Usage figures for the ACTIVE Claude profile, from a shared cache.
#
# Line 1: 5HR|WEEKLY|5HR_RESET|WEEKLY_RESET|SCOPED_PCT|SCOPED_MODEL|WEEKLY_SEV|SCOPED_SEV|AGE
# Then one line per other cached profile: other|NAME|5HR|WEEKLY|AGE|WEEKLY_SEV
# On failure: "unknown" (other-profile lines may still follow)
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

# Emit every cached record in one jq pass: "self|..." for this profile, then
# "other|NAME|5HR|WEEKLY|AGE|WEEKLY_SEV" per other account. Ages are seconds
# since the record was fetched. Other profiles are read from cache only; they
# are refreshed by their own sessions, never from here.
#
# Usage is per login, and several config dirs can share one login. Dirs whose
# identity files carry the same account id collapse into one account, served
# from the record with the newest fetched_at; if the current dir is a member,
# that account is "self". The id is only compared in memory, never emitted.
read_cache() {
    [[ -f "$CACHE_FILE" ]] || return 1
    local f identity_files=()
    shopt -s nullglob
    for f in "$HOME/.claude.json" "$CONFIG_DIR/.claude.json" "$HOME"/.claude-profiles/*/.claude.json; do
        # A file listed twice would be read twice and no longer parse.
        [[ -f "$f" && " ${identity_files[*]} " != *" $f "* ]] && identity_files+=("$f")
    done
    shopt -u nullglob
    jq -n -R -r --slurpfile cache "$CACHE_FILE" --arg k "$CONFIG_DIR" --arg def "$DEFAULT_DIR" --arg home_id "$HOME/.claude.json" \
        --argjson now "$(date +%s)" '
        def age: $now - (.fetched_at // 0);
        def name: .key | sub(".*/"; "") | if . == ".claude" then "default" else . end;
        def idfile($dir): if $dir == $def then $home_id else $dir + "/.claude.json" end;
        # Identity files are read raw: Claude Code rewrites them often, so one
        # caught mid-write must only stop that dir from merging.
        (reduce inputs as $line ({}; .[input_filename] += [$line])
            | map_values(try (join("\n") | fromjson | .oauthAccount.accountUuid) catch null)) as $ids
        | ($cache[0] | to_entries
            | map(. + {account: ($ids[idfile(.key)] // .key)})
            | group_by(.account)
            | map({members: ., best: (max_by(.value.fetched_at // 0))})) as $accounts
        | ($accounts | map(select(any(.members[]; .key == $k)))[0].best // empty
            | .value
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
              ] | join("|")),
          ($accounts[] | select(any(.members[]; .key == $k) | not) | .best
            | [ "other", name
              , (.value.five_hour_pct // "unknown")
              , (.value.weekly_pct    // "unknown")
              , (.value | age)
              , (.value.weekly_sev    // "")
              ] | join("|"))
    ' "${identity_files[@]}" 2>/dev/null
}

# Output contract: the own record (without its tag) first, then the others.
emit() {
    local all="$1"
    sed -n 's/^self|//p' <<<"$all"
    sed -n '/^other|/p' <<<"$all"
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

all=$(read_cache)
self_line=$(sed -n 's/^self|//p' <<<"$all")
age=${self_line##*|}
[[ "$age" =~ ^[0-9]+$ ]] || age=999999

if (( age < CACHE_TTL )); then
    emit "$all"
    exit 0
fi

if [[ -n "$self_line" ]]; then
    # Stale but usable: serve it now, refresh out of band so the prompt stays fast.
    if acquire_lock; then
        ( refresh; release_lock ) >/dev/null 2>&1 &
        disown 2>/dev/null
    fi
    emit "$all"
    exit 0
fi

# Nothing cached for this profile: fetch synchronously so the first render is not blank.
if acquire_lock; then
    refresh >/dev/null 2>&1
    release_lock
fi

all=$(read_cache)
if grep -q '^self|' <<<"$all"; then emit "$all"; exit 0; fi
echo "unknown"
[[ -n "$all" ]] && emit "$all"
exit 0
