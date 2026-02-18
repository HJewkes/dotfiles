#!/bin/bash
# PreToolUse hook: record active tool state for statusline
# Claude Code passes tool info via stdin as JSON
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null)
echo "working|${tool_name}|$(date +%s)" > ~/.claude/status-cache/tool_state 2>/dev/null
