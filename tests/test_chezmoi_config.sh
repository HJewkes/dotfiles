#!/bin/zsh
# Renders .chezmoi.toml.tmpl with scripted prompt answers and checks the [data] it writes.
# Run: zsh tests/test_chezmoi_config.sh
ROOT="${0:A:h:h}"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/empty.toml"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

# Prompts are answered by their text, not their data key.
render() {
    chezmoi --config "$TMP/empty.toml" --source "$ROOT" execute-template --init \
        --promptString 'Git author name=test' \
        --promptString 'Git author email=test@example.com' \
        --promptChoice "Machine type=$1" \
        --promptString "active-work data dir to back up (may use \$HOME)=$2" \
        --promptString "Mac hostname whose restic snapshots to stamp=$3" \
        < "$ROOT/.chezmoi.toml.tmpl"
}

both=$(render server '$HOME/aw' test-mac.example)
check "server config keeps awDataDir" 'grep -qxF "    awDataDir = \"\$HOME/aw\"" <<< "$both"'
check "server config keeps macHost" 'grep -qxF "    macHost = \"test-mac.example\"" <<< "$both"'

no_aw=$(render server '' test-mac.example)
check "macHost survives an empty awDataDir" 'grep -qxF "    macHost = \"test-mac.example\"" <<< "$no_aw"'
check "an empty awDataDir is left out" '! grep -q awDataDir <<< "$no_aw"'

personal=$(render personal '' '')
check "non-server config has neither key" '! grep -qE "awDataDir|macHost" <<< "$personal"'

exit $FAILS
