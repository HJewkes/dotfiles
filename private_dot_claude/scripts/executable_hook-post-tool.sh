#!/bin/bash
# PostToolUse hook: clear active tool, set idle
echo "idle||$(date +%s)" > ~/.claude/status-cache/tool_state 2>/dev/null
