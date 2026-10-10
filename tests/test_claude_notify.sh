#!/bin/zsh
# Runs the Notification hook against stubbed uname, osascript and curl in a throwaway HOME.
# Run: zsh tests/test_claude_notify.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/dot_local/bin/executable_claude-notify"
FAILS=0

WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
STUBS="$WORK/stubs" LOG="$WORK/log"
mkdir -p "$STUBS"
print -r -- '#!/bin/sh
echo "${FAKE_UNAME:-Linux}"' > "$STUBS/uname"
print -r -- '#!/bin/sh
printf "osascript %s\n" "$*" >> "$LOG"' > "$STUBS/osascript"
print -r -- '#!/bin/sh
printf "curl %s\n" "$*" >> "$LOG"
case " $* " in *" -K - "*) sed "s/^/stdin /" >> "$LOG" ;; esac
exit "${CURL_EXIT:-0}"' > "$STUBS/curl"
chmod +x "$STUBS"/*
export LOG PATH="$STUBS:$PATH"
unset AGENT_CHAT_NAME

reset_home() {
    export HOME="$WORK/home-$1" XDG_RUNTIME_DIR="$WORK/run-$1"
    mkdir -p "$HOME/.config/claude-notify"
    : > "$LOG"
}

write_env() {
    print -r -- "# NTFY_URL=https://ntfy.invalid/commented-out
NTFY_URL=https://ntfy.invalid/test-topic$1" > "$HOME/.config/claude-notify/env"
}

hook() {
    printf '{"session_id":"%s","cwd":"/work/my-repo","message":"Claude needs your permission to use Bash"}' "$1" |
        AGENT_CHAT_NAME="${AGENT_CHAT_NAME-}" sh "$SCRIPT"
}

check() {
    local name="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then echo "ok   $name"; else echo "FAIL $name"; echo "     got:  $got"; echo "     want: $want"; FAILS=$((FAILS + 1)); fi
}

posts() { grep -c '^curl ' "$LOG"; }

reset_home darwin
FAKE_UNAME=Darwin hook s1; rc=$?
check "darwin shows the same local notification as before" "$(cat "$LOG")" \
    "osascript -e display notification \"Claude Code needs your attention\" with title \"Claude Code\" sound name \"Funk\""
check "darwin exits 0" "$rc" 0

reset_home once; write_env
hook s1; rc=$?
check "linux posts once" "$(posts)" 1
check "linux titles the post with the cwd basename" "$(grep -c -- '-H Title: Claude: my-repo ' "$LOG")" 1
check "linux sends the hook message as the body" "$(grep -c -- '--data-binary Claude needs your permission to use Bash https://ntfy.invalid/test-topic$' "$LOG")" 1
check "linux leaves osascript alone" "$(grep -c '^osascript' "$LOG")" 0
check "linux exits 0 after posting" "$rc" 0

hook s1
check "a second call in the same session within 10 min is suppressed" "$(posts)" 1
hook s2
check "another session still posts" "$(posts)" 2

print 1 > "$XDG_RUNTIME_DIR/claude-notify/s1"
hook s1
check "the same session posts again once 10 min have passed" "$(posts)" 3

reset_home agent; write_env
AGENT_CHAT_NAME=reviewer hook s1
check "an agent name wins over the cwd in the title" "$(grep -c -- '-H Title: Claude: reviewer ' "$LOG")" 1

reset_home token; write_env "
NTFY_TOKEN=tk_secret"
hook s1
check "the token goes to curl on stdin" "$(grep -c '^stdin header = "Authorization: Bearer tk_secret"$' "$LOG")" 1
check "the token stays out of curl's arguments" "$(grep '^curl ' "$LOG" | grep -c tk_secret)" 0

reset_home noenv
hook s1; rc=$?
check "a missing env file posts nothing" "$(posts)" 0
check "a missing env file exits 0" "$rc" 0
check "a missing env file is silent" "$(hook s2 2>&1)" ""

reset_home placeholder
print -r -- "# NTFY_URL=https://ntfy.invalid/<topic>" > "$HOME/.config/claude-notify/env"
hook s1
check "an env file with only the commented placeholder posts nothing" "$(posts)" 0

reset_home curlfail; write_env
out=$(CURL_EXIT=7 hook s1 2>&1); rc=$?
check "a curl failure exits 0" "$rc" 0
check "a curl failure is silent" "$out" ""

reset_home nordir; unset XDG_RUNTIME_DIR; write_env
hook s1
check "without XDG_RUNTIME_DIR the state lives in ~/.cache" "$(ls "$HOME/.cache/claude-notify")" s1

echo
if (( FAILS )); then echo "$FAILS failed"; exit 1; fi
echo "all passed"
