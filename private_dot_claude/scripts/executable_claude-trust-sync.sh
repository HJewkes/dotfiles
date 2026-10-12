#!/usr/bin/env bash
# Keep workspace-trust decisions in sync across Claude profiles.
#
# Trust lives in `.claude.json` inside each config directory, so a folder you
# trust under one profile still prompts under the others. This unions the
# trusted paths across the default profile and every profile directory, so a
# folder trusted anywhere is trusted everywhere. Folders in
# ~/.claude/trusted-folders.txt join the union too, so a new folder is trusted
# before any profile has opened it. Private paths go in trusted-folders.local.txt,
# which comes from the private overlay because this repo is public.
#
# Only the `hasTrustDialogAccepted` flag moves. Session history, costs and MCP
# state stay per-profile, which is the point of having profiles at all.
#
# Exit codes: 0 no change or synced, 1 failure, 2 synced with warnings.
set -uo pipefail

PROFILE_ROOT="${CLAUDE_PROFILE_ROOT:-$HOME/.claude-profiles}"
# The default profile keeps .claude.json beside ~/.claude, not inside it.
# Only a CLAUDE_CONFIG_DIR profile nests the file within its own directory.
DEFAULT_CONFIG="$HOME/.claude.json"
TRUSTED_LISTS="${CLAUDE_TRUSTED_FOLDERS:-$HOME/.claude/trusted-folders.txt:$HOME/.claude/trusted-folders.local.txt}"
DRY_RUN=0

usage() {
    cat <<'USAGE'
usage: claude-trust-sync.sh [--dry-run] [--help]

Unions workspace-trust decisions across the default Claude config directory and
every profile under ~/.claude-profiles (override with CLAUDE_PROFILE_ROOT),
plus every folder listed in ~/.claude/trusted-folders.txt and
~/.claude/trusted-folders.local.txt (override with CLAUDE_TRUSTED_FOLDERS, a
colon-separated list of files): one path per line, ~ for home, # for comments.

  --dry-run   Report what would change without writing.
  --help      Show this message.

Backs up each modified .claude.json alongside itself before writing. Run it when
a profile starts prompting for folders you have already trusted elsewhere.

Not safe to run while a session is live in one of the affected profiles: Claude
Code rewrites .claude.json on exit and would overwrite the merge.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

DRY_RUN="$DRY_RUN" DEFAULT_CONFIG="$DEFAULT_CONFIG" PROFILE_ROOT="$PROFILE_ROOT" \
    TRUSTED_LISTS="$TRUSTED_LISTS" python3 <<'PY'
import glob, json, os, sys, tempfile, time

dry = os.environ['DRY_RUN'] == '1'
configs = [os.environ['DEFAULT_CONFIG']]
configs += sorted(glob.glob(os.path.join(os.environ['PROFILE_ROOT'], '*', '.claude.json')))

loaded, warnings = [], 0
for path in configs:
    if not os.path.exists(path):
        continue
    try:
        loaded.append((path, json.load(open(path))))
    except (OSError, ValueError) as err:
        print(f'skipping unreadable {path}: {err}', file=sys.stderr)
        warnings += 1

if not loaded:
    print('nothing to sync: no readable configs')
    sys.exit(2 if warnings else 0)

def listed_folders(path):
    if not os.path.exists(path):
        return set()
    lines = (line.strip() for line in open(path))
    return {os.path.expanduser(line) for line in lines if line and not line.startswith('#')}

union = set()
for list_path in os.environ['TRUSTED_LISTS'].split(':'):
    union |= listed_folders(list_path)
for _, data in loaded:
    for p, v in (data.get('projects') or {}).items():
        if isinstance(v, dict) and v.get('hasTrustDialogAccepted'):
            union.add(p)

stamp = time.strftime('%Y%m%d-%H%M%S')
changed = 0
for path, data in loaded:
    projects = data.setdefault('projects', {})
    missing = [p for p in union
               if not (isinstance(projects.get(p), dict)
                       and projects[p].get('hasTrustDialogAccepted'))]
    label = 'default' if path == os.environ['DEFAULT_CONFIG'] \
        else os.path.basename(os.path.dirname(path))
    if not missing:
        print(f'{label:<12} up to date ({len(union)} trusted)')
        continue
    changed += 1
    print(f'{label:<12} {"would add" if dry else "adding"} {len(missing)}')
    if dry:
        continue
    for p in missing:
        projects.setdefault(p, {})['hasTrustDialogAccepted'] = True
    try:
        with open(path) as fh:
            open(f'{path}.bak-{stamp}', 'w').write(fh.read())
        tmp = tempfile.NamedTemporaryFile('w', dir=os.path.dirname(path),
                                          delete=False, suffix='.tmp')
        json.dump(data, tmp, indent=2)
        tmp.close()
        os.replace(tmp.name, path)
    except OSError as err:
        print(f'failed to write {path}: {err}', file=sys.stderr)
        warnings += 1

print(f'{len(union)} trusted paths across {len(loaded)} configs'
      + ('' if changed else '; nothing to do'))
sys.exit(2 if warnings else 0)
PY
