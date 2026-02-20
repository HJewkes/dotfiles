#!/bin/bash
# Deploy files from private local chezmoi overlay if it exists.
# Store work-specific or machine-private files in ~/.local/private/chezmoi/
# using standard chezmoi source naming (dot_, private_, executable_, etc.).
# This directory is local-only and never committed to the public repo.
PRIVATE="${HOME}/.local/private/chezmoi"
[[ -d "$PRIVATE" ]] || exit 0
chezmoi apply --source "$PRIVATE" --force 2>/dev/null
