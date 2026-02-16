---
name: dependabot-pr-review
description: Triage, review, fix, and merge Dependabot PRs using the gh CLI. Use when the user asks to review dependabot PRs, handle dependency updates, merge bot PRs, or manage automated dependency pull requests.
---

# Dependabot PR Review & Merge

Automate the triage, review, and merging of Dependabot PRs for any GitHub repo using the `gh` CLI.

## Prerequisites

- `gh` CLI authenticated with `repo` scope (`gh auth status`)
- Repository cloned locally and set as working directory

## Phase 1: Triage

Fetch all open Dependabot PRs with CI status in one call:

```bash
gh pr list --state open --json number,title,mergeable,mergeStateStatus,statusCheckRollup,headRefName,labels,createdAt \
  --jq '.[] | select(.title | test("dependabot|bump|chore\\(deps\\)|chore\\(ci\\)"))'
```

For each PR, extract check results:

```bash
gh pr checks <N>
```

### Classify each PR

| Category | Criteria | Action |
|----------|----------|--------|
| Ready to merge | All checks pass, MERGEABLE, CLEAN or BLOCKED (needs approval only) | Approve and merge |
| Needs rebase | CONFLICTING / DIRTY, or stale CI from old base branch | `@dependabot rebase` |
| Failing CI | Check failures unrelated to the dependency change (e.g. pre-existing issues) | Rebase first, then reassess |
| Needs code fix | Build/type/lint errors introduced by the dependency bump itself | Checkout branch, fix, push |

### Diagnosing failures

Get the failed CI run logs:

```bash
gh run view <run-id> --log-failed
```

Filter for actionable errors:

```bash
gh run view <run-id> --log-failed 2>/dev/null | grep -E '(error|Error|FAIL|✖)' | head -30
```

### Present summary

Show the user a table:

```
| PR  | Title                          | Status       | Action needed         |
|-----|--------------------------------|--------------|-----------------------|
| #N  | bump X from A to B             | All green    | Ready to merge        |
| #N  | bump Y from A to B             | Stale CI     | Needs rebase          |
| #N  | bump Z from A to B             | Build fail   | Needs code fix at ... |
```

Ask the user for their preferred **merge strategy** (squash, merge commit, or rebase) before proceeding.

## Phase 2: Merge green PRs

Merge sequentially to avoid conflicts. After each merge, GitHub recalculates mergeability for remaining PRs.

```bash
gh pr review <N> --approve --body "LGTM - <brief reason>"
gh pr merge <N> --rebase --delete-branch   # or --squash / --merge per user pref
```

**Merge order** (lowest risk first):
1. CI/GitHub Actions bumps (`.github/workflows/` only)
2. Dev dependencies (lint, test, build tooling)
3. Runtime/production dependencies
4. Major version bumps (last, highest risk)

After each merge, check the next PR:

```bash
gh pr view <N> --json mergeable,mergeStateStatus --jq '"\(.mergeable) \(.mergeStateStatus)"'
```

If CONFLICTING or DIRTY, trigger a rebase:

```bash
gh pr comment <N> --body "@dependabot rebase"
```

Then wait for CI to re-run:

```bash
# Poll every 15s, or use --watch if available
gh pr checks <N> --watch
```

## Phase 3: Rebase stale PRs

For PRs with outdated CI (failures from old base branch, not from the dependency change):

```bash
gh pr comment <N> --body "@dependabot rebase"
```

Dependabot typically rebases within 30-60 seconds. Poll:

```bash
sleep 30
gh pr view <N> --json mergeable --jq '.mergeable'
gh pr checks <N>
```

Once all checks pass, approve and merge as in Phase 2.

## Phase 4: Fix PRs with code-level failures

When a dependency bump introduces build/type/lint errors:

1. **Checkout the branch:**
   ```bash
   git fetch origin <branch-name>
   git checkout <branch-name>
   ```

2. **Install and reproduce locally:**
   ```bash
   npm ci && npm run build
   ```

3. **Fix the issue** based on CI error output.

4. **Run the full CI suite locally:**
   ```bash
   npm run build && npm run lint && npm test
   ```

5. **Commit and push:**
   ```bash
   git add <files>
   git commit -m "fix: <description of fix>"
   git push origin <branch-name>
   ```
   If the remote was force-updated by dependabot while you worked:
   ```bash
   git pull --rebase origin <branch-name>
   git push origin <branch-name>
   ```

6. **Wait for CI, then merge:**
   ```bash
   gh pr checks <N> --watch
   gh pr review <N> --approve && gh pr merge <N> --rebase --delete-branch
   ```

## Phase 5: Sync local repo

After all PRs are merged:

```bash
git checkout <default-branch>
git pull origin <default-branch>
```

Verify no open dependabot PRs remain:

```bash
gh pr list --state open
```

## Common failure patterns

| Error pattern | Likely cause | Fix |
|---------------|-------------|-----|
| `TS2345` / type incompatibility | TypeScript major/minor bump with stricter checks | Add type assertions or narrow types |
| `security-audit` fail | Transitive dep vulnerability (e.g. `tar`) | Often fixed by bumping the parent dep; check if another PR resolves it |
| `node-matrix (N)` fail | Node version dropped from support | Update CI matrix to remove unsupported version |
| Lint warnings treated as errors | `--max-warnings=0` or `eslint` with `warningsAsErrors` | Fix warnings or update eslint config |
| `format:check` fail | Prettier formatting not applied after code changes | Run `npx prettier --write <file>` |
