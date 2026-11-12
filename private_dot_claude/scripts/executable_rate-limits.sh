#!/bin/bash
# Usage figures for the status line, read by `anthropic-account status --statusline`
# (the same reader on every OS). Output contract lives in that CLI: line 1 is the
# current account, then one `other|<account>|...` line per other account.
# If the CLI is missing or fails, print nothing and exit 0; the caller renders "unknown".

out=$(anthropic-account status --statusline 2>/dev/null) || exit 0
[[ -n "$out" ]] && printf '%s\n' "$out"
exit 0
