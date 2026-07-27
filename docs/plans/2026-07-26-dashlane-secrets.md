# Dashlane as a Secrets Backend for chezmoi

**Status:** researched, not scheduled. Nothing in this document has been implemented.

## Problem

Secrets live in a single age-encrypted blob, `encrypted_private_dot_secrets.zsh.age`,
which deploys to `~/.secrets.zsh` and is sourced from `dot_zshrc:11`. That works, but
it has three weaknesses:

1. **All-or-nothing.** The file decrypts as a unit. There is no way to grant, rotate,
   or audit one value.
2. **Rotation is manual.** Changing a token means decrypting, editing, re-encrypting,
   and committing.
3. **The age identity is a single point of failure.** `~/.config/chezmoi/key.txt`
   exists only on the local disk. It is deliberately gitignored from the private
   overlay, because a repo compromise would otherwise expose every secret. Lose the
   disk without an out-of-band copy and the encrypted blob is unrecoverable forever.

Dashlane is already the password manager in use, and it has recovery built in — which
is precisely the property `key.txt` lacks.

## Current state

| Thing | State |
| --- | --- |
| chezmoi | v2.69.4, Homebrew |
| `dashlanePassword` / `dashlaneNote` template functions | present in this chezmoi build |
| `dcli` | installed at `/opt/homebrew/bin/dcli` |
| `dcli` in `Brewfile` | **no** — a new machine would not get it |
| `dcli` login on this machine | **no** — no keychain item; prompts for email |
| Secrets in `~/.secrets.zsh` | `NPM_TOKEN`, `NPM_TOKEN_VOLTRAS`, `NPM_TOKEN_TITAN_DESIGN`, `BRIGHTDATA_API_TOKEN` |

The template functions were confirmed present by probing them: they fail at `dcli`'s
prompt rather than with "function not defined".

## What dcli supports

Relevant subcommands: `sync`, `read <path>`, `password`, `note`, `secret`, `accounts`,
`configure`.

### Interactive-once, then silent

```bash
dcli configure save-master-password true      # default; encrypted master password to OS keychain
dcli configure user-presence --method none    # drop the biometric gate on each read
```

After one login, `dcli read` and `dcli password` resolve from the local vault with no
prompt. This is enough for `chezmoi apply` on a personal machine.

### Fully headless

Two environment variables exist in the shipped source but are **not** in the published
docs:

| Variable | Source |
| --- | --- |
| `DASHLANE_MASTER_PASSWORD` | `src/modules/crypto/keychainManager.ts` |
| `DASHLANE_SERVICE_DEVICE_KEYS` | `src/utils/deviceCredentials.ts` |

`DASHLANE_SERVICE_DEVICE_KEYS` is the service-account path: device credentials supplied
directly, no keychain and no interactive registration. Treat both as verified-in-source
but unsupported — Dashlane has published no stability promise for them.

## Design: hybrid, not migration

Keep both backends and split by whether a secret is needed *before* a Dashlane session
can exist.

**Stays in age** — anything required to bootstrap a machine to the point where `dcli`
can log in. Today that is nothing beyond the age key itself, but the tier must exist so
provisioning never depends on an unlocked vault.

**Moves to Dashlane** — everything downstream of a working login. The four tokens above
qualify: none are needed before a shell can reach the network.

The alternative, migrating everything, creates a circular dependency. Headless
provisioning needs `DASHLANE_MASTER_PASSWORD`, which has to come from somewhere; if it
comes from the vault, the machine cannot bootstrap.

### Shape

`dot_secrets.zsh.tmpl` replaces the encrypted blob for migrated values:

```
export NPM_TOKEN={{ dashlanePassword "npm-token" }}
```

Values resolve at render time, so `chezmoi apply` gains a dependency on `dcli` being
installed and logged in.

## Work items

Not scheduled. Rough order:

1. Add `dcli` to `Brewfile` — needed regardless of whether the rest happens, since the
   binary is currently installed but untracked.
2. Log in on this machine, then set `save-master-password true` and
   `user-presence --method none`. Confirm `dcli read` is prompt-free.
3. Prototype exactly one secret (`BRIGHTDATA_API_TOKEN` — lowest blast radius, already
   proven non-load-bearing) through `dashlanePassword` and compare ergonomics.
4. Decide on naming convention for vault entries before migrating more than one.
5. Migrate the three `NPM_TOKEN*` values if step 3 holds up.
6. Keep `encrypted_private_dot_secrets.zsh.age` for the bootstrap tier. Do not delete
   it even when empty of migrated values.

## Risks

- **Render-time coupling.** Every `chezmoi apply` shells out to `dcli` per secret.
  Slower, and a broken or logged-out `dcli` turns a working apply into a failed one.
  The current age setup has no such runtime dependency.
- **Undocumented env vars.** The headless path rests on two variables Dashlane has not
  documented. They can disappear in any release.
- **Offline.** `dcli` reads a locally synced vault, so reads should work offline after a
  sync, but this is untested here.
- **Does not fix the age key.** Migrating secrets to Dashlane does not back up
  `key.txt`. That remains an independent action item, and stays necessary as long as the
  bootstrap tier exists.

## Verification

Before migrating anything beyond the prototype:

- `dcli read` returns a value with no prompt in a non-interactive shell.
- `chezmoi apply` on a clean checkout renders the migrated secret correctly.
- `chezmoi apply` with `dcli` logged out fails loudly rather than writing an empty
  value into `~/.secrets.zsh` — an empty token is worse than a hard error.
