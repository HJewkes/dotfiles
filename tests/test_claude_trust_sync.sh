#!/bin/zsh
# Runs claude-trust-sync.sh against fake profiles in a temp home; never touches real configs.
# Run: zsh tests/test_claude_trust_sync.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/private_dot_claude/scripts/executable_claude-trust-sync.sh"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude" "$TMP/.claude-profiles/work" "$TMP/.claude-profiles/play"
echo '{"projects": {"/repo/a": {"hasTrustDialogAccepted": true, "lastCost": 3}}}' > "$TMP/.claude.json"
echo '{"projects": {"/repo/b": {"hasTrustDialogAccepted": true}}, "userID": "keep"}' > "$TMP/.claude-profiles/work/.claude.json"
echo '{}' > "$TMP/.claude-profiles/play/.claude.json"
printf '# comment\n\n~/listed\n/abs/listed\n' > "$TMP/.claude/trusted-folders.txt"
echo '~/private' > "$TMP/.claude/trusted-folders.local.txt"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}
trusted() {
    jq -e --arg p "$2" '.projects[$p].hasTrustDialogAccepted == true' "$1" >/dev/null
}

HOME="$TMP" bash "$SCRIPT" --dry-run >/dev/null
check "dry run writes nothing" '! trusted "$TMP/.claude-profiles/play/.claude.json" /repo/a'

HOME="$TMP" bash "$SCRIPT" >/dev/null
for f in "$TMP/.claude.json" "$TMP"/.claude-profiles/*/.claude.json; do
    name="${f#$TMP/}"
    check "$name trusts folders trusted elsewhere" 'trusted "$f" /repo/a && trusted "$f" /repo/b'
    check "$name trusts listed folders with ~ expanded" 'trusted "$f" "$TMP/listed" && trusted "$f" /abs/listed'
done
check "local list folders are trusted" 'trusted "$TMP/.claude.json" "$TMP/private"'
check "comment lines are not trusted" '! jq -e ".projects | has(\"# comment\")" "$TMP/.claude.json" >/dev/null'
check "other per-profile state is kept" 'jq -e ".userID == \"keep\"" "$TMP/.claude-profiles/work/.claude.json" >/dev/null'
check "existing project fields are kept" 'jq -e ".projects[\"/repo/a\"].lastCost == 3" "$TMP/.claude.json" >/dev/null'

rm -rf "$TMP/.claude-profiles"
echo '{}' > "$TMP/.claude.json"
HOME="$TMP" bash "$SCRIPT" >/dev/null
check "a lone config still gets the listed folders" 'trusted "$TMP/.claude.json" /abs/listed'

check "second run reports nothing to do" 'HOME="$TMP" bash "$SCRIPT" | grep -q "nothing to do"'

exit $FAILS
