#!/bin/zsh
# Checks the basement-only units: they render and verify on a server, stay off other machines,
# and match what is live on this host.
# Run on basement: zsh tests/test_basement_units.sh
ROOT="${0:A:h:h}"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
# The active-work data dir stays out of this public repo: restic-nightly renders it from local data.
AW_DATA_DIR=$(chezmoi data --format json | jq -r '.awDataDir // empty')
[ -n "$AW_DATA_DIR" ] || { echo "FAIL awDataDir missing from the local chezmoi config"; exit 1; }

UNITS=(restic-nightly restic-check restic-stamp-mac)
TARGETS=(.config/restic/unas.pass)
for u in $UNITS; do
    TARGETS+=(.local/bin/$u .config/systemd/user/$u.service .config/systemd/user/$u.timer)
done

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

write_config() {
    cat > "$TMP/$1.toml" <<CONF
encryption = "age"
[age]
    identity = "$HOME/.config/chezmoi/key.txt"
    recipient = "age1j7hqrrzez0xus82vt3akl79vwev7cyt7mzdymz2kzrvu6wqjmpkqxgsm0v"
[data]
    name = "test"
    email = "test@example.com"
    machine = "$1"
    awDataDir = "$AW_DATA_DIR"
    macHost = "test-mac.example"
CONF
}

cz() {
    local machine=$1; shift
    chezmoi --source "$ROOT" --config "$TMP/$machine.toml" --destination "$TMP/$machine" \
        --cache "$TMP/cache-$machine" --persistent-state "$TMP/state-$machine.boltdb" "$@"
}

write_config server
write_config personal
mkdir -p "$TMP/server" "$TMP/personal"

server_managed=$(cz server managed --include files)
personal_managed=$(cz personal managed --include files)
for t in $TARGETS; do
    check "server manages $t" 'grep -qxF "$t" <<< "$server_managed"'
    check "non-server machine does not manage $t" '! grep -qxF "$t" <<< "$personal_managed"'
done

mkdir -p "$TMP/server"/{.config/restic,.config/systemd/user,.local/bin}
cz server apply --force ${TARGETS/#/$TMP/server/}
for u in $UNITS; do
    for kind in service timer; do
        unit="$TMP/server/.config/systemd/user/$u.$kind"
        check "$u.$kind passes systemd-analyze verify" \
            'HOME="$TMP/server" systemd-analyze --user verify "$unit" 2>"$TMP/verify.err" && [ ! -s "$TMP/verify.err" ] || { cat "$TMP/verify.err"; false; }'
    done
    check "$u script is executable" '[ -x "$TMP/server/.local/bin/$u" ]'
done
check "restic-stamp-mac renders the macHost data" 'grep -qxF "mac_host=\"test-mac.example\"" "$TMP/server/.local/bin/restic-stamp-mac"'
check "repo password decrypts to the live file" 'cmp -s "$TMP/server/.config/restic/unas.pass" "$HOME/.config/restic/unas.pass"'

# Content, not mode: the live restic-nightly is 0755 and chezmoi's umask renders 0775.
for t in $TARGETS; do
    check "$t matches the live file on this host" 'chezmoi --source "$ROOT" cat "$HOME/$t" | cmp -s - "$HOME/$t"'
done

exit $FAILS
