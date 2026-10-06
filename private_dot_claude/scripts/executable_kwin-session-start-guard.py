#!/usr/bin/env python3
"""PreToolUse hook for mcp__kwin__session_start.

session_start runs app_command as the owner with the caller's env, outside
Claude Code's Bash rules, so only a fixed set of apps may start, with no extra
env, in a throwaway HOME. Exit 2 blocks the call and shows stderr to the model.
"""
import json
import shlex
import sys

# Exact argv only. No terminal: typing into one would be a shell outside the
# Bash permission rules. With isolate_home, Firefox gets a fresh profile.
ALLOWED_APPS = {
    (),
    ("dolphin",),
    ("kate",),
    ("kcalc",),
    ("firefox",),
}


def rejection(tool_input):
    """Return why the call must be blocked, or None to let it through."""
    if not isinstance(tool_input, dict):
        return "tool_input is not an object"
    env = tool_input.get("env")
    if env not in (None, {}):
        return "env must be empty; launched apps get only the server's scrubbed env"
    command = tool_input.get("app_command", "")
    if not isinstance(command, str):
        return "app_command must be a string"
    try:
        argv = tuple(shlex.split(command))
    except ValueError as error:
        return f"app_command does not parse: {error}"
    if argv not in ALLOWED_APPS:
        allowed = ", ".join(" ".join(app) for app in sorted(ALLOWED_APPS) if app)
        return f"app_command {command!r} is not allowed; use one of: {allowed}, or none"
    if tool_input.get("isolate_home") is not True:
        return "isolate_home must be true"
    return None


def main():
    try:
        payload = json.load(sys.stdin)
        reason = rejection(payload.get("tool_input"))
    except (ValueError, AttributeError) as error:
        reason = f"unreadable hook payload: {error}"
    if reason:
        print(f"kwin session_start blocked: {reason}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
