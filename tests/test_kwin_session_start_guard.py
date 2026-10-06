"""Runs the kwin session_start hook on sample PreToolUse payloads.

Run: python3 -m unittest tests/test_kwin_session_start_guard.py
"""
import json
import pathlib
import subprocess
import sys
import unittest

HOOK = (pathlib.Path(__file__).resolve().parent.parent
        / "private_dot_claude/scripts/executable_kwin-session-start-guard.py")


def run_hook(stdin_text):
    return subprocess.run([sys.executable, str(HOOK)], input=stdin_text,
                          capture_output=True, text=True, check=False)


def session_start(**tool_input):
    payload = {"hook_event_name": "PreToolUse", "tool_name": "mcp__kwin__session_start",
               "tool_input": tool_input}
    return run_hook(json.dumps(payload))


class AllowedCalls(unittest.TestCase):
    def test_bare_session_with_isolated_home_passes(self):
        result = session_start(isolate_home=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_allowlisted_app_with_empty_env_passes(self):
        result = session_start(app_command="kate", env={}, isolate_home=True,
                               screen_width=1280, screen_height=800)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_null_env_passes(self):
        result = session_start(app_command="dolphin", env=None, isolate_home=True)
        self.assertEqual(result.returncode, 0, result.stderr)


class BlockedCalls(unittest.TestCase):
    def assertBlocked(self, result, fragment):
        self.assertEqual(result.returncode, 2)
        self.assertIn(fragment, result.stderr)

    def test_non_empty_env_is_blocked(self):
        result = session_start(app_command="kate", env={"LD_PRELOAD": "/x.so"},
                               isolate_home=True)
        self.assertBlocked(result, "env must be empty")

    def test_shell_command_is_blocked(self):
        result = session_start(app_command="bash -c 'id'", isolate_home=True)
        self.assertBlocked(result, "is not allowed")

    def test_terminal_is_blocked(self):
        self.assertBlocked(session_start(app_command="konsole", isolate_home=True),
                           "is not allowed")

    def test_allowlisted_app_with_extra_args_is_blocked(self):
        result = session_start(app_command="kate /etc/shadow", isolate_home=True)
        self.assertBlocked(result, "is not allowed")

    def test_allowlisted_app_by_other_path_is_blocked(self):
        result = session_start(app_command="/tmp/kate", isolate_home=True)
        self.assertBlocked(result, "is not allowed")

    def test_unbalanced_quotes_are_blocked(self):
        result = session_start(app_command="kate 'oops", isolate_home=True)
        self.assertBlocked(result, "does not parse")

    def test_missing_isolate_home_is_blocked(self):
        self.assertBlocked(session_start(app_command="kate"), "isolate_home must be true")

    def test_truthy_non_boolean_isolate_home_is_blocked(self):
        result = session_start(app_command="kate", isolate_home="yes")
        self.assertBlocked(result, "isolate_home must be true")

    def test_non_string_app_command_is_blocked(self):
        result = session_start(app_command=["kate"], isolate_home=True)
        self.assertBlocked(result, "must be a string")

    def test_garbage_payload_is_blocked(self):
        self.assertBlocked(run_hook("not json"), "unreadable hook payload")

    def test_payload_without_tool_input_is_blocked(self):
        self.assertBlocked(run_hook(json.dumps({"tool_name": "x"})), "not an object")


if __name__ == "__main__":
    unittest.main()
