#!/bin/zsh
# Renders restic-stamp-mac and runs it against stub restic, mountpoint and hostname in a temp home.
# Run: zsh tests/test_restic_stamp_mac.sh
ROOT="${0:A:h:h}"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
printf '#!/bin/sh\ncat %s/snapshots.json\n' "$TMP" > "$TMP/bin/restic"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/mountpoint"
printf '#!/bin/sh\necho server.example\n' > "$TMP/bin/hostname"
chmod +x "$TMP/bin"/*

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

# $1 is the macHost data line, or empty to leave the key out.
render() {
    printf '[data]\n    machine = "server"\n%s\n' "$1" > "$TMP/config.toml"
    chezmoi --config "$TMP/config.toml" --source "$ROOT" execute-template \
        < "$ROOT/dot_local/bin/executable_restic-stamp-mac.tmpl" > "$TMP/restic-stamp-mac"
}

snapshot() { printf '{"hostname":"%s","time":"%s"}' "$1" "$2"; }

stamp_with() {
    print -r -- "[$(IFS=,; echo "$*")]" > "$TMP/snapshots.json"
    rm -rf "$TMP/.local/state/restic"
    HOME="$TMP" PATH="$TMP/bin:$PATH" bash "$TMP/restic-stamp-mac" 2>/dev/null
}

stamped() { cat "$TMP/.local/state/restic/last-success-mac" 2>/dev/null; }

OLD=2026-01-01T02:45:00-06:00
NEW=2026-01-05T02:45:00-06:00
SELF=2026-01-06T02:30:00-06:00

render '    macHost = "old-mac.example"'
stamp_with "$(snapshot old-mac.example $OLD)" "$(snapshot renamed-mac.example $NEW)" "$(snapshot server.example $SELF)"
check "a renamed Mac's newer snapshot wins over the stale macHost" '[ "$(stamped)" = "$NEW" ]'

stamp_with "$(snapshot old-mac.example $NEW)" "$(snapshot server.example $SELF)"
check "the server's own snapshot is never stamped as the Mac's" '[ "$(stamped)" = "$NEW" ]'

stamp_with "$(snapshot server.example $SELF)"
rc=$?
check "only the server's own snapshot fails without a stamp" '[ $rc -ne 0 ] && [ -z "$(stamped)" ]'

render ''
check "renders with no macHost in the data" '[ -s "$TMP/restic-stamp-mac" ] && grep -qxF "mac_host=\"\"" "$TMP/restic-stamp-mac"'
stamp_with "$(snapshot renamed-mac.example $NEW)" "$(snapshot server.example $SELF)"
check "stamps another host's snapshot with no macHost" '[ "$(stamped)" = "$NEW" ]'

exit $FAILS
