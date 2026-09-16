# Claude account separation

Research notes from 2026-09-14 on whether to run separate Anthropic accounts per
project (workout app, agentic tooling, personal document organization), and how
to isolate Claude Code state per project regardless of account count.

## Verdict

Multiple accounts are permitted. Nothing in the published terms caps accounts per
person. For isolation of concerns alone, per-project `CLAUDE_CONFIG_DIR` profiles
on one account give you most of the benefit without a second subscription.

## Decision, 2026-09-14 — implemented and verified 2026-09-15

Three profiles via `claude-profile`, defined in `dot_zsh/claude.zsh`. Two of them
have their own Claude account. Verified with `claude auth status` per profile:

| Profile | Account | Plan |
| --- | --- | --- |
| `agents` | `agentic@henryjewkes.com` | max |
| `workout` | `coach@henryjewkes.com` | max |
| `personal` | `hjewkes@gmail.com` | max |
| *(default `~/.claude`)* | `hjewkes@gmail.com` | max |

The two new addresses come from Cloudflare Email Routing on `henryjewkes.com`.
See `henryjewkes-com-cloudflare-migration.md`.

### Baseline profile for new shells (short-term, 2026-09-15)

`dot_zsh/claude.zsh` exports `CLAUDE_CONFIG_DIR` for the `agents` profile in
every new shell, because the default account hit 100% of its weekly limit
(resets Sat 19 Sep 18:00 MDT) while `agents` sat at 1%.

Precedence, highest first:

1. A `CLAUDE_CONFIG_DIR` already in the environment — `aw` and agent-chat set
   this for an initiative's declared `profile`, and it survives the shell they
   launch into.
2. `CLAUDE_DEFAULT_PROFILE`, defaulting to `agents`.
3. `~/.claude`, when `CLAUDE_DEFAULT_PROFILE` is `default` or empty.

So an initiative that declares a profile still gets it, and one that declares
none now runs on `agents` rather than the default account.

To revert, set `CLAUDE_DEFAULT_PROFILE=default` for one shell, or change the
default in `dot_zsh/claude.zsh` to make it permanent.

### Binding gotcha: the browser session wins, not `--email`

`claude auth login --claudeai --email <address>` only *prefills* the login form.
The OAuth callback authenticates whichever account is signed in at claude.ai in
the default browser. Binding `personal` while signed in as `coach@` bound coach,
not the intended account, and it had to be redone.

Check the account name in the claude.ai sidebar before approving each login.

Also: always carry the config dir inline.

```bash
CLAUDE_CONFIG_DIR=$HOME/.claude-profiles/<profile> claude auth login --claudeai --email <address>
```

A bare `claude auth login` writes to `~/.claude` and would replace the default
Max session.

Watch anthropics/claude-code#94195, where subscription metadata can go stale when
switching accounts. It did not occur here; all four profiles reported `max`
correctly on first check.

## What the terms actually say

Checked: Consumer Terms, Usage Policy, Max plan article, account management FAQs,
Claude Code Pro/Max article. There is no "one account per person" clause.

The prohibitions that do exist are narrow:

- Consumer Terms: "You may not share your Account login information, Anthropic API
  key, or Account credentials with anyone else." Also "You also may not make your
  Account available to anyone else."
- Consumer Terms: "If you use an email address owned by your employer or another
  organization, your Account may be linked to the organization's Anthropic
  enterprise account."
- Usage Policy: circumventing a ban via a different account; "Utilize automation in
  account creation or to engage in spammy behavior"; "Coordinate malicious activity
  across multiple accounts to avoid detection or circumvent product guardrails."

Every one concerns other people using your account, ban evasion, or malicious
coordination. Two accounts both paid for and used by one person touch none of them.

Anthropic documents two multi-account setups as normal: a Claude account plus a
Console account on the same email, and a personal account alongside a Team org you
switch between in the sidebar.

## Anthropic's on-record position

After the February 2026 ban wave, Thariq Shihipar of the Claude Code team said on X:

> We haven't changed anything here. It's not against terms of service to have
> multiple MAX accounts.

He attributed the confusion to "a docs clean up we rolled out that's caused some
confusion." Enforcement targets token reselling and businesses running on
consumer-tier subscriptions instead of API keys.

## What actually gets enforced

The line is not account count. It is whether consumer-tier billing is subsidizing a
workload that should be metered.

