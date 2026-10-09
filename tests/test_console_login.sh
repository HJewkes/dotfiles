#!/bin/zsh
# Runs console-login against a stub ssh and a stub opener.
# Run: zsh tests/test_console_login.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/dot_local/bin/executable_console-login"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
LINK='https://box.example.ts.net:7500/auth/login?code=abc123'

printf '#!/bin/sh\necho "$1" > "%s/host"\nprintf "%%s" "$STUB_OUTPUT"\n' "$TMP" > "$TMP/ssh"
printf '#!/bin/sh\necho "$1" > "%s/opened"\n' "$TMP" > "$TMP/open"
chmod +x "$TMP/ssh" "$TMP/open"
export CONSOLE_LOGIN_SSH="$TMP/ssh" CONSOLE_LOGIN_OPEN="$TMP/open"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}

STUB_OUTPUT="$LINK
Open it within ten minutes on the device to sign in; it works once.
" sh "$SCRIPT" > "$TMP/out" 2>&1
check "the link line is opened, not the hint after it" '[[ "$(cat "$TMP/opened")" == "$LINK" ]]'
check "the link never reaches the terminal" '! grep -q "code=" "$TMP/out"'
check "the default host is basement" '[[ "$(cat "$TMP/host")" == basement ]]'

rm -f "$TMP/opened"
STUB_OUTPUT="error: no token file" sh "$SCRIPT" > "$TMP/out" 2>&1
rc=$?
check "a non-link answer exits non-zero" '(( rc != 0 ))'
check "a non-link answer opens nothing" '[[ ! -e "$TMP/opened" ]]'

STUB_OUTPUT="$LINK" CONSOLE_LOGIN_HOST=other sh "$SCRIPT" > /dev/null 2>&1
check "CONSOLE_LOGIN_HOST picks the host" '[[ "$(cat "$TMP/host")" == other ]]'

exit $FAILS
