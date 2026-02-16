# dotfiles

Managed by [chezmoi](https://chezmoi.io/).

## Setup on a new machine

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply HJewkes
```

Prompts for git name, email, and machine type (personal/work).

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
