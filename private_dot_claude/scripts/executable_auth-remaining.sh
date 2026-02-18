#!/bin/bash
# Compute auth token remaining minutes from cached timestamp
# Output: integer minutes remaining (or "expired" / "unknown")
# Token TTL: 7200 seconds (2 hours)

CACHE_FILE="$HOME/.claude/status-cache/token_issued_at"
TTL=7200

if [[ ! -f "$CACHE_FILE" ]]; then
    echo "unknown"
    exit 0
fi

issued_at=$(cat "$CACHE_FILE" 2>/dev/null)
now=$(date +%s)
expires_at=$((issued_at + TTL))
remaining=$((expires_at - now))

if [[ $remaining -le 0 ]]; then
    echo "expired"
else
    echo $(( remaining / 60 ))
fi
