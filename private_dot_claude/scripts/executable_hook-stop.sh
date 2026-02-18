#!/bin/bash
# Stop hook: Claude finished turn, set idle
echo "idle||$(date +%s)" > ~/.claude/status-cache/tool_state 2>/dev/null