The February 2026 ban wave targeted third-party harnesses (OpenClaw, OpenCode)
extracting subscription OAuth tokens and replaying them against the API with spoofed
Claude Code client headers, to run always-on agent swarms on a flat $200/month.
Anthropic responded with token binding: subscription credentials now only work with
verified Claude Code clients, producing "This credential is only authorized for use
with Claude Code and cannot be used for other API requests."

TechCrunch, July 2025, quoting Anthropic on why rate limits arrived: users running
Claude Code "continuously in the background, 24/7" and "a handful of users who are
violating Claude's usage policy by sharing accounts and reselling access."

Residual risk is that detection is heuristic. February caught legitimate paying
users in a net built for resellers.

### This machine's profile is clean

`agent-chat` launches the official CLI (`src/agents/launch-plan.ts:196` sets
`bin: 'claude'`), not a third-party harness. Subagents run in visible iTerm panes,
occasional overnight work, one timer-triggered agent for the fantasy-football
project. None of that resembles the enforcement target.

## The "20 accounts" story

Does not hold up as stated. Two real stories get conflated:

1. Developers run 20-30 parallel Claude Code agents on a *single* Max 20x
   subscription. One account, many processes. Ordinary supported use.
2. The February 2026 ban wave, which was about token extraction into third-party
   harnesses, not about subscription count.

## Getting more usage, legitimately

Usage credits let Pro, Max 5x, and Max 20x accounts continue past the session limit
at standard API rates, billed separately, with a monthly cap you set. Credits cover
Claude Code terminal usage. Enable via Settings > Usage.

Economics: a second Max 20x is $200/month flat. Credits are pay-per-token. Bursty
overflow favors credits; sustained saturation of two accounts favors two
subscriptions.

## Email constraints on a second account

- One email address gets one Claude account. The only documented same-email pairing
  is Claude account plus Console account, which are separate systems.
- Gmail plus-addressing does not work. Verified 2026-09-14: `hjewkes+x@gmail.com`
  resolves to the existing account at login.
- An account's email address cannot be changed after creation. Pick something durable.
- Do not use an employer-owned domain; the account may be absorbed into that
  organization's enterprise account.

Options for a distinct address that still reaches the primary inbox, best first:

1. Cloudflare Email Routing on an owned domain. Free, unlimited aliases, forwards to
   Gmail, looks like a normal address. Requires a registered domain (a `workers.dev`
   subdomain will not do).
2. A second Gmail account with forwarding enabled to the primary, plus "Send mail as"
   configured on the primary.
3. Apple Hide My Email (iCloud+). Works, but opaque addresses are harder to manage
   and some services treat them as disposable.

## Config isolation without a second account

Verified 2026-09-14: `CLAUDE_CONFIG_DIR` isolates authentication, not just settings.

```
$ claude auth status
{ "loggedIn": true,  "email": "hjewkes@gmail.com", "subscriptionType": "max", ... }

$ CLAUDE_CONFIG_DIR=/tmp/cfgtest claude auth status
{ "loggedIn": false, "authMethod": "none", ... }
```

So a profile directory is independently authenticated. One profile per account is
possible, and so is one profile per project on a single account for context hygiene.

The default `~/.claude` is 1.7G, so a profile should share tooling (skills, plugins,
commands, output styles, settings) and isolate only session state (projects,
history, todos, credentials).

Claude Code also supports explicit account switching on one config dir:
`claude auth login --claudeai --email <address>`. Note anthropics/claude-code#94195,
a confirmed bug where subscription metadata goes stale when switching between
accounts, requiring explicit re-authentication.

## Sources

- https://www.anthropic.com/legal/consumer-terms
- https://www.anthropic.com/legal/aup
- https://support.claude.com/en/articles/8987223-can-i-have-a-claude-account-and-a-console-account
- https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans
- https://support.claude.com/en/articles/12109679-creating-a-new-account-after-deletion
- https://support.claude.com/en/articles/8452276-how-do-i-change-the-email-address-associated-with-my-account
- https://techcrunch.com/2025/07/28/anthropic-unveils-new-rate-limits-to-curb-claude-code-power-users/
- https://piunikaweb.com/2026/02/19/anthropic-claude-max-ban-agent-sdk-clarification/
- https://augmentedmind.substack.com/p/the-end-of-the-claude-subscription-hack
- https://github.com/anthropics/claude-code/issues/94195
