# dotfiles

Managed by [chezmoi](https://chezmoi.io/).

## Setup on a new machine

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply HJewkes
```

Prompts for git name, email, and machine type (personal/work/server).

## New Linux server

The `server` machine type targets an Ubuntu host whose base toolchain (node,
gh, git, tmux, Claude Code, chezmoi, uv) is already installed by the server's
own bootstrap. Homebrew is not used on Linux; the package script installs only
`zsh`, `starship` and `jq` with apt, so `chezmoi apply` asks for the sudo
password once.

Steps, run by the owner:

1. Copy the age key from the Mac, so chezmoi can decrypt `~/.secrets.zsh`
   (chezmoi uses its builtin age when the `age` binary is absent):

   ```bash
   ssh <server> 'mkdir -p ~/.config/chezmoi && chmod 700 ~/.config/chezmoi'
   scp ~/.config/chezmoi/key.txt <server>:.config/chezmoi/key.txt
   ssh <server> 'chmod 600 ~/.config/chezmoi/key.txt'
   ```

2. Copy the git-safety hook, which `settings.json` runs before every Bash call
   but which is not managed here:

   ```bash
   rsync -a --exclude git-safety.log ~/.claude/hooks/git-safety <server>:.claude/hooks/
   ```

3. On the server:

   ```bash
   chezmoi init --apply HJewkes/dotfiles
   ```

   Answer `server` at the machine type prompt.

4. Make zsh the login shell. The Claude status line runs under zsh either way.

   ```bash
   chsh -s /usr/bin/zsh
   ```

5. Review `~/.claude/settings.json`. On Linux the sandbox `allowAppleEvents`
   flag and the osascript `Notification` hook are dropped. The `server` type
   appends a host line, rendered from `.chezmoitemplates/claude-settings-server.json`,
   to `autoMode.environment`. Permissions and `autoMode.allow` match the Mac.
   A private settings patch copied into `~/.config/chezmoi/` is merged as on the
   Mac, and the macOS-only keys are still dropped afterwards.

6. KDE computer use for agents (kwin-mcp). Apply installs it with the Ubuntu
   packages it needs, into `~/.local/share/kwin-mcp/venv` from the hash-pinned
   `requirements.txt` there, then registers the `kwin` MCP server at user scope
   in every Claude config dir that uses `~/.claude/settings.json`. The server
   runs in a transient systemd user unit with a scrubbed environment, so its
   virtual KWin sessions die with it. The server settings deny
   `mcp__kwin__dbus_call`, `mcp__kwin__launch_app` and
   `mcp__kwin__clipboard_get`, and a PreToolUse hook lets `session_start` launch
   only allowlisted apps, with no extra env and `isolate_home: true`. Don't bump
   the pin without re-reading upstream.

Not deployed on Linux: the LaunchAgent and `refresh-usage.sh`, `rate-limits.sh`
(it reads the macOS Keychain, so the status line shows usage as unknown), and
the `claude` profile shim.

## What's included

- **Git**: Templated gitconfig with aliases, colors, rerere, autosquash
- **Zsh**: zinit plugins (syntax highlighting, autosuggestions, completions)
- **Starship**: Minimal prompt (directory, git branch/status)
- **Brewfile**: Core packages via `brew bundle`
- **Claude Code**: Settings, hooks, agents, skills, global CLAUDE.md
- **Cursor**: Skills and meta-skills

## Secrets

Secrets are managed via chezmoi + Dashlane. The `~/.secrets.zsh` template pulls
tokens from Dashlane at `chezmoi apply` time. Machine-specific paths live in
`~/.localrc` (not managed by chezmoi).

## Daily usage

```bash
chezmoi edit ~/.zshrc        # Edit source, not target
chezmoi apply                # Apply changes to home dir
chezmoi diff                 # Preview pending changes
chezmoi update               # Pull latest from GitHub and apply
```
