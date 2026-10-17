#!/bin/zsh
# S1a preserves every managed file, symlink and script on Linux.
# Run: zsh tests/test_machine_profiles.sh
ROOT="${0:A:h:h}"
FAILS=0
TMP=$(cd "$(mktemp -d)" && pwd -P)
# Leave throwaway state in /tmp; no live config, age key or apply is needed.
check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi
}
write_config() {
    cat > "$TMP/$1.toml" <<CONF
[data]
    name = "test"
    email = "test@example.com"
    machine = "$1"
    awDataDir = "/fixture/active-work"
    macHost = "test-mac.example"
CONF
    mkdir -p "$TMP/$1"
}
cz() {
    local machine=$1; shift
    chezmoi --source "$ROOT" --config "$TMP/$machine.toml" --destination "$TMP/$machine" \
        --cache "$TMP/cache-$machine" --persistent-state "$TMP/state-$machine.boltdb" "$@"
}
for machine in server personal work; do
    write_config "$machine"
    check "$machine managed targets match Linux golden byte for byte" \
        'cz "$machine" managed --include files,symlinks,scripts > "$TMP/$machine.txt" && cmp "$ROOT/tests/fixtures/managed-$machine.linux.txt" "$TMP/$machine.txt"'
    check "$machine settings render valid JSON" \
        'cz "$machine" execute-template < "$ROOT/private_dot_claude/settings.json.tmpl" > "$TMP/$machine-settings.json" && jq -e . "$TMP/$machine-settings.json" > /dev/null'
    check "$machine kwin installer renders valid shell" \
        'cz "$machine" execute-template < "$ROOT/run_onchange_after_install-kwin-mcp.sh.tmpl" > "$TMP/$machine-kwin.sh" && bash -n "$TMP/$machine-kwin.sh"'
done
# Optional local role additions are de-duplicated; removals win over additions.
cat >> "$TMP/personal.toml" <<'CONF'
    extraRoles = ["factory-host", "fleet", "factory-client"]
    withoutRoles = ["factory-client"]
CONF
printf '%s' '["base","owner-personal","fleet","claude-multi-account","backup-source","private-overlay","factory-host"]' > "$TMP/expected-roles.json"
check "role overrides append, de-duplicate and remove in order" \
    'cz personal execute-template < "$ROOT/.chezmoitemplates/roles" > "$TMP/roles.json" && cmp "$TMP/expected-roles.json" "$TMP/roles.json"'
write_config unknown
check "unknown machine fails with a profile error" \
    '! cz unknown managed --include files,symlinks,scripts > "$TMP/unknown.txt" 2> "$TMP/unknown.err" && grep -q "unknown machine" "$TMP/unknown.err"'

# Platform-only paths are base in S1a. All remaining conditional ignore paths
# must belong to exactly one role block; duplicates and unowned paths fail.
if python3 - "$ROOT/.chezmoiignore" <<'PY'
import re
import sys
from collections import Counter

stack = []
expected = set("""
.local/share/kwin-mcp
.claude/scripts/kwin-session-start-guard.py
install-kwin-mcp.sh
.local/bin/tmp-inode-alarm
.config/systemd/user/tmp-inode-alarm.service
.config/systemd/user/tmp-inode-alarm.timer
.config/systemd/user/titan-console.service.d
.local/bin/basement-health
.config/systemd/user/basement-health.service
.config/systemd/user/basement-health.timer
.local/bin/env-drift-check
.config/systemd/user/env-drift-check.service
.config/systemd/user/env-drift-check.timer
.local/bin/titan-console-login-link
.config/systemd/user/titan-factory-digest.service
.config/systemd/user/titan-factory-digest.timer
.config/systemd/user/active-work.service.d
.config/systemd/user/agent-chat-burndown.service.d
.config/systemd/user/agent-chat-seat-watchdog-pilot.service.d
.config/systemd/user/agent-chat-seat-watchdog.service.d
.config/systemd/user/session-miner-refresh.service.d
.config/restic
.local/bin/restic-nightly
.local/bin/restic-check
.local/bin/restic-stamp-mac
.config/systemd/user/restic-nightly.service
.config/systemd/user/restic-nightly.timer
.config/systemd/user/restic-check.service
.config/systemd/user/restic-check.timer
.config/systemd/user/restic-stamp-mac.service
.config/systemd/user/restic-stamp-mac.timer
.config/mise
""".split())
paths = Counter()
roles = Counter()
errors = []
for number, raw in enumerate(open(sys.argv[1]), 1):
    line = raw.strip()
    if line.startswith('{{ if '):
        role = re.fullmatch(r'{{ if not \(has "([\w-]+)" \$roles\) }}', line)
        if not role and not re.fullmatch(r'{{ if (?:eq|ne) \.chezmoi\.os "(?:linux|darwin)" }}', line):
            errors.append(f'line {number}: unsupported conditional: {line}')
        stack.append(role[1] if role else None)
        if role:
            roles[role[1]] += 1
    elif line == '{{ end }}':
        stack.pop()
    elif line and not line.startswith(('#', '{{')):
        owners = [role for role in stack if role]
        # OS-only blocks deliberately retain base platform gates in this slice.
        if not owners and line not in expected:
            continue
        if len(owners) != 1:
            errors.append(f'line {number}: expected exactly one role owner: {line}')
        paths[line] += 1
for path in expected - paths.keys():
    errors.append(f'{path}: missing role owner')
for path, count in paths.items():
    if count != 1:
        errors.append(f'{path}: appears {count} times in role blocks')
for role, count in roles.items():
    if count != 1:
        errors.append(f'{role}: expected one block, found {count}')
if not roles:
    errors.append('no role blocks found')
if re.search(r'\.machine\b', open(sys.argv[1]).read()):
    errors.append('machine conditional remains in ignore file')
for error in errors:
    print('FAIL', error)
sys.exit(bool(errors))
PY
then
    echo "ok   non-base ignore paths have exactly one role block"
else
    echo "FAIL non-base ignore paths have exactly one role block"
    FAILS=$((FAILS + 1))
fi
exit $((FAILS > 0))
