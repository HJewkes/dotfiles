#!/bin/bash
# Deploy the chezmoi config slice of the private overlay before apply renders.
# settings.json.tmpl reads ~/.config/chezmoi/claude-settings-patch.json while
# rendering, so it must already be in place; the run_after script that syncs the
# rest of the overlay is too late for anything consumed at render time.
PRIVATE="${HOME}/.local/private/chezmoi/.config/chezmoi"
[[ -d "$PRIVATE" ]] || exit 0
mkdir -p "${HOME}/.config/chezmoi"
rsync -a "$PRIVATE/" "${HOME}/.config/chezmoi/"
