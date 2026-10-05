#!/bin/zsh
# Runs refresh-usage.sh against fake profiles and a stub rate-limits script.
# Run: zsh tests/test_refresh_usage.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/scripts/executable_refresh-usage.sh"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/profiles/good" "$TMP/profiles/broken" "$TMP/profiles/crashy"
export REFRESH_PROFILES_DIR="$TMP/profiles" REFRESH_CACHE_FILE="$TMP/usage.json" \
    REFRESH_LOG_FILE="$TMP/logs/refresh.log" REFRESH_RATE_LIMITS="$TMP/stub.sh" REFRESH_WAIT_SECONDS=1

# Stub: "good" writes a fresh record, "crashy" exits non-zero, "broken" does nothing.
cat > "$TMP/stub.sh" <<STUB
#!/bin/bash
case "\$(basename "\$CLAUDE_CONFIG_DIR")" in
  good) echo "{\"\$CLAUDE_CONFIG_DIR\": {\"fetched_at\": \$(date +%s)}}" > "$TMP/usage.json" ;;
  crashy) exit 3 ;;
esac
STUB
chmod +x "$TMP/stub.sh"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

bash "$SCRIPT"
check "healthy profile is not logged" '! grep -q " good " "$REFRESH_LOG_FILE"'
check "non-zero exit is logged with its code" 'grep -q " crashy exit 3$" "$REFRESH_LOG_FILE"'
check "profile with no fresh record is logged" 'grep -q " broken no fresh usage" "$REFRESH_LOG_FILE"'

for i in {1..300}; do echo "old line $i" >> "$REFRESH_LOG_FILE"; done
bash "$SCRIPT"
check "log is truncated to its bound" '(( $(wc -l < "$REFRESH_LOG_FILE") <= 200 ))'
check "newest failures survive truncation" 'tail -n 1 "$REFRESH_LOG_FILE" | grep -q " broken "'

exit $FAILS
