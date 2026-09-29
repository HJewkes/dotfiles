---
name: repo-rulesets
description: |
  Use when creating a new GitHub repo, when a repo's CI job names change, when auditing branch protection across the owner's repos, or when someone proposes pushing straight to main/master, adding an admin bypass, or requiring the owner's approval on their own PRs. Triggers: "branch protection", "ruleset", "protect main", "no direct push", "required checks", "required status checks", "bypass", "classic protection", "why can't I push to main", "new repo setup".
---

# repo-rulesets: the owner's GitHub branch policy

## The policy (owner-approved 2026-09-28)

1. Changes land only through PRs, and a PR merges once CI is green. The owner's approval is not needed.
2. Nobody pushes directly to the default branch, the owner included. Agents use the owner's credentials, so an owner bypass is an agent bypass.
3. A third party with write access cannot merge their own PR without the owner's approval.

## How it is built

Two rulesets on `~DEFAULT_BRANCH`. Bodies live in `templates/`, copied from the live reference, HJewkes/agent-chat rulesets 24135880 and 24135883.

| Ruleset | Rules | Bypass |
|---|---|---|
| `no-direct-push` | deletion, non_fast_forward, pull_request (0 approvals), required_status_checks (the repo's real CI job names) | none |
| `outside-approval` | pull_request: 1 approval, dismiss_stale_reviews_on_push, require_last_push_approval | Repository admin (actor_id 5), `bypass_mode: pull_request` |

Why each piece exists:

- **No bypass on `no-direct-push`** enforces rule 2. Any bypass here would let an agent push to main.
- **pull_request with 0 approvals** forces every change through a PR without waiting on the owner (rules 1 and 2).
- **required_status_checks** is the "CI is green" half of rule 1. The names must be checks that run on every PR. A name that never reports on a PR blocks every merge.
- **deletion and non_fast_forward** stop anyone deleting or rewriting the default branch.
- **`outside-approval`** enforces rule 3. `last_push_approval` and dismissing stale reviews stop a third party from pushing new code after the owner approves.
- **The admin `pull_request` bypass** lets the owner merge their own PRs without an approval, which nobody could give them. `pull_request` mode covers PR merges only, never a direct push.

Rulesets aggregate. A rule applies if any active ruleset requires it. A bypass exempts only from the ruleset that grants it. Overrides therefore need care about where they go. Example: `require_code_owner_review` on `no-direct-push` would block every owner PR, so voltras-mcp carries it on `outside-approval`.

## Private repos

Private repos on the free plan cannot have rulesets or classic protection. The API answers 403 "Upgrade to GitHub Pro or make this repository public". The script reports them as uncoverable and skips them.

## When to run

- **Every new repo**, after its first PR has merged with CI. Discovery needs a merged PR to see which checks run on PRs.
- **Any time CI job names change**: renamed jobs, new matrix entries, or workflows that were split or merged. Stale names block merges; missing names let red PRs through.
- **Periodically**, with `audit --all`, to catch drift and legacy protection.

## The script

```
scripts/repo-rulesets audit <owner/repo>|--all [--commits N]
scripts/repo-rulesets apply <owner/repo>|--all [--yes]
```

`apply` without `--yes` prints the method, endpoint and JSON diff for each ruleset, and changes nothing. `apply --yes` creates a ruleset (POST) or updates the one with the same name (PUT to its id), so reruns are safe. With `--yes` it skips held repos, private repos, and repos whose checks it cannot discover. It never deletes anything.

The owner runs `apply --yes` from their own session. Agents run `audit` and dry-run `apply` only.

Required checks are the check-run names on the default-branch HEAD that also ran, and were not skipped, on each of the 3 most recent merged PRs. That drops push-only jobs such as deploy and release, and path-filtered jobs. When no merged PR exists, or nothing overlaps, the repo is flagged "not discoverable". Pin the names in an override after reading the workflow triggers.

`audit` also reports:

- **Legacy protection**: any other active ruleset on the default branch, and classic branch protection, with what each enforces. Remove it by hand once the standard pair is live. The script never deletes it.
- **Direct pushes**: how many of the last N default-branch commits have no merged PR, by author.
- **Workflows with a push step**, such as release bots that commit version bumps to main. `no-direct-push` has no bypass, so these break and must move to a PR-based release.

- **Bot-token warning**: a workflow that pushes a branch or opens a PR with `secrets.GITHUB_TOKEN` and no App token. It is a warning only. It also prints in dry-run `apply` and never blocks. See the gotcha below.

Only `gh api` REST calls are used. GraphQL is rate-limited on this account. Filtering happens with `--jq` inside gh.

## Overrides

`overrides.json` is keyed by `owner/repo`. Every entry says why it exists.

| Key | Effect |
|---|---|
| `hold` | Audit and dry-run still report. `apply --yes` skips the repo. |
| `required_checks` | Replaces discovery with this list. |
| `rule_parameters.<ruleset>.<rule type>` | Merged into that rule's parameters. |
| `reason` | Free text shown in the audit. |

Remove a `hold` once the blocking decision lands.

## Gotcha: PRs opened by github-actions[bot] never get CI (TP-447)

Found 2026-09-28 in titan-platform. `release.yml` runs `changesets/action` with `GITHUB_TOKEN`, so github-actions[bot] pushes the `changeset-release/main` branch. GitHub holds CI runs triggered by that bot in `action_required`, and they never report. `no-direct-push` requires checks and has no bypass, so the Version Packages PR cannot merge. PR #173's head e0e97fd had zero check runs.

Spot it: `audit` prints `WARNING .github/workflows/<file>` for any workflow with a branch-push or PR step (`changesets/action`, `create-pull-request`, `gh pr create`, `git push`) that uses `secrets.GITHUB_TOKEN` and no `create-github-app-token` step. Confirm on the PR head: `gh api repos/O/R/commits/<sha>/check-runs --jq .total_count` returns 0.

Manual approval, only with the owner's word each time. List the held runs with `gh api "repos/O/R/actions/runs?status=action_required" --jq '.workflow_runs[] | {id, name, head_sha}'`. Then approve each: `gh api -X POST repos/O/R/actions/runs/<id>/approve`. The owner chose this for now.

Durable fix: mint a GitHub App installation token with `actions/create-github-app-token` and pass it to `changesets/action` (and its checkout) as `GITHUB_TOKEN`. Pushes by an App trigger CI normally. The script warns until the workflow stops using `GITHUB_TOKEN` for that push.
