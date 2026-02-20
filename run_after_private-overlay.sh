#!/bin/bash
# Deploy files from private local chezmoi overlay.
# Structure mirrors $HOME: ~/.local/private/chezmoi/.zsh/ai.zsh → ~/.zsh/ai.zsh
# This directory is local-only and never committed to the public repo.
PRIVATE="${HOME}/.local/private/chezmoi"
[[ -d "$PRIVATE" ]] || exit 0
rsync -a "$PRIVATE/" "$HOME/"
