#!/bin/zsh
# Runs refresh-usage.sh against fake profiles and a stub rate-limits script.
# Run: zsh tests/test_refresh_usage.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/scripts/executable_refresh-usage.sh"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/profiles/recent" "$TMP/profiles/good" "$TMP/profiles/broken" "$TMP/profiles/crashy" "$TMP/profiles/tokenless" "$TMP/profiles/remote" "$TMP/default"
touch "$TMP/profiles/remote/usage-remote"
export REFRESH_PROFILES_DIR="$TMP/profiles" REFRESH_CACHE_FILE="$TMP/usage.json" REFRESH_DEFAULT_DIR="$TMP/default" \
    REFRESH_LOG_FILE="$TMP/logs/refresh.log" REFRESH_RATE_LIMITS="$TMP/stub.sh"

# Stub: "good" writes a fresh record (plus one already 30s old for "recent"), "crashy" exits non-zero, "broken" does nothing.
cat > "$TMP/stub.sh" <<STUB
#!/bin/bash
case "\$(basename "\$CLAUDE_CONFIG_DIR")" in
  good) echo "{\"\$CLAUDE_CONFIG_DIR\": {\"fetched_at\": \$(date +%s)}, \"$TMP/profiles/recent\": {\"fetched_at\": \$(( \$(date +%s) - 30 ))}}" > "$TMP/usage.json" ;;
  crashy) exit 3 ;;
esac
STUB
chmod +x "$TMP/stub.sh"

# Fake Keychain: every dir has a login except "tokenless" and "remote".
mkdir -p "$TMP/bin"
cat > "$TMP/bin/security" <<SEC
#!/bin/bash
for h in $(for p in tokenless remote; do printf '%s' "$TMP/profiles/$p" | shasum -a 256 | cut -c1-8; done | tr "\n" " "); do
  [[ "\$*" == *"-credentials-\$h"* ]] && exit 44
done
exit 0
SEC
chmod +x "$TMP/bin/security"
export PATH="$TMP/bin:$PATH"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

bash "$SCRIPT"
check "healthy profile is not logged" '! grep -q " good " "$REFRESH_LOG_FILE"'
check "profile with a record under the TTL old is not logged" '! grep -q " recent " "$REFRESH_LOG_FILE"'
check "non-zero exit is logged with its code" 'grep -q " crashy exit 3$" "$REFRESH_LOG_FILE"'
check "profile with no fresh record is logged" 'grep -q " broken no fresh usage" "$REFRESH_LOG_FILE"'
check "profile with no login or remote source is skipped" '! grep -q " tokenless " "$REFRESH_LOG_FILE"'
check "remote-only profile is still polled" 'grep -q " remote no fresh usage" "$REFRESH_LOG_FILE"'

for i in {1..300}; do echo "old line $i" >> "$REFRESH_LOG_FILE"; done
bash "$SCRIPT"
check "log is truncated to its bound" '(( $(wc -l < "$REFRESH_LOG_FILE") <= 200 ))'
check "newest failures survive truncation" 'tail -n 3 "$REFRESH_LOG_FILE" | grep -q " crashy exit 3$"'

exit $FAILS
