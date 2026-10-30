#!/bin/zsh
# Runs basement-suite in a temp home with fake git and pnpm, and kills it mid-run and mid-cleanup.
# Run: zsh tests/test_basement_suite.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/dot_local/bin/executable_basement-suite"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
SHIMS="$TMP/shims"
SRC="$TMP/projects/titan-platform"
RUNS="$TMP/suite-runs"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$SHIMS" "$SRC/.git" "$RUNS" "$TMP/runtime" "$TMP/marks"

# Each shim drops its own dir from PATH, so nothing it starts can reach a fake.
cat > "$SHIMS/git" <<'EOF'
#!/bin/bash
PATH=${PATH#"$FAKE_SHIMS":}
[[ $1 == -C ]] && shift 2
case "$1 $2" in
  "worktree add")
    mkdir -p "$5"; touch "$5/.git" "$5/.git-from-fake"; echo '{}' > "$5/package.json" ;;
  "worktree remove")
    [[ -e $4/.git ]] || exit 128
    touch "$FAKE_MARKS/remove-entered"
    if [[ -n ${FAKE_SLOW_REMOVE:-} ]]; then sleep "$FAKE_SLOW_REMOVE"; fi
    rm -rf "$4" ;;
  "rev-parse HEAD") echo 0123456789abcdef ;;
esac
exit 0
EOF
cat > "$SHIMS/pnpm" <<'EOF'
#!/bin/bash
PATH=${PATH#"$FAKE_SHIMS":}
[[ $1 == run ]] || exit 0
mkdir -p "$TMPDIR/vt-fake"; touch "$TMPDIR/vt-fake/fixture"
echo "$TMPDIR" > "$FAKE_MARKS/run-tmp"
touch "$FAKE_MARKS/test-started"
if [[ -n ${FAKE_SLOW_TEST:-} ]]; then sleep "$FAKE_SLOW_TEST"; fi
exit 0
EOF
chmod +x "$SHIMS/git" "$SHIMS/pnpm"

check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}
suite() {
    HOME="$TMP" XDG_RUNTIME_DIR="$TMP/runtime" PATH="$SHIMS:$PATH" BASEMENT_SUITE_LEGACY_TMP="$TMP/legacy" \
        FAKE_SHIMS="$SHIMS" FAKE_MARKS="$TMP/marks" \
        setsid --wait bash -c 'echo $$ > "$FAKE_MARKS/pid"; exec bash "$@"' _ \
        "$SCRIPT" titan-platform some-branch --agent fake --no-build
}
wait_for() {
    local tries=500
    while [[ ! -e $1 && $tries -gt 0 ]]; do sleep 0.02; tries=$((tries - 1)); done
    [[ -e $1 ]]
}
reset_marks() {
    rm -f "$TMP"/marks/*(N)
}
no_worktrees() {
    [[ -z $(find "$RUNS" -mindepth 2 -maxdepth 2 -type d -name 'titan-platform-*') ]]
}
run_tmp_gone() {
    [[ -s $TMP/marks/run-tmp && ! -e $(cat "$TMP/marks/run-tmp") ]]
}
dead_pid() {
    sh -c 'exit 0' &
    local pid=$!
    wait "$pid"
    echo "$pid"
}
# The run leads its own group, so this is what `timeout` delivers to it and its children.
term_group() {
    kill -TERM -- "-$(cat "$TMP/marks/pid")"
}

reset_marks
suite >/dev/null
code=$?
check "a clean run exits 0" '[[ $code -eq 0 ]]'
check "a clean run leaves no run dir" 'run_tmp_gone'
check "a clean run leaves no worktree" 'no_worktrees'
check "the run dir is on disk under the cache, not in /tmp" '[[ $(cat "$TMP/marks/run-tmp") == "$TMP/.cache/basement-suite/run-"* ]]'

reset_marks
FAKE_SLOW_TEST=30 suite >/dev/null &
pid=$!
wait_for "$TMP/marks/test-started"
term_group
wait "$pid"
code=$?
check "SIGTERM during the test exits 130" '[[ $code -eq 130 ]]'
check "SIGTERM during the test leaves no run dir" 'run_tmp_gone'
check "SIGTERM during the test leaves no worktree" 'no_worktrees'

reset_marks
FAKE_SLOW_REMOVE=2 suite >/dev/null &
pid=$!
wait_for "$TMP/marks/remove-entered"
check "the run dir is removed before the slow worktree remove" 'run_tmp_gone'
term_group
sleep 0.2
term_group 2>/dev/null
wait "$pid"
code=$?
check "SIGTERM mid-cleanup keeps the finished run's exit code" '[[ $code -eq 0 ]]'
check "SIGTERM mid-cleanup leaves no run dir" 'run_tmp_gone'
check "SIGTERM mid-cleanup leaves no worktree" 'no_worktrees'

gone=$(dead_pid)
half=$(dead_pid)
stamp=20260101-000000
mkdir -p "$TMP/.cache/basement-suite/run-$gone/vt-fake" "$RUNS/other/titan-platform-$stamp-$gone" "$RUNS/other/titan-platform-$stamp-$half"
touch "$RUNS/other/titan-platform-$stamp-$gone/.git" "$RUNS/other/titan-platform-$stamp-$gone.log"
mkdir -p "$RUNS/other/titan-platform-$stamp-$$" "$TMP/.cache/basement-suite/run-$$" "$RUNS/other/titan-design-$stamp-$gone"
mkdir -p "$TMP/legacy/bs-$gone" "$TMP/legacy/bs-$$" "$TMP/legacy/bs-notes"
reset_marks
suite >/dev/null
check "a dead run's dir is swept at start" '[[ ! -e $TMP/.cache/basement-suite/run-$gone ]]'
check "a dead run's old /tmp dir is swept at start" '[[ ! -e $TMP/legacy/bs-$gone ]]'
check "a live run's old /tmp dir survives the sweep" '[[ -d $TMP/legacy/bs-$$ ]]'
check "a bs- dir with no pid in its name survives the sweep" '[[ -d $TMP/legacy/bs-notes ]]'
check "a dead run's worktree is swept at start" '[[ ! -e $RUNS/other/titan-platform-$stamp-$gone ]]'
check "a half-removed worktree of a dead run is swept" '[[ ! -e $RUNS/other/titan-platform-$stamp-$half ]]'
check "a dead run's log survives the sweep" '[[ -e $RUNS/other/titan-platform-$stamp-$gone.log ]]'
check "a live run's worktree survives the sweep" '[[ -d $RUNS/other/titan-platform-$stamp-$$ ]]'
check "a live run's dir survives the sweep" '[[ -d $TMP/.cache/basement-suite/run-$$ ]]'
check "another repo's worktree is left to that repo's runs" '[[ -d $RUNS/other/titan-design-$stamp-$gone ]]'

exit $FAILS
