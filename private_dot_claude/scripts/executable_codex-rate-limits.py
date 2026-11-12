#!/usr/bin/env python3
"""Quiet Codex display cache. Source commands run only during background refresh."""
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import signal
import shlex
import subprocess
import sys
import tempfile
import time

LABEL = re.compile(r"[A-Za-z0-9_.-]{1,64}\Z")


def safe_label(value):
    return isinstance(value, str) and LABEL.fullmatch(value) and not value.startswith("sk-")


def load(path):
    try:
        if path.stat().st_size > 16384:
            return {}
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def command(config):
    args = config.get("argv")
    if not safe_label(config.get("label")) or not isinstance(args, list) or not args:
        return None
    if any(not isinstance(arg, str) or not arg or "\0" in arg or len(arg) > 4096 for arg in args):
        return None
    host = config.get("remote_host")
    if host is None:
        return args
    if not isinstance(host, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", host):
        return None
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=yes", host,
            " ".join(shlex.quote(arg) for arg in args)]


def source_output(args, timeout_seconds=12):
    child = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(child.stdout, selectors.EVENT_READ)
            output = b""
            deadline = time.monotonic() + timeout_seconds
            while time.monotonic() < deadline:
                if not selector.select(max(0, deadline - time.monotonic())):
                    break
                chunk = os.read(child.stdout.fileno(), 4097 - len(output))
                if not chunk:
                    return output.decode("utf-8") if child.wait(timeout=1) == 0 else None
                output += chunk
                if len(output) > 4096:
                    break
        return None
    finally:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            pass
        child.stdout.close()


def observation(line, label, started):
    if not isinstance(line, str):
        return {}
    fields = line.strip().split("|")
    if len(fields) != 6 or fields[0] != "codex" or fields[1] != label or fields[5] != "":
        return {}
    if not all(re.fullmatch(r"[0-9]{1,3}", field) for field in fields[2:5]):
        return {}
    five, weekly, age = map(int, fields[2:5])
    if five > 100 or weekly > 100 or age > 900:
        return {}
    # The wire floors age. Adding one bounds its hidden fractional second.
    return {"label": label, "five": five, "weekly": weekly, "age_bound": age + 1, "started_at": started}


def atomic_write(path, value):
    descriptor, name = tempfile.mkstemp(dir=path.parent, prefix=".codex-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(value, stream)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def source_key(config):
    return hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()


def refresh(config, cache, clock=time.time, fetch=source_output):
    args = command(config)
    if args is None:
        return
    cache.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (cache.parent / "refresh.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        started = clock()
        old = load(cache)
        last = old.get("last_attempt")
        if isinstance(last, (int, float)) and 0 <= started - last < 60:
            return
        atomic_write(cache, {"last_attempt": started})
        try:
            record = observation(fetch(args), config["label"], started)
        except (OSError, ValueError, subprocess.SubprocessError):
            record = {}
        atomic_write(cache, {**record, "last_attempt": clock(), "source_key": source_key(config)})


def display(record, label, now):
    unknown = f"codex|{label}|unknown|unknown||"
    try:
        age = record["age_bound"] + now - record["started_at"]
        values = [record["five"], record["weekly"]]
        if record["label"] != label or not math.isfinite(age) or now < record["started_at"] or not 0 <= age <= 900:
            return unknown
        if any(type(value) is not int or not 0 <= value <= 100 for value in values):
            return unknown
        if type(record["age_bound"]) is not int or not 1 <= record["age_bound"] <= 901:
            return unknown
        return f"codex|{label}|{values[0]}|{values[1]}|{math.ceil(age)}|"
    except (KeyError, TypeError, ValueError, OverflowError):
        return unknown


def cached_display(config, record, now):
    label = config.get("label") if safe_label(config.get("label")) else "default"
    if not command(config) or record.get("source_key") != source_key(config):
        return f"codex|{label}|unknown|unknown||"
    return display(record, label, now)


def main():
    home = Path.home()
    config = load(Path(os.environ.get("STATUSLINE_CODEX_CONFIG", home / ".config/codex-statusline.json")))
    cache = Path(os.environ.get("STATUSLINE_CODEX_CACHE", home / ".cache/codex-statusline/usage.json"))
    if sys.argv[1:] == ["--refresh"]:
        refresh(config, cache)
        return
    print(cached_display(config, load(cache), time.time()))
    if command(config):
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--refresh"], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError):
        print("codex|default|unknown|unknown||")
