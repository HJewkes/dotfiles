#!/bin/bash
# Put the claude launch-time profile shim ahead of ~/.local/bin/claude on PATH.
# /opt/homebrew/bin precedes ~/.local/bin in every shell and daemon here, and it
# is the one early PATH directory writable without sudo.
set -euo pipefail
shim="$HOME/.local/libexec/claude-shim/claude"
link="/opt/homebrew/bin/claude"
[[ -x "$shim" && -d /opt/homebrew/bin ]] || exit 0
if [[ -e "$link" && ! -L "$link" ]]; then
  echo "install-claude-shim: $link exists and is not a symlink; leaving it alone" >&2
  exit 0
fi
ln -sfn "$shim" "$link"
