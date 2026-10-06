#!/bin/sh
# Runs inside the transient unit, which inherits the systemd user manager's
# environment (SSH_AUTH_SOCK, GPG_AGENT_INFO, XAUTHORITY, ...). kwin-mcp and the
# apps it launches get only what a Wayland session needs.
exec /usr/bin/env -i \
    PATH="$HOME/.local/share/kwin-mcp/venv/bin:/usr/local/bin:/usr/bin:/bin" \
    HOME="$HOME" \
    LANG="${LANG:-C.UTF-8}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    "$@"
