"""Runs the kwin-mcp launcher with `env` as the server to see what survives.

Run: python3 -m unittest tests/test_kwin_scrubbed_env.py
"""
import pathlib
import subprocess
import unittest

LAUNCHER = (pathlib.Path(__file__).resolve().parent.parent
            / "dot_local/share/kwin-mcp/executable_scrubbed-env.sh")


def launched_env(environment):
    output = subprocess.run(["/bin/sh", str(LAUNCHER), "/usr/bin/env"], env=environment,
                            capture_output=True, text=True, check=True).stdout
    return dict(line.split("=", 1) for line in output.splitlines())


SESSION = {"HOME": "/srv/agent", "LANG": "en_US.UTF-8", "XDG_RUNTIME_DIR": "/run/user/1000",
           "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus",
           "WAYLAND_DISPLAY": "wayland-0"}


class ScrubbedEnv(unittest.TestCase):
    def test_secrets_from_the_manager_environment_are_dropped(self):
        result = launched_env({**SESSION, "SSH_AUTH_SOCK": "/run/agent.sock",
                               "GH_TOKEN": "t", "LD_PRELOAD": "/x.so", "DISPLAY": ":0"})
        self.assertEqual(set(result), {"PATH", *SESSION})

    def test_session_variables_pass_through_unchanged(self):
        result = launched_env(SESSION)
        self.assertEqual({k: result[k] for k in SESSION}, SESSION)

    def test_path_is_fixed_with_the_venv_first(self):
        result = launched_env({**SESSION, "PATH": "/evil:/usr/bin"})
        self.assertEqual(result["PATH"],
                         "/srv/agent/.local/share/kwin-mcp/venv/bin:/usr/local/bin:/usr/bin:/bin")

    def test_missing_lang_and_display_get_defaults(self):
        partial = {k: v for k, v in SESSION.items() if k not in ("LANG", "WAYLAND_DISPLAY")}
        result = launched_env(partial)
        self.assertEqual((result["LANG"], result["WAYLAND_DISPLAY"]), ("C.UTF-8", "wayland-0"))


if __name__ == "__main__":
    unittest.main()
