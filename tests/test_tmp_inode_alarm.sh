#!/bin/zsh
# Runs tmp-inode-alarm with stub df and agent-chat in a temp home.
# Run: zsh tests/test_tmp_inode_alarm.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/dot_local/bin/executable_tmp-inode-alarm"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho IUse%%\necho " $(cat %s/pct)%%"\n' "$TMP" > "$TMP/bin/df"
printf '#!/bin/sh\necho "$3" >> %s/sent\n' "$TMP" > "$TMP/bin/agent-chat"
chmod +x "$TMP/bin/df" "$TMP/bin/agent-chat"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}
run_at() {
    rm -rf "$TMP/sent" "$TMP/.local/state/tmp-inode-alarm"
    mkdir -p "$TMP/.local/state/tmp-inode-alarm"
    echo "$1" > "$TMP/.local/state/tmp-inode-alarm/last-pct"
    echo "$2" > "$TMP/pct"
    HOME="$TMP" PATH="$TMP/bin:$PATH" TMP_INODE_ALARM_TO=someone bash "$SCRIPT"
}

run_at 2 30
check "a spike below 60% sends nothing" '[[ ! -s "$TMP/sent" ]]'

run_at 59 61
check "crossing 60% without a spike sends level 60" 'grep -q "(level 60;" "$TMP/sent"'

run_at 55 70
check "a spike above 60% sends level 60+spike" 'grep -q "(level 60+spike;" "$TMP/sent"'

run_at 40 45
check "below 60% without a spike sends nothing" '[[ ! -s "$TMP/sent" ]]'

exit $FAILS
