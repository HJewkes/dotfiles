#!/bin/zsh
# Runs basement-suite against a real temp git repo seeded with runs that died without cleanup.
# Run: zsh tests/test_basement_suite_sweep.sh
ROOT="${0:A:h:h}"
SCRIPT="$ROOT/dot_local/bin/executable_basement-suite"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
SHIMS="$TMP/shims"
ORIGIN="$TMP/origin"
SRC="$TMP/projects/titan-platform"
RUNS="$TMP/suite-runs"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$SHIMS" "$RUNS" "$TMP/runtime" "$TMP/legacy"

cat > "$SHIMS/pnpm" <<'EOF'
#!/bin/bash
PATH=${PATH#"$FAKE_SHIMS":}
exit 0
EOF
chmod +x "$SHIMS/pnpm"

g() { git -c user.name=t -c user.email=t@example.invalid -C "$@"; }
check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}
dead_pid() {
    sh -c 'exit 0' &
    local pid=$!
    wait "$pid"
    echo "$pid"
}
listed() { g "$SRC" worktree list --porcelain | grep -qxF "worktree $1"; }
has_ref() { g "$SRC" show-ref -q --verify "refs/suite-runs/$1"; }
# A run that died leaving its fetched ref and detached tree behind.
leak_run() {
    local name=$1 age=$2
    g "$SRC" update-ref "refs/suite-runs/agent-x-$name" HEAD
    g "$SRC" worktree add -q --detach "$RUNS/agent-x/titan-platform-$name" "refs/suite-runs/agent-x-$name"
    [[ -z $age ]] || touch -d "$age" "$RUNS/agent-x/titan-platform-$name"
}

git init -q -b main "$ORIGIN"
echo '{}' > "$ORIGIN/package.json"
g "$ORIGIN" add package.json
g "$ORIGIN" commit -q -m init
g "$TMP" clone -q "$ORIGIN" "$SRC"

stamp=20260101-000000
stale_dead="$stamp-$(dead_pid)"
fresh_dead="$stamp-$(dead_pid)"
stale_live="$stamp-$$"
orphan_ref="$stamp-$(dead_pid)"
fetching_ref="$stamp-$$"
tmp_dead="bs-$(dead_pid)"
leak_run "$stale_dead" '7 hours ago'
leak_run "$fresh_dead" ''
leak_run "$stale_live" '7 hours ago'
g "$SRC" update-ref "refs/suite-runs/agent-x-$orphan_ref" HEAD
g "$SRC" update-ref "refs/suite-runs/other-$fetching_ref" HEAD
mkdir -p "$TMP/legacy/$tmp_dead/fixture" "$TMP/legacy/bs-$$"
touch "$RUNS/agent-x/titan-platform-$stale_dead.log"

HOME="$TMP" XDG_RUNTIME_DIR="$TMP/runtime" PATH="$SHIMS:$PATH" FAKE_SHIMS="$SHIMS" \
    BASEMENT_SUITE_LEGACY_TMP="$TMP/legacy" \
    bash "$SCRIPT" titan-platform main --agent fake --no-build >/dev/null
code=$?

check "the run itself exits 0" '[[ $code -eq 0 ]]'
check "a stale tree of a dead run is removed" '[[ ! -e $RUNS/agent-x/titan-platform-$stale_dead ]]'
check "git no longer lists the stale dead tree" '! listed "$RUNS/agent-x/titan-platform-$stale_dead"'
check "the stale dead run's ref is removed" '! has_ref "agent-x-$stale_dead"'
check "the stale dead run's log is kept" '[[ -e $RUNS/agent-x/titan-platform-$stale_dead.log ]]'
check "a fresh tree of a dead run is kept" '[[ -d $RUNS/agent-x/titan-platform-$fresh_dead ]] && listed "$RUNS/agent-x/titan-platform-$fresh_dead"'
check "a fresh tree's ref is kept" 'has_ref "agent-x-$fresh_dead"'
check "a stale tree of a live run is kept" '[[ -d $RUNS/agent-x/titan-platform-$stale_live ]] && listed "$RUNS/agent-x/titan-platform-$stale_live"'
check "a live run's ref is kept" 'has_ref "agent-x-$stale_live"'
check "a dead run's ref with no tree is removed" '! has_ref "agent-x-$orphan_ref"'
check "a live run's ref before its tree exists is kept" 'has_ref "other-$fetching_ref"'
check "a dead run's tmp dir is removed" '[[ ! -e $TMP/legacy/$tmp_dead ]]'
check "a live run's tmp dir is kept" '[[ -d $TMP/legacy/bs-$$ ]]'
check "the run cleans up its own ref" '[[ -z $(g "$SRC" for-each-ref refs/suite-runs/fake-) ]]'

exit $FAILS
