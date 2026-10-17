#!/bin/zsh
# Runs basement-health in a temp home with stubbed commands (the script puts ~/.local/bin on PATH).
# Run: zsh tests/test_basement_health.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/dot_local/bin/executable_basement-health"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/.local/bin"
mkdir -p "$BIN" "$TMP/.local/state/restic" "$TMP/unas/restic" "$TMP/.claude" "$TMP/.claude-profiles/work"
echo repo > "$TMP/unas/restic/config"
for s in last-success-basement last-success-mac last-check-ok; do touch "$TMP/.local/state/restic/$s"; done

stub() { printf '#!/bin/sh\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
stub agent-chat 'echo "socket   up"'
stub curl 'exit 0'
stub df 'echo Use; echo " 10%"'
stub nvidia-smi 'echo 40'
stub timeout 'shift; exec "$@"'
stub gh "exit \$(cat $TMP/gh-rc)"
stub systemctl "case \"\$*\" in
  *list-timers*) cat $TMP/timers.json ;;
  *list-unit-files*) cat $TMP/enabled ;;
  *is-active*) for last; do :; done; grep -qx \"\$last\" $TMP/inactive && exit 3; exit 0 ;;
esac"

now_us() { echo $(( $(date +%s) * 1000000 )); }
expires_in_days() { echo $(( ($(date +%s) + $1 * 86400) * 1000 )); }
healthy() {
  echo 0 > "$TMP/gh-rc"
  echo "[{\"unit\":\"a.timer\",\"next\":$(( $(now_us) + 60000000 )),\"last\":0}]" > "$TMP/timers.json"
  echo "a.timer enabled enabled" > "$TMP/enabled"
  : > "$TMP/inactive"
  echo "{\"claudeAiOauth\":{\"refreshTokenExpiresAt\":$(expires_in_days 20)}}" > "$TMP/.claude/.credentials.json"
  echo "{\"claudeAiOauth\":{\"refreshTokenExpiresAt\":$(expires_in_days 20)}}" > "$TMP/.claude-profiles/work/.credentials.json"
}
run() { HOME="$TMP" BASEMENT_HEALTH_UNAS="$TMP/unas" bash "$SCRIPT"; }
failing() { jq -r '.failing | join(",")' "$TMP/.local/state/basement-health/status.json"; }
detail() { jq -r --arg n "$1" '.details[] | select(startswith($n + ":"))' "$TMP/.local/state/basement-health/status.json"; }
check() {
  if eval "$2"; then echo "ok   $1"; else echo "FAIL $1 (failing: $(failing))"; FAILS=$((FAILS + 1)); fi
}

healthy; run
check "a healthy host reports ok" '[[ $(failing) == "" ]]'

healthy; echo "{\"claudeAiOauth\":{\"refreshTokenExpiresAt\":$(expires_in_days 3)}}" > "$TMP/.claude-profiles/work/.credentials.json"; run
check "a refresh token inside 7 days fails token-expiry" '[[ $(failing) == token-expiry ]]'
check "token-expiry names the profile" 'detail token-expiry | grep -q "work in [23]d"'

healthy; echo '{"claudeAiOauth":{}}' > "$TMP/.claude/.credentials.json"; run
check "credentials without a refresh expiry are skipped" '[[ $(failing) == "" ]]'

healthy; echo 1 > "$TMP/gh-rc"; run
check "a failing gh auth fails gh-auth" '[[ $(failing) == gh-auth ]]'

healthy; echo "[{\"unit\":\"a.timer\",\"next\":$(( $(now_us) - 3600000000 )),\"last\":0}]" > "$TMP/timers.json"; run
check "a timer an hour past its next run fails stale-timers" 'detail stale-timers | grep -q "overdue: a.timer;"'

healthy; echo "[{\"unit\":\"a.timer\",\"next\":$(( $(now_us) - 120000000 )),\"last\":0}]" > "$TMP/timers.json"; run
check "a timer 2 min late is within grace" '[[ $(failing) == "" ]]'

healthy; echo "a.timer" > "$TMP/inactive"; run
check "an enabled timer that is not running fails stale-timers" 'detail stale-timers | grep -q "not running: a.timer$"'

exit $FAILS
